#include <Arduino.h>
#include <HardwareSerial.h>
#include <esp_task_wdt.h>

#include "Config.h"
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"
#include "ObstacleDetector.h"
#include "BluetoothManager.h"
#include <ESP32Servo.h>
#include "GPSAssistance.h" 

HardwareSerial SIM808(2);

GPSTracker gps(SIM808);
GSMEmergency gsm(SIM808, gps);
ObstacleDetector detector;
BluetoothManager bluetooth(gps);
GPSAssistance imu(bluetooth); 
IModule* modules[] = { &gps, &gsm, &detector, &bluetooth, &imu};

// ===== BOUTON SOS =====
bool boutonPrecedent = HIGH;
unsigned long tempsPremierAppui = 0;
unsigned long tempsAppui = 0;
int compteurClics = 0;
bool appuiEnCours = false;

// ===== TIMERS =====
unsigned long lastStatusLog = 0;
unsigned long lastGPSCheck = 0;
unsigned long lastObstacleBLESend = 0;
unsigned long lastWaterBLESend = 0;
unsigned long lastDistanceLog = 0;

const unsigned long STATUS_INTERVAL = 10000;
const unsigned long GPS_CHECK_INTERVAL = 5000;
const unsigned long DISTANCE_LOG_INTERVAL = 2000;

// =======================================================
// DETECTION PATTERN BOUTON SOS
// =======================================================
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
        
        Logger::info("🔘 [SOS] Clic " + String(compteurClics));
    }

    if (boutonPrecedent == LOW && boutonActuel == HIGH) {
        unsigned long duree = maintenant - tempsAppui;
        appuiEnCours = false;
        
        Logger::info("🔘 [SOS] Relâché (durée=" + String(duree) + "ms)");
        
        if (duree >= DELAI_APPUI_LONG) {
            Logger::warn("🚨 [SOS] APPUI LONG - ALERTE !");
            gsm.sendAlertToAll("URGENCE ! J'ai besoin d'aide !");
            compteurClics = 0;
        }
    }

    if (compteurClics > 0 && !appuiEnCours) {
        if (maintenant - tempsPremierAppui > DELAI_DOUBLE_CLIC) {
            if (compteurClics == 1) {
                Logger::info("✅ [SOS] 1 clic - Message OK");
                gsm.sendAlertToAll("Tout va bien.");
            }
            else if (compteurClics >= 2) {
                Logger::info("ℹ️ [SOS] " + String(compteurClics) + " clics - Ignoré");
            }
            
            compteurClics = 0;
        }
    }
    
    boutonPrecedent = boutonActuel;
}


