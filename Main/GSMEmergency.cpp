// ============================================
// GSMEmergency.cpp - Implémentation GSM
// ============================================
#include "GSMEmergency.h"
#include "Logger.h"
#include "Config.h"

// Constructeur : initialise les références
GSMEmergency::GSMEmergency(HardwareSerial& serial, GPSTracker& gpsRef)
    : sim808(serial), gps(gpsRef) {}

// Initialise le module GSM pour l'envoi de SMS
void GSMEmergency::init() {
    Logger::info("Initialisation GSM");
    
    // Configure le module en mode texte pour les SMS
    sim808.println("AT+CMGF=1");
    delay(500);
    
    ready = true;
    Logger::info("GSM prêt");
}

// Arrête le module GSM
void GSMEmergency::stop() {
    Logger::info("GSM arrêté");
    ready = false;
}

// Vérifie si le GSM est prêt
bool GSMEmergency::isReady() const {
    return ready;
}

// Mise à jour (pour futur traitement des SMS entrants)
void GSMEmergency::update() {
    // TODO: Implémenter la réception et le traitement des SMS entrants
    // Exemple: Commandes à distance pour localiser la canne
}

// Envoie une alerte SOS avec la position GPS complète
void GSMEmergency::sendSOS() {
    Logger::warn("=== ALERTE SOS ===");
    
    // Récupère toutes les données GPS
    GPSData gpsData = gps.getGPSData();
    
    // Construction du message SOS
    String msg = "🆘 ALERTE SOS - Canne Intelligente\n\n";
    
    // Vérifie si les données GPS sont valides
    if (gpsData.isValid) {
        // Ajoute le lien Google Maps
        msg += "📍 Position:\n";
        msg += "https://maps.google.com/?q=";
        msg += String(gpsData.latitude, 6) + "," + String(gpsData.longitude, 6);
        msg += "\n\n";
        
        // Ajoute les détails GPS
        msg += "Latitude: " + String(gpsData.latitude, 6) + "\n";
        msg += "Longitude: " + String(gpsData.longitude, 6) + "\n";
        msg += "Altitude: " + String(gpsData.altitude, 1) + "m\n";
        
        // Ajoute la vitesse si en mouvement
        if (gpsData.speed > 1.0) {
            msg += "Vitesse: " + String(gpsData.speed, 1) + " km/h\n";
        }
        
        // Ajoute la qualité du signal GPS
        msg += "Satellites: " + String(gpsData.satellitesCount) + "\n";
        msg += "Précision: " + gpsData.fixType + "\n";
        
        // Ajoute l'horodatage si disponible
        if (gpsData.gpsTimestamp.length() > 0) {
            msg += "Heure GPS: " + gpsData.gpsTimestamp;
        }
    } else {
        // Si pas de position GPS valide
        msg += "⚠️ Position GPS indisponible\n";
        msg += "Raison: " + gpsData.fixType + "\n";
        msg += "Satellites: " + String(gpsData.satellitesCount);
    }
    
    // Envoie le SMS au numéro d'urgence
    Logger::info("Envoi SMS SOS à " + String(NUMERO_URGENCE));
    if (sendSMS(NUMERO_URGENCE, msg)) {
        Logger::info("SMS SOS envoyé avec succès");
    } else {
        Logger::error("Échec de l'envoi du SMS SOS");
    }
    
    // Optionnel: Envoyer aussi au numéro du proche si défini
    #ifdef NUMERO_PROCHE
    if (String(NUMERO_PROCHE).length() > 0 && String(NUMERO_PROCHE) != String(NUMERO_URGENCE)) {
        delay(2000); // Délai entre deux envois
        Logger::info("Envoi SMS SOS à " + String(NUMERO_PROCHE));
        sendSMS(NUMERO_PROCHE, msg);
    }
    #endif
}

// Envoie un SMS via le module GSM
bool GSMEmergency::sendSMS(const String& number, const String& message) {
    // Vérifie que le GSM est prêt
    if (!ready) {
        Logger::error("GSM non prêt - Envoi SMS annulé");
        return false;
    }
    
    // Vérifie que le numéro est valide
    if (number.length() < 10) {
        Logger::error("Numéro invalide: " + number);
        return false;
    }
    
    Logger::info("Envoi SMS vers: " + number);
    
    // Commande AT pour commencer l'envoi d'un SMS
    sim808.print("AT+CMGS=\"");
    sim808.print(number);
    sim808.println("\"");
    delay(500);
    
    // Envoie le contenu du message
    sim808.print(message);
    
    // Envoie le caractère Ctrl+Z (26) pour terminer et envoyer le SMS
    sim808.write(26);
    delay(3000); // Attend la confirmation d'envoi
    
    // TODO: Vérifier la réponse du module pour confirmer l'envoi
    // Lire la réponse et chercher "+CMGS:" pour confirmer
    
    return true;
}
