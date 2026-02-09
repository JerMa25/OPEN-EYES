// lib/model/sms_message.dart

class SmsMessage {
  final int id;
  final int canne;
  final String typeMessage;
  final String typeMessageDisplay;
  final String contenu;
  final String statut;
  final String statutDisplay;
  final int? envoyePar;
  final String? envoieParNom;
  final DateTime timestamp;
  final String? erreurDetails;

  SmsMessage({
    required this.id,
    required this.canne,
    required this.typeMessage,
    required this.typeMessageDisplay,
    required this.contenu,
    required this.statut,
    required this.statutDisplay,
    this.envoyePar,
    this.envoieParNom,
    required this.timestamp,
    this.erreurDetails,
  });

  /// Crée un SmsMessage depuis une Map JSON
  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    return SmsMessage(
      id: json['id'] as int,
      canne: _parseToInt(json['canne']),
      typeMessage: json['type_message']?.toString() ?? typeNotification,
      typeMessageDisplay: json['type_message_display']?.toString() ?? 'Notification',
      contenu: json['contenu']?.toString() ?? '',
      statut: json['statut']?.toString() ?? statutEnAttente,
      statutDisplay: json['statut_display']?.toString() ?? 'En attente',
      envoyePar: json['envoye_par'] as int?,
      envoieParNom: json['envoye_par_nom']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      erreurDetails: json['erreur_details']?.toString(),
    );
  }

  /// Convertit en Map JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canne': canne,
      'type_message': typeMessage,
      'contenu': contenu,
      'statut': statut,
      if (envoyePar != null) 'envoye_par': envoyePar,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES - Types de messages
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String typeCommande = 'COMMANDE';
  static const String typeAlerte = 'ALERTE';
  static const String typeNotification = 'NOTIFICATION';
  static const String typeReponse = 'REPONSE';

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES - Statuts
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String statutEnAttente = 'EN_ATTENTE';
  static const String statutEnvoye = 'ENVOYE';
  static const String statutRecu = 'RECU';
  static const String statutEchec = 'ECHEC';

  /// Vérifie si le message a une erreur
  bool get hasError => statut == statutEchec && erreurDetails != null;

  /// Vérifie si c'est une alerte
  bool get isAlert => typeMessage == typeAlerte;

  /// Vérifie si c'est une commande
  bool get isCommand => typeMessage == typeCommande;

  /// Helper pour parser en int
  static int _parseToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  String toString() {
    return 'SmsMessage(id: $id, type: $typeMessage, statut: $statut)';
  }
}
