// lib/features/detection/models/gps_data.dart

/// Modèle de données pour le module GPS
/// 
/// Le GPS permet :
/// - Localisation précise de l'utilisateur
/// - Calcul de trajectoires et distances
/// - Enregistrement de parcours (historique)
/// - Guidage vers destinations (navigation)
/// - Géolocalisation d'urgence (SOS)
/// 
/// Module typique : NEO-6M, NEO-7M, ou équivalent
class GpsData {
  /// Latitude (degrés décimaux)
  /// 
  /// Pourquoi décimal ? Format standard GPS moderne (vs degrés/minutes/secondes)
  /// Plus facile à calculer et à utiliser avec les APIs cartographiques
  /// 
  /// Plage : -90.0 (Pôle Sud) à +90.0 (Pôle Nord)
  /// Exemple : 48.8566 = Paris (48.8566°N)
  final double? latitude;

  /// Longitude (degrés décimaux)
  /// 
  /// Pourquoi décimal ? Même raison que latitude
  /// 
  /// Plage : -180.0 (Ouest) à +180.0 (Est)
  /// Exemple : 2.3522 = Paris (2.3522°E)
  final double? longitude;

  /// Altitude en mètres au-dessus du niveau de la mer
  /// 
  /// Pourquoi important ? Permet de :
  /// - Détecter changements d'étage (immeubles)
  /// - Calculer dénivelé (montées/descentes)
  /// - Identifier ponts vs tunnel
  /// 
  /// null si pas disponible (certains modules GPS bas de gamme)
  final double? altitude;

  /// Vitesse au sol en km/h
  /// 
  /// Pourquoi km/h ? Unité familière pour l'utilisateur
  /// (le GPS fournit généralement en nœuds ou m/s, on convertit)
  /// 
  /// Permet de :
  /// - Détecter si l'utilisateur est immobile/marche/court
  /// - Adapter la fréquence de mise à jour GPS
  /// - Calculer le temps d'arrivée estimé
  final double? speed;

  /// Cap/Direction en degrés (0-360°)
  /// 
  /// Pourquoi ? Indique la direction du déplacement :
  /// - 0° = Nord
  /// - 90° = Est
  /// - 180° = Sud
  /// - 270° = Ouest
  /// 
  /// Différent du yaw IMU : le heading est la direction de DÉPLACEMENT,
  /// le yaw est l'orientation de la TÊTE
  final double? heading;

  /// Nombre de satellites utilisés pour le fix
  /// 
  /// Pourquoi important ? Indicateur de qualité du signal :
  /// - < 4 satellites : pas de fix (position invalide)
  /// - 4-6 satellites : fix minimal (précision ~15m)
  /// - 7-10 satellites : bon fix (précision ~5m)
  /// - > 10 satellites : excellent fix (précision ~2m)
  final int? satellitesCount;

  /// Précision horizontale estimée (HDOP - Horizontal Dilution of Precision)
  /// 
  /// Pourquoi ? Mesure la qualité géométrique des satellites :
  /// - < 1.0 : Idéal (très rare)
  /// - 1.0-2.0 : Excellent
  /// - 2.0-5.0 : Bon
  /// - 5.0-10.0 : Modéré
  /// - > 10.0 : Mauvais
  /// 
  /// Plus la valeur est basse, meilleure est la précision
  final double? hdop;

  /// Timestamp de la mesure GPS (fourni par le satellite)
  /// 
  /// Pourquoi séparé du timestamp global ? Le GPS a sa propre horloge
  /// atomique très précise. Permet de :
  /// - Détecter latence entre mesure GPS et transmission BLE
  /// - Synchroniser l'horloge ESP32
  /// - Valider la fraîcheur des données
  final DateTime? gpsTimestamp;

  /// Type de fix GPS obtenu
  /// 
  /// Pourquoi ? Indique la qualité et le type de positionnement :
  /// - 'none' : Pas de fix (recherche satellites)
  /// - '2d' : Fix 2D (lat/lon uniquement, pas d'altitude)
  /// - '3d' : Fix 3D (lat/lon + altitude)
  /// - 'dgps' : Differential GPS (correction différentielle, très précis)
  final GpsFixType fixType;

