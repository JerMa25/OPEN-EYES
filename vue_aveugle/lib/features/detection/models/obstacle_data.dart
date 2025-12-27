// lib/features/detection/models/obstacle_data.dart

/// Modèle de données pour les capteurs d'obstacles ultrasoniques
/// 
/// Architecture matérielle OPEN-EYES :
/// - CAPTEUR BAS : Monté sur servo moteur, peut tourner pour balayer l'environnement
///   Détecte les obstacles au niveau du sol/jambes (marches, trottoirs, objets bas)
/// - CAPTEUR HAUT : Fixe, orienté vers l'avant
///   Détecte les obstacles au niveau du torse/tête (portes, branches, panneaux)
/// 
/// Unité : Toutes les distances sont en mètres
/// Plage de détection typique : 0.02m à 4.00m (selon capteur HC-SR04)
class ObstacleData {
  /// Distance mesurée par le capteur HAUT fixe (en mètres)
  /// 
  /// Pourquoi capteur haut ? Pour détecter :
  /// - Obstacles au niveau du visage/torse (branches, panneaux)
  /// - Portes fermées
  /// - Murs en approche
  /// - Objets suspendus (enseignes, auvents)
  /// 
  /// Ce capteur est FIXE (pas de rotation) et pointe toujours devant
  /// Valeur null si le capteur ne détecte rien (hors de portée)
  final double? upper;

  /// Distance mesurée par le capteur BAS rotatif (en mètres)
  /// 
  /// Pourquoi capteur bas ? Pour détecter :
  /// - Marches et escaliers
  /// - Trottoirs et bordures
  /// - Objets au sol (chaises, tables basses, animaux)
  /// - Changements de niveau du sol
  /// 
  /// Ce capteur est MONTÉ SUR SERVO et peut tourner pour balayer
  /// Valeur null si aucun obstacle détecté
  final double? lower;

  /// Angle actuel du servo du capteur bas (en degrés)
  /// 
  /// Pourquoi cet angle ? Pour savoir DANS QUELLE DIRECTION le capteur bas regarde :
  /// - 0° = directement devant (centre)
  /// - -90° = complètement à gauche
  /// - +90° = complètement à droite
  /// 
  /// Cet angle est crucial pour :
  /// - Interpréter correctement la distance mesurée
  /// - Construire une carte de l'environnement
  /// - Planifier les prochaines mesures (où regarder ensuite)
  /// 
  /// Plage typique : -90° à +90° (180° de balayage total)
  final double servoAngle;

  /// Seuil de danger immédiat pour capteur HAUT (en mètres)
  /// 
  /// Pourquoi 0.6m pour le haut ? Le capteur haut détecte au niveau torse/tête :
  /// - Plus critique qu'un obstacle au sol
  /// - Moins de temps pour réagir (impact direct au visage)
  /// - Distance légèrement supérieure pour compenser le temps de réaction
  static const double upperDangerThreshold = 0.6;

  /// Seuil de danger immédiat pour capteur BAS (en mètres)
  /// 
  /// Pourquoi 0.4m pour le bas ? Le capteur bas détecte au niveau jambes/sol :
  /// - On peut enjamber certains petits obstacles
  /// - Plus de temps pour réagir (impact moins critique)
  /// - Distance plus courte acceptable
  static const double lowerDangerThreshold = 0.4;

  /// Seuil d'alerte préventive (en mètres)
  /// 
  /// Pourquoi 1.0m ? Zone d'attention où l'utilisateur doit être vigilant
  /// mais n'est pas en danger immédiat. Permet une navigation anticipative.
  static const double warningThreshold = 1.0;

  /// Distance maximale considérée comme "voie libre" (en mètres)
  /// 
  /// Pourquoi 2.5m ? Au-delà de cette distance, l'obstacle est assez loin
  /// pour ne pas nécessiter d'action immédiate. Limite aussi les faux positifs
  /// dus à des objets très éloignés (murs lointains, etc.)
  static const double clearThreshold = 2.5;

