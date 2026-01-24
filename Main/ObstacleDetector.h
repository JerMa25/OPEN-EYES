// ObstacleDetector.h - VERSION OPTIMISÉE SANS BLOCAGES
#ifndef OBSTACLE_DETECTOR_H
#define OBSTACLE_DETECTOR_H

#include <Arduino.h>
#include <ESP32Servo.h>
#include "IModule.h"
#include "BluetoothManager.h"

// Structure pour stocker une détection d'obstacle
struct ObstacleInfo {
    int distance = -1;
    int angle = 0;
    bool isHigh = false;
    unsigned long timestamp = 0;
};

// ===== États du buzzer =====
enum BuzzerState {
    BUZZER_OFF,
    BUZZER_BIP_ON,
    BUZZER_BIP_WAIT,
    BUZZER_DOUBLE_BIP_FIRST,
    BUZZER_DOUBLE_BIP_GAP_STATE,
    BUZZER_DOUBLE_BIP_SECOND,
    BUZZER_DOUBLE_BIP_WAIT,
    BUZZER_CONTINUOUS
};

// ✅ NOUVEAU : États pour alerte eau non-bloquante
enum WaterAlertState {
    WATER_ALERT_OFF,
    WATER_ALERT_BIP1_ON,
    WATER_ALERT_BIP1_OFF,
    WATER_ALERT_BIP2_ON
};

class ObstacleDetector : public IModule {
  public:
    ObstacleDetector();

    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    ObstacleInfo getLastObstacle() const;
    bool hasObstacleHigh() const;
    bool hasObstacleLow() const;
    
    // Méthodes pour Bluetooth
    ObstacleData getObstacleData() const;
    WaterSensorData getWaterSensorData() const;

  private:
    // Servo
    Servo servoMoteur;
    int angleActuel;
    bool directionDroite;
    bool ready;

    // Obstacles
    ObstacleInfo lastObstacle;
    int lastDistanceHaut;
    int lastDistanceBas;

    int bufferHaut[5];
    int bufferBas[5];
    int indexBufferHaut;
    int indexBufferBas;

    int distPrecedenteHaut;
    int distPrecedenteBas;

    unsigned long lastAlertTimeHaut;
    unsigned long lastAlertTimeBas;

    // Capteur d'eau
    int lastWaterLevel;
    int waterRawValue;
    unsigned long lastWaterCheckTime;
    unsigned long lastWaterAlertTime;
    
    unsigned long lastObstacleCheckTime;

    // ===== Gestion buzzers actifs =====
    BuzzerState buzzer1State;
    BuzzerState buzzer2State;
    unsigned long buzzer1LastChange;
    unsigned long buzzer2LastChange;
    int currentDistanceHaut;
    int currentDistanceBas;
    
    // ✅ CORRECTION : Timestamps pour timeout (augmenté à 1500ms)
    unsigned long lastMeasureTimeHaut;
    unsigned long lastMeasureTimeBas;
    
    // ✅ NOUVEAU : Timer pour servo non-bloquant
    unsigned long lastServoMoveTime;
    
    // ✅ NOUVEAU : Machine à états pour alerte eau
    WaterAlertState waterAlertState;
    unsigned long waterAlertLastChange;
    
    // Fonctions obstacles
    void verifierObstacleHaut();
    void balayerNiveauBas();
    int mesureDistance(int trigPin, int echoPin);
    int mesureDistanceFiltre(int trigPin, int echoPin, int* buffer, int* index);
    
    // ===== Gestion buzzers non-bloquants =====
    void updateBuzzer1();  // Gère BUZZER_1 (HAUT)
    void updateBuzzer2();  // Gère BUZZER_2 (BAS)
    void updateWaterAlert();  // ✅ NOUVEAU : Gère alerte eau non-bloquante
    int getIntervalForDistance(int distance);
    String getDistanceCategory(int distance);
    
    // Fonctions eau
    void verifierEau();
    int lireNiveauEau();
    void alerterEau(int niveau);
    
    // Fonctions vibration
    void vibrerCourt();
    void vibrerLong();
    void vibrerPattern(int count);
    void stopVibration();
    
    // ===== Buzzers actifs (digitalWrite) =====
    void buzzer1On();
    void buzzer1Off();
    void buzzer2On();
    void buzzer2Off();
};

#endif