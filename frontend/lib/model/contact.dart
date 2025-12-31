// lib/models/contact.dart
import 'package:flutter/material.dart';

class Contact {
  final String name;
  final String role;
  final String phone;
  final String avatarText;
  final bool isAccompagnateur;
  final bool useEmoji;
  final Color? backgroundColor;
  final Color? textColor;

  Contact({
    required this.name,
    required this.role,
    required this.phone,
    required this.avatarText,
    this.isAccompagnateur = false,
    this.useEmoji = false,
    this.backgroundColor,
    this.textColor,
  });
}

// Données d'exemple
class ContactData {
  static List<Contact> getAccompagnateurs() {
    return [
      Contact(
        name: 'Jean Dupont',
        role: 'Accompagnateur',
        phone: '06 12 34 56 78',
        avatarText: '👨‍💼',
        isAccompagnateur: true,
        useEmoji: true,
      ),
      Contact(
        name: 'Marie Martin',
        role: '',
        phone: '06 98 76 54 32',
        avatarText: '👩',
        isAccompagnateur: false,
        useEmoji: true,
      ),
    ];
  }

  static List<Contact> getAllContacts() {
    return [
      Contact(
        name: 'Dr. Leblanc',
        role: 'Accompagnateur',
        phone: '01 23 45 67 89',
        avatarText: 'DL',
        isAccompagnateur: false,
        backgroundColor: Colors.blue[100],
        textColor: Colors.blue[700],
      ),
      Contact(
        name: 'Taxi Abeille',
        role: "Contact d urgence",
        phone: '04 91 00 00 00',
        avatarText: 'TA',
        isAccompagnateur: false,
        backgroundColor: Colors.orange[100],
        textColor: Colors.orange[700],
      ),
    ];
  }
}