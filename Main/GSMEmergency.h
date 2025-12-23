#ifndef GSM_EMERGENCY_H
#define GSM_EMERGENCY_H

#include <Arduino.h>
#include "IModule.h"
#include "GPSTracker.h"

class GSMEmergency : public IModule {
public:
    GSMEmergency(HardwareSerial& serial, GPSTracker& gps);

    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    void sendSOS();

private:
    HardwareSerial& sim808;
    GPSTracker& gps;
    bool ready = false;

    bool sendSMS(const String& number, const String& message);
};

#endif
