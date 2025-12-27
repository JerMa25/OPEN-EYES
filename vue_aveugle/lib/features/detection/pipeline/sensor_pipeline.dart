// lib/features/detection/pipeline/sensor_pipeline.dart
// VERSION FINALE INTÉGRÉE

// ===== IMPORTS MODIFIÉS =====
import 'dart:async';
import '../models/sensor_packet.dart';
import 'sensor_filter.dart';
import 'sensor_state.dart';
import '../domain/sensor_state_adapter.dart';   // ← AJOUT
import '../domain/expert_engine.dart';          // ← AJOUT
import '../domain/sensor_snapshot.dart';        // ← AJOUT
import '../domain/instruction_guidage.dart';    // ← AJOUT
import '../../navigation/route_navigator.dart'; // ← AJOUT
import '../../../core/services/ble_service.dart';

class SensorPipeline {
  final BleService bleService;
  final SensorFilter filter;
  
  // ===== AJOUT : Système Expert et GPS =====
  final ExpertEngine? expertEngine;
  final RouteNavigator? routeNavigator;
  final Function(InstructionGuidage, SensorSnapshot)? onInstruction;
  // ==========================================

  final StreamController<SensorState> _stateStreamController =
      StreamController<SensorState>.broadcast();

  Stream<SensorState> get stateStream => _stateStreamController.stream;

  SensorState? _lastState;
  StreamSubscription<SensorPacket>? _bleSubscription;
  bool _isActive = false;
  bool get isActive => _isActive;

  int _packetsReceived = 0;
  int _packetsProcessed = 0;
  int _packetsErrored = 0;

  // ===== CONSTRUCTEUR MODIFIÉ =====
  SensorPipeline({
    required this.bleService,
    SensorFilter? filter,
    this.expertEngine,        // ← AJOUT
    this.routeNavigator,      // ← AJOUT
    this.onInstruction,       // ← AJOUT
  }) : filter = filter ?? SensorFilter();
  // =================================

  Future<void> start() async {
    if (_isActive) {
      print('⚠️ Pipeline déjà actif, ignorant start()');
      return;
    }

    if (!bleService.isConnected) {
      throw Exception(
        'Impossible de démarrer le pipeline : BLE non connecté',
      );
    }

    print('🚀 Démarrage du pipeline de traitement...');

    filter.reset();
    _packetsReceived = 0;
    _packetsProcessed = 0;
    _packetsErrored = 0;

    _bleSubscription = bleService.dataStream.listen(
      _processPacket,
      onError: _handleError,
      onDone: _handleStreamClosed,
      cancelOnError: false,
    );

    _isActive = true;
    print('✅ Pipeline actif et en écoute');
  }

  // ===== MÉTHODE MODIFIÉE : Traitement des paquets =====
  void _processPacket(SensorPacket rawPacket) {
    try {
      _packetsReceived++;

      if (!_validatePacket(rawPacket)) {
        print('❌ Paquet invalide rejeté');
        _packetsErrored++;
        return;
      }

      final SensorPacket filteredPacket = filter.filter(rawPacket);
      print('🔄 Paquet filtré : ${filteredPacket.toString()}');

      final SensorState newState = SensorState.fromPacket(
        filteredPacket,
        previousState: _lastState,
      );
      print('📊 État généré : ${newState.situationDescription}');

      _lastState = newState;
      _stateStreamController.add(newState);

      // ===== AJOUT 1 : Mettre à jour position GPS =====
      if (routeNavigator != null) {
        routeNavigator!.updatePosition(newState.latestPacket.gps);
      }
      // ================================================

      // ===== AJOUT 2 : Traiter avec système expert =====
      if (expertEngine != null) {
        _processWithExpertSystem(newState);
      }
      // ==================================================

      _packetsProcessed++;

      if (_packetsReceived % 10 == 0) {
        _logStats();
      }
    } catch (e, stackTrace) {
      print('❌ Erreur lors du traitement du paquet : $e');
      print('Stack trace : $stackTrace');
      _packetsErrored++;
    }
  }

