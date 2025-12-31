// lib/widgets/contact_card.dart
import 'package:flutter/material.dart';
import '../model/contact.dart';

class ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onMenuPressed;

  const ContactCard({
    super.key,
    required this.contact,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: contact.backgroundColor ?? Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    contact.avatarText,
                    style: TextStyle(
                      fontSize: contact.useEmoji ? 28 : 20,
                      fontWeight: FontWeight.bold,
                      color: contact.textColor ?? Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.role,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Menu
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onPressed: onMenuPressed,
          ),
        ],
      ),
    );
  }
}