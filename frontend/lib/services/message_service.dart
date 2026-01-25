import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/message.dart';
import '../config.dart';

class SmsService {
  static const String baseUrl = AppConfig.baseUrl;

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // 📌 GET – Récupère l'historique des SMS d'une canne
  // GET /api/sms/canes/{canne_id}/history/
  // ---------------------------------------------------------------------------
  Future<List<SmsMessage>> fetchSmsHistory({required int canneId}) async {
    final uri = Uri.parse('$baseUrl/api/sms/canes/$canneId/history/');
    
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => SmsMessage.fromJson(json)).toList();
    } else {
      throw Exception('Erreur récupération historique SMS (${response.statusCode})');
    }
  }
}