#include <Arduino.h>
#include <HardwareSerial.h>

#include "Config.h"
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"
#include "ObstacleDetector.h"
#include "BluetoothManager.h"

// Création d'un port série matériel (UART2) pour communiquer avec le SIM808
HardwareSerial SIM808(2);

// Initialisation des objets
GPSTracker gps(SIM808);      // Objet qui gère le GPS
GSMEmergency gsm(SIM808, gps); // Objet qui gère les urgences GSM
ObstacleDetector detector; // Objet qui gère détection des obstacles
BluetoothManager bluetooth(gps); //Objet qui gère des données via bluetooth

// Tableau de pointeurs vers tous les modules à initialiser et mettre à jour
IModule* modules[] = { &gps, &gsm, &detector, &bluetooth };

// ===== VARIABLES BOUTON ON/OFF =====
bool systemeActif = true;           // État du système (ON/OFF)
bool dernierEtatBoutonONOFF = HIGH; // État précédent du bouton ON/OFF
unsigned long dernierToggle = 0;    // Dernier changement d'état
const unsigned long DELAI_DEBOUNCE = 200; // Anti-rebond 200ms

// ===== VARIABLES POUR PATTERN BOUTON SOS =====
bool boutonPrecedent = HIGH;
unsigned long tempsPremierAppui = 0;
unsigned long tempsAppui = 0;
int compteurClics = 0;
bool appuiEnCours = false;

// Variables pour les indicateurs de statut
unsigned long lastStatusLog = 0;
unsigned long lastGPSCheck = 0;
const unsigned long STATUS_INTERVAL = 10000;  // Log de statut toutes les 10 secondes
const unsigned long GPS_CHECK_INTERVAL = 5000; // Vérification GPS toutes les 5 secondes

// ============================================
// FONCTION : GESTION BOUTON ON/OFF
// ============================================
void gererBoutonONOFF() {
    bool etatActuel = digitalRead(BOUTON_ONOFF);
    
    // Détection d'un appui (transition HIGH -> LOW)
    if (dernierEtatBoutonONOFF == HIGH && etatActuel == LOW) {
        // Anti-rebond : ignore si moins de 200ms depuis dernier toggle
        if (millis() - dernierToggle > DELAI_DEBOUNCE) {
            // Inverse l'état du système
            systemeActif = !systemeActif;
            dernierToggle = millis();
            
            if (systemeActif) {
                Logger::info("=== SYSTÈME ACTIVÉ ===");

                // Allume LED Power (verte)
                digitalWrite(LED_POWER, HIGH);

                // Réactive tous les modules
                for (IModule* m : modules) {
                    if (!m->isReady()) {
                        m->init();
                    }
                }
                // LED Status clignote 3 fois pour confirmer
                for (int i = 0; i < 3; i++) {
                    digitalWrite(LED_STATUS, HIGH);
                    delay(200);
                    digitalWrite(LED_STATUS, LOW);
                    delay(200);
                }
            } else {
                Logger::info("=== SYSTÈME DÉSACTIVÉ ===");

                // Éteint LED Power (verte)
                digitalWrite(LED_POWER, LOW);

                // Arrête tous les modules
                for (IModule* m : modules) {
                    m->stop();
                }
                // LED Status éteinte
                digitalWrite(LED_STATUS, LOW);
                
                // Bip de confirmation (2 bips courts)
                ledcWriteTone(OBSTACLE_BUZZER_PIN, 1500);
                delay(100);
                ledcWrite(OBSTACLE_BUZZER_PIN, 0);
                delay(100);
                ledcWriteTone(OBSTACLE_BUZZER_PIN, 1500);
                delay(100);
                ledcWrite(OBSTACLE_BUZZER_PIN, 0);
            }
        }
    }
    
    dernierEtatBoutonONOFF = etatActuel;
}

