// ObstacleDetector.cpp - ✅ VERSION DEBUG INTENSIVE
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
      lastObstacleCheckTime(0) {
    
    Logger::info("🔧 [CONSTRUCTOR] ObstacleDetector créé");
    
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        bufferHaut[i] = 999;
        bufferBas[i] = 999;
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

    // ===== TEST SERVO =====
    Logger::info("🧪 [INIT] TEST SERVO : Balayage 0-180...");
    for (int angle = 0; angle <= 180; angle += 30) {
        servoMoteur.write(angle);
        Logger::info("🔄 [TEST] Servo angle=" + String(angle));
        delay(200);
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

    // ===== TEST BUZZERS =====
    Logger::info("🔊 [INIT] TEST BUZZER 1 (GPIO" + String(BUZZER_1_PIN) + ")...");
    buzzer1Tone(OBSTACLE_FREQ_DEMARRAGE);
    delay(300);
    buzzer1Off();
    Logger::info("✅ [INIT] BUZZER 1 testé");
    
    delay(200);
    
    Logger::info("🔊 [INIT] TEST BUZZER 2 (GPIO" + String(BUZZER_2_PIN) + ")...");
    buzzer2Tone(WATER_FREQ_ALERT);
    delay(300);
    buzzer2Off();
    Logger::info("✅ [INIT] BUZZER 2 testé");

    ready = true;
    Logger::info("========================================");
    Logger::info("✅ [INIT] ObstacleDetector PRÊT !");
    Logger::info("========================================");
}

// =======================================================
// UPDATE (✅ AVEC LOGS DEBUG)
// =======================================================
void ObstacleDetector::update() {
    if (!ready) {
        Logger::warn("⚠️ [UPDATE] Module pas prêt - skip");
        return;
    }

    unsigned long currentTime = millis();
    
    // Throttle
    if (currentTime - lastObstacleCheckTime < OBSTACLE_CHECK_INTERVAL) {
        return;
    }
    
    lastObstacleCheckTime = currentTime;

    #ifdef DEBUG_MODE
    static unsigned long lastDebugLog = 0;
    if (currentTime - lastDebugLog > 5000) {
        Logger::info("🔍 [UPDATE] Cycle détection en cours...");
        Logger::info("🔍 [UPDATE] Angle servo actuel : " + String(angleActuel));
        Logger::info("🔍 [UPDATE] Direction : " + String(directionDroite ? "DROITE" : "GAUCHE"));
        lastDebugLog = currentTime;
    }
    #endif

    // Vérifier obstacles
    verifierObstacleHaut();
    balayerNiveauBas();

    
    // Vérifier eau
    if (WATER_SENSOR_ENABLED) {
        verifierEau();
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
    Logger::info("📏 [HAUT] Mesure distance obstacle HAUT...");
    
    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_HIGH, OBSTACLE_ECHO_HIGH,
                                        bufferHaut, &indexBufferHaut);

    if (distance <= 0) {
        Logger::warn("⚠️ [HAUT] Mesure invalide (distance=" + String(distance) + ")");
        return;
    }

    Logger::info("📏 [HAUT] Distance mesurée : " + String(distance) + " cm");

    if (distPrecedenteHaut != -1 &&
        abs(distance - distPrecedenteHaut) > OBSTACLE_SEUIL_VARIATION) {
        Logger::warn("⚠️ [HAUT] Variation trop grande - rejet (précédent=" + 
                     String(distPrecedenteHaut) + " nouveau=" + String(distance) + ")");
        return;
    }

    distPrecedenteHaut = distance;
    lastDistanceHaut = distance;

    if (distance < OBSTACLE_DIST_SECURITE_HAUT) {
        Logger::warn("🚨 [HAUT] OBSTACLE DÉTECTÉ à " + String(distance) + " cm !");

        lastObstacle.distance = distance;
        lastObstacle.angle = 0;
        lastObstacle.isHigh = true;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeHaut > OBSTACLE_ALERT_COOLDOWN) {
            Logger::warn("🔊 [HAUT] ALERTE SONORE activée");
            alerterObstacle(distance, OBSTACLE_FREQ_HAUT);
            
            if (OBSTACLE_VIBRATION_ENABLED) {
                Logger::info("📳 [HAUT] Vibration activée");
                vibrerPattern(2);
            }
            
            lastAlertTimeHaut = now;
        } else {
            Logger::info("⏳ [HAUT] Cooldown actif - pas d'alerte");
        }
    } else {
        Logger::info("✅ [HAUT] Pas d'obstacle (distance=" + String(distance) + " cm)");
    }
}

