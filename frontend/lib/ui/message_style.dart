// lib/ui/sms_message_ui.dart

import 'package:flutter/material.dart';
import '../model/message.dart';

extension SmsMessageUi on SmsMessage {
  
  /// Icône selon le type de message
  IconData get typeIcon {
    switch (typeMessage) {
      case SmsMessage.TYPE_COMMANDE:
        return Icons.settings_remote;
      case SmsMessage.TYPE_ALERTE:
        return Icons.warning_rounded;
      case SmsMessage.TYPE_NOTIFICATION:
        return Icons.notifications;
      case SmsMessage.TYPE_REPONSE:
        return Icons.reply;
      default:
        return Icons.message;
    }
  }

  /// Couleur selon le type de message
  Color get typeColor {
    switch (typeMessage) {
      case SmsMessage.TYPE_COMMANDE:
        return const Color(0xFF1976D2); // Bleu
      case SmsMessage.TYPE_ALERTE:
        return const Color(0xFFD32F2F); // Rouge
      case SmsMessage.TYPE_NOTIFICATION:
        return const Color(0xFFF57C00); // Orange
      case SmsMessage.TYPE_REPONSE:
        return const Color(0xFF388E3C); // Vert
      default:
        return const Color(0xFF757575); // Gris
    }
  }

  /// Couleur de fond selon le type
  Color get typeBackgroundColor {
    switch (typeMessage) {
      case SmsMessage.TYPE_COMMANDE:
        return const Color(0xFFE3F2FD); // Bleu clair
      case SmsMessage.TYPE_ALERTE:
        return const Color(0xFFFFEBEE); // Rouge clair
      case SmsMessage.TYPE_NOTIFICATION:
        return const Color(0xFFFFF3E0); // Orange clair
      case SmsMessage.TYPE_REPONSE:
        return const Color(0xFFE8F5E9); // Vert clair
      default:
        return const Color(0xFFF5F5F5); // Gris clair
    }
  }

  /// Icône selon le statut
  IconData get statutIcon {
    switch (statut) {
      case SmsMessage.STATUT_EN_ATTENTE:
        return Icons.schedule;
      case SmsMessage.STATUT_ENVOYE:
        return Icons.send;
      case SmsMessage.STATUT_RECU:
        return Icons.done_all;
      case SmsMessage.STATUT_ECHEC:
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// Couleur selon le statut
  Color get statutColor {
    switch (statut) {
      case SmsMessage.STATUT_EN_ATTENTE:
        return const Color(0xFFFFA000); // Orange
      case SmsMessage.STATUT_ENVOYE:
        return const Color(0xFF1976D2); // Bleu
      case SmsMessage.STATUT_RECU:
        return const Color(0xFF388E3C); // Vert
      case SmsMessage.STATUT_ECHEC:
        return const Color(0xFFD32F2F); // Rouge
      default:
        return const Color(0xFF757575); // Gris
    }
  }

  /// Format de la date (ex: "Il y a 2h" ou "12/01/2026")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Heure formatée (ex: "14:30")
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// A-t-il une erreur ?
  bool get hasError => statut == SmsMessage.STATUT_ECHEC && erreurDetails != null;
}