// ============================================
// FONCTION DETECTION PATTERN BOUTON SOS
// ============================================
void detecterPatternBouton() {
    bool boutonActuel = digitalRead(BOUTON_SOS);
    unsigned long maintenant = millis();

    // Détection d'un appui (transition HIGH -> LOW)
    if (boutonPrecedent == HIGH && boutonActuel == LOW) {
        tempsAppui = maintenant;
        appuiEnCours = true;
        
        // Si c'est le premier clic, on enregistre le temps
        if (compteurClics == 0) {
            tempsPremierAppui = maintenant;
        }
        compteurClics++;
        
        Logger::info("Bouton pressé (clic " + String(compteurClics) + ")");
    }

    // Détection d'un relâchement (transition LOW -> HIGH)
    if (boutonPrecedent == LOW && boutonActuel == HIGH) {
        unsigned long duree = maintenant - tempsAppui;
        appuiEnCours = false;
        
        Logger::info("Bouton relâché (durée: " + String(duree) + "ms)");
        
        // Appui long détecté (≥ 2 secondes)
        if (duree >= DELAI_APPUI_LONG) {
            Logger::warn("!!! APPUI LONG DETECTE - ALERTE SOS !!!");
            gsm.sendAlertToAll("URGENCE ! J'ai besoin d'aide !");
            compteurClics = 0;
        }
    }

    // Vérification du timeout pour un simple clic
    if (compteurClics > 0 && !appuiEnCours) {
        if (maintenant - tempsPremierAppui > DELAI_DOUBLE_CLIC) {
            // Un seul clic court = Message rassurant
            if (compteurClics == 1) {
                Logger::info("1 clic court détecté - Envoi message 'Tout va bien'");
                gsm.sendAlertToAll("Tout va bien.");
            }
            // Double clic ou plus : ignoré pour le moment
            else if (compteurClics >= 2) {
                Logger::info(String(compteurClics) + " clics détectés - Ignoré");
            }
            
            compteurClics = 0;
        }
    }
    
    boutonPrecedent = boutonActuel;
}

// ============================================
// SETUP
// ============================================
void setup() {
    // Initialisation de la communication série pour le debug (USB)
    Serial.begin(DEBUG_BAUDRATE);

    // Petit délai pour laisser le moniteur série se connecter
    delay(2000);
    
    // Initialisation de la communication série avec le module SIM808
    // SERIAL_8N1 = 8 bits de données, pas de parité, 1 bit d'arrêt
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);

    Logger::info("=== CANNE INTELLIGENTE - DEMARRAGE ===");

    // Configuration du nom BLE
    bluetooth.setDeviceName("OPEN EYES");

    // ===== CONFIGURATION DES BOUTONS =====
    pinMode(BOUTON_SOS, INPUT_PULLUP);     // Bouton SOS avec résistance PULLUP interne
    pinMode(BOUTON_ONOFF, INPUT_PULLUP);   // Bouton ON/OFF avec résistance PULLUP interne

    // Configuration des LEDs
    pinMode(LED_POWER, OUTPUT);            // LED verte Power
    pinMode(LED_STATUS, OUTPUT);           // LED rouge Status
    digitalWrite(LED_POWER, HIGH);         // LED Power allumée au démarrage
    digitalWrite(LED_STATUS, LOW);

    // Configuration du buzzer
    ledcAttach(OBSTACLE_BUZZER_PIN, 2000, OBSTACLE_BUZZER_RES);
    ledcWrite(OBSTACLE_BUZZER_PIN, 0);

    // Initialisation de tous les modules
    for (IModule* m : modules) {
        m->init();
    }
    
    // Bip de démarrage (3 bips)
    for (int i = 0; i < 3; i++) {
        ledcWriteTone(OBSTACLE_BUZZER_PIN, OBSTACLE_FREQ_DEMARRAGE);
        delay(150);
        ledcWrite(OBSTACLE_BUZZER_PIN, 0);
        delay(150);
    }

    Logger::info("=== SYSTEME OPERATIONNEL ===");
    Logger::info("Nom BLE: OPEN EYES");
    Logger::info("Contacts enregistrés: " + String(gsm.getNombreContacts()));
    Logger::info("");
    Logger::info("--- BOUTONS ---");
    Logger::info("Bouton VERT (GPIO12) = ON/OFF système");
    Logger::info("Bouton ROUGE (GPIO13) = SOS");
    Logger::info("");
    Logger::info("--- COMMANDES SMS ADMIN ---");
    Logger::info("ADMIN:ADD:+237XXX - Ajouter contact");
    Logger::info("ADMIN:DEL:+237XXX - Supprimer contact");
    Logger::info("ADMIN:LIST - Liste contacts");
    Logger::info("ADMIN:LOC - Position GPS");
    Logger::info("ADMIN:HELP - Aide");
    Logger::info("");
    Logger::info("--- PATTERNS BOUTON SOS ---");
    Logger::info("1 clic court = Message 'Tout va bien'");
    Logger::info("Appui long (2s) = Alerte SOS complète");
    Logger::info("---------------------------");
}

