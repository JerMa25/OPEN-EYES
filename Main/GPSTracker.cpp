// ============================================
// GPSTracker.cpp - Implémentation GPS uniquement
// ============================================
#include "GPSTracker.h"
#include "Logger.h"
#include "Config.h"

// Constructeur : initialise la référence au port série
GPSTracker::GPSTracker(HardwareSerial& serial) : sim808(serial) {}

// Initialise le module GPS
void GPSTracker::init() {
    ready = true;
    Logger::info("Activation GPS");
    
    // Commande AT pour activer l'alimentation du GPS
    sendAT("AT+CGPSPWR=1");
    delay(1000);
    
    // Commande AT pour réinitialiser le GPS
    sendAT("AT+CGPSRST=1");
    delay(1000);
}

// Arrête le module GPS
void GPSTracker::stop() {
    Logger::info("GPS arrêté");
    
    // Désactive le GPS
    sendAT("AT+CGPSPWR=0");
    delay(500);
    
    ready = false;
}

// Vérifie si le GPS est prêt
bool GPSTracker::isReady() const {
    return ready;
}

// Met à jour la position GPS
void GPSTracker::update() {
    // Lit la position GPS
    readGPS();
}

// Lit et parse les données GPS du module SIM808
bool GPSTracker::readGPS() {
    // Demande les informations GPS au module (mode 0 = format court)
    sendAT("AT+CGPSINF=0");
    String rep = readResponse();

    // Vérifie si la réponse contient des données GPS
    if (rep.indexOf("+CGPSINF:") >= 0) {
        // Parse la chaîne de réponse pour extraire longitude et latitude
        // Format: +CGPSINF: mode,longitude,latitude,altitude,...
        int idx1 = rep.indexOf(',');           // Trouve la 1ère virgule
        int idx2 = rep.indexOf(',', idx1 + 1); // Trouve la 2ème virgule
        int idx3 = rep.indexOf(',', idx2 + 1); // Trouve la 3ème virgule

        // Extraction et conversion en float
        position.longitude = rep.substring(idx1 + 1, idx2).toFloat();
        position.latitude  = rep.substring(idx2 + 1, idx3).toFloat();

        // Vérifie que les coordonnées ne sont pas nulles (position valide)
        position.isValid = (position.latitude != 0 && position.longitude != 0);
        return position.isValid;
    }
    return false;
}

// Retourne la position GPS actuelle
GPSPosition GPSTracker::getPosition() const {
    return position;
}

// Envoie une commande AT au module SIM808
void GPSTracker::sendAT(const String& cmd) {
    sim808.println(cmd);
}

// Lit la réponse du module SIM808 (timeout 2 secondes)
String GPSTracker::readResponse() {
    String r;
    unsigned long t = millis();
    
    // Lit pendant 2 secondes maximum
    while (millis() - t < 2000) {
        while (sim808.available()) {
            r += sim808.readString();
        }
    }
    return r;
}
