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
      lastDistanceBas(-1) {
    
    for (int i = 0; i < OBSTACLE_BUFFER_SIZE; i++) {
        bufferHaut[i] = 999;
        bufferBas[i] = 999;
    }
}

// =======================================================
// INIT
// =======================================================
void ObstacleDetector::init() {
    Logger::info("Initialisation détection obstacles");

    // Configuration des capteurs ultrasons
    pinMode(OBSTACLE_TRIG_HIGH, OUTPUT);
    pinMode(OBSTACLE_ECHO_HIGH, INPUT);
    pinMode(OBSTACLE_TRIG_LOW, OUTPUT);
    pinMode(OBSTACLE_ECHO_LOW, INPUT);

    // Configuration du servo
    servoMoteur.setPeriodHertz(50);
    servoMoteur.attach(OBSTACLE_SERVO_PIN, 500, 2400);
    servoMoteur.write(90);

    // Configuration du buzzer (PWM ESP32 v3.x)
    ledcAttach(OBSTACLE_BUZZER_PIN, 2000, OBSTACLE_BUZZER_RES);
    ledcWrite(OBSTACLE_BUZZER_PIN, 0);

    // Configuration du moteur vibrant
    pinMode(OBSTACLE_VIBRATOR_PIN, OUTPUT);
    digitalWrite(OBSTACLE_VIBRATOR_PIN, LOW);
    Logger::info("Moteur vibrant configuré sur GPIO " + String(OBSTACLE_VIBRATOR_PIN));

    // Bip + Vibration de démarrage (3 fois)
    for (int i = 0; i < 3; i++) {
        ledcWriteTone(OBSTACLE_BUZZER_PIN, OBSTACLE_FREQ_DEMARRAGE);
        vibrerCourt();
        ledcWrite(OBSTACLE_BUZZER_PIN, 0);
        delay(200);
    }

    ready = true;
    Logger::info("Détection obstacles prête (avec retour haptique)");
}

// =======================================================
// UPDATE
// =======================================================
void ObstacleDetector::update() {
    if (!ready) return;

    verifierObstacleHaut();
    delay(60);
    balayerNiveauBas();
    delay(60);
}

// =======================================================
// STOP
// =======================================================
void ObstacleDetector::stop() {
    Logger::info("Arrêt détection obstacles");
    ledcWrite(OBSTACLE_BUZZER_PIN, 0);
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
// GET WATER DETECTION DATA FOR BLE
// =======================================================
WaterSensorData ObstacleDetector::getWaterSensorData() const {
    WaterSensorData data;
    // Pour le moment, retourne des données fictives
    // À implémenter quand le capteur d'eau sera ajouté
    data.humidityLevel = 0.0;
    data.rawData = 0;
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
            alerter(distance, OBSTACLE_FREQ_HAUT);
            
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
            int freq = (angleActuel < 60)  ? OBSTACLE_FREQ_BAS_GAUCHE :
                       (angleActuel > 120) ? OBSTACLE_FREQ_BAS_DROITE : 
                                             OBSTACLE_FREQ_BAS_CENTRE;

            alerter(distance, freq);
            
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
// ALERTER (SON)
// =======================================================
void ObstacleDetector::alerter(int distance, int frequence) {
    distance = constrain(distance, 2, 150);
    int duree = map(distance, 2, 150, 300, 50);

    ledcWriteTone(OBSTACLE_BUZZER_PIN, frequence);
    delay(duree);
    ledcWrite(OBSTACLE_BUZZER_PIN, 0);
    delay(50);
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