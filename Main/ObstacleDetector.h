// ObstacleDetector.h - ✅ VERSION CORRIGÉE
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
    
    // ✅ AJOUTÉ : Throttle pour éviter trop de vérifications
    unsigned long lastObstacleCheckTime;

    // Fonctions obstacles
    void verifierObstacleHaut();
    void balayerNiveauBas();
    int mesureDistance(int trigPin, int echoPin);
    int mesureDistanceFiltre(int trigPin, int echoPin, int* buffer, int* index);
    void alerterObstacle(int distance, int frequence);
    
    // Fonctions eau
    void verifierEau();
    int lireNiveauEau();
    void alerterEau(int niveau);
    
    // Fonctions vibration
    void vibrerCourt();
    void vibrerLong();
    void vibrerPattern(int count);
    void stopVibration();
    
    // Fonctions buzzers
    void buzzer1Tone(int frequence);
    void buzzer1Off();
    void buzzer2Tone(int frequence);
    void buzzer2Off();
};

#endif
