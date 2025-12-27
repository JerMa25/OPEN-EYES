// lib/features/navigation/timing_controller.dart

import 'dart:async';
import 'dart:math' as math;
import '../detection/domain/sensor_snapshot.dart';

/// Contrôleur de timing et de distance
/// Convertit les distances en pas et déclenche les actions au bon moment
/// 
/// Utilise les données IMU pour :
/// - Calculer la distance parcourue
/// - Détecter les erreurs de trajectoire
/// - Estimer le nombre de pas
class TimingController {
  /// Longueur moyenne d'un pas en mètres
  static const double stepLength = 0.5;
  
  /// Callback appelé quand la distance cible est atteinte
  Function()? _onReachedCallback;
  
  /// Distance cible à parcourir (en mètres)
  double? _targetDistance;
  
  /// Distance parcourue actuellement (en mètres)
  double _currentDistance = 0.0;
  
  /// État du tracking
  bool _isTracking = false;
  bool _isPaused = false;
  
  /// Timer pour vérifications périodiques
  Timer? _checkTimer;
  
  /// Timestamp du dernier update
  int? _lastUpdateTime;

  /// Démarre le suivi de distance
  /// 
  /// [targetDistance] : distance à parcourir en mètres
  /// [onReached] : callback appelé quand la distance est atteinte
  void startTracking({
    required double targetDistance,
    required Function() onReached,
  }) {
    _targetDistance = targetDistance;
    _onReachedCallback = onReached;
    _currentDistance = 0.0;
    _isTracking = true;
    _isPaused = false;
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    
    // Timer de vérification toutes les 100ms
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _checkProgress(),
    );
  }

  /// Met à jour la distance parcourue
  void updateDistance(double distance) {
    if (!_isTracking || _isPaused) return;
    
    _currentDistance = distance;
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Calcule la distance entre deux positions
  /// Utilise les données IMU (yaw, pitch) et la trigonométrie
  double calculateDistance(
    SensorSnapshot from,
    SensorSnapshot to,
  ) {
    // Méthode 1: Estimation basique avec nombre de mesures
    // Dans un vrai système, utiliser l'intégration de l'accélération
    final timeDiff = (to.timestamp - from.timestamp) / 1000.0; // secondes
    
    // Vitesse de marche moyenne : 1.4 m/s
    const averageWalkingSpeed = 1.4;
    
    // Distance = vitesse × temps
    var estimatedDistance = averageWalkingSpeed * timeDiff;
    
    // Correction basée sur l'inclinaison (pitch)
    // Si l'utilisateur est penché, il marche probablement moins vite
    if (to.pitch.abs() > 10.0) {
      estimatedDistance *= 0.8; // Réduction de 20%
    }
    
    // Correction basée sur la rotation (yaw)
    // Si l'utilisateur tourne, la distance réelle est plus courte
    final yawChange = (to.yaw - from.yaw).abs();
    if (yawChange > 15.0) {
      estimatedDistance *= math.cos(yawChange * math.pi / 180);
    }
    
    return estimatedDistance;
  }

  /// Convertit une distance en nombre de pas
  int distanceToSteps(double distanceMeters) {
    return (distanceMeters / stepLength).round();
  }

  /// Convertit un nombre de pas en distance
  double stepsToDistance(int steps) {
    return steps * stepLength;
  }

  /// Retourne le pourcentage de progression (0.0 à 1.0)
  double get progress {
    if (_targetDistance == null || _targetDistance == 0) return 0.0;
    return (_currentDistance / _targetDistance!).clamp(0.0, 1.0);
  }

  /// Retourne la distance restante en mètres
  double get remainingDistance {
    if (_targetDistance == null) return 0.0;
    return math.max(0.0, _targetDistance! - _currentDistance);
  }

  /// Retourne le nombre de pas restants
  int get remainingSteps {
    return distanceToSteps(remainingDistance);
  }

  /// Vérifie périodiquement si la cible est atteinte
  void _checkProgress() {
    if (!_isTracking || _isPaused) return;
    
    if (_targetDistance != null && _currentDistance >= _targetDistance!) {
      // Cible atteinte !
      _isTracking = false;
      _checkTimer?.cancel();
      _onReachedCallback?.call();
    }
    
    // Vérifier le timeout (pas de mise à jour depuis 5 secondes)
    if (_lastUpdateTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastUpdateTime! > 5000) {
        // L'utilisateur s'est probablement arrêté
        // On peut générer un événement ici si nécessaire
      }
    }
  }

  /// Met en pause le tracking
  void pause() {
    _isPaused = true;
  }

  /// Reprend le tracking
  void resume() {
    _isPaused = false;
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Arrête le tracking
  void stop() {
    _isTracking = false;
    _isPaused = false;
    _checkTimer?.cancel();
    _targetDistance = null;
    _currentDistance = 0.0;
    _onReachedCallback = null;
  }

  /// Estime le temps restant en secondes
  /// Basé sur une vitesse de marche moyenne de 1.4 m/s
  double get estimatedTimeRemaining {
    const averageWalkingSpeed = 1.4; // m/s
    return remainingDistance / averageWalkingSpeed;
  }

  /// Retourne true si le tracking est actif
  bool get isTracking => _isTracking && !_isPaused;

  /// Statistiques pour debug
  Map<String, dynamic> getStatistics() {
    return {
      'isTracking': _isTracking,
      'isPaused': _isPaused,
      'targetDistance': _targetDistance,
      'currentDistance': _currentDistance,
      'progress': progress,
      'remainingDistance': remainingDistance,
      'remainingSteps': remainingSteps,
      'estimatedTimeRemaining': estimatedTimeRemaining,
    };
  }

  /// Libère les ressources
  void dispose() {
    _checkTimer?.cancel();
  }
}

/// Classe utilitaire pour les calculs de distance
class DistanceCalculator {
  /// Calcule la distance euclidienne entre deux points 3D
  /// Utilisé pour les capteurs de distance
  static double euclidean3D(
    double x1, double y1, double z1,
    double x2, double y2, double z2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dz = z2 - z1;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Calcule l'angle entre deux orientations (en degrés)
  static double angleDifference(double angle1, double angle2) {
    var diff = (angle2 - angle1).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }

  /// Normalise un angle entre -180 et 180 degrés
  static double normalizeAngle(double angle) {
    var normalized = angle % 360;
    if (normalized > 180) {
      normalized -= 360;
    } else if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  /// Calcule la vitesse entre deux snapshots (m/s)
  static double calculateSpeed(
    SensorSnapshot from,
    SensorSnapshot to,
    double distanceTraveled,
  ) {
    final timeDiff = (to.timestamp - from.timestamp) / 1000.0; // secondes
    if (timeDiff == 0) return 0.0;
    return distanceTraveled / timeDiff;
  }
}