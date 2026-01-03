// ObstacleDetector.cpp - ✅ VERSION CORRIGÉE
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
      lastObstacleCheckTime(0) {  // ✅ AJOUTÉ
    
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        bufferHaut[i] = 999;
        bufferBas[i] = 999;
    }
}

// =======================================================
// INIT
// =======================================================
void ObstacleDetector::init() {
    Logger::info("Initialisation détection obstacles + eau");

    // Configuration des capteurs ultrasons
    pinMode(OBSTACLE_TRIG_HIGH, OUTPUT);
    pinMode(OBSTACLE_ECHO_HIGH, INPUT);
    pinMode(OBSTACLE_TRIG_LOW, OUTPUT);
    pinMode(OBSTACLE_ECHO_LOW, INPUT);

    // Configuration du servo
    servoMoteur.setPeriodHertz(50);
    servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    servoMoteur.write(90);
    delay(200);  // ✅ Laisser le servo se stabiliser

    // ✅ SUPPRESSION de l'initialisation PWM (déjà fait dans Main.ino)
    // Les buzzers sont déjà configurés dans setup()

    // Configuration du moteur vibrant
    pinMode(OBSTACLE_VIBRATOR_PIN, OUTPUT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
    Logger::info("Moteur vibrant configuré sur GPIO " + String(OBSTACLE_VIBRATOR_PIN));

    // ✅ CAPTEUR D'EAU - GPIO 34 (Analogique)
    pinMode(WATER_SENSOR_PIN, INPUT);
    Logger::info("Capteur d'eau configuré sur GPIO " + String(WATER_SENSOR_PIN));

    // ✅ Test des 2 buzzers au démarrage (SIMPLIFIÉ)
    Logger::info("Test buzzers...");
    buzzer1Tone(OBSTACLE_FREQ_DEMARRAGE);
    delay(200);
    buzzer1Off();
    delay(100);
    
    buzzer2Tone(WATER_FREQ_ALERT);
    delay(200);
    buzzer2Off();
    delay(100);

    ready = true;
    Logger::info("Système complet prêt (obstacles + eau + vibration)");
}

// =======================================================
// UPDATE (✅ AVEC THROTTLE)
// =======================================================
void ObstacleDetector::update() {
    if (!ready) return;

    unsigned long currentTime = millis();
    
    // ✅ THROTTLE : Ne vérifier que toutes les OBSTACLE_CHECK_INTERVAL ms
    if (currentTime - lastObstacleCheckTime < OBSTACLE_CHECK_INTERVAL) {
        return;
    }
    
    lastObstacleCheckTime = currentTime;

    // Vérifier obstacles
    verifierObstacleHaut();
    delay(80);  // ✅ Augmenté de 60 à 80ms
    balayerNiveauBas();
    delay(80);  // ✅ Augmenté de 60 à 80ms
    
    // Vérifier eau
    if (WATER_SENSOR_ENABLED) {
        verifierEau();
    }
}

// =======================================================
// STOP
// =======================================================
void ObstacleDetector::stop() {
    Logger::info("Arrêt détection obstacles + eau");
    buzzer1Off();
    buzzer2Off();
    stopVibration();
    servoMoteur.detach();
    ready = false;
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
// ✅ GET OBSTACLE DATA FOR BLE
// =======================================================
ObstacleData ObstacleDetector::getObstacleData() const {
    ObstacleData data;
    data.upper = lastDistanceHaut;
    data.lower = lastDistanceBas;
    data.servoAngle = angleActuel;
    return data;
}

// =======================================================
// ✅ GET WATER SENSOR DATA FOR BLE
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

    if (distance <= 0) return;

    if (distPrecedenteHaut != -1 &&
        abs(distance - distPrecedenteHaut) > OBSTACLE_SEUIL_VARIATION) return;

    distPrecedenteHaut = distance;
    lastDistanceHaut = distance;

    if (distance < OBSTACLE_DIST_SECURITE_HAUT) {
        Logger::info("Obstacle HAUT à " + String(distance) + " cm");

        lastObstacle.distance = distance;
        lastObstacle.angle = 0;
        lastObstacle.isHigh = true;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeHaut > OBSTACLE_ALERT_COOLDOWN) {
            alerterObstacle(distance, OBSTACLE_FREQ_HAUT);
            
            if (OBSTACLE_VIBRATION_ENABLED) {
                vibrerPattern(2);
            }
            
            lastAlertTimeHaut = now;
        }
    }
}