// ============================================
// LOOP
// ============================================
void loop() {
    // ===== GESTION BOUTON ON/OFF (TOUJOURS ACTIF) =====
    gererBoutonONOFF();

    // ===== SI SYSTÈME INACTIF, ON NE FAIT RIEN D'AUTRE =====
    if (!systemeActif) {
        delay(100); // Économie d'énergie
        return;     // Sort de loop() sans exécuter le reste
    }

    // ===== SYSTÈME ACTIF : FONCTIONNEMENT NORMAL =====

    // Mise à jour de tous les modules à chaque itération
    for (IModule* m : modules) {
        m->update();
    }

    // ===== DETECTION DES PATTERNS DU BOUTON =====
    detecterPatternBouton();

    // ===== INDICATEUR DE STATUT PERIODIQUE =====
    unsigned long currentTime = millis();

    // Affiche un log de statut toutes les 10 secondes
    if (currentTime - lastStatusLog >= STATUS_INTERVAL) {
        Logger::info("--- Statut Système ---");
        Logger::info("Système: " + String(systemeActif ? "ON" : "OFF"));
        Logger::info("BLE Connecté: " + String(bluetooth.isClientConnected() ? "OUI" : "NON"));
        Logger::info("GPS Prêt: " + String(gps.isReady() ? "OUI" : "NON"));
        Logger::info("GSM Prêt: " + String(gsm.isReady() ? "OUI" : "NON"));
        Logger::info("Détecteur Prêt: " + String(detector.isReady() ? "OUI" : "NON"));
        Logger::info("Contacts EEPROM: " + String(gsm.getNombreContacts()) + "/" + String(MAX_CONTACTS));
        Logger::info("----------------------");
        
        lastStatusLog = currentTime;
    }

    // ===== VERIFICATION GPS PERIODIQUE =====
    if (currentTime - lastGPSCheck >= GPS_CHECK_INTERVAL) {
        // Récupère et affiche les données GPS
        GPSData gpsData = gps.getGPSData();
        
        if (gpsData.isValid) {
            Logger::info("GPS: Lat=" + String(gpsData.latitude, 6) + 
                         " Lon=" + String(gpsData.longitude, 6) +
                         " Sats=" + String(gpsData.satellitesCount) +
                         " Fix=" + gpsData.fixType);
        } else {
            Logger::warn("GPS: Pas de fix valide (Sats=" + String(gpsData.satellitesCount) + 
                         " Fix=" + gpsData.fixType + ")");
        }
        
        lastGPSCheck = currentTime;
    }

    // ===== ENVOI DES DONNEES BLUETOOTH SI CLIENT CONNECTE =====
    static unsigned long lastManualSend = 0;
    if (bluetooth.isClientConnected() && currentTime - lastManualSend >= GPS_UPDATE_INTERVAL) {
        // Envoie les données d'obstacles
        ObstacleData obstacleData = detector.getObstacleData();
        bluetooth.sendObstacleData(obstacleData);
        
        // Envoie les données du capteur d'eau
        WaterSensorData waterData = detector.getWaterSensorData();
        bluetooth.sendWaterSensorData(waterData);

        // Envoie les données GPS
        bluetooth.sendGPSData();
        
        lastManualSend = currentTime;
    }

    // ===== INDICATEUR VISUEL (LED) =====
    // LED clignote pour montrer que le système fonctionne
    static unsigned long lastBlink = 0;
    static bool ledState = false;
    
    if (currentTime - lastBlink >= 1000) {
        ledState = !ledState;
        digitalWrite(LED_STATUS, ledState);
        lastBlink = currentTime;
    }
    
    // Petit délai pour ne pas surcharger le processeur
    delay(10);
}

// ============================================
// GUIDE D'UTILISATION
// ============================================
/*
=== GESTION DES CONTACTS VIA SMS ===

1. Envoyer un SMS depuis le NUMERO_ADMIN au SIM808:

   Pour ajouter un contact:
   ADMIN:ADD:+237XXXXXXXXX
   
   Pour supprimer un contact:
   ADMIN:DEL:+237XXXXXXXXX
   
   Pour lister tous les contacts:
   ADMIN:LIST
   
   Pour obtenir la position GPS:
   ADMIN:LOC
   
   Pour obtenir l'aide:
   ADMIN:HELP

2. Le système répondra avec une confirmation

=== UTILISATION DU BOUTON SOS ===

1 clic court:
   - Envoie "Tout va bien" à tous les contacts EEPROM
   
Appui long (≥ 2 secondes):
   - Envoie "URGENCE ! J'ai besoin d'aide !" à tous les contacts EEPROM
   - Inclut la position GPS si disponible

=== NOTES IMPORTANTES ===

- Seul le NUMERO_ADMIN peut gérer les contacts
- Maximum 5 contacts peuvent être enregistrés en EEPROM
- Les contacts sont persistants (sauvegardés en EEPROM)
- Les SMS entrants sont traités automatiquement dans loop()
- Délai de 3,5 secondes entre chaque SMS pour ne pas surcharger le SIM808
*/