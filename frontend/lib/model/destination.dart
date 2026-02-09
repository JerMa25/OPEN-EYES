class Destination {
  final int? id;
  final String lieu;
  final int nombreDeVisites;
  final double? latitude;
  final double? longitude;
  final DateTime? derniereVisite;

  Destination({
    this.id,
    required this.lieu,
    required this.nombreDeVisites,
    this.latitude,
    this.longitude,
    this.derniereVisite,
  });

  /// Crée une Destination depuis une Map JSON
  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as int?,
      lieu: json['lieu']?.toString() ?? 'Lieu inconnu',
      nombreDeVisites: _parseToInt(json['nombre_de_visites']),
      latitude: _parseToDouble(json['latitude']),
      longitude: _parseToDouble(json['longitude']),
      derniereVisite: json['derniere_visite'] != null
          ? DateTime.tryParse(json['derniere_visite'].toString())
          : null,
    );
  }

  /// Convertit en Map JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'lieu': lieu,
      'nombre_de_visites': nombreDeVisites,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Crée une copie modifiée
  Destination copyWith({
    int? id,
    String? lieu,
    int? nombreDeVisites,
    double? latitude,
    double? longitude,
    DateTime? derniereVisite,
  }) {
    return Destination(
      id: id ?? this.id,
      lieu: lieu ?? this.lieu,
      nombreDeVisites: nombreDeVisites ?? this.nombreDeVisites,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      derniereVisite: derniereVisite ?? this.derniereVisite,
    );
  }

  /// Vérifie si la destination a des coordonnées GPS
  bool get hasCoordinates => latitude != null && longitude != null;

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
    return 'Destination(id: $id, lieu: $lieu, visites: $nombreDeVisites)';
  }
}
