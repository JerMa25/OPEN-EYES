// ============================================
// GPSTracker.cpp - Implémentation
// ============================================
#include "GPSTracker.h"
#include "Logger.h"
#include "Config.h"

// Constructeur : initialise la référence au port série
GPSTracker::GPSTracker(HardwareSerial& serial) : sim808(serial) {}

// Initialise le module GPS et le Bluetooth
void GPSTracker::init() {
    ready = true;
    Logger::info("Activation GPS");
    
    // Commande AT pour activer l'alimentation du GPS
    sendAT("AT+CGPSPWR=1");
    delay(1000);
    
    // Commande AT pour réinitialiser le GPS
    sendAT("AT+CGPSRST=1");
    delay(1000);
    
    // Initialise le Bluetooth
    initBluetooth();
}

// Initialise le module Bluetooth
void GPSTracker::initBluetooth() {
    Logger::info("Initialisation Bluetooth");
    
    // Active le Bluetooth
    sendAT("AT+BTPOWER=1");
    delay(2000);
    
    // Vérifie l'état du Bluetooth
    sendAT("AT+BTHOST?");
    String response = readResponse();
    
    if (response.indexOf("OK") >= 0) {
        bluetoothEnabled = true;
        Logger::info("Bluetooth activé avec succès");
    } else {
        Logger::error("Échec de l'activation Bluetooth");
        bluetoothEnabled = false;
    }
}

// Configure le nom Bluetooth et le code PIN
void GPSTracker::configureBluetooth(const String& name, const String& pin) {
    if (!bluetoothEnabled) {
        Logger::warn("Bluetooth non activé");
        return;
    }
    
    Logger::info("Configuration Bluetooth: " + name);
    
    // Définit le nom visible du Bluetooth
    sendAT("AT+BTHOST=" + name);
    delay(1000);
    
    // Définit le code PIN pour l'appairage (ex: "1234")
    sendAT("AT+BTPIN=" + pin);
    delay(1000);
    
    // Rend le module visible et découvrable
    sendAT("AT+BTSCAN=1");
    delay(1000);
    
    Logger::info("Bluetooth configuré - Nom: " + name + " PIN: " + pin);
}

// Active/désactive l'envoi automatique via Bluetooth
void GPSTracker::enableBluetoothSending(bool enable) {
    autoSendBluetooth = enable;
    Logger::info(enable ? "Envoi Bluetooth activé" : "Envoi Bluetooth désactivé");
}

// Arrête le module GPS et le Bluetooth
void GPSTracker::stop() {
    Logger::info("GPS et Bluetooth arrêtés");
    
    // Désactive le GPS
    sim808.println("AT+CGPSPWR=0");
    delay(500);
    
    // Désactive le Bluetooth
    sendAT("AT+BTPOWER=0");
    delay(500);
    
    ready = false;
    bluetoothEnabled = false;
}

// Vérifie si le GPS est prêt
bool GPSTracker::isReady() const {
    return ready;
}

// Met à jour la position GPS et envoie via Bluetooth si activé
void GPSTracker::update() {
    // Lit la position GPS
    readGPS();
    
    // Envoie via Bluetooth si activé et intervalle écoulé
    if (autoSendBluetooth && bluetoothEnabled && position.isValid) {
        unsigned long currentTime = millis();
        
        // Envoie toutes les GPS_UPDATE_INTERVAL millisecondes (5 secondes par défaut)
        if (currentTime - lastBluetoothSend >= GPS_UPDATE_INTERVAL) {
            sendGPSViaBluetooth();
            lastBluetoothSend = currentTime;
        }
    }
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

// Envoie la position GPS via Bluetooth
void GPSTracker::sendGPSViaBluetooth() {
    // Vérifie si la position est valide
    if (!position.isValid) {
        Logger::warn("Position GPS invalide - Envoi annulé");
        return;
    }
    
    // Vérifie si un appareil est connecté
    if (!isBluetoothConnected()) {
        Logger::warn("Aucun appareil Bluetooth connecté");
        return;
    }
    
    // Formate les données GPS en JSON pour faciliter le parsing côté récepteur
    String gpsData = "{";
    gpsData += "\"lat\":" + String(position.latitude, 6) + ",";
    gpsData += "\"lon\":" + String(position.longitude, 6) + ",";
    gpsData += "\"alt\":" + String(position.altitude, 2) + ",";
    gpsData += "\"valid\":" + String(position.isValid ? "true" : "false");
    gpsData += "}";
    
    // Alternative: format texte simple
    // String gpsData = "GPS:" + String(position.latitude, 6) + "," + String(position.longitude, 6);
    
    // Prépare l'envoi de données via SPP (Serial Port Profile)
    sendAT("AT+BTSPPDATA=" + String(gpsData.length()));
    delay(100);
    
    // Envoie les données
    sim808.print(gpsData);
    delay(100);
    
    // Attend la confirmation
    String response = readResponse();
    if (response.indexOf("OK") >= 0) {
        Logger::info("GPS envoyé via BT: Lat=" + String(position.latitude, 6) + 
                     " Lon=" + String(position.longitude, 6));
    } else {
        Logger::error("Échec de l'envoi Bluetooth");
    }
}

// Vérifie si un appareil Bluetooth est connecté
bool GPSTracker::isBluetoothConnected() {
    // Vérifie l'état de la connexion SPP (Serial Port Profile)
    sendAT("AT+BTGETPROF=1");
    String response = readResponse();
    
    // Si la réponse contient "CONNECT", un appareil est connecté
    return (response.indexOf("CONNECT") >= 0);
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
