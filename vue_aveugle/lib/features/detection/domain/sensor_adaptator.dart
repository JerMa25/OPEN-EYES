// lib/features/detection/domain/sensor_state_adapter.dart

import '../pipeline/sensor_state.dart';
import '../../navigation/route_navigator.dart';
import 'sensor_snapshot.dart';

/// ADAPTATEUR : Convertit SensorState + RouteNavigator → SensorSnapshot COMPLET
/// 
/// Votre pipeline produit un SensorState (capteurs filtrés).
/// Le RouteNavigator fournit le contexte GPS.
/// Cet adaptateur combine les deux en UN snapshot complet pour le système expert.
/// 
/// Flux :
/// SensorState (capteurs) + RouteNavigator (GPS) 
///           ↓
///   SensorSnapshot COMPLET
///           ↓
///   Système Expert (décision unique)
class SensorStateAdapter {
  /// Convertit SensorState + RouteNavigator en SensorSnapshot COMPLET
  /// 
  /// Le snapshot résultant contient TOUT ce dont le système expert a besoin :
  /// - Obstacles locaux
  /// - Orientation actuelle
  /// - Contexte GPS de destination
  static SensorSnapshot toSnapshot(
    SensorState state,
    RouteNavigator? routeNavigator,
  ) {
    return SensorSnapshot(
      // ===== DONNÉES CAPTEURS LOCAUX =====
      distanceFront: _extractFrontDistance(state),
      distanceLeft: _extractLeftDistance(state),
      distanceRight: _extractRightDistance(state),
      obstacleHigh: _detectHighObstacle(state),
      waterDetected: state.latestPacket.waterSensor.isDangerous || 
                     state.latestPacket.waterSensor.isSubmerged,
      
      // ===== ORIENTATION ACTUELLE =====
      yaw: state.imu.yaw,
      pitch: state.imu.pitch,
      roll: state.imu.roll,
      
      // ===== TIMESTAMP =====
      timestamp: state.latestPacket.timestamp,
      
      // ===== CONTEXTE GPS (si disponible) =====
      targetBearing: routeNavigator?.targetBearing,
      distanceToDestination: routeNavigator?.distanceToDestination,
      destinationName: routeNavigator?.destinationName,
      distanceToNextWaypoint: routeNavigator?.distanceToCurrentWaypoint,
      nextWaypointName: routeNavigator?.currentWaypoint?.name,
    );
  }

  // ========== EXTRACTION DONNÉES CAPTEURS ==========

  /// Extrait la distance frontale depuis le SensorState
  /// 
  /// Votre système a :
  /// - upper : capteur fixe en hauteur
  /// - lower : capteur rotatif au sol avec angle servo
  /// 
  /// Pour le système expert, on considère :
  /// - distanceFront = distance du capteur pointant vers l'avant
  static double _extractFrontDistance(SensorState state) {
    final obstacles = state.obstacles;
    
    // Si le servo est proche de 0° (centre), on utilise lower
    final servoAngle = obstacles.servoAngle ?? 0.0;
    
    if (servoAngle.abs() <= 30.0) {
      // Servo pointe vers l'avant (±30°)
      return obstacles.lower ?? 10.0;
    }
    
    // Sinon, on utilise upper comme référence avant
    return obstacles.upper ?? 10.0;
  }

  /// Extrait la distance gauche
  /// 
  /// Le capteur lower scanne de -90° à +90°.
  /// On considère "gauche" quand servo est entre -90° et -30°
  static double _extractLeftDistance(SensorState state) {
    final obstacles = state.obstacles;
    final servoAngle = obstacles.servoAngle ?? 0.0;
    
    // Si le servo pointe vers la gauche (-90° à -30°)
    if (servoAngle < -30.0 && servoAngle >= -90.0) {
      return obstacles.lower ?? 10.0;
    }
    
    // Sinon, pas de mesure latérale gauche directe
    // On retourne une distance sûre par défaut
    return 10.0;
  }

  /// Extrait la distance droite
  /// 
  /// On considère "droite" quand servo est entre +30° et +90°
  static double _extractRightDistance(SensorState state) {
    final obstacles = state.obstacles;
    final servoAngle = obstacles.servoAngle ?? 0.0;
    
    // Si le servo pointe vers la droite (+30° à +90°)
    if (servoAngle > 30.0 && servoAngle <= 90.0) {
      return obstacles.lower ?? 10.0;
    }
    
    // Sinon, distance sûre par défaut
    return 10.0;
  }

