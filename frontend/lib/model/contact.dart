// lib/model/contact.dart

class Contact {
  final int? id;
  final int canne;
  final String nom;
  final String prenom;
  final String telephone;
  final String typeContact;
  final int priorite;

  Contact({
    this.id,
    required this.canne,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.typeContact,
    this.priorite = 1,
  });

  /// Crée un Contact depuis une Map JSON (réponse API)
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as int?,
      canne: _parseToInt(json['canne']),
      nom: json['nom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      typeContact: json['type_contact']?.toString() ?? 'AUTRE',
      priorite: _parseToInt(json['priorite'], defaultValue: 1),
    );
  }

  /// Convertit le Contact en Map JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'canne': canne,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'type_contact': typeContact,
      'priorite': priorite,
    };
  }

  /// Crée une copie modifiée du Contact
  Contact copyWith({
    int? id,
    int? canne,
    String? nom,
    String? prenom,
    String? telephone,
    String? typeContact,
    int? priorite,
  }) {
    return Contact(
      id: id ?? this.id,
      canne: canne ?? this.canne,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      typeContact: typeContact ?? this.typeContact,
      priorite: priorite ?? this.priorite,
    );
  }

  /// Numéro de téléphone formaté avec le +
  String get cannePhone => '+$canne';

  /// Nom complet (Prénom Nom)
  String get fullName => '$prenom $nom'.trim();

  /// Vérifie si le contact est valide
  bool get isValid =>
      nom.isNotEmpty && prenom.isNotEmpty && telephone.isNotEmpty;

  /// Helper pour parser en int de façon sécurisée
  static int _parseToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  String toString() {
    return 'Contact(id: $id, nom: $nom, prenom: $prenom, tel: $telephone, type: $typeContact)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact &&
        other.id == id &&
        other.telephone == telephone;
  }

  @override
  int get hashCode => id.hashCode ^ telephone.hashCode;
}
