#include <Arduino.h>
#include <HardwareSerial.h>

#include "Config.h"
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"
#include "ObstacleDetector.h"

// Création d'un port série matériel (UART2) pour communiquer avec le SIM808
HardwareSerial SIM808(2);

// Initialisation des objets
GPSTracker gps(SIM808);      // Objet qui gère le GPS
GSMEmergency gsm(SIM808, gps); // Objet qui gère les urgences GSM
ObstacleDetector detector; // Objet qui gère détection des obstacles

// Tableau de pointeurs vers tous les modules à initialiser et mettre à jour
IModule* modules[] = { &gps, &gsm, &detector };

void setup() {
    // Initialisation de la communication série pour le debug (USB)
    Serial.begin(DEBUG_BAUDRATE);
    
    // Initialisation de la communication série avec le module SIM808
    // SERIAL_8N1 = 8 bits de données, pas de parité, 1 bit d'arrêt
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);

    Logger::info("=== CANNE INTELLIGENTE - DEMARRAGE ===");

    pinMode(BOUTON_SOS, INPUT_PULLUP);

    // Initialisation de tous les modules
    for (IModule* m : modules) {
        m->init();
    }

    // Configuration du Bluetooth (AJOUT)
    gps.configureBluetooth("GPS_TRACKER", "1234");

    // L'envoi automatique est activé par défaut
    // Pour le désactiver: gps.enableBluetoothSending(false);
    
    Logger::info("=== SYSTEME OPERATIONNEL ===");
}

void loop() {
    // Mise à jour de tous les modules à chaque itération
    for (IModule* m : modules) {
        m->update();
    }

    // Vérification si le bouton SOS est pressé (LOW = bouton enfoncé)
    if (digitalRead(BOUTON_SOS) == LOW) {
        gsm.sendSOS(); // Envoi d'un message SOS
        delay(1000); // Attente d'1 seconde pour éviter les envois multiples
    }
}
