// ObstacleDetector.cpp - VERSION OPTIMISÉE SANS BLOCAGES
#include "ObstacleDetector.h"
#include "Logger.h"
#include "Config.h"

// =======================================================
// CONSTRUCTEUR
// =======================================================
ObstacleDetector::ObstacleDetector() 
    : angleActuel(90), 
      directionDroite(true),
      ready(false),
      indexBufferHaut(0),
      indexBufferBas(0),
      distPrecedenteHaut(-1),
      distPrecedenteBas(-1),
      lastAlertTimeHaut(0),
      lastAlertTimeBas(0),
      lastDistanceHaut(-1),
      lastDistanceBas(-1),
      lastWaterLevel(0),
      waterRawValue(0),
      lastWaterCheckTime(0),
      lastWaterAlertTime(0),
      lastObstacleCheckTime(0),
      buzzer1State(BUZZER_OFF),
      buzzer2State(BUZZER_OFF),
      buzzer1LastChange(0),
      buzzer2LastChange(0),
      currentDistanceHaut(-1),
      currentDistanceBas(-1),
      lastMeasureTimeHaut(0),
      lastMeasureTimeBas(0),
      lastServoMoveTime(0),
      waterAlertState(WATER_ALERT_OFF),
      waterAlertLastChange(0) {
    
    Logger::info("🔧 [CONSTRUCTOR] ObstacleDetector créé");
    
    // Initialiser buffer à -1
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        bufferHaut[i] = -1;
        bufferBas[i] = -1;
    }
    
    Logger::info("🔧 [CONSTRUCTOR] Buffers initialisés");
}

// =======================================================
// INIT
// =======================================================
void ObstacleDetector::init() {
    Logger::info("========================================");
    Logger::info("🚀 [INIT] Démarrage ObstacleDetector");
    Logger::info("========================================");

    // ===== CONFIGURATION CAPTEURS ULTRASONS =====
    Logger::info("📡 [INIT] Configuration HC-SR04 HAUT...");
    pinMode(OBSTACLE_TRIG_HIGH, OUTPUT);
    pinMode(OBSTACLE_ECHO_HIGH, INPUT);
    Logger::info("✅ [INIT] HC-SR04 HAUT : TRIG=" + String(OBSTACLE_TRIG_HIGH) + 
                 " ECHO=" + String(OBSTACLE_ECHO_HIGH));
    
    Logger::info("📡 [INIT] Configuration HC-SR04 BAS...");
    pinMode(OBSTACLE_TRIG_LOW, OUTPUT);
    pinMode(OBSTACLE_ECHO_LOW, INPUT);
    Logger::info("✅ [INIT] HC-SR04 BAS : TRIG=" + String(OBSTACLE_TRIG_LOW) + 
                 " ECHO=" + String(OBSTACLE_ECHO_LOW));

    // ===== CONFIGURATION SERVO (UNE SEULE FOIS) =====
    Logger::info("🔄 [INIT] Configuration SERVO...");
    Logger::info("🔄 [INIT] Pin SERVO : GPIO" + String(OBSTACLE_SERVO_PIN));
    
    servoMoteur.setPeriodHertz(50);
    Logger::info("✅ [INIT] SERVO fréquence 50Hz OK");
    
    // ✅ CORRECTION : Attach UNE SEULE FOIS
    bool servoAttached = servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    if (servoAttached) {
        Logger::info("✅ [INIT] SERVO attaché avec succès");
    } else {
        Logger::error("❌ [INIT] ERREUR : SERVO pas attaché !");
    }
    
    Logger::info("🔄 [INIT] Position servo à 90°...");
    servoMoteur.write(90);
    delay(500);  // ⚠️ OK dans init() seulement
    Logger::info("✅ [INIT] SERVO positionné à 90°");

    // ===== TEST SERVO (RAPIDE) =====
    Logger::info("🧪 [INIT] TEST SERVO : Balayage 0-180...");
    for (int angle = 0; angle <= 180; angle += 60) {
        servoMoteur.write(angle);
        Logger::info("🔄 [TEST] Servo angle=" + String(angle));
        delay(150);  // ⚠️ OK dans init() seulement
    }
    servoMoteur.write(90);
    Logger::info("✅ [INIT] Test SERVO terminé - retour 90°");



    // ===== CONFIGURATION CAPTEUR EAU =====
    Logger::info("💧 [INIT] Configuration capteur eau...");
    pinMode(WATER_SENSOR_PIN, INPUT);
    Logger::info("✅ [INIT] Capteur eau : GPIO" + String(WATER_SENSOR_PIN));

    // ===== CONFIGURATION BUZZERS ACTIFS =====
    Logger::info("🔊 [INIT] Configuration BUZZERS ACTIFS...");
    pinMode(BUZZER_1_PIN, OUTPUT);
    pinMode(BUZZER_2_PIN, OUTPUT);
    digitalWrite(BUZZER_1_PIN, LOW);
    digitalWrite(BUZZER_2_PIN, LOW);
    Logger::info("✅ [INIT] BUZZER 1 (HAUT) : GPIO" + String(BUZZER_1_PIN));
    Logger::info("✅ [INIT] BUZZER 2 (BAS)  : GPIO" + String(BUZZER_2_PIN));

    // ===== TEST BUZZERS (RAPIDE) =====
    Logger::info("🔊 [INIT] TEST BUZZER 1...");
    digitalWrite(BUZZER_1_PIN, HIGH);
    delay(200);  // ⚠️ OK dans init() seulement
    digitalWrite(BUZZER_1_PIN, LOW);
    Logger::info("✅ [INIT] BUZZER 1 testé");
    
    delay(150);  // ⚠️ OK dans init() seulement
    
    Logger::info("🔊 [INIT] TEST BUZZER 2...");
    digitalWrite(BUZZER_2_PIN, HIGH);
    delay(200);  // ⚠️ OK dans init() seulement
    digitalWrite(BUZZER_2_PIN, LOW);
    Logger::info("✅ [INIT] BUZZER 2 testé");

    ready = true;
    Logger::info("========================================");
    Logger::info("✅ [INIT] ObstacleDetector PRÊT !");
    Logger::info("========================================");
}

