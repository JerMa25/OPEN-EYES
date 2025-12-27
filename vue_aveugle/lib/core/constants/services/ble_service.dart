// lib/core/services/ble_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../features/detection/models/sensor_packet.dart';

/// Service centralisé pour la gestion Bluetooth Low Energy
/// 
/// Cette classe est responsable de TOUTE la communication BLE avec l'ESP32.
/// Elle gère :
/// - Le scan des périphériques BLE à proximité
/// - La connexion à l'ESP32 spécifique
/// - L'abonnement aux notifications des caractéristiques BLE
/// - La réception et le parsing des données brutes
/// - L'émission des paquets parsés vers le pipeline
/// 
/// Pourquoi un service séparé ? Séparation des responsabilités :
/// - Le BLE est une couche technique (hardware)
/// - Le pipeline est une couche métier (traitement)
/// Cette séparation facilite les tests et la maintenance
class BleService {
  /// UUID du service BLE principal de l'ESP32
  /// 
  /// Pourquoi un UUID spécifique ? En BLE, les services sont identifiés
  /// par des UUID uniques. Cet UUID doit correspondre EXACTEMENT à celui
  /// programmé dans l'ESP32, sinon la connexion échouera.
  /// 
  /// Format : 8-4-4-4-12 caractères hexadécimaux
  /// Exemple : 4fafc201-1fb5-459e-8fcc-c5c9c331914b
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// UUID de la caractéristique BLE qui transmet les données capteurs
  /// 
  /// Pourquoi une caractéristique ? En BLE, un service contient plusieurs
  /// caractéristiques. Chaque caractéristique est un canal de communication
  /// pour un type de données spécifique. Ici, on transmet les JSON capteurs.
  static const String characteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  /// Nom du périphérique ESP32 à rechercher lors du scan
  /// 
  /// Pourquoi filtrer par nom ? Pour éviter de se connecter à d'autres
  /// périphériques BLE environnants (montres, écouteurs, etc.)
  static const String deviceName = 'OPEN-EYES';

  /// Périphérique BLE actuellement connecté (null si déconnecté)
  /// 
  /// Pourquoi nullable ? Parce qu'on n'est pas toujours connecté.
  /// On vérifie cette variable avant d'envoyer des commandes.
  BluetoothDevice? _connectedDevice;

  /// Caractéristique BLE active pour la réception de données
  /// 
  /// Pourquoi séparer device et characteristic ? Parce qu'un device
  /// contient plusieurs caractéristiques. On garde une référence directe
  /// à celle qui nous intéresse pour optimiser les performances.
  BluetoothCharacteristic? _sensorCharacteristic;

  /// Stream de paquets de données capteurs parsés
  /// 
  /// Pourquoi un StreamController ? Pour transformer les notifications BLE
  /// (bytes bruts) en objets Dart fortement typés (SensorPacket) que le
  /// reste de l'application peut consommer facilement.
  /// 
  /// Le pattern Stream permet une architecture réactive : dès qu'une donnée
  /// arrive, elle est automatiquement propagée à tous les listeners.
  final StreamController<SensorPacket> _dataStreamController =
      StreamController<SensorPacket>.broadcast();

  /// Stream public des paquets de données
  /// 
  /// Pourquoi exposer un Stream en lecture seule ? Encapsulation :
  /// - Le reste de l'app peut LIRE les données
  /// - Seul ce service peut ÉCRIRE dans le stream
  /// Cela évite les modifications accidentelles ou malveillantes.
  Stream<SensorPacket> get dataStream => _dataStreamController.stream;

  /// Stream de l'état de connexion BLE
  /// 
  /// Pourquoi un stream séparé pour l'état ? Permet à l'UI d'afficher
  /// un indicateur de connexion sans avoir à gérer les données capteurs.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  /// Stream public de l'état de connexion
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Getter : indique si on est actuellement connecté
  /// 
  /// Pourquoi un getter ? Pour vérification rapide de l'état sans
  /// avoir à s'abonner au stream. Utile pour des conditions if simples.
  bool get isConnected => _connectedDevice != null;

  /// Subscription aux notifications BLE (pour pouvoir s'en désabonner)
  /// 
  /// Pourquoi garder la subscription ? En Flutter, il faut explicitement
  /// canceller les subscriptions pour éviter les fuites mémoire.
  StreamSubscription<List<int>>? _notificationSubscription;

