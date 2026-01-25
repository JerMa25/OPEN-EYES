import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import '../model/contact.dart';
import '../config.dart';

class ContactService {
  static const String baseUrl = AppConfig.baseUrl;
  static const String role = 'SUPER_ADMIN';

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ⚠️ CONFIGUREZ ICI
  static int canneId = AppConfig.cannePhoneNumber; // ⚠️ SANS LE +
  
  // Pour l'affichage avec le + (format international)
  static String get cannePhoneDisplay => AppConfig.cannePhoneDisplay;
  
  // Pour les appels API et SMS (sans le +)
  static String get cannePhone => AppConfig.cannePhoneString;

  // ---------------------------------------------------------------------------
  // 🔐 Demander les permissions SMS
  // ---------------------------------------------------------------------------
  Future<bool> requestSmsPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  // ---------------------------------------------------------------------------
  // 📤 Envoyer un SMS (teste avec et sans + selon l'opérateur)
  // ---------------------------------------------------------------------------
  Future<void> _sendAtCommandToCanne({required String command}) async {
    try {
      // La plupart des opérateurs acceptent les deux formats
      // On essaie d'abord sans le +
      await sendSMS(
        message: command,
        recipients: [cannePhone], // Sans le +
        sendDirect: true,
      );
      print('✅ SMS envoyé à $cannePhone: $command');
    } catch (e) {
      print('❌ Erreur envoi SMS: $e');
      
      // Si ça échoue, on réessaie avec le + (pour certains opérateurs)
      try {
        await sendSMS(
          message: command,
          recipients: [cannePhoneDisplay], // Avec le +
          sendDirect: true,
        );
        print('✅ SMS envoyé à $cannePhoneDisplay: $command');
      } catch (e2) {
        throw Exception('Impossible d\'envoyer le SMS: $e2');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📌 Ajouter un contact dans la SIM
  // ---------------------------------------------------------------------------
  Future<void> _addContactToSim({required Contact contact}) async {
    final String nom = '${contact.prenom} ${contact.nom}';
    final String commande = 'AT+CPBW=,"${contact.telephone}",129,"$nom"';
    
    await _sendAtCommandToCanne(command: commande);
  }

  // ---------------------------------------------------------------------------
  // 🗑️ Supprimer un contact de la SIM
  // ---------------------------------------------------------------------------
  Future<void> _deleteContactFromSim({required String telephone}) async {
    final String commande = 'DELETE_CONTACT:$telephone';
    await _sendAtCommandToCanne(command: commande);
  }

  // ---------------------------------------------------------------------------
  // ✏️ Mettre à jour un contact dans la SIM
  // ---------------------------------------------------------------------------
  Future<void> _updateContactInSim({
    required String ancienTelephone,
    required Contact newContact,
  }) async {
    await _deleteContactFromSim(telephone: ancienTelephone);
    await Future.delayed(const Duration(milliseconds: 500));
    await _addContactToSim(contact: newContact);
  }

  // ---------------------------------------------------------------------------
  // 📌 GET – Récupère TOUS les contacts
  // ---------------------------------------------------------------------------
  Future<List<Contact>> fetchAllContacts() async {
    print('📡 ContactService: Fetching contacts form $baseUrl/api/contacts/$canneId/');
    final uri = Uri.parse('$baseUrl/api/contacts/$canneId/');
    
    try {
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ ContactService: Timeout reached!');
          throw Exception('Délai d\'attente dépassé. Vérifiez que le serveur backend est lancé (0.0.0.0:8000) et accessible.');
        },
      );
      
      print('📥 ContactService: Response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        print('✅ ContactService: Parsed ${jsonList.length} contacts');
        return jsonList.map((json) => Contact.fromJson(json)).toList();
      } else {
        print('❌ ContactService: Error ${response.statusCode} - ${response.body}');
        throw Exception('Erreur récupération contacts (${response.statusCode})');
      }
    } catch (e) {
      print('❌ ContactService: Exception - $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 📌 POST – Enregistrement d'un contact (BACKEND + SMS)
  // ---------------------------------------------------------------------------
  Future<Contact> registerContact({required Contact contact}) async {
    // 1️⃣ ENVOYER AU BACKEND (sans le +)
    final uri = Uri.parse(
      '$baseUrl/api/contacts/register-sms/$canneId/$role/${contact.telephone}/',
    );

    final response = await http.post(
      uri,
      headers: _headers,
      body: json.encode(contact.toJson()),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Délai d\'attente dépassé (POST). Vérifiez le serveur.');
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur backend (${response.statusCode})');
    }

    final savedContact = Contact.fromJson(json.decode(response.body));

    // 2️⃣ ENVOYER SMS
    try {
      await _addContactToSim(contact: savedContact);
      print('✅ Contact ajouté dans la SIM');
    } catch (e) {
      print('⚠️ Contact sauvegardé backend mais erreur SIM: $e');
      // On ne rethrow PAS pour ne pas bloquer l'interface si le backend a réussi
    }

    return savedContact;
  }

  // ---------------------------------------------------------------------------
  // 📌 PUT – Mise à jour d'un contact
  // ---------------------------------------------------------------------------
  Future<Contact> updateContactByTelephone({
    required String ancienTelephone,
    required Contact updatedContact,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/contacts/$canneId/contacts/$ancienTelephone/$role/update/',
    );

    final response = await http.put(
      uri,
      headers: _headers,
      body: json.encode(updatedContact.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur mise à jour backend (${response.statusCode})');
    }

    final savedContact = Contact.fromJson(json.decode(response.body));

    try {
      await _updateContactInSim(
        ancienTelephone: ancienTelephone,
        newContact: savedContact,
      );
      print('✅ Contact mis à jour dans la SIM');
    } catch (e) {
      print('⚠️ Mise à jour backend OK mais erreur SIM: $e');
      // On continue car la DB est à jour
    }

    return savedContact;
  }

  // ---------------------------------------------------------------------------
  // 📌 POST – Suppression d'un contact
  // ---------------------------------------------------------------------------
  Future<void> deleteContact({
    required int contactId,
    required String telephone,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/contacts/$canneId/contacts/$contactId/$role/delete/',
    );

    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur suppression backend (${response.statusCode})');
    }

    try {
      await _deleteContactFromSim(telephone: telephone);
      print('✅ Contact supprimé de la SIM');
    } catch (e) {
      print('⚠️ Suppression backend OK mais erreur SIM: $e');
      // On continue
    }
  }

  // ---------------------------------------------------------------------------
  // 📌 Synchroniser tous les contacts
  // ---------------------------------------------------------------------------
  Future<void> syncAllContactsToSim() async {
    final contacts = await fetchAllContacts();

    await _sendAtCommandToCanne(command: 'CLEAR_ALL_CONTACTS');
    await Future.delayed(const Duration(seconds: 2));

    for (var contact in contacts) {
      try {
        await _addContactToSim(contact: contact);
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        print('⚠️ Erreur sync contact ${contact.nom}: $e');
      }
    }
  }
}