// lib/pages/contacts_page.dart
// VERSION MISE À JOUR - Gère les résultats SMS

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
    _checkPermissions();
    _loadContacts();
  }

  Future<void> _checkPermissions() async {
    final hasPerms = await _contactService.hasSmsPermissions();
    if (!hasPerms) {
      final granted = await _contactService.requestSmsPermission();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(granted 
              ? '✅ Permissions SMS accordées' 
              : '⚠️ Permissions SMS refusées - Les SMS ne pourront pas être envoyés'),
            backgroundColor: granted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
      // Afficher un indicateur de chargement
      _showLoadingDialog('Enregistrement du contact...');

      try {
        final result = await _contactService.registerContact(newContact);
        
        if (!mounted) return;
        Navigator.pop(context); // Fermer le loading dialog

        _loadContacts();

        // Afficher le résultat
        _showResultSnackBar(result);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Fermer le loading dialog
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showResultSnackBar(RegistrationResult result) {
    final Color backgroundColor;
    final String message;
    final IconData icon;

    if (result.backendOk && (result.smsResult?.success ?? false)) {
      backgroundColor = Colors.green;
      message = '${result.contact.fullName} ajouté ✓\nSMS envoyé à la canne';
      icon = Icons.check_circle;
    } else if (result.backendOk && (result.smsResult?.requiresUserAction ?? false)) {
      backgroundColor = Colors.orange;
      message = '${result.contact.fullName} ajouté ✓\nVeuillez envoyer le SMS manuellement';
      icon = Icons.warning;
    } else if (result.backendOk) {
      backgroundColor = Colors.blue;
      message = '${result.contact.fullName} ajouté ✓\nSMS: ${result.smsResult?.error ?? "en attente"}';
      icon = Icons.info;
    } else {
      backgroundColor = Colors.red;
      message = 'Erreur lors de l\'ajout';
      icon = Icons.error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
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
    } else if (action == 'set_urgence') {
      _setAsUrgenceContact(contact);
    }
  }

  void _setAsUrgenceContact(Contact contact) async {
    _showLoadingDialog('Configuration du contact d\'urgence...');

    try {
      final result = await _contactService.definirUrgence(
        contact.telephone,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
            ? '✅ ${contact.fullName} défini comme contact d\'urgence'
            : '⚠️ Erreur: ${result.error}'),
          backgroundColor: result.success ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _showDeleteConfirmation(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(contact: contact),
    );

    if (confirmed == true && mounted) {
      _showLoadingDialog('Suppression du contact...');

      try {
        if (contact.id == null) {
          throw Exception('Contact sans ID');
        }

        final result = await _contactService.deleteContact(
          contact.id!,
          contact.telephone,
        );

        if (!mounted) return;
        Navigator.pop(context);
        _loadContacts();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.smsResult?.success == true
              ? '${contact.fullName} supprimé ✓'
              : '${contact.fullName} supprimé (SMS: ${result.smsResult?.error ?? "en attente"})'),
            backgroundColor: result.backendOk ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
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
      _showLoadingDialog('Mise à jour du contact...');

      try {
        final result = await _contactService.updateContact(contact.telephone, updatedContact);
        if (!mounted) return;
        Navigator.pop(context);
        _loadContacts();

        _showResultSnackBar(result);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showSyncDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sync, color: Colors.blue),
            SizedBox(width: 12),
            Text('Synchroniser'),
          ],
        ),
        content: const Text(
          'Voulez-vous synchroniser tous les contacts vers la SIM de la canne?\n\n'
          'Cela va effacer les contacts existants dans la canne et les remplacer par ceux de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Synchroniser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _showLoadingDialog('Synchronisation en cours...');

      try {
        final result = await _contactService.syncAllContacts();

        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synchronisation terminée: ${result.success}/${result.total} contacts',
            ),
            backgroundColor: result.complete ? Colors.green : Colors.orange,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
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
              // Bouton Sync
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.orange),
                onPressed: _showSyncDialog,
                tooltip: 'Synchroniser avec la canne',
              ),
              // Bouton Refresh
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
              // Bouton Ajouter
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
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
