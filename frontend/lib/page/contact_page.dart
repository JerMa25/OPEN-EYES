// lib/page/contact_page.dart
import 'package:flutter/material.dart';
import '../model/contact.dart';
import '../outil/contact_card.dart';
import '../outil/add_contact.dart';
import '../outil/option_contact_dialog.dart';
import '../outil/delete_confirmation.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> favorites = [];
  List<Contact> allContacts = [];

  @override
  void initState() {
    super.initState();
    // Charger les données initiales
    favorites = ContactData.getAccompagnateurs();
    allContacts = ContactData.getAllContacts();
  }

  void _showAddContactDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddContactDialog(),
    );

    if (result != null) {
      setState(() {
        allContacts.add(Contact(
          name: result['name']!,
          role: result['role']!,
          phone: result['phone']!,
          avatarText: _getInitials(result['name']!),
          backgroundColor: Colors.blue[100],
          textColor: Colors.blue[700],
        ));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['name']} a été ajouté aux contacts'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showContactOptions(Contact contact, bool isFavorite) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => const ContactOptionsDialog(),
    );

    if (action == 'delete') {
      _showDeleteConfirmation(contact, isFavorite);
    } else if (action == 'update') {
      _showUpdateContactDialog(contact, isFavorite);
    }
  }

  void _showDeleteConfirmation(Contact contact, bool isFavorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(contact: contact),
    );

    if (confirmed == true) {
      setState(() {
        if (isFavorite) {
          favorites.removeWhere((c) => c.name == contact.name);
        } else {
          allContacts.removeWhere((c) => c.name == contact.name);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.name} a été supprimé'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showUpdateContactDialog(Contact contact, bool isFavorite) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddContactDialog(contact: contact),
    );

    if (result != null) {
      final updatedContact = Contact(
        name: result['name']!,
        role: result['role']!,
        phone: result['phone']!,
        avatarText: contact.useEmoji ? contact.avatarText : _getInitials(result['name']!),
        isAccompagnateur: contact.isAccompagnateur,
        useEmoji: contact.useEmoji,
        backgroundColor: contact.backgroundColor,
        textColor: contact.textColor,
      );

      setState(() {
        if (isFavorite) {
          final index = favorites.indexWhere((c) => c.name == contact.name);
          if (index != -1) favorites[index] = updatedContact;
        } else {
          final index = allContacts.indexWhere((c) => c.name == contact.name);
          if (index != -1) allContacts[index] = updatedContact;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['name']} a été mis à jour'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
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

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Section Favoris
                  if (favorites.isNotEmpty) ...[
                    Text(
                      'FAVORIS',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ...favorites.map((contact) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ContactCard(
                        contact: contact,
                        onMenuPressed: () => _showContactOptions(contact, true),
                      ),
                    )),
                    
                    const SizedBox(height: 24),
                  ],

                  // Section Tous les contacts
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
                  
                  if (allContacts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun contact',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajoutez votre premier contact',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...allContacts.map((contact) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ContactCard(
                        contact: contact,
                        onMenuPressed: () => _showContactOptions(contact, false),
                      ),
                    )),
                  
                  const SizedBox(height: 24),
                  if (allContacts.isNotEmpty)
                    Center(
                      child: Text(
                        'Vous avez atteint la fin de la liste.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
