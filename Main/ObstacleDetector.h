// ObstacleDetector.h
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
    
    // Méthode pour Bluetooth
    ObstacleData getObstacleData() const;
    WaterSensorData getWaterSensorData() const;

  private:
    Servo servoMoteur;
    int angleActuel;
    bool directionDroite;
    bool ready;

    ObstacleInfo lastObstacle;
    
    // Variables pour Bluetooth
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

    void verifierObstacleHaut();
    void balayerNiveauBas();
    int mesureDistance(int trigPin, int echoPin);
    int mesureDistanceFiltre(int trigPin, int echoPin, int* buffer, int* index);
    void alerter(int distance, int frequence);
    
    // Méthodes vibration
    void vibrerCourt();
    void vibrerLong();
    void vibrerPattern(int count);
    void stopVibration();
};

#endif