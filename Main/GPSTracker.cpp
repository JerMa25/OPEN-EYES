// ============================================
// GPSTracker.cpp - Implémentation GPS complète
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
    
    Logger::info("GPS initialisé");
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

// Met à jour les données GPS
void GPSTracker::update() {
    // Lit et parse les données GPS
    readGPS();
}

// Lit et parse les données GPS complètes du module SIM808
bool GPSTracker::readGPS() {
    // Demande les informations GPS complètes (mode 32 = toutes les données)
    sendAT("AT+CGPSINF=32");
    String response = readResponse();

    // Vérifie si la réponse contient des données GPS
    if (response.indexOf("+CGPSINF:") >= 0) {
        parseGPSInfo(response);
        return gpsData.isValid;
    }
    
    // Si pas de données valides, marque comme invalide
    gpsData.isValid = false;
    gpsData.fixType = "No Fix";
    return false;
}

// Parse la réponse GPS complète
void GPSTracker::parseGPSInfo(const String& response) {
    // Format de la réponse CGPSINF:
    // +CGPSINF: mode,longitude,latitude,altitude,utc_time,ttff,satellites,speed,course
    
    int startIdx = response.indexOf("+CGPSINF:") + 10;
    String data = response.substring(startIdx);
    
    // Tableau pour stocker les valeurs parsées
    String values[9];
    int valueIndex = 0;
    int lastComma = -1;
    
    // Parse chaque valeur séparée par des virgules
    for (int i = 0; i < data.length() && valueIndex < 9; i++) {
        if (data[i] == ',' || data[i] == '\r' || data[i] == '\n') {
            values[valueIndex++] = data.substring(lastComma + 1, i);
            lastComma = i;
        }
    }
    
    // Extraction des données
    int mode = values[0].toInt();
    gpsData.longitude = values[1].toFloat();
    gpsData.latitude = values[2].toFloat();
    gpsData.altitude = values[3].toFloat();
    gpsData.gpsTimestamp = values[4];  // Format: yyyyMMddHHmmss.sss
    // values[5] = TTFF (Time To First Fix) - pas utilisé
    gpsData.satellitesCount = values[6].toInt();
    gpsData.speed = values[7].toFloat();      // en km/h
    gpsData.heading = values[8].toFloat();    // course/direction en degrés
    
    // Détermine le type de fix selon le mode
    if (mode == 0) {
        gpsData.fixType = "No Fix";
        gpsData.isValid = false;
    } else if (mode == 1) {
        gpsData.fixType = "2D Fix";
        gpsData.isValid = (gpsData.latitude != 0 && gpsData.longitude != 0);
    } else if (mode >= 2) {
        gpsData.fixType = "3D Fix";
        gpsData.isValid = (gpsData.latitude != 0 && gpsData.longitude != 0);
    }
    
    // Calcul approximatif du HDOP (Horizontal Dilution of Precision)
    // Plus le nombre de satellites est élevé, meilleur est le HDOP
    if (gpsData.satellitesCount >= 8) {
        gpsData.hdop = 1.0;  // Excellent
    } else if (gpsData.satellitesCount >= 6) {
        gpsData.hdop = 2.0;  // Bon
    } else if (gpsData.satellitesCount >= 4) {
        gpsData.hdop = 5.0;  // Moyen
    } else {
        gpsData.hdop = 99.9; // Mauvais
    }
    
    // Log des données pour debug
    if (gpsData.isValid) {
        Logger::info("GPS: Lat=" + String(gpsData.latitude, 6) + 
                     " Lon=" + String(gpsData.longitude, 6) + 
                     " Sats=" + String(gpsData.satellitesCount) +
                     " Fix=" + gpsData.fixType);
    }
}

// Retourne toutes les données GPS
GPSData GPSTracker::getGPSData() const {
    return gpsData;
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
