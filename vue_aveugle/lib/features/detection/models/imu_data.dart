// lib/features/detection/models/imu_data.dart

/// Modèle de données pour l'Inertial Measurement Unit (MPU9250)
/// 
/// Ce modèle représente l'orientation du dispositif dans l'espace 3D.
/// Ces données sont cruciales pour comprendre comment l'utilisateur aveugle
/// se déplace et dans quelle direction il regarde.
/// 
/// Axes de référence :
/// - Yaw (lacet) : rotation autour de l'axe vertical (gauche/droite)
/// - Pitch (tangage) : rotation autour de l'axe latéral (haut/bas)
/// - Roll (roulis) : rotation autour de l'axe longitudinal (inclinaison latérale)
class ImuData {
  /// Angle de lacet en degrés (-180 à +180)
  /// Indique la direction dans laquelle l'utilisateur regarde
  /// 0° = Nord, 90° = Est, -90° = Ouest, ±180° = Sud
  final double yaw;

  /// Angle de tangage en degrés (-90 à +90)
  /// Indique si l'utilisateur regarde vers le haut (+) ou vers le bas (-)
  /// Important pour détecter si la tête est penchée
  final double pitch;

  /// Angle de roulis en degrés (-180 à +180)
  /// Indique l'inclinaison latérale de la tête
  /// Utile pour détecter une posture anormale ou une chute
  final double roll;

  /// Constructeur avec validation des données
  /// 
  /// Pourquoi valider ? Les capteurs IMU peuvent parfois envoyer des valeurs
  /// aberrantes dues à des interférences magnétiques ou des erreurs de lecture.
  /// Il vaut mieux détecter ces erreurs tôt plutôt que de les propager.
  ImuData({
    required this.yaw,
    required this.pitch,
    required this.roll,
  }) {
    // Validation du yaw : doit être dans l'intervalle [-180, 180]
    // Pourquoi ? C'est la convention standard pour les angles de cap
    if (yaw < -180 || yaw > 180) {
      throw ArgumentError(
        'Yaw doit être entre -180 et 180 degrés. Reçu: $yaw',
      );
    }

    // Validation du pitch : doit être dans l'intervalle [-90, 90]
    // Pourquoi ? Au-delà de ±90°, on regarde vers l'arrière (physiquement impossible)
    if (pitch < -90 || pitch > 90) {
      throw ArgumentError(
        'Pitch doit être entre -90 et 90 degrés. Reçu: $pitch',
      );
    }

    // Validation du roll : doit être dans l'intervalle [-180, 180]
    // Pourquoi ? Convention standard pour l'inclinaison latérale
    if (roll < -180 || roll > 180) {
      throw ArgumentError(
        'Roll doit être entre -180 et 180 degrés. Reçu: $roll',
      );
    }
  }

  /// Factory pour créer une instance depuis un Map JSON
  /// 
  /// Pourquoi un factory ? Parce qu'on doit parser les données BLE qui arrivent
  /// en JSON, et on veut centraliser toute la logique de parsing ici.
  /// 
  /// Exemple de JSON attendu : {"yaw": 12.4, "pitch": -1.2, "roll": 0.3}
  factory ImuData.fromJson(Map<String, dynamic> json) {
    // On utilise ?? 0.0 pour fournir une valeur par défaut si le champ est absent
    // Pourquoi ? Pour éviter un crash complet si une donnée manque,
    // tout en permettant au système de continuer avec des données neutres
    return ImuData(
      yaw: (json['yaw'] as num?)?.toDouble() ?? 0.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
      roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Conversion vers Map pour sérialisation
  /// 
  /// Pourquoi ? Utile pour le logging, le débogage, ou la sauvegarde des données
  Map<String, dynamic> toJson() {
    return {
      'yaw': yaw,
      'pitch': pitch,
      'roll': roll,
    };
  }

  /// Vérifie si la tête de l'utilisateur est dans une position dangereuse
  /// 
  /// Pourquoi cette méthode ? Une tête trop penchée peut indiquer :
  /// - Une chute imminente
  /// - Une posture dangereuse
  /// - Un malaise
  bool get isDangerousTilt {
    // Seuil de tangage : ±60° (tête très penchée vers haut/bas)
    // Pourquoi 60° ? C'est une inclinaison importante qui indique
    // une posture anormale pour la marche
    final bool extremePitch = pitch.abs() > 60;

    // Seuil de roulis : ±45° (tête très inclinée latéralement)
    // Pourquoi 45° ? Au-delà, la personne pourrait perdre l'équilibre
    final bool extremeRoll = roll.abs() > 45;

    return extremePitch || extremeRoll;
  }

  /// Calcule la magnitude totale de l'inclinaison
  /// 
  /// Pourquoi ? Pour avoir une mesure unique de "à quel point la tête est penchée"
  /// indépendamment de la direction. Utile pour des alertes générales.
  double get tiltMagnitude {
    // Formule euclidienne : racine carrée de la somme des carrés
    // On ignore le yaw car il représente la direction, pas l'inclinaison
    return (pitch * pitch + roll * roll).abs().toDouble();
  }

  /// Représentation textuelle pour le débogage
  /// 
  /// Pourquoi ? Facilite grandement le débogage en affichant
  /// les valeurs de manière lisible dans les logs
  @override
  String toString() {
    return 'ImuData(yaw: ${yaw.toStringAsFixed(2)}°, '
        'pitch: ${pitch.toStringAsFixed(2)}°, '
        'roll: ${roll.toStringAsFixed(2)}°)';
  }

  /// Égalité basée sur les valeurs
  /// 
  /// Pourquoi ? Permet de comparer deux instances d'ImuData
  /// pour détecter des changements significatifs
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImuData &&
        other.yaw == yaw &&
        other.pitch == pitch &&
        other.roll == roll;
  }

  /// Hash code pour utilisation dans des collections
  /// 
  /// Pourquoi ? Nécessaire quand on override ==, permet d'utiliser
  /// ImuData comme clé dans des Map ou dans des Set
  @override
  int get hashCode => Object.hash(yaw, pitch, roll);

  /// Copie avec modification de certains champs
  /// 
  /// Pourquoi ? Pattern immutable : au lieu de modifier l'objet,
  /// on en crée une nouvelle version. Plus sûr en programmation concurrente.
  ImuData copyWith({
    double? yaw,
    double? pitch,
    double? roll,
  }) {
    return ImuData(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
    );
  }
}