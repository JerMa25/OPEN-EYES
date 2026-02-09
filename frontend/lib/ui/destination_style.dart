// lib/ui/destination_style.dart

import 'package:flutter/material.dart';
import '../model/destination.dart';

/// Extension pour les styles visuels des destinations
extension DestinationUi on Destination {
  /// Icône dynamique selon le type de lieu
  IconData get icon {
    final lieuLower = lieu.toLowerCase();

    // Domicile
    if (lieuLower.contains('maison') ||
        lieuLower.contains('domicile') ||
        lieuLower.contains('home') ||
        lieuLower.contains('chez')) {
      return Icons.home;
    }
    
    // Travail
    if (lieuLower.contains('travail') ||
        lieuLower.contains('bureau') ||
        lieuLower.contains('office') ||
        lieuLower.contains('entreprise')) {
      return Icons.work;
    }
    
    // Santé
    if (lieuLower.contains('hôpital') ||
        lieuLower.contains('hopital') ||
        lieuLower.contains('clinique') ||
        lieuLower.contains('hospital') ||
        lieuLower.contains('médecin') ||
        lieuLower.contains('medecin')) {
      return Icons.local_hospital;
    }
    
    // Commerce
    if (lieuLower.contains('marché') ||
        lieuLower.contains('marche') ||
        lieuLower.contains('supermarché') ||
        lieuLower.contains('boutique') ||
        lieuLower.contains('magasin') ||
        lieuLower.contains('shop')) {
      return Icons.shopping_cart;
    }
    
    // Religion
    if (lieuLower.contains('église') ||
        lieuLower.contains('eglise') ||
        lieuLower.contains('mosquée') ||
        lieuLower.contains('mosquee') ||
        lieuLower.contains('temple')) {
      return Icons.church;
    }
    
    // Nature
    if (lieuLower.contains('parc') ||
        lieuLower.contains('jardin') ||
        lieuLower.contains('forêt') ||
        lieuLower.contains('foret')) {
      return Icons.park;
    }
    
    // Restaurant
    if (lieuLower.contains('restaurant') ||
        lieuLower.contains('café') ||
        lieuLower.contains('cafe') ||
        lieuLower.contains('bar') ||
        lieuLower.contains('manger')) {
      return Icons.restaurant;
    }
    
    // Éducation
    if (lieuLower.contains('école') ||
        lieuLower.contains('ecole') ||
        lieuLower.contains('université') ||
        lieuLower.contains('universite') ||
        lieuLower.contains('collège') ||
        lieuLower.contains('college') ||
        lieuLower.contains('lycée') ||
        lieuLower.contains('lycee')) {
      return Icons.school;
    }
    
    // Pharmacie
    if (lieuLower.contains('pharmacie')) {
      return Icons.local_pharmacy;
    }
    
    // Banque
    if (lieuLower.contains('banque') ||
        lieuLower.contains('atm') ||
        lieuLower.contains('distributeur')) {
      return Icons.account_balance;
    }
    
    // Transport
    if (lieuLower.contains('gare') ||
        lieuLower.contains('station') ||
        lieuLower.contains('arrêt') ||
        lieuLower.contains('arret') ||
        lieuLower.contains('bus') ||
        lieuLower.contains('taxi')) {
      return Icons.directions_bus;
    }
    
    // Sport
    if (lieuLower.contains('gym') ||
        lieuLower.contains('sport') ||
        lieuLower.contains('stade') ||
        lieuLower.contains('piscine')) {
      return Icons.fitness_center;
    }
    
    // Ami/Famille
    if (lieuLower.contains('ami') ||
        lieuLower.contains('famille') ||
        lieuLower.contains('voisin')) {
      return Icons.people;
    }

    // Par défaut
    return Icons.place;
  }

  /// Couleur de fond selon la fréquence de visite
  Color get backgroundColor {
    if (nombreDeVisites >= 50) {
      return const Color(0xFFE8F5E9); // Vert clair - Très fréquent
    } else if (nombreDeVisites >= 20) {
      return const Color(0xFFE3F2FD); // Bleu clair - Fréquent
    } else if (nombreDeVisites >= 10) {
      return const Color(0xFFFFF3E0); // Orange clair - Occasionnel
    } else if (nombreDeVisites >= 5) {
      return const Color(0xFFFCE4EC); // Rose clair - Peu fréquent
    } else {
      return const Color(0xFFF5F5F5); // Gris clair - Rare
    }
  }

  /// Couleur de l'icône selon la fréquence
  Color get iconColor {
    if (nombreDeVisites >= 50) {
      return const Color(0xFF2E7D32); // Vert foncé
    } else if (nombreDeVisites >= 20) {
      return const Color(0xFF1976D2); // Bleu foncé
    } else if (nombreDeVisites >= 10) {
      return const Color(0xFFF57C00); // Orange foncé
    } else if (nombreDeVisites >= 5) {
      return const Color(0xFFC2185B); // Rose foncé
    } else {
      return const Color(0xFF757575); // Gris foncé
    }
  }

  /// Label de fréquence
  String get frequenceLabel {
    if (nombreDeVisites >= 50) {
      return 'Très fréquent';
    } else if (nombreDeVisites >= 20) {
      return 'Fréquent';
    } else if (nombreDeVisites >= 10) {
      return 'Occasionnel';
    } else if (nombreDeVisites >= 5) {
      return 'Peu fréquent';
    } else {
      return 'Rare';
    }
  }

  /// Badge de visite (nombre de visites formaté)
  String get visiteBadge {
    if (nombreDeVisites == 1) {
      return '1 visite';
    }
    return '$nombreDeVisites visites';
  }

  /// Étoile de popularité (1-5)
  int get popularityStars {
    if (nombreDeVisites >= 50) return 5;
    if (nombreDeVisites >= 30) return 4;
    if (nombreDeVisites >= 15) return 3;
    if (nombreDeVisites >= 5) return 2;
    return 1;
  }
}
