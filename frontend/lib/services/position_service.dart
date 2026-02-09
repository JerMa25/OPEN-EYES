// lib/services/position_service.dart
import 'package:flutter/foundation.dart';
import '../model/destination.dart';
import '../model/position.dart';
import '../config.dart';
import 'api_client.dart';

/// Service pour gérer les positions et destinations
class PositionService {
  final ApiClient _api = ApiClient();

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 LIEUX FRÉQUENTÉS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère les lieux les plus fréquentés par la canne
  /// GET /api/positions/{canne_id}/positions/frequents/
  Future<List<Destination>> fetchLieuxFrequents({required int canneId}) async {
    _log('📡 Fetching frequent places for canne $canneId');

    final response = await _api.get('/api/positions/$canneId/positions/frequents/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} places');
      return jsonList.map((json) => Destination.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération lieux fréquentés');
  }

  /// Récupère toutes les destinations
  /// GET /api/positions/{canne_id}/positions/
  Future<List<Destination>> fetchAllDestinations({required int canneId}) async {
    _log('📡 Fetching all destinations for canne $canneId');

    final response = await _api.get('/api/positions/$canneId/positions/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} destinations');
      return jsonList.map((json) => Destination.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération destinations');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 POSITION ACTUELLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère la position actuelle de la canne
  /// GET /api/positions/{canne_id}/positions/current/
  Future<CannePosition?> fetchCurrentPosition({required int canneId}) async {
    _log('📡 Fetching current position for canne $canneId');

    try {
      final response = await _api.get('/api/positions/$canneId/positions/current/');

      if (response.statusCode == 200 && response.data != null) {
        _log('✅ Position received');
        return CannePosition.fromJson(response.data);
      }
    } catch (e) {
      _log('⚠️ No current position available: $e');
    }

    return null;
  }

  /// Récupère l'historique des positions
  /// GET /api/positions/{canne_id}/positions/history/
  Future<List<CannePosition>> fetchPositionHistory({
    required int canneId,
    int? limit,
  }) async {
    _log('📡 Fetching position history for canne $canneId');

    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;

    final response = await _api.get(
      '/api/positions/$canneId/positions/history/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} positions');
      return jsonList.map((json) => CannePosition.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération historique positions');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 MISE À JOUR POSITION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crée ou met à jour la position de la canne
  /// POST /api/positions/position-update/{canne_id}/{lieu}/positions/update/
  Future<Destination> updatePosition({
    required int canneId,
    required String lieu,
    double? latitude,
    double? longitude,
  }) async {
    _log('📡 Updating position: $lieu');

    final data = <String, dynamic>{'lieu': lieu};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    final response = await _api.post(
      '/api/positions/position-update/$canneId/$lieu/positions/update/',
      data: data,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('✅ Position updated');
      return Destination.fromJson(response.data);
    }

    throw Exception('Erreur mise à jour position');
  }

  /// Envoie une nouvelle position GPS
  /// POST /api/positions/{canne_id}/positions/
  Future<CannePosition> sendPosition({
    required int canneId,
    required double latitude,
    required double longitude,
    String? lieu,
  }) async {
    _log('📡 Sending position: $latitude, $longitude');

    final data = {
      'canne': canneId,
      'latitude': latitude,
      'longitude': longitude,
      if (lieu != null) 'lieu': lieu,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await _api.post(
      '/api/positions/$canneId/positions/',
      data: data,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('✅ Position sent');
      return CannePosition.fromJson(response.data);
    }

    throw Exception('Erreur envoi position');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 UTILITAIRES
  // ═══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('[PositionService] $message');
    }
  }
}
