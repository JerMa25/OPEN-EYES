// ============================================
// BluetoothManager.cpp - Implémentation BLE complète
// ============================================
#include "BluetoothManager.h"
#include "Config.h"

// Constructeur
BluetoothManager::BluetoothManager(GPSTracker& gpsTracker) : gps(gpsTracker) {}

// Initialise le module BLE de l'ESP32
void BluetoothManager::init() {
    Logger::info("Initialisation BLE ESP32");
    
    // Initialise le dispositif BLE avec le nom
    BLEDevice::init(deviceName.c_str());
    
    // Crée le serveur BLE
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks(this));
    
    // Crée le service principal
    BLEService* pService = pServer->createService(SERVICE_UUID);
    
    // ===== Caractéristique GPS =====
    pGPSCharacteristic = pService->createCharacteristic(
        GPS_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pGPSCharacteristic->addDescriptor(new BLE2902());
    
    // ===== Caractéristique Capteur d'Eau =====
    pWaterCharacteristic = pService->createCharacteristic(
        WATER_SENSOR_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pWaterCharacteristic->addDescriptor(new BLE2902());
    
    // ===== Caractéristique Obstacles =====
    pObstacleCharacteristic = pService->createCharacteristic(
        OBSTACLE_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pObstacleCharacteristic->addDescriptor(new BLE2902());
    
    // ===== Caractéristique IMU =====
    pImuCharacteristic = pService->createCharacteristic(
        IMU_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pImuCharacteristic->addDescriptor(new BLE2902());
    
    // Démarre le service
    pService->start();
    
    // Démarre l'advertising (rend l'appareil visible)
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    
    ready = true;
    Logger::info("BLE prêt - Nom: " + deviceName);
}

// Configure le nom du dispositif BLE
void BluetoothManager::setDeviceName(const String& name) {
    deviceName = name;
    Logger::info("Nom BLE défini: " + name);
}

// Arrête le module BLE
void BluetoothManager::stop() {
    Logger::info("BLE arrêté");
    
    if (pServer) {
        pServer->getAdvertising()->stop();
    }
    
    BLEDevice::deinit(true);
    ready = false;
}

// Vérifie si le BLE est prêt
bool BluetoothManager::isReady() const {
    return ready;
}

// Vérifie si un client est connecté
bool BluetoothManager::isClientConnected() const {
    return deviceConnected;
}

// Active/désactive l'envoi automatique
void BluetoothManager::enableAutoSend(bool enable) {
    autoSend = enable;
    Logger::info(enable ? "Envoi BLE automatique activé" : "Envoi BLE automatique désactivé");
}

// Met à jour et envoie les données périodiquement
void BluetoothManager::update() {
    // Vérifie si le BLE est prêt et un client est connecté
    if (!ready || !deviceConnected) return;
    
    // Envoie automatique des données GPS si activé
    if (autoSend) {
        unsigned long currentTime = millis();
        
        // Envoie toutes les GPS_UPDATE_INTERVAL millisecondes (5 secondes par défaut)
        if (currentTime - lastSendTime >= GPS_UPDATE_INTERVAL) {
            sendGPSData();
            lastSendTime = currentTime;
        }
    }
}

// Envoie les données GPS complètes via BLE
void BluetoothManager::sendGPSData() {
    if (!deviceConnected) {
        Logger::warn("Aucun client BLE connecté");
        return;
    }
    
    // Récupère toutes les données GPS
    GPSData gpsData = gps.getGPSData();
    
    if (!gpsData.isValid) {
        Logger::warn("Données GPS invalides - Envoi annulé");
        return;
    }
    
    // Formate les données GPS en JSON selon le format attendu par l'application
    String jsonData = "{";
    jsonData += "\"latitude\":" + String(gpsData.latitude, 6) + ",";
    jsonData += "\"longitude\":" + String(gpsData.longitude, 6) + ",";
    jsonData += "\"altitude\":" + String(gpsData.altitude, 2) + ",";
    jsonData += "\"speed\":" + String(gpsData.speed, 2) + ",";
    jsonData += "\"heading\":" + String(gpsData.heading, 2) + ",";
    jsonData += "\"satellitesCount\":" + String(gpsData.satellitesCount) + ",";
    jsonData += "\"hdop\":" + String(gpsData.hdop, 2) + ",";
    jsonData += "\"gpsTimestamp\":\"" + gpsData.gpsTimestamp + "\",";
    jsonData += "\"fixType\":\"" + gpsData.fixType + "\"";
    jsonData += "}";
    
    // Envoie via la caractéristique BLE
    pGPSCharacteristic->setValue(jsonData.c_str());
    pGPSCharacteristic->notify(); // Notifie le client
    
    Logger::info("GPS envoyé via BLE: Lat=" + String(gpsData.latitude, 6) + 
                 " Lon=" + String(gpsData.longitude, 6) + 
                 " Sats=" + String(gpsData.satellitesCount));
}

// Envoie les données du capteur d'eau via BLE
void BluetoothManager::sendWaterSensorData(const WaterSensorData& data) {
    if (!deviceConnected) return;
    
    // Formate les données en JSON selon le format attendu
    String jsonData = "{";
    jsonData += "\"humidityLevel\":" + String(data.humidityLevel, 2) + ",";
    jsonData += "\"rawData\":" + String(data.rawData);
    jsonData += "}";
    
    // Envoie via BLE
    pWaterCharacteristic->setValue(jsonData.c_str());
    pWaterCharacteristic->notify();
    
    Logger::info("Capteur eau envoyé via BLE: " + String(data.humidityLevel) + "%");
}

// Envoie les données de détection d'obstacles via BLE
void BluetoothManager::sendObstacleData(const ObstacleData& data) {
    if (!deviceConnected) return;
    
    // Formate les données en JSON selon le format attendu
    String jsonData = "{";
    jsonData += "\"upper\":" + String(data.upper) + ",";
    jsonData += "\"lower\":" + String(data.lower) + ",";
    jsonData += "\"servoAngle\":" + String(data.servoAngle);
    jsonData += "}";
    
    // Envoie via BLE
    pObstacleCharacteristic->setValue(jsonData.c_str());
    pObstacleCharacteristic->notify();
    
    Logger::info("Obstacles envoyés via BLE: Upper=" + String(data.upper) + 
                 " Lower=" + String(data.lower));
}

// Envoie les données IMU (orientation) via BLE
void BluetoothManager::sendImuData(const ImuData& data) {
    if (!deviceConnected) return;
    
    // Formate les données en JSON selon le format attendu
    String jsonData = "{";
    jsonData += "\"yaw\":" + String(data.yaw, 2) + ",";
    jsonData += "\"pitch\":" + String(data.pitch, 2) + ",";
    jsonData += "\"roll\":" + String(data.roll, 2);
    jsonData += "}";
    
    // Envoie via BLE
    pImuCharacteristic->setValue(jsonData.c_str());
    pImuCharacteristic->notify();
    
    Logger::info("IMU envoyé via BLE: Yaw=" + String(data.yaw) + 
                 " Pitch=" + String(data.pitch) + 
                 " Roll=" + String(data.roll));
}
