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

  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    return SmsMessage(
      id: json['id'],
      canne: json['canne'],
      typeMessage: json['type_message'],
      typeMessageDisplay: json['type_message_display'],
      contenu: json['contenu'],
      statut: json['statut'],
      statutDisplay: json['statut_display'],
      envoyePar: json['envoye_par'],
      envoieParNom: json['envoye_par_nom'],
      timestamp: DateTime.parse(json['timestamp']),
      erreurDetails: json['erreur_details'],
    );
  }

  // Types de messages possibles
  static const String TYPE_COMMANDE = 'COMMANDE';
  static const String TYPE_ALERTE = 'ALERTE';
  static const String TYPE_NOTIFICATION = 'NOTIFICATION';
  static const String TYPE_REPONSE = 'REPONSE';

  // Statuts possibles
  static const String STATUT_EN_ATTENTE = 'EN_ATTENTE';
  static const String STATUT_ENVOYE = 'ENVOYE';
  static const String STATUT_RECU = 'RECU';
  static const String STATUT_ECHEC = 'ECHEC';
}