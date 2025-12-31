// lib/models/destination.dart
import 'package:flutter/material.dart';

class Destination {
  final String title;
  final String address;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  Destination({
    required this.title,
    required this.address,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}

// Données d'exemple
class DestinationData {
  static List<Destination> getDestinations() {
    return [
      Destination(
        title: 'Maison',
        address: '12 Avenue des Ternes, Paris',
        icon: Icons.home,
        iconColor: Colors.orange,
        backgroundColor: Colors.orange.shade50,
      ),
      Destination(
        title: 'Bureau',
        address: 'Tour Montparnasse, Paris',
        icon: Icons.business_center,
        iconColor: Colors.purple,
        backgroundColor: Colors.purple.shade50,
      ),
      Destination(
        title: 'Pharmacie',
        address: '88 Rue de Rivoli, Paris',
        icon: Icons.local_pharmacy,
        iconColor: Colors.teal,
        backgroundColor: Colors.teal.shade50,
      ),
    ];
  }
}