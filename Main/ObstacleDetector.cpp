// ObstacleDetector.cpp - VERSION BUZZERS ACTIFS PROGRESSIFS + TIMEOUT
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
      lastMeasureTimeHaut(0),      // ⚠️ NOUVEAU
      lastMeasureTimeBas(0) {      // ⚠️ NOUVEAU
    
    Logger::info("🔧 [CONSTRUCTOR] ObstacleDetector créé");
    
    // ⚠️ MODIFIÉ : Initialiser buffer à -1 au lieu de 999
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

    // ===== CONFIGURATION SERVO =====
    Logger::info("🔄 [INIT] Configuration SERVO...");
    Logger::info("🔄 [INIT] Pin SERVO : GPIO" + String(OBSTACLE_SERVO_PIN));
    
    servoMoteur.setPeriodHertz(50);
    Logger::info("✅ [INIT] SERVO fréquence 50Hz OK");
    
    bool servoAttached = servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    if (servoAttached) {
        Logger::info("✅ [INIT] SERVO attaché avec succès");
    } else {
        Logger::error("❌ [INIT] ERREUR : SERVO pas attaché !");
    }
    
    Logger::info("🔄 [INIT] Position servo à 90°...");
    servoMoteur.write(90);
    delay(500);
    Logger::info("✅ [INIT] SERVO positionné à 90°");

    // ===== TEST SERVO (RAPIDE) =====
    Logger::info("🧪 [INIT] TEST SERVO : Balayage 0-180...");
    for (int angle = 0; angle <= 180; angle += 60) {  // ⚠️ MODIFIÉ : 60° au lieu de 30°
        servoMoteur.write(angle);
        Logger::info("🔄 [TEST] Servo angle=" + String(angle));
        delay(150);  // ⚠️ MODIFIÉ : 150ms au lieu de 200ms
    }
    servoMoteur.write(90);
    Logger::info("✅ [INIT] Test SERVO terminé - retour 90°");

    // ===== CONFIGURATION VIBRATION =====
    Logger::info("📳 [INIT] Configuration moteur vibrant...");
    pinMode(OBSTACLE_VIBRATOR_PIN, OUTPUT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
    Logger::info("✅ [INIT] Moteur vibrant : GPIO" + String(OBSTACLE_VIBRATOR_PIN));

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
    delay(200);  // ⚠️ MODIFIÉ : 200ms au lieu de 300ms
    digitalWrite(BUZZER_1_PIN, LOW);
    Logger::info("✅ [INIT] BUZZER 1 testé");
    
    delay(150);  // ⚠️ MODIFIÉ : 150ms au lieu de 200ms
    
    Logger::info("🔊 [INIT] TEST BUZZER 2...");
    digitalWrite(BUZZER_2_PIN, HIGH);
    delay(200);  // ⚠️ MODIFIÉ : 200ms au lieu de 300ms
    digitalWrite(BUZZER_2_PIN, LOW);
    Logger::info("✅ [INIT] BUZZER 2 testé");

    ready = true;
    Logger::info("========================================");
    Logger::info("✅ [INIT] ObstacleDetector PRÊT !");
    Logger::info("========================================");
}

// =======================================================
// UPDATE
// =======================================================
void ObstacleDetector::update() {
    if (!ready) {
        return;
    }

    unsigned long currentTime = millis();
    
    // Throttle
    if (currentTime - lastObstacleCheckTime < OBSTACLE_CHECK_INTERVAL) {
        updateBuzzer1();
        updateBuzzer2();
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
    }
}

// =======================================================
// ⚠️ MODIFIÉ : UPDATE BUZZER 1 (HAUT) - AVEC TIMEOUT
// =======================================================
// =======================================================
// ⚠️ SIMPLIFIÉ : UPDATE BUZZER 1 - VERSION RAPIDE
// =======================================================
// =======================================================
// ⚠️ SIMPLIFIÉ : UPDATE BUZZER 1 - 1 SEUL BIP À 30CM
// =======================================================
void ObstacleDetector::updateBuzzer1() {
    unsigned long now = millis();
    
    // Timeout
    if (now - lastMeasureTimeHaut > 300) {
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
    
    // ⚠️ SIMPLIFIÉ : Bip simple toutes les 0.5 secondes
    switch (buzzer1State) {
        case BUZZER_OFF:
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
// =======================================================
// ⚠️ SIMPLIFIÉ : UPDATE BUZZER 2 - 1 SEUL BIP À 30CM
// =======================================================
void ObstacleDetector::updateBuzzer2() {
    unsigned long now = millis();
    
    // Timeout
    if (now - lastMeasureTimeBas > 300) {
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
    stopVibration();
    servoMoteur.detach();
    buzzer1State = BUZZER_OFF;
    buzzer2State = BUZZER_OFF;
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
// ⚠️ MODIFIÉ : VÉRIFIER OBSTACLE HAUT
// =======================================================
void ObstacleDetector::verifierObstacleHaut() {
    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_HIGH, OBSTACLE_ECHO_HIGH,
                                        bufferHaut, &indexBufferHaut);

    // ⚠️ MODIFIÉ : Réinitialiser TOUT
    if (distance <= 0 || distance >= 900) {
        currentDistanceHaut = -1;
        distPrecedenteHaut = -1;
        lastDistanceHaut = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ MODIFIÉ : Réinitialiser si variation excessive
    if (distPrecedenteHaut != -1 && abs(distance - distPrecedenteHaut) > 150) {
        currentDistanceHaut = -1;
        distPrecedenteHaut = -1;
        lastDistanceHaut = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ MODIFIÉ : Réinitialiser si distance > 300cm
    if (distance > 300) {
        currentDistanceHaut = -1;
        distPrecedenteHaut = -1;
        lastDistanceHaut = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ NOUVEAU : Mesure valide - mettre à jour timestamp
    distPrecedenteHaut = distance;
    lastDistanceHaut = distance;
    currentDistanceHaut = distance;
    lastMeasureTimeHaut = millis();  // ⚠️ AJOUT

    String category = getDistanceCategory(distance);
    Logger::info("🔍 [HAUT] Distance=" + String(distance) + "cm [" + category + "]");

    if (distance < OBSTACLE_DIST_SECURITE_HAUT) {
        lastObstacle.distance = distance;
        lastObstacle.angle = 0;
        lastObstacle.isHigh = true;
        lastObstacle.timestamp = millis();
    }
}

// =======================================================
// ⚠️ MODIFIÉ : BALAYER NIVEAU BAS
// =======================================================
void ObstacleDetector::balayerNiveauBas() {
    angleActuel += directionDroite ? OBSTACLE_ANGLE_STEP : -OBSTACLE_ANGLE_STEP;

    if (angleActuel >= OBSTACLE_ANGLE_MAX) {
        angleActuel = OBSTACLE_ANGLE_MAX;
        directionDroite = false;
    }
    if (angleActuel <= OBSTACLE_ANGLE_MIN) {
        angleActuel = OBSTACLE_ANGLE_MIN;
        directionDroite = true;
    }

    // ⚠️ NOUVEAU : Attach/Detach pour économiser
    servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    servoMoteur.write(angleActuel);
    delay(OBSTACLE_SERVO_DELAY);
    servoMoteur.detach();  // ⚠️ AJOUT

    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_LOW, OBSTACLE_ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    // ⚠️ MODIFIÉ : Réinitialiser TOUT
    if (distance <= 0 || distance >= 900) {
        currentDistanceBas = -1;
        distPrecedenteBas = -1;
        lastDistanceBas = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ MODIFIÉ : Réinitialiser si variation excessive
    if (distPrecedenteBas != -1 && abs(distance - distPrecedenteBas) > 150) {
        currentDistanceBas = -1;
        distPrecedenteBas = -1;
        lastDistanceBas = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ MODIFIÉ : Réinitialiser si distance > 300cm
    if (distance > 300) {
        currentDistanceBas = -1;
        distPrecedenteBas = -1;
        lastDistanceBas = -1;  // ⚠️ AJOUT
        return;
    }

    // ⚠️ NOUVEAU : Mesure valide - mettre à jour timestamp
    distPrecedenteBas = distance;
    lastDistanceBas = distance;
    currentDistanceBas = distance;
    lastMeasureTimeBas = millis();  // ⚠️ AJOUT

    // String dir = (angleActuel < 60) ? "GAUCHE" :
    //              (angleActuel > 120) ? "DROITE" : "CENTRE";
    // String category = getDistanceCategory(distance);
    
    // Logger::info("🔍 [BAS] Angle=" + String(angleActuel) + "° Distance=" + 
    //              String(distance) + "cm [" + dir + " / " + category + "]");

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
// ALERTER EAU (BUZZER 2 - PATTERNS SPÉCIAUX)
// =======================================================
void ObstacleDetector::alerterEau(int niveau) {
    if (niveau > WATER_THRESHOLD_HIGH) {
        Logger::warn("🔊 [EAU] Alerte NIVEAU ÉLEVÉ (2 bips)");
        
        digitalWrite(BUZZER_2_PIN, HIGH);
        delay(300);
        digitalWrite(BUZZER_2_PIN, LOW);
        delay(100);
        digitalWrite(BUZZER_2_PIN, HIGH);
        delay(300);
        digitalWrite(BUZZER_2_PIN, LOW);
        
        if (OBSTACLE_VIBRATION_ENABLED) {
            vibrerPattern(4);
        }
        
    } else if (niveau > WATER_THRESHOLD_LOW) {
        Logger::info("🔊 [EAU] Alerte niveau moyen (1 bip)");
        
        digitalWrite(BUZZER_2_PIN, HIGH);
        delay(300);
        digitalWrite(BUZZER_2_PIN, LOW);
        
        if (OBSTACLE_VIBRATION_ENABLED) {
            vibrerCourt();
        }
    }
}

// =======================================================
// MESURE DISTANCE
// =======================================================
int ObstacleDetector::mesureDistance(int trigPin, int echoPin) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH, 50000);
    
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
// ⚠️ MODIFIÉ : FILTRAGE MÉDIAN
// =======================================================
// =======================================================
// ⚠️ MODIFIÉ : FILTRAGE AMÉLIORÉ - 2 MESURES + 50MS
// =======================================================
// =======================================================
// ⚠️ OPTIMISÉ : FILTRAGE RAPIDE - 2 MESURES + 10MS
// =======================================================
int ObstacleDetector::mesureDistanceFiltre(int trigPin, int echoPin,
                                           int* buffer, int* index) {
    // ⚠️ 2 mesures avec délai de 10ms (au lieu de 50ms)
    int readings[2];
    
    readings[0] = mesureDistance(trigPin, echoPin);
    delay(10);  // ⚠️ RÉDUIT : 50ms → 10ms
    
    readings[1] = mesureDistance(trigPin, echoPin);
    
    // Validation stricte
    bool mesure1Valide = (readings[0] > 0 && readings[0] < 400);
    bool mesure2Valide = (readings[1] > 0 && readings[1] < 400);
    
    if (!mesure1Valide || !mesure2Valide) {
        for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
            buffer[i] = -1;
        }
        *index = 0;
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
    
    int moyenne = sum / count;
    
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

// =======================================================
// VIBRATION COURTE
// =======================================================
void ObstacleDetector::vibrerCourt() {
    digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
    delay(OBSTACLE_VIBRATION_PATTERN_SHORT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}

// =======================================================
// VIBRATION LONGUE
// =======================================================
void ObstacleDetector::vibrerLong() {
    digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
    delay(OBSTACLE_VIBRATION_PATTERN_LONG);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}

// =======================================================
// PATTERN DE VIBRATIONS
// =======================================================
void ObstacleDetector::vibrerPattern(int count) {
    for (int i = 0; i < count; i++) {
        digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
        delay(OBSTACLE_VIBRATION_PATTERN_SHORT);
        digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
        
        if (i < count - 1) {
            delay(OBSTACLE_VIBRATION_PAUSE);
        }
    }
}

// =======================================================
// ARRÊTER VIBRATION
// =======================================================
void ObstacleDetector::stopVibration() {
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}