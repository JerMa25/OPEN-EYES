// ============================================
// GSMEmergency.cpp - Implémentation complète
// ============================================
#include "GSMEmergency.h"
#include "Logger.h"
#include "Config.h"
#include <esp_task_wdt.h> 

// Constructeur : initialise les références
GSMEmergency::GSMEmergency(HardwareSerial& serial, GPSTracker& gpsRef)
    : sim808(serial), gps(gpsRef) {}

void GSMEmergency::init() {
    Logger::info("Initialisation GSM");

    // Initialise l'EEPROM
    initialiserEEPROM();

    // ── Étape 1 : Tester d'abord si le SIM808 répond déjà ─────────────────
    // IMPORTANT : PWRKEY fonctionne en TOGGLE sur le SIM808.
    //   - Si module ÉTEINT → impulsion l'ALLUME
    //   - Si module ALLUMÉ → impulsion l'ÉTEINT
    // Il faut donc tester AT avant d'envoyer l'impulsion !
    pinMode(SIM808_PWR, OUTPUT);
    digitalWrite(SIM808_PWR, HIGH); // état de repos (inactif)

    Logger::info("[GSM] Test présence SIM808...");

    // Vide le buffer avant de tester
    while (sim808.available()) sim808.read();

    sim808.println("AT");
    bool dejaPret = waitFor("OK", 3000);

    if (!dejaPret) {
        // Le module ne répond pas → envoyer l'impulsion PWRKEY pour le démarrer
        Logger::info("[GSM] Pas de réponse, envoi impulsion PWRKEY...");
        digitalWrite(SIM808_PWR, LOW);
        delay(1500); // maintien > 1s requis par le SIM808
        digitalWrite(SIM808_PWR, HIGH);
        Logger::info("[GSM] Impulsion envoyée, attente démarrage (5s)...");
        esp_task_wdt_reset();
        delay(5000); // délai de démarrage du module
        esp_task_wdt_reset();

        // Vide le buffer des messages de démarrage
        while (sim808.available()) sim808.read();

        // Re-test AT
        sim808.println("AT");
        if (!waitFor("OK", 5000)) {
            Logger::error("[GSM] SIM808 ne répond toujours pas ! Vérifier câblage TX/RX et alimentation.");
            ready = false;
            return;
        }
    }

    Logger::info("[GSM] SIM808 répond OK");
    esp_task_wdt_reset();

    // ── Étape 2 : Mode SMS texte ──────────────────────────────────────────
    while (sim808.available()) sim808.read(); // flush buffer avant chaque commande
    sim808.println("AT+CMGF=1");
    if (!waitFor("OK", 2000)) {
        Logger::error("[GSM] AT+CMGF=1 échoué");
        ready = false;
        return;
    }
    esp_task_wdt_reset();

    // ── Étape 3 : Notifications SMS entrants ─────────────────────────────
    while (sim808.available()) sim808.read();
    sim808.println("AT+CNMI=2,2,0,0,0");
    waitFor("OK", 2000);
    esp_task_wdt_reset();

    // ── Étape 4 : Active le GPS interne du SIM808 ────────────────────────
    while (sim808.available()) sim808.read();
    sim808.println("AT+CGPSPWR=1");
    waitFor("OK", 2000);
    esp_task_wdt_reset();

    ready = true;
    Logger::info("[GSM] Prêt - Contacts: " + String(getNombreContacts()));
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
    Logger::info("Commande reçue");

    // ✅ ADD:+237XXXXXXXXX
    if (sms.indexOf("ADD:") != -1) {
        int pos = sms.indexOf("ADD:") + 4;
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
            sendSMS(NUMERO_ADMIN, "ERREUR: Format invalide. ADD:+237XXXXXXXXX");
        }
    }

    // ✅ DEL:+237XXXXXXXXX
    else if (sms.indexOf("DEL:") != -1) {
        int pos = sms.indexOf("DEL:") + 4;
        String numero = sms.substring(pos, pos + 13);
        numero.trim();

        if (supprimerContact(numero)) {
            sendSMS(NUMERO_ADMIN, "CONF_OK: Contact supprime: " + numero);
            Logger::info("Contact supprimé: " + numero);
        } else {
            sendSMS(NUMERO_ADMIN, "ERREUR: Contact non trouve");
        }
    }

    // ✅ LIST
    else if (sms.indexOf("LIST") != -1) {
        listerContacts();
    }

    // ✅ LOC
    else if (sms.indexOf("LOC") != -1) {
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

    // ✅ HELP
    else if (sms.indexOf("HELP") != -1) {
        String aide = "Commandes:\n";
        aide += "ADD:+237XXX - Ajouter\n";
        aide += "DEL:+237XXX - Supprimer\n";
        aide += "LIST - Liste\n";
        aide += "LOC - Position\n";
        aide += "HELP - Aide";
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

    GPSData gpsData = gps.getGPSData();
    String msg = "ALERTE SOS - Canne Intelligente\n\n";

    if (gpsData.isValid) {
        msg += "Position:\nhttp://maps.google.com/maps?q=";
        msg += String(gpsData.latitude, 6) + "," + String(gpsData.longitude, 6);
        msg += "\nSats: " + String(gpsData.satellitesCount);
        msg += "\nFix: " + gpsData.fixType;
    } else {
        msg += "Position GPS indisponible\n";
        msg += "Fix: " + gpsData.fixType + "\n";
        msg += "Sats: " + String(gpsData.satellitesCount);
    }

    // 1) Numéro urgence principal
    sendSMS(NUMERO_URGENCE, msg);

    // 2) Tous les contacts EEPROM (donc ton tel test)
    sendAlertToAll(msg);
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

            //Reset watchdog APRÈS chaque SMS
            esp_task_wdt_reset();
        }
    }
    
    Logger::info("Alertes envoyées: " + String(envoyesAvecSucces) + "/" + String(getNombreContacts()));
}

