// ============================================
// Logger.h - Système de journalisation
// ============================================
#ifndef LOGGER_H
#define LOGGER_H

#include <Arduino.h>
#include "Config.h"
    
class Logger {
  public:
    // Affiche un message d'information
    static void info(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[INFO] "+ msg);
      }
    }

    // Affiche un message d'avertissement
    static void warn(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[WARN] "+ msg);
      }
    }

    // Affiche un message d'erreur
    static void error(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[ERROR] "+ msg);
      }
    }
};

#endif
