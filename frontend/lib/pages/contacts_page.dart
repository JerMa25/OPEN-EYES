// lib/pages/contacts_page.dart

import 'package:flutter/material.dart';
import '../model/contact.dart';
import '../services/contact_service.dart';
import '../widgets/contact/contact_card.dart';
import '../widgets/contact/add_contact_dialog.dart';
import '../widgets/contact/contact_options_dialog.dart';
import '../widgets/contact/delete_confirmation_dialog.dart';
import '../config.dart';

/// Page affichant la liste des contacts
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _contactService = ContactService();
  late Future<List<Contact>> _contactsFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    setState(() {
      _contactsFuture = _contactService.fetchAllContacts();
    });
  }

  Future<void> _refreshContacts() async {
    setState(() => _isRefreshing = true);
    try {
      await _contactService.fetchAllContacts();
      _loadContacts();
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _showAddContactDialog() async {
    final newContact = await showDialog<Contact>(
      context: context,
      builder: (context) => AddContactDialog(
        canneId: AppConfig.cannePhoneNumber,
      ),
    );

    if (newContact != null && mounted) {
      try {
        await _contactService.registerContact(contact: newContact);
        
        if (!mounted) return;
        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newContact.fullName} ajouté avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showContactOptions(Contact contact) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => const ContactOptionsDialog(),
    );

    if (!mounted) return;

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
        if (contact.id == null) {
          throw Exception('Contact sans ID');
        }

        await _contactService.deleteContact(
          contactId: contact.id!,
          telephone: contact.telephone,
        );

        if (!mounted) return;
        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.fullName} supprimé'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showUpdateContactDialog(Contact contact) async {
    final updatedContact = await showDialog<Contact>(
      context: context,
      builder: (context) => AddContactDialog(
        contact: contact,
        canneId: AppConfig.cannePhoneNumber,
      ),
    );

    if (updatedContact != null && mounted) {
      try {
        await _contactService.updateContactByTelephone(
          ancienTelephone: contact.telephone,
          updatedContact: updatedContact,
        );

        if (!mounted) return;
        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedContact.fullName} mis à jour'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContactsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contacts',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez les contacts de la canne',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_isRefreshing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: _refreshContacts,
                ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return RefreshIndicator(
      onRefresh: _refreshContacts,
      child: FutureBuilder<List<Contact>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final contacts = snapshot.data!;
          final urgences = contacts.where((c) => c.typeContact.toUpperCase() == 'URGENCE').toList();
          final autres = contacts.where((c) => c.typeContact.toUpperCase() != 'URGENCE').toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (urgences.isNotEmpty) ...[
                _buildSectionTitle('CONTACTS D\'URGENCE', Icons.emergency, Colors.red),
                const SizedBox(height: 12),
                ...urgences.map((contact) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ContactCard(
                    contact: contact,
                    onMenuPressed: () => _showContactOptions(contact),
                  ),
                )),
                const SizedBox(height: 24),
              ],

              if (autres.isNotEmpty) ...[
                _buildSectionTitle('TOUS LES CONTACTS', Icons.contacts, Colors.blue),
                const SizedBox(height: 12),
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
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.contacts_outlined, size: 64, color: Colors.blue[300]),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre premier contact\npour la canne connectée',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