  /// Constructeur avec validation des distances et angle servo
  /// 
  /// Pourquoi des double? nullable pour distances ? Les capteurs ultrasoniques 
  /// ne détectent pas toujours quelque chose (hors de portée, angle oblique).
  /// null signifie "pas d'obstacle détecté" ≠ "obstacle à 0m"
  /// 
  /// servoAngle est OBLIGATOIRE car on doit toujours savoir où regarde le capteur bas
  ObstacleData({
    this.upper,
    this.lower,
    required this.servoAngle,
  }) {
    // Validation : les distances doivent être positives si présentes
    // Pourquoi ? Une distance négative n'a pas de sens physique
    if (upper != null && upper! < 0) {
      throw ArgumentError('Distance upper ne peut pas être négative: $upper');
    }
    if (lower != null && lower! < 0) {
      throw ArgumentError('Distance lower ne peut pas être négative: $lower');
    }

    // Validation : distances raisonnables (< 10m)
    // Pourquoi 10m ? Les capteurs ultrasoniques dépassent rarement 4-5m de portée
    if (upper != null && upper! > 10) {
      throw ArgumentError('Distance upper irréaliste: $upper m');
    }
    if (lower != null && lower! > 10) {
      throw ArgumentError('Distance lower irréaliste: $lower m');
    }

    // Validation : angle servo dans une plage raisonnable
    // Pourquoi -180 à +180 ? Plage standard des servos, même si on n'utilise que -90 à +90
    if (servoAngle < -180 || servoAngle > 180) {
      throw ArgumentError(
        'Angle servo hors limites: $servoAngle° (attendu: -180° à +180°)',
      );
    }
  }

