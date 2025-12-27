// lib/features/detection/domain/sensor_snapshot.dart

/// Représente une photo instantanée des données capteurs à un moment T
/// Cette classe est immutable pour garantir la cohérence des données
class SensorSnapshot {
  /// Distance mesurée par le capteur avant (en mètres)
  final double distanceFront;
  
  /// Distance mesurée par le capteur gauche (en mètres)
  final double distanceLeft;
  
  /// Distance mesurée par le capteur droit (en mètres)
  final double distanceRight;

  /// Détection d'obstacle en hauteur (tête/visage)
  /// true = obstacle détecté à hauteur dangereuse
  final bool obstacleHigh;
  
  /// Détection d'eau au sol
  /// true = présence d'eau détectée
  final bool waterDetected;

  /// Orientation azimut (rotation horizontale) en degrés
  /// 0° = Nord, 90° = Est, 180° = Sud, 270° = Ouest
  final double yaw;
  
  /// Inclinaison avant/arrière en degrés
  /// Positif = penché vers l'avant
  final double pitch;
  
  /// Inclinaison gauche/droite en degrés
  /// Positif = penché vers la droite
  final double roll;

  /// Timestamp de la capture (millisecondes depuis epoch)
  final int timestamp;

  const SensorSnapshot({
    required this.distanceFront,
    required this.distanceLeft,
    required this.distanceRight,
    required this.obstacleHigh,
    required this.waterDetected,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.timestamp,
  });

  /// Retourne true si un obstacle est proche devant (< 1.5m)
  bool get hasObstacleFront => distanceFront < 1.5;

  /// Retourne true si un obstacle est proche à gauche (< 0.8m)
  bool get hasObstacleLeft => distanceLeft < 0.8;

  /// Retourne true si un obstacle est proche à droite (< 0.8m)
  bool get hasObstacleRight => distanceRight < 0.8;

  /// Retourne true si l'utilisateur dévie significativement
  /// Seuil : +/- 15° par rapport à la trajectoire droite
  bool get isDeviating => yaw.abs() > 15.0;

  /// Copie avec modifications
  SensorSnapshot copyWith({
    double? distanceFront,
    double? distanceLeft,
    double? distanceRight,
    bool? obstacleHigh,
    bool? waterDetected,
    double? yaw,
    double? pitch,
    double? roll,
    int? timestamp,
  }) {
    return SensorSnapshot(
      distanceFront: distanceFront ?? this.distanceFront,
      distanceLeft: distanceLeft ?? this.distanceLeft,
      distanceRight: distanceRight ?? this.distanceRight,
      obstacleHigh: obstacleHigh ?? this.obstacleHigh,
      waterDetected: waterDetected ?? this.waterDetected,
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'SensorSnapshot(front: ${distanceFront.toStringAsFixed(2)}m, '
        'left: ${distanceLeft.toStringAsFixed(2)}m, '
        'right: ${distanceRight.toStringAsFixed(2)}m, '
        'yaw: ${yaw.toStringAsFixed(1)}°, '
        'high: $obstacleHigh, water: $waterDetected)';
  }
}