// =======================================================
// SETUP
// =======================================================
void setup() {
    Serial.begin(DEBUG_BAUDRATE);
    delay(500);
    
    Logger::info("╔════════════════════════════════════════╗");
    Logger::info("║   CANNE INTELLIGENTE - DEBUG MODE     ║");
    Logger::info("╚════════════════════════════════════════╝");
    Logger::info("");

    // ===== CONFIGURATION WATCHDOG =====
    Logger::info("🛡️ [SETUP] Configuration Watchdog Timer...");
    esp_task_wdt_init(8, true);
    esp_task_wdt_add(NULL);
    Logger::info("✅ [SETUP] Watchdog configuré (8s)");
    Logger::info("");

    // ===== TEST PINS =====
    Logger::info("🔧 [SETUP] Test configuration pins...");
    Logger::info("📍 BUZZER_1_PIN = GPIO" + String(BUZZER_1_PIN));
    Logger::info("📍 BUZZER_2_PIN = GPIO" + String(BUZZER_2_PIN));
    Logger::info("📍 SERVO_PIN = GPIO" + String(OBSTACLE_SERVO_PIN));
    Logger::info("📍 LED_STATUS = GPIO" + String(LED_STATUS));
    Logger::info("");
    
    // ===== INIT UART SIM808 =====
    Logger::info("📡 [SETUP] Init UART SIM808...");
    SIM808.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);
    Logger::info("✅ [SETUP] UART SIM808 OK");

    // ===== INIT BLE =====
    Logger::info("📱 [SETUP] Configuration BLE...");
    bluetooth.setDeviceName("OPEN EYES");
    Logger::info("✅ [SETUP] BLE nom: OPEN EYES");

    // ===== CONFIG BOUTON SOS =====
    Logger::info("🔘 [SETUP] Configuration bouton SOS...");
    pinMode(BOUTON_SOS, INPUT_PULLUP);
    Logger::info("✅ [SETUP] Bouton SOS : GPIO" + String(BOUTON_SOS) + " (PULLUP)");

    // ===== CONFIG LED =====
    Logger::info("💡 [SETUP] Configuration LED Status...");
    pinMode(LED_STATUS, OUTPUT);
    digitalWrite(LED_STATUS, LOW);
    Logger::info("✅ [SETUP] LED Status : GPIO" + String(LED_STATUS));
    
    // Test LED
    Logger::info("🧪 [SETUP] Test LED Status...");
    for (int i = 0; i < 2; i++) {
        digitalWrite(LED_STATUS, HIGH);
        Logger::info("💡 [TEST] LED ON");
        delay(200);
        digitalWrite(LED_STATUS, LOW);
        Logger::info("💡 [TEST] LED OFF");
        delay(200);
    }
    Logger::info("✅ [SETUP] Test LED terminé");

    // ===== CONFIG BUZZERS =====
    Logger::info("🔊 [SETUP] Configuration buzzers actifs...");
    Logger::info("🔊 [SETUP] BUZZER 1 : GPIO" + String(BUZZER_1_PIN));
    Logger::info("🔊 [SETUP] BUZZER 2 : GPIO" + String(BUZZER_2_PIN));
    pinMode(BUZZER_1_PIN, OUTPUT);
    pinMode(BUZZER_2_PIN, OUTPUT);
    digitalWrite(BUZZER_1_PIN, LOW);
    digitalWrite(BUZZER_2_PIN, LOW);
    Logger::info("✅ [SETUP] Buzzers configurés");

    // ===== LIER IMU AU BLUETOOTH =====
    bluetooth.setIMUReference(&imu);

    // ===== INIT MODULES =====
    Logger::info("");
    Logger::info("🚀 [SETUP] Initialisation modules...");
    Logger::info("════════════════════════════════════════");
    
    for (int i = 0; i < 5; i++) {
        Logger::info("");
        Logger::info("🔄 [SETUP] Init module " + String(i+1) + "/5...");
        
        unsigned long startTime = millis();
        modules[i]->init();
        unsigned long initDuration = millis() - startTime;
        
        if (initDuration > 5000) {
            Logger::warn("⚠️ [SETUP] Module " + String(i+1) + " timeout (" + String(initDuration) + "ms)");
        }
        
        if (modules[i]->isReady()) {
            Logger::info("✅ [SETUP] Module " + String(i+1) + " prêt");
        } else {
            Logger::error("❌ [SETUP] Module " + String(i+1) + " ÉCHEC !");
        }
    }
    
    Logger::info("");
    Logger::info("════════════════════════════════════════");
    Logger::info("✅ [SETUP] Tous les modules initialisés");

    // ===== TEST DÉMARRAGE BUZZERS =====
    Logger::info("");
    Logger::info("🔊 [SETUP] Test bips démarrage...");
    for (int i = 0; i < 2; i++) {
        Logger::info("🔊 [TEST] Bip " + String(i+1) + "/2");
        digitalWrite(BUZZER_1_PIN, HIGH);
        delay(150);
        digitalWrite(BUZZER_1_PIN, LOW);
        delay(150);
    }
    Logger::info("✅ [SETUP] Test bips terminé");
    
    // ===== RÉCAP FINAL =====
    Logger::info("");
    Logger::info("╔════════════════════════════════════════╗");
    Logger::info("║      SYSTÈME OPÉRATIONNEL              ║");
    Logger::info("╚════════════════════════════════════════╝");
    Logger::info("📱 Nom BLE: OPEN EYES");
    Logger::info("📞 Contacts: " + String(gsm.getNombreContacts()) + "/" + String(MAX_CONTACTS));
    Logger::info("");
    Logger::info("📍 CONFIGURATION HARDWARE:");
    Logger::info("   • Buzzer 1 (Obstacles) : GPIO" + String(BUZZER_1_PIN));
    Logger::info("   • Buzzer 2 (Eau)       : GPIO" + String(BUZZER_2_PIN));
    Logger::info("   • Servo moteur         : GPIO" + String(OBSTACLE_SERVO_PIN));
    Logger::info("   • Capteur eau          : GPIO" + String(WATER_SENSOR_PIN));
    Logger::info("   • Moteur vibrant       : GPIO" + String(OBSTACLE_VIBRATOR_PIN));
    Logger::info("   • LED Status           : GPIO" + String(LED_STATUS));
    Logger::info("");
    Logger::info("🎮 COMMANDES SMS ADMIN:");
    Logger::info("   • ADMIN:ADD:+237XXX - Ajouter contact");
    Logger::info("   • ADMIN:DEL:+237XXX - Supprimer contact");
    Logger::info("   • ADMIN:LIST        - Liste contacts");
    Logger::info("   • ADMIN:LOC         - Position GPS");
    Logger::info("   • ADMIN:HELP        - Aide");
    Logger::info("");
    Logger::info("🔘 BOUTON SOS:");
    Logger::info("   • 1 clic court      = 'Tout va bien'");
    Logger::info("   • Appui long (2s)   = Alerte SOS");
    Logger::info("");
    Logger::info("════════════════════════════════════════");
    Logger::info("🟢 Système démarré - Alimentation par switch");
    Logger::info("════════════════════════════════════════");
    Logger::info("");
    
    // Initialiser les timestamps
    unsigned long now = millis();
    lastStatusLog = now;
    lastGPSCheck = now;
    lastObstacleBLESend = now;
    lastWaterBLESend = now;
    lastDistanceLog = now;
}

