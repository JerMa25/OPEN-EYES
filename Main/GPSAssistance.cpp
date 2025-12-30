#include "GPSAssistance.h"
#include <Wire.h>
#include <math.h>

#include "Config.h"


GPSAssistance::GPSAssistance(BluetoothManager& bt)
: bluetooth(bt) {}

void GPSAssistance::init() {

    Wire.begin(MPU_SDA_PIN, MPU_SCL_PIN);
    Wire.setClock(400000); // I2C rapide recommandé MPU

    initMPU();
    ready = true;
}

void GPSAssistance::initMPU() {
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(REG_PWR);
    Wire.write(0x00); // réveil
    Wire.endTransmission();
    delay(100);
}

void GPSAssistance::update() {
    if (!ready) return;

    readIMU();

    ImuData data;
    data.yaw   = imuData.yaw;
    data.pitch = imuData.pitch;
    data.roll  = imuData.roll;

    bluetooth.sendImuData(data);
}

void GPSAssistance::readIMU() {
    uint8_t buf[6];
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(REG_ACCEL);
    Wire.endTransmission(false);
    Wire.requestFrom(MPU_ADDR, 6);

    int16_t ax = Wire.read()<<8 | Wire.read();
    int16_t ay = Wire.read()<<8 | Wire.read();
    int16_t az = Wire.read()<<8 | Wire.read();

    float axg = ax / 16384.0;
    float ayg = ay / 16384.0;
    float azg = az / 16384.0;

    imuData.roll  = atan2(ayg, azg) * 180.0 / M_PI;
    imuData.pitch = atan2(-axg, sqrt(ayg*ayg + azg*azg)) * 180.0 / M_PI;

    // Yaw estimé plus tard avec magnétomètre
    imuData.yaw = imuData.yaw; 
}

void GPSAssistance::stop() {
    ready = false;
    Logger::info("GPS Assistance arrêtée");
}

bool GPSAssistance::isReady() const {
    return ready;
}

IMUData GPSAssistance::getIMUData() const {
    return imuData;
}
