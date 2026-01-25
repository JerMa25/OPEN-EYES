import 'package:flutter/material.dart';
import '../model/contact.dart';

extension ContactUi on Contact {

  /// Première lettre du nom pour l'avatar
  String get avatarInitial => nom.isNotEmpty ? nom[0].toUpperCase() : '?';

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
        return const Color(0xFFFF8A65); // orange
      case 'AUTRE':
        return const Color(0xFFE0E0E0); // gris
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
      default:
        return typeContact.isNotEmpty ? typeContact : 'Contact';
    }
  }
}