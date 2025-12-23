#include <Arduino.h>
#include <HardwareSerial.h>

#include "Config.h"
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"

HardwareSerial SIM808(2);

GPSTracker gps(SIM808);
GSMEmergency gsm(SIM808, gps);

IModule* modules[] = { &gps, &gsm };

void setup() {
    Serial.begin(DEBUG_BAUDRATE);
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);

    for (IModule* m : modules) {
        m->init();
    }
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