  /// Scanne les périphériques BLE environnants et trouve l'ESP32
  /// 
  /// Pourquoi une méthode asynchrone ? Le scan BLE prend du temps
  /// (plusieurs secondes) et on ne veut pas bloquer l'UI.
  /// 
  /// Retourne le périphérique trouvé ou null si non trouvé
  Future<BluetoothDevice?> scanForDevice({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Étape 1 : Vérifier que le Bluetooth est activé
      // Pourquoi vérifier ? Si le BT est éteint, le scan échouera.
      // Mieux vaut détecter cela immédiatement avec un message clair.
      final isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        throw Exception('Bluetooth non disponible sur cet appareil');
      }

      // Étape 2 : Vérifier que le Bluetooth est allumé
      final isOn = await FlutterBluePlus.isOn;
      if (!isOn) {
        throw Exception('Bluetooth désactivé. Veuillez l\'activer.');
      }

      // Étape 3 : Démarrer le scan BLE
      // Pourquoi timeout ? Pour éviter un scan infini qui viderait la batterie
      print('🔍 Début du scan BLE (timeout: ${timeout.inSeconds}s)...');
      await FlutterBluePlus.startScan(timeout: timeout);

      // Étape 4 : Écouter les résultats du scan
      // Pourquoi firstWhere ? On s'arrête dès qu'on trouve notre ESP32,
      // pas besoin de continuer le scan après.
      final result = await FlutterBluePlus.scanResults.firstWhere(
        (results) => results.any(
          (r) => r.device.name == deviceName,
        ),
        orElse: () => [],
      ).timeout(
        timeout,
        onTimeout: () => [],
      );

      // Étape 5 : Arrêter le scan pour économiser la batterie
      // Pourquoi arrêter manuellement ? Le scan peut continuer même après
      // avoir trouvé le device si on ne l'arrête pas explicitement
      await FlutterBluePlus.stopScan();

      // Étape 6 : Extraire le device de résultat
      if (result.isEmpty) {
        print('❌ ESP32 non trouvé après ${timeout.inSeconds}s');
        return null;
      }

      final device = result.firstWhere(
        (r) => r.device.name == deviceName,
      ).device;

      print('✅ ESP32 trouvé : ${device.name} (${device.id})');
      return device;
    } catch (e) {
      print('❌ Erreur pendant le scan BLE : $e');
      // On s'assure que le scan est arrêté même en cas d'erreur
      await FlutterBluePlus.stopScan();
      rethrow; // On propage l'erreur pour que l'appelant puisse la gérer
    }
  }

  /// Connecte l'application à l'ESP32 trouvé
  /// 
  /// Pourquoi une méthode séparée ? Séparer scan et connexion permet
  /// de réutiliser les méthodes : on peut scanner plusieurs fois avant
  /// de se connecter, ou se reconnecter à un device déjà scanné.
  Future<void> connect(BluetoothDevice device) async {
    try {
      print('🔗 Connexion à ${device.name}...');

      // Étape 1 : Se déconnecter de tout device précédent
      // Pourquoi ? BLE ne supporte généralement qu'une connexion à la fois
      await disconnect();

      // Étape 2 : Établir la connexion
      // timeout : limite pour éviter une attente infinie
      // autoConnect : false car on veut une connexion immédiate
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      print('✅ Connecté à ${device.name}');
      _connectedDevice = device;
      _connectionStateController.add(true);

      // Étape 3 : Découvrir les services BLE disponibles sur l'ESP32
      // Pourquoi découvrir ? L'ESP32 expose plusieurs services,
      // on doit les lister pour trouver celui qui nous intéresse
      print('🔍 Découverte des services BLE...');
      final services = await device.discoverServices();

      // Étape 4 : Trouver notre service spécifique
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
        orElse: () => throw Exception('Service $serviceUuid non trouvé'),
      );

      print('✅ Service trouvé : $serviceUuid');

      // Étape 5 : Trouver notre caractéristique dans ce service
      _sensorCharacteristic = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase(),
        orElse: () =>
            throw Exception('Caractéristique $characteristicUuid non trouvée'),
      );

      print('✅ Caractéristique trouvée : $characteristicUuid');

      // Étape 6 : Activer les notifications pour recevoir les données
      // Pourquoi notifications ? En BLE, il existe 2 modes :
      // - Read : l'app demande les données (polling, inefficace)
      // - Notify : l'ESP32 envoie automatiquement (push, optimal)
      await _subscribeToNotifications();

      print('🎉 Configuration BLE terminée avec succès');
    } catch (e) {
      print('❌ Erreur de connexion : $e');
      // En cas d'erreur, on nettoie tout
      await disconnect();
      rethrow;
    }
  }

  /// S'abonne aux notifications de la caractéristique capteurs
  /// 
  /// Pourquoi une méthode privée ? C'est un détail d'implémentation interne,
  /// l'appelant n'a pas besoin de savoir comment on s'abonne.
  Future<void> _subscribeToNotifications() async {
    if (_sensorCharacteristic == null) {
      throw Exception('Caractéristique non initialisée');
    }

    // Étape 1 : Activer les notifications sur la caractéristique
    // Cela dit à l'ESP32 : "Envoie-moi les données automatiquement"
    await _sensorCharacteristic!.setNotifyValue(true);

    print('🔔 Notifications activées');

    // Étape 2 : S'abonner au stream de notifications
    // Chaque fois que l'ESP32 envoie des données, on reçoit un événement
    _notificationSubscription = _sensorCharacteristic!.value.listen(
      _onDataReceived,
      onError: _onDataError,
      cancelOnError: false, // Continue même après une erreur
    );
  }

  /// Callback appelé à chaque réception de données BLE
  /// 
  /// Pourquoi un callback ? Pattern Observer : dès que l'ESP32 envoie,
  /// cette méthode est automatiquement appelée avec les bytes reçus.
  /// 
  /// data : tableau de bytes bruts (List<int>) reçu via BLE
  void _onDataReceived(List<int> data) {
    try {
      // Étape 1 : Convertir les bytes en String UTF-8
      // Pourquoi UTF-8 ? C'est l'encodage standard pour le JSON
      // Les bytes sont la représentation binaire du texte JSON
      final String jsonString = utf8.decode(data);

      print('📦 Données reçues : $jsonString');

      // Étape 2 : Parser le String JSON en Map Dart
      // Pourquoi json.decode ? Transforme le texte '{"a":1}' en Map réel {a: 1}
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Étape 3 : Créer un SensorPacket fortement typé
      // Pourquoi ? Pour avoir des objets Dart avec autocomplétion,
      // validation, et méthodes utilitaires plutôt que des Map génériques
      final SensorPacket packet = SensorPacket.fromJson(jsonData);

      // Étape 4 : Vérifier la fraîcheur des données
      // Pourquoi ? Des données trop anciennes sont dangereuses pour la navigation
      if (packet.isStale) {
        print('⚠️ Attention : données périmées (âge: ${packet.age}ms)');
      }

      // Étape 5 : Émettre le paquet vers le stream
      // Tous les listeners du dataStream recevront automatiquement ce paquet
      _dataStreamController.add(packet);

      print('✅ Paquet traité avec succès');
    } catch (e) {
      // Si le parsing échoue, on log l'erreur mais on ne crash pas l'app
      // Pourquoi ? Une donnée corrompue ne doit pas bloquer tout le système
      print('❌ Erreur de parsing des données BLE : $e');
      _onDataError(e);
    }
  }

  /// Callback appelé en cas d'erreur dans le stream de notifications
  /// 
  /// Pourquoi gérer les erreurs séparément ? Pour pouvoir logger,
  /// alerter l'utilisateur, ou tenter une reconnexion automatique
  void _onDataError(Object error) {
    print('❌ Erreur dans le stream de données : $error');

    // On pourrait implémenter ici une logique de reconnexion automatique
    // ou envoyer une alerte à l'utilisateur via un autre stream
  }

  /// Déconnecte proprement du périphérique BLE
  /// 
  /// Pourquoi une déconnexion propre ? Pour libérer les ressources :
  /// - Annuler les subscriptions (éviter fuites mémoire)
  /// - Fermer la connexion BLE (libérer le hardware)
  /// - Nettoyer les variables d'état
  Future<void> disconnect() async {
    try {
      print('🔌 Déconnexion en cours...');

      // Étape 1 : Annuler la subscription aux notifications
      // Pourquoi d'abord ? Pour arrêter de recevoir des données avant
      // de fermer la connexion, évitant ainsi des erreurs de stream
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;

      // Étape 2 : Déconnecter le périphérique BLE
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print('✅ Déconnecté de ${_connectedDevice!.name}');
      }

      // Étape 3 : Nettoyer les variables d'état
      _connectedDevice = null;
      _sensorCharacteristic = null;

      // Étape 4 : Notifier les listeners que la connexion est fermée
      _connectionStateController.add(false);
    } catch (e) {
      print('❌ Erreur pendant la déconnexion : $e');
      // Même en cas d'erreur, on nettoie les variables
      _connectedDevice = null;
      _sensorCharacteristic = null;
      _connectionStateController.add(false);
    }
  }

  /// Workflow complet : scan + connexion en une seule méthode
  /// 
  /// Pourquoi combiner ? Simplification pour l'appelant :
  /// au lieu de scanner puis connecter, il appelle juste cette méthode
  Future<bool> scanAndConnect({
    Duration scanTimeout = const Duration(seconds: 10),
  }) async {
    try {
      // Étape 1 : Scanner pour trouver l'ESP32
      final device = await scanForDevice(timeout: scanTimeout);

      if (device == null) {
        print('❌ ESP32 non trouvé');
        return false;
      }

      // Étape 2 : Se connecter à l'ESP32 trouvé
      await connect(device);

      return true;
    } catch (e) {
      print('❌ Échec de scanAndConnect : $e');
      return false;
    }
  }

  /// Nettoie toutes les ressources du service
  /// 
  /// Pourquoi dispose ? En Flutter, il faut explicitement libérer
  /// les ressources (streams, connexions) pour éviter les fuites mémoire.
  /// Cette méthode doit être appelée quand l'app se ferme.
  Future<void> dispose() async {
    print('🧹 Nettoyage du BleService...');

    // Étape 1 : Se déconnecter proprement
    await disconnect();

    // Étape 2 : Fermer les StreamControllers
    // Pourquoi fermer ? Un StreamController ouvert consomme de la mémoire
    await _dataStreamController.close();
    await _connectionStateController.close();

    print('✅ BleService nettoyé');
  }
}