// =======================================================
// LOOP
// =======================================================
void loop() {
    esp_task_wdt_reset();
    
    static unsigned long loopCount = 0;
    loopCount++;
    
    #ifdef DEBUG_MODE
    if (loopCount % 1000 == 0) {
        Logger::info("♻️ [LOOP] Cycle #" + String(loopCount/1000) + "k");
    }
    #endif

    // ===== UPDATE MODULES =====
    for (IModule* m : modules) {
        if (m->isReady()) {
            m->update();
        }
    }

    // ===== GESTION BOUTON SOS =====
    detecterPatternBouton();

    unsigned long currentTime = millis();

    // ===== STATUS PÉRIODIQUE =====
    if (currentTime - lastStatusLog >= STATUS_INTERVAL) {
        Logger::info("════════════════════════════════════════");
        Logger::info("📊 STATUT SYSTÈME (uptime=" + String(currentTime/1000) + "s)");
        Logger::info("════════════════════════════════════════");
        Logger::info("📱 BLE Connecté     : " + String(bluetooth.isClientConnected() ? "✅ OUI" : "❌ NON"));
        Logger::info("🛰️ GPS Prêt         : " + String(gps.isReady() ? "✅ OUI" : "❌ NON"));
        Logger::info("📡 GSM Prêt         : " + String(gsm.isReady() ? "✅ OUI" : "❌ NON"));
        Logger::info("👁️ Détecteur Prêt   : " + String(detector.isReady() ? "✅ OUI" : "❌ NON"));
        Logger::info("🧭 IMU Prêt         : " + String(imu.isReady() ? "✅ OUI" : "❌ NON"));
        Logger::info("📞 Contacts EEPROM  : " + String(gsm.getNombreContacts()) + "/" + String(MAX_CONTACTS));
        
        WaterSensorData waterData = detector.getWaterSensorData();
        Logger::info("💧 Capteur Eau      : " + String(waterData.humidityLevel) + "% (raw=" + String(waterData.rawData) + ")");
        
        ObstacleData obstData = detector.getObstacleData();
        Logger::info("📏 Obstacles        : Haut=" + String(obstData.upper) + "cm Bas=" + String(obstData.lower) + "cm");
        Logger::info("🔄 Servo angle      : " + String(obstData.servoAngle) + "°");
        
        Logger::info("════════════════════════════════════════");
        
        lastStatusLog = currentTime;
    }

    // ===== LOGS DISTANCE =====
    if (currentTime - lastDistanceLog >= DISTANCE_LOG_INTERVAL) {
        ObstacleData obstData = detector.getObstacleData();
        
        if (obstData.upper > 0 && obstData.upper < 300) {
            Logger::info("🔍 [HAUT] Distance=" + String(obstData.upper) + "cm");
        }
        
        if (obstData.lower > 0 && obstData.lower < 300) {
            String dir = (obstData.servoAngle < 60) ? "GAUCHE" :
                         (obstData.servoAngle > 120) ? "DROITE" : "CENTRE";
            Logger::info("🔍 [BAS] Angle=" + String(obstData.servoAngle) + "° Distance=" + 
                         String(obstData.lower) + "cm [" + dir + "]");
        }
        
        lastDistanceLog = currentTime;
    }

    // ===== GPS CHECK =====
    if (currentTime - lastGPSCheck >= GPS_CHECK_INTERVAL) {
        GPSData gpsData = gps.getGPSData();
        
        if (gpsData.isValid) {
            Logger::info("🛰️ [GPS] Lat=" + String(gpsData.latitude, 6) + 
                         " Lon=" + String(gpsData.longitude, 6) +
                         " Sats=" + String(gpsData.satellitesCount) +
                         " Fix=" + gpsData.fixType);
        } else {
            Logger::warn("⚠️ [GPS] Pas de fix (Sats=" + String(gpsData.satellitesCount) + 
                         " Fix=" + gpsData.fixType + ")");
        }
        
        lastGPSCheck = currentTime;
    }

    // ===== BLE OBSTACLES =====
    if (currentTime - lastObstacleBLESend >= OBSTACLE_BLE_UPDATE_INTERVAL) {
        if (bluetooth.isClientConnected()) {
            ObstacleData obstacleData = detector.getObstacleData();
            bluetooth.sendObstacleData(obstacleData);
            #ifdef DEBUG_MODE
            Logger::info("📤 [BLE] Obstacles envoyés");
            #endif
        }
        lastObstacleBLESend = currentTime;
    }

    // ===== BLE EAU =====
    if (currentTime - lastWaterBLESend >= WATER_BLE_UPDATE_INTERVAL) {
        if (bluetooth.isClientConnected()) {
            WaterSensorData waterData = detector.getWaterSensorData();
            bluetooth.sendWaterSensorData(waterData);
            #ifdef DEBUG_MODE
            Logger::info("📤 [BLE] Eau envoyée");
            #endif
        }
        lastWaterBLESend = currentTime;
    }

    // ===== LED HEARTBEAT =====
    static unsigned long lastBlink = 0;
    static bool ledState = false;
    
    if (currentTime - lastBlink >= 1000) {
        ledState = !ledState;
        digitalWrite(LED_STATUS, ledState);
        #ifdef DEBUG_MODE
        Logger::info("💡 [LED] " + String(ledState ? "ON" : "OFF"));
        #endif
        lastBlink = currentTime;
    }
}