  /// Détecte un obstacle en hauteur (niveau tête/visage)
  /// 
  /// Le capteur 'upper' est fixe en hauteur → parfait pour ça
  static bool _detectHighObstacle(SensorState state) {
    final obstacles = state.obstacles;
    
    // Si upper détecte quelque chose à moins de 1.5m
    // C'est un obstacle en hauteur dangereux
    if (obstacles.upper != null && obstacles.upper! < 1.5) {
      return true;
    }
    
    // Alternative : utiliser le flag de danger immédiat
    if (obstacles.hasImmediateDanger) {
      // Vérifier si c'est le capteur upper qui déclenche
      return obstacles.criticalSensor == 'upper';
    }
    
    return false;
  }

  // ========== VERSION AMÉLIORÉE AVEC ANALYSES ==========

  /// Version améliorée utilisant les analyses du SensorState
  /// 
  /// Cette version tire profit des calculs déjà faits par SensorState
  /// (danger score, approach speed, etc.)
  static SensorSnapshot toSnapshotEnhanced(
    SensorState state,
    RouteNavigator? routeNavigator,
  ) {
    final baseSnapshot = toSnapshot(state, routeNavigator);
    
    // Si le SensorState détecte une approche rapide d'obstacle,
    // on peut réduire artificiellement les distances pour forcer
    // une réaction plus précoce du système expert
    if (state.isApproachingObstacle && state.approachSpeed != null) {
      final speed = state.approachSpeed!;
      
      // Facteur de correction : plus on approche vite, plus on réduit
      // la distance perçue pour déclencher les alertes plus tôt
      final correctionFactor = 1.0 - (speed * 0.2).clamp(0.0, 0.3);
      
      return SensorSnapshot(
        distanceFront: baseSnapshot.distanceFront * correctionFactor,
        distanceLeft: baseSnapshot.distanceLeft * correctionFactor,
        distanceRight: baseSnapshot.distanceRight * correctionFactor,
        obstacleHigh: baseSnapshot.obstacleHigh,
        waterDetected: baseSnapshot.waterDetected,
        yaw: baseSnapshot.yaw,
        pitch: baseSnapshot.pitch,
        roll: baseSnapshot.roll,
        timestamp: baseSnapshot.timestamp,
        targetBearing: baseSnapshot.targetBearing,
        distanceToDestination: baseSnapshot.distanceToDestination,
        destinationName: baseSnapshot.destinationName,
        distanceToNextWaypoint: baseSnapshot.distanceToNextWaypoint,
        nextWaypointName: baseSnapshot.nextWaypointName,
      );
    }
    
    return baseSnapshot;
  }

  // ========== VALIDATION ==========

  /// Validation du SensorState avant conversion
  /// 
  /// Le pipeline valide déjà, mais double vérification ne fait pas de mal
  static bool isValidState(SensorState state) {
    // Vérifier que les données ne sont pas trop anciennes
    if (!state.isFresh) {
      return false;
    }
    
    // Vérifier que l'IMU a des valeurs valides
    if (state.imu.yaw.isNaN || state.imu.pitch.isNaN || state.imu.roll.isNaN) {
      return false;
    }
    
    return true;
  }

  /// Diagnostique pourquoi un état serait invalide
  /// Utile pour le débogage
  static String? diagnoseInvalidState(SensorState state) {
    if (!state.isFresh) {
      return 'Données périmées (âge: ${state.dataAge}ms)';
    }
    
    if (state.imu.yaw.isNaN) {
      return 'Yaw IMU invalide (NaN)';
    }
    
    if (state.imu.pitch.isNaN) {
      return 'Pitch IMU invalide (NaN)';
    }
    
    if (state.imu.roll.isNaN) {
      return 'Roll IMU invalide (NaN)';
    }
    
    return null; // Tout est OK
  }

  /// Convertit une liste de SensorState en liste de SensorSnapshot
  static List<SensorSnapshot> toSnapshotList(
    List<SensorState> states,
    RouteNavigator? routeNavigator,
  ) {
    return states
        .where((state) => isValidState(state))
        .map((state) => toSnapshot(state, routeNavigator))
        .toList();
  }
}