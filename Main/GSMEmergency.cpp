#include "GSMEmergency.h"
#include "Logger.h"
#include "Config.h"

GSMEmergency::GSMEmergency(HardwareSerial& serial, GPSTracker& gpsRef)
    : sim808(serial), gps(gpsRef) {}

void GSMEmergency::init() {
    Logger::info("Initialisation GSM");
    sim808.println("AT+CMGF=1");
}

void GSMEmergency::stop() {
    ready = true;
    Logger::info("GSM arrêté");
    ready = false;
}

bool GSMEmergency::isReady() const {
    return ready;
}

void GSMEmergency::update() {
    // futur traitement SMS entrants
}

void GSMEmergency::sendSOS() {
    Logger::warn("ALERTE SOS");

    GPSPosition pos = gps.getPosition();
    String msg = "ALERTE SOS\n";

    if (pos.isValid) {
        msg += "https://maps.google.com/?q=";
        msg += String(pos.latitude, 6) + "," + String(pos.longitude, 6);
    } else {
        msg += "Position GPS indisponible";
    }

    sendSMS(NUMERO_URGENCE, msg);
}

bool GSMEmergency::sendSMS(const String& number, const String& message) {
    sim808.print("AT+CMGS=\"");
    sim808.print(number);
    sim808.println("\"");
    delay(500);
    sim808.print(message);
    sim808.write(26);
    delay(3000);
    return true;
}