// =======================================================
// UPDATE - SANS DELAY
// =======================================================
void ObstacleDetector::update() {
    if (!ready) return;
    
    unsigned long currentTime = millis();
    
    // Vérifications périodiques (50ms)
    if (currentTime - lastObstacleCheckTime >= OBSTACLE_CHECK_INTERVAL) {
        verifierObstacleHaut();
        balayerNiveauBas();
        
        // ✅ AJOUTER DES LOGS DE DEBUG
        if (WATER_SENSOR_ENABLED) {
            if (currentTime - lastWaterCheckTime >= WATER_CHECK_INTERVAL) {
                Logger::info("💧 [DEBUG] Vérification capteur eau...");
                verifierEau();
                
                lastWaterCheckTime = currentTime;
            }
        } else {
            // ✅ LOG SI DÉSACTIVÉ
            static unsigned long lastDisabledLog = 0;
            if (currentTime - lastDisabledLog >= 10000) {
                Logger::warn("💧 [WARNING] Capteur eau DÉSACTIVÉ dans Config.h");
                lastDisabledLog = currentTime;
            }
        }
        
        lastObstacleCheckTime = currentTime;
    }
    
    // Mise à jour des buzzers (non-bloquant)
    updateBuzzer1();
    updateBuzzer2();
    updateWaterAlert();
}

// =======================================================
// UPDATE BUZZER 1 (HAUT)
// =======================================================
void ObstacleDetector::updateBuzzer1() {
    unsigned long now = millis();
    
    // Timeout - si pas de mesure depuis 500ms, éteindre
    if (now - lastMeasureTimeHaut > 500) {
        if (buzzer1State != BUZZER_OFF) {
            buzzer1Off();
            buzzer1State = BUZZER_OFF;
            currentDistanceHaut = -1;
        }
        return;
    }
    
    // Bip UNIQUEMENT si distance ≤ 30cm
    if (currentDistanceHaut == -1 || currentDistanceHaut > BUZZER_DISTANCE_SEUIL) {
        if (buzzer1State != BUZZER_OFF) {
            buzzer1Off();
            buzzer1State = BUZZER_OFF;
        }
        return;
    }
    
    // Danger immédiat : son continu
    if (currentDistanceHaut < BUZZER_DISTANCE_RAPIDE) {
        if (buzzer1State != BUZZER_CONTINUOUS) {
            buzzer1On();
            buzzer1State = BUZZER_CONTINUOUS;
            Logger::warn("🚨 [BUZZER1] MODE CONTINU (distance=" + String(currentDistanceHaut) + "cm)");
        }
        return;
    }
    
    // Calcul de l'intervalle selon la distance
    // Calcul de l'intervalle selon la distance (Non utilisé pour l'instant - on utilise la constante)
    // int interval = getIntervalForDistance(currentDistanceHaut);
    
    // Machine à états pour bip simple
    switch (buzzer1State) {
        case BUZZER_OFF:
        case BUZZER_CONTINUOUS:
            buzzer1On();
            buzzer1State = BUZZER_BIP_ON;
            buzzer1LastChange = now;
            Logger::info("🔊 [BUZZER1] Obstacle à " + String(currentDistanceHaut) + "cm");
            break;
            
        case BUZZER_BIP_ON:
            if (now - buzzer1LastChange >= BUZZER_BIP_DURATION) {
                buzzer1Off();
                buzzer1State = BUZZER_BIP_WAIT;
                buzzer1LastChange = now;
            }
            break;
            
        case BUZZER_BIP_WAIT:
            if (now - buzzer1LastChange >= BUZZER_INTERVAL) {
                buzzer1On();
                buzzer1State = BUZZER_BIP_ON;
                buzzer1LastChange = now;
            }
            break;
            
        default:
            buzzer1State = BUZZER_OFF;
            break;
    }
}

