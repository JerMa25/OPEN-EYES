#include <esp_task_wdt.h>
#include "Config.h"
#include "Logger.h"
#include "GPSTracker.h"
#include "GSMEmergency.h"
#include "BluetoothManager.h"
#include "ObstacleDetector.h"
#include "GPSAssistance.h"

// Instances modules
HardwareSerial sim808Serial(2);
GPSTracker gpsTracker(sim808Serial);
GSMEmergency gsmModule(sim808Serial, gpsTracker);
ObstacleDetector obstacleDetector;
GPSAssistance imuModule;
BluetoothManager bleManager(gpsTracker, imuModule);

// Variables bouton SOS
unsigned long dernierAppui = 0;
bool appuiLong = false;
unsigned long debutAppui = 0;

void setup() {
    Serial.begin(DEBUG_BAUDRATE);
    Logger::info("╔════════════════════════════════════════╗");
    Logger::info("║   CANNE INTELLIGENTE - DEBUG MODE     ║");
    Logger::info("╚════════════════════════════════════════╝");
    Logger::info("");
    
    // ✅ CONFIGURATION WATCHDOG - 30 SECONDES
    Logger::info("🛡️ [SETUP] Configuration Watchdog Timer...");
    esp_task_wdt_config_t wdt_config = {
        .timeout_ms = 30000,  // ← 30 secondes
        .idle_core_mask = 0,
        .trigger_panic = true
    };
    esp_task_wdt_init(&wdt_config);
    esp_task_wdt_add(NULL);
    Logger::info("✅ [SETUP] Watchdog configuré (30s)");
    Logger::info("");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Configuration pins
    Logger::info("🔧 [SETUP] Test configuration pins...");
    Logger::info("📍 BUZZER_1_PIN = GPIO" + String(BUZZER_1_PIN));
    Logger::info("📍 BUZZER_2_PIN = GPIO" + String(BUZZER_2_PIN));
    Logger::info("📍 SERVO_PIN = GPIO" + String(OBSTACLE_SERVO_PIN));
    Logger::info("📍 LED_STATUS = GPIO" + String(LED_STATUS));
    Logger::info("");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Init UART SIM808
    Logger::info("📡 [SETUP] Init UART SIM808...");
    sim808Serial.begin(SIM808_BAUDRATE, SERIAL_8N1, SIM808_RX, SIM808_TX);
    delay(2000);
    Logger::info("✅ [SETUP] UART SIM808 OK");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Configuration BLE
    Logger::info("📱 [SETUP] Configuration BLE...");
    bleManager.setDeviceName("OPEN EYES");
    Logger::info("✅ [SETUP] BLE nom: OPEN EYES");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Configuration bouton SOS
    Logger::info("🔘 [SETUP] Configuration bouton SOS...");
    pinMode(BOUTON_SOS, INPUT_PULLUP);
    Logger::info("✅ [SETUP] Bouton SOS : GPIO" + String(BOUTON_SOS) + " (PULLUP)");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Configuration LED
    Logger::info("💡 [SETUP] Configuration LED Status...");
    pinMode(LED_STATUS, OUTPUT);
    Logger::info("✅ [SETUP] LED Status : GPIO" + String(LED_STATUS));
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Test LED
    Logger::info("🧪 [SETUP] Test LED Status...");
    for (int i = 0; i < 2; i++) {
        Logger::info("💡 [TEST] LED ON");
        digitalWrite(LED_STATUS, HIGH);
        delay(200);
        Logger::info("💡 [TEST] LED OFF");
        digitalWrite(LED_STATUS, LOW);
        delay(200);
        
        // ✅ RESET WATCHDOG après chaque boucle
        esp_task_wdt_reset();
    }
    Logger::info("✅ [SETUP] Test LED terminé");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Configuration buzzers
    Logger::info("🔊 [SETUP] Configuration buzzers actifs...");
    pinMode(BUZZER_1_PIN, OUTPUT);
    pinMode(BUZZER_2_PIN, OUTPUT);
    digitalWrite(BUZZER_1_PIN, LOW);
    digitalWrite(BUZZER_2_PIN, LOW);
    Logger::info("🔊 [SETUP] BUZZER 1 : GPIO" + String(BUZZER_1_PIN));
    Logger::info("🔊 [SETUP] BUZZER 2 : GPIO" + String(BUZZER_2_PIN));
    Logger::info("✅ [SETUP] Buzzers configurés");
    Logger::info("");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Initialisation modules
    Logger::info("🚀 [SETUP] Initialisation modules...");
    Logger::info("════════════════════════════════════════");
    Logger::info("");
    
    // Module 1: GPS
    Logger::info("🔄 [SETUP] Init module 1/5...");
    gpsTracker.init();
    Logger::info("✅ [SETUP] Module 1 prêt");
    Logger::info("");
    esp_task_wdt_reset();  // ✅
    
    // Module 2: GSM
    Logger::info("🔄 [SETUP] Init module 2/5...");
    gsmModule.init();
    Logger::info("✅ [SETUP] Module 2 prêt");
    Logger::info("");
    esp_task_wdt_reset();  // ✅
    
    // Module 3: Obstacles
    Logger::info("🔄 [SETUP] Init module 3/5...");
    obstacleDetector.init();
    Logger::info("✅ [SETUP] Module 3 prêt");
    Logger::info("");
    esp_task_wdt_reset();  // ✅
    
    // Module 4: IMU
    Logger::info("🔄 [SETUP] Init module 4/5...");
    imuModule.init();
    Logger::info("✅ [SETUP] Module 4 prêt");
    Logger::info("");
    esp_task_wdt_reset();  // ✅
    
    // Module 5: BLE
    Logger::info("🔄 [SETUP] Init module 5/5...");
    bleManager.init();
    Logger::info("✅ [SETUP] Module 5 prêt");
    Logger::info("");
    esp_task_wdt_reset();  // ✅
    
    Logger::info("════════════════════════════════════════");
    Logger::info("✅ [SETUP] Tous les modules initialisés");
    Logger::info("");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Test bips démarrage
    Logger::info("🔊 [SETUP] Test bips démarrage...");
    for (int i = 0; i < 2; i++) {
        Logger::info("🔊 [TEST] Bip " + String(i + 1) + "/2");
        digitalWrite(BUZZER_1_PIN, HIGH);
        delay(100);
        digitalWrite(BUZZER_1_PIN, LOW);
        delay(200);
        
        // ✅ RESET WATCHDOG après chaque bip
        esp_task_wdt_reset();
    }
    Logger::info("✅ [SETUP] Test bips terminé");
    Logger::info("");
    
    // ✅ RESET WATCHDOG
    esp_task_wdt_reset();
    
    // Affichage final
    Logger::info("╔════════════════════════════════════════╗");
    Logger::info("║      SYSTÈME OPÉRATIONNEL              ║");
    Logger::info("╚════════════════════════════════════════╝");
    Logger::info("📱 Nom BLE: OPEN EYES");
    Logger::info("📞 Contacts: " + String(gsmModule.getNombreContacts()) + "/5");
    Logger::info("");
    Logger::info("📍 CONFIGURATION HARDWARE:");
    Logger::info("   • Buzzer 1 (Obstacles) : GPIO" + String(BUZZER_1_PIN));
    Logger::info("   • Buzzer 2 (Eau)       : GPIO" + String(BUZZER_2_PIN));
    Logger::info("   • Servo moteur         : GPIO" + String(OBSTACLE_SERVO_PIN));
    Logger::info("   • Capteur eau          : GPIO" + String(WATER_SENSOR_PIN));
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
    
    // ✅ RESET WATCHDOG FINAL
    esp_task_wdt_reset();
}

