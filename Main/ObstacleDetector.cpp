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
// UPDATE - ✅ SANS AUCUN DELAY
// =======================================================
void ObstacleDetector::update() {
    if (!ready) {
        return;
    }

    unsigned long currentTime = millis();
    
    // Throttle général
    if (currentTime - lastObstacleCheckTime < OBSTACLE_CHECK_INTERVAL) {
        // Même en throttle, on update les buzzers
        updateBuzzer1();
        updateBuzzer2();
        updateWaterAlert();  // ✅ NOUVEAU : Alerte eau non-bloquante
        return;
    }
    
    lastObstacleCheckTime = currentTime;

    // Vérifier obstacles
    verifierObstacleHaut();
    balayerNiveauBas();

    // Update buzzers
    updateBuzzer1();
    updateBuzzer2();
    
    // Vérifier eau
    if (WATER_SENSOR_ENABLED) {
        verifierEau();
        updateWaterAlert();  // ✅ NOUVEAU : Alerte eau non-bloquante
    }
}

// =======================================================
// ✅ CORRECTION : UPDATE BUZZER 1 (HAUT) - TIMEOUT AUGMENTÉ
// =======================================================
// =======================================================
// ⚠️ SIMPLIFIÉ : UPDATE BUZZER 1 - VERSION RAPIDE
// =======================================================
// =======================================================
// ⚠️ SIMPLIFIÉ : UPDATE BUZZER 1 - 1 SEUL BIP À 30CM
// =======================================================
void ObstacleDetector::updateBuzzer1() {
    unsigned long now = millis();
    
    // ⚠️ NOUVEAU : Timeout - si pas de mesure depuis 500ms, éteindre
    if (now - lastMeasureTimeHaut > 500) {
        if (buzzer1State != BUZZER_OFF) {
            buzzer1Off();
            buzzer1State = BUZZER_OFF;
            currentDistanceHaut = -1;
        }
        return;
    }
    
    // ⚠️ NOUVEAU : Bip UNIQUEMENT si distance ≤ 30cm
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
    int interval = getIntervalForDistance(currentDistanceHaut);
    
    // Machine à états pour bip simple
    switch (buzzer1State) {
        case BUZZER_OFF:
        case BUZZER_CONTINUOUS:  // ⚠️ AJOUT : Reset depuis continu
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
// ⚠️ MODIFIÉ : UPDATE BUZZER 2 (BAS) - AVEC TIMEOUT
// =======================================================
void ObstacleDetector::updateBuzzer2() {
    unsigned long now = millis();
    
    // ⚠️ NOUVEAU : Timeout - si pas de mesure depuis 500ms, éteindre
    if (now - lastMeasureTimeBas > 500) {
        if (buzzer2State != BUZZER_OFF) {
            buzzer2Off();
            buzzer2State = BUZZER_OFF;
            currentDistanceBas = -1;
        }
        return;
    }
    
    // ⚠️ NOUVEAU : Bip UNIQUEMENT si distance ≤ 30cm
    if (currentDistanceBas == -1 || currentDistanceBas > BUZZER_DISTANCE_SEUIL) {
        if (buzzer2State != BUZZER_OFF) {
            buzzer2Off();
            buzzer2State = BUZZER_OFF;
        }
        return;
    }
    
    // ⚠️ SIMPLIFIÉ : Bip simple toutes les 0.5 secondes
    switch (buzzer2State) {
        case BUZZER_OFF:
        case BUZZER_CONTINUOUS:  // ⚠️ AJOUT : Reset depuis continu
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
// ✅ NOUVEAU : UPDATE ALERTE EAU NON-BLOQUANTE
// =======================================================
void ObstacleDetector::updateWaterAlert() {
    unsigned long now = millis();
    
    switch (waterAlertState) {
        case WATER_ALERT_OFF:
            // Rien à faire
            break;
            
        case WATER_ALERT_BIP1_ON:
            if (now - waterAlertLastChange >= 300) {
                digitalWrite(BUZZER_2_PIN, LOW);
                waterAlertState = WATER_ALERT_BIP1_OFF;
                waterAlertLastChange = now;
            }
            break;
            
        case WATER_ALERT_BIP1_OFF:
            if (now - waterAlertLastChange >= 100) {
                digitalWrite(BUZZER_2_PIN, HIGH);
                waterAlertState = WATER_ALERT_BIP2_ON;
                waterAlertLastChange = now;
            }
            break;
            
        case WATER_ALERT_BIP2_ON:
            if (now - waterAlertLastChange >= 300) {
                digitalWrite(BUZZER_2_PIN, LOW);
                waterAlertState = WATER_ALERT_OFF;
                waterAlertLastChange = now;
            }
            break;
    }
}

// =======================================================
// CALCUL INTERVALLE SELON DISTANCE
// =======================================================
// int ObstacleDetector::getIntervalForDistance(int distance) {
//     if (distance >= BUZZER_DISTANCE_LENT) {
//         return BUZZER_INTERVAL_LENT;
//     } else if (distance >= BUZZER_DISTANCE_MOYEN) {
//         return BUZZER_INTERVAL_MOYEN;
//     } else if (distance >= BUZZER_DISTANCE_RAPIDE) {
//         return BUZZER_INTERVAL_RAPIDE;
//     }
//     return 0; // Continu
// }

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
    
    // ✅ CORRECTION : Detach seulement au stop
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
// ✅ CORRECTION : VÉRIFIER OBSTACLE HAUT
// =======================================================
void ObstacleDetector::verifierObstacleHaut() {
    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_HIGH, OBSTACLE_ECHO_HIGH,
                                        bufferHaut, &indexBufferHaut);

    // Mesure invalide
    if (distance <= 0 || distance >= 900) {
        // ✅ CORRECTION : Ne pas réinitialiser immédiatement
        // On garde les anciennes valeurs pour éviter les coupures
        return;
    }

    // Variation excessive (probable erreur)
    if (distPrecedenteHaut != -1 && abs(distance - distPrecedenteHaut) > 150) {
        // ✅ CORRECTION : On ignore cette mesure mais on garde l'ancienne
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
// ✅ CORRECTION : BALAYER NIVEAU BAS - SANS ATTACH/DETACH
// =======================================================
void ObstacleDetector::balayerNiveauBas() {
    unsigned long now = millis();
    
    // ✅ CORRECTION : Throttle pour le servo (éviter mouvements trop rapides)
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

    // ✅ CORRECTION : Pas de attach/detach, juste write
    servoMoteur.write(angleActuel);

    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_LOW, OBSTACLE_ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    // Mesure invalide
    if (distance <= 0 || distance >= 900) {
        // ✅ CORRECTION : Ne pas réinitialiser immédiatement
        return;
    }

    // Variation excessive
    if (distPrecedenteBas != -1 && abs(distance - distPrecedenteBas) > 150) {
        // ✅ CORRECTION : On ignore cette mesure
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

    // String dir = (angleActuel < 60) ? "GAUCHE" :
    //              (angleActuel > 120) ? "DROITE" : "CENTRE";
    // String category = getDistanceCategory(distance);
    
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
    unsigned long currentTime = millis();
    
    if (currentTime - lastWaterCheckTime < WATER_CHECK_INTERVAL) {
        return;
    }
    
    lastWaterCheckTime = currentTime;
    int niveau = lireNiveauEau();
    
    if (niveau > WATER_THRESHOLD_LOW) {
        if (currentTime - lastWaterAlertTime > WATER_ALERT_COOLDOWN) {
            Logger::warn("💧 [EAU] EAU DÉTECTÉE (niveau=" + String(niveau) + ") !");
            alerterEau(niveau);
            lastWaterAlertTime = currentTime;
        }
    }
}

// =======================================================
// LIRE NIVEAU EAU
// =======================================================
int ObstacleDetector::lireNiveauEau() {
    waterRawValue = analogRead(WATER_SENSOR_PIN);
    
    // ✅ CORRECTION : Buffer statique au lieu de stack
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
// ✅ CORRECTION : ALERTER EAU - NON-BLOQUANT
// =======================================================
void ObstacleDetector::alerterEau(int niveau) {
    if (niveau > WATER_THRESHOLD_HIGH) {
        Logger::warn("🔊 [EAU] Alerte NIVEAU ÉLEVÉ (2 bips)");
        
        // ✅ CORRECTION : Démarre la machine à états non-bloquante
        digitalWrite(BUZZER_2_PIN, HIGH);
        waterAlertState = WATER_ALERT_BIP1_ON;
        waterAlertLastChange = millis();
        

        
    } else if (niveau > WATER_THRESHOLD_LOW) {
        Logger::info("🔊 [EAU] Alerte niveau moyen (1 bip)");
        
        // ✅ CORRECTION : Un seul bip court
        digitalWrite(BUZZER_2_PIN, HIGH);
        waterAlertState = WATER_ALERT_BIP1_ON;
        waterAlertLastChange = millis();
        

    }
}

// =======================================================
// ✅ CORRECTION : MESURE DISTANCE - TIMEOUT RÉDUIT
// =======================================================
int ObstacleDetector::mesureDistance(int trigPin, int echoPin) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    // ✅ CORRECTION : Timeout réduit à 30ms (au lieu de 50ms)
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
// ✅ CORRECTION : FILTRAGE MÉDIAN AMÉLIORÉ
// =======================================================
// =======================================================
// ⚠️ MODIFIÉ : FILTRAGE AMÉLIORÉ - 2 MESURES + 50MS
// =======================================================
// =======================================================
// ⚠️ OPTIMISÉ : FILTRAGE RAPIDE - 2 MESURES + 10MS
// =======================================================
int ObstacleDetector::mesureDistanceFiltre(int trigPin, int echoPin,
                                           int* buffer, int* index) {
    // ⚠️ MODIFIÉ : 2 mesures au lieu de 3
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
    
    // ✅ CORRECTION : Si invalide, on garde l'ancien buffer
    if (validCount == 0) {
        // Ne pas vider le buffer, juste retourner -1
        return -1;
    }
    
    int avgDistance = (readings[0] + readings[1]) / 2;
    
    // ⚠️ RÉDUIT : Écart max 30cm → 50cm (plus permissif)
    int ecart = abs(readings[0] - readings[1]);
    if (ecart > 50) {
        return -1;
    }
    
    // Ajouter au buffer
    buffer[*index] = avgDistance;
    *index = (*index + 1) % OBSTACLE_BUFFER_SIZE;
    
    // ⚠️ SIMPLIFICATION : Pas de médiane, juste moyenne des valeurs valides
    int sum = 0;
    int count = 0;
    
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        if (buffer[i] > 0 && buffer[i] < 400) {
            sum += buffer[i];
            count++;
        }
    }
    
    if (count == 0) {
        return -1;
    }
    
    // Tri
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE - 1; i++)
        for (int j = 0; j < OBSTACLE_BUFFER_SIZE - i - 1; j++)
            if (sorted[j] > sorted[j + 1])
                std::swap(sorted[j], sorted[j + 1]);
    
    int median = sorted[OBSTACLE_BUFFER_SIZE / 2];
    
    if (moyenne <= 0 || moyenne > 900) {
        return -1;
    }
    
    return moyenne;
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