// =======================================================
// UPDATE BUZZER 2 (BAS)
// =======================================================
void ObstacleDetector::updateBuzzer2() {
    unsigned long now = millis();
    
    // Priorité à l'alerte eau : si active, on ne touche pas au buzzer
    if (waterAlertState != WATER_ALERT_OFF) {
        return;
    }

    // Timeout - si pas de mesure depuis 500ms, éteindre
    if (now - lastMeasureTimeBas > 500) {
        if (buzzer2State != BUZZER_OFF) {
            buzzer2Off();
            buzzer2State = BUZZER_OFF;
            currentDistanceBas = -1;
        }
        return;
    }
    
    // Bip UNIQUEMENT si distance ≤ 30cm
    if (currentDistanceBas == -1 || currentDistanceBas > BUZZER_DISTANCE_SEUIL) {
        if (buzzer2State != BUZZER_OFF) {
            buzzer2Off();
            buzzer2State = BUZZER_OFF;
        }
        return;
    }
    
    // Bip simple toutes les 0.5 secondes
    switch (buzzer2State) {
        case BUZZER_OFF:
        case BUZZER_CONTINUOUS:
            buzzer2On();
            buzzer2State = BUZZER_BIP_ON;
            buzzer2LastChange = now;
            Logger::info("🔊 [BUZZER2] Obstacle à " + String(currentDistanceBas) + "cm");
            break;
            
        case BUZZER_BIP_ON:
            if (now - buzzer2LastChange >= BUZZER_BIP_DURATION) {
                buzzer2Off();
                buzzer2State = BUZZER_BIP_WAIT;
                buzzer2LastChange = now;
            }
            break;
            
        case BUZZER_BIP_WAIT:
            if (now - buzzer2LastChange >= BUZZER_INTERVAL) {
                buzzer2On();
                buzzer2State = BUZZER_BIP_ON;
                buzzer2LastChange = now;
            }
            break;
            
        default:
            buzzer2State = BUZZER_OFF;
            break;
    }
}

// =======================================================
// UPDATE ALERTE EAU NON-BLOQUANTE
// =======================================================
void ObstacleDetector::updateWaterAlert() {
    if (!WATER_SENSOR_ENABLED) return;
    
    unsigned long currentTime = millis();
    
    switch (waterAlertState) {
        case WATER_ALERT_OFF:
            // Ne rien faire
            buzzer2Off();
            break;
            
        case WATER_ALERT_BIP1_ON:
            // ✅ Premier bip AIGU (2200 Hz)
            buzzer1On(); 
            buzzer2On(); // Tonalité aiguë
            Logger::info("🔊 [EAU] Bip 1 ON (2200 Hz)");
            
            if (currentTime - waterAlertLastChange >= 150) {
                waterAlertState = WATER_ALERT_BIP1_OFF;
                waterAlertLastChange = currentTime;
            }
            break;
            
        case WATER_ALERT_BIP1_OFF:
            // ✅ Pause entre bip 1 et 2
            buzzer1Off();
            Logger::info("🔊 [EAU] Bip 1 OFF");
            
            if (currentTime - waterAlertLastChange >= 100) {
                waterAlertState = WATER_ALERT_BIP2_ON;
                waterAlertLastChange = currentTime;
            }
            break;
            
        case WATER_ALERT_BIP2_ON:
            // ✅ Deuxième bip PLUS AIGU (2500 Hz)
            buzzer2On();
            buzzer1On();   // Encore plus aigu
            Logger::info("🔊 [EAU] Bip 2 ON (2500 Hz)");
            
            if (currentTime - waterAlertLastChange >= 150) {
                waterAlertState = WATER_ALERT_OFF;
                buzzer2Off();
                buzzer1Off();
                waterAlertLastChange = currentTime;
                Logger::info("🔊 [EAU] Séquence terminée");
            }
            break;
            
        case WATER_ALERT_SINGLE_BIP:
            // ✅ Bip unique long pour niveau moyen
            buzzer2On();
            buzzer1On();  // 1800 Hz
            Logger::info("🔊 [EAU] Bip unique (1800 Hz)");
            
            if (currentTime - waterAlertLastChange >= 300) {
                waterAlertState = WATER_ALERT_OFF;
                buzzer2Off();
                buzzer1Off(); 
                Logger::info("🔊 [EAU] Bip unique terminé");
            }
            break;
    }
}

