import 'package:flutter/material.dart';

class Message {
  final String content;
  final String receiver;
  final String avatarText;
  final bool useEmoji;
  final Color? backgroundColor;

  Message({
    required this.content,
    required this.receiver,
    required this.avatarText,
    this.useEmoji = false,
    this.backgroundColor,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'],
      receiver: json['receiver'],
      avatarText: json['avatarText'] ?? '🦯',
      useEmoji: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "content": content,
      "receiver": receiver,
      "avatarText": avatarText,
    };
  }
}
