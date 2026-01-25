import 'package:flutter/material.dart';
import '../model/contact.dart';
import '../services/contact_service.dart';
import '../outil/contact/contact_card.dart';
import '../outil/contact/add_contact.dart';
import '../outil/contact/option_contact_dialog.dart';
import '../outil/contact/delete_confirmation.dart';
import '../config.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _contactService = ContactService();
  late Future<List<Contact>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    print('🔄 ContactsPage: Loading contacts...');
    setState(() {
      _contactsFuture = _contactService.fetchAllContacts();
    });
  }

  void _showAddContactDialog() async {
    // ✅ CORRIGÉ : Le dialogue retourne un Contact, pas un Map
    final newContact = await showDialog<Contact>(
      context: context,
      builder: (context) => const AddContactDialog(canneId: AppConfig.cannePhoneNumber,),
    );

    if (newContact != null && mounted) {
      try {
        // ✅ CORRIGÉ : Utilisation de registerContact
        await _contactService.registerContact(contact: newContact);
        
        if (!mounted) return;

        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newContact.nom} ${newContact.prenom} ajouté avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showContactOptions(Contact contact) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => const ContactOptionsDialog(),
    );

    if (action == 'delete') {
      _showDeleteConfirmation(contact);
    } else if (action == 'update') {
      _showUpdateContactDialog(contact);
    }
  }

  void _showDeleteConfirmation(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(contact: contact),
    );

    if (confirmed == true && mounted) {
      try {
        // ✅ CORRIGÉ : Vérification que l'ID existe
        if (contact.id == null) {
          throw Exception('Contact sans ID');
        }

        // ✅ CORRIGÉ : Utilisation de la bonne méthode avec les bons paramètres
        await _contactService.deleteContact(
          contactId: contact.id!,
          telephone: contact.telephone,
        );
        
        if (!mounted) return;

        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.nom} ${contact.prenom} supprimé'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showUpdateContactDialog(Contact contact) async {
    // ✅ CORRIGÉ : Le dialogue retourne un Contact
    final updatedContact = await showDialog<Contact>(
      context: context,
      builder: (context) => AddContactDialog(
        contact: contact,
        canneId: AppConfig.cannePhoneNumber,
      ),
    );

    if (updatedContact != null && mounted) {
      try {
        // ✅ CORRIGÉ : Utilisation de updateContactByTelephone
        await _contactService.updateContactByTelephone(
          ancienTelephone: contact.telephone,
          updatedContact: updatedContact,
        );
        
        if (!mounted) return;

        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedContact.nom} ${updatedContact.prenom} mis à jour'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contacts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                    onPressed: _showAddContactDialog,
                  ),
                ],
              ),
            ),

            // Liste des contacts
            Expanded(
              child: FutureBuilder<List<Contact>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Erreur: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadContacts,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Aucun contact', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Ajoutez votre premier contact', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        ],
                      ),
                    );
                  }

                  // ✅ CORRIGÉ : Groupement par type de contact
                  final urgences = snapshot.data!
                      .where((c) => c.typeContact.toUpperCase() == 'URGENCE')
                      .toList();
                  final autres = snapshot.data!
                      .where((c) => c.typeContact.toUpperCase() != 'URGENCE')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Contacts d'urgence
                      if (urgences.isNotEmpty) ...[
                        Text(
                          'CONTACTS D\'URGENCE',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...urgences.map((contact) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ContactCard(
                                contact: contact,
                                onMenuPressed: () => _showContactOptions(contact),
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],

                      // Autres contacts
                      if (autres.isNotEmpty) ...[
                        Text(
                          'TOUS LES CONTACTS',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...autres.map((contact) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ContactCard(
                                contact: contact,
                                onMenuPressed: () => _showContactOptions(contact),
                              ),
                            )),
                      ],
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}