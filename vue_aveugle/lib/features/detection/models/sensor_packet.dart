// lib/features/detection/models/sensor_packet.dart

import 'imu_data.dart';
import 'obstacle_data.dart';
import 'water_sensor_data.dart';
import 'gps_data.dart';

/// Paquet global contenant toutes les données capteurs d'une mesure
/// 
/// Cette classe encapsule un instantané complet de l'état des capteurs
/// à un moment précis. Elle combine :
/// - Les données d'orientation (IMU)
/// - Les données de distance (obstacles)
/// - Un horodatage pour synchronisation temporelle
/// 
/// Pourquoi grouper tout dans un paquet ? Pour garantir la cohérence temporelle :
/// toutes ces données ont été capturées au même instant par l'ESP32.
class SensorPacket {
  /// Horodatage Unix en millisecondes
  /// 
  /// Pourquoi un timestamp ? Essentiel pour :
  /// - Détecter des données périmées (latence réseau)
  /// - Synchroniser plusieurs flux de données
  /// - Calculer des vitesses et accélérations
  /// - Détecter des pertes de paquets
  /// 
  /// Format : millisecondes depuis epoch (01/01/1970 00:00:00 UTC)
  /// Exemple : 1712345678000 = 6 avril 2024, 01:54:38 UTC
  final int timestamp;

  /// Données de l'Inertial Measurement Unit (orientation)
  /// 
  /// Contient yaw, pitch, roll pour comprendre la posture et l'orientation
  /// de l'utilisateur dans l'espace
  final ImuData imu;

  /// Données des capteurs d'obstacles (distances)
  /// 
  /// Contient les distances upper (haut fixe), lower (bas rotatif) et l'angle servo
  final ObstacleData obstacles;

  /// Données du capteur d'eau/humidité
  /// 
  /// Détecte la présence d'eau au sol pour éviter glissades et flaques
  final WaterSensorData waterSensor;

  /// Données du module GPS
  /// 
  /// Position géographique, vitesse, cap, qualité du signal
  final GpsData gps;

  /// Constructeur du paquet de données
  /// 
  /// Tous les champs sont requis car un paquet incomplet est inutilisable
  /// pour la navigation sécuritaire
  SensorPacket({
    required this.timestamp,
    required this.imu,
    required this.obstacles,
    required this.waterSensor,
    required this.gps,
  }) {
    // Validation : le timestamp ne peut pas être dans le futur
    // Pourquoi ? Un timestamp futur indique une erreur d'horloge sur l'ESP32
    // ou une corruption de données
    final now = DateTime.now().millisecondsSinceEpoch;
    if (timestamp > now + 5000) {
      // On tolère 5 secondes de décalage pour des problèmes d'horloge mineurs
      throw ArgumentError(
        'Timestamp est dans le futur: $timestamp > $now',
      );
    }

    // Validation : le timestamp ne peut pas être trop ancien (> 1 heure)
    // Pourquoi ? Des données de plus d'une heure sont probablement corrompues
    // ou proviennent d'un cache non vidé
    if (timestamp < now - 3600000) {
      // 3600000 ms = 1 heure
      throw ArgumentError(
        'Timestamp est trop ancien (> 1 heure): $timestamp',
      );
    }
  }