// =======================================================
// BALAYER NIVEAU BAS
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

    servoMoteur.write(angleActuel);
    delay(OBSTACLE_SERVO_DELAY);

    int distance = mesureDistanceFiltre(OBSTACLE_TRIG_LOW, OBSTACLE_ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    if (distance <= 0) return;

    if (distPrecedenteBas != -1 &&
        abs(distance - distPrecedenteBas) > OBSTACLE_SEUIL_VARIATION) return;

    distPrecedenteBas = distance;
    lastDistanceBas = distance;

    if (distance < OBSTACLE_DIST_SECURITE_BAS) {
        String dir = (angleActuel < 60) ? "GAUCHE" :
                     (angleActuel > 120) ? "DROITE" : "CENTRE";
        
        Logger::info("Obstacle BAS à " + String(distance) + " cm (" + dir + ")");

        lastObstacle.distance = distance;
        lastObstacle.angle = angleActuel;
        lastObstacle.isHigh = false;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeBas > OBSTACLE_ALERT_COOLDOWN) {
            int freq = (angleActuel < 60)  ? OBSTACLE_FREQ_BAS_GAUCHE :
                       (angleActuel > 120) ? OBSTACLE_FREQ_BAS_DROITE : 
                                             OBSTACLE_FREQ_BAS_CENTRE;

            alerterObstacle(distance, freq);
            
            if (OBSTACLE_VIBRATION_ENABLED) {
                if (angleActuel < 60) {
                    vibrerLong();
                } else if (angleActuel > 120) {
                    vibrerPattern(3);
                } else {
                    vibrerCourt();
                }
            }
            
            lastAlertTimeBas = now;
        }
    }
}

// =======================================================
// ✅ VÉRIFIER EAU
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
            alerterEau(niveau);
            lastWaterAlertTime = currentTime;
        }
    }
}

// =======================================================
// ✅ LIRE NIVEAU EAU
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
// ✅ ALERTER EAU (BUZZER 2)
// =======================================================
void ObstacleDetector::alerterEau(int niveau) {
    if (niveau > WATER_THRESHOLD_HIGH) {
        Logger::warn("EAU DÉTECTÉE - Niveau ÉLEVÉ: " + String(niveau));
        
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
        Logger::info("Eau détectée - Niveau moyen: " + String(niveau));
        
        buzzer2Tone(WATER_FREQ_ALERT);
        delay(300);
        buzzer2Off();
        
        if (OBSTACLE_VIBRATION_ENABLED) {
            vibrerCourt();
        }
    }
}

// =======================================================
// MESURE DISTANCE (✅ TIMEOUT AUGMENTÉ)
// =======================================================
int ObstacleDetector::mesureDistance(int trigPin, int echoPin) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    // ✅ Timeout augmenté à 50ms (au lieu de 30ms)
    long duration = pulseIn(echoPin, HIGH, 50000);
    if (duration == 0) return -1;

    int distance = duration * 0.034 / 2;

    if (distance < 2 || distance > 400) return -1;

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

    return sorted[OBSTACLE_BUFFER_SIZE / 2];
}

// =======================================================
// ALERTER OBSTACLE (BUZZER 1)
// =======================================================
void ObstacleDetector::alerterObstacle(int distance, int frequence) {
    distance = constrain(distance, 2, 150);
    int duree = map(distance, 2, 150, 300, 50);

    buzzer1Tone(frequence);
    delay(duree);
    buzzer1Off();
    delay(50);
}

// =======================================================
// ✅ BUZZER 1 - ON
// =======================================================
void ObstacleDetector::buzzer1Tone(int frequence) {
    ledcWriteTone(BUZZER_1_PIN, frequence);
}

// =======================================================
// ✅ BUZZER 1 - OFF
// =======================================================
void ObstacleDetector::buzzer1Off() {
    ledcWrite(BUZZER_1_PIN, 0);
}

// =======================================================
// ✅ BUZZER 2 - ON
// =======================================================
void ObstacleDetector::buzzer2Tone(int frequence) {
    ledcWriteTone(BUZZER_2_PIN, frequence);
}

// =======================================================
// ✅ BUZZER 2 - OFF
// =======================================================
void ObstacleDetector::buzzer2Off() {
    ledcWrite(BUZZER_2_PIN, 0);
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
