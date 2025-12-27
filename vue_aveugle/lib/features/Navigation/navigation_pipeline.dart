// lib/features/navigation/navigation_pipeline.dart

import 'dart:async';
import '../detection/domain/instruction_guidage.dart';
import '../detection/domain/sensor_snapshot.dart';
import 'timing_controller.dart';
import 'audio_feedback.dart';

/// Pipeline principal de navigation
/// Coordonne l'ensemble du flux : capteurs → système expert → timing → audio
/// 
/// Ce module ne fait PAS partie du système expert, il l'UTILISE
class NavigationPipeline {
  final TimingController _timingController;
  final AudioFeedback _audioFeedback;
  
  /// Instruction en cours d'exécution
  InstructionGuidage? _currentInstruction;
  
  /// État de la navigation
  NavigationState _state = NavigationState.idle;
  
  /// Stream des états de navigation
  final _stateController = StreamController<NavigationState>.broadcast();
  
  /// Position de départ pour calculer la distance parcourue
  SensorSnapshot? _startPosition;

  NavigationPipeline({
    required TimingController timingController,
    required AudioFeedback audioFeedback,
  })  : _timingController = timingController,
        _audioFeedback = audioFeedback;

  /// Stream des changements d'état
  Stream<NavigationState> get stateStream => _stateController.stream;

  /// État actuel
  NavigationState get state => _state;

  /// Instruction en cours
  InstructionGuidage? get currentInstruction => _currentInstruction;

  /// MÉTHODE PRINCIPALE: Traite une nouvelle instruction du système expert
  /// 
  /// Processus:
  /// 1. Vérifie si l'instruction est urgente (immediate=true)
  /// 2. Si urgente : interrompt tout et annonce immédiatement
  /// 3. Sinon : met en file d'attente
  /// 4. Lance le suivi de distance si nécessaire
  Future<void> processInstruction(
    InstructionGuidage instruction,
    SensorSnapshot currentSnapshot,
  ) async {
    // Instruction urgente : priorité absolue
    if (instruction.immediate) {
      await _handleImmediateInstruction(instruction, currentSnapshot);
      return;
    }

    // Instruction normale : mise en file d'attente
    await _handleNormalInstruction(instruction, currentSnapshot);
  }

  /// Traite une instruction urgente (interruption)
  Future<void> _handleImmediateInstruction(
    InstructionGuidage instruction,
    SensorSnapshot currentSnapshot,
  ) async {
    // Interrompre toute instruction en cours
    await _audioFeedback.interrupt();
    
    // Mettre à jour l'état
    _currentInstruction = instruction;
    _updateState(NavigationState.alerting);
    
    // Annoncer immédiatement
    await _audioFeedback.speak(instruction.message, priority: AudioPriority.urgent);
    
    // Si l'instruction nécessite un mouvement, suivre la distance
    if (instruction.requiresMovement) {
      _startPosition = currentSnapshot;
      _updateState(NavigationState.navigating);
      _timingController.startTracking(
        targetDistance: instruction.distanceMeters!,
        onReached: () => _handleDistanceReached(instruction),
      );
    } else {
      // Instruction immédiate sans mouvement (ex: "Arrêtez-vous")
      _updateState(NavigationState.idle);
    }
  }

  /// Traite une instruction normale (guidage)
  Future<void> _handleNormalInstruction(
    InstructionGuidage instruction,
    SensorSnapshot currentSnapshot,
  ) async {
    // Attendre que l'instruction précédente soit terminée
    if (_state == NavigationState.speaking) {
      await _audioFeedback.waitForCompletion();
    }
    
    _currentInstruction = instruction;
    _updateState(NavigationState.speaking);
    
    // Annoncer l'instruction
    await _audioFeedback.speak(instruction.message, priority: AudioPriority.normal);
    
    // Si l'instruction nécessite un mouvement
    if (instruction.requiresMovement) {
      _startPosition = currentSnapshot;
      _updateState(NavigationState.navigating);
      _timingController.startTracking(
        targetDistance: instruction.distanceMeters!,
        onReached: () => _handleDistanceReached(instruction),
      );
    } else {
      _updateState(NavigationState.idle);
    }
  }

  /// Appelé quand la distance cible est atteinte
  Future<void> _handleDistanceReached(InstructionGuidage instruction) async {
    // Si une action de suivi est définie, l'annoncer
    if (instruction.hasFollowUp) {
      final followUpMessage = _getFollowUpMessage(instruction.followUpAction!);
      await _audioFeedback.speak(followUpMessage, priority: AudioPriority.normal);
    }
    
    _currentInstruction = null;
    _startPosition = null;
    _updateState(NavigationState.idle);
  }

  /// Traduit l'action de suivi en message vocal
  String _getFollowUpMessage(String action) {
    switch (action) {
      case 'TURN_LEFT':
        return 'Tournez à gauche maintenant.';
      case 'TURN_RIGHT':
        return 'Tournez à droite maintenant.';
      case 'STOP':
        return 'Arrêtez-vous.';
      case 'CONTINUE':
        return 'Continuez tout droit.';
      default:
        return 'Action suivante : $action';
    }
  }

  /// Met à jour le snapshot de position pour le calcul de distance
  void updatePosition(SensorSnapshot snapshot) {
    if (_state == NavigationState.navigating && _startPosition != null) {
      final distance = _timingController.calculateDistance(
        _startPosition!,
        snapshot,
      );
      _timingController.updateDistance(distance);
    }
  }

  /// Vérifie si l'utilisateur dévie de la trajectoire
  /// Peut générer une alerte de correction
  bool checkTrajectoryDeviation(SensorSnapshot snapshot) {
    if (_state == NavigationState.navigating && _startPosition != null) {
      // Calculer la déviation angulaire
      final yawDeviation = (snapshot.yaw - _startPosition!.yaw).abs();
      
      // Si déviation > 20°, alerte
      if (yawDeviation > 20.0) {
        return true;
      }
    }
    return false;
  }

  /// Pause la navigation
  void pause() {
    _timingController.pause();
    _audioFeedback.pause();
    _updateState(NavigationState.paused);
  }

  /// Reprend la navigation
  void resume() {
    _timingController.resume();
    _audioFeedback.resume();
    _updateState(_currentInstruction != null 
        ? NavigationState.navigating 
        : NavigationState.idle);
  }

  /// Arrête complètement la navigation
  Future<void> stop() async {
    _timingController.stop();
    await _audioFeedback.stop();
    _currentInstruction = null;
    _startPosition = null;
    _updateState(NavigationState.idle);
  }

  /// Met à jour l'état et notifie les listeners
  void _updateState(NavigationState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Libère les ressources
  void dispose() {
    _timingController.dispose();
    _stateController.close();
  }

  /// Statistiques pour debug
  Map<String, dynamic> getStatistics() {
    return {
      'state': _state.toString(),
      'hasCurrentInstruction': _currentInstruction != null,
      'currentInstructionMessage': _currentInstruction?.message,
      'timingStats': _timingController.getStatistics(),
      'audioStats': _audioFeedback.getStatistics(),
    };
  }
}

/// États possibles de la navigation
enum NavigationState {
  /// Inactif, en attente d'instruction
  idle,
  
  /// En train d'annoncer une instruction
  speaking,
  
  /// En train de naviguer (suivi de distance)
  navigating,
  
  /// En alerte (danger immédiat)
  alerting,
  
  /// En pause
  paused,
}