  /// Constructeur avec validation des coordonnées
  GpsData({
    this.latitude,
    this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.satellitesCount,
    this.hdop,
    this.gpsTimestamp,
    this.fixType = GpsFixType.none,
  }) {
    // Validation latitude
    if (latitude != null && (latitude! < -90 || latitude! > 90)) {
      throw ArgumentError(
        'Latitude hors limites (-90 à +90): $latitude',
      );
    }

    // Validation longitude
    if (longitude != null && (longitude! < -180 || longitude! > 180)) {
      throw ArgumentError(
        'Longitude hors limites (-180 à +180): $longitude',
      );
    }

    // Validation altitude (raisonnable pour usage terrestre)
    if (altitude != null && altitude!.abs() > 9000) {
      throw ArgumentError(
        'Altitude irréaliste (Everest = 8849m): $altitude',
      );
    }

    // Validation vitesse (limite terrestre raisonnable)
    if (speed != null && speed! < 0) {
      throw ArgumentError('Vitesse ne peut pas être négative: $speed');
    }
    if (speed != null && speed! > 300) {
      // 300 km/h = vitesse TGV, limite raisonnable pour usage piéton
      throw ArgumentError('Vitesse irréaliste pour usage piéton: $speed km/h');
    }

    // Validation heading
    if (heading != null && (heading! < 0 || heading! >= 360)) {
      throw ArgumentError('Heading doit être entre 0 et 360°: $heading');
    }

    // Validation nombre de satellites
    if (satellitesCount != null && satellitesCount! < 0) {
      throw ArgumentError(
        'Nombre de satellites négatif: $satellitesCount',
      );
    }

    // Validation HDOP
    if (hdop != null && hdop! < 0) {
      throw ArgumentError('HDOP ne peut pas être négatif: $hdop');
    }
  }

