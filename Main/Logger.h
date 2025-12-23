// Logger.h
#ifndef LOGGER_H
#define LOGGER_H

#include <Arduino.h>
#include "Config.h"
    
class Logger {
  public:
    static void info(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[INFO] "+ msg);
      }
    }

    static void warn(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[WARN] "+ msg);
      }
    }

    static void error(const String& msg) {
      if (LOG_ENABLED) {
        Serial.println("[ERROR] "+ msg);
      }
    }
};

#endif
