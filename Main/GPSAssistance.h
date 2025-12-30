// ============================================
// GPSAssistance.h - Assistance à la navigation
// ============================================
#ifndef GPS_ASSISTANCE_H
#define GPS_ASSISTANCE_H

#include <Arduino.h>
#include "GPSTracker.h"
#include "Logger.h"




enum DirectionInstruction {
    DIR_CONTINUE,
    DIR_TURN_LEFT,
    DIR_TURN_RIGHT,
    DIR_ARRIVED,
    DIR_NO_GPS
};

class GPSAssistance {
  public:
    GPSAssistance(GPSTracker& gps);

    void setDestination(float latitude, float longitude);
    bool hasDestination() const;

    void update();   // À appeler dans loop()

    DirectionInstruction getInstruction() const;
    float getDistanceToDestination() const;
    float getBearingToDestination() const;

  private:
    GPSTracker& gpsTracker;

    float destLat = 0.0;
    float destLon = 0.0;
    bool destinationSet = false;

    float distanceMeters = 0.0;
    float bearingDegrees = 0.0;
    DirectionInstruction currentInstruction = DIR_NO_GPS;

    float calculateDistance(float lat1, float lon1, float lat2, float lon2);
    float calculateBearing(float lat1, float lon1, float lat2, float lon2);
    float normalizeAngle(float angle);
};

#endif