// =======================================================
// BALAYER NIVEAU BAS
// =======================================================
void ObstacleDetector::balayerNiveauBas() {
    int oldAngle = angleActuel;
    angleActuel += directionDroite ? OBSTACLE_ANGLE_STEP : -OBSTACLE_ANGLE_STEP;

    if (angleActuel >= OBSTACLE_ANGLE_MAX) {
        angleActuel = OBSTACLE_ANGLE_MAX;
        directionDroite = false;
        Logger::info("🔄 [SERVO] Inversion direction -> GAUCHE");
    }
    if (angleActuel <= OBSTACLE_ANGLE_MIN) {
        angleActuel = OBSTACLE_ANGLE_MIN;
        directionDroite = true;
        Logger::info("🔄 [SERVO] Inversion direction -> DROITE");
    }

    Logger::info("🔄 [SERVO] Rotation : " + String(oldAngle) + "° -> " + String(angleActuel) + "°");
    servoMoteur.write(angleActuel);
    delay(OBSTACLE_SERVO_DELAY);

    Logger::info("📏 [BAS] Mesure distance obstacle BAS...");
    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_LOW, OBSTACLE_ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    if (distance <= 0) {
        Logger::warn("⚠️ [BAS] Mesure invalide (distance=" + String(distance) + ")");
        return;
    }

    Logger::info("📏 [BAS] Distance mesurée : " + String(distance) + " cm (angle=" + String(angleActuel) + "°)");

    if (distPrecedenteBas != -1 &&
        abs(distance - distPrecedenteBas) > OBSTACLE_SEUIL_VARIATION) {
        Logger::warn("⚠️ [BAS] Variation trop grande - rejet");
        return;
    }

    distPrecedenteBas = distance;
    lastDistanceBas = distance;

    if (distance < OBSTACLE_DIST_SECURITE_BAS) {
        String dir = (angleActuel < 60) ? "GAUCHE" :
                     (angleActuel > 120) ? "DROITE" : "CENTRE";
        
        Logger::warn("🚨 [BAS] OBSTACLE DÉTECTÉ à " + String(distance) + " cm (" + dir + ") !");

        lastObstacle.distance = distance;
        lastObstacle.angle = angleActuel;
        lastObstacle.isHigh = false;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeBas > OBSTACLE_ALERT_COOLDOWN) {
            int freq = (angleActuel < 60)  ? OBSTACLE_FREQ_BAS_GAUCHE :
                       (angleActuel > 120) ? OBSTACLE_FREQ_BAS_DROITE : 
                                             OBSTACLE_FREQ_BAS_CENTRE;

            Logger::warn("🔊 [BAS] ALERTE SONORE " + dir + " (freq=" + String(freq) + "Hz)");
            alerterObstacle(distance, freq);
            
            if (OBSTACLE_VIBRATION_ENABLED) {
                Logger::info("📳 [BAS] Vibration " + dir);
                if (angleActuel < 60) {
                    vibrerLong();
                } else if (angleActuel > 120) {
                    vibrerPattern(3);
                } else {
                    vibrerCourt();
                }
            }
            
            lastAlertTimeBas = now;
        } else {
            Logger::info("⏳ [BAS] Cooldown actif - pas d'alerte");
        }
    } else {
        Logger::info("✅ [BAS] Pas d'obstacle (distance=" + String(distance) + " cm)");
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
    
    Logger::info("💧 [EAU] Niveau : " + String(niveau) + " (seuil=" + String(WATER_THRESHOLD_LOW) + ")");
    
    if (niveau > WATER_THRESHOLD_LOW) {
        if (currentTime - lastWaterAlertTime > WATER_ALERT_COOLDOWN) {
            Logger::warn("💧 [EAU] EAU DÉTECTÉE !");
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
// ALERTER EAU (BUZZER 2)
// =======================================================
void ObstacleDetector::alerterEau(int niveau) {
    if (niveau > WATER_THRESHOLD_HIGH) {
        Logger::warn("🔊 [EAU] Alerte NIVEAU ÉLEVÉ (2 bips)");
        
        buzzer2Tone(WATER_FREQ_WARNING);
        delay(300);
        buzzer2Off();
        delay(100);
        buzzer2Tone(WATER_FREQ_WARNING);
        delay(300);
        buzzer2Off();
        
        if (OBSTACLE_VIBRATION_ENABLED) {
            vibrerPattern(4);
        }
        
    } else if (niveau > WATER_THRESHOLD_LOW) {
        Logger::info("🔊 [EAU] Alerte niveau moyen (1 bip)");
        
        buzzer2Tone(WATER_FREQ_ALERT);
        delay(300);
        buzzer2Off();
        
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
        Logger::warn("⚠️ [MESURE] Timeout - pas d'écho reçu");
        return -1;
    }

    int distance = duration * 0.034 / 2;

    if (distance < 2 || distance > 400) {
        Logger::warn("⚠️ [MESURE] Distance hors limites : " + String(distance) + " cm");
        return -1;
    }

    return distance;
}

// =======================================================
// FILTRAGE MÉDIAN
// =======================================================
int ObstacleDetector::mesureDistanceFiltre(int trigPin, int echoPin,
                                           int* buffer, int* index) {
    int d = mesureDistance(trigPin, echoPin);
    if (d < 0) return -1;

    buffer[*index] = d;
    *index = (*index + 1) % OBSTACLE_BUFFER_SIZE;

    int sorted[OBSTACLE_BUFFER_SIZE];
    memcpy(sorted, buffer, sizeof(sorted));

    for (int i = 0; i < OBSTACLE_BUFFER_SIZE - 1; i++)
        for (int j = 0; j < OBSTACLE_BUFFER_SIZE - i - 1; j++)
            if (sorted[j] > sorted[j + 1])
                std::swap(sorted[j], sorted[j + 1]);

    int median = sorted[OBSTACLE_BUFFER_SIZE / 2];
    Logger::info("📊 [FILTRE] Médian=" + String(median) + " cm");
    
    return median;
}

// =======================================================
// ALERTER OBSTACLE (BUZZER 1)
// =======================================================
void ObstacleDetector::alerterObstacle(int distance, int frequence) {
    distance = constrain(distance, 2, 150);
    int duree = map(distance, 2, 150, 300, 50);

    Logger::info("🔊 [BUZZER1] Freq=" + String(frequence) + "Hz Durée=" + String(duree) + "ms");
    
    buzzer1Tone(frequence);
    delay(duree);
    buzzer1Off();
    delay(50);
}

// =======================================================
// BUZZER 1 - ON (ESP32 Core 2.0.x)
// =======================================================
void ObstacleDetector::buzzer1Tone(int frequence) {
    Logger::info("🔊 [BUZZER1] ON - Canal" + String(BUZZER_1_CHANNEL) + " @ " + String(frequence) + "Hz");
    ledcWriteTone(BUZZER_1_CHANNEL, frequence);
}

// =======================================================
// BUZZER 1 - OFF (ESP32 Core 2.0.x)
// =======================================================
void ObstacleDetector::buzzer1Off() {
    Logger::info("🔇 [BUZZER1] OFF - Canal" + String(BUZZER_1_CHANNEL));
    ledcWriteTone(BUZZER_1_CHANNEL, 0);
}

// =======================================================
// BUZZER 2 - ON (ESP32 Core 2.0.x)
// =======================================================
void ObstacleDetector::buzzer2Tone(int frequence) {
    Logger::info("🔊 [BUZZER2] ON - Canal" + String(BUZZER_2_CHANNEL) + " @ " + String(frequence) + "Hz");
    ledcWriteTone(BUZZER_2_CHANNEL, frequence);
}

// =======================================================
// BUZZER 2 - OFF (ESP32 Core 2.0.x)
// =======================================================
void ObstacleDetector::buzzer2Off() {
    Logger::info("🔇 [BUZZER2] OFF - Canal" + String(BUZZER_2_CHANNEL));
    ledcWriteTone(BUZZER_2_CHANNEL, 0);
}

// =======================================================
// VIBRATION COURTE
// =======================================================
void ObstacleDetector::vibrerCourt() {
    Logger::info("📳 [VIB] Court");
    digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
    delay(OBSTACLE_VIBRATION_PATTERN_SHORT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}

// =======================================================
// VIBRATION LONGUE
// =======================================================
void ObstacleDetector::vibrerLong() {
    Logger::info("📳 [VIB] Long");
    digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
    delay(OBSTACLE_VIBRATION_PATTERN_LONG);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}

// =======================================================
// PATTERN DE VIBRATIONS
// =======================================================
void ObstacleDetector::vibrerPattern(int count) {
    Logger::info("📳 [VIB] Pattern x" + String(count));
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
    Logger::info("📳 [VIB] Stop");
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}