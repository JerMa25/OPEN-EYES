// ObstacleDetector.cpp
#include "ObstacleDetector.h"
#include "Logger.h"
#include "Config.h"

// =======================================================
// PINS
// =======================================================
const int TRIG_HIGH = 16;
const int ECHO_HIGH = 17;
const int TRIG_LOW  = 4;
const int ECHO_LOW  = 5;
const int SERVO_PIN  = 18;
const int BUZZER_PIN = 27;

// =======================================================
// PARAMÈTRES
// =======================================================
const int BUZZER_CHANNEL = 0;
const int BUZZER_RES = 8;

const int DIST_SECURITE_HAUT = 150;
const int DIST_SECURITE_BAS  = 100;

const int ANGLE_MIN = 0;
const int ANGLE_MAX = 180;
const int ANGLE_STEP = 15;
const int SERVO_DELAY = 120;

const int BUFFER_SIZE = 5;
const int SEUIL_VARIATION = 40;
const unsigned long ALERT_COOLDOWN = 800;

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
      lastAlertTimeBas(0) {
    
    // Initialiser les buffers
    for (int i = 0; i < 5; i++) {
        bufferHaut[i] = 999;
        bufferBas[i] = 999;
    }
}

// =======================================================
// INIT (APPELÉE DANS SETUP)
// =======================================================
void ObstacleDetector::init() {
    Logger::info("Initialisation détection obstacles");

    // Configuration des capteurs ultrasons
    pinMode(TRIG_HIGH, OUTPUT);
    pinMode(ECHO_HIGH, INPUT);
    pinMode(TRIG_LOW, OUTPUT);
    pinMode(ECHO_LOW, INPUT);

    // Configuration du servo
    servoMoteur.setPeriodHertz(50);
    servoMoteur.attach(SERVO_PIN, 500, 2400);
    servoMoteur.write(90);

    // Configuration du buzzer (PWM ESP32 v3.x)
    ledcAttach(BUZZER_PIN, 2000, BUZZER_RES);
    ledcWrite(BUZZER_PIN, 0);  // Buzzer OFF

    // Bip de démarrage (3 bips)
    for (int i = 0; i < 3; i++) {
        ledcWriteTone(BUZZER_PIN, 1500);
        delay(100);
        ledcWrite(BUZZER_PIN, 0);
        delay(200);
    }

    ready = true;
    Logger::info("Détection obstacles prête");
}

// =======================================================
// UPDATE (APPELÉE DANS LOOP)
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
    ledcWrite(BUZZER_PIN, 0);
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
            lastObstacle.distance < DIST_SECURITE_HAUT);
}

// =======================================================
// HAS OBSTACLE LOW
// =======================================================
bool ObstacleDetector::hasObstacleLow() const {
    return (!lastObstacle.isHigh && 
            lastObstacle.distance > 0 && 
            lastObstacle.distance < DIST_SECURITE_BAS);
}

// =======================================================
// VÉRIFIER OBSTACLE HAUT
// =======================================================
void ObstacleDetector::verifierObstacleHaut() {
    int distance = mesureDistanceFiltre(TRIG_HIGH, ECHO_HIGH,
                                        bufferHaut, &indexBufferHaut);

    if (distance <= 0) return;

    if (distPrecedenteHaut != -1 &&
        abs(distance - distPrecedenteHaut) > SEUIL_VARIATION) return;

    distPrecedenteHaut = distance;

    if (distance < DIST_SECURITE_HAUT) {
        Logger::info("Obstacle HAUT à " + String(distance) + " cm");

        // Enregistrer dernière détection
        lastObstacle.distance = distance;
        lastObstacle.angle = 0;
        lastObstacle.isHigh = true;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeHaut > ALERT_COOLDOWN) {
            alerter(distance, 2000);
            lastAlertTimeHaut = now;
        }
    }
}

// =======================================================
// BALAYER NIVEAU BAS
// =======================================================
void ObstacleDetector::balayerNiveauBas() {
    angleActuel += directionDroite ? ANGLE_STEP : -ANGLE_STEP;

    if (angleActuel >= ANGLE_MAX) {
        angleActuel = ANGLE_MAX;
        directionDroite = false;
    }
    if (angleActuel <= ANGLE_MIN) {
        angleActuel = ANGLE_MIN;
        directionDroite = true;
    }

    servoMoteur.write(angleActuel);
    delay(SERVO_DELAY);

    int distance = mesureDistanceFiltre(TRIG_LOW, ECHO_LOW,
                                        bufferBas, &indexBufferBas);

    if (distance <= 0) return;

    if (distPrecedenteBas != -1 &&
        abs(distance - distPrecedenteBas) > SEUIL_VARIATION) return;

    distPrecedenteBas = distance;

    if (distance < DIST_SECURITE_BAS) {
        String dir = (angleActuel < 60) ? "GAUCHE" :
                     (angleActuel > 120) ? "DROITE" : "CENTRE";
        
        Logger::info("Obstacle BAS à " + String(distance) + " cm (" + dir + ")");

        // Enregistrer dernière détection
        lastObstacle.distance = distance;
        lastObstacle.angle = angleActuel;
        lastObstacle.isHigh = false;
        lastObstacle.timestamp = millis();

        unsigned long now = millis();
        if (now - lastAlertTimeBas > ALERT_COOLDOWN) {
            int freq = (angleActuel < 60)  ? 1000 :
                       (angleActuel > 120) ? 1500 : 1200;

            alerter(distance, freq);
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
    *index = (*index + 1) % BUFFER_SIZE;

    int sorted[BUFFER_SIZE];
    memcpy(sorted, buffer, sizeof(sorted));

    for (int i = 0; i < BUFFER_SIZE - 1; i++)
        for (int j = 0; j < BUFFER_SIZE - i - 1; j++)
            if (sorted[j] > sorted[j + 1])
                std::swap(sorted[j], sorted[j + 1]);

    return sorted[BUFFER_SIZE / 2];
}

// =======================================================
// ALERTER
// =======================================================
void ObstacleDetector::alerter(int distance, int frequence) {
    distance = constrain(distance, 2, 150);
    int duree = map(distance, 2, 150, 300, 50);

    ledcWriteTone(BUZZER_PIN, frequence);
    delay(duree);
    ledcWrite(BUZZER_PIN, 0);
    delay(50);
}