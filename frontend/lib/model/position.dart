// lib/model/position.dart

class CannePosition {
  final int? id;
  final int canneId;
  final double latitude;
  final double longitude;
  final String? lieu;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;

  CannePosition({
    this.id,
    required this.canneId,
    required this.latitude,
    required this.longitude,
    this.lieu,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
  });

  /// Crée une CannePosition depuis une Map JSON
  factory CannePosition.fromJson(Map<String, dynamic> json) {
    return CannePosition(
      id: json['id'] as int?,
      canneId: _parseToInt(json['canne'] ?? json['canne_id']),
      latitude: _parseToDouble(json['latitude']) ?? 0.0,
      longitude: _parseToDouble(json['longitude']) ?? 0.0,
      lieu: json['lieu']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      accuracy: _parseToDouble(json['accuracy']),
      altitude: _parseToDouble(json['altitude']),
      speed: _parseToDouble(json['speed']),
    );
  }

  /// Convertit en Map JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'canne': canneId,
      'latitude': latitude,
      'longitude': longitude,
      if (lieu != null) 'lieu': lieu,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
    };
  }

  /// Vérifie si la position est valide
  bool get isValid => latitude != 0.0 && longitude != 0.0;

  /// Coordonnées formatées
  String get coordinatesString => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// Lien Google Maps
  String get googleMapsUrl => 'https://www.google.com/maps?q=$latitude,$longitude';

  /// Helper pour parser en int
  static int _parseToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Helper pour parser en double
  static double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'CannePosition(lat: $latitude, lng: $longitude, lieu: $lieu)';
  }
}
