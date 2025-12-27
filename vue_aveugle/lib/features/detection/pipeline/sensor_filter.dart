// lib/features/detection/pipeline/sensor_filter.dart

import 'dart:collection';
import '../models/sensor_packet.dart';
import '../models/imu_data.dart';
import '../models/obstacle_data.dart';

/// Filtre de données capteurs pour réduire le bruit et stabiliser les mesures
/// 
/// Pourquoi filtrer ? Les capteurs physiques produisent du bruit :
/// - Vibrations mécaniques
/// - Interférences électromagnétiques
/// - Erreurs de mesure aléatoires
/// - Rebonds dans les capteurs ultrasoniques
/// 
/// Sans filtrage, l'app recevrait des valeurs erratiques qui causeraient :
/// - Fausses alertes
/// - Navigation saccadée
/// - Expérience utilisateur dégradée
/// 
/// Ce filtre utilise une moyenne glissante (moving average) simple mais efficace
class SensorFilter {
  /// Taille de la fenêtre de filtrage (nombre de mesures gardées en mémoire)
  /// 
  /// Pourquoi 5 ? C'est un compromis :
  /// - Trop petit (1-2) : filtrage insuffisant, bruit toujours présent
  /// - Trop grand (10+) : trop de latence, réponse lente aux changements réels
  /// - 5 mesures : bon équilibre entre stabilité et réactivité
  /// 
  /// À 10Hz de fréquence capteur, 5 mesures = 500ms de données
  final int windowSize;

  /// Historique des paquets IMU pour calcul de moyenne
  /// 
  /// Pourquoi Queue ? Structure FIFO (First In First Out) :
  /// - add() ajoute à la fin
  /// - removeFirst() retire du début
  /// Parfait pour une fenêtre glissante qui garde les N dernières valeurs
  final Queue<ImuData> _imuHistory = Queue<ImuData>();

  /// Historiques séparés pour chaque direction d'obstacle
  /// 
  /// Pourquoi séparer front/left/right ? Chaque capteur a son propre bruit,
  /// les filtrer indépendamment donne de meilleurs résultats qu'un filtre global
  final Queue<double?> _frontHistory = Queue<double?>();
  final Queue<double?> _leftHistory = Queue<double?>();
  final Queue<double?> _rightHistory = Queue<double?>();

  /// Seuil de changement brusque pour détection d'anomalie (en mètres)
  /// 
  /// Pourquoi 1.5m ? Si la distance change de plus de 1.5m en une mesure,
  /// c'est probablement une erreur de capteur (rebond ultrasonique) plutôt
  /// qu'un vrai changement de l'environnement.
  /// 
  /// Exemple : passer de 2.0m à 0.2m instantanément est physiquement impossible
  /// à vitesse de marche humaine
  static const double anomalyThreshold = 1.5;

  /// Constructeur avec taille de fenêtre paramétrable
  /// 
  /// Pourquoi paramétrable ? Permet d'ajuster le filtrage selon :
  /// - La fréquence des capteurs (plus rapide = fenêtre plus grande)
  /// - Le type d'environnement (intérieur stable vs extérieur dynamique)
  /// - Les préférences utilisateur (réactivité vs stabilité)
  SensorFilter({this.windowSize = 5}) {
    // Validation : la fenêtre doit être d'au moins 2 mesures
    // Pourquoi >= 2 ? Avec 1 seule mesure, pas de filtrage possible (moyenne = valeur)
    if (windowSize < 2) {
      throw ArgumentError('windowSize doit être >= 2, reçu: $windowSize');
    }

    // Validation : limiter la taille pour éviter trop de latence
    // Pourquoi <= 20 ? Au-delà, la latence devient perceptible (> 2 secondes)
    if (windowSize > 20) {
      throw ArgumentError('windowSize doit être <= 20, reçu: $windowSize');
    }
  }

  /// Filtre un paquet de données complet
  /// 
  /// C'est la méthode principale appelée par le pipeline.
  /// Elle applique le filtrage sur toutes les composantes du paquet.
  /// 
  /// Retourne un nouveau paquet avec les valeurs filtrées
  SensorPacket filter(SensorPacket packet) {
    // Étape 1 : Filtrer les données IMU
    final ImuData filteredImu = _filterImu(packet.imu);

    // Étape 2 : Filtrer les données obstacles
    final ObstacleData filteredObstacles = _filterObstacles(packet.obstacles);

    // Étape 3 : Créer et retourner un nouveau paquet avec les valeurs filtrées
    // On garde le timestamp original car il représente le moment de capture réel
    return SensorPacket(
      timestamp: packet.timestamp,
      imu: filteredImu,
      obstacles: filteredObstacles,
    );
  }