  /// Factory pour créer un paquet depuis un String JSON complet
  /// 
  /// C'est le point d'entrée principal pour parser les données BLE.
  /// Les données arrivent comme un String JSON depuis l'ESP32, et cette
  /// méthode les transforme en objet Dart fortement typé.
  /// 
  /// Exemple de JSON attendu :
  /// ```json
  /// {
  ///   "timestamp": 1712345678000,
  ///   "imu": {
  ///     "yaw": 12.4,
  ///     "pitch": -1.2,
  ///     "roll": 0.3
  ///   },
  ///   "obstacles": {
  ///     "upper": 1.20,
  ///     "lower": 0.85,
  ///     "servoAngle": -45.0
  ///   },
  ///   "waterSensor": {
  ///     "humidityLevel": 45.5,
  ///     "rawValue": 1865
  ///   },
  ///   "gps": {
  ///     "latitude": 48.8566,
  ///     "longitude": 2.3522,
  ///     "altitude": 35.0,
  ///     "speed": 3.5,
  ///     "heading": 180.0,
  ///     "satellitesCount": 8,
  ///     "hdop": 1.2,
  ///     "gpsTimestamp": 1712345678000,
  ///     "fixType": "3d"
  ///   }
  /// }
  /// ```
  factory SensorPacket.fromJson(Map<String, dynamic> json) {
    // On extrait le timestamp
    // Pourquoi 'as int' ? On s'attend à un entier, pas un double
    // Le '?' rend l'opération sûre en cas de valeur null
    // Le '?? 0' fournit une valeur par défaut si absent (sera rejeté par validation)
    final int timestamp = json['timestamp'] as int? ?? 0;

    // On extrait et parse les données IMU
    // Pourquoi vérifier null ? Si la clé 'imu' est absente, on veut un objet
    // valide avec des valeurs par défaut plutôt qu'un crash
    final Map<String, dynamic> imuJson =
        json['imu'] as Map<String, dynamic>? ?? {};
    final ImuData imu = ImuData.fromJson(imuJson);

    // On extrait et parse les données obstacles
    final Map<String, dynamic> obstaclesJson =
        json['obstacles'] as Map<String, dynamic>? ?? {};
    final ObstacleData obstacles = ObstacleData.fromJson(obstaclesJson);

    // On extrait et parse les données du capteur d'eau
    final Map<String, dynamic> waterJson =
        json['waterSensor'] as Map<String, dynamic>? ?? {};
    final WaterSensorData waterSensor = WaterSensorData.fromJson(waterJson);

    // On extrait et parse les données GPS
    final Map<String, dynamic> gpsJson =
        json['gps'] as Map<String, dynamic>? ?? {};
    final GpsData gps = GpsData.fromJson(gpsJson);

    // On crée et retourne le paquet complet
    // Le constructeur fera les validations nécessaires
    return SensorPacket(
      timestamp: timestamp,
      imu: imu,
      obstacles: obstacles,
      waterSensor: waterSensor,
      gps: gps,
    );
  }

