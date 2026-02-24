// lib/ui/contact_style.dart

import 'package:flutter/material.dart';
import '../model/contact.dart';

/// Extension pour les styles visuels des contacts
extension ContactUi on Contact {
  /// Première lettre du nom pour l'avatar
  String get avatarInitial => nom.isNotEmpty ? nom[0].toUpperCase() : '?';

  /// Initiales combinées (Prénom + Nom)
  String get avatarText {
    final n = nom.trim();
    final p = prenom.trim();
    String initial(String s) => s.isNotEmpty ? s[0].toUpperCase() : '';
    final iNom = initial(n);
    final iPrenom = initial(p);
    if (iNom.isNotEmpty && iPrenom.isNotEmpty) return '$iPrenom$iNom';
    if (iNom.isNotEmpty) return iNom;
    if (iPrenom.isNotEmpty) return iPrenom;
    return '?';
  }

  /// Couleur de fond selon le type de contact
  Color get avatarBackground {
    switch (typeContact.toUpperCase()) {
      case 'FAMILLE':
        return const Color(0xFFFFCDD2); // rouge clair
      case 'AMI':
        return const Color(0xFFFFF9C4); // jaune clair
      case 'SOIGNANT':
        return const Color(0xFFC8E6C9); // vert clair
      case 'URGENCE':
        return const Color(0xFFFFAB91); // orange clair
      case 'AUTRE':
        return const Color(0xFFE0E0E0); // gris clair
      case 'SUPER_ADMIN':
        return const Color(0xFFB39DDB); // violet clair
      default:
        return const Color(0xFFE0E0E0); // gris par défaut
    }
  }

  /// Couleur du texte selon le type de contact
  Color get avatarTextColor {
    switch (typeContact.toUpperCase()) {
      case 'FAMILLE':
        return const Color(0xFFB71C1C); // rouge foncé
      case 'AMI':
        return const Color(0xFFF57F17); // jaune foncé
      case 'SOIGNANT':
        return const Color(0xFF1B5E20); // vert foncé
      case 'URGENCE':
        return const Color(0xFFBF360C); // orange foncé
      case 'AUTRE':
        return const Color(0xFF424242); // gris foncé
      case 'SUPER_ADMIN':
        return const Color(0xFF4527A0); // violet foncé
      default:
        return const Color(0xFF424242); // gris foncé
    }
  }

  /// Label lisible du type de contact
  String get typeContactLabel {
    switch (typeContact.toUpperCase()) {
      case 'FAMILLE':
        return 'Famille';
      case 'AMI':
        return 'Ami';
      case 'SOIGNANT':
        return 'Soignant';
      case 'URGENCE':
        return 'Service d\'urgence';
      case 'AUTRE':
        return 'Autre';
      case 'SUPER_ADMIN':
        return 'Administrateur';
      default:
        return typeContact.isNotEmpty ? typeContact : 'Contact';
    }
  }

  /// Icône selon le type de contact
  IconData get typeContactIcon {
    switch (typeContact.toUpperCase()) {
      case 'FAMILLE':
        return Icons.family_restroom;
      case 'AMI':
        return Icons.person;
      case 'SOIGNANT':
        return Icons.medical_services;
      case 'URGENCE':
        return Icons.emergency;
      case 'SUPER_ADMIN':
        return Icons.admin_panel_settings;
      default:
        return Icons.contact_phone;
    }
  }

  /// Priorité affichable
  String get prioriteLabel {
    if (priorite == 1) return 'Haute priorité';
    if (priorite == 2) return 'Priorité moyenne';
    return 'Priorité basse';
  }
}

class PhoneCM {
  // Format strict: +2376XXXXXXXX (8 chiffres après 6)
  static final RegExp _cmMobile = RegExp(r'^\+2376\d{8}$');

  static String normalize(String input) {
    var s = input.trim().replaceAll(' ', '').replaceAll('-', '');

    // déjà au bon format
    if (_cmMobile.hasMatch(s)) return s;

    // "6XXXXXXXX" -> "+2376XXXXXXXX"
    if (RegExp(r'^6\d{8}$').hasMatch(s)) return '+237$s';

    // "2376XXXXXXXX" -> "+2376XXXXXXXX"
    if (RegExp(r'^2376\d{8}$').hasMatch(s)) return '+$s';

    // "+2376XXXXXXXX" déjà traité plus haut, sinon on retourne tel quel
    return s;
  }

  static bool isValid(String input) {
    final s = normalize(input);
    return _cmMobile.hasMatch(s);
  }
}