// Lis les réponses du SIM808 pendant un délai, et les loggue
String GSMEmergency::readUntil(unsigned long timeoutMs) {
    String resp = "";
    unsigned long start = millis();
    while (millis() - start < timeoutMs) {
        while (sim808.available()) {
            char c = sim808.read();
            resp += c;
        }
        // petite pause pour laisser le modem répondre
        delay(10);
        esp_task_wdt_reset();
    }
    resp.trim();
    return resp;
}

// Attend qu'un motif apparaisse dans la réponse (OK, ERROR, >, etc.)
bool GSMEmergency::waitFor(const String& token, unsigned long timeoutMs) {
    unsigned long start = millis();
    String buf = "";
    while (millis() - start < timeoutMs) {
        while (sim808.available()) {
            char c = sim808.read();
            buf += c;
            if (buf.indexOf(token) != -1) {
                return true;
            }
            if (buf.indexOf("ERROR") != -1) {
                return false;
            }
        }
        delay(10);
        esp_task_wdt_reset();
    }
    return false;
}

// ✅ Envoie un SMS ET confirme l'envoi (OK/ERROR)
bool GSMEmergency::sendSMS(const String& number, const String& message) {
    if (!ready) {
        Logger::error("[SMS] GSM non prêt");
        return false;
    }

    if (number.length() < 10) {
        Logger::error("[SMS] Numéro invalide: " + number);
        return false;
    }

    Logger::info("[SMS] Préparation envoi vers: " + number);

    // Mode texte
    sim808.println("AT+CMGF=1");
    if (!waitFor("OK", 1500)) {
        Logger::error("[SMS] AT+CMGF=1 -> pas de OK");
        Logger::error("[SMS] Réponse: " + readUntil(500));
        return false;
    }

    // Démarre l'envoi
    sim808.print("AT+CMGS=\"");
    sim808.print(number);
    sim808.println("\"");

    // Le modem doit répondre ">" pour indiquer qu'il attend le message
    if (!waitFor(">", 3000)) {
        Logger::error("[SMS] AT+CMGS -> pas de prompt '>' (ou ERROR)");
        Logger::error("[SMS] Réponse: " + readUntil(1000));
        return false;
    }

    // Envoie le message + Ctrl+Z
    sim808.print(message);
    sim808.write(26); // Ctrl+Z

    // Attendre confirmation d'envoi (+CMGS puis OK)
    bool gotCMGS = waitFor("+CMGS:", 10000);
    bool gotOK = waitFor("OK", 10000);

    String tail = readUntil(800); // récupère le reste pour log

    if (gotCMGS && gotOK) {
        Logger::warn("[SMS] ✅ ENVOI CONFIRMÉ vers " + number);
        if (tail.length()) Logger::info("[SMS] Détails: " + tail);
        return true;
    }

    Logger::error("[SMS] ❌ ENVOI ÉCHOUÉ vers " + number);
    if (tail.length()) Logger::error("[SMS] Détails: " + tail);
    return false;
}