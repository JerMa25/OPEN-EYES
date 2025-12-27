// lib/features/navigation/route_navigator.dart

import 'dart:math' as math;
import '../detection/models/gps_data.dart';
import 'models/destination.dart';

/// Gestionnaire de navigation GPS (PASSIF - ne décide pas)
/// 
/// Ce module calcule les informations GPS nécessaires à la décision,
/// mais NE PREND AUCUNE DÉCISION. Il fournit simplement le contexte
/// GPS qui sera injecté dans le SensorSnapshot pour le système expert.
/// 
/// Responsabilités :
/// - Charger une destination
/// - Suivre la position GPS actuelle
/// - Calculer cap à suivre (bearing)
/// - Calculer distances
/// - Détecter waypoints atteints
/// 
/// Ce qu'il NE fait PAS :
/// - Générer des instructions vocales (système expert)
/// - Décider des actions (système expert)
/// - Gérer les obstacles (système expert)
class RouteNavigator {
  /// Destination actuelle
  Destination? _currentDestination;
  
  /// Index du waypoint actuellement visé
  int _currentWaypointIndex = 0;
  
  /// Seuil de proximité pour considérer un waypoint atteint (mètres)
  final double waypointReachedThreshold;
  
  /// Position GPS actuelle de l'utilisateur
  GpsData? _currentPosition;
  
  /// Callback appelé quand un waypoint est atteint
  Function(Waypoint)? onWaypointReached;
  
  /// Callback appelé quand la destination est atteinte
  Function()? onDestinationReached;

  RouteNavigator({
    this.waypointReachedThreshold = 10.0, // 10 mètres par défaut
    this.onWaypointReached,
    this.onDestinationReached,
  });

  /// Charge une nouvelle destination
  void loadDestination(Destination destination) {
    if (!destination.isValid) {
      throw ArgumentError('Destination invalide : ${destination.toString()}');
    }
    
    _currentDestination = destination;
    _currentWaypointIndex = 0;
    
    print('📍 Destination chargée : ${destination.name}');
    print('   Waypoints : ${destination.waypoints.length}');
    print('   Distance totale : ${destination.totalDistanceMeters?.toStringAsFixed(0) ?? "?"}m');
  }

  /// Charge une destination depuis un JSON
  void loadDestinationFromJson(Map<String, dynamic> json) {
    final destination = Destination.fromJson(json);
    loadDestination(destination);
  }

  /// Met à jour la position GPS actuelle
  void updatePosition(GpsData gpsData) {
    _currentPosition = gpsData;
    
    if (_currentDestination != null && gpsData.hasValidFix) {
      _checkWaypointReached();
    }
  }

  /// Vérifie si le waypoint actuel est atteint
  void _checkWaypointReached() {
    if (_currentDestination == null || _currentPosition == null) return;
    if (_currentWaypointIndex >= _currentDestination!.waypoints.length) return;

    final currentWaypoint = _currentDestination!.waypoints[_currentWaypointIndex];
    final distance = _calculateDistance(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
      currentWaypoint.latitude,
      currentWaypoint.longitude,
    );

    if (distance <= waypointReachedThreshold) {
      print('✅ Waypoint atteint : ${currentWaypoint.name ?? "Point $_currentWaypointIndex"}');
      
      // Callback
      onWaypointReached?.call(currentWaypoint);
      
      // Passer au waypoint suivant
      _currentWaypointIndex++;
      
      // Vérifier si c'était le dernier waypoint
      if (_currentWaypointIndex >= _currentDestination!.waypoints.length) {
        print('🎯 DESTINATION ATTEINTE : ${_currentDestination!.name}');
        onDestinationReached?.call();
      }
    }
  }

  // ========== GETTERS PUBLICS (pour injection dans SensorSnapshot) ==========

