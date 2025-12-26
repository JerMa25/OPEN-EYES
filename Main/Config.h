#ifndef CONFIG_H
#define CONFIG_H

// ===== LOG =====
#define LOG_ENABLED true

// ===== SIM808 PINS =====
#define SIM808_RX         16
#define SIM808_TX         17
#define SIM808_PWR        2

// ===== BOUTON & LED =====
#define BOUTON_SOS        0
#define LED_STATUS        2

// ===== GPS =====
#define GPS_UPDATE_INTERVAL   5000
#define GPS_TIMEOUT           30000
#define DELAI_ENTRE_SMS       60000

// ===== NUMÉROS =====
#define NUMERO_URGENCE "+237XXXXXXXXX"
#define NUMERO_PROCHE  "+237YYYYYYYYY"

// ===== SERIAL =====
#define DEBUG_BAUDRATE 115200
#define SIM808_BAUDRATE 9600

// ===== OBSTACLE DETECTOR =====
#define OBSTACLE_CHECK_INTERVAL 40

#endif