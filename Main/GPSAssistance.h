#ifndef GPS_ASSISTANCE_H
#define GPS_ASSISTANCE_H

#include <Arduino.h>
#include "IModule.h"
#include "Logger.h"
#include "BluetoothManager.h"

class GPSAssistance : public IModule {
  public:
    GPSAssistance(BluetoothManager& bt);

    void init() override;
    void update() override;
    void stop() override;
    bool isReady() const override;

    IMUData getIMUData() const;

  private:
    BluetoothManager& bluetooth;
    IMUData imuData;
    bool ready = false;
    unsigned long lastBLESend = 0;  // ✅ AJOUTER

    void initMPU();
    void initMagnetometer();  // ✅ AJOUTER
    void readIMU();
    void readMagnetometer();  // ✅ AJOUTER
};

#endif