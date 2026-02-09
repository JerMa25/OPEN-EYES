// lib/services/sms_service.dart

import '../model/sms_message.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'api_client.dart';

/// Service pour gérer les messages SMS
class SmsService {
  final ApiClient _api = ApiClient();

  // ═══════════════════════════════════════════════════════════════════════════
  // 📨 HISTORIQUE DES MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère l'historique des SMS d'une canne
  /// GET /api/sms/canes/{canne_id}/history/
  Future<List<SmsMessage>> fetchSmsHistory({required int canneId}) async {
    _log('📡 Fetching SMS history for canne $canneId');

    final response = await _api.get('/api/sms/canes/$canneId/history/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} messages');
      return jsonList.map((json) => SmsMessage.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération historique SMS');
  }

  /// Récupère les SMS par type
  /// GET /api/sms/canes/{canne_id}/history/?type={type}
  Future<List<SmsMessage>> fetchSmsByType({
    required int canneId,
    required String type,
  }) async {
    _log('📡 Fetching SMS by type: $type');

    final response = await _api.get(
      '/api/sms/canes/$canneId/history/',
      queryParameters: {'type': type},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} messages of type $type');
      return jsonList.map((json) => SmsMessage.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération SMS par type');
  }

  /// Récupère les alertes non lues
  /// GET /api/sms/canes/{canne_id}/alerts/
  Future<List<SmsMessage>> fetchAlerts({required int canneId}) async {
    _log('📡 Fetching alerts for canne $canneId');

    final response = await _api.get('/api/sms/canes/$canneId/alerts/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} alerts');
      return jsonList.map((json) => SmsMessage.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération alertes');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📤 ENVOI DE MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envoie une commande à la canne
  /// POST /api/sms/canes/{canne_id}/send/
  Future<SmsMessage> sendCommand({
    required int canneId,
    required String contenu,
    int? envoyePar,
  }) async {
    _log('📡 Sending command to canne $canneId');

    final data = {
      'type_message': SmsMessage.typeCommande,
      'contenu': contenu,
      if (envoyePar != null) 'envoye_par': envoyePar,
    };

    final response = await _api.post(
      '/api/sms/canes/$canneId/send/',
      data: data,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('✅ Command sent');
      return SmsMessage.fromJson(response.data);
    }

    throw Exception('Erreur envoi commande');
  }

  /// Envoie une notification
  /// POST /api/sms/canes/{canne_id}/send/
  Future<SmsMessage> sendNotification({
    required int canneId,
    required String contenu,
    int? envoyePar,
  }) async {
    _log('📡 Sending notification to canne $canneId');

    final data = {
      'type_message': SmsMessage.typeNotification,
      'contenu': contenu,
      if (envoyePar != null) 'envoye_par': envoyePar,
    };

    final response = await _api.post(
      '/api/sms/canes/$canneId/send/',
      data: data,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _log('✅ Notification sent');
      return SmsMessage.fromJson(response.data);
    }

    throw Exception('Erreur envoi notification');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 STATISTIQUES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère les statistiques des messages
  /// GET /api/sms/canes/{canne_id}/stats/
  Future<Map<String, dynamic>> fetchStats({required int canneId}) async {
    _log('📡 Fetching SMS stats for canne $canneId');

    final response = await _api.get('/api/sms/canes/$canneId/stats/');

    if (response.statusCode == 200) {
      _log('✅ Stats received');
      return response.data as Map<String, dynamic>;
    }

    throw Exception('Erreur récupération statistiques');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 UTILITAIRES
  // ═══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('[SmsService] $message');
    }
  }
}
