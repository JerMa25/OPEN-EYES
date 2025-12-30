// ============================================
// GPSAssistance.cpp - Implémentation assistance GPS
// ============================================
#include "GPSAssistance.h"
#include <math.h>
#include "Config.h"



GPSAssistance::GPSAssistance(GPSTracker& gps)
    : gpsTracker(gps) {}

void GPSAssistance::setDestination(float latitude, float longitude) {
    destLat = latitude;
    destLon = longitude;
    destinationSet = true;
    Logger::info("Destination définie");
}

bool GPSAssistance::hasDestination() const {
    return destinationSet;
}

void GPSAssistance::update() {
    if (!destinationSet) {
        currentInstruction = DIR_NO_GPS;
        return;
    }

    GPSData data = gpsTracker.getGPSData();
    if (!data.isValid) {
        currentInstruction = DIR_NO_GPS;
        return;
    }

    distanceMeters = calculateDistance(
        data.latitude, data.longitude,
        destLat, destLon
    );

    bearingDegrees = calculateBearing(
        data.latitude, data.longitude,
        destLat, destLon
    );

    float angleError = normalizeAngle(bearingDegrees - data.heading);

    if (distanceMeters <= ARRIVAL_DISTANCE_METERS) {
        currentInstruction = DIR_ARRIVED;
    } else if (angleError > TURN_THRESHOLD_DEG) {
        currentInstruction = DIR_TURN_RIGHT;
    } else if (angleError < -TURN_THRESHOLD_DEG) {
        currentInstruction = DIR_TURN_LEFT;
    } else {
        currentInstruction = DIR_CONTINUE;
    }
}

DirectionInstruction GPSAssistance::getInstruction() const {
    return currentInstruction;
}

float GPSAssistance::getDistanceToDestination() const {
    return distanceMeters;
}

float GPSAssistance::getBearingToDestination() const {
    return bearingDegrees;
}

// =================== CALCULS ===================

float GPSAssistance::calculateDistance(float lat1, float lon1,
                                       float lat2, float lon2) {
    float dLat = (lat2 - lat1) * DEG_TO_RAD;
    float dLon = (lon2 - lon1) * DEG_TO_RAD;

    float a = sin(dLat/2) * sin(dLat/2) +
              cos(lat1 * DEG_TO_RAD) * cos(lat2 * DEG_TO_RAD) *
              sin(dLon/2) * sin(dLon/2);

    float c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return EARTH_RADIUS * c;
}

float GPSAssistance::calculateBearing(float lat1, float lon1,
                                      float lat2, float lon2) {
    float y = sin((lon2 - lon1) * DEG_TO_RAD) * cos(lat2 * DEG_TO_RAD);
    float x = cos(lat1 * DEG_TO_RAD) * sin(lat2 * DEG_TO_RAD) -
              sin(lat1 * DEG_TO_RAD) * cos(lat2 * DEG_TO_RAD) *
              cos((lon2 - lon1) * DEG_TO_RAD);

    float bearing = atan2(y, x) * RAD_TO_DEG;
    return normalizeAngle(bearing);
}

float GPSAssistance::normalizeAngle(float angle) {
    while (angle < -180) angle += 360;
    while (angle > 180) angle -= 360;
    return angle;
}
