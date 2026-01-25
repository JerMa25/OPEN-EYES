class Contact {
  final int? id; // reçu du backend
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
    required this.priorite,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      canne: json['canne'],
      nom: json['nom'],
      prenom: json['prenom'],
      telephone: json['telephone'],
      typeContact: json['type_contact'],
      priorite: json['priorite'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "canne": canne,
      "nom": nom,
      "prenom": prenom,
      "telephone": telephone,
      "type_contact": typeContact,
      "priorite": priorite,
    };
  }
   String get cannePhone => '+$canne';
}
