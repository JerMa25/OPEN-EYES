#ifndef GPS_ASSISTANCE_H
#define GPS_ASSISTANCE_H

#include <Arduino.h>
#include "IModule.h"
#include "Logger.h"
#include "BluetoothManager.h"

// Données IMU calculées
struct IMUData {
    float yaw;
    float pitch;
    float roll;
};

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

    // --- Fonctions internes ---
    void initMPU();
    void readIMU();
};

#endif
