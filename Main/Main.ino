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
GPSTracker gps(SIM808);
GSMEmergency gsm(SIM808, gps);
ObstacleDetector detector;
BluetoothManager bluetooth(gps);

// Tableau de pointeurs vers tous les modules à initialiser et mettre à jour
IModule* modules[] = { &gps, &gsm, &detector, &bluetooth };

// ===== VARIABLES BOUTON ON/OFF =====
bool systemeActif = true;
bool dernierEtatBoutonONOFF = HIGH;
unsigned long dernierToggle = 0;
const unsigned long DELAI_DEBOUNCE = 200;

// ===== VARIABLES POUR PATTERN BOUTON SOS =====
bool boutonPrecedent = HIGH;
unsigned long tempsPremierAppui = 0;
unsigned long tempsAppui = 0;
int compteurClics = 0;
bool appuiEnCours = false;

// Variables pour les indicateurs de statut
unsigned long lastStatusLog = 0;
unsigned long lastGPSCheck = 0;
const unsigned long STATUS_INTERVAL = 10000;
const unsigned long GPS_CHECK_INTERVAL = 5000;

// ✅ Variables pour envoi BLE
unsigned long lastObstacleBLESend = 0;
unsigned long lastWaterBLESend = 0;

// ============================================
// FONCTION : GESTION BOUTON ON/OFF
// ============================================
void gererBoutonONOFF() {
    bool etatActuel = digitalRead(BOUTON_ONOFF);
    
    if (dernierEtatBoutonONOFF == HIGH && etatActuel == LOW) {
        if (millis() - dernierToggle > DELAI_DEBOUNCE) {
            systemeActif = !systemeActif;
            dernierToggle = millis();
            
            if (systemeActif) {
                Logger::info("=== SYSTÈME ACTIVÉ ===");
                for (IModule* m : modules) {
                    if (!m->isReady()) {
                        m->init();
                    }
                }
                for (int i = 0; i < 3; i++) {
                    digitalWrite(LED_STATUS, HIGH);
                    delay(200);
                    digitalWrite(LED_STATUS, LOW);
                    delay(200);
                }
            } else {
                Logger::info("=== SYSTÈME DÉSACTIVÉ ===");
                for (IModule* m : modules) {
                    m->stop();
                }
                digitalWrite(LED_STATUS, LOW);
                
                // ✅ Signal d'arrêt
                ledcWriteTone(BUZZER_1_PIN, 1500);
                delay(100);
                ledcWrite(BUZZER_1_PIN, 0);
                delay(100);
                ledcWriteTone(BUZZER_1_PIN, 1500);
                delay(100);
                ledcWrite(BUZZER_1_PIN, 0);
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

    if (boutonPrecedent == HIGH && boutonActuel == LOW) {
        tempsAppui = maintenant;
        appuiEnCours = true;
        
        if (compteurClics == 0) {
            tempsPremierAppui = maintenant;
        }
        compteurClics++;
        
        Logger::info("Bouton pressé (clic " + String(compteurClics) + ")");
    }

    if (boutonPrecedent == LOW && boutonActuel == HIGH) {
        unsigned long duree = maintenant - tempsAppui;
        appuiEnCours = false;
        
        Logger::info("Bouton relâché (durée: " + String(duree) + "ms)");
        
        if (duree >= DELAI_APPUI_LONG) {
            Logger::warn("!!! APPUI LONG DETECTE - ALERTE SOS !!!");
            gsm.sendAlertToAll("URGENCE ! J'ai besoin d'aide !");
            compteurClics = 0;
        }
    }

    if (compteurClics > 0 && !appuiEnCours) {
        if (maintenant - tempsPremierAppui > DELAI_DOUBLE_CLIC) {
            if (compteurClics == 1) {
                Logger::info("1 clic court détecté - Envoi message 'Tout va bien'");
                gsm.sendAlertToAll("Tout va bien.");
            }
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
    Serial.begin(DEBUG_BAUDRATE);
    delay(2000);
    
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);

    Logger::info("=== CANNE INTELLIGENTE - DEMARRAGE ===");

    bluetooth.setDeviceName("OPEN EYES");

    pinMode(BOUTON_SOS, INPUT_PULLUP);
    pinMode(BOUTON_ONOFF, INPUT_PULLUP);

    pinMode(LED_STATUS, OUTPUT);
    digitalWrite(LED_STATUS, LOW);

    // ✅ CONFIGURATION DES 2 BUZZERS (UNE SEULE FOIS ICI)
    Logger::info("Configuration PWM Buzzers...");
    ledcAttach(BUZZER_1_PIN, 2000, BUZZER_1_RES);
    ledcWrite(BUZZER_1_PIN, 0);
    Logger::info("Buzzer 1 (GPIO " + String(BUZZER_1_PIN) + ") - Obstacles");
    
    ledcAttach(BUZZER_2_PIN, 2000, BUZZER_2_RES);
    ledcWrite(BUZZER_2_PIN, 0);
    Logger::info("Buzzer 2 (GPIO " + String(BUZZER_2_PIN) + ") - Eau");

    // ✅ Initialisation des modules (ObstacleDetector n'initialisera PAS les buzzers)
    for (IModule* m : modules) {
        m->init();
    }
    
    // ✅ Test de démarrage (3 bips)
    for (int i = 0; i < 3; i++) {
        ledcWriteTone(BUZZER_1_PIN, OBSTACLE_FREQ_DEMARRAGE);
        delay(150);
        ledcWrite(BUZZER_1_PIN, 0);
        delay(150);
    }

    Logger::info("=== SYSTEME OPERATIONNEL ===");
    Logger::info("Nom BLE: OPEN EYES");
    Logger::info("Contacts enregistrés: " + String(gsm.getNombreContacts()));
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
    Logger::info("");
    Logger::info("--- SYSTÈME DE DÉTECTION ---");
    Logger::info("Buzzer 1 (GPIO " + String(BUZZER_1_PIN) + ") = Obstacles");
    Logger::info("Buzzer 2 (GPIO " + String(BUZZER_2_PIN) + ") = Eau");
    Logger::info("Capteur eau (GPIO " + String(WATER_SENSOR_PIN) + ")");
    Logger::info("Vibration (GPIO " + String(OBSTACLE_VIBRATOR_PIN) + ")");
    Logger::info("---------------------------");
}

// ============================================
// LOOP (✅ AVEC DÉLAI AUGMENTÉ)
// ============================================
void loop() {
    gererBoutonONOFF();

    if (!systemeActif) {
        delay(100);
        return;
    }

    // ✅ Update des modules
    for (IModule* m : modules) {
        m->update();
    }

    detecterPatternBouton();

    unsigned long currentTime = millis();

    if (currentTime - lastStatusLog >= STATUS_INTERVAL) {
        Logger::info("--- Statut Système ---");
        Logger::info("BLE Connecté: " + String(bluetooth.isClientConnected() ? "OUI" : "NON"));
        Logger::info("GPS Prêt: " + String(gps.isReady() ? "OUI" : "NON"));
        Logger::info("GSM Prêt: " + String(gsm.isReady() ? "OUI" : "NON"));
        Logger::info("Détecteur Prêt: " + String(detector.isReady() ? "OUI" : "NON"));
        Logger::info("Contacts EEPROM: " + String(gsm.getNombreContacts()) + "/" + String(MAX_CONTACTS));
        
        WaterSensorData waterData = detector.getWaterSensorData();
        Logger::info("Capteur Eau: " + String(waterData.humidityLevel) + "% (raw: " + String(waterData.rawData) + ")");
        
        Logger::info("----------------------");
        
        lastStatusLog = currentTime;
    }

    if (currentTime - lastGPSCheck >= GPS_CHECK_INTERVAL) {
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

    // ✅ Envoi BLE obstacles et eau séparément
    if (currentTime - lastObstacleBLESend >= OBSTACLE_BLE_UPDATE_INTERVAL) {
        if (bluetooth.isClientConnected()) {
            ObstacleData obstacleData = detector.getObstacleData();
            bluetooth.sendObstacleData(obstacleData);
        }
        lastObstacleBLESend = currentTime;
    }

    if (currentTime - lastWaterBLESend >= WATER_BLE_UPDATE_INTERVAL) {
        if (bluetooth.isClientConnected()) {
            WaterSensorData waterData = detector.getWaterSensorData();
            bluetooth.sendWaterSensorData(waterData);
        }
        lastWaterBLESend = currentTime;
    }

    static unsigned long lastBlink = 0;
    static bool ledState = false;
    
    if (currentTime - lastBlink >= 1000) {
        ledState = !ledState;
        digitalWrite(LED_STATUS, ledState);
        lastBlink = currentTime;
    }
    
    // ✅ Délai augmenté de 10ms à 50ms pour laisser respirer le système
    delay(50);
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