  /// Cap à suivre (bearing) vers le waypoint actuel (0-360°)
  /// Retourne null si pas de destination ou pas de GPS
  double? get targetBearing {
    if (_currentDestination == null || _currentPosition == null) return null;
    if (_currentWaypointIndex >= _currentDestination!.waypoints.length) return null;
    if (!_currentPosition!.hasValidFix) return null;

    final waypoint = _currentDestination!.waypoints[_currentWaypointIndex];
    
    return _calculateBearing(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
      waypoint.latitude,
      waypoint.longitude,
    );
  }

  /// Distance restante jusqu'au waypoint actuel (mètres)
  double? get distanceToCurrentWaypoint {
    if (_currentDestination == null || _currentPosition == null) return null;
    if (_currentWaypointIndex >= _currentDestination!.waypoints.length) return null;
    if (!_currentPosition!.hasValidFix) return null;

    final waypoint = _currentDestination!.waypoints[_currentWaypointIndex];
    
    return _calculateDistance(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
      waypoint.latitude,
      waypoint.longitude,
    );
  }

  /// Distance totale restante jusqu'à la destination finale (mètres)
  double? get distanceToDestination {
    if (_currentDestination == null || _currentPosition == null) return null;
    if (_currentWaypointIndex >= _currentDestination!.waypoints.length) return 0.0;
    if (!_currentPosition!.hasValidFix) return null;

    double total = 0.0;
    
    // Distance jusqu'au waypoint actuel
    final distToCurrent = distanceToCurrentWaypoint;
    if (distToCurrent != null) {
      total += distToCurrent;
    }
    
    // Distance entre les waypoints restants
    for (int i = _currentWaypointIndex; i < _currentDestination!.waypoints.length - 1; i++) {
      final w1 = _currentDestination!.waypoints[i];
      final w2 = _currentDestination!.waypoints[i + 1];
      total += _calculateDistance(w1.latitude, w1.longitude, w2.latitude, w2.longitude);
    }
    
    return total;
  }

  /// Waypoint actuel (celui qu'on vise maintenant)
  Waypoint? get currentWaypoint {
    if (_currentDestination == null) return null;
    if (_currentWaypointIndex >= _currentDestination!.waypoints.length) return null;
    return _currentDestination!.waypoints[_currentWaypointIndex];
  }

  /// Nom de la destination finale
  String? get destinationName => _currentDestination?.name;

  /// Est-ce qu'on a atteint la destination finale ?
  bool get hasReachedDestination {
    if (_currentDestination == null) return false;
    return _currentWaypointIndex >= _currentDestination!.waypoints.length;
  }

  /// Est-ce qu'une destination est chargée et active ?
  bool get hasActiveDestination {
    return _currentDestination != null && !hasReachedDestination;
  }

  /// Progression de l'itinéraire (0.0 à 1.0)
  double get progress {
    if (_currentDestination == null) return 0.0;
    if (_currentDestination!.waypoints.isEmpty) return 0.0;
    return _currentWaypointIndex / _currentDestination!.waypoints.length;
  }

  /// Réinitialise la navigation
  void reset() {
    _currentDestination = null;
    _currentWaypointIndex = 0;
    _currentPosition = null;
  }

  // ========== CALCULS GÉOGRAPHIQUES ==========

  /// Calcule la distance entre deux points GPS (formule Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0; // Rayon de la Terre en mètres
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c;
  }

  /// Calcule le cap (bearing) entre deux points GPS
  double _calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _degreesToRadians(lon2 - lon1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);
    
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    final bearing = math.atan2(y, x);
    
    // Convertir en degrés (0-360)
    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  /// Statistiques pour debug
  Map<String, dynamic> getStatistics() {
    return {
      'hasActiveDestination': hasActiveDestination,
      'hasReachedDestination': hasReachedDestination,
      'currentWaypointIndex': _currentWaypointIndex,
      'totalWaypoints': _currentDestination?.waypoints.length ?? 0,
      'progress': progress,
      'distanceToWaypoint': distanceToCurrentWaypoint,
      'distanceToDestination': distanceToDestination,
      'targetBearing': targetBearing,
      'destinationName': destinationName,
      'currentWaypointName': currentWaypoint?.name,
    };
  }
}