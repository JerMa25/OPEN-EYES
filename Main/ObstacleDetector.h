// ObstacleDetector.h
#ifndef OBSTACLE_DETECTOR_H
#define OBSTACLE_DETECTOR_H

#include <Arduino.h>
#include <ESP32Servo.h>
#include "IModule.h"

// Structure pour stocker une détection d'obstacle
struct ObstacleInfo {
    int distance = -1;      // Distance en cm (-1 = pas d'obstacle)
    int angle = 0;          // Angle du servo (0-180°)
    bool isHigh = false;    // true = obstacle haut, false = obstacle bas
    unsigned long timestamp = 0;
};

class ObstacleDetector : public IModule {
  public:
    // Constructeur
    ObstacleDetector();

    // Méthodes de IModule
    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    // Méthodes spécifiques
    ObstacleInfo getLastObstacle() const;
    bool hasObstacleHigh() const;
    bool hasObstacleLow() const;

  private:
    // Servo
    Servo servoMoteur;
    int angleActuel;
    bool directionDroite;

    // État du module
    bool ready;

    // Dernière détection
    ObstacleInfo lastObstacle;

    // Buffers de filtrage
    int bufferHaut[5];
    int bufferBas[5];
    int indexBufferHaut;
    int indexBufferBas;

    // Distances précédentes
    int distPrecedenteHaut;
    int distPrecedenteBas;

    // Cooldown alertes
    unsigned long lastAlertTimeHaut;
    unsigned long lastAlertTimeBas;

    // Fonctions internes
    void verifierObstacleHaut();
    void balayerNiveauBas();
    int mesureDistance(int trigPin, int echoPin);
    int mesureDistanceFiltre(int trigPin, int echoPin, int* buffer, int* index);
    void alerter(int distance, int frequence);
};

#endif