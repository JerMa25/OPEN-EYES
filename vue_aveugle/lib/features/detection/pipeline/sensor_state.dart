// lib/features/detection/pipeline/sensor_state.dart

import '../models/sensor_packet.dart';
import '../models/imu_data.dart';
import '../models/obstacle_data.dart';

/// État courant consolidé de l'environnement et de l'utilisateur
/// 
/// Cette classe représente la "situation actuelle" telle que perçue
/// par le système. Elle agrège et interprète les données brutes des capteurs
/// pour fournir une vue d'ensemble compréhensible et actionnable.
/// 
/// Pourquoi cette classe ? Séparation des responsabilités :
/// - SensorPacket = données brutes des capteurs
/// - SensorState = interprétation de haut niveau de ces données
/// 
/// Le futur système expert utilisera SensorState pour prendre des décisions
class SensorState {
  /// Le paquet de données capteurs le plus récent (déjà filtré)
  /// 
  /// Pourquoi garder le paquet complet ? Pour avoir accès à toutes
  /// les données détaillées si besoin, tout en exposant des interprétations
  /// de haut niveau via les autres propriétés
  final SensorPacket latestPacket;

  /// L'état précédent (null si c'est le premier état)
  /// 
  /// Pourquoi garder l'historique ? Pour calculer des deltas (changements),
  /// détecter des tendances, et comprendre l'évolution de la situation
  final SensorState? previousState;

  /// Horodatage de création de cet état
  /// 
  /// Pourquoi un timestamp séparé ? Le latestPacket a son propre timestamp
  /// (moment de capture par l'ESP32), mais on veut aussi savoir quand
  /// CET état a été créé par le pipeline (peut différer à cause du filtrage)
  final DateTime timestamp;

  /// Constructeur privé (pattern factory)
  /// 
  /// Pourquoi privé ? On veut forcer l'utilisation de fromPacket() pour
  /// s'assurer que tous les états sont créés de manière cohérente
  SensorState._({
    required this.latestPacket,
    this.previousState,
    required this.timestamp,
  });

  /// Factory pour créer un nouvel état depuis un paquet filtré
  /// 
  /// C'est la méthode principale utilisée par le pipeline pour transformer
  /// des paquets de données en états interprétés
  factory SensorState.fromPacket(
    SensorPacket packet, {
    SensorState? previousState,
  }) {
    return SensorState._(
      latestPacket: packet,
      previousState: previousState,
      timestamp: DateTime.now(),
    );
  }

  // ========== GETTERS DE COMMODITÉ ==========
  // Ces getters facilitent l'accès aux données sans avoir à naviguer
  // dans latestPacket.imu.yaw, etc. Plus lisible et maintenable.

  /// Données IMU actuelles
  ImuData get imu => latestPacket.imu;

  /// Données obstacles actuelles
  ObstacleData get obstacles => latestPacket.obstacles;

  /// Âge des données en millisecondes
  /// 
  /// Pourquoi important ? Des données anciennes peuvent être dangereuses
  /// pour la navigation en temps réel
  int get dataAge => latestPacket.age;

  /// Vérifie si les données sont fraîches (< 1 seconde)
  bool get isFresh => latestPacket.isFresh;

  // ========== ANALYSE DE MOUVEMENT ==========
  // Ces méthodes analysent comment l'utilisateur bouge en comparant
  // l'état actuel avec l'état précédent

  /// Calcule le changement d'orientation (rotation) depuis l'état précédent
  /// 
  /// Pourquoi ? Permet de détecter :
  /// - Si l'utilisateur tourne la tête (balayage visuel)
  /// - La vitesse de rotation (rapide = peut-être désorienté)
  /// - La direction du mouvement
  /// 
  /// Retourne null si pas d'état précédent disponible
  ImuData? get imuDelta {
    if (previousState == null) return null;

    final prev = previousState!.imu;
    final curr = imu;

    // Calculer les différences pour chaque axe
    return ImuData(
      yaw: _calculateAngleDelta(prev.yaw, curr.yaw),
      pitch: _calculateAngleDelta(prev.pitch, curr.pitch),
      roll: _calculateAngleDelta(prev.roll, curr.roll),
    );
  }

  /// Calcule la différence entre deux angles en gérant le wrap-around
  /// 
  /// Pourquoi cette méthode ? Les angles "wrappent" à ±180° :
  /// passer de 179° à -179° est un changement de 2°, pas 358° !
  /// 
  /// Exemple : prev=170°, curr=-170° -> delta=20° (pas 340°)
  double _calculateAngleDelta(double prev, double curr) {
    double delta = curr - prev;

    // Normaliser dans l'intervalle [-180, 180]
    // Pourquoi ? Pour avoir le chemin le plus court entre les deux angles
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;

    return delta;
  }

