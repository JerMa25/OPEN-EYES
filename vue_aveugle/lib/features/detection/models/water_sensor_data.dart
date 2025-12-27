// lib/features/detection/models/water_sensor_data.dart

/// Modèle de données pour le capteur d'eau
/// 
/// Ce capteur détecte la présence d'eau ou d'humidité au sol, crucial pour :
/// - Éviter les flaques d'eau (glissades)
/// - Détecter les fuites ou inondations
/// - Identifier les zones humides dangereuses (boue, glace fondue)
/// - Alerter sur les conditions météo (pluie active)
/// 
/// Le capteur retourne généralement une valeur analogique (0-1023 sur ESP32)
/// que l'on normalise en pourcentage (0-100%)
class WaterSensorData {
  /// Niveau d'humidité détecté (0.0 = sec, 100.0 = très humide/submergé)
  /// 
  /// Pourquoi un pourcentage ? Plus intuitif qu'une valeur ADC brute.
  /// Facilite aussi la calibration et les seuils de décision.
  /// 
  /// Plages typiques :
  /// - 0-20% : Sol sec, pas de danger
  /// - 20-50% : Légère humidité, vigilance
  /// - 50-80% : Humidité importante, danger glissade
  /// - 80-100% : Eau stagnante ou submersion
  final double humidityLevel;

  /// Valeur brute ADC du capteur (optionnel, pour débogage)
  /// 
  /// Pourquoi garder la valeur brute ? Pour :
  /// - Recalibrer les seuils si nécessaire
  /// - Déboguer les problèmes de capteur
  /// - Analyser les dérives dans le temps
  /// 
  /// Plage ESP32 : 0-4095 (ADC 12-bit)
  final int? rawValue;

  /// Seuil d'alerte humidité modérée (%)
  /// 
  /// Pourquoi 30% ? Seuil conservateur où le sol commence à être glissant
  /// mais reste praticable avec prudence
  static const double warningThreshold = 30.0;

  /// Seuil de danger humidité élevée (%)
  /// 
  /// Pourquoi 60% ? Au-delà, risque élevé de glissade ou présence d'eau
  /// stagnante. L'utilisateur doit contourner la zone.
  static const double dangerThreshold = 60.0;

  /// Seuil critique submersion (%)
  /// 
  /// Pourquoi 85% ? Indique eau stagnante profonde ou flaque importante.
  /// Passage impossible sans se mouiller.
  static const double criticalThreshold = 85.0;

  /// Constructeur avec validation du niveau d'humidité
  /// 
  /// Pourquoi valider ? Le pourcentage doit être entre 0 et 100.
  /// Des valeurs hors limite indiquent un problème de calibration ou
  /// un dysfonctionnement du capteur.
  WaterSensorData({
    required this.humidityLevel,
    this.rawValue,
  }) {
    // Validation : humidité entre 0 et 100%
    if (humidityLevel < 0 || humidityLevel > 100) {
      throw ArgumentError(
        'humidityLevel doit être entre 0 et 100%, reçu: $humidityLevel',
      );
    }

    // Validation optionnelle : valeur ADC dans la plage ESP32
    if (rawValue != null && (rawValue! < 0 || rawValue! > 4095)) {
      throw ArgumentError(
        'rawValue hors limites ADC ESP32 (0-4095): $rawValue',
      );
    }
  }

  /// Factory pour créer une instance depuis un Map JSON
  /// 
  /// Pourquoi un factory ? Centralise le parsing des données BLE
  /// 
  /// Exemple JSON : 
  /// {
  ///   "humidityLevel": 45.5,
  ///   "rawValue": 1865
  /// }
  factory WaterSensorData.fromJson(Map<String, dynamic> json) {
    return WaterSensorData(
      humidityLevel: (json['humidityLevel'] as num?)?.toDouble() ?? 0.0,
      rawValue: json['rawValue'] as int?,
    );
  }

  /// Conversion vers Map pour sérialisation
  Map<String, dynamic> toJson() {
    return {
      'humidityLevel': humidityLevel,
      'rawValue': rawValue,
    };
  }

  /// Vérifie si le sol est sec et sûr
  /// 
  /// Pourquoi < 20% ? En dessous de ce seuil, le sol est suffisamment
  /// sec pour ne présenter aucun risque de glissade
  bool get isDry {
    return humidityLevel < 20.0;
  }

  /// Vérifie si le niveau d'humidité nécessite une vigilance
  /// 
  /// Pourquoi ce seuil ? Sol commence à être glissant, mais passage
  /// possible avec prudence (ralentir, attention aux pas)
  bool get requiresAttention {
    return humidityLevel >= warningThreshold && 
           humidityLevel < dangerThreshold;
  }

