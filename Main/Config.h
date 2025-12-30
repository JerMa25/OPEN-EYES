#ifndef CONFIG_H
#define CONFIG_H

// ===== ACTIVATION DES LOGS =====
#define LOG_ENABLED true  // true = les logs sont activés, false = désactivés

// ===== PINS DU MODULE SIM808 =====
#define SIM808_RX         16  // Pin de réception (RX) pour la communication avec SIM808
#define SIM808_TX         17  // Pin de transmission (TX) pour la communication avec SIM808
#define SIM808_PWR        2   // Pin pour contrôler l'alimentation du SIM808

// ===== BOUTONS ET LEDS =====
#define BOUTON_SOS        0   // Pin du bouton d'urgence SOS
#define LED_STATUS        2   // Pin de la LED d'état

// ===== PARAMÈTRES GPS =====
#define GPS_UPDATE_INTERVAL   5000   // Intervalle de mise à jour GPS (5 secondes)
#define GPS_TIMEOUT           30000  // Timeout GPS (30 secondes)
#define DELAI_ENTRE_SMS       60000  // Délai minimum entre deux SMS (60 secondes)

// ===== NUMÉROS DE TÉLÉPHONE =====
#define NUMERO_URGENCE "+237XXXXXXXXX"  // Numéro d'urgence à contacter
#define NUMERO_PROCHE  "+237YYYYYYYYY"  // Numéro d'un proche à contacter

// ===== PARAMÈTRES DE COMMUNICATION SÉRIE =====
#define DEBUG_BAUDRATE 115200  // Vitesse de communication pour le debug USB
#define SIM808_BAUDRATE 9600   // Vitesse de communication avec le SIM808

// ===== OBSTACLE DETECTOR =====
#define OBSTACLE_CHECK_INTERVAL 40

// Seuils de navigation
#define ARRIVAL_DISTANCE_METERS 10.0   // Distance pour considérer l'arrivée
#define TURN_THRESHOLD_DEG      15.0   // Angle minimum pour corriger la direction

#define DEG_TO_RAD 0.01745329251
#define RAD_TO_DEG 57.2957795131
#define EARTH_RADIUS 6371000.0  // mètres

#endif
