// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Service pour gérer la géolocalisation
/// Utilise le package geolocator pour obtenir la position GPS
class LocationService {
  // Singleton
  static LocationService? _instance;
  factory LocationService() {
    _instance ??= LocationService._internal();
    return _instance!;
  }
  LocationService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔐 PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vérifie et demande les permissions de localisation
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifier si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('❌ Location services are disabled');
      return false;
    }

    // Vérifier les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _log('❌ Location permissions denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log('❌ Location permissions permanently denied');
      return false;
    }

    _log('✅ Location permissions granted');
    return true;
  }

  /// Ouvre les paramètres de localisation
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Ouvre les paramètres de l'application
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 POSITION ACTUELLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtient la position actuelle de l'appareil
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 10, // Minimum 10 mètres entre les mises à jour
        ),
      );

      _log('📍 Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _log('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Obtient la dernière position connue (plus rapide, pas de GPS)
  Future<Position?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _log('📍 Last known position: ${position.latitude}, ${position.longitude}');
      }
      return position;
    } catch (e) {
      _log('⚠️ No last known position: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 SUIVI EN TEMPS RÉEL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de positions en temps réel
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    int intervalDuration = 5000, // millisecondes
  }) {
    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: Duration(milliseconds: intervalDuration),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Écoute les changements de position
  Stream<Position> watchPosition({
    int distanceFilterMeters = 50,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📏 CALCULS DE DISTANCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcule la distance entre deux points en mètres
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calcule le bearing (direction) entre deux points
  double calculateBearing({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🗺️ GÉOCODAGE (Coordonnées <-> Adresse)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convertit des coordonnées en adresse (reverse geocoding)
  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = _formatPlacemark(place);
        _log('📍 Address: $address');
        return address;
      }
    } catch (e) {
      _log('⚠️ Geocoding error: $e');
    }
    return null;
  }

  /// Convertit une adresse en coordonnées (geocoding)
  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        _log('📍 Coordinates: ${location.latitude}, ${location.longitude}');
        return location;
      }
    } catch (e) {
      _log('⚠️ Address lookup error: $e');
    }
    return null;
  }

  /// Formate un Placemark en adresse lisible
  String _formatPlacemark(Placemark place) {
    final parts = <String>[];
    
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.join(', ');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 UTILITAIRES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Formate une distance en texte lisible
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Génère un lien Google Maps
  String getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  /// Génère un lien pour la navigation
  String getNavigationUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
  }

  void _log(String message) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('[LocationService] $message');
    }
  }
}