// =======================================================
// CATÉGORIE DE DISTANCE (POUR LOGS)
// =======================================================
String ObstacleDetector::getDistanceCategory(int distance) {

    if (distance <= BUZZER_DISTANCE_SEUIL) {

        return "ALERTE";

    } else {

        return "OK";

    }

}

// =======================================================
// STOP
// =======================================================
void ObstacleDetector::stop() {
    Logger::info("🛑 [STOP] Arrêt ObstacleDetector...");
    buzzer1Off();
    buzzer2Off();
    
    // Detach seulement au stop
    if (servoMoteur.attached()) {
        servoMoteur.detach();
    }
    
    buzzer1State = BUZZER_OFF;
    buzzer2State = BUZZER_OFF;
    waterAlertState = WATER_ALERT_OFF;
    currentDistanceHaut = -1;
    currentDistanceBas = -1;
    ready = false;
    Logger::info("✅ [STOP] ObstacleDetector arrêté");
}

// =======================================================
// IS READY
// =======================================================
bool ObstacleDetector::isReady() const {
    return ready;
}

// =======================================================
// GET LAST OBSTACLE
// =======================================================
ObstacleInfo ObstacleDetector::getLastObstacle() const {
    return lastObstacle;
}

// =======================================================
// HAS OBSTACLE HIGH
// =======================================================
bool ObstacleDetector::hasObstacleHigh() const {
    return (lastObstacle.isHigh && 
            lastObstacle.distance > 0 && 
            lastObstacle.distance < OBSTACLE_DIST_SECURITE_HAUT);
}

// =======================================================
// HAS OBSTACLE LOW
// =======================================================
bool ObstacleDetector::hasObstacleLow() const {
    return (!lastObstacle.isHigh && 
            lastObstacle.distance > 0 && 
            lastObstacle.distance < OBSTACLE_DIST_SECURITE_BAS);
}

// =======================================================
// GET OBSTACLE DATA FOR BLE
// =======================================================
ObstacleData ObstacleDetector::getObstacleData() const {
    ObstacleData data;
    data.upper = lastDistanceHaut;
    data.lower = lastDistanceBas;
    data.servoAngle = angleActuel;
    return data;
}

// =======================================================
// GET WATER SENSOR DATA FOR BLE
// =======================================================
WaterSensorData ObstacleDetector::getWaterSensorData() const {
    WaterSensorData data;
    data.rawData = waterRawValue;
    data.humidityLevel = map(waterRawValue, 0, 4095, 0, 100);
    data.humidityLevel = constrain(data.humidityLevel, 0, 100);
    return data;
}

