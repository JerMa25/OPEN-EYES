// lib/features/detection/domain/expert_rule.dart

import 'sensor_snapshot.dart';
import 'instruction_guidage.dart';

/// Classe abstraite définissant une règle experte
/// Chaque règle analyse un snapshot et génère une instruction si applicable
abstract class ExpertRule {
  /// Nom descriptif de la règle (pour debug)
  String get name;
  
  /// Priorité de la règle (plus élevé = plus prioritaire)
  /// Les règles avec priorité élevée sont évaluées en premier
  int get priority;

  /// Vérifie si cette règle s'applique au snapshot donné
  /// Retourne true si les conditions de la règle sont satisfaites
  bool matches(SensorSnapshot snapshot);

  /// Génère l'instruction de guidage appropriée
  /// Cette méthode ne doit être appelée que si matches() retourne true
  InstructionGuidage apply(SensorSnapshot snapshot);
}

// ========== RÈGLES CONCRÈTES ==========

/// RÈGLE 1: Détection d'obstacle en hauteur (PRIORITÉ MAXIMALE)
class HighObstacleRule extends ExpertRule {
  @override
  String get name => 'Obstacle en hauteur';
  
  @override
  int get priority => 100; // Priorité maximale

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.obstacleHigh;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    return InstructionGuidage.warning(
      'Attention, obstacle en hauteur devant vous.',
    );
  }
}

/// RÈGLE 2: Détection d'eau au sol
class WaterDetectionRule extends ExpertRule {
  @override
  String get name => 'Présence d\'eau';
  
  @override
  int get priority => 90;

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.waterDetected;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    return InstructionGuidage.warning(
      'Présence d\'eau au sol. Avancez lentement.',
    );
  }
}

/// RÈGLE 3: Obstacle proche devant (< 1m)
class ImmediateObstacleFrontRule extends ExpertRule {
  @override
  String get name => 'Obstacle immédiat devant';
  
  @override
  int get priority => 80;

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.distanceFront < 1.0;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    // Détermine la meilleure direction pour contourner
    final canGoLeft = snapshot.distanceLeft > 1.5;
    final canGoRight = snapshot.distanceRight > 1.5;
    
    String direction;
    String action;
    
    if (canGoLeft && !canGoRight) {
      direction = 'gauche';
      action = 'TURN_LEFT';
    } else if (canGoRight && !canGoLeft) {
      direction = 'droite';
      action = 'TURN_RIGHT';
    } else if (canGoLeft && canGoRight) {
      // Les deux côtés sont libres, choisir le plus dégagé
      direction = snapshot.distanceLeft > snapshot.distanceRight ? 'gauche' : 'droite';
      action = direction == 'gauche' ? 'TURN_LEFT' : 'TURN_RIGHT';
    } else {
      // Aucun côté n'est libre
      return InstructionGuidage.warning(
        'Obstacle très proche. Arrêtez-vous.',
      );
    }
    
    return InstructionGuidage.guidance(
      message: 'Obstacle devant. Tournez à $direction maintenant.',
      followUpAction: action,
    );
  }
}

/// RÈGLE 4: Obstacle moyen devant (1m - 2m)
class MediumObstacleFrontRule extends ExpertRule {
  @override
  String get name => 'Obstacle moyen devant';
  
  @override
  int get priority => 70;

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.distanceFront >= 1.0 && snapshot.distanceFront < 2.0;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    final distanceToObstacle = snapshot.distanceFront;
    final distanceBeforeTurn = (distanceToObstacle - 0.5).clamp(0.5, 1.5);
    final steps = (distanceBeforeTurn / 0.5).round();
    
    // Détermine la meilleure direction
    final direction = snapshot.distanceLeft > snapshot.distanceRight ? 'gauche' : 'droite';
    final action = direction == 'gauche' ? 'TURN_LEFT' : 'TURN_RIGHT';
    
    return InstructionGuidage.guidance(
      message: 'Obstacle devant. Avancez encore d\'un mètre, puis tournez à $direction.',
      distanceMeters: distanceBeforeTurn,
      stepsEstimate: steps,
      followUpAction: action,
    );
  }
}

/// RÈGLE 5: Déviation de trajectoire
class TrajectoryDeviationRule extends ExpertRule {
  @override
  String get name => 'Déviation de trajectoire';
  
  @override
  int get priority => 60;

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.isDeviating;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    final yaw = snapshot.yaw;
    final direction = yaw > 0 ? 'gauche' : 'droite';
    final oppositeDirection = yaw > 0 ? 'droite' : 'gauche';
    
    // Si forte déviation (> 30°), demander de revenir en arrière
    if (yaw.abs() > 30) {
      return InstructionGuidage.correction(
        message: 'Mauvaise trajectoire. Revenez d\'un mètre, puis tournez à $oppositeDirection.',
        distanceMeters: 1.0,
        followUpAction: oppositeDirection == 'droite' ? 'TURN_RIGHT' : 'TURN_LEFT',
      );
    }
    
    // Sinon, simple correction
    return InstructionGuidage.correction(
      message: 'Vous déviez vers la $direction. Redressez vers la $oppositeDirection.',
      followUpAction: oppositeDirection == 'droite' ? 'TURN_RIGHT' : 'TURN_LEFT',
    );
  }
}

/// RÈGLE 6: Obstacle latéral proche
class LateralObstacleRule extends ExpertRule {
  @override
  String get name => 'Obstacle latéral';
  
  @override
  int get priority => 50;

  @override
  bool matches(SensorSnapshot snapshot) {
    return snapshot.hasObstacleLeft || snapshot.hasObstacleRight;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    if (snapshot.hasObstacleLeft && snapshot.hasObstacleRight) {
      return InstructionGuidage.warning(
        'Passage étroit. Avancez prudemment.',
      );
    } else if (snapshot.hasObstacleLeft) {
      return InstructionGuidage.warning(
        'Obstacle proche sur votre gauche.',
      );
    } else {
      return InstructionGuidage.warning(
        'Obstacle proche sur votre droite.',
      );
    }
  }
}

/// RÈGLE 7: Voie libre (règle par défaut)
class ClearPathRule extends ExpertRule {
  @override
  String get name => 'Voie libre';
  
  @override
  int get priority => 0; // Priorité minimale

  @override
  bool matches(SensorSnapshot snapshot) {
    // Cette règle s'applique toujours si aucune autre ne s'est déclenchée
    return true;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    return InstructionGuidage.guidance(
      message: 'Voie libre. Continuez tout droit.',
      followUpAction: 'CONTINUE',
    );
  }
}