  // ===== NOUVELLE MÉTHODE : Traitement par système expert =====
  void _processWithExpertSystem(SensorState state) {
    try {
      // 1. Validation préalable
      if (!SensorStateAdapter.isValidState(state)) {
        final reason = SensorStateAdapter.diagnoseInvalidState(state);
        print('⚠️ État invalide pour système expert : $reason');
        return;
      }

      // 2. Convertir en SensorSnapshot COMPLET (capteurs + GPS)
      final snapshot = SensorStateAdapter.toSnapshot(
        state,
        routeNavigator, // ← Injection du contexte GPS
      );
      
      // Log détaillé
      print('🧠 Snapshot système expert :');
      print('   Obstacles : F=${snapshot.distanceFront.toStringAsFixed(1)}m, '
            'L=${snapshot.distanceLeft.toStringAsFixed(1)}m, '
            'R=${snapshot.distanceRight.toStringAsFixed(1)}m');
      print('   Hauteur: ${snapshot.obstacleHigh}, Eau: ${snapshot.waterDetected}');
      print('   Orientation : Yaw=${snapshot.yaw.toStringAsFixed(0)}°');
      
      if (snapshot.hasActiveDestination) {
        print('   🗺️ GPS actif :');
        print('      Cap cible: ${snapshot.targetBearing!.toStringAsFixed(0)}°');
        print('      Déviation: ${snapshot.headingDeviation!.toStringAsFixed(0)}°');
        print('      Distance destination: ${snapshot.distanceToDestination!.toStringAsFixed(0)}m');
        print('      Destination: ${snapshot.destinationName ?? "Inconnue"}');
      } else {
        print('   🗺️ Pas de destination active');
      }

      // 3. Évaluer avec le système expert (DÉCISION UNIQUE)
      final instruction = expertEngine!.evaluate(snapshot);
      
      print('💬 Instruction générée :');
      print('   Message: "${instruction.message}"');
      print('   Type: ${instruction.type}');
      print('   Immédiat: ${instruction.immediate}');
      print('   Distance: ${instruction.distanceMeters?.toStringAsFixed(1)}m');
      print('   Action: ${instruction.followUpAction}');

      // 4. Notifier le callback (vers NavigationPipeline)
      if (onInstruction != null) {
        onInstruction!(instruction, snapshot);
      }

    } catch (e, stackTrace) {
      print('❌ Erreur système expert : $e');
      print('Stack trace : $stackTrace');
    }
  }
  // ================================================================

  bool _validatePacket(SensorPacket packet) {
    if (packet.age > 5000) {
      print('⚠️ Paquet trop ancien : ${packet.age}ms');
      return false;
    }

    try {
      final imu = packet.imu;
    } catch (e) {
      print('⚠️ Données IMU invalides : $e');
      return false;
    }

    final obstacles = packet.obstacles;
    if (obstacles.front == null &&
        obstacles.left == null &&
        obstacles.right == null) {
      print('⚠️ Aucune donnée d\'obstacle disponible');
    }

    return true;
  }

  void _handleError(Object error, StackTrace stackTrace) {
    print('❌ Erreur dans le stream BLE : $error');
    print('Stack trace : $stackTrace');
    _packetsErrored++;
  }

  void _handleStreamClosed() {
    print('⚠️ Stream BLE fermé');
    _isActive = false;
  }

  Future<void> stop() async {
    if (!_isActive) {
      print('⚠️ Pipeline déjà arrêté');
      return;
    }

    print('🛑 Arrêt du pipeline...');
    await _bleSubscription?.cancel();
    _bleSubscription = null;
    _isActive = false;
    _logStats();
    print('✅ Pipeline arrêté');
  }

  Future<void> restart() async {
    print('🔄 Redémarrage du pipeline...');
    await stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await start();
  }

  void _logStats() {
    final successRate = _packetsReceived > 0
        ? (_packetsProcessed / _packetsReceived * 100).toStringAsFixed(1)
        : '0.0';

    final errorRate = _packetsReceived > 0
        ? (_packetsErrored / _packetsReceived * 100).toStringAsFixed(1)
        : '0.0';

    print('📈 Stats Pipeline : '
        'Reçus=$_packetsReceived, '
        'Traités=$_packetsProcessed ($successRate%), '
        'Erreurs=$_packetsErrored ($errorRate%)');

    print('🔧 Stats Filtre : ${filter.getStats()}');
    
    // ===== AJOUT : Stats GPS =====
    if (routeNavigator != null) {
      final gpsStats = routeNavigator!.getStatistics();
      print('🗺️ Stats GPS : ${gpsStats}');
    }
    // =============================
  }

  Map<String, dynamic> getStats() {
    return {
      'isActive': _isActive,
      'packetsReceived': _packetsReceived,
      'packetsProcessed': _packetsProcessed,
      'packetsErrored': _packetsErrored,
      'successRate': _packetsReceived > 0
          ? _packetsProcessed / _packetsReceived
          : 0.0,
      'errorRate':
          _packetsReceived > 0 ? _packetsErrored / _packetsReceived : 0.0,
      'filterStats': filter.getStats(),
      'lastState': _lastState?.toJson(),
      'gpsStats': routeNavigator?.getStatistics(), // ← AJOUT
    };
  }

  Future<void> dispose() async {
    print('🧹 Nettoyage du SensorPipeline...');
    await stop();
    await _stateStreamController.close();
    _lastState = null;
    print('✅ SensorPipeline nettoyé');
  }

  SensorState? get lastState => _lastState;
  bool get hasProcessedData => _lastState != null;

  double get successRate {
    if (_packetsReceived == 0) return 0.0;
    return _packetsProcessed / _packetsReceived;
  }

  double get errorRate {
    if (_packetsReceived == 0) return 0.0;
    return _packetsErrored / _packetsReceived;
  }
}