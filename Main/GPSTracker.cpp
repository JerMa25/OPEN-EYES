#include "GPSTracker.h"
#include "Logger.h"
#include "Config.h"

GPSTracker::GPSTracker(HardwareSerial& serial) : sim808(serial) {}

void GPSTracker::init() {
    ready = true;
    Logger::info("Activation GPS");
    sendAT("AT+CGPSPWR=1");
    delay(1000);
    sendAT("AT+CGPSRST=1");
}

void GPSTracker::stop() {
    Logger::info("GPS arrêté");
    sim808.println("AT+CGPSPWR=0");
    ready = false;
}

bool GPSTracker::isReady() const {
    return ready;
}

void GPSTracker::update() {
    readGPS();
}

bool GPSTracker::readGPS() {
    sendAT("AT+CGPSINF=0");
    String rep = readResponse();

    if (rep.indexOf("+CGPSINF:") >= 0) {
        int idx1 = rep.indexOf(',');
        int idx2 = rep.indexOf(',', idx1 + 1);
        int idx3 = rep.indexOf(',', idx2 + 1);

        position.longitude = rep.substring(idx1 + 1, idx2).toFloat();
        position.latitude  = rep.substring(idx2 + 1, idx3).toFloat();

        position.isValid = (position.latitude != 0 && position.longitude != 0);
        return position.isValid;
    }
    return false;
}

GPSPosition GPSTracker::getPosition() const {
    return position;
}

void GPSTracker::sendAT(const String& cmd) {
    sim808.println(cmd);
}

String GPSTracker::readResponse() {
    String r;
    unsigned long t = millis();
    while (millis() - t < 2000) {
        while (sim808.available()) {
            r += sim808.readString();
        }
    }
    return r;
}
