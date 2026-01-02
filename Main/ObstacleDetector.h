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

// Énumération pour les niveaux d'eau
enum WaterLevel {
    WATER_NONE = 0,      // Sec
    WATER_HUMID = 1,     // Humide
    WATER_FLOOD = 2      // Inondation
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
    // 🎵 MÉLODIE SOS (NOUVELLE)
        void melodieSOS();                             // Sirène

  private:
    Servo servoMoteur;
    int angleActuel;
    bool directionDroite;
    bool ready;

    ObstacleInfo lastObstacle;
    
    // Variables pour Bluetooth
    int lastDistanceHaut;
    int lastDistanceBas;

    // Buffers filtrage
    int bufferHaut[5];
    int bufferBas[5];
    int indexBufferHaut;
    int indexBufferBas;

    int distPrecedenteHaut;
    int distPrecedenteBas;

    unsigned long lastAlertTimeHaut;
    unsigned long lastAlertTimeBas;
    
    // ===== CAPTEUR D'EAU =====
    int lastWaterValue;              // Dernière valeur lue (0-4095)
    WaterLevel lastWaterLevel;       // Dernier niveau détecté
    unsigned long lastWaterCheck;    // Dernier check eau
    unsigned long lastWaterAlert;    // Dernière alerte eau
    bool waterAlertActive;           // Alerte eau en cours

    // ===== MÉTHODES PRIVÉES =====
    
    // Détection obstacles (existantes)
    void verifierObstacleHaut();
    void balayerNiveauBas();
    int mesureDistance(int trigPin, int echoPin);
    int mesureDistanceFiltre(int trigPin, int echoPin, int* buffer, int* index);
    
    // Détection eau (NOUVELLES)
    void verifierCapteurEau();
    WaterLevel determinerNiveauEau(int valeurBrute);
    
    // Alertes sonores génériques (existante mais modifiée)
    void alerter(int distance, int frequence);
    
    // Mélodies différenciées (NOUVELLES)
    void melodieObstacleProgressif(int distance);  // Bips progressifs
    void melodieTrouEscalier();                    // 3 bips rapides + vibration
    void melodieEauDetectee();                     // Mélodie descendante

    
    // Contrôle buzzers (NOUVELLES)
    void jouerToneDual(int frequence);             // Joue sur les 2 buzzers
    void stopToneDual();                           // Arrête les 2 buzzers
    
    // Vibration (existantes)
    void vibrerCourt();
    void vibrerLong();
    void vibrerPattern(int count);
    void vibrerContinue(unsigned long duree);      // NOUVELLE
    void stopVibration();
};

#endif