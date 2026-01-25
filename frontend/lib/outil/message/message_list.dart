// lib/widgets/sms/message_list.dart

import 'package:flutter/material.dart';
import '../../model/message.dart';
import 'message_card.dart';

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
        return SmsMessageCard(
          message: message,
          onTap: () => onMessageTap?.call(message),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filterType != null && filterType != 'Tous'
                ? Icons.filter_alt_off
                : Icons.sms_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            filterType != null && filterType != 'Tous'
                ? 'Aucun message de ce type'
                : 'Aucun message',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filterType != null && filterType != 'Tous'
                ? 'Essayez un autre filtre'
                : 'L\'historique des SMS apparaîtra ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}