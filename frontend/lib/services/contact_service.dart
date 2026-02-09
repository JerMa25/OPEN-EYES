// lib/services/contact_service.dart

import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import '../model/contact.dart';
import '../config.dart';
import 'api_client.dart';

/// Service pour gérer les contacts
/// Synchronise les contacts entre le backend Django et la SIM de la canne
class ContactService {
  final ApiClient _api = ApiClient();

  // Configuration
  static int get canneId => AppConfig.canneId;
  static String get cannePhone => AppConfig.cannePhoneString;
  static String get cannePhoneDisplay => AppConfig.cannePhoneDisplay;
  static String get role => AppConfig.defaultRole;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 GESTION SMS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Demande les permissions SMS
  Future<bool> requestSmsPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Envoie une commande AT à la canne via SMS
  Future<void> _sendAtCommandToCanne({required String command}) async {
    try {
      // Essayer d'abord sans le +
      await sendSMS(
        message: command,
        recipients: [cannePhone],
        sendDirect: true,
      );
      _log('✅ SMS envoyé à $cannePhone: $command');
    } catch (e) {
      _log('⚠️ Erreur envoi SMS sans +, tentative avec +');
      
      // Si ça échoue, réessayer avec le +
      try {
        await sendSMS(
          message: command,
          recipients: [cannePhoneDisplay],
          sendDirect: true,
        );
        _log('✅ SMS envoyé à $cannePhoneDisplay: $command');
      } catch (e2) {
        _log('❌ Impossible d\'envoyer le SMS: $e2');
        throw Exception('Impossible d\'envoyer le SMS: $e2');
      }
    }
  }

  /// Ajoute un contact dans la SIM de la canne
  Future<void> _addContactToSim({required Contact contact}) async {
    final String nom = '${contact.prenom} ${contact.nom}';
    final String commande = 'AT+CPBW=,"${contact.telephone}",129,"$nom"';
    await _sendAtCommandToCanne(command: commande);
  }

  /// Supprime un contact de la SIM de la canne
  Future<void> _deleteContactFromSim({required String telephone}) async {
    final String commande = 'DELETE_CONTACT:$telephone';
    await _sendAtCommandToCanne(command: commande);
  }

  /// Met à jour un contact dans la SIM
  Future<void> _updateContactInSim({
    required String ancienTelephone,
    required Contact newContact,
  }) async {
    await _deleteContactFromSim(telephone: ancienTelephone);
    await Future.delayed(const Duration(milliseconds: 500));
    await _addContactToSim(contact: newContact);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 API BACKEND
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère tous les contacts de la canne
  /// GET /api/contacts/{canne_id}/
  Future<List<Contact>> fetchAllContacts() async {
    _log('📡 Fetching contacts for canne $canneId');

    final response = await _api.get('/api/contacts/$canneId/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data as List<dynamic>;
      _log('✅ Parsed ${jsonList.length} contacts');
      return jsonList.map((json) => Contact.fromJson(json)).toList();
    }

    throw Exception('Erreur récupération contacts');
  }

  /// Enregistre un nouveau contact
  /// POST /api/contacts/register-sms/{canne_id}/{role}/{telephone}/
  Future<Contact> registerContact({required Contact contact}) async {
    _log('📡 Registering contact: ${contact.fullName}');

    // 1️⃣ Envoyer au backend
    final response = await _api.post(
      '/api/contacts/register-sms/$canneId/$role/${contact.telephone}/',
      data: contact.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur backend (${response.statusCode})');
    }

    final savedContact = Contact.fromJson(response.data);
    _log('✅ Contact sauvegardé dans le backend');

    // 2️⃣ Envoyer le SMS à la canne
    try {
      await _addContactToSim(contact: savedContact);
      _log('✅ Contact ajouté dans la SIM');
    } catch (e) {
      _log('⚠️ Contact sauvegardé backend mais erreur SIM: $e');
      // On ne throw pas pour ne pas bloquer si le backend a réussi
    }

    return savedContact;
  }

  /// Met à jour un contact existant
  /// PUT /api/contacts/{canne_id}/contacts/{ancien_telephone}/{role}/update/
  Future<Contact> updateContactByTelephone({
    required String ancienTelephone,
    required Contact updatedContact,
  }) async {
    _log('📡 Updating contact: $ancienTelephone -> ${updatedContact.telephone}');

    final response = await _api.put(
      '/api/contacts/$canneId/contacts/$ancienTelephone/$role/update/',
      data: updatedContact.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur mise à jour backend (${response.statusCode})');
    }

    final savedContact = Contact.fromJson(response.data);
    _log('✅ Contact mis à jour dans le backend');

    // Mettre à jour la SIM
    try {
      await _updateContactInSim(
        ancienTelephone: ancienTelephone,
        newContact: savedContact,
      );
      _log('✅ Contact mis à jour dans la SIM');
    } catch (e) {
      _log('⚠️ Mise à jour backend OK mais erreur SIM: $e');
    }

    return savedContact;
  }

  /// Supprime un contact
  /// POST /api/contacts/{canne_id}/contacts/{contact_id}/{role}/delete/
  Future<void> deleteContact({
    required int contactId,
    required String telephone,
  }) async {
    _log('📡 Deleting contact: $contactId ($telephone)');

    final response = await _api.post(
      '/api/contacts/$canneId/contacts/$contactId/$role/delete/',
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur suppression backend (${response.statusCode})');
    }

    _log('✅ Contact supprimé du backend');

    // Supprimer de la SIM
    try {
      await _deleteContactFromSim(telephone: telephone);
      _log('✅ Contact supprimé de la SIM');
    } catch (e) {
      _log('⚠️ Suppression backend OK mais erreur SIM: $e');
    }
  }

  /// Synchronise tous les contacts vers la SIM
  Future<void> syncAllContactsToSim() async {
    _log('📡 Synchronizing all contacts to SIM');

    final contacts = await fetchAllContacts();

    // Vider la SIM d'abord
    await _sendAtCommandToCanne(command: 'CLEAR_ALL_CONTACTS');
    await Future.delayed(const Duration(seconds: 2));

    // Ajouter chaque contact
    for (var contact in contacts) {
      try {
        await _addContactToSim(contact: contact);
        await Future.delayed(const Duration(milliseconds: 800));
        _log('✅ Synced: ${contact.fullName}');
      } catch (e) {
        _log('⚠️ Erreur sync contact ${contact.nom}: $e');
      }
    }

    _log('✅ Synchronisation terminée');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 UTILITAIRES
  // ═══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('[ContactService] $message');
    }
  }
}