  /// Filtre les données IMU (orientation)
  /// 
  /// Pourquoi une méthode séparée ? L'IMU et les obstacles ont des
  /// caractéristiques différentes et nécessitent des traitements adaptés
  ImuData _filterImu(ImuData current) {
    // Étape 1 : Ajouter la mesure actuelle à l'historique
    _imuHistory.add(current);

    // Étape 2 : Limiter la taille de l'historique à windowSize
    // Pourquoi ? Pour maintenir une fenêtre glissante de taille constante
    while (_imuHistory.length > windowSize) {
      _imuHistory.removeFirst(); // Retire la plus ancienne mesure
    }

    // Étape 3 : Si pas assez de données, retourner la valeur brute
    // Pourquoi ? Pendant les premières mesures, pas assez d'historique
    // pour calculer une moyenne fiable. Mieux vaut laisser passer les
    // données brutes que de les rejeter.
    if (_imuHistory.length < 2) {
      return current;
    }

    // Étape 4 : Calculer les moyennes pour chaque angle
    // Pourquoi moyennes séparées ? Yaw, pitch et roll sont indépendants,
    // les moyenner séparément préserve leur signification physique
    final double avgYaw = _calculateAverage(
      _imuHistory.map((imu) => imu.yaw).toList(),
    );

    final double avgPitch = _calculateAverage(
      _imuHistory.map((imu) => imu.pitch).toList(),
    );

    final double avgRoll = _calculateAverage(
      _imuHistory.map((imu) => imu.roll).toList(),
    );

    // Étape 5 : Créer et retourner l'IMU filtré
    return ImuData(
      yaw: avgYaw,
      pitch: avgPitch,
      roll: avgRoll,
    );
  }

  /// Filtre les données d'obstacles
  /// 
  /// Plus complexe que l'IMU car il faut :
  /// - Gérer les valeurs nulles (pas d'obstacle détecté)
  /// - Détecter les anomalies (changements brusques)
  /// - Filtrer chaque direction indépendamment
  ObstacleData _filterObstacles(ObstacleData current) {
    // Filtrer chaque direction indépendamment
    final double? filteredFront = _filterDistance(
      current.front,
      _frontHistory,
    );

    final double? filteredLeft = _filterDistance(
      current.left,
      _leftHistory,
    );

    final double? filteredRight = _filterDistance(
      current.right,
      _rightHistory,
    );

    // Retourner un ObstacleData avec les distances filtrées
    return ObstacleData(
      front: filteredFront,
      left: filteredLeft,
      right: filteredRight,
    );
  }

  /// Filtre une distance d'obstacle individuelle avec détection d'anomalie
  /// 
  /// Cette méthode est le cœur du filtrage des obstacles.
  /// Elle gère les cas complexes comme les null et les sauts de valeur.
  double? _filterDistance(double? current, Queue<double?> history) {
    // Cas 1 : Pas de valeur actuelle (capteur ne détecte rien)
    // On ajoute null à l'historique et on retourne null
    if (current == null) {
      history.add(null);
      _limitQueueSize(history);
      return null;
    }

    // Cas 2 : Détection d'anomalie (changement brusque)
    // Pourquoi vérifier ? Les capteurs ultrasoniques peuvent avoir des "glitches"
    // où ils retournent une valeur aberrante pendant une mesure
    if (history.isNotEmpty && _isAnomaly(current, history)) {
      // On IGNORE la valeur anormale (ne pas l'ajouter à l'historique)
      // On retourne la dernière valeur valide connue
      // Pourquoi ? Mieux vaut une valeur légèrement périmée qu'une fausse alerte
      print('⚠️ Anomalie détectée et filtrée : $current m');
      return _getLastValidValue(history);
    }

    // Cas 3 : Valeur normale, on l'ajoute à l'historique
    history.add(current);
    _limitQueueSize(history);

    // Cas 4 : Pas assez d'historique, retourner la valeur brute
    if (history.length < 2) {
      return current;
    }

    // Cas 5 : Calculer et retourner la moyenne des valeurs non-nulles
    // Pourquoi filtrer les nulls ? On veut une moyenne des distances réelles,
    // pas une moyenne qui inclut des "pas de détection"
    final List<double> validValues = history.whereType<double>().toList();

    if (validValues.isEmpty) {
      return null; // Aucune valeur valide dans l'historique
    }

    return _calculateAverage(validValues);
  }

