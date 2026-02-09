// lib/widgets/contact/contact_card.dart

import 'package:flutter/material.dart';
import '../../model/contact.dart';
import '../../ui/contact_style.dart';

/// Carte affichant un contact
class ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.contact,
    this.onMenuPressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(25), // Remplace withOpacity
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar avec initiales
              _buildAvatar(),
              const SizedBox(width: 16),

              // Informations du contact
              Expanded(child: _buildInfo()),

              // Menu options
              if (onMenuPressed != null) _buildMenuButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: contact.avatarBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          contact.avatarText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: contact.avatarTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom complet
        Text(
          contact.fullName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Type de contact avec icône
        Row(
          children: [
            Icon(
              contact.typeContactIcon,
              size: 14,
              color: contact.avatarTextColor,
            ),
            const SizedBox(width: 4),
            Text(
              contact.typeContactLabel,
              style: TextStyle(
                fontSize: 13,
                color: contact.avatarTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Téléphone
        Row(
          children: [
            Icon(
              Icons.phone_outlined,
              size: 14,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              contact.telephone,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuButton() {
    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: Colors.grey[400],
      ),
      onPressed: onMenuPressed,
      splashRadius: 24,
    );
  }
}