  /// Conversion vers Map pour sérialisation
  /// 
  /// Pourquoi ? Utile pour :
  /// - Sauvegarder les données dans une base de données
  /// - Envoyer les données à un serveur d'analyse
  /// - Logger les données pour débogage
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'imu': imu.toJson(),
      'obstacles': obstacles.toJson(),
      'waterSensor': waterSensor.toJson(),
      'gps': gps.toJson(),
    };
  }

  /// Calcule l'âge du paquet en millisecondes
  /// 
  /// Pourquoi cette méthode ? Pour détecter les données périmées.
  /// Si l'âge est > 500ms par exemple, on sait qu'il y a une latence
  /// importante dans le système BLE.
  int get age {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp;
  }

  /// Vérifie si le paquet est encore frais (< 1 seconde)
  /// 
  /// Pourquoi 1 seconde ? C'est un seuil raisonnable pour la navigation :
  /// - L'environnement change peu en 1 seconde à vitesse de marche
  /// - Au-delà, les données risquent d'être obsolètes pour la sécurité
  bool get isFresh {
    return age < 1000; // 1000ms = 1 seconde
  }

  /// Vérifie si le paquet est périmé (> 2 secondes)
  /// 
  /// Pourquoi 2 secondes ? Seuil critique au-delà duquel les données
  /// sont définitivement trop anciennes pour être utilisées en sécurité.
  /// Le système devrait ignorer ou alerter sur ces paquets.
  bool get isStale {
    return age > 2000; // 2000ms = 2 secondes
  }

  /// Conversion du timestamp en DateTime lisible
  /// 
  /// Pourquoi ? Facilite l'affichage et le débogage avec des dates
  /// humainement compréhensibles plutôt que des nombres Unix
  DateTime get dateTime {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Évalue la situation globale de danger en combinant tous les capteurs
  /// 
  /// Pourquoi cette méthode ? Donne une vue d'ensemble en un seul appel.
  /// Combine la posture (IMU), les obstacles, l'eau et même le GPS.
  /// 
  /// Retourne un score de 0.0 (sûr) à 1.0+ (très dangereux)
  double get overallDangerScore {
    double score = 0.0;

    // Score des obstacles (distance)
    final double obstacleScore = obstacles.dangerScore;
    score += obstacleScore;

    // Score de la posture (inclinaison)
    // On considère qu'une posture dangereuse ajoute 0.3 au score
    final double postureScore = imu.isDangerousTilt ? 0.3 : 0.0;
    score += postureScore;

    // Score du capteur d'eau (humidité)
    // Pondération x0.8 car moins critique qu'un obstacle dur
    final double waterScore = waterSensor.dangerScore * 0.8;
    score += waterScore;

    // Pénalité si GPS invalide en extérieur
    // Pourquoi ? Pas de GPS = pas de localisation d'urgence possible
    if (!gps.hasValidFix) {
      score += 0.1; // Légère pénalité
    }

    // Score combiné plafonné à 1.0
    return score.clamp(0.0, 1.0);
  }

  /// Vérifie si ce paquet nécessite une alerte immédiate
  /// 
  /// Pourquoi ? Point d'entrée simple pour le système d'alerte.
  /// Retourne true si AU MOINS un danger critique est détecté.
  bool get requiresImmediateAlert {
    // Danger obstacle : un obstacle très proche
    final bool obstacleDanger = obstacles.hasImmediateDanger;

    // Danger posture : tête dangereusement inclinée
    final bool postureDanger = imu.isDangerousTilt;

    // Danger données périmées : informations trop anciennes
    // Pourquoi alerter sur données périmées ? Parce que l'utilisateur
    // se déplace avec des informations obsolètes = danger
    final bool dataDanger = isStale;

    // Danger eau : sol submergé ou très glissant
    final bool waterDanger = waterSensor.isSubmerged || waterSensor.isDangerous;

    return obstacleDanger || postureDanger || dataDanger || waterDanger;
  }

  /// Génère un message d'alerte descriptif basé sur l'état actuel
  /// 
  /// Pourquoi ? Facilite la conversion des données en feedback vocal
  /// ou haptique pour l'utilisateur aveugle. Retourne un message clair
  /// et actionnable.
  String? get alertMessage {
    if (!requiresImmediateAlert) return null;

    // On priorise les messages par ordre de criticité
    if (isStale) {
      return 'Attention : perte de connexion avec les capteurs';
    }

    // Priorité 1 : Obstacles (le plus dangereux)
    if (obstacles.hasImmediateDanger) {
      final sensor = obstacles.criticalSensor;
      final distance = obstacles.minDistance;
      
      if (sensor == 'upper') {
        return 'Danger ! Obstacle en hauteur à ${distance?.toStringAsFixed(2)}m. Arrêtez-vous.';
      } else if (sensor == 'lower') {
        final zone = obstacles.lowerZone;
        return 'Danger ! Obstacle au sol ${zone == 'center' ? 'devant' : 'sur le côté $zone'} à ${distance?.toStringAsFixed(2)}m.';
      }
    }

    // Priorité 2 : Eau/humidité
    if (waterSensor.isSubmerged) {
      return 'Danger ! Eau détectée. Zone inondée, contournez.';
    }

    if (waterSensor.isDangerous) {
      return 'Attention ! Sol très glissant détecté. Ralentissez.';
    }

    // Priorité 3 : Posture
    if (imu.isDangerousTilt) {
      return 'Attention : posture instable détectée. Redressez-vous.';
    }

    return 'Attention requise'; // Message générique de fallback
  }

  /// Représentation textuelle complète pour le débogage
  /// 
  /// Pourquoi ? Permet de voir tous les détails d'un paquet en un coup d'œil
  /// dans les logs. Inclut toutes les métadonnées importantes.
  @override
  String toString() {
    return 'SensorPacket(\n'
        '  timestamp: $timestamp (${dateTime.toIso8601String()}),\n'
        '  age: ${age}ms,\n'
        '  imu: $imu,\n'
        '  obstacles: $obstacles,\n'
        '  water: $waterSensor,\n'
        '  gps: $gps,\n'
        '  dangerScore: ${overallDangerScore.toStringAsFixed(2)},\n'
        '  alert: ${requiresImmediateAlert ? alertMessage : 'none'}\n'
        ')';
  }

  /// Égalité basée sur les valeurs
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorPacket &&
        other.timestamp == timestamp &&
        other.imu == imu &&
        other.obstacles == obstacles &&
        other.waterSensor == waterSensor &&
        other.gps == gps;
  }

  /// Hash code pour collections
  @override
  int get hashCode => Object.hash(timestamp, imu, obstacles, waterSensor, gps);

  /// Copie avec modification de certains champs
  /// 
  /// Pourquoi ? Utile pour créer des variations de paquets
  /// lors de tests ou de corrections de données
  SensorPacket copyWith({
    int? timestamp,
    ImuData? imu,
    ObstacleData? obstacles,
    WaterSensorData? waterSensor,
    GpsData? gps,
  }) {
    return SensorPacket(
      timestamp: timestamp ?? this.timestamp,
      imu: imu ?? this.imu,
      obstacles: obstacles ?? this.obstacles,
      waterSensor: waterSensor ?? this.waterSensor,
      gps: gps ?? this.gps,
    );
  }
}