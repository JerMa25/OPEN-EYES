// lib/features/navigation/audio_feedback.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';

/// Priorité des messages audio
enum AudioPriority {
  /// Message urgent (interruption immédiate)
  urgent,
  
  /// Message normal (file d'attente)
  normal,
  
  /// Message informatif (peut être ignoré si système occupé)
  info,
}

/// Gestionnaire de feedback audio
/// Lit les instructions vocales via écouteurs filaires
/// 
/// ⚠️ IMPORTANT: L'audio passe par écouteurs filaires
/// Le Bluetooth est RÉSERVÉ à l'ESP32
class AudioFeedback {
  final FlutterTts _tts = FlutterTts();
  
  /// File d'attente des messages par priorité
  final _messageQueue = Queue<AudioMessage>();
  
  /// Message en cours de lecture
  AudioMessage? _currentMessage;
  
  /// État du système audio
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  
  /// Completer pour attendre la fin de la lecture
  Completer<void>? _speechCompleter;
  
  /// Statistiques
  int _totalMessagesSpoken = 0;
  int _messagesInterrupted = 0;

  /// Initialise le système de synthèse vocale
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Configuration de la synthèse vocale
    await _tts.setLanguage("fr-FR"); // Français
    await _tts.setSpeechRate(0.5);   // Vitesse de parole (0.5 = 50% plus lent)
    await _tts.setVolume(1.0);       // Volume maximum
    await _tts.setPitch(1.0);        // Pitch normal
    
    // ⚠️ IMPORTANT: Forcer la sortie vers écouteurs filaires
    // Sur Android/iOS, s'assurer que l'audio sort par jack, pas BT
    await _configureAudioOutput();
    
    // Callbacks de fin de lecture
    _tts.setCompletionHandler(() {
      _onSpeechCompleted();
    });
    
    _tts.setErrorHandler((msg) {
      _onSpeechError(msg);
    });
    
