// lib/features/detection/domain/gps_expert_rules.dart

import 'sensor_snapshot.dart';
import 'instruction_guidage.dart';
import 'expert_rule.dart';

/// RÈGLES GPS pour le système expert
/// 
/// Ces règles utilisent le contexte GPS dans le SensorSnapshot
/// pour générer des instructions de navigation vers la destination.
/// 
/// IMPORTANT : Ces règles ont une priorité BASSE. Les dangers
/// (obstacles, eau) ont toujours la priorité.

// ========== RÈGLE GPS 1 : Navigation vers destination ==========

/// RÈGLE : Correction de trajectoire GPS
/// Priorité : 10 (BASSE - après tous les dangers)
class GpsNavigationRule extends ExpertRule {
  @override
  String get name => 'Navigation GPS';
  
  @override
  int get priority => 10;

  @override
  bool matches(SensorSnapshot snapshot) {
    // Condition 1 : Pas d'obstacle bloquant
    if (snapshot.hasBlockingObstacle || snapshot.obstacleHigh) {
      return false; // Les obstacles ont la priorité
    }
    
    // Condition 2 : Destination active
    if (!snapshot.hasActiveDestination) {
      return false;
    }
    
    // Condition 3 : Déviation significative du cap (> 15°)
    if (!snapshot.isOffCourse) {
      return false; // Trajectoire OK
    }
    
    return true;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    final deviation = snapshot.headingDeviation!;
    final distance = snapshot.distanceToNextWaypoint;
    final waypointName = snapshot.nextWaypointName;
    
    String direction = snapshot.correctionDirection!;
    String action = direction == 'droite' ? 'TURN_RIGHT' : 'TURN_LEFT';
    
    String message;
    
    // Cas 1 : Forte déviation (> 45°)
    if (snapshot.isStronglyOffCourse) {
      message = 'Vous déviez fortement. Tournez $direction pour revenir sur l\'itinéraire.';
    }
    // Cas 2 : Proche du waypoint
    else if (distance != null && distance < 50) {
      final distText = distance.toStringAsFixed(0);
      if (waypointName != null) {
        message = 'Tournez légèrement $direction. $waypointName à $distText mètres.';
      } else {
        message = 'Tournez légèrement $direction. Waypoint à $distText mètres.';
      }
    }
    // Cas 3 : Déviation normale
    else {
      message = 'Ajustez votre trajectoire vers la $direction.';
    }
    
    return InstructionGuidage.guidance(
      message: message,
      followUpAction: action,
    );
  }
}

// ========== RÈGLE GPS 2 : Arrivée à destination ==========

/// RÈGLE : Annonce d'arrivée à destination
/// Priorité : 95 (HAUTE - juste après les dangers)
class DestinationReachedRule extends ExpertRule {
  bool _alreadyAnnounced = false;

  @override
  String get name => 'Destination atteinte';
  
  @override
  int get priority => 95;

  @override
  bool matches(SensorSnapshot snapshot) {
    // Réinitialiser le flag si on s'éloigne
    if (!snapshot.isNearDestination) {
      _alreadyAnnounced = false;
      return false;
    }
    
    // Ne pas répéter l'annonce
    if (_alreadyAnnounced) return false;
    
    _alreadyAnnounced = true;
    return true;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    final destName = snapshot.destinationName ?? 'votre destination';
    
    return InstructionGuidage.guidance(
      message: 'Destination atteinte : $destName. Vous êtes arrivé.',
      followUpAction: 'STOP',
    );
  }
}

// ========== RÈGLE GPS 3 : Arrivée au waypoint ==========

/// RÈGLE : Annonce d'arrivée au waypoint intermédiaire
/// Priorité : 40 (MOYENNE)
class WaypointReachedRule extends ExpertRule {
  bool _alreadyAnnounced = false;

  @override
  String get name => 'Waypoint atteint';
  
  @override
  int get priority => 40;

  @override
  bool matches(SensorSnapshot snapshot) {
    // Réinitialiser le flag si on s'éloigne
    if (!snapshot.isNearWaypoint) {
      _alreadyAnnounced = false;
      return false;
    }
    
    // Ne pas annoncer si on est proche de la destination finale
    if (snapshot.isNearDestination) {
      return false; // DestinationReachedRule s'en charge
    }
    
    // Ne pas répéter l'annonce
    if (_alreadyAnnounced) return false;
    
    _alreadyAnnounced = true;
    return true;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    final waypointName = snapshot.nextWaypointName;
    
    String message;
    if (waypointName != null) {
      message = 'Point atteint : $waypointName. Continuez.';
    } else {
      message = 'Point de passage atteint. Continuez.';
    }
    
    return InstructionGuidage.guidance(
      message: message,
      followUpAction: 'CONTINUE',
    );
  }
}

// ========== RÈGLE GPS 4 : Obstacle sur la route GPS ==========

/// RÈGLE : Obstacle bloque l'itinéraire GPS
/// Cette règle propose un contournement intelligent
/// Priorité : 75 (entre obstacle immédiat et GPS)
class ObstacleOnGpsRouteRule extends ExpertRule {
  @override
  String get name => 'Obstacle sur itinéraire GPS';
  
  @override
  int get priority => 75;

  @override
  bool matches(SensorSnapshot snapshot) {
    // Condition 1 : Obstacle devant
    if (!snapshot.hasObstacleFront) return false;
    
    // Condition 2 : Destination active
    if (!snapshot.hasActiveDestination) return false;
    
    // Condition 3 : On était sur la bonne trajectoire (déviation < 30°)
    final deviation = snapshot.headingDeviation;
    if (deviation == null || deviation.abs() > 30.0) return false;
    
    return true;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    // Analyser quel côté est le plus dégagé
    final leftClear = snapshot.distanceLeft > 2.0;
    final rightClear = snapshot.distanceRight > 2.0;
    
    String direction;
    String action;
    
    if (leftClear && !rightClear) {
      direction = 'gauche';
      action = 'TURN_LEFT';
    } else if (rightClear && !leftClear) {
      direction = 'droite';
      action = 'TURN_RIGHT';
    } else if (leftClear && rightClear) {
      // Les deux côtés libres, choisir selon le cap GPS
      direction = snapshot.correctionDirection ?? 'droite';
      action = direction == 'droite' ? 'TURN_RIGHT' : 'TURN_LEFT';
    } else {
      // Aucun côté libre
      return InstructionGuidage.warning(
        'Obstacle bloque votre chemin. Arrêtez-vous.',
      );
    }
    
    return InstructionGuidage.guidance(
      message: 'Obstacle sur votre route. Contournez par la $direction.',
      distanceMeters: 1.0,
      followUpAction: action,
    );
  }
}

// ========== RÈGLE GPS 5 : Perte du signal GPS ==========

/// RÈGLE : Perte du signal GPS pendant navigation
/// Priorité : 65 (moyenne-haute)
class GpsLostDuringNavigationRule extends ExpertRule {
  bool _alreadyAlerted = false;

  @override
  String get name => 'Perte GPS';
  
  @override
  int get priority => 65;

  @override
  bool matches(SensorSnapshot snapshot) {
    // Cette règle ne peut être évaluée que depuis le pipeline
    // car on a besoin de savoir si on avait une destination avant
    // Pour l'instant, on la laisse désactivée
    return false;
  }

  @override
  InstructionGuidage apply(SensorSnapshot snapshot) {
    return InstructionGuidage.warning(
      'Signal GPS perdu. Navigation suspendue. Continuez prudemment.',
    );
  }
}