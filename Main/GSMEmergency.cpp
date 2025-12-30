// ============================================
// GSMEmergency.cpp - Implémentation complète
// ============================================
#include "GSMEmergency.h"
#include "Logger.h"
#include "Config.h"

// Constructeur : initialise les références
GSMEmergency::GSMEmergency(HardwareSerial& serial, GPSTracker& gpsRef)
    : sim808(serial), gps(gpsRef) {}

// Initialise le module GSM et l'EEPROM
void GSMEmergency::init() {
    Logger::info("Initialisation GSM");
    
    // Initialise l'EEPROM pour stocker les contacts
    initialiserEEPROM();
    
    // Configure le module en mode texte pour les SMS
    sim808.println("AT+CMGF=1");
    delay(500);
    
    // Active les notifications de SMS entrants
    sim808.println("AT+CNMI=2,2,0,0,0");
    delay(500);
    
    // Active le GPS du SIM808
    sim808.println("AT+CGPSPWR=1");
    delay(1000);
    
    ready = true;
    Logger::info("GSM prêt - Contacts: " + String(getNombreContacts()));
}

// Initialise l'EEPROM
void GSMEmergency::initialiserEEPROM() {
    EEPROM.begin(EEPROM_SIZE);
    
    // Vérifie si l'EEPROM a déjà été initialisée
    byte marker = EEPROM.read(0);
    if (marker != EEPROM_INIT_MARKER) {
        // Première initialisation : efface tout
        Logger::info("Première initialisation EEPROM");
        for (int i = 0; i < EEPROM_SIZE; i++) {
            EEPROM.write(i, 0xFF);
        }
        EEPROM.write(0, EEPROM_INIT_MARKER);
        EEPROM.commit();
        Logger::info("EEPROM initialisée");
    }
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

// Traitement des SMS entrants dans la boucle principale
void GSMEmergency::update() {
    traiterSMSEntrants();
}

// Traite les SMS entrants
void GSMEmergency::traiterSMSEntrants() {
    if (!sim808.available()) return;
    
    String sms = "";
    unsigned long timeout = millis();
    
    // Lit le SMS complet (timeout 2 secondes)
    while (millis() - timeout < 2000) {
        if (sim808.available()) {
            sms += sim808.readString();
        }
    }
    
    if (sms.length() == 0) return;
    
    Logger::info("SMS reçu");
    
    // Extrait le numéro de l'expéditeur
    String expediteur = extraireNumeroExpediteur(sms);
    
    // Vérifie si c'est une commande admin
    if (estNumeroAdmin(expediteur)) {
        traiterCommandeAdmin(sms);
    }
}

// Extrait le numéro de téléphone de l'expéditeur
String GSMEmergency::extraireNumeroExpediteur(const String& sms) {
    // Format typique: +CMT: "+237XXXXXXXXX"
    int pos1 = sms.indexOf("+CMT:");
    if (pos1 == -1) {
        // Essaye un autre format possible
        pos1 = sms.indexOf("+237");
        if (pos1 != -1) {
            return sms.substring(pos1, pos1 + 13);
        }
        return "";
    }
    
    int pos2 = sms.indexOf('"', pos1 + 6);
    int pos3 = sms.indexOf('"', pos2 + 1);
    
    if (pos2 != -1 && pos3 != -1) {
        return sms.substring(pos2 + 1, pos3);
    }
    return "";
}

// Vérifie si le numéro est celui de l'admin
bool GSMEmergency::estNumeroAdmin(const String& numero) {
    return (numero == String(NUMERO_ADMIN));
}

// Traite les commandes SMS de l'admin
void GSMEmergency::traiterCommandeAdmin(const String& sms) {
    Logger::info("Commande admin reçue");
    
    // Commande: ADMIN:ADD:+237XXXXXXXXX
    if (sms.indexOf("ADMIN:ADD:") != -1) {
        int pos = sms.indexOf("ADMIN:ADD:") + 10;
        String numero = sms.substring(pos, pos + 13);
        numero.trim();
        
        if (numero.startsWith("+") && numero.length() >= 10) {
            if (ajouterContact(numero)) {
                sendSMS(NUMERO_ADMIN, "CONF_OK: Contact ajoute: " + numero);
                Logger::info("Contact ajouté: " + numero);
            } else {
                sendSMS(NUMERO_ADMIN, "ERREUR: Memoire pleine ou existe deja");
            }
        } else {
            sendSMS(NUMERO_ADMIN, "ERREUR: Format invalide. ADMIN:ADD:+237XXXXXXXXX");
        }
    }
    
    // Commande: ADMIN:DEL:+237XXXXXXXXX
    else if (sms.indexOf("ADMIN:DEL:") != -1) {
        int pos = sms.indexOf("ADMIN:DEL:") + 10;
        String numero = sms.substring(pos, pos + 13);
        numero.trim();
        
        if (supprimerContact(numero)) {
            sendSMS(NUMERO_ADMIN, "CONF_OK: Contact supprime: " + numero);
            Logger::info("Contact supprimé: " + numero);
        } else {
            sendSMS(NUMERO_ADMIN, "ERREUR: Contact non trouve");
        }
    }
    
    // Commande: ADMIN:LIST
    else if (sms.indexOf("ADMIN:LIST") != -1) {
        listerContacts();
    }
    
    // Commande: ADMIN:LOC (demande de localisation)
    else if (sms.indexOf("ADMIN:LOC") != -1) {
        GPSData gpsData = gps.getGPSData();
        String reponse = "Position actuelle:\n";
        
        if (gpsData.isValid) {
            reponse += "http://maps.google.com/maps?q=";
            reponse += String(gpsData.latitude, 6) + "," + String(gpsData.longitude, 6);
            reponse += "\nSats: " + String(gpsData.satellitesCount);
            reponse += "\nFix: " + gpsData.fixType;
        } else {
            reponse += "Position indisponible\n";
            reponse += "Fix: " + gpsData.fixType;
            reponse += "\nSats: " + String(gpsData.satellitesCount);
        }
        
        sendSMS(NUMERO_ADMIN, reponse);
    }
    
    // Commande: ADMIN:HELP
    else if (sms.indexOf("ADMIN:HELP") != -1) {
        String aide = "Commandes:\n";
        aide += "ADMIN:ADD:+237XXX - Ajouter\n";
        aide += "ADMIN:DEL:+237XXX - Supprimer\n";
        aide += "ADMIN:LIST - Liste\n";
        aide += "ADMIN:LOC - Position\n";
        aide += "ADMIN:HELP - Aide";
        sendSMS(NUMERO_ADMIN, aide);
    }
}

// Ajoute un contact d'urgence en EEPROM
bool GSMEmergency::ajouterContact(const String& numero) {
    // Vérifie si le contact existe déjà
    if (contactExiste(numero)) {
        Logger::warn("Contact existe déjà: " + numero);
        return false;
    }
    
    // Cherche un slot libre
    for (int i = 0; i < MAX_CONTACTS; i++) {
        String contactActuel = lireContact(i);
        if (contactActuel.length() == 0 || contactActuel[0] == '\0' || (uint8_t)contactActuel[0] == 0xFF) {
            // Slot libre trouvé
            sauvegarderContact(i, numero);
            return true;
        }
    }
    
    Logger::error("Mémoire contacts pleine");
    return false;
}

// Supprime un contact d'urgence
bool GSMEmergency::supprimerContact(const String& numero) {
    for (int i = 0; i < MAX_CONTACTS; i++) {
        String contactActuel = lireContact(i);
        if (contactActuel == numero) {
            // Efface le contact
            sauvegarderContact(i, "");
            return true;
        }
    }
    return false;
}

// Vérifie si un contact existe
bool GSMEmergency::contactExiste(const String& numero) {
    for (int i = 0; i < MAX_CONTACTS; i++) {
        if (lireContact(i) == numero) {
            return true;
        }
    }
    return false;
}

// Sauvegarde un contact dans l'EEPROM
void GSMEmergency::sauvegarderContact(int slot, const String& numero) {
    if (slot < 0 || slot >= MAX_CONTACTS) return;
    
    int addr = EEPROM_START_ADDR + (slot * CONTACT_LENGTH);
    
    // Efface le slot
    for (int i = 0; i < CONTACT_LENGTH; i++) {
        EEPROM.write(addr + i, 0xFF);
    }
    
    // Écrit le nouveau numéro
    for (int i = 0; i < numero.length() && i < CONTACT_LENGTH - 1; i++) {
        EEPROM.write(addr + i, numero[i]);
    }
    
    EEPROM.commit();
}

// Lit un contact depuis l'EEPROM
String GSMEmergency::lireContact(int slot) {
    if (slot < 0 || slot >= MAX_CONTACTS) return "";
    
    int addr = EEPROM_START_ADDR + (slot * CONTACT_LENGTH);
    String numero = "";
    
    for (int i = 0; i < CONTACT_LENGTH; i++) {
        byte c = EEPROM.read(addr + i);
        if (c == 0 || c == 0xFF) break;
        numero += (char)c;
    }
    
    return numero;
}

// Liste tous les contacts enregistrés
void GSMEmergency::listerContacts() {
    String liste = "Contacts d'urgence:\n";
    int count = 0;
    
    for (int i = 0; i < MAX_CONTACTS; i++) {
        String contact = lireContact(i);
        if (contact.length() > 0 && contact[0] == '+') {
            liste += String(i + 1) + ". " + contact + "\n";
            count++;
        }
    }
    
    if (count == 0) {
        liste += "Aucun contact enregistre";
    }
    
    sendSMS(NUMERO_ADMIN, liste);
    Logger::info("Contacts listés: " + String(count));
}

// Retourne le nombre de contacts enregistrés
int GSMEmergency::getNombreContacts() const {
    int count = 0;
    for (int i = 0; i < MAX_CONTACTS; i++) {
        String contact = const_cast<GSMEmergency*>(this)->lireContact(i);
        if (contact.length() > 0 && contact[0] == '+') {
            count++;
        }
    }
    return count;
}

// Envoie une alerte SOS simple au numéro d'urgence
void GSMEmergency::sendSOS() {
    Logger::warn("=== ALERTE SOS ===");
    
    // Récupère toutes les données GPS
    GPSData gpsData = gps.getGPSData();
    
    // Construction du message SOS
    String msg = "ALERTE SOS - Canne Intelligente\n\n";
    
    // Vérifie si les données GPS sont valides
    if (gpsData.isValid) {
        msg += "Position:\n";
        msg += "http://maps.google.com/maps?q=";
        msg += String(gpsData.latitude, 6) + "," + String(gpsData.longitude, 6);
        msg += "\n\n";
        msg += "Lat: " + String(gpsData.latitude, 6) + "\n";
        msg += "Lon: " + String(gpsData.longitude, 6) + "\n";
        msg += "Alt: " + String(gpsData.altitude, 1) + "m\n";
        
        if (gpsData.speed > 1.0) {
            msg += "Vitesse: " + String(gpsData.speed, 1) + " km/h\n";
        }
        
        msg += "Sats: " + String(gpsData.satellitesCount) + "\n";
        msg += "Fix: " + gpsData.fixType;
    } else {
        msg += "Position GPS indisponible\n";
        msg += "Raison: " + gpsData.fixType + "\n";
        msg += "Sats: " + String(gpsData.satellitesCount);
    }
    
    // Envoie au numéro d'urgence principal
    sendSMS(NUMERO_URGENCE, msg);
}

// Envoie une alerte à TOUS les contacts enregistrés en EEPROM
void GSMEmergency::sendAlertToAll(const String& message) {
    Logger::warn("=== ALERTE MULTI-CONTACTS ===");
    
    GPSData gpsData = gps.getGPSData();
    String msg = message;
    
    // Ajoute la position si disponible
    if (gpsData.isValid && strlen(gpsData.gpsTimestamp.c_str()) > 5) {
        msg += " Loc: http://maps.google.com/maps?q=";
        msg += String(gpsData.latitude, 6) + "," + String(gpsData.longitude, 6);
    }
    
    int envoyesAvecSucces = 0;
    
    // Envoie à tous les contacts enregistrés en EEPROM
    for (int i = 0; i < MAX_CONTACTS; i++) {
        String contact = lireContact(i);
        if (contact.length() > 0 && contact[0] == '+') {
            Logger::info("Envoi alerte à: " + contact);
            if (sendSMS(contact, msg)) {
                envoyesAvecSucces++;
            }
            delay(3500); // Délai entre chaque SMS (important pour SIM808)
        }
    }
    
    Logger::info("Alertes envoyées: " + String(envoyesAvecSucces) + "/" + String(getNombreContacts()));
}

// Envoie un SMS via le module GSM
bool GSMEmergency::sendSMS(const String& number, const String& message) {
    if (!ready) {
        Logger::error("GSM non prêt");
        return false;
    }
    
    if (number.length() < 10) {
        Logger::error("Numéro invalide: " + number);
        return false;
    }
    
    Logger::info("Envoi SMS vers: " + number);
    
    // Commande AT pour envoyer un SMS
    sim808.print("AT+CMGF=1\r");
    delay(100);
    
    sim808.print("AT+CMGS=\"");
    sim808.print(number);
    sim808.println("\"");
    delay(200);
    
    // Envoie le message
    sim808.print(message);
    
    // Envoie Ctrl+Z pour terminer
    sim808.write(26);
    delay(3000);
    
    return true;
}