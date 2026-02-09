// lib/widgets/message/message_card.dart

import 'package:flutter/material.dart';
import '../../model/sms_message.dart';
import '../../ui/message_style.dart';

/// Carte affichant un message SMS
class MessageCard extends StatelessWidget {
  final SmsMessage message;
  final VoidCallback? onTap;

  const MessageCard({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(25),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header : Type + Statut
                _buildHeader(),
                const SizedBox(height: 12),

                // Contenu du message
                _buildContent(),

                // Erreur si présente
                if (message.hasError) ...[
                  const SizedBox(height: 8),
                  _buildError(),
                ],

                const SizedBox(height: 8),

                // Footer : Timestamp
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Icône du type de message
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: message.typeBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            message.typeIcon,
            color: message.typeColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Type et expéditeur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.typeMessageDisplay,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'De: ${message.senderName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Badge de statut
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: message.statutColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.statutIcon,
                size: 14,
                color: message.statutColor,
              ),
              const SizedBox(width: 4),
              Text(
                message.statutDisplay,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: message.statutColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message.contentPreview,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[800],
          height: 1.4,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.erreurDetails!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          message.timeAgo,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          message.formattedTime,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