    _isInitialized = true;
  }

  /// Configure la sortie audio (écouteurs filaires uniquement)
  Future<void> _configureAudioOutput() async {
    // Code spécifique à la plateforme pour forcer jack audio
    // Sur Android, utiliser AudioManager
    // Sur iOS, utiliser AVAudioSession
    
    // Exemple conceptuel:
    // await _tts.setAudioCategory(
    //   category: AudioCategory.playback,
    //   mode: AudioMode.spokenAudio,
    //   options: [AudioOption.allowBluetooth: false],
    // );
  }

  /// Lit un message vocal
  /// 
  /// [message] : texte à lire
  /// [priority] : priorité du message
  /// [repeat] : nombre de répétitions (par défaut 1)
  Future<void> speak(
    String message, {
    AudioPriority priority = AudioPriority.normal,
    int repeat = 1,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final audioMessage = AudioMessage(
      text: message,
      priority: priority,
      repeatCount: repeat,
    );
    
    // Message urgent : interruption immédiate
    if (priority == AudioPriority.urgent) {
      await interrupt();
      await _speakNow(audioMessage);
    } else {
      // Ajout en file d'attente
      _messageQueue.add(audioMessage);
      _processQueue();
    }
  }

  /// Lit immédiatement un message (bypass de la file)
  Future<void> _speakNow(AudioMessage message) async {
    _currentMessage = message;
    _isSpeaking = true;
    _speechCompleter = Completer<void>();
    
    // Répéter le message si nécessaire
    for (int i = 0; i < message.repeatCount; i++) {
      await _tts.speak(message.text);
      
      // Attendre la fin avant la répétition
      if (i < message.repeatCount - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    _totalMessagesSpoken++;
  }

  /// Traite la file d'attente des messages
  Future<void> _processQueue() async {
    if (_isSpeaking || _isPaused || _messageQueue.isEmpty) {
      return;
    }
    
    // Récupérer le message de plus haute priorité
    final message = _getHighestPriorityMessage();
    
    if (message != null) {
      await _speakNow(message);
    }
  }

  /// Récupère le message de plus haute priorité dans la file
  AudioMessage? _getHighestPriorityMessage() {
    if (_messageQueue.isEmpty) return null;
    
    // Trier par priorité (urgent > normal > info)
    final messages = _messageQueue.toList();
    messages.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    final highest = messages.first;
    _messageQueue.remove(highest);
    return highest;
  }

  /// Appelé quand la lecture est terminée
  void _onSpeechCompleted() {
    _isSpeaking = false;
    _currentMessage = null;
    _speechCompleter?.complete();
    _speechCompleter = null;
    
    // Traiter le prochain message dans la file
    _processQueue();
  }

  /// Appelé en cas d'erreur de lecture
  void _onSpeechError(String error) {
    print('Erreur audio: $error');
    _isSpeaking = false;
    _speechCompleter?.completeError(error);
    _speechCompleter = null;
  }

  /// Interrompt la lecture en cours
  Future<void> interrupt() async {
    if (_isSpeaking) {
      await _tts.stop();
      _messagesInterrupted++;
      _isSpeaking = false;
      _speechCompleter?.complete();
      _speechCompleter = null;
    }
  }

  /// Attend la fin de la lecture en cours
  Future<void> waitForCompletion() async {
    if (_speechCompleter != null) {
      await _speechCompleter!.future;
    }
  }

  /// Met en pause la lecture
  Future<void> pause() async {
    if (_isSpeaking) {
      await _tts.pause();
      _isPaused = true;
    }
  }

  /// Reprend la lecture
  Future<void> resume() async {
    if (_isPaused) {
      // Note: FlutterTts n'a pas de méthode resume()
      // On doit relire le message depuis le début
      _isPaused = false;
      _processQueue();
    }
  }

  /// Arrête complètement le système audio
  Future<void> stop() async {
    await _tts.stop();
    _messageQueue.clear();
    _isSpeaking = false;
    _isPaused = false;
    _currentMessage = null;
    _speechCompleter?.complete();
    _speechCompleter = null;
  }

  /// Vide la file d'attente
  void clearQueue() {
    _messageQueue.clear();
  }

  /// Retourne le nombre de messages en attente
  int get queueLength => _messageQueue.length;

  /// Retourne true si un message est en cours de lecture
  bool get isSpeaking => _isSpeaking;

  /// Retourne true si le système est en pause
  bool get isPaused => _isPaused;

  /// Statistiques pour debug
  Map<String, dynamic> getStatistics() {
    return {
      'isSpeaking': _isSpeaking,
      'isPaused': _isPaused,
      'queueLength': queueLength,
      'currentMessage': _currentMessage?.text,
      'totalMessagesSpoken': _totalMessagesSpoken,
      'messagesInterrupted': _messagesInterrupted,
    };
  }

  /// Teste la synthèse vocale
  Future<void> test() async {
    await speak(
      'Test du système audio. Si vous entendez ce message, le système fonctionne correctement.',
      priority: AudioPriority.normal,
    );
  }

  /// Libère les ressources
  void dispose() {
    _tts.stop();
    _messageQueue.clear();
  }
}

/// Représente un message audio dans la file d'attente
class AudioMessage {
  final String text;
  final AudioPriority priority;
  final int repeatCount;
  final int timestamp;

  AudioMessage({
    required this.text,
    required this.priority,
    this.repeatCount = 1,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;

  /// Durée estimée de lecture (en millisecondes)
  int get estimatedDuration {
    final wordCount = text.split(' ').length;
    // ~150 mots par minute
    final durationPerRepeat = ((wordCount / 150) * 60 * 1000).round();
    return durationPerRepeat * repeatCount;
  }

  @override
  String toString() {
    return 'AudioMessage(text: "$text", priority: $priority, repeat: $repeatCount)';
  }
}

/// Configuration audio recommandée
class AudioConfig {
  /// Vitesse de parole recommandée pour une personne aveugle
  static const double speechRate = 0.5; // 50% plus lent que normal
  
  /// Volume recommandé
  static const double volume = 1.0; // Maximum
  
  /// Pitch recommandé
  static const double pitch = 1.0; // Normal
  
  /// Délai entre deux messages (ms)
  static const int delayBetweenMessages = 500;
  
  /// Délai avant répétition d'un message urgent (ms)
  static const int urgentRepeatDelay = 2000;
}