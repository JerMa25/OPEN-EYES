// lib/models/contact.dart
import 'package:flutter/material.dart';

class Message {
  final String content;
  final String receiver;
  final String avatarText;
  final bool useEmoji;
  final Color? backgroundColor;
  final Color? textColor;

  Message({
    required this.content,
    required this.receiver,
    required this.avatarText,
    this.useEmoji = false,
    this.backgroundColor,
    this.textColor,
  });
}

// Données d'exemple
class MessageData {
  static List<Message> getmessages() {
    return [
      Message(
        content: 'Jean Dupont',
        receiver: 'Frère',
        avatarText: '👨‍💼',
        useEmoji: true,
      ),
    ];
  }

  
}
