#ifndef CONFIG_H
#define CONFIG_H

// ===== ACTIVATION DES LOGS =====
#define LOG_ENABLED true
#define DEBUG_MODE false  // ✅ NOUVEAU : Mode debug ultra-verbeux

// ===== PINS DU MODULE SIM808 =====
#define SIM808_RX         17
#define SIM808_TX         16
#define SIM808_PWR        25
  
// ===== BOUTONS =====
#define BOUTON_SOS        13
#define BOUTON_ONOFF      12

// ===== LEDS =====
#define LED_POWER         14
#define LED_STATUS        27

// ===== PARAMÈTRES GPS =====
#define GPS_UPDATE_INTERVAL   5000
#define GPS_TIMEOUT           30000
#define DELAI_ENTRE_SMS       60000

// ===== NUMÉROS DE TÉLÉPHONE =====
#define NUMERO_URGENCE "+237XXXXXXXXX"
#define NUMERO_PROCHE  "+237YYYYYYYYY"
#define NUMERO_ADMIN   "+237670000000"

// ===== PARAMÈTRES DE COMMUNICATION SÉRIE =====
#define DEBUG_BAUDRATE 9600
#define SIM808_BAUDRATE 9600

// ===== CONFIGURATION EEPROM =====
#define EEPROM_SIZE 200
#define EEPROM_INIT_MARKER 0xAB
#define EEPROM_START_ADDR 10
#define MAX_CONTACTS 5
#define CONTACT_LENGTH 20

// ===== GESTION DU BOUTON SOS - PATTERNS =====
#define DELAI_DOUBLE_CLIC 500
#define DELAI_APPUI_LONG 2000

// ===== DÉTECTION D'OBSTACLES =====
#define DISTANCE_ALERTE 50
#define DISTANCE_DANGER 20

// ============================================================
// ===== OBSTACLE DETECTOR - PINS =====
// ============================================================
#define OBSTACLE_TRIG_HIGH    19
#define OBSTACLE_ECHO_HIGH    21
#define OBSTACLE_TRIG_LOW     5
#define OBSTACLE_ECHO_LOW     18
#define OBSTACLE_SERVO_PIN    23

// ===== BUZZERS =====
#define BUZZER_1_PIN          4
#define BUZZER_2_PIN          26
#define OBSTACLE_VIBRATOR_PIN 15
#define WATER_SENSOR_PIN      34

// ===== BUZZERS - PARAMÈTRES PROGRESSIFS =====
// #define BUZZER_DISTANCE_SILENCE  120  // > 120 cm : silence
// #define BUZZER_DISTANCE_LENT     60   // 60-120 cm : bip lent
// #define BUZZER_DISTANCE_MOYEN    30   // 30-60 cm : bip moyen
// #define BUZZER_DISTANCE_RAPIDE   12   // 12-30 cm : bip rapide
//                                       // < 12 cm : son continu

// #define BUZZER_INTERVAL_LENT     1000  // 1 seconde entre bips
// #define BUZZER_INTERVAL_MOYEN    500   // 0.5 seconde
// #define BUZZER_INTERVAL_RAPIDE   200   // 0.2 seconde

#define BUZZER_DISTANCE_SEUIL    30   // ⚠️ Bip si distance ≤ 30cm
#define BUZZER_INTERVAL          500  // ⚠️ 1 bip toutes les 0.5 secondes
#define BUZZER_BIP_DURATION      100   // Durée d'un bip (ms)
#define BUZZER_DOUBLE_BIP_GAP    80    // Pause entre 2 bips du double-bip

// ===== OBSTACLE DETECTOR - PARAMÈTRES DÉTECTION =====
#define OBSTACLE_DIST_SECURITE_HAUT  150
#define OBSTACLE_DIST_SECURITE_BAS   100

// ===== OBSTACLE DETECTOR - PARAMÈTRES SERVO =====
#define OBSTACLE_ANGLE_MIN      0
#define OBSTACLE_ANGLE_MAX      180
#define OBSTACLE_ANGLE_STEP     30
#define OBSTACLE_SERVO_DELAY    30

// ===== OBSTACLE DETECTOR - FILTRAGE =====
#define OBSTACLE_BUFFER_SIZE        3
#define OBSTACLE_SEUIL_VARIATION    40
#define OBSTACLE_ALERT_COOLDOWN     1500
#define OBSTACLE_MAX_DISTANCE       400  // ✅ AJOUTER CETTE LIGNE
#define OBSTACLE_MIN_DISTANCE       2    // ✅ AJOUTER CETTE LIGNE

// ===== BUZZER PWM CHANNELS =====
#define BUZZER_1_CHANNEL        0
#define BUZZER_1_RES            8
#define BUZZER_2_CHANNEL        1
#define BUZZER_2_RES            8

// ===== OBSTACLE DETECTOR - FRÉQUENCES SONORES =====
#define OBSTACLE_FREQ_HAUT          2000
#define OBSTACLE_FREQ_BAS_GAUCHE    1000
#define OBSTACLE_FREQ_BAS_CENTRE    1200
#define OBSTACLE_FREQ_BAS_DROITE    1500
#define OBSTACLE_FREQ_DEMARRAGE     1500

// ===== FRÉQUENCES SONORES - EAU (BUZZER 2) =====
#define WATER_FREQ_ALERT            1800
#define WATER_FREQ_WARNING          2200

// ===== OBSTACLE DETECTOR - VIBRATION HAPTIQUE =====
#define OBSTACLE_VIBRATION_ENABLED       false
#define OBSTACLE_VIBRATION_INTENSITY     255
#define OBSTACLE_VIBRATION_PATTERN_SHORT 100
#define OBSTACLE_VIBRATION_PATTERN_LONG  300
#define OBSTACLE_VIBRATION_PAUSE         50

// ===== CAPTEUR D'EAU - PARAMÈTRES =====
#define WATER_SENSOR_ENABLED         false
#define WATER_THRESHOLD_LOW          1000
#define WATER_THRESHOLD_HIGH         3000
#define WATER_CHECK_INTERVAL         1000
#define WATER_ALERT_COOLDOWN         5000

// ===== OBSTACLE DETECTOR - BLUETOOTH =====
#define OBSTACLE_BLE_UPDATE_INTERVAL  500
#define WATER_BLE_UPDATE_INTERVAL     1000

// ===== OBSTACLE DETECTOR - GÉNÉRAL =====
#define OBSTACLE_CHECK_INTERVAL 50

// ===== SEUILS DE NAVIGATION =====
#define ARRIVAL_DISTANCE_METERS 10.0
#define TURN_THRESHOLD_DEG      15.0

#define DEG_TO_RAD 0.01745329251
#define RAD_TO_DEG 57.2957795131
#define EARTH_RADIUS 6371000.0

// MPU9250
#define MPU_ADDR 0x68
#define REG_ACCEL 0x3B
#define REG_PWR   0x6B
#define MPU_SCL_PIN 22
#define MPU_SDA_PIN 35

#endif