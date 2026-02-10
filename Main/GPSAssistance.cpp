#include "GPSAssistance.h"
#include <Wire.h>
#include <math.h>
#include "Config.h"

GPSAssistance::GPSAssistance() {}

void GPSAssistance::init() {
    Logger::info("========================================");
    Logger::info("🧭 [INIT] Démarrage GPSAssistance (IMU)");
    Logger::info("========================================");
    
    Wire.begin(MPU_SDA_PIN, MPU_SCL_PIN);
    Wire.setClock(400000);
    Logger::info("✅ [IMU] I2C initialisé (SDA=" + String(MPU_SDA_PIN) + 
                 " SCL=" + String(MPU_SCL_PIN) + ")");

    initMPU();
    initMagnetometer();  // ✅ AJOUTER
    
    ready = true;
    Logger::info("✅ [IMU] GPSAssistance PRÊT");
    Logger::info("========================================");
}

void GPSAssistance::initMPU() {
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(REG_PWR);
    Wire.write(0x00);
    Wire.endTransmission();
    delay(100);
    Logger::info("✅ [IMU] MPU9250 réveillé");
}

// ✅ AJOUTER
void GPSAssistance::initMagnetometer() {
    // Active le bypass pour accès direct au magnétomètre
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(0x37);  // INT_PIN_CFG
    Wire.write(0x02);  // Bypass enable
    Wire.endTransmission();
    delay(10);
    
    // Configure le magnétomètre AK8963
    Wire.beginTransmission(0x0C);
    Wire.write(0x0A);  // Control register
    Wire.write(0x16);  // Mode continu 100Hz, 16-bit
    Wire.endTransmission();
    delay(10);
    
    Logger::info("✅ [IMU] Magnétomètre AK8963 configuré");
}

void GPSAssistance::update() {
    if (!ready) return;

    readIMU();

    // ✅ Les données IMU sont maintenant envoyées par BluetoothManager::update()
    // Plus besoin d'envoi direct ici
}

void GPSAssistance::readIMU() {
    // ===== Accéléromètre =====
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

    // ===== Magnétomètre =====
    readMagnetometer();  // ✅ AJOUTER
}

// ✅ AJOUTER
void GPSAssistance::readMagnetometer() {
    Wire.beginTransmission(0x0C);
    Wire.write(0x03);
    Wire.endTransmission(false);
    Wire.requestFrom(0x0C, 6);
    
    if (Wire.available() >= 6) {
        int16_t mx = Wire.read() | (Wire.read() << 8);
        int16_t my = Wire.read() | (Wire.read() << 8);
        int16_t mz = Wire.read() | (Wire.read() << 8);
        
        // Calcul yaw
        float heading = atan2(my, mx) * 180.0 / M_PI;
        
        if (heading < 0) {
            heading += 360;
        }
        
        imuData.yaw = heading;
    }
}

void GPSAssistance::stop() {
    ready = false;
    Logger::info("🛑 [IMU] GPS Assistance arrêtée");
}

bool GPSAssistance::isReady() const {
    return ready;
}

IMUData GPSAssistance::getIMUData() const {
    return imuData;
}