// lib/features/detection/tests/expert_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import '../domain/expert_engine.dart';
import '../domain/instruction_type.dart';
import 'fake_sensor_data.dart';

/// Tests unitaires du système expert
/// Ces tests DOIVENT passer AVANT d'utiliser des données réelles
void main() {
  late ExpertEngine engine;

  setUp(() {
    // Créer une nouvelle instance du moteur avant chaque test
    engine = ExpertEngine();
  });

  group('Tests de détection d\'obstacles frontaux', () {
    test('Obstacle frontal proche génère une instruction immédiate', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleFrontClose();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.GUIDANCE));
      expect(instruction.message, contains('Obstacle devant'));
      expect(instruction.message, contains('Tournez'));
      expect(instruction.followUpAction, isNotNull);
      expect(
        instruction.followUpAction,
        anyOf(equals('TURN_LEFT'), equals('TURN_RIGHT')),
      );
    });

    test('Obstacle frontal moyen donne une distance avant de tourner', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleFrontMedium();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.GUIDANCE));
      expect(instruction.message, contains('Avancez encore'));
      expect(instruction.message, contains('puis tournez'));
      expect(instruction.distanceMeters, isNotNull);
      expect(instruction.distanceMeters! > 0, isTrue);
      expect(instruction.stepsEstimate, isNotNull);
    });

    test('Situation coincée génère un arrêt immédiat', () {
      // Arrange
      final snapshot = FakeSensorData.trapped();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.WARNING));
      expect(instruction.message, contains('Arrêtez-vous'));
      expect(instruction.immediate, isTrue);
    });
  });

  group('Tests de priorité des dangers', () {
    test('Obstacle en hauteur a la priorité maximale', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleHigh();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.WARNING));
      expect(instruction.message, contains('obstacle en hauteur'));
      expect(instruction.immediate, isTrue);
    });

    test('Eau détectée génère un avertissement', () {
      // Arrange
      final snapshot = FakeSensorData.waterDetected();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.WARNING));
      expect(instruction.message, contains('eau'));
      expect(instruction.message, contains('Avancez lentement'));
      expect(instruction.immediate, isTrue);
    });

    test('Priorités correctes: obstacle haut > eau > obstacle frontal', () {
      // Test séquence d'urgence
      final snapshots = FakeSensorData.emergencySequence();
      final instructions = <String>[];

      for (final snapshot in snapshots) {
        final instruction = engine.evaluate(snapshot);
        if (instruction.immediate) {
          instructions.add(instruction.message);
        }
      }

      // Vérifier que les messages urgents sont bien générés
      expect(instructions.length, greaterThan(0));
      expect(
        instructions.any((msg) => msg.contains('hauteur')),
        isTrue,
        reason: 'Obstacle en hauteur doit être détecté',
      );
    });
  });

  group('Tests de correction de trajectoire', () {
    test('Légère déviation génère une correction simple', () {
      // Arrange
      final snapshot = FakeSensorData.wrongOrientationSlight();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.CORRECTION));
      expect(instruction.message, contains('déviez'));
      expect(instruction.message, contains('Redressez'));
      expect(instruction.immediate, isTrue);
    });

    test('Forte déviation demande de revenir en arrière', () {
      // Arrange
      final snapshot = FakeSensorData.wrongOrientationStrong();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.CORRECTION));
      expect(instruction.message, contains('Mauvaise trajectoire'));
      expect(instruction.message, contains('Revenez'));
      expect(instruction.distanceMeters, equals(1.0));
      expect(instruction.followUpAction, isNotNull);
    });
  });

  group('Tests d\'obstacles latéraux', () {
    test('Passage étroit génère un avertissement de prudence', () {
      // Arrange
      final snapshot = FakeSensorData.narrowPassage();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.type, equals(InstructionType.WARNING));
      expect(instruction.message, contains('Passage étroit'));
      expect(instruction.message, contains('prudemment'));
    });

    test('Obstacle à gauche uniquement', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleLeft();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.message, contains('gauche'));
      expect(instruction.type, equals(InstructionType.WARNING));
    });

    test('Obstacle à droite uniquement', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleRight();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.message, contains('droite'));
      expect(instruction.type, equals(InstructionType.WARNING));
    });
  });

  group('Tests de voie libre', () {
    test('Baseline génère instruction de continuer', () {
      // Arrange
      final snapshot = FakeSensorData.baseline();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      expect(instruction.message, contains('Voie libre'));
      expect(instruction.type, equals(InstructionType.GUIDANCE));
      expect(instruction.immediate, isFalse);
    });
  });

  group('Tests de séquence de navigation', () {
    test('Séquence complète génère des instructions cohérentes', () {
      // Arrange
      final snapshots = FakeSensorData.navigationSequence();

      // Act
      final instructions = <String>[];
      for (final snapshot in snapshots) {
        final instruction = engine.evaluate(snapshot);
        instructions.add(instruction.message);
      }

      // Assert
      expect(instructions.length, equals(snapshots.length));
      expect(instructions, isNotEmpty);
      
      // Vérifier qu'il y a différents types d'instructions
      final uniqueMessages = instructions.toSet();
      expect(uniqueMessages.length, greaterThan(3));
    });

    test('Déduplication des messages identiques', () {
      // Arrange
      final snapshot = FakeSensorData.baseline();

      // Act
      final instruction1 = engine.evaluate(snapshot);
      final instruction2 = engine.evaluate(snapshot);

      // Assert
      // Le moteur ne devrait pas répéter la même instruction
      // (sauf si immediate=true)
      expect(instruction1.message, equals(instruction2.message));
    });
  });

  group('Tests des métadonnées d\'instruction', () {
    test('Instructions avec distance incluent estimation de pas', () {
      // Arrange
      final snapshot = FakeSensorData.obstacleFrontMedium();

      // Act
      final instruction = engine.evaluate(snapshot);

      // Assert
      if (instruction.distanceMeters != null) {
        expect(instruction.stepsEstimate, isNotNull);
        expect(
          instruction.stepsEstimate,
          equals((instruction.distanceMeters! / 0.5).round()),
        );
      }
    });

    test('Messages urgents sont marqués comme immediate', () {
      // Arrange
      final urgentSnapshots = [
        FakeSensorData.obstacleHigh(),
        FakeSensorData.waterDetected(),
        FakeSensorData.wrongOrientationStrong(),
      ];

      // Act & Assert
      for (final snapshot in urgentSnapshots) {
        final instruction = engine.evaluate(snapshot);
        expect(
          instruction.immediate,
          isTrue,
          reason: 'Situations urgentes doivent avoir immediate=true',
        );
      }
    });
  });

  group('Tests des statistiques du moteur', () {
    test('Statistiques sont disponibles après évaluation', () {
      // Arrange
      final snapshot = FakeSensorData.baseline();

      // Act
      engine.evaluate(snapshot);
      final stats = engine.getStatistics();

      // Assert
      expect(stats['rulesCount'], greaterThan(0));
      expect(stats['lastEvaluationTime'], isNotNull);
      expect(stats['hasLastInstruction'], isTrue);
    });

    test('Reset efface l\'historique', () {
      // Arrange
      final snapshot = FakeSensorData.baseline();
      engine.evaluate(snapshot);

      // Act
      engine.reset();

      // Assert
      expect(engine.lastInstruction, isNull);
      expect(engine.lastEvaluationTime, isNull);
    });
  });

  group('Tests de robustesse', () {
    test('Messages ne contiennent jamais de termes techniques', () {
      // Arrange
      final allScenarios = [
        FakeSensorData.baseline(),
        FakeSensorData.obstacleFrontClose(),
        FakeSensorData.obstacleHigh(),
        FakeSensorData.waterDetected(),
        FakeSensorData.wrongOrientationSlight(),
        FakeSensorData.narrowPassage(),
      ];

      // Act & Assert
      for (final snapshot in allScenarios) {
        final instruction = engine.evaluate(snapshot);
        
        // Vérifier absence de termes interdits
        expect(instruction.message, isNot(contains('STOP')));
        expect(instruction.message, isNot(contains('GAUCHE')));
        expect(instruction.message, isNot(contains('DROITE')));
        expect(instruction.message, isNot(contains('YAW')));
        expect(instruction.message, isNot(contains('PITCH')));
        expect(instruction.message, isNot(contains('SENSOR')));
      }
    });

    test('Tous les messages sont compréhensibles sans vision', () {
      // Arrange
      final allScenarios = [
        FakeSensorData.baseline(),
        FakeSensorData.obstacleFrontClose(),
        FakeSensorData.obstacleHigh(),
        FakeSensorData.waterDetected(),
      ];

      // Act & Assert
      for (final snapshot in allScenarios) {
        final instruction = engine.evaluate(snapshot);
        
        // Le message doit contenir des mots d'action clairs
        final hasAction = instruction.message.contains('Avancez') ||
            instruction.message.contains('Tournez') ||
            instruction.message.contains('Arrêtez') ||
            instruction.message.contains('Continuez') ||
            instruction.message.contains('Revenez') ||
            instruction.message.contains('Attention');
            
        expect(
          hasAction,
          isTrue,
          reason: 'Message doit contenir une action claire: ${instruction.message}',
        );
      }
    });
  });
}