#ifndef GPS_ASSISTANCE_H
#define GPS_ASSISTANCE_H

#include <Arduino.h>
#include "IModule.h"
#include "Logger.h"

// Structure IMUData (précédemment dans BluetoothManager.h)
struct IMUData {
    float yaw = 0.0;
    float pitch = 0.0;
    float roll = 0.0;
};

class GPSAssistance : public IModule {
  public:
    GPSAssistance();  // ✅ Plus besoin de BluetoothManager

    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    IMUData getIMUData() const;

  private:
    IMUData imuData;
    bool ready = false;

    void initMPU();
    void initMagnetometer();
    void readIMU();
    void readMagnetometer();
};

#endif