// lib/features/detection/domain/instruction_type.dart

/// Type logique d'instruction vocale
/// Permet de classifier et prioriser les messages
enum InstructionType {
  /// Avertissement d'un danger immédiat
  /// Ex: "Attention, obstacle en hauteur devant vous"
  WARNING,
  
  /// Instruction de guidage pour la navigation
  /// Ex: "Avancez encore d'un mètre, puis tournez à droite"
  GUIDANCE,
  
  /// Correction de trajectoire
  /// Ex: "Mauvaise trajectoire. Revenez d'un mètre"
  CORRECTION,
}

/// Extension pour gérer les priorités et comportements
extension InstructionTypeExtension on InstructionType {
  /// Priorité de l'instruction (plus élevé = plus urgent)
  int get priority {
    switch (this) {
      case InstructionType.WARNING:
        return 3; // Le plus urgent
      case InstructionType.CORRECTION:
        return 2;
      case InstructionType.GUIDANCE:
        return 1;
    }
  }

  /// Indique si l'instruction doit interrompre une instruction en cours
  bool get shouldInterrupt {
    switch (this) {
      case InstructionType.WARNING:
        return true; // Les avertissements interrompent toujours
      case InstructionType.CORRECTION:
        return true; // Les corrections aussi
      case InstructionType.GUIDANCE:
        return false; // Le guidage normal peut attendre
    }
  }

  /// Préfixe vocal optionnel pour le type d'instruction
  String? get voicePrefix {
    switch (this) {
      case InstructionType.WARNING:
        return 'Attention'; // "Attention, ..."
      case InstructionType.CORRECTION:
        return null; // Pas de préfixe spécifique
      case InstructionType.GUIDANCE:
        return null;
    }
  }
}