// =======================================================
// VÉRIFIER OBSTACLE HAUT
// =======================================================
void ObstacleDetector::verifierObstacleHaut() {
    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_HIGH, OBSTACLE_ECHO_HIGH,
                                        bufferHaut, &indexBufferHaut);

    // Mesure invalide
    if (distance <= 0 || distance >= 900) {
        // Ne pas réinitialiser immédiatement
        // On garde les anciennes valeurs pour éviter les coupures
        return;
    }

    // Variation excessive (probable erreur)
    if (distPrecedenteHaut != -1 && abs(distance - distPrecedenteHaut) > 150) {
        // On ignore cette mesure mais on garde l'ancienne
        return;
    }

    // Distance trop grande (hors portée)
    if (distance > 300) {
        currentDistanceHaut = -1;
        distPrecedenteHaut = -1;
        lastDistanceHaut = -1;
        return;
    }

    // Mesure valide - mettre à jour
    distPrecedenteHaut = distance;
    lastDistanceHaut = distance;
    currentDistanceHaut = distance;
    lastMeasureTimeHaut = millis();

    #ifdef DEBUG_MODE
    String category = getDistanceCategory(distance);
    Logger::info("🔍 [HAUT] Distance=" + String(distance) + "cm [" + category + "]");
    #endif

    if (distance < OBSTACLE_DIST_SECURITE_HAUT) {
        lastObstacle.distance = distance;
        lastObstacle.angle = 0;
        lastObstacle.isHigh = true;
        lastObstacle.timestamp = millis();
    }
}

// =======================================================
// BALAYER NIVEAU BAS
// =======================================================
void ObstacleDetector::balayerNiveauBas() {
    unsigned long now = millis();
    
    
    // Throttle pour le servo (éviter mouvements trop rapides)
    if (now - lastServoMoveTime < OBSTACLE_SERVO_DELAY) {
        return;
    }
    
    lastServoMoveTime = now;
    
    angleActuel += directionDroite ? OBSTACLE_ANGLE_STEP : -OBSTACLE_ANGLE_STEP;

    if (angleActuel >= OBSTACLE_ANGLE_MAX) {
        angleActuel = OBSTACLE_ANGLE_MAX;
        directionDroite = false;
    }
    if (angleActuel <= OBSTACLE_ANGLE_MIN) {
        angleActuel = OBSTACLE_ANGLE_MIN;
        directionDroite = true;
    }

    servoMoteur.write(angleActuel);

    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_LOW, OBSTACLE_ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    if (distance <= 0 || distance >= 900) {
        return;
    }

    // Variation excessive
    if (distPrecedenteBas != -1 && abs(distance - distPrecedenteBas) > 150) {
        return;
    }

    // Distance trop grande
    if (distance > 300) {
        currentDistanceBas = -1;
        distPrecedenteBas = -1;
        lastDistanceBas = -1;
        return;
    }

    // Mesure valide
    distPrecedenteBas = distance;
    lastDistanceBas = distance;
    currentDistanceBas = distance;
    lastMeasureTimeBas = millis();

    String dir = (angleActuel < 60) ? "GAUCHE" :
                 (angleActuel > 120) ? "DROITE" : "CENTRE";
    String category = getDistanceCategory(distance);
    
    Logger::info("🔍 [BAS] Angle=" + String(angleActuel) + "° Distance=" + 
                 String(distance) + "cm [" + dir + " / " + category + "]");

    if (distance < OBSTACLE_DIST_SECURITE_BAS) {
        lastObstacle.distance = distance;
        lastObstacle.angle = angleActuel;
        lastObstacle.isHigh = false;
        lastObstacle.timestamp = millis();
    }
}

// =======================================================
// VÉRIFIER EAU
// =======================================================
void ObstacleDetector::verifierEau() {
    Logger::info("💧 [EAU] Début vérification...");
    
    int niveau = lireNiveauEau();
    
    Logger::info("💧 [EAU] Niveau brut lu: " + String(niveau));
    Logger::info("💧 [EAU] Seuil LOW: " + String(WATER_THRESHOLD_LOW));
    Logger::info("💧 [EAU] Seuil HIGH: " + String(WATER_THRESHOLD_HIGH));
    
    lastWaterLevel = niveau;
    waterRawValue = niveau;
    
    // Détection eau
    if (niveau > WATER_THRESHOLD_LOW) {
        Logger::warn("💧 [EAU] EAU DÉTECTÉE ! Niveau=" + String(niveau));
        
        unsigned long currentTime = millis();
        if (currentTime - lastWaterAlertTime >= WATER_ALERT_COOLDOWN) {
            Logger::warn("💧 [EAU] Déclenchement alerte...");
            alerterEau(niveau);
            lastWaterAlertTime = currentTime;
        } else {
            Logger::info("💧 [EAU] Cooldown actif, pas d'alerte");
        }
    } else {
        Logger::info("💧 [EAU] Pas d'eau détectée (niveau trop bas)");
    }
}

