// lib/services/contact_service.dart
// Service Contact définitif - Cameroun

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/contact.dart';
import '../config.dart';
import 'api_client.dart';

class ContactService {
  final ApiClient _api = ApiClient();

  // ══════════════════════════════════════════════════════════════════════════
  // 🔐 PERMISSIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> requestSmsPermission() async {
  final sms = await Permission.sms.request();
  final phone = await Permission.phone.request();
  return sms.isGranted && phone.isGranted;
  }

  Future<bool> hasSmsPermissions() async {
  final sms = await Permission.sms.isGranted;
  final phone = await Permission.phone.isGranted;
  return sms && phone;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📤 ENVOI SMS À LA CANNE
  // ══════════════════════════════════════════════════════════════════════════

  /// Envoie une commande SMS à la canne
  Future<SmsResult> _envoyerCommande(String commande) async {
  _log('📤 Commande: $commande');

  if (!await hasSmsPermissions()) {
    if (!await requestSmsPermission()) {
      return SmsResult(success: false, error: 'Permission SMS refusée');
    }
  }

  final uri = Uri(
    scheme: 'sms',
    path: AppConfig.cannePhoneDisplay,
    queryParameters: {'body': commande},
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return SmsResult(
      success: true,
      requiresUserAction: true,
      message: 'Appuyez sur Envoyer',
    );
  }

  return SmsResult(success: false, error: 'Impossible d’ouvrir l’app SMS');
}


  // ══════════════════════════════════════════════════════════════════════════
  // 📱 COMMANDES CANNE
  // ══════════════════════════════════════════════════════════════════════════

  /// Ajouter un contact dans la canne
  Future<SmsResult> ajouterContactCanne(Contact contact) async {
  final cmd = contact.buildAddCommand(pin: AppConfig.smsPin);
  return await _envoyerCommande(cmd);
  }


  /// Supprimer un contact de la canne
  /// Format: DEL:PIN:+237XXXXXXXXX
  Future<SmsResult> supprimerContactCanne(String telephone) async {
    String tel = _normaliserTel(telephone);
    String cmd = 'DEL:${AppConfig.smsPin}:$tel';
    return await _envoyerCommande(cmd);
  }

  /// Définir le contact d'urgence
  /// Format: URG:PIN:+237XXXXXXXXX
  Future<SmsResult> definirUrgence(String telephone) async {
    String tel = _normaliserTel(telephone);
    String cmd = 'URG:${AppConfig.smsPin}:$tel';
    return await _envoyerCommande(cmd);
  }

  /// Lister les contacts de la canne
  /// Format: LIST:PIN
  Future<SmsResult> listerContactsCanne() async {
    String cmd = 'LIST:${AppConfig.smsPin}';
    return await _envoyerCommande(cmd);
  }

  /// Effacer tous les contacts de la canne
  /// Format: CLEAR:PIN
  Future<SmsResult> effacerContactsCanne() async {
    String cmd = 'CLEAR:${AppConfig.smsPin}';
    return await _envoyerCommande(cmd);
  }

  /// Tester l'envoi d'alerte
  /// Format: TEST:PIN
  Future<SmsResult> testerAlerte() async {
    String cmd = 'TEST:${AppConfig.smsPin}';
    return await _envoyerCommande(cmd);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📡 API BACKEND
  // ══════════════════════════════════════════════════════════════════════════

  /// Récupérer tous les contacts
  Future<List<Contact>> fetchAllContacts() async {
    _log('📡 Chargement contacts...');
    final response = await _api.get('/api/contacts/${AppConfig.canneId}/');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      _log('✅ ${data.length} contacts');
      return data.map((j) => Contact.fromJson(j)).toList();
    }
    throw Exception('Erreur chargement');
  }

  /// Enregistrer un contact (backend + canne)
  Future<RegistrationResult> registerContact(Contact contact) async {
    _log('📡 Enregistrement: ${contact.fullName}');

    // 1. Backend
    final response = await _api.post(
      '/api/contacts/register-sms/${AppConfig.canneId}/${AppConfig.defaultRole}/${contact.telephone}/',
      data: contact.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur backend');
    }

    final id = response.data['id'] as int?;
    final saved = contact.copyWith(id: id);
    _log('✅ Backend OK (ID: $id)');

    // 2. Canne
    SmsResult? sms;
    try {
      sms = await ajouterContactCanne(saved);
    } catch (e) {
      _log('⚠️ SMS: $e');
      sms = SmsResult(success: false, error: '$e');
    }

    return RegistrationResult(contact: saved, smsResult: sms);
  }

  /// Mettre à jour un contact
  Future<RegistrationResult> updateContact(String ancienTel, Contact contact) async {
    _log('📡 Mise à jour: $ancienTel -> ${contact.telephone}');

    final response = await _api.put(
      '/api/contacts/${AppConfig.canneId}/contacts/$ancienTel/${AppConfig.defaultRole}/update/',
      data: contact.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur backend');
    }

    // Mettre à jour canne: supprimer ancien + ajouter nouveau
    await supprimerContactCanne(ancienTel);
    await Future.delayed(const Duration(seconds: 2));
    final sms = await ajouterContactCanne(contact);

    return RegistrationResult(contact: contact, smsResult: sms);
  }

  /// Supprimer un contact
  Future<DeletionResult> deleteContact(int id, String telephone) async {
    _log('📡 Suppression: $id');

    final response = await _api.post(
      '/api/contacts/${AppConfig.canneId}/contacts/$id/${AppConfig.defaultRole}/delete/',
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur backend');
    }

    final sms = await supprimerContactCanne(telephone);
    return DeletionResult(backendOk: true, smsResult: sms);
  }

  /// Synchroniser tous les contacts vers la canne
  Future<SyncResult> syncAllContacts() async {
    _log('🔄 Synchronisation...');
    
    // Effacer la canne
    await effacerContactsCanne();
    await Future.delayed(const Duration(seconds: 3));

    // Récupérer et envoyer
    final contacts = await fetchAllContacts();
    int ok = 0;

    for (var contact in contacts) {
      final result = await ajouterContactCanne(contact);
      if (result.success) ok++;
      await Future.delayed(const Duration(seconds: 2));
    }

    return SyncResult(total: contacts.length, success: ok);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔧 UTILITAIRES
  // ══════════════════════════════════════════════════════════════════════════

  String _normaliserTel(String tel) {
    tel = tel.trim().replaceAll(' ', '').replaceAll('-', '');
    if (tel.startsWith('6') || tel.startsWith('2') || tel.startsWith('9')) {
      return '+237$tel';
    } else if (tel.startsWith('237')) {
      return '+$tel';
    } else if (!tel.startsWith('+')) {
      return '+$tel';
    }
    return tel;
  }

  void _log(String msg) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('[ContactService] $msg');
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 📦 CLASSES RÉSULTAT
// ══════════════════════════════════════════════════════════════════════════════

class SmsResult {
  final bool success;
  final String? error;
  final String? message;
  final bool requiresUserAction;

  SmsResult({
    required this.success,
    this.error,
    this.message,
    this.requiresUserAction = false,
  });
}

class RegistrationResult {
  final Contact contact;
  final SmsResult? smsResult;

  RegistrationResult({required this.contact, this.smsResult});

  bool get backendOk => contact.id != null;
  bool get smsOk => smsResult?.success ?? false;
}

class DeletionResult {
  final bool backendOk;
  final SmsResult? smsResult;

  DeletionResult({required this.backendOk, this.smsResult});
}

class SyncResult {
  final int total;
  final int success;

  SyncResult({required this.total, required this.success});
  
  bool get complete => success == total;
}