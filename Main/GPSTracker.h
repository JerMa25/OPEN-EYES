#ifndef GPS_TRACKER_H
#define GPS_TRACKER_H

#include <Arduino.h>
#include "IModule.h"

struct GPSPosition {
    float latitude = 0;
    float longitude = 0;
    float altitude = 0;
    bool isValid = false;
    String timestamp;
};

class GPSTracker : public IModule {
  public:
    GPSTracker(HardwareSerial& serial);

    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    GPSPosition getPosition() const;

  private:
    HardwareSerial& sim808;
    GPSPosition position;
    bool ready = false;
  
    bool readGPS();
    void sendAT(const String& cmd);
    String readResponse();
};

#endif
