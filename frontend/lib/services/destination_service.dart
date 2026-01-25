import 'dart:convert';
import 'package:frontend/model/destination.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class PositionService {
  static const String baseUrl = AppConfig.baseUrl;

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // 📌 GET – Récupère les lieux les plus fréquentés
  // GET /api/positions/{canne_id}/positions/frequents/
  // ---------------------------------------------------------------------------
  Future<List<Destination>> fetchLieuxFrequents({required int canneId}) async {
    print('📡 DestinationService: Fetching frequent places for $canneId');
    final uri = Uri.parse('$baseUrl/api/positions/$canneId/positions/frequents/');
    print('🔗 DestinationService: URI = $uri');
    
    try {
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ DestinationService: Timeout reached!');
          throw Exception('Délai d\'attente dépassé (Destinations). Vérifiez le serveur.');
        },
      );

      print('📥 DestinationService: Response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        print('✅ DestinationService: Parsed ${jsonList.length} places');
        return jsonList.map((json) => Destination.fromJson(json)).toList();
      } else {
        print('❌ DestinationService: Error ${response.statusCode} - ${response.body}');
        throw Exception('Erreur récupération lieux fréquentés (${response.statusCode})');
      }
    } catch (e) {
      print('❌ DestinationService: Exception - $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 📌 POST – Crée ou met à jour la position de la canne
  // POST /api/positions/position-update/{canne_id}/{lieu}/positions/update/
  // ---------------------------------------------------------------------------
  Future<Destination> updatePosition({
    required int canneId,
    required String lieu,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/positions/position-update/$canneId/$lieu/positions/update/',
    );

    final body = json.encode({'lieu': lieu});

    final response = await http.post(
      uri,
      headers: _headers,
      body: body,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Délai d\'attente dépassé (Update Position). Vérifiez le serveur.');
      },
    );

    if (response.statusCode == 200) {
      return Destination.fromJson(json.decode(response.body));
    } else {
      throw Exception('Erreur mise à jour position (${response.statusCode})');
    }
  }
}