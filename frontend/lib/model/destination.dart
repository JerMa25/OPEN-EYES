// lib/model/destination.dart

class Destination {
  final int? id;
  final String lieu;
  final int nombreDeVisites;

  Destination({
    this.id,
    required this.lieu,
    required this.nombreDeVisites,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'],
      lieu: json['lieu'],
      nombreDeVisites: json['nombre_de_visites'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lieu': lieu,
      'nombre_de_visites': nombreDeVisites,
    };
  }
}