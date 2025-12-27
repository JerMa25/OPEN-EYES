// lib/features/detection/tests/fake_sensor_data.dart

import '../domain/sensor_snapshot.dart';

/// Générateur de données capteurs simulées pour les tests
/// Permet de tester le système expert AVANT de recevoir des données réelles
class FakeSensorData {
  /// Snapshot de base : tout est OK, voie libre
  static SensorSnapshot baseline() {
    return SensorSnapshot(
      distanceFront: 5.0,
      distanceLeft: 3.0,
      distanceRight: 3.0,
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 1: Obstacle frontal très proche (< 1m)
  /// Attendu: "Obstacle devant. Tournez à [direction] maintenant."
  static SensorSnapshot obstacleFrontClose() {
    return SensorSnapshot(
      distanceFront: 0.7, // Très proche
      distanceLeft: 2.5,  // Espace suffisant à gauche
      distanceRight: 1.0, // Moins d'espace à droite
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 2: Obstacle frontal à distance moyenne (1-2m)
  /// Attendu: "Obstacle devant. Avancez encore d'un mètre, puis tournez à droite."
  static SensorSnapshot obstacleFrontMedium() {
    return SensorSnapshot(
      distanceFront: 1.5,
      distanceLeft: 1.5,
      distanceRight: 3.0, // Plus d'espace à droite
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 3: Obstacle en hauteur (priorité maximale)
  /// Attendu: "Attention, obstacle en hauteur devant vous."
  static SensorSnapshot obstacleHigh() {
    return SensorSnapshot(
      distanceFront: 3.0,
      distanceLeft: 2.0,
      distanceRight: 2.0,
      obstacleHigh: true, // DANGER: niveau tête
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 4: Présence d'eau au sol
  /// Attendu: "Présence d'eau au sol. Avancez lentement."
  static SensorSnapshot waterDetected() {
    return SensorSnapshot(
      distanceFront: 4.0,
      distanceLeft: 2.5,
      distanceRight: 2.5,
      obstacleHigh: false,
      waterDetected: true, // Eau détectée
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 5: Déviation de trajectoire (légère)
  /// Attendu: "Vous déviez vers la droite. Redressez vers la gauche."
  static SensorSnapshot wrongOrientationSlight() {
    return SensorSnapshot(
      distanceFront: 5.0,
      distanceLeft: 2.5,
      distanceRight: 2.5,
      obstacleHigh: false,
      waterDetected: false,
      yaw: 20.0, // Déviation de 20° vers la droite
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 6: Déviation de trajectoire (forte)
  /// Attendu: "Mauvaise trajectoire. Revenez d'un mètre, puis tournez à gauche."
  static SensorSnapshot wrongOrientationStrong() {
    return SensorSnapshot(
      distanceFront: 5.0,
      distanceLeft: 2.5,
      distanceRight: 2.5,
      obstacleHigh: false,
      waterDetected: false,
      yaw: 35.0, // Déviation de 35° vers la droite
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 7: Obstacles latéraux (passage étroit)
  /// Attendu: "Passage étroit. Avancez prudemment."
  static SensorSnapshot narrowPassage() {
    return SensorSnapshot(
      distanceFront: 4.0,
      distanceLeft: 0.6,  // Très proche à gauche
      distanceRight: 0.7, // Très proche à droite
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 8: Obstacle uniquement à gauche
  /// Attendu: "Obstacle proche sur votre gauche."
  static SensorSnapshot obstacleLeft() {
    return SensorSnapshot(
      distanceFront: 5.0,
      distanceLeft: 0.5, // Très proche à gauche
      distanceRight: 3.0,
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 9: Obstacle uniquement à droite
  /// Attendu: "Obstacle proche sur votre droite."
  static SensorSnapshot obstacleRight() {
    return SensorSnapshot(
      distanceFront: 5.0,
      distanceLeft: 3.0,
      distanceRight: 0.6, // Très proche à droite
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 10: Situation complexe (obstacle + eau)
  /// Attendu: La règle de priorité maximale (eau) devrait être appliquée
  static SensorSnapshot complexScenario() {
    return SensorSnapshot(
      distanceFront: 1.2,
      distanceLeft: 2.0,
      distanceRight: 2.0,
      obstacleHigh: false,
      waterDetected: true, // Priorité 90
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// SCÉNARIO 11: Obstacle coincé (aucune issue)
  /// Attendu: "Obstacle très proche. Arrêtez-vous."
  static SensorSnapshot trapped() {
    return SensorSnapshot(
      distanceFront: 0.5, // Très proche devant
      distanceLeft: 0.4,  // Pas d'issue à gauche
      distanceRight: 0.4, // Pas d'issue à droite
      obstacleHigh: false,
      waterDetected: false,
      yaw: 0.0,
      pitch: 0.0,
      roll: 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Génère une séquence de snapshots simulant un parcours
  /// Utile pour tester la navigation complète
  static List<SensorSnapshot> navigationSequence() {
    return [
      baseline(),                  // 1. Départ, tout va bien
      obstacleFrontMedium(),       // 2. Obstacle détecté à distance
      wrongOrientationSlight(),    // 3. Correction de trajectoire
      baseline(),                  // 4. Retour à la normale
      obstacleLeft(),              // 5. Attention côté gauche
      narrowPassage(),             // 6. Passage étroit
      baseline(),                  // 7. Tout va bien
      waterDetected(),             // 8. Eau détectée
      baseline(),                  // 9. Fin du parcours
    ];
  }

  /// Génère une séquence d'urgence avec priorités multiples
  static List<SensorSnapshot> emergencySequence() {
    return [
      baseline(),
      obstacleFrontClose(),
      obstacleHigh(),       // Priorité maximale
      waterDetected(),
      trapped(),            // Situation critique
    ];
  }
}