  /// Calcule la vitesse de rotation angulaire (degrés par seconde)
  /// 
  /// Pourquoi ? Indicateur important de désorientation :
  /// - Rotation lente = navigation contrôlée
  /// - Rotation rapide = peut-être perdu ou désorienté
  /// 
  /// Retourne null si calcul impossible (pas d'état précédent ou temps invalide)
  double? get rotationSpeed {
    if (previousState == null) return null;

    final delta = imuDelta;
    if (delta == null) return null;

    // Calculer le temps écoulé entre les deux états en secondes
    final timeDiffMs = timestamp.millisecondsSinceEpoch -
        previousState!.timestamp.millisecondsSinceEpoch;

    if (timeDiffMs <= 0) return null; // Éviter division par zéro

    final timeDiffSeconds = timeDiffMs / 1000.0;

    // Calculer la magnitude totale de rotation (Pythagore 3D)
    // Pourquoi ? Pour avoir UNE métrique de "vitesse de rotation globale"
    final magnitude = (delta.yaw * delta.yaw +
            delta.pitch * delta.pitch +
            delta.roll * delta.roll)
        .abs();

    // Vitesse = distance angulaire / temps
    return magnitude / timeDiffSeconds;
  }

  /// Vérifie si l'utilisateur est en train de tourner rapidement
  /// 
  /// Pourquoi > 30°/s ? Seuil empirique :
  /// - Marche normale : 5-15°/s de rotation de tête
  /// - Balayage actif : 20-30°/s
  /// - Rotation rapide : > 30°/s (possiblement désorienté)
  bool get isRotatingFast {
    final speed = rotationSpeed;
    return speed != null && speed > 30.0; // degrés/seconde
  }

  // ========== ANALYSE DES OBSTACLES ==========
  // Ces méthodes analysent l'évolution des obstacles dans le temps

  /// Calcule le changement de distance des obstacles depuis l'état précédent
  /// 
  /// Pourquoi ? Permet de détecter :
  /// - Si l'utilisateur s'approche d'un obstacle (distances diminuent)
  /// - Si un nouvel obstacle apparaît soudainement
  /// - La vitesse d'approche (critique pour la sécurité)
  ObstacleData? get obstacleDelta {
    if (previousState == null) return null;

    final prev = previousState!.obstacles;
    final curr = obstacles;

    return ObstacleData(
      front: _calculateDistanceDelta(prev.front, curr.front),
      left: _calculateDistanceDelta(prev.left, curr.left),
      right: _calculateDistanceDelta(prev.right, curr.right),
    );
  }

  /// Calcule la différence entre deux distances
  /// 
  /// Pourquoi ? Gérer les cas null (pas d'obstacle) correctement
  /// - null -> null = pas de changement (toujours rien)
  /// - null -> valeur = obstacle apparu (retourne valeur négative)
  /// - valeur -> null = obstacle disparu (retourne valeur positive)
  /// - valeur -> valeur = changement normal
  double? _calculateDistanceDelta(double? prev, double? curr) {
    if (prev == null && curr == null) return null; // Toujours rien
    if (prev == null) return -curr!; // Apparu (négatif = approche)
    if (curr == null) return prev; // Disparu (positif = éloignement)
    return curr - prev; // Changement normal
  }

  /// Vérifie si l'utilisateur s'approche d'un obstacle
  /// 
  /// Pourquoi ? Information critique pour la sécurité :
  /// s'approcher = danger imminent, besoin d'alerte précoce
  /// 
  /// On considère "approche" si la distance diminue de > 0.1m
  bool get isApproachingObstacle {
    final delta = obstacleDelta;
    if (delta == null) return false;

    // Vérifier chaque direction : si AU MOINS UNE distance diminue
    // significativement (> 0.1m), on considère qu'il y a approche
    final frontApproach = delta.front != null && delta.front! < -0.1;
    final leftApproach = delta.left != null && delta.left! < -0.1;
    final rightApproach = delta.right != null && delta.right! < -0.1;

    return frontApproach || leftApproach || rightApproach;
  }

  /// Calcule la vitesse d'approche d'un obstacle (m/s)
  /// 
  /// Pourquoi ? Pour estimer le temps avant collision :
  /// - Vitesse élevée + obstacle proche = danger imminent
  /// - Vitesse faible = l'utilisateur a le temps de réagir
  /// 
  /// Retourne null si calcul impossible
  double? get approachSpeed {
    if (previousState == null) return null;

    final delta = obstacleDelta;
    if (delta == null) return null;

    // Calculer le temps écoulé en secondes
    final timeDiffMs = timestamp.millisecondsSinceEpoch -
        previousState!.timestamp.millisecondsSinceEpoch;

    if (timeDiffMs <= 0) return null;

    final timeDiffSeconds = timeDiffMs / 1000.0;

    // Prendre la vitesse d'approche la plus rapide parmi les 3 directions
    // Pourquoi le min ? En approche, delta est négatif, donc min = plus rapide
    final speeds = [delta.front, delta.left, delta.right]
        .where((d) => d != null)
        .map((d) => d! / timeDiffSeconds)
        .toList();

    if (speeds.isEmpty) return null;

    // Retourner la valeur absolue de la vitesse la plus élevée
    return speeds.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
  }

  // ========== ÉVALUATION GLOBALE ==========
  // Ces méthodes fournissent des jugements de haut niveau sur la situation

