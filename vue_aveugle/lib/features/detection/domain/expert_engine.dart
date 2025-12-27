// lib/features/detection/domain/expert_engine.dart

import 'sensor_snapshot.dart';
import 'instruction_guidage.dart';
import 'expert_rule.dart';
import 'gps_expert_rules.dart'; // ← AJOUT

/// MOTEUR PRINCIPAL DU SYSTÈME EXPERT (DÉCIDEUR UNIQUE)
/// 
/// Analyse le SensorSnapshot COMPLET (obstacles + GPS) et génère
/// UNE instruction de guidage unique.
/// 
/// Principe : Les règles sont évaluées par ordre de priorité décroissante.
/// La première règle qui match génère l'instruction.
/// 
/// Priorités :
/// - 100 : Obstacle hauteur (danger immédiat)
/// - 95  : Destination atteinte
/// - 90  : Eau
/// - 80  : Obstacle immédiat
/// - 75  : Obstacle sur route GPS
/// - 70  : Obstacle moyen
/// - 65  : GPS perdu
/// - 60  : Déviation trajectoire
/// - 50  : Obstacle latéral
/// - 40  : Waypoint atteint
/// - 10  : Navigation GPS
/// - 0   : Voie libre (fallback)
class ExpertEngine {
  /// Liste des règles expertes, triées par priorité décroissante
  final List<ExpertRule> rules;

  /// Cache de la dernière instruction générée (pour éviter les répétitions)
  InstructionGuidage? _lastInstruction;
  
  /// Timestamp de la dernière évaluation
  int? _lastEvaluationTime;

