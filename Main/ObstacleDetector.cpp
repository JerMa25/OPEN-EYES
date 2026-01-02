// ObstacleDetector.cpp
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
      lastWaterValue(0),
      lastWaterLevel(WATER_NONE),
      lastWaterCheck(0),
      lastWaterAlert(0),
      waterAlertActive(false) {
    
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

    // Configuration du capteur d'eau (ADC)
    pinMode(WATER_SENSOR_PIN, INPUT);
    Logger::info("Capteur eau configuré sur GPIO " + String(WATER_SENSOR_PIN));

    // Configuration du servo
    servoMoteur.setPeriodHertz(50);
    servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    servoMoteur.write(90);

    // Configuration des 2 buzzers (PWM ESP32 v3.x)
    ledcAttach(OBSTACLE_BUZZER_PIN_1, 2000, OBSTACLE_BUZZER_RES);
    ledcAttach(OBSTACLE_BUZZER_PIN_2, 2000, OBSTACLE_BUZZER_RES);
    ledcWrite(OBSTACLE_BUZZER_PIN_1, 0);
    ledcWrite(OBSTACLE_BUZZER_PIN_2, 0);
    Logger::info("2 Buzzers synchronisés sur GPIO4 + GPIO26");

    // Configuration du moteur vibrant
    pinMode(OBSTACLE_VIBRATOR_PIN, OUTPUT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
    Logger::info("Moteur vibrant configuré sur GPIO " + String(OBSTACLE_VIBRATOR_PIN));

    // Bip + Vibration de démarrage (3 fois)
    for (int i = 0; i < 3; i++) {
        jouerToneDual(OBSTACLE_FREQ_DEMARRAGE);
        vibrerCourt();
        delay(150);
        stopToneDual();
        delay(200);
    }

    ready = true;
    Logger::info("Détection complète prête (Obstacles + Eau)");
}

// =======================================================
// UPDATE
// =======================================================
void ObstacleDetector::update() {
    if (!ready) return;

    // Vérification obstacle haut
    verifierObstacleHaut();
    delay(40);
    
    // Balayage sol
    balayerNiveauBas();
    delay(40);
    
    // Vérification eau (toutes les 500ms)
    if (millis() - lastWaterCheck >= 500) {
        verifierCapteurEau();
        lastWaterCheck = millis();
    }
}

// =======================================================
// STOP
// =======================================================
void ObstacleDetector::stop() {
    Logger::info("Arrêt détection obstacles + eau");
    stopToneDual();
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
// GET WATER SENSOR DATA FOR BLE (MAINTENANT RÉEL !)
// =======================================================
WaterSensorData ObstacleDetector::getWaterSensorData() const {
    WaterSensorData data;
    
    // Conversion valeur ADC (0-4095) en pourcentage
    // Plus la valeur est haute, plus il y a d'eau
    data.humidityLevel = map(lastWaterValue, 0, 4095, 0, 100);
    data.rawData = lastWaterValue;
    
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
            // 🎵 MÉLODIE OBSTACLE PROGRESSIF
            melodieObstacleProgressif(distance);
            
            // Vibration HAUT : 2 vibrations courtes
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
            // 🎵 MÉLODIE TROU/ESCALIER (3 bips rapides)
            melodieTrouEscalier();
            
            // Vibration BAS : Pattern selon direction
            if (OBSTACLE_VIBRATION_ENABLED) {
                if (angleActuel < 60) {
                    vibrerLong();  // GAUCHE : 1 longue
                } else if (angleActuel > 120) {
                    vibrerPattern(3);  // DROITE : 3 courtes
                } else {
                    vibrerCourt();  // CENTRE : 1 courte
                }
            }
            
            lastAlertTimeBas = now;
        }
    }
}

// =======================================================
// VÉRIFIER CAPTEUR EAU (NOUVELLE MÉTHODE)
// =======================================================
void ObstacleDetector::verifierCapteurEau() {
    // Lecture ADC (0-4095 sur ESP32)
    lastWaterValue = analogRead(WATER_SENSOR_PIN);
    
    // Déterminer le niveau d'eau
    WaterLevel niveau = determinerNiveauEau(lastWaterValue);
    
    // Si changement de niveau
    if (niveau != lastWaterLevel) {
        lastWaterLevel = niveau;
        
        switch(niveau) {
            case WATER_NONE:
                Logger::info("Capteur eau : SEC (valeur=" + String(lastWaterValue) + ")");
                waterAlertActive = false;
                stopToneDual();
                stopVibration();
                break;
                
            case WATER_HUMID:
                Logger::warn("Capteur eau : HUMIDE détectée ! (valeur=" + String(lastWaterValue) + ")");
                if (millis() - lastWaterAlert > 3000) {  // Max 1 alerte / 3 secondes
                    // 🎵 MÉLODIE EAU
                    melodieEauDetectee();
                    
                    // Vibration courte
                    if (OBSTACLE_VIBRATION_ENABLED) {
                        vibrerPattern(2);
                    }
                    
                    lastWaterAlert = millis();
                }
                break;
                
            case WATER_FLOOD:
                Logger::error("Capteur eau : INONDATION ! (valeur=" + String(lastWaterValue) + ")");
                if (!waterAlertActive) {
                    waterAlertActive = true;
                    
                    // 🎵 MÉLODIE EAU en boucle
                    for (int i = 0; i < 3; i++) {
                        melodieEauDetectee();
                        delay(200);
                    }
                    
                    // Vibration continue 1 seconde
                    if (OBSTACLE_VIBRATION_ENABLED) {
                        vibrerContinue(1000);
                    }
                    
                    lastWaterAlert = millis();
                }
                break;
        }
    }
    
    // Si eau détectée (humide ou inondation), rappel périodique
    if (niveau != WATER_NONE && millis() - lastWaterAlert > 5000) {
        melodieEauDetectee();
        lastWaterAlert = millis();
    }
}