void loop() {
    // ✅ RESET WATCHDOG AU DÉBUT DE LA LOOP
    esp_task_wdt_reset();
    
    static unsigned long lastLedTime = 0;
    static bool ledState = false;
    unsigned long currentTime = millis();
    
    // Clignotement LED toutes les 10 secondes
    if (currentTime - lastLedTime >= 10000) {
        ledState = !ledState;
        digitalWrite(LED_STATUS, ledState);
        Logger::info(String(currentTime / 1000) + "s.[INFO] 💡 [LED] " + 
                    (ledState ? "ON" : "OFF"));
        lastLedTime = currentTime;
    }
    
    // Mise à jour modules
    gpsTracker.update();
    gsmModule.update();
    obstacleDetector.update();
    imuModule.update();
    bleManager.update();
    
    // Gestion bouton SOS
    gererBoutonSOS();
    
    // ✅ RESET WATCHDOG À LA FIN DE LA LOOP
    esp_task_wdt_reset();
}

void gererBoutonSOS() {
    int etatBouton = digitalRead(BOUTON_SOS);
    unsigned long maintenant = millis();
    
    //Début d'appui
    if (etatBouton == LOW && debutAppui == 0) {
        debutAppui = maintenant;
        appuiLong = false;
        Logger::info("[BTN] Appui détecté (début)");
    }
            unsigned long duree = maintenant - debutAppui;


    //appui long
    if (etatBouton == LOW && debutAppui > 0) {
        static unsigned long lastTickLog = 0;
        if (maintenant - lastTickLog > 500) {
            lastTickLog = maintenant;
            Logger::info("[BTN] Maintien..." + String(duree) + "ms");
        }
    }
    
    if (duree >= DELAI_APPUI_LONG && !appuiLong) {
        Logger::warn("🆘 [BTN] APPUI LONG DÉTECTÉ (" + String(duree) + "ms) -> sendSOS()");
        gsmModule.sendSOS();
        Logger::warn("🆘 [BTN] sendSOS() déclenché (attente résultat SIM808 dans logs)");
        appuiLong = true;
    }
    
    if (etatBouton == HIGH && debutAppui > 0) {
        unsigned long dureeAppui = maintenant - debutAppui;
        
        Logger::info("[BTN] Relâchement (" + String(dureeAppui) + "ms)");

        if (dureeAppui < DELAI_APPUI_LONG && !appuiLong) {
            Logger::info("✅ [BTN] CLIC COURT - Tout va bien");
        }
        
        debutAppui = 0;
        appuiLong = false;
    }
}