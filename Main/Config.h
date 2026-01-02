#ifndef CONFIG_H
#define CONFIG_H

// ===== ACTIVATION DES LOGS =====
#define LOG_ENABLED true // true = les logs sont activés, false = désactivés

// ===== PINS DU MODULE SIM808 =====
#define SIM808_RX         17  // Pin de réception (RX) pour la communication avec SIM808
#define SIM808_TX         16  // Pin de transmission (TX) pour la communication avec SIM808
#define SIM808_PWR        25  // Pin pour contrôler l'alimentation du SIM808
  
// ===== BOUTONS =====
#define BOUTON_SOS        13   // Pin du bouton d'urgence SOS
#define BOUTON_ONOFF      12   // Pin du bouton ON/OFF

// ===== LEDS =====
#define LED_POWER         14   // LED verte power (système ON/OFF)
#define LED_STATUS        27   // LED rouge status

// ===== PARAMÈTRES GPS =====
#define GPS_UPDATE_INTERVAL   5000   // Intervalle de mise à jour GPS (5 secondes)
#define GPS_TIMEOUT           30000  // Timeout GPS (30 secondes)
#define DELAI_ENTRE_SMS       60000  // Délai minimum entre deux SMS (60 secondes)

// ===== NUMÉROS DE TÉLÉPHONE =====
#define NUMERO_URGENCE "+237XXXXXXXXX"  // Numéro d'urgence principal
#define NUMERO_PROCHE  "+237YYYYYYYYY"  // Numéro d'un proche (optionnel)
#define NUMERO_ADMIN   "+237691501793"  // Numéro de l'administrateur qui peut gérer les contacts

// ===== PARAMÈTRES DE COMMUNICATION SÉRIE =====
#define DEBUG_BAUDRATE 115200  // Vitesse de communication pour le debug USB
#define SIM808_BAUDRATE 115200   // Vitesse de communication avec le SIM808

// ===== CONFIGURATION EEPROM =====
#define EEPROM_SIZE 200              // Taille totale de l'EEPROM à utiliser
#define EEPROM_INIT_MARKER 0xAB      // Marqueur pour vérifier si l'EEPROM est initialisée
#define EEPROM_START_ADDR 10         // Adresse de début pour les contacts (après le marqueur)
#define MAX_CONTACTS 5               // Nombre maximum de contacts d'urgence
#define CONTACT_LENGTH 20            // Longueur maximale d'un numéro de téléphone

// ===== GESTION DU BOUTON SOS - PATTERNS =====
#define DELAI_DOUBLE_CLIC 500        // Délai pour détecter un double-clic (ms)
#define DELAI_APPUI_LONG 2000        // Délai pour détecter un appui long (ms)

// ===== DÉTECTION D'OBSTACLES =====
#define DISTANCE_ALERTE 50           // Distance d'alerte en cm
#define DISTANCE_DANGER 20           // Distance de danger en cm

// ============================================================
// ===== OBSTACLE DETECTOR - PINS =====
// ============================================================
#define OBSTACLE_TRIG_HIGH    5      // HC-SR04 HAUT - TRIG
#define OBSTACLE_ECHO_HIGH    18     // HC-SR04 HAUT - ECHO
#define OBSTACLE_TRIG_LOW     19     // HC-SR04 BAS - TRIG
#define OBSTACLE_ECHO_LOW     21     // HC-SR04 BAS - ECHO
#define OBSTACLE_SERVO_PIN    32     // Servomoteur

// ===== BUZZERS (2 SYNCHRONISÉS) =====
#define OBSTACLE_BUZZER_PIN_1   4    // Buzzer principal (GPIO4)
#define OBSTACLE_BUZZER_PIN_2   26   // Buzzer secondaire (GPIO26) - Volume doublé

#define OBSTACLE_VIBRATOR_PIN 15     // Moteur vibrant

// ===== CAPTEUR D'EAU =====
#define WATER_SENSOR_PIN      34     // Capteur d'eau (ADC1 - GPIO34)

// ===== SEUILS CAPTEUR D'EAU =====
#define WATER_SEUIL_SEC           300   // < 300 : Pas d'eau
#define WATER_SEUIL_HUMIDE        500   // 300-500 : Humidité détectée
#define WATER_SEUIL_INONDATION    700   // > 500 : Eau importante

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
#define OBSTACLE_BUZZER_CHANNEL_1   0     // Canal PWM buzzer 1
#define OBSTACLE_BUZZER_CHANNEL_2   1     // Canal PWM buzzer 2
#define OBSTACLE_BUZZER_RES         8     // Résolution PWM (8 bits)

// ===== OBSTACLE DETECTOR - FRÉQUENCES SONORES =====
#define OBSTACLE_FREQ_HAUT          2000   // Fréquence obstacle HAUT (Hz)
#define OBSTACLE_FREQ_BAS_GAUCHE    1000   // Fréquence obstacle BAS GAUCHE (Hz)
#define OBSTACLE_FREQ_BAS_CENTRE    1200   // Fréquence obstacle BAS CENTRE (Hz)
#define OBSTACLE_FREQ_BAS_DROITE    1500   // Fréquence obstacle BAS DROITE (Hz)
#define OBSTACLE_FREQ_DEMARRAGE     1500   // Fréquence bips démarrage (Hz)

// ===== MÉLODIES DIFFÉRENCIÉES =====
// Obstacle avant : Bips progressifs
#define MELODIE_OBSTACLE_FREQ_MIN   500    // Fréquence minimale (loin)
#define MELODIE_OBSTACLE_FREQ_MAX   4000   // Fréquence maximale (proche)

// Trou/Escalier : 3 bips rapides
#define MELODIE_TROU_FREQ           3000   // Fréquence fixe
#define MELODIE_TROU_BIPS           3      // Nombre de bips
#define MELODIE_TROU_DUREE          100    // Durée bip (ms)
#define MELODIE_TROU_PAUSE          100    // Pause entre bips (ms)

// Eau : Mélodie descendante (goutte d'eau)
#define MELODIE_EAU_FREQ_1          1500   // Note 1 (aiguë)
#define MELODIE_EAU_FREQ_2          1000   // Note 2 (moyenne)
#define MELODIE_EAU_FREQ_3          800    // Note 3 (grave)
#define MELODIE_EAU_DUREE_NOTE      200    // Durée note (ms)
#define MELODIE_EAU_PAUSE           100    // Pause entre notes (ms)

// SOS : Sirène alternée
#define MELODIE_SOS_FREQ_BAS        800    // Fréquence basse
#define MELODIE_SOS_FREQ_HAUT       1500   // Fréquence haute
#define MELODIE_SOS_DUREE           300    // Durée alternance (ms)
#define MELODIE_SOS_CYCLES          3      // Nombre de cycles

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

// MPU9250
#define MPU_ADDR 0x68
#define REG_ACCEL 0x3B
#define REG_PWR   0x6B

#define MPU_SCL_PIN 22
#define MPU_SDA_PIN 23

#endif