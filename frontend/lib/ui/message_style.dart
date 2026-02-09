// lib/ui/message_style.dart

import 'package:flutter/material.dart';
import '../model/sms_message.dart';

/// Extension pour les styles visuels des messages SMS
extension SmsMessageUi on SmsMessage {
  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 TYPE DE MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Icône selon le type de message
  IconData get typeIcon {
    switch (typeMessage) {
      case SmsMessage.typeCommande:
        return Icons.settings_remote;
      case SmsMessage.typeAlerte:
        return Icons.warning_rounded;
      case SmsMessage.typeNotification:
        return Icons.notifications;
      case SmsMessage.typeReponse:
        return Icons.reply;
      default:
        return Icons.message;
    }
  }

  /// Couleur selon le type de message
  Color get typeColor {
    switch (typeMessage) {
      case SmsMessage.typeCommande:
        return const Color(0xFF1976D2); // Bleu
      case SmsMessage.typeAlerte:
        return const Color(0xFFD32F2F); // Rouge
      case SmsMessage.typeNotification:
        return const Color(0xFFF57C00); // Orange
      case SmsMessage.typeReponse:
        return const Color(0xFF388E3C); // Vert
      default:
        return const Color(0xFF757575); // Gris
    }
  }

  /// Couleur de fond selon le type
  Color get typeBackgroundColor {
    switch (typeMessage) {
      case SmsMessage.typeCommande:
        return const Color(0xFFE3F2FD); // Bleu clair
      case SmsMessage.typeAlerte:
        return const Color(0xFFFFEBEE); // Rouge clair
      case SmsMessage.typeNotification:
        return const Color(0xFFFFF3E0); // Orange clair
      case SmsMessage.typeReponse:
        return const Color(0xFFE8F5E9); // Vert clair
      default:
        return const Color(0xFFF5F5F5); // Gris clair
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ STATUT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Icône selon le statut
  IconData get statutIcon {
    switch (statut) {
      case SmsMessage.statutEnAttente:
        return Icons.schedule;
      case SmsMessage.statutEnvoye:
        return Icons.send;
      case SmsMessage.statutRecu:
        return Icons.done_all;
      case SmsMessage.statutEchec:
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// Couleur selon le statut
  Color get statutColor {
    switch (statut) {
      case SmsMessage.statutEnAttente:
        return const Color(0xFFFFA000); // Orange
      case SmsMessage.statutEnvoye:
        return const Color(0xFF1976D2); // Bleu
      case SmsMessage.statutRecu:
        return const Color(0xFF388E3C); // Vert
      case SmsMessage.statutEchec:
        return const Color(0xFFD32F2F); // Rouge
      default:
        return const Color(0xFF757575); // Gris
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🕐 FORMATAGE DU TEMPS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Format relatif de la date (ex: "Il y a 2h")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Il y a $minutes min';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Il y a ${hours}h';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Il y a ${days}j';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks}sem';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Heure formatée (ex: "14:30")
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Date formatée (ex: "15 janv. 2026")
  String get formattedDate {
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${timestamp.day} ${mois[timestamp.month - 1]} ${timestamp.year}';
  }

  /// Date et heure complètes
  String get formattedDateTime {
    return '$formattedDate à $formattedTime';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📝 AFFICHAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Nom de l'expéditeur ou "Système" par défaut
  String get senderName => envoieParNom ?? 'Système';

  /// Aperçu du contenu (tronqué si trop long)
  String get contentPreview {
    if (contenu.length <= 100) return contenu;
    return '${contenu.substring(0, 97)}...';
  }

  /// Badge de priorité pour les alertes
  bool get isUrgent => typeMessage == SmsMessage.typeAlerte;
}