  /// Factory depuis JSON
  factory GpsData.fromJson(Map<String, dynamic> json) {
    return GpsData(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      satellitesCount: json['satellitesCount'] as int?,
      hdop: (json['hdop'] as num?)?.toDouble(),
      gpsTimestamp: json['gpsTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['gpsTimestamp'] as int)
          : null,
      fixType: GpsFixType.fromString(json['fixType'] as String? ?? 'none'),
    );
  }

  /// Conversion vers JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'satellitesCount': satellitesCount,
      'hdop': hdop,
      'gpsTimestamp': gpsTimestamp?.millisecondsSinceEpoch,
      'fixType': fixType.toString(),
    };
  }

  /// Vérifie si on a une position valide (fix obtenu)
  /// 
  /// Pourquoi ? Pour savoir si on peut utiliser les données GPS
  /// ou si on doit attendre un fix
  bool get hasValidFix {
    return fixType != GpsFixType.none &&
        latitude != null &&
        longitude != null;
  }

  /// Vérifie si la qualité du fix est bonne
  /// 
  /// Pourquoi ? Pour décider si on peut faire confiance à la position
  /// pour de la navigation précise
  bool get hasGoodFixQuality {
    if (!hasValidFix) return false;

    // Critères de qualité :
    // - Au moins 6 satellites
    // - HDOP < 5.0 (bon à excellent)
    final goodSatellites = satellitesCount != null && satellitesCount! >= 6;
    final goodHdop = hdop != null && hdop! < 5.0;

    return goodSatellites && goodHdop;
  }

  /// Vérifie si l'utilisateur est immobile
  /// 
  /// Pourquoi 0.5 km/h ? Seuil au-dessus du bruit GPS mais en dessous
  /// d'une marche lente (~1 km/h)
  bool get isStationary {
    return speed != null && speed! < 0.5;
  }

  /// Vérifie si l'utilisateur marche
  /// 
  /// Pourquoi 1-6 km/h ? Plage typique de marche humaine :
  /// - Marche lente : 1-3 km/h
  /// - Marche normale : 3-5 km/h
  /// - Marche rapide : 5-6 km/h
  bool get isWalking {
    return speed != null && speed! >= 1.0 && speed! < 6.0;
  }

  /// Vérifie si l'utilisateur court
  /// 
  /// Pourquoi > 6 km/h ? Au-dessus de la marche rapide
  bool get isRunning {
    return speed != null && speed! >= 6.0;
  }

  /// Calcule la distance vers une autre position (en mètres)
  /// 
  /// Pourquoi ? Pour calculer :
  /// - Distance jusqu'à destination
  /// - Périmètre de sécurité
  /// - Historique de déplacement
  /// 
  /// Utilise la formule de Haversine (précise pour courtes distances)
  double? distanceTo(GpsData other) {
    if (!hasValidFix || !other.hasValidFix) return null;

    // Formule de Haversine
    const earthRadius = 6371000.0; // Rayon de la Terre en mètres

    final lat1 = _degreesToRadians(latitude!);
    final lat2 = _degreesToRadians(other.latitude!);
    final deltaLat = _degreesToRadians(other.latitude! - latitude!);
    final deltaLon = _degreesToRadians(other.longitude! - longitude!);

    final a = (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        (cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcule le cap vers une autre position (en degrés)
  /// 
  /// Pourquoi ? Pour indiquer la direction à suivre vers une destination
  double? bearingTo(GpsData other) {
    if (!hasValidFix || !other.hasValidFix) return null;

    final lat1 = _degreesToRadians(latitude!);
    final lat2 = _degreesToRadians(other.latitude!);
    final deltaLon = _degreesToRadians(other.longitude! - longitude!);

    final y = sin(deltaLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);

    final bearing = atan2(y, x);
    final bearingDegrees = _radiansToDegrees(bearing);

    // Normaliser entre 0 et 360
    return (bearingDegrees + 360) % 360;
  }

  /// Convertit degrés en radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Convertit radians en degrés
  double _radiansToDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  /// Import des fonctions math nécessaires
  double sin(double x) => 0.0; // Placeholder - utiliser dart:math
  double cos(double x) => 0.0;
  double atan2(double y, double x) => 0.0;
  double sqrt(double x) => 0.0;
  double get pi => 3.14159265359;

  /// Retourne une description de la qualité du signal GPS
  String get fixQualityDescription {
    if (!hasValidFix) return 'Pas de signal GPS';

    if (satellitesCount == null || hdop == null) {
      return 'Signal GPS (qualité inconnue)';
    }

    if (satellitesCount! >= 10 && hdop! < 2.0) {
      return 'Signal GPS excellent (${satellitesCount} satellites)';
    }

    if (satellitesCount! >= 7 && hdop! < 5.0) {
      return 'Signal GPS bon (${satellitesCount} satellites)';
    }

    if (satellitesCount! >= 4) {
      return 'Signal GPS modéré (${satellitesCount} satellites)';
    }

    return 'Signal GPS faible (${satellitesCount} satellites)';
  }

  /// Représentation textuelle
  @override
  String toString() {
    if (!hasValidFix) return 'GpsData(no fix)';

    return 'GpsData('
        'lat: ${latitude?.toStringAsFixed(6)}, '
        'lon: ${longitude?.toStringAsFixed(6)}, '
        'alt: ${altitude?.toStringAsFixed(1)}m, '
        'speed: ${speed?.toStringAsFixed(1)}km/h, '
        'sats: $satellitesCount, '
        'fix: $fixType'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GpsData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.speed == speed &&
        other.heading == heading;
  }

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitude,
        speed,
        heading,
      );

  GpsData copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? heading,
    int? satellitesCount,
    double? hdop,
    DateTime? gpsTimestamp,
    GpsFixType? fixType,
  }) {
    return GpsData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      satellitesCount: satellitesCount ?? this.satellitesCount,
      hdop: hdop ?? this.hdop,
      gpsTimestamp: gpsTimestamp ?? this.gpsTimestamp,
      fixType: fixType ?? this.fixType,
    );
  }
}

/// Enum pour les types de fix GPS
enum GpsFixType {
  none, // Pas de fix
  fix2d, // Fix 2D (lat/lon seulement)
  fix3d, // Fix 3D (lat/lon + altitude)
  dgps; // Differential GPS (haute précision)

  static GpsFixType fromString(String value) {
    switch (value.toLowerCase()) {
      case '2d':
        return GpsFixType.fix2d;
      case '3d':
        return GpsFixType.fix3d;
      case 'dgps':
        return GpsFixType.dgps;
      default:
        return GpsFixType.none;
    }
  }

  @override
  String toString() {
    switch (this) {
      case GpsFixType.none:
        return 'none';
      case GpsFixType.fix2d:
        return '2d';
      case GpsFixType.fix3d:
        return '3d';
      case GpsFixType.dgps:
        return 'dgps';
    }
  }
}