  /// Détecte si une valeur est anormale par rapport à l'historique
  /// 
  /// Pourquoi cette méthode ? Pour identifier les "glitches" des capteurs
  /// qui produisent des valeurs physiquement impossibles
  bool _isAnomaly(double current, Queue<double?> history) {
    // On récupère la dernière valeur valide (non-null) de l'historique
    final lastValid = _getLastValidValue(history);

    // Si pas d'historique valide, on ne peut pas détecter d'anomalie
    if (lastValid == null) return false;

    // Calculer la différence absolue entre actuel et précédent
    final double difference = (current - lastValid).abs();

    // C'est une anomalie si le changement dépasse le seuil
    // Pourquoi > et pas >= ? Pour être inclusif au seuil exact
    return difference > anomalyThreshold;
  }

  /// Récupère la dernière valeur non-null d'un historique
  /// 
  /// Pourquoi ? Utile quand on détecte une anomalie : on retourne
  /// la dernière valeur valide connue au lieu de la valeur aberrante
  double? _getLastValidValue(Queue<double?> history) {
    // Parcourir l'historique en sens inverse (du plus récent au plus ancien)
    // et retourner la première valeur non-null trouvée
    for (final value in history.toList().reversed) {
      if (value != null) return value;
    }
    return null; // Aucune valeur valide dans tout l'historique
  }

  /// Calcule la moyenne d'une liste de valeurs
  /// 
  /// Pourquoi une méthode utilitaire ? Le calcul de moyenne est utilisé
  /// plusieurs fois, autant centraliser le code pour éviter la duplication
  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;

    // Somme de toutes les valeurs divisée par le nombre de valeurs
    // Formule classique : moyenne = somme / nombre
    final double sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  /// Limite la taille d'une Queue au windowSize configuré
  /// 
  /// Pourquoi une méthode séparée ? Code réutilisé pour toutes les Queues,
  /// évite la duplication et les erreurs
  void _limitQueueSize(Queue<dynamic> queue) {
    while (queue.length > windowSize) {
      queue.removeFirst(); // Retire l'élément le plus ancien
    }
  }

  /// Réinitialise complètement le filtre (vide tous les historiques)
  /// 
  /// Pourquoi cette méthode ? Utile dans plusieurs cas :
  /// - Après une longue déconnexion (données périmées)
  /// - Changement d'environnement radical (intérieur -> extérieur)
  /// - Détection d'erreur système nécessitant un redémarrage propre
  void reset() {
    _imuHistory.clear();
    _frontHistory.clear();
    _leftHistory.clear();
    _rightHistory.clear();
    print('🔄 Filtre réinitialisé');
  }

  /// Retourne des statistiques sur l'état du filtre
  /// 
  /// Pourquoi ? Utile pour le débogage et le monitoring :
  /// - Vérifier que le filtre fonctionne (historiques remplis)
  /// - Détecter des problèmes (trop d'anomalies, etc.)
  Map<String, dynamic> getStats() {
    return {
      'windowSize': windowSize,
      'imuHistorySize': _imuHistory.length,
      'frontHistorySize': _frontHistory.length,
      'leftHistorySize': _leftHistory.length,
      'rightHistorySize': _rightHistory.length,
      'isWarmedUp': _imuHistory.length >= windowSize,
    };
  }

  /// Vérifie si le filtre a assez de données pour être pleinement efficace
  /// 
  /// Pourquoi ? Pendant les premières mesures, le filtre ne peut pas
  /// fonctionner à pleine capacité. Cette méthode permet de le détecter.
  bool get isWarmedUp {
    return _imuHistory.length >= windowSize &&
        _frontHistory.length >= windowSize &&
        _leftHistory.length >= windowSize &&
        _rightHistory.length >= windowSize;
  }
}