#include <Arduino.h>
#include <HardwareSerial.h>

#include "Config.h"
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"
#include "ObstacleDetector.h"

HardwareSerial SIM808(2);

GPSTracker gps(SIM808);
GSMEmergency gsm(SIM808, gps);
ObstacleDetector detector;

IModule* modules[] = { &gps, &gsm, &detector };

void setup() {
    Serial.begin(DEBUG_BAUDRATE);
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);

    Logger::info("=== CANNE INTELLIGENTE - DEMARRAGE ===");

    pinMode(BOUTON_SOS, INPUT_PULLUP);

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
    for (IModule* m : modules) {
        m->update();
    }

    if (digitalRead(BOUTON_SOS) == LOW) {
        gsm.sendSOS();
        delay(1000);
    }
}