  ExpertEngine({
    List<ExpertRule>? rules,
    bool includeGpsRules = true, // ← AJOUT
  }) : rules = rules ?? _defaultRules(includeGpsRules) {
    // Trie les règles par priorité décroissante
    this.rules.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Règles par défaut du système (obstacles locaux + GPS)
  static List<ExpertRule> _defaultRules(bool includeGps) {
    final rules = <ExpertRule>[
      // ===== RÈGLES LOCALES (obstacles) - Priorité haute =====
      HighObstacleRule(),           // Priorité 100
      WaterDetectionRule(),         // Priorité 90
      ImmediateObstacleFrontRule(), // Priorité 80
      MediumObstacleFrontRule(),    // Priorité 70
      TrajectoryDeviationRule(),    // Priorité 60
      LateralObstacleRule(),        // Priorité 50
      ClearPathRule(),              // Priorité 0 (fallback)
    ];
    
    // ===== RÈGLES GPS - Priorité variable =====
    if (includeGps) {
      rules.addAll([
        DestinationReachedRule(),         // Priorité 95 (haute)
        ObstacleOnGpsRouteRule(),         // Priorité 75 (moyenne-haute)
        GpsLostDuringNavigationRule(),    // Priorité 65 (moyenne)
        WaypointReachedRule(),            // Priorité 40 (moyenne)
        GpsNavigationRule(),              // Priorité 10 (basse)
      ]);
    }
    
    return rules;
  }

  /// MÉTHODE PRINCIPALE: Évalue un snapshot et retourne UNE instruction
  /// 
  /// Le snapshot contient TOUT (obstacles + GPS).
  /// Cette méthode évalue les règles par ordre de priorité et
  /// retourne l'instruction de la première règle qui match.
  /// 
  /// Processus:
  /// 1. Parcourt les règles par ordre de priorité décroissante
  /// 2. Applique la première règle qui correspond (matches = true)
  /// 3. Retourne l'instruction générée
  /// 4. Gère la déduplication pour éviter les répétitions
  InstructionGuidage evaluate(SensorSnapshot snapshot) {
    _lastEvaluationTime = snapshot.timestamp;

    // Parcourt les règles par ordre de priorité
    for (final rule in rules) {
      if (rule.matches(snapshot)) {
        final instruction = rule.apply(snapshot);
        
        // Log pour debug
        print('🎯 Règle appliquée : ${rule.name} (priorité ${rule.priority})');
        
        // Vérifie si l'instruction est différente de la précédente
        if (_shouldGenerateInstruction(instruction)) {
          _lastInstruction = instruction;
          return instruction;
        } else {
          // Instruction identique à la précédente, on ne la répète pas
          // sauf si elle est urgente (immediate = true)
          if (instruction.immediate) {
            return instruction;
          }
        }
      }
    }

    // Ne devrait jamais arriver car ClearPathRule s'applique toujours
    throw StateError('Aucune règle applicable - vérifier ClearPathRule');
  }

  /// Évalue plusieurs snapshots en séquence
  /// Utile pour analyser une trajectoire complète
  List<InstructionGuidage> evaluateSequence(List<SensorSnapshot> snapshots) {
    final instructions = <InstructionGuidage>[];
    
    for (final snapshot in snapshots) {
      final instruction = evaluate(snapshot);
      if (_shouldGenerateInstruction(instruction)) {
        instructions.add(instruction);
      }
    }
    
    return instructions;
  }

  /// Détermine si une instruction doit être générée
  /// Évite les répétitions inutiles du même message
  bool _shouldGenerateInstruction(InstructionGuidage instruction) {
    // Première instruction ou pas d'historique
    if (_lastInstruction == null) {
      return true;
    }

    // Les instructions urgentes sont toujours générées
    if (instruction.immediate) {
      return true;
    }

    // Les instructions différentes sont générées
    if (instruction.message != _lastInstruction!.message) {
      return true;
    }

    // Même message mais type différent = génère
    if (instruction.type != _lastInstruction!.type) {
      return true;
    }

    // Sinon, on évite la répétition
    return false;
  }

  /// Réinitialise l'historique des instructions
  /// Utile pour forcer la régénération d'instructions
  void reset() {
    _lastInstruction = null;
    _lastEvaluationTime = null;
  }

  /// Retourne la dernière instruction générée
  InstructionGuidage? get lastInstruction => _lastInstruction;

  /// Retourne le timestamp de la dernière évaluation
  int? get lastEvaluationTime => _lastEvaluationTime;

  /// Statistiques du moteur (pour debug)
  Map<String, dynamic> getStatistics() {
    return {
      'rulesCount': rules.length,
      'lastEvaluationTime': _lastEvaluationTime,
      'hasLastInstruction': _lastInstruction != null,
      'lastInstructionType': _lastInstruction?.type.toString(),
      'lastInstructionMessage': _lastInstruction?.message,
      'rulesPriorities': rules.map((r) => '${r.name}: ${r.priority}').toList(),
    };
  }

  /// Teste une règle spécifique contre un snapshot (pour debug)
  bool testRule(String ruleName, SensorSnapshot snapshot) {
    final rule = rules.firstWhere(
      (r) => r.name == ruleName,
      orElse: () => throw ArgumentError('Règle "$ruleName" introuvable'),
    );
    return rule.matches(snapshot);
  }

  /// Génère un rapport d'évaluation détaillé (pour debug)
  String evaluateWithReport(SensorSnapshot snapshot) {
    final buffer = StringBuffer();
    buffer.writeln('=== RAPPORT D\'ÉVALUATION ===');
    buffer.writeln('Snapshot: $snapshot');
    buffer.writeln('\nRègles évaluées:');
    
    for (final rule in rules) {
      final matches = rule.matches(snapshot);
      buffer.writeln('  [${matches ? 'X' : ' '}] ${rule.name} (priorité: ${rule.priority})');
      
      if (matches) {
        final instruction = rule.apply(snapshot);
        buffer.writeln('      → Instruction: "${instruction.message}"');
        buffer.writeln('      → Type: ${instruction.type}');
        buffer.writeln('      → Immédiat: ${instruction.immediate}');
        break; // Première règle applicable trouvée
      }
    }
    
    return buffer.toString();
  }
}