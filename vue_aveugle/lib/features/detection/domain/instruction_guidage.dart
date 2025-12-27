// lib/features/detection/domain/instruction_guidage.dart

import 'instruction_type.dart';

/// SORTIE FINALE DU SYSTÈME EXPERT
/// Représente une instruction vocale complète et actionnable
/// Cette classe contient TOUT ce qui doit être communiqué à l'utilisateur
class InstructionGuidage {
  /// Type logique de l'instruction (warning, guidance, correction)
  final InstructionType type;
  
  /// Message vocal lisible TEL QUEL par le système audio
  /// Ce message est déjà formaté pour être compréhensible sans vision
  /// Ex: "Obstacle devant. Avancez encore d'un mètre, puis tournez à droite."
  final String message;
  
  /// Distance en mètres mentionnée dans l'instruction (si applicable)
  /// Utilisé par le timing_controller pour déclencher les actions
  /// Ex: 1.0 pour "avancez encore d'un mètre"
  final double? distanceMeters;
  
  /// Estimation en nombre de pas (basé sur ~0.5m par pas)
  /// Peut être annoncé à l'utilisateur pour plus de clarté
  /// Ex: 2 pas pour 1 mètre
  final int? stepsEstimate;
  
  /// Action à effectuer après avoir parcouru la distance
  /// Valeurs possibles: TURN_RIGHT, TURN_LEFT, STOP, CONTINUE
  /// null = aucune action spécifique requise
  final String? followUpAction;
  
  /// Indique si l'instruction doit être prononcée IMMÉDIATEMENT
  /// true = danger imminent, interrompt toute instruction en cours
  /// false = peut être mise en file d'attente
  final bool immediate;

  const InstructionGuidage({
    required this.type,
    required this.message,
    this.distanceMeters,
    this.stepsEstimate,
    this.followUpAction,
    this.immediate = false,
  });

  /// Factory pour créer une instruction d'avertissement urgent
  factory InstructionGuidage.warning(String message) {
    return InstructionGuidage(
      type: InstructionType.WARNING,
      message: message,
      immediate: true,
    );
  }

  /// Factory pour créer une instruction de guidage standard
  factory InstructionGuidage.guidance({
    required String message,
    double? distanceMeters,
    int? stepsEstimate,
    String? followUpAction,
  }) {
    return InstructionGuidage(
      type: InstructionType.GUIDANCE,
      message: message,
      distanceMeters: distanceMeters,
      stepsEstimate: stepsEstimate,
      followUpAction: followUpAction,
      immediate: false,
    );
  }

  /// Factory pour créer une instruction de correction
  factory InstructionGuidage.correction({
    required String message,
    double? distanceMeters,
    String? followUpAction,
  }) {
    return InstructionGuidage(
      type: InstructionType.CORRECTION,
      message: message,
      distanceMeters: distanceMeters,
      followUpAction: followUpAction,
      immediate: true,
    );
  }

  /// Retourne true si cette instruction a une action de suivi planifiée
  bool get hasFollowUp => followUpAction != null;

  /// Retourne true si cette instruction nécessite un déplacement
  bool get requiresMovement => distanceMeters != null && distanceMeters! > 0;

  /// Durée estimée pour prononcer le message (en millisecondes)
  /// Basé sur ~150 mots par minute de parole
  int get estimatedDurationMs {
    final wordCount = message.split(' ').length;
    return ((wordCount / 150) * 60 * 1000).round();
  }

  @override
  String toString() {
    return 'InstructionGuidage('
        'type: $type, '
        'message: "$message", '
        'distance: ${distanceMeters?.toStringAsFixed(1)}m, '
        'steps: $stepsEstimate, '
        'followUp: $followUpAction, '
        'immediate: $immediate)';
  }

  /// Copie avec modifications
  InstructionGuidage copyWith({
    InstructionType? type,
    String? message,
    double? distanceMeters,
    int? stepsEstimate,
    String? followUpAction,
    bool? immediate,
  }) {
    return InstructionGuidage(
      type: type ?? this.type,
      message: message ?? this.message,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      stepsEstimate: stepsEstimate ?? this.stepsEstimate,
      followUpAction: followUpAction ?? this.followUpAction,
      immediate: immediate ?? this.immediate,
    );
  }
}