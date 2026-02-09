// lib/config.dart
import 'package:flutter/foundation.dart';


class AppConfig {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🌐 CONFIGURATION SERVEUR
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// URL de base du backend Django
  /// ⚠️ Pour tester sur un VRAI téléphone, utiliser l'IP locale de l'ordinateur
  /// Exemples:
  /// - Émulateur Android: 'http://10.0.2.2:8000'
  /// - Téléphone réel: 'http://192.168.x.x:8000' (IP de votre PC)
  static const String baseUrl = 'http://192.168.112.198:8000';
  
  /// Timeout pour les requêtes HTTP (en secondes)
  static const int httpTimeout = 15;
  
  /// Nombre de tentatives de retry en cas d'échec
  static const int maxRetries = 3;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 CONFIGURATION DE LA CANNE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Numéro de téléphone de la canne (sans le +)
  /// Utilisé comme identifiant unique dans le backend
  static const int cannePhoneNumber = 237672777581;
  
  /// Alias pour la compatibilité avec le code existant
  static const int canneId = cannePhoneNumber;
  
  /// Format d'affichage international (+237...)
  static String get cannePhoneDisplay => '+$cannePhoneNumber';
  
  /// Format string pour les API
  static String get cannePhoneString => cannePhoneNumber.toString();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 👤 RÔLES UTILISATEUR
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Rôle par défaut pour les opérations API
  static const String defaultRole = 'SUPER_ADMIN';
  
  /// Types de contacts disponibles
  static const List<Map<String, String>> contactTypes = [
    {'value': 'FAMILLE', 'label': 'Famille'},
    {'value': 'AMI', 'label': 'Ami'},
    {'value': 'SOIGNANT', 'label': 'Soignant'},
    {'value': 'URGENCE', 'label': 'Service d\'urgence'},
    {'value': 'AUTRE', 'label': 'Autre'},
  ];
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 DEBUG
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Active les logs détaillés
  static const bool enableDebugLogs = true;
  
  /// Affiche la configuration actuelle
  static void debugPrintConfig() {
    if (!enableDebugLogs) return;
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║         CONFIGURATION APP                ║');
    debugPrint('╠══════════════════════════════════════════╣');
    debugPrint('║ 🌐 BaseUrl: $baseUrl');
    debugPrint('║ 📱 CanneId: $canneId');
    debugPrint('║ 📞 Phone: $cannePhoneDisplay');
    debugPrint('║ ⏱️ Timeout: ${httpTimeout}s');
    debugPrint('╚══════════════════════════════════════════╝');
  }
}
