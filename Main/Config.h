#ifndef CONFIG_H
#define CONFIG_H

// ===== ACTIVATION DES LOGS =====
#define LOG_ENABLED true

// ===== PINS DU MODULE SIM808 =====
#define SIM808_RX         17
#define SIM808_TX         16
#define SIM808_PWR        25

// ===== BOUTONS ET LEDS =====
#define BOUTON_SOS        13
#define LED_STATUS        27

// ===== PARAMÈTRES GPS =====
#define GPS_UPDATE_INTERVAL   5000
#define GPS_TIMEOUT           30000
#define DELAI_ENTRE_SMS       60000

// ===== NUMÉROS DE TÉLÉPHONE =====
#define NUMERO_URGENCE "+237XXXXXXXXX"
#define NUMERO_PROCHE  "+237YYYYYYYYY"

// ===== PARAMÈTRES DE COMMUNICATION SÉRIE =====
#define DEBUG_BAUDRATE 115200
#define SIM808_BAUDRATE 9600

// ============================================================
// ===== OBSTACLE DETECTOR - PINS =====
// ============================================================
#define OBSTACLE_TRIG_HIGH    5    // HC-SR04 HAUT - TRIG
#define OBSTACLE_ECHO_HIGH    18    // HC-SR04 HAUT - ECHO
#define OBSTACLE_TRIG_LOW     19     // HC-SR04 BAS - TRIG
#define OBSTACLE_ECHO_LOW     21     // HC-SR04 BAS - ECHO
#define OBSTACLE_SERVO_PIN    32    // Servomoteur
#define OBSTACLE_BUZZER_PIN   27    // Buzzer
#define OBSTACLE_VIBRATOR_PIN 26    // Moteur vibrant

// ===== OBSTACLE DETECTOR - PARAMÈTRES DÉTECTION =====
#define OBSTACLE_DIST_SECURITE_HAUT  150   // Distance sécurité obstacle haut (cm)
#define OBSTACLE_DIST_SECURITE_BAS   100   // Distance sécurité obstacle bas (cm)

// ===== OBSTACLE DETECTOR - PARAMÈTRES SERVO =====
#define OBSTACLE_ANGLE_MIN      0      // Angle minimum servo
#define OBSTACLE_ANGLE_MAX      180    // Angle maximum servo
#define OBSTACLE_ANGLE_STEP     15     // Pas de rotation servo
#define OBSTACLE_SERVO_DELAY    120    // Délai stabilisation servo (ms)

// ===== OBSTACLE DETECTOR - FILTRAGE =====
#define OBSTACLE_BUFFER_SIZE        5      // Taille buffer filtrage médian
#define OBSTACLE_SEUIL_VARIATION    40     // Seuil rejet variations (cm)
#define OBSTACLE_ALERT_COOLDOWN     800    // Délai minimum entre alertes (ms)

// ===== OBSTACLE DETECTOR - BUZZER PWM =====
#define OBSTACLE_BUZZER_CHANNEL           // Canal PWM buzzer
#define OBSTACLE_BUZZER_RES         8      // Résolution PWM (8 bits)

// ===== OBSTACLE DETECTOR - FRÉQUENCES SONORES =====
#define OBSTACLE_FREQ_HAUT          2000   // Fréquence obstacle HAUT (Hz)
#define OBSTACLE_FREQ_BAS_GAUCHE    1000   // Fréquence obstacle BAS GAUCHE (Hz)
#define OBSTACLE_FREQ_BAS_CENTRE    1200   // Fréquence obstacle BAS CENTRE (Hz)
#define OBSTACLE_FREQ_BAS_DROITE    1500   // Fréquence obstacle BAS DROITE (Hz)
#define OBSTACLE_FREQ_DEMARRAGE     1500   // Fréquence bips démarrage (Hz)

// ===== OBSTACLE DETECTOR - VIBRATION HAPTIQUE =====
#define OBSTACLE_VIBRATION_ENABLED       true   // Activer/désactiver vibration
#define OBSTACLE_VIBRATION_INTENSITY     255    // Intensité PWM (0-255)
#define OBSTACLE_VIBRATION_PATTERN_SHORT 100    // Vibration courte (ms)
#define OBSTACLE_VIBRATION_PATTERN_LONG  300    // Vibration longue (ms)
#define OBSTACLE_VIBRATION_PAUSE         50     // Pause entre vibrations (ms)

// ===== OBSTACLE DETECTOR - BLUETOOTH =====
#define OBSTACLE_BLE_UPDATE_INTERVAL  500  // Intervalle envoi BLE (ms)

// ===== OBSTACLE DETECTOR - GÉNÉRAL =====
#define OBSTACLE_CHECK_INTERVAL 40

// ===== SEUILS DE NAVIGATION =====
#define ARRIVAL_DISTANCE_METERS 10.0
#define TURN_THRESHOLD_DEG      15.0

#define DEG_TO_RAD 0.01745329251
#define RAD_TO_DEG 57.2957795131
#define EARTH_RADIUS 6371000.0

#endif