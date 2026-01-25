// lib/ui/destination_ui.dart

import 'package:flutter/material.dart';
import '../model/destination.dart';

extension DestinationUi on Destination {
  
  /// Icône dynamique selon le type de lieu
  IconData get icon {
    final lieuLower = lieu.toLowerCase();
    
    if (lieuLower.contains('maison') || 
        lieuLower.contains('domicile') || 
        lieuLower.contains('home')) {
      return Icons.home;
    } else if (lieuLower.contains('travail') || 
               lieuLower.contains('bureau') || 
               lieuLower.contains('office')) {
      return Icons.work;
    } else if (lieuLower.contains('hôpital') || 
               lieuLower.contains('clinique') || 
               lieuLower.contains('hospital')) {
      return Icons.local_hospital;
    } else if (lieuLower.contains('marché') || 
               lieuLower.contains('supermarché') || 
               lieuLower.contains('boutique') ||
               lieuLower.contains('magasin')) {
      return Icons.shopping_cart;
    } else if (lieuLower.contains('église') || 
               lieuLower.contains('mosquée') || 
               lieuLower.contains('temple')) {
      return Icons.church;
    } else if (lieuLower.contains('parc') || 
               lieuLower.contains('jardin')) {
      return Icons.park;
    } else if (lieuLower.contains('restaurant') || 
               lieuLower.contains('café') || 
               lieuLower.contains('bar')) {
      return Icons.restaurant;
    } else if (lieuLower.contains('école') || 
               lieuLower.contains('université') || 
               lieuLower.contains('collège')) {
      return Icons.school;
    } else if (lieuLower.contains('pharmacie')) {
      return Icons.local_pharmacy;
    } else if (lieuLower.contains('banque') || 
               lieuLower.contains('atm')) {
      return Icons.account_balance;
    } else if (lieuLower.contains('gare') || 
               lieuLower.contains('station') || 
               lieuLower.contains('arrêt')) {
      return Icons.directions_bus;
    } else if (lieuLower.contains('gym') || 
               lieuLower.contains('sport')) {
      return Icons.fitness_center;
    } else {
      return Icons.place;
    }
  }

  /// Couleur de fond selon la fréquence de visite
  Color get backgroundColor {
    if (nombreDeVisites >= 50) {
      return const Color(0xFFE8F5E9); // Vert clair
    } else if (nombreDeVisites >= 20) {
      return const Color(0xFFE3F2FD); // Bleu clair
    } else if (nombreDeVisites >= 10) {
      return const Color(0xFFFFF3E0); // Orange clair
    } else {
      return const Color(0xFFF5F5F5); // Gris clair
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
    } else {
      return 'Rare';
    }
  }

  /// Badge de fréquence (pour afficher le nombre)
  String get visiteBadge => '$nombreDeVisites visite${nombreDeVisites > 1 ? 's' : ''}';
}