  /// Vérifie si le niveau d'humidité est dangereux
  /// 
  /// Pourquoi ? Sol très glissant ou présence d'eau. L'utilisateur
  /// devrait contourner la zone si possible.
  bool get isDangerous {
    return humidityLevel >= dangerThreshold && 
           humidityLevel < criticalThreshold;
  }

  /// Vérifie si présence d'eau stagnante (submersion)
  /// 
  /// Pourquoi ? Eau profonde ou flaque importante. Passage impossible
  /// sans se mouiller les pieds. Contournement obligatoire.
  bool get isSubmerged {
    return humidityLevel >= criticalThreshold;
  }

  /// Retourne le niveau de risque sous forme textuelle
  /// 
  /// Pourquoi ? Facilite la génération de messages d'alerte vocaux
  /// ou l'affichage dans l'interface utilisateur
  String get riskLevel {
    if (isSubmerged) return 'Submergé';
    if (isDangerous) return 'Dangereux';
    if (requiresAttention) return 'Vigilance';
    return 'Sec';
  }

  /// Calcule un score de danger (0.0 = sec, 1.0 = submergé)
  /// 
  /// Pourquoi ? Métrique continue pour adapter l'intensité des alertes
  /// et faciliter la prise de décision
  /// 
  /// Formule progressive : plus c'est humide, plus le score est élevé
  double get dangerScore {
    if (humidityLevel < warningThreshold) {
      return 0.0; // Aucun danger
    }

    // Score progressif de 0.0 à 1.0 selon le niveau d'humidité
    // 30% -> 0.0, 100% -> 1.0
    final normalizedLevel = (humidityLevel - warningThreshold) / 
                           (100.0 - warningThreshold);
    
    return normalizedLevel.clamp(0.0, 1.0);
  }

  /// Estime le temps de séchage approximatif (en minutes)
  /// 
  /// Pourquoi ? Pour informer l'utilisateur si la zone sera praticable
  /// plus tard (utile pour planification de trajet)
  /// 
  /// Note : estimation très approximative, dépend de :
  /// - Température ambiante
  /// - Humidité de l'air
  /// - Ventilation
  /// - Type de surface
  int? get estimatedDryingTime {
    if (isDry) return 0; // Déjà sec

    // Estimation grossière : 1 minute par pourcent au-dessus de 20%
    // Exemple : 50% humidité -> ~30 minutes
    final timeMinutes = (humidityLevel - 20.0).round();
    
    return timeMinutes.clamp(5, 180); // Entre 5min et 3h
  }

  /// Vérifie si le capteur fonctionne correctement
  /// 
  /// Pourquoi ? Pour détecter un capteur défectueux :
  /// - Bloqué à 0% (déconnecté)
  /// - Bloqué à 100% (court-circuit)
  /// - Valeur ADC suspecte
  bool get isSensorHealthy {
    // Vérification 1 : pas bloqué aux extrêmes
    if (humidityLevel == 0.0 || humidityLevel == 100.0) {
      // Acceptable seulement si cohérent avec rawValue
      if (rawValue != null) {
        if (humidityLevel == 0.0 && rawValue! > 100) return false;
        if (humidityLevel == 100.0 && rawValue! < 3900) return false;
      }
    }

    // Vérification 2 : cohérence humidité/rawValue si disponible
    if (rawValue != null) {
      final expectedHumidity = (rawValue! / 4095.0) * 100.0;
      final difference = (humidityLevel - expectedHumidity).abs();
      
      // Tolérance de 10% de différence
      if (difference > 10.0) return false;
    }

    return true;
  }

  /// Représentation textuelle pour le débogage
  @override
  String toString() {
    final raw = rawValue != null ? ' (raw: $rawValue)' : '';
    return 'WaterSensorData('
        'humidity: ${humidityLevel.toStringAsFixed(1)}%$raw, '
        'risk: $riskLevel'
        ')';
  }

  /// Égalité basée sur les valeurs
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaterSensorData &&
        other.humidityLevel == humidityLevel &&
        other.rawValue == rawValue;
  }

  /// Hash code pour collections
  @override
  int get hashCode => Object.hash(humidityLevel, rawValue);

  /// Copie avec modification de certains champs
  WaterSensorData copyWith({
    double? humidityLevel,
    int? rawValue,
  }) {
    return WaterSensorData(
      humidityLevel: humidityLevel ?? this.humidityLevel,
      rawValue: rawValue ?? this.rawValue,
    );
  }
}