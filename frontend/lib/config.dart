// lib/config.dart

class AppConfig {
  // ⚠️ Pour tester sur un VRAI téléphone, utiliser l'IP locale de l'ordinateur
  static const String baseUrl = 'http://10.225.40.198:8000';
  
  // ⚠️ CONFIGURATION DE LA CANNE
  // On utilise le numéro de téléphone comme identifiant unique
  static const int cannePhoneNumber = 237672777581; 

  // Alias pour la compatibilité avec le code existant qui attend "canneId"
  static const int canneId = cannePhoneNumber;
  
  static String get cannePhoneDisplay => '+$cannePhoneNumber';
  static String get cannePhoneString => cannePhoneNumber.toString();

  static void printConfig() {
    print('🔧 CONFIG: BaseUrl=$baseUrl');
    print('🔧 CONFIG: CanneId=$canneId');
  }
}
