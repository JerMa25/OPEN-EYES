// ============================================
// BluetoothManager.cpp - Implémentation BLE
// ============================================
#include "BluetoothManager.h"
#include "Logger.h"
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
    
    // ===== Caractéristique Statut =====
    pStatusCharacteristic = pService->createCharacteristic(
        STATUS_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pStatusCharacteristic->addDescriptor(new BLE2902());
    
    // ===== Caractéristique Batterie =====
    pBatteryCharacteristic = pService->createCharacteristic(
        BATTERY_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pBatteryCharacteristic->addDescriptor(new BLE2902());
    
    // ===== Caractéristique SOS =====
    pSOSCharacteristic = pService->createCharacteristic(
        SOS_CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pSOSCharacteristic->addDescriptor(new BLE2902());
    
    // Démarre le service
    pService->start();
    
    // Démarre l'advertising (rend l'appareil visible)
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  // Aide avec les problèmes de connexion iPhone
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

// Envoie les données GPS via BLE
void BluetoothManager::sendGPSData() {
    if (!deviceConnected) {
        Logger::warn("Aucun client BLE connecté");
        return;
    }
    
    // Récupère la position GPS actuelle
    GPSPosition pos = gps.getPosition();
    
    if (!pos.isValid) {
        Logger::warn("Position GPS invalide - Envoi annulé");
        return;
    }
    
    // Formate les données GPS en JSON
    String gpsData = "{";
    gpsData += "\"lat\":" + String(pos.latitude, 6) + ",";
    gpsData += "\"lon\":" + String(pos.longitude, 6) + ",";
    gpsData += "\"alt\":" + String(pos.altitude, 2) + ",";
    gpsData += "\"valid\":true";
    gpsData += "}";
    
    // Envoie via la caractéristique BLE
    pGPSCharacteristic->setValue(gpsData.c_str());
    pGPSCharacteristic->notify(); // Notifie le client
    
    Logger::info("GPS envoyé via BLE: Lat=" + String(pos.latitude, 6) + 
                 " Lon=" + String(pos.longitude, 6));
}

// Envoie les données de statut
void BluetoothManager::sendStatusData(const String& status) {
    if (!deviceConnected) return;
    
    // Formate le statut en JSON
    String statusData = "{\"status\":\"" + status + "\"}";
    
    // Envoie via BLE
    pStatusCharacteristic->setValue(statusData.c_str());
    pStatusCharacteristic->notify();
    
    Logger::info("Statut envoyé via BLE: " + status);
}

// Envoie le niveau de batterie
void BluetoothManager::sendBatteryLevel(int percentage) {
    if (!deviceConnected) return;
    
    // Limite entre 0 et 100
    if (percentage < 0) percentage = 0;
    if (percentage > 100) percentage = 100;
    
    // Formate les données de batterie
    String batteryData = "{\"battery\":" + String(percentage) + "}";
    
    // Envoie via BLE
    pBatteryCharacteristic->setValue(batteryData.c_str());
    pBatteryCharacteristic->notify();
    
    Logger::info("Batterie envoyée via BLE: " + String(percentage) + "%");
}

// Envoie une alerte SOS
void BluetoothManager::sendSOSAlert(bool active) {
    if (!deviceConnected) return;
    
    // Formate l'alerte SOS
    String sosData = "{\"sos\":" + String(active ? "true" : "false") + "}";
    
    // Envoie via BLE
    pSOSCharacteristic->setValue(sosData.c_str());
    pSOSCharacteristic->notify();
    
    Logger::info("Alerte SOS envoyée via BLE: " + String(active ? "ACTIVE" : "INACTIVE"));
}
