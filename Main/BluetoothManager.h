// ============================================
// BluetoothManager.h - Gestionnaire BLE ESP32
// ============================================
#ifndef BLUETOOTH_MANAGER_H
#define BLUETOOTH_MANAGER_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "Logger.h"
#include "IModule.h"
#include "GPSTracker.h"

// UUID pour le service principal de la canne
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// UUID pour les caractéristiques (données à envoyer)
#define GPS_CHARACTERISTIC_UUID      "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define STATUS_CHARACTERISTIC_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define BATTERY_CHARACTERISTIC_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26aa"
#define SOS_CHARACTERISTIC_UUID      "beb5483e-36e1-4688-b7f5-ea07361b26ab"

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
    
    // Envoie les données GPS via BLE
    void sendGPSData();
    
    // Envoie les données de statut (ex: batterie, état de la canne)
    void sendStatusData(const String& status);
    
    // Envoie le niveau de batterie
    void sendBatteryLevel(int percentage);
    
    // Envoie une alerte SOS
    void sendSOSAlert(bool active);
    
    // Active/désactive l'envoi automatique
    void enableAutoSend(bool enable);
    
    // Vérifie si un client est connecté
    bool isClientConnected() const;

  private:
    GPSTracker& gps;                      // Référence au tracker GPS
    
    // Objets BLE
    BLEServer* pServer = nullptr;         // Serveur BLE
    BLECharacteristic* pGPSCharacteristic = nullptr;      // Caractéristique GPS
    BLECharacteristic* pStatusCharacteristic = nullptr;   // Caractéristique statut
    BLECharacteristic* pBatteryCharacteristic = nullptr;  // Caractéristique batterie
    BLECharacteristic* pSOSCharacteristic = nullptr;      // Caractéristique SOS
    
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
