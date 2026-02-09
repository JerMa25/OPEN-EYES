// lib/widgets/message/message_list.dart

import 'package:flutter/material.dart';
import '../../model/sms_message.dart';
import 'message_card.dart';

/// Liste de messages avec filtrage par type
class MessageList extends StatelessWidget {
  final List<SmsMessage> messages;
  final String? filterType;
  final Function(SmsMessage)? onMessageTap;

  const MessageList({
    super.key,
    required this.messages,
    this.filterType,
    this.onMessageTap,
  });

  List<SmsMessage> get filteredMessages {
    if (filterType == null || filterType == 'Tous') {
      return messages;
    }
    return messages.where((m) => m.typeMessage == filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMessages;

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final message = filtered[index];
        return MessageCard(
          message: message,
          onTap: () => onMessageTap?.call(message),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = filterType != null && filterType != 'Tous';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter ? Icons.filter_alt_off : Icons.sms_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasFilter ? 'Aucun message de ce type' : 'Aucun message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Essayez un autre filtre ou vérifiez plus tard'
                  : 'L\'historique des SMS apparaîtra ici',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
