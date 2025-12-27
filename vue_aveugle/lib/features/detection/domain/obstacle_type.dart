// lib/features/detection/domain/obstacle_type.dart

/// Types d'obstacles détectables par le système
/// Utilisé pour classifier les situations dangereuses
enum ObstacleType {
  /// Obstacle détecté devant l'utilisateur
  FRONT,
  
  /// Obstacle détecté sur le côté gauche
  LEFT,
  
  /// Obstacle détecté sur le côté droit
  RIGHT,
  
  /// Obstacle en hauteur (niveau tête/visage)
  HIGH,
  
  /// Présence d'eau détectée au sol
  WATER,
  
  /// Aucun obstacle détecté
  NONE,
}

/// Extension pour obtenir des descriptions lisibles
extension ObstacleTypeExtension on ObstacleType {
  /// Description humaine de l'obstacle
  String get description {
    switch (this) {
      case ObstacleType.FRONT:
        return 'devant';
      case ObstacleType.LEFT:
        return 'à gauche';
      case ObstacleType.RIGHT:
        return 'à droite';
      case ObstacleType.HIGH:
        return 'en hauteur';
      case ObstacleType.WATER:
        return 'eau au sol';
      case ObstacleType.NONE:
        return 'aucun';
    }
  }

  /// Niveau de priorité (plus élevé = plus urgent)
  int get priority {
    switch (this) {
      case ObstacleType.HIGH:
        return 5; // Le plus dangereux
      case ObstacleType.WATER:
        return 4;
      case ObstacleType.FRONT:
        return 3;
      case ObstacleType.LEFT:
      case ObstacleType.RIGHT:
        return 2;
      case ObstacleType.NONE:
        return 0;
    }
  }
}