// =======================================================
// DÉTERMINER NIVEAU EAU (NOUVELLE MÉTHODE)
// =======================================================
WaterLevel ObstacleDetector::determinerNiveauEau(int valeurBrute) {
    if (valeurBrute < WATER_SEUIL_SEC) {
        return WATER_NONE;  // Sec
    } else if (valeurBrute < WATER_SEUIL_HUMIDE) {
        return WATER_HUMID;  // Humide
    } else {
        return WATER_FLOOD;  // Inondation
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

    long duration = pulseIn(echoPin, HIGH, 30000);
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
// ALERTER GÉNÉRIQUE (ANCIENNE MÉTHODE - CONSERVÉE)
// =======================================================
void ObstacleDetector::alerter(int distance, int frequence) {
    distance = constrain(distance, 2, 150);
    int duree = map(distance, 2, 150, 300, 50);

    jouerToneDual(frequence);
    delay(duree);
    stopToneDual();
    delay(50);
}

// =======================================================
// 🎵 MÉLODIE OBSTACLE PROGRESSIF (NOUVELLE)
// =======================================================
void ObstacleDetector::melodieObstacleProgressif(int distance) {
    // Plus l'obstacle est proche, plus le son est aigu et rapide
    
    // Calcul fréquence : 500 Hz (loin) -> 4000 Hz (proche)
    int frequence = map(distance, 2, 150, 
                       MELODIE_OBSTACLE_FREQ_MAX, 
                       MELODIE_OBSTACLE_FREQ_MIN);
    
    // Calcul durée bip : Long (loin) -> Court (proche)
    int dureeBip = map(distance, 2, 150, 50, 300);
    
    // Calcul pause : Courte (proche) -> Longue (loin)
    int dureePause = map(distance, 2, 150, 50, 500);
    
    // Jouer le bip
    jouerToneDual(frequence);
    delay(dureeBip);
    stopToneDual();
    delay(dureePause);
}

// =======================================================
// 🎵 MÉLODIE TROU/ESCALIER (NOUVELLE)
// =======================================================
void ObstacleDetector::melodieTrouEscalier() {
    // 3 bips rapides aigus + vibration
    
    for (int i = 0; i < MELODIE_TROU_BIPS; i++) {
        jouerToneDual(MELODIE_TROU_FREQ);
        delay(MELODIE_TROU_DUREE);
        stopToneDual();
        
        if (i < MELODIE_TROU_BIPS - 1) {
            delay(MELODIE_TROU_PAUSE);
        }
    }
    
    // Vibration 500ms
    if (OBSTACLE_VIBRATION_ENABLED) {
        digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
        delay(500);
        digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
    }
}

// =======================================================
// 🎵 MÉLODIE EAU DÉTECTÉE (NOUVELLE)
// =======================================================
void ObstacleDetector::melodieEauDetectee() {
    // Mélodie descendante "goutte d'eau" : 1500 -> 1000 -> 800 Hz
    
    // Note 1 (aiguë)
    jouerToneDual(MELODIE_EAU_FREQ_1);
    delay(MELODIE_EAU_DUREE_NOTE);
    stopToneDual();
    delay(MELODIE_EAU_PAUSE);
    
    // Note 2 (moyenne)
    jouerToneDual(MELODIE_EAU_FREQ_2);
    delay(MELODIE_EAU_DUREE_NOTE);
    stopToneDual();
    delay(MELODIE_EAU_PAUSE);
    
    // Note 3 (grave)
    jouerToneDual(MELODIE_EAU_FREQ_3);
    delay(MELODIE_EAU_DUREE_NOTE);
    stopToneDual();
}

// =======================================================
// 🎵 MÉLODIE SOS (NOUVELLE)
// =======================================================
void ObstacleDetector::melodieSOS() {
    // Sirène alternée : 800 <-> 1500 Hz (3 cycles)
    
    for (int i = 0; i < MELODIE_SOS_CYCLES; i++) {
        // Montée
        jouerToneDual(MELODIE_SOS_FREQ_BAS);
        delay(MELODIE_SOS_DUREE);
        
        // Descente
        jouerToneDual(MELODIE_SOS_FREQ_HAUT);
        delay(MELODIE_SOS_DUREE);
    }
    
    stopToneDual();
}

// =======================================================
// JOUER TONE DUAL (NOUVELLE - 2 BUZZERS)
// =======================================================
void ObstacleDetector::jouerToneDual(int frequence) {
    ledcWriteTone(OBSTACLE_BUZZER_PIN_1, frequence);
    ledcWriteTone(OBSTACLE_BUZZER_PIN_2, frequence);
}

// =======================================================
// STOP TONE DUAL (NOUVELLE)
// =======================================================
void ObstacleDetector::stopToneDual() {
    ledcWrite(OBSTACLE_BUZZER_PIN_1, 0);
    ledcWrite(OBSTACLE_BUZZER_PIN_2, 0);
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
// VIBRATION CONTINUE (NOUVELLE)
// =======================================================
void ObstacleDetector::vibrerContinue(unsigned long duree) {
    digitalWrite(OBSTACLE_VIBRATOR_PIN, HIGH);
    delay(duree);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}

// =======================================================
// ARRÊTER VIBRATION
// =======================================================
void ObstacleDetector::stopVibration() {
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
}