  /// Factory pour créer une instance depuis un Map JSON
  /// 
  /// Pourquoi un factory ? Centralise le parsing des données BLE
  /// et gère les cas où les capteurs ne renvoient pas de données
  /// 
  /// Exemple JSON : 
  /// {
  ///   "upper": 1.20,
  ///   "lower": 0.85,
  ///   "servoAngle": -45.0
  /// }
  factory ObstacleData.fromJson(Map<String, dynamic> json) {
    return ObstacleData(
      // Distances peuvent être absentes (null) si pas d'obstacle détecté
      upper: (json['upper'] as num?)?.toDouble(),
      lower: (json['lower'] as num?)?.toDouble(),
      // L'angle servo est OBLIGATOIRE (on doit toujours savoir où regarde le capteur)
      servoAngle: (json['servoAngle'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Conversion vers Map pour sérialisation
  /// 
  /// Pourquoi ? Utile pour logging, débogage et sauvegarde
  Map<String, dynamic> toJson() {
    return {
      'upper': upper,
      'lower': lower,
      'servoAngle': servoAngle,
    };
  }

  /// Vérifie si un obstacle est en danger immédiat
  /// 
  /// Pourquoi cette méthode ? C'est l'information la plus critique pour la sécurité.
  /// Si true, le système doit alerter l'utilisateur immédiatement.
  /// 
  /// On utilise des seuils différents selon le capteur (haut vs bas)
  bool get hasImmediateDanger {
    // Danger capteur HAUT : obstacle au niveau torse/tête (plus critique)
    final bool upperDanger = upper != null && upper! < upperDangerThreshold;
    
    // Danger capteur BAS : obstacle au niveau jambes/sol (moins critique)
    final bool lowerDanger = lower != null && lower! < lowerDangerThreshold;

    return upperDanger || lowerDanger;
  }

  /// Vérifie si un obstacle nécessite une vigilance accrue
  /// 
  /// Pourquoi ? Zone intermédiaire entre "tout va bien" et "danger".
  /// L'utilisateur doit ralentir ou modifier légèrement sa trajectoire.
  bool get requiresAttention {
    final bool upperWarning = upper != null && upper! < warningThreshold;
    final bool lowerWarning = lower != null && lower! < warningThreshold;

    return upperWarning || lowerWarning;
  }

  /// Retourne la distance minimale détectée (obstacle le plus proche)
  /// 
  /// Pourquoi ? Donne rapidement "l'obstacle le plus critique" tous capteurs confondus
  double? get minDistance {
    final distances = [upper, lower].whereType<double>().toList();
    if (distances.isEmpty) return null;
    return distances.reduce((a, b) => a < b ? a : b);
  }

  /// Vérifie si la voie est complètement dégagée au niveau HAUT (torse/tête)
  /// 
  /// Pourquoi vérifier le haut spécifiquement ? C'est la zone la plus critique :
  /// un obstacle au niveau du visage est plus dangereux qu'au niveau des pieds
  bool get isUpperClear {
    return upper == null || upper! > clearThreshold;
  }

  /// Vérifie si la voie est dégagée au niveau BAS dans la direction actuelle du servo
  /// 
  /// Pourquoi cette méthode ? Pour savoir si on peut avancer sans risque de trébucher
  bool get isLowerClear {
    return lower == null || lower! > clearThreshold;
  }

  /// Indique si le capteur bas regarde vers l'avant (dans un cône de ±30°)
  /// 
  /// Pourquoi ±30° ? Définit une zone "devant" raisonnable :
  /// - 0° = exactement devant
  /// - ±30° = légèrement sur les côtés mais toujours "devant"
  /// - Au-delà = vraiment sur le côté
  bool get isLowerFacingForward {
    return servoAngle.abs() <= 30.0;
  }

  /// Retourne la zone géographique regardée par le capteur bas
  /// 
  /// Pourquoi ? Pour interpréter correctement les détections :
  /// une distance courte à gauche n'a pas la même implication qu'au centre
  /// 
  /// Retourne : 'center', 'left', 'right'
  String get lowerZone {
    if (servoAngle.abs() <= 30.0) return 'center';
    if (servoAngle < -30.0) return 'left';
    return 'right';
  }

  /// Calcule un "score de danger" global (0.0 = sûr, 1.0 = très dangereux)
  /// 
  /// Pourquoi ? Métrique unique pour évaluer la situation.
  /// Priorité au capteur HAUT car plus critique (impacts visage/torse)
  double get dangerScore {
    double score = 0.0;

    // Score du capteur HAUT (pondération x1.5 car plus critique)
    if (upper != null) {
      if (upper! < upperDangerThreshold) {
        score += 1.0; // Danger immédiat
      } else if (upper! < clearThreshold) {
        // Formule progressive : plus c'est proche, plus le score est élevé
        score += (1.0 - (upper! / clearThreshold)) * 1.5;
      }
    }

    // Score du capteur BAS (pondération x1.0 car moins critique)
    if (lower != null) {
      if (lower! < lowerDangerThreshold) {
        score += 0.7; // Danger modéré (peut enjamber)
      } else if (lower! < clearThreshold) {
        score += (1.0 - (lower! / clearThreshold)) * 1.0;
      }
    }

    // Bonus si capteur bas regarde devant ET détecte obstacle proche
    // Pourquoi ? Obstacle devant au sol = risque de trébucher immédiat
    if (isLowerFacingForward && lower != null && lower! < 1.0) {
      score += 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Identifie le capteur ayant détecté l'obstacle le plus proche
  /// 
  /// Pourquoi ? Pour adapter le message d'alerte :
  /// "Attention obstacle en hauteur" vs "Attention marche"
  String? get criticalSensor {
    final min = minDistance;
    if (min == null) return null;

    if (upper == min) return 'upper';
    if (lower == min) return 'lower';
    return null;
  }

  /// Vérifie si le capteur bas a terminé un balayage complet
  /// 
  /// Pourquoi ? Pour savoir quand on a une vue complète de l'environnement.
  /// Un balayage complet va généralement de -90° à +90°
  /// 
  /// Cette méthode nécessite de comparer avec l'angle précédent (non implémenté ici,
  /// sera géré dans SensorState qui garde l'historique)
  bool get isAtSweepBoundary {
    // Aux limites du balayage (-90° ou +90°)
    return servoAngle.abs() >= 85.0;
  }

  /// Représentation textuelle pour le débogage
  /// 
  /// Pourquoi ? Facilite le débogage avec des logs lisibles
  @override
  String toString() {
    String formatDistance(double? d) {
      return d != null ? '${d.toStringAsFixed(2)}m' : 'N/A';
    }

    return 'ObstacleData('
        'upper: ${formatDistance(upper)}, '
        'lower: ${formatDistance(lower)} @ ${servoAngle.toStringAsFixed(1)}° '
        '[${lowerZone}]'
        ')';
  }

  /// Égalité basée sur les valeurs
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ObstacleData &&
        other.upper == upper &&
        other.lower == lower &&
        other.servoAngle == servoAngle;
  }

  /// Hash code pour collections
  @override
  int get hashCode => Object.hash(upper, lower, servoAngle);

  /// Copie avec modification de certains champs
  /// 
  /// Pourquoi ? Pattern immutable pour la sécurité thread
  ObstacleData copyWith({
    double? upper,
    double? lower,
    double? servoAngle,
  }) {
    return ObstacleData(
      upper: upper ?? this.upper,
      lower: lower ?? this.lower,
      servoAngle: servoAngle ?? this.servoAngle,
    );
  }
}