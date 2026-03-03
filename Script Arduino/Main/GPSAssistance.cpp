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

    // Activer bypass I2C
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(0x37);  // INT_PIN_CFG
    Wire.write(0x02);  // BYPASS_EN
    Wire.endTransmission();
    delay(10);

    // Vérifier présence AK8963
    Wire.beginTransmission(0x0C);
    byte error = Wire.endTransmission();

    if (error == 0) {
        Logger::info("✅ AK8963 détecté");
    } else {
        Logger::info("❌ AK8963 NON détecté");
        return;
    }

    // Mettre en mode power-down d'abord (important)
    Wire.beginTransmission(0x0C);
    Wire.write(0x0A);
    Wire.write(0x00);
    Wire.endTransmission();
    delay(10);

    // Mode continu 100Hz, 16-bit
    Wire.beginTransmission(0x0C);
    Wire.write(0x0A);
    Wire.write(0x16);
    Wire.endTransmission();
    delay(10);

    Logger::info("✅ Magnétomètre configuré en 100Hz 16-bit");
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

    // Vérifier data ready
    Wire.beginTransmission(0x0C);
    Wire.write(0x02);
    Wire.endTransmission(false);
    Wire.requestFrom(0x0C, 1);

    if (!(Wire.read() & 0x01)) {
        return; // pas de nouvelle donnée
    }

    Wire.beginTransmission(0x0C);
    Wire.write(0x03);
    Wire.endTransmission(false);
    Wire.requestFrom(0x0C, 7);

    if (Wire.available() >= 7) {

        int16_t mx = Wire.read() | (Wire.read() << 8);
        int16_t my = Wire.read() | (Wire.read() << 8);
        int16_t mz = Wire.read() | (Wire.read() << 8);
        Wire.read(); // ST2 (important à lire !)

        // Compensation d'inclinaison
        float rollRad  = imuData.roll * M_PI / 180.0;
        float pitchRad = imuData.pitch * M_PI / 180.0;

        float mxComp = mx * cos(pitchRad) + mz * sin(pitchRad);
        float myComp = mx * sin(rollRad) * sin(pitchRad) +
                    my * cos(rollRad) -
                    mz * sin(rollRad) * cos(pitchRad);

        float heading = atan2(myComp, mxComp) * 180.0 / M_PI;

        if (heading < 0)
            heading += 360;

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