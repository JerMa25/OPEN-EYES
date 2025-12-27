// ============================================
// GPSTracker.h - Gestionnaire GPS avec Bluetooth
// ============================================
#ifndef GPS_TRACKER_H
#define GPS_TRACKER_H

#include <Arduino.h>
#include "IModule.h"

// Structure pour stocker une position GPS
struct GPSPosition {
    float latitude = 0;      // Latitude en degrés décimaux
    float longitude = 0;     // Longitude en degrés décimaux
    float altitude = 0;      // Altitude en mètres
    bool isValid = false;    // Indique si la position est valide
    String timestamp;        // Horodatage de la position
};

// Classe pour gérer le GPS et le Bluetooth du module SIM808
class GPSTracker : public IModule {
  public:
    // Constructeur qui prend la référence au port série
    GPSTracker(HardwareSerial& serial);

    // Méthodes héritées de IModule
    void init() override;      // Initialise le GPS et le Bluetooth
    void update() override;    // Met à jour la position GPS et l'envoi Bluetooth
    void stop() override;      // Arrête le GPS et le Bluetooth
    bool isReady() const override; // Vérifie si le GPS est prêt

    // Récupère la position GPS actuelle
    GPSPosition getPosition() const;
    
    // Configuration du Bluetooth
    void configureBluetooth(const String& name, const String& pin);
    
    // Active/désactive l'envoi automatique via Bluetooth
    void enableBluetoothSending(bool enable);

  private:
    HardwareSerial& sim808;    // Référence au port série du SIM808
    GPSPosition position;       // Position GPS actuelle
    bool ready = false;         // État de préparation du GPS
    bool bluetoothEnabled = false; // État du Bluetooth
    bool autoSendBluetooth = true; // Envoi automatique via Bluetooth
    unsigned long lastBluetoothSend = 0; // Dernier envoi Bluetooth
  
    // Fonctions GPS
    bool readGPS();             // Lit les données GPS du module
    
    // Fonctions Bluetooth
    void initBluetooth();       // Initialise le Bluetooth
    void sendGPSViaBluetooth(); // Envoie les données GPS via Bluetooth
    bool isBluetoothConnected(); // Vérifie si un appareil est connecté
    
    // Fonctions utilitaires
    void sendAT(const String& cmd);  // Envoie une commande AT au module
    String readResponse();      // Lit la réponse du module
};

#endif
