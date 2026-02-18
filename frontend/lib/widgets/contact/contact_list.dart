import 'package:flutter/material.dart';
import '../../model/contact.dart';
import '../../services/contact_service.dart';
import 'add_contact_dialog.dart';
import 'contact_card.dart';
import 'delete_confirmation_dialog.dart';
import 'contact_options_dialog.dart';

class ContactListWidget extends StatefulWidget {
  final int canneId; // ✅ AJOUTÉ : numéro de la canne

  const ContactListWidget({
    super.key,
    required this.canneId,
  });

  @override
  State<ContactListWidget> createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  final ContactService service = ContactService();

  late Future<List<Contact>> _contactsFuture;

  // 🔹 Contacts de test
  final List<Contact> _testContacts = [
    Contact(
      id: 1,
      canne: 237690000000,
      nom: 'Molo',
      prenom: 'Aurore',
      telephone: '237699999999',
      typeContact: 'FAMILLE',
      priorite: 1,
    ),
    Contact(
      id: 2,
      canne: 237690000000,
      nom: 'Meka',
      prenom: 'John',
      telephone: '237688888888',
      typeContact: 'AMI',
      priorite: 2,
    ),
  ];

  // ✅ Passe à true quand le backend est prêt
  final bool _useBackend = false;

  @override
  void initState() {
    super.initState();
    _reloadContacts();
  }

  void _reloadContacts() {
    setState(() {
      _contactsFuture = _useBackend 
        ? service.fetchAllContacts()
        : _loadContactsFromTest();
    });
  }

  Future<List<Contact>> _loadContactsFromTest() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _testContacts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Contact>>(
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
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Erreur : ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _reloadContacts,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final contacts = snapshot.data ?? [];
        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun contact',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // ✅ Groupement corrigé (enlever ACCOMPAGNATEUR)
        final urgences = contacts
          .where((c) => c.typeContact.toUpperCase() == 'URGENCE')
          .toList();
        final autres = contacts
          .where((c) => c.typeContact.toUpperCase() != 'URGENCE')
          .toList();

        return ListView(
          children: [
            if (urgences.isNotEmpty) ...[
              _sectionTitle('Contacts d\'urgence'),
              ...urgences.map((c) => _buildContact(c)),
            ],
            
            if (autres.isNotEmpty) ...[
              _sectionTitle('Autres contacts'),
              ...autres.map((c) => _buildContact(c)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContact(Contact contact) {
    return ContactCard(
      contact: contact,
      onMenuPressed: () async {
        final action = await showDialog<String>(
          context: context,
          builder: (_) => const ContactOptionsDialog(),
        );

        if (action == 'update') {
          // ✅ AJOUTÉ : Gestion de la mise à jour
          final updatedContact = await showDialog<Contact>(
            context: context,
            builder: (_) => AddContactDialog(
              contact: contact,
              canneId: widget.canneId,
            ),
          );

          if (updatedContact != null && mounted) {
            try {
              await service.updateContact(
                contact.telephone, updatedContact
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact mis à jour avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
                _reloadContacts();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } else if (action == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => DeleteConfirmationDialog(contact: contact),
          );

          if (confirm == true && mounted) {
            try {
              await service.deleteContact(
               contact.id!, contact.telephone
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact supprimé avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
                _reloadContacts();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}