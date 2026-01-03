// ============================================
// BluetoothManager.h - Gestionnaire BLE pour toutes les données de la canne
// ============================================
#ifndef BLUETOOTH_MANAGER_H
#define BLUETOOTH_MANAGER_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "IModule.h"
#include "Logger.h"
#include "GPSTracker.h"

// UUID pour le service principal de la canne
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// UUID pour chaque type de données
#define GPS_CHARACTERISTIC_UUID         "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define WATER_SENSOR_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define OBSTACLE_CHARACTERISTIC_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26aa"
#define IMU_CHARACTERISTIC_UUID         "beb5483e-36e1-4688-b7f5-ea07361b26ab"

// Structures pour les données des futurs modules
struct WaterSensorData {
    float humidityLevel = 0.0;
    int rawData = 0;
};

struct ObstacleData {
    int upper = 0;
    int lower = 0;
    int servoAngle = 0;
};

struct IMUData {
    float yaw = 0.0;
    float pitch = 0.0;
    float roll = 0.0;
};

// Classe pour gérer le Bluetooth BLE de l'ESP32
class BluetoothManager : public IModule {
  public:
    // Constructeur prenant le tracker GPS
    BluetoothManager(GPSTracker& gpsTracker);

    // Méthodes héritées de IModule
    void init() override;           // Initialise le BLE
    void update() override;         // Met à jour et envoie les données
    void stop() override;           // Arrête le BLE
    bool isReady() const override;  // Vérifie si le BLE est prêt

    // Configure le nom BLE de l'appareil
    void setDeviceName(const String& name);
    
    // Méthodes d'envoi pour chaque type de données
    void sendGPSData();                                    // GPS
    void sendWaterSensorData(const WaterSensorData& data); // Capteur d'eau
    void sendObstacleData(const ObstacleData& data);       // Détection obstacles
    void sendImuData(const ImuData& data);                 // IMU (orientation)
    
    // Active/désactive l'envoi automatique
    void enableAutoSend(bool enable);
    
    // Vérifie si un client est connecté
    bool isClientConnected() const;

  private:
    GPSTracker& gps;                      // Référence au tracker GPS
    
    // Objets BLE
    BLEServer* pServer = nullptr;                          // Serveur BLE
    BLECharacteristic* pGPSCharacteristic = nullptr;       // Caractéristique GPS
    BLECharacteristic* pWaterCharacteristic = nullptr;     // Caractéristique capteur eau
    BLECharacteristic* pObstacleCharacteristic = nullptr;  // Caractéristique obstacles
    BLECharacteristic* pImuCharacteristic = nullptr;       // Caractéristique IMU
    
    // État du BLE
    bool ready = false;                   // BLE prêt
    bool deviceConnected = false;         // Client connecté
    bool autoSend = true;                 // Envoi automatique activé
    unsigned long lastSendTime = 0;       // Dernier envoi de données
    String deviceName = "Canne_Intelligente"; // Nom par défaut
    
    // Classe interne pour gérer les callbacks de connexion
    class ServerCallbacks : public BLEServerCallbacks {
      public:
        ServerCallbacks(BluetoothManager* manager) : btManager(manager) {}
        
        void onConnect(BLEServer* pServer) {
          btManager->deviceConnected = true;
          Logger::info("Client BLE connecté");
        }
        
        void onDisconnect(BLEServer* pServer) {
          btManager->deviceConnected = false;
          Logger::info("Client BLE déconnecté");
          // Redémarre l'advertising pour permettre une nouvelle connexion
          pServer->startAdvertising();
        }
        
      private:
        BluetoothManager* btManager;
    };
};

#endif
