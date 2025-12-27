// ============================================
// GPSTracker.h - En-tête sans Bluetooth
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

// Classe pour gérer le GPS du module SIM808
class GPSTracker : public IModule {
  public:
    // Constructeur qui prend la référence au port série
    GPSTracker(HardwareSerial& serial);

    // Méthodes héritées de IModule
    void init() override;      // Initialise le GPS
    void update() override;    // Met à jour la position GPS
    void stop() override;      // Arrête le GPS
    bool isReady() const override; // Vérifie si le GPS est prêt

    // Récupère la position GPS actuelle
    GPSPosition getPosition() const;

  private:
    HardwareSerial& sim808;    // Référence au port série du SIM808
    GPSPosition position;       // Position GPS actuelle
    bool ready = false;         // État de préparation du GPS
  
    bool readGPS();             // Lit les données GPS du module
    void sendAT(const String& cmd);  // Envoie une commande AT au module
    String readResponse();      // Lit la réponse du module
};

#endif