// =======================================================
// LIRE NIVEAU EAU
// =======================================================
int ObstacleDetector::lireNiveauEau() {
    waterRawValue = analogRead(WATER_SENSOR_PIN);
    
    // Buffer statique au lieu de stack
    static int readings[5] = {0, 0, 0, 0, 0};
    static int index = 0;
    
    readings[index] = waterRawValue;
    index = (index + 1) % 5;
    
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        sum += readings[i];
    }
    
    int niveau = sum / 5;
    lastWaterLevel = niveau;
    
    return niveau;
}

// =======================================================
// ALERTER EAU - NON-BLOQUANT
// =======================================================
void ObstacleDetector::alerterEau(int niveau) {
    if (niveau > WATER_THRESHOLD_HIGH) {
        Logger::warn("🔊 [EAU] Alerte NIVEAU ÉLEVÉ (2 bips)");
        
        // Démarre la machine à états non-bloquante
        buzzer2On();
        waterAlertState = WATER_ALERT_BIP1_ON;
        waterAlertLastChange = millis();
        
    } 
}

// =======================================================
// MESURE DISTANCE - TIMEOUT RÉDUIT
// =======================================================
int ObstacleDetector::mesureDistance(int trigPin, int echoPin) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    // Timeout réduit à 30ms (au lieu de 50ms)
    // 30ms = ~5m de portée max (suffisant pour une canne)
    long duration = pulseIn(echoPin, HIGH, 30000);
    
    if (duration == 0) {
        return -1;
    }

    int distance = duration * 0.034 / 2;

    if (distance < 2 || distance > 400) {
        return -1;
    }

    return distance;
}

// =======================================================
// FILTRAGE MÉDIAN AMÉLIORÉ
// =======================================================
int ObstacleDetector::mesureDistanceFiltre(int trigPin, int echoPin,
                                           int* buffer, int* index) {
    // 2 mesures au lieu de 3
    int readings[2];
    for (int i = 0; i < 2; i++) {
        readings[i] = mesureDistance(trigPin, echoPin);
        delayMicroseconds(100);
    }
    
    // Rejeter les mesures invalides
    int validCount = 0;
    int sum = 0;
    for (int i = 0; i < 2; i++) {
        if (readings[i] > 0 && readings[i] < 400) {
            sum += readings[i];
            validCount++;
        }
    }
    
    // Si invalide, on garde l'ancien buffer
    if (validCount == 0) {
        // Ne pas vider le buffer, juste retourner -1
        return -1;
    }
    
    int avgDistance = (readings[0] + readings[1]) / 2;
    
    // Écart max 30cm → 50cm (plus permissif)
    int ecart = abs(readings[0] - readings[1]);
    if (ecart > 50) {
        return -1;
    }
    
    // Ajouter au buffer
    buffer[*index] = avgDistance;
    *index = (*index + 1) % OBSTACLE_BUFFER_SIZE;
    
    // Algorithme de tri fonctionnel
    // 1. Copier le buffer dans un tableau temporaire pour le trier
    int sorted[OBSTACLE_BUFFER_SIZE];
    int count = 0;
    
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        // On ne prend que les valeurs valides pour la médiane
        if (buffer[i] > 0 && buffer[i] < 400) {
            sorted[count] = buffer[i];
            count++;
        }
    }
    
    // Si pas assez de données valides
    if (count == 0) {
        return -1;
    }
    
    // 2. Tri à bulles (Bubble Sort) - simple et efficace pour n=3 ou 5
    for (int i = 0; i < count - 1; i++) {
        for (int j = 0; j < count - i - 1; j++) {
            if (sorted[j] > sorted[j + 1]) {
                // Swap
                int temp = sorted[j];
                sorted[j] = sorted[j + 1];
                sorted[j + 1] = temp;
            }
        }
    }
    
    // 3. Médiane
    int mediane = sorted[count / 2];
    
    return mediane;
}

// =======================================================
// BUZZER 1 - ON
// =======================================================
void ObstacleDetector::buzzer1On() {
    digitalWrite(BUZZER_1_PIN, HIGH);
}

// =======================================================
// BUZZER 1 - OFF
// =======================================================
void ObstacleDetector::buzzer1Off() {
    digitalWrite(BUZZER_1_PIN, LOW);
}

// =======================================================
// BUZZER 2 - ON
// =======================================================
void ObstacleDetector::buzzer2On() {
    digitalWrite(BUZZER_2_PIN, HIGH);
}

// =======================================================
// BUZZER 2 - OFF
// =======================================================
void ObstacleDetector::buzzer2Off() {
    digitalWrite(BUZZER_2_PIN, LOW);
}