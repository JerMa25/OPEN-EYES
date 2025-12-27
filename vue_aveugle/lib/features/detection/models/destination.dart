// lib/features/navigation/models/destination.dart

/// Point de cheminement (waypoint) dans un itinéraire
class Waypoint {
  /// Latitude du point (degrés décimaux)
  final double latitude;
  
  /// Longitude du point (degrés décimaux)
  final double longitude;
  
  /// Nom optionnel du waypoint (affiché dans les messages)
  final String? name;
  
  /// Instruction vocale spécifique à annoncer en arrivant à ce point
  /// Ex: "Tournez à droite dans la rue Victor Hugo"
  final String? instruction;
  
  /// Type de waypoint (départ, intermédiaire, arrivée)
  final WaypointType type;

  const Waypoint({
    required this.latitude,
    required this.longitude,
    this.name,
    this.instruction,
    this.type = WaypointType.intermediate,
  });

  /// Crée un waypoint depuis un JSON
  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String?,
      instruction: json['instruction'] as String?,
      type: WaypointType.fromString(json['type'] as String?),
    );
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null) 'name': name,
      if (instruction != null) 'instruction': instruction,
      'type': type.toString().split('.').last,
    };
  }

  @override
  String toString() {
    return 'Waypoint(lat: $latitude, lon: $longitude, name: ${name ?? "sans nom"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Waypoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Type de waypoint
enum WaypointType {
  /// Point de départ
  start,
  
  /// Point intermédiaire
  intermediate,
  
  /// Point d'arrivée (destination finale)
  destination,
}

extension WaypointTypeExtension on WaypointType {
  static WaypointType fromString(String? str) {
    switch (str?.toLowerCase()) {
      case 'start':
      case 'depart':
        return WaypointType.start;
      case 'destination':
      case 'arrivee':
      case 'end':
        return WaypointType.destination;
      default:
        return WaypointType.intermediate;
    }
  }
}

/// Destination complète avec itinéraire
/// 
/// Cette classe représente une destination fournie par un module externe
/// Elle contient tous les waypoints à suivre pour atteindre la destination
class Destination {
  /// Nom de la destination finale
  final String name;
  
  /// Liste ordonnée des waypoints à suivre
  final List<Waypoint> waypoints;
  
  /// Distance totale estimée en mètres
  /// Calculée automatiquement si non fournie
  final double? totalDistanceMeters;
  
  /// Temps estimé en secondes
  final int? estimatedTimeSeconds;
  
  /// Type de transport (marche, vélo, etc.)
  final TransportMode transportMode;
  
  /// Métadonnées additionnelles (optionnel)
  final Map<String, dynamic>? metadata;

  const Destination({
    required this.name,
    required this.waypoints,
    this.totalDistanceMeters,
    this.estimatedTimeSeconds,
    this.transportMode = TransportMode.walking,
    this.metadata,
  });

  /// Crée une destination depuis un JSON
  /// 
  /// Format attendu :
  /// ```json
  /// {
  ///   "name": "Pharmacie du Centre",
  ///   "totalDistanceMeters": 450,
  ///   "estimatedTimeSeconds": 360,
  ///   "transportMode": "walking",
  ///   "waypoints": [
  ///     {
  ///       "latitude": 48.8566,
  ///       "longitude": 2.3522,
  ///       "name": "Départ",
  ///       "type": "start"
  ///     },
  ///     {
  ///       "latitude": 48.8570,
  ///       "longitude": 2.3525,
  ///       "name": "Intersection rue Victor Hugo",
  ///       "instruction": "Tournez à droite dans la rue Victor Hugo"
  ///     },
  ///     {
  ///       "latitude": 48.8575,
  ///       "longitude": 2.3530,
  ///       "name": "Pharmacie du Centre",
  ///       "type": "destination"
  ///     }
  ///   ]
  /// }
  /// ```
  factory Destination.fromJson(Map<String, dynamic> json) {
    // Parser les waypoints
    final waypointsJson = json['waypoints'] as List?;
    if (waypointsJson == null || waypointsJson.isEmpty) {
      throw ArgumentError('Destination invalide : waypoints manquants ou vides');
    }
    
    final waypoints = waypointsJson
        .map((w) => Waypoint.fromJson(w as Map<String, dynamic>))
        .toList();
    
    // Valider : au moins 2 waypoints (départ + arrivée)
    if (waypoints.length < 2) {
      throw ArgumentError('Destination invalide : minimum 2 waypoints requis');
    }
    
    return Destination(
      name: json['name'] as String? ?? 'Destination',
      waypoints: waypoints,
      totalDistanceMeters: (json['totalDistanceMeters'] as num?)?.toDouble(),
      estimatedTimeSeconds: json['estimatedTimeSeconds'] as int?,
      transportMode: TransportMode.fromString(json['transportMode'] as String?),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      if (totalDistanceMeters != null) 'totalDistanceMeters': totalDistanceMeters,
      if (estimatedTimeSeconds != null) 'estimatedTimeSeconds': estimatedTimeSeconds,
      'transportMode': transportMode.toString().split('.').last,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Point de départ (premier waypoint)
  Waypoint get startPoint => waypoints.first;

  /// Point d'arrivée (dernier waypoint)
  Waypoint get endPoint => waypoints.last;

  /// Nombre de waypoints intermédiaires (sans départ ni arrivée)
  int get intermediateWaypointsCount => waypoints.length - 2;

  /// Vérifie si la destination est valide
  bool get isValid {
    return waypoints.length >= 2 && name.isNotEmpty;
  }

  @override
  String toString() {
    return 'Destination('
        'name: $name, '
        'waypoints: ${waypoints.length}, '
        'distance: ${totalDistanceMeters?.toStringAsFixed(0) ?? "?"}m)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Destination &&
        other.name == name &&
        other.waypoints.length == waypoints.length;
  }

  @override
  int get hashCode => Object.hash(name, waypoints.length);
}

/// Mode de transport
enum TransportMode {
  /// À pied (par défaut)
  walking,
  
  /// Vélo
  cycling,
  
  /// Transport en commun
  transit,
  
  /// Voiture
  driving,
}

extension TransportModeExtension on TransportMode {
  static TransportMode fromString(String? str) {
    switch (str?.toLowerCase()) {
      case 'walking':
      case 'marche':
      case 'pied':
        return TransportMode.walking;
      case 'cycling':
      case 'bike':
      case 'velo':
        return TransportMode.cycling;
      case 'transit':
      case 'bus':
      case 'metro':
        return TransportMode.transit;
      case 'driving':
      case 'car':
      case 'voiture':
        return TransportMode.driving;
      default:
        return TransportMode.walking;
    }
  }

  /// Vitesse moyenne en m/s selon le mode
  double get averageSpeed {
    switch (this) {
      case TransportMode.walking:
        return 1.4; // 1.4 m/s = 5 km/h
      case TransportMode.cycling:
        return 4.2; // 4.2 m/s = 15 km/h
      case TransportMode.transit:
        return 8.3; // 8.3 m/s = 30 km/h
      case TransportMode.driving:
        return 13.9; // 13.9 m/s = 50 km/h
    }
  }
}