import 'package:flutter/material.dart';
import '../../model/contact.dart';
import '../../ui/contact_style.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: contact.avatarBackground,
            child: Text(
              contact.avatarText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: contact.avatarTextColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.nom,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.prenom,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.typeContactLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: contact.avatarTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.telephone,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          if (onMenuPressed != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onMenuPressed,
            ),
        ],
      ),
    );
  }
}