  /// Niveau de danger global (0 = sûr, 1 = très dangereux, 2+ = critique)
  /// 
  /// Pourquoi un score ? Permet de prioriser les alertes et d'adapter
  /// l'intensité du feedback (haptique, audio) selon la gravité
  /// 
  /// Le score combine plusieurs facteurs pondérés
  double get dangerLevel {
    double score = 0.0;

    // Facteur 1 : Score de danger des obstacles (0.0-1.0)
    score += latestPacket.overallDangerScore;

    // Facteur 2 : Données périmées (+0.5 si périmé)
    // Pourquoi 0.5 ? C'est un danger modéré mais significatif
    if (!isFresh) score += 0.5;

    // Facteur 3 : Approche rapide d'obstacle (+0.3 par 0.1m/s)
    // Pourquoi ? Plus on s'approche vite, plus c'est dangereux
    final speed = approachSpeed;
    if (speed != null && speed > 0.1) {
      score += speed * 3.0; // 0.3m/s -> +0.9 au score
    }

    // Facteur 4 : Rotation rapide (+0.3)
    // Pourquoi ? Rotation rapide = possiblement désorienté
    if (isRotatingFast) score += 0.3;

    return score;
  }

  /// Vérifie si une alerte immédiate est nécessaire
  /// 
  /// Pourquoi cette méthode ? Point d'entrée simple pour le système d'alerte.
  /// Retourne true si la situation nécessite une intervention immédiate
  bool get requiresImmediateAlert {
    // Critère 1 : Le paquet lui-même signale un danger
    if (latestPacket.requiresImmediateAlert) return true;

    // Critère 2 : Niveau de danger élevé (> 1.5)
    // Pourquoi 1.5 ? Seuil conservateur pour la sécurité
    if (dangerLevel > 1.5) return true;

    // Critère 3 : Vitesse d'approche très élevée (> 0.5 m/s)
    // Pourquoi 0.5m/s ? À cette vitesse, collision en < 2 secondes
    // avec un obstacle à 1m
    final speed = approachSpeed;
    if (speed != null && speed > 0.5) return true;

    return false;
  }

  /// Retourne une description textuelle de la situation actuelle
  /// 
  /// Pourquoi ? Facilite le débogage et peut être utilisée pour
  /// générer des messages vocaux à l'utilisateur
  String get situationDescription {
    if (!isFresh) {
      return 'Connexion perdue avec les capteurs';
    }

    if (latestPacket.obstacles.hasImmediateDanger) {
      final dir = latestPacket.obstacles.closestObstacleDirection;
      final dist = latestPacket.obstacles.minDistance;
      return 'Danger immédiat : obstacle $dir à ${dist?.toStringAsFixed(2)}m';
    }

    if (latestPacket.obstacles.requiresAttention) {
      return 'Vigilance requise : obstacles proches détectés';
    }

    if (isApproachingObstacle) {
      final speed = approachSpeed;
      return 'Approche d\'obstacle à ${speed?.toStringAsFixed(2)} m/s';
    }

    if (isRotatingFast) {
      return 'Rotation rapide détectée';
    }

    return 'Environnement dégagé';
  }

  /// Niveau de priorité de l'alerte (0 = aucune, 1 = info, 2 = attention, 3 = danger)
  /// 
  /// Pourquoi des niveaux ? Permet d'adapter le type de feedback :
  /// - 0 : rien
  /// - 1 : notification légère (vibration courte)
  /// - 2 : alerte modérée (son + vibration)
  /// - 3 : alerte maximale (son fort + vibration continue)
  int get alertPriority {
    if (!isFresh) return 3; // Perte de données = danger maximum

    if (latestPacket.obstacles.hasImmediateDanger) return 3;

    if (dangerLevel > 1.5) return 3;

    if (isApproachingObstacle) return 2;

    if (latestPacket.obstacles.requiresAttention) return 2;

    if (isRotatingFast) return 1;

    return 0; // Situation normale
  }

  /// Représentation textuelle pour le débogage
  /// 
  /// Pourquoi ? Affiche un résumé complet de l'état dans les logs,
  /// facilitant le diagnostic de problèmes
  @override
  String toString() {
    return 'SensorState(\n'
        '  timestamp: ${timestamp.toIso8601String()},\n'
        '  dataAge: ${dataAge}ms,\n'
        '  isFresh: $isFresh,\n'
        '  dangerLevel: ${dangerLevel.toStringAsFixed(2)},\n'
        '  alertPriority: $alertPriority,\n'
        '  situation: $situationDescription,\n'
        '  latestPacket: $latestPacket\n'
        ')';
  }

  /// Conversion vers Map pour sérialisation/logging
  /// 
  /// Pourquoi ? Permet de sauvegarder l'état complet pour analyse
  /// ultérieure ou transmission à un serveur de monitoring
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'dataAge': dataAge,
      'isFresh': isFresh,
      'dangerLevel': dangerLevel,
      'alertPriority': alertPriority,
      'situation': situationDescription,
      'rotationSpeed': rotationSpeed,
      'approachSpeed': approachSpeed,
      'latestPacket': latestPacket.toJson(),
    };
  }
}