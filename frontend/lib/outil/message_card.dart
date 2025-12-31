// lib/widgets/contact_card.dart
import 'package:flutter/material.dart';
import '../model/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;

  const MessageCard({
    super.key,
    required this.message,
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
            color: Colors.black.withValues(alpha: 0.5),
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
                  color: message.backgroundColor ?? Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    message.avatarText,
                    style: TextStyle(
                      fontSize: message.useEmoji ? 28 : 20,
                      fontWeight: FontWeight.bold,
                      color: message.textColor ?? Colors.grey[700],
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
                  message.content,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.receiver,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // Menu
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}