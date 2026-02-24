// lib/config.dart
// Configuration définitive - Cameroun

import 'package:flutter/foundation.dart';

class AppConfig {
  // ══════════════════════════════════════════════════════════════════════════
  // 🌐 SERVEUR BACKEND
  // ══════════════════════════════════════════════════════════════════════════
  
  /// URL du backend Django
  static const String baseUrl = 'http://172.20.10.6:8000';
  
  /// Timeout HTTP en secondes
  static const int httpTimeout = 15;
  
  /// Nombre de tentatives en cas d'échec
  static const int maxRetries = 3;
  
  // ══════════════════════════════════════════════════════════════════════════
  // 📱 CONFIGURATION CANNE
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Numéro de la canne (sans le +)
  /// C'est le numéro de la carte SIM dans le module GSM de la canne
  //static const int cannePhoneNumber = 237672777581;
  static const int cannePhoneNumber = 237651937920;
  //51937920

  
  /// Alias
  static const int canneId = cannePhoneNumber;
  
  /// Format +237XXXXXXXXX
  static String get cannePhoneDisplay => '+$cannePhoneNumber';
  
  /// Format string
  static String get cannePhoneString => cannePhoneNumber.toString();
  
  // ══════════════════════════════════════════════════════════════════════════
  // 🔐 SÉCURITÉ
  // ══════════════════════════════════════════════════════════════════════════
  
  
  /// Rôle par défaut pour l'API
  static const String defaultRole = 'SUPER_ADMIN';
  
  // ══════════════════════════════════════════════════════════════════════════
  // 👥 TYPES DE CONTACTS
  // ══════════════════════════════════════════════════════════════════════════
  
  static const List<Map<String, String>> contactTypes = [
    {'value': 'FAMILLE', 'label': 'Famille'},
    {'value': 'AMI', 'label': 'Ami'},
    {'value': 'VOISIN', 'label': 'Voisin'},
    {'value': 'SOIGNANT', 'label': 'Soignant'},
    {'value': 'URGENCE', 'label': 'Service d\'urgence'},
    {'value': 'AUTRE', 'label': 'Autre'},
  ];
  
  // ══════════════════════════════════════════════════════════════════════════
  // 🐛 DEBUG
  // ══════════════════════════════════════════════════════════════════════════
  
  static const bool enableDebugLogs = true;
  
  static void debugPrintConfig() {
    if (!enableDebugLogs) return;
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║      CANNE CONNECTÉE - CAMEROUN          ║');
    debugPrint('╠══════════════════════════════════════════╣');
    debugPrint('║ Backend: $baseUrl');
    debugPrint('║ Canne: $cannePhoneDisplay');
    debugPrint('╚══════════════════════════════════════════╝');
  }
}
