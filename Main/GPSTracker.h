// ============================================
// GPSTracker.h - En-tête GPS avec toutes les données
// ============================================
#ifndef GPS_TRACKER_H
#define GPS_TRACKER_H

#include <Arduino.h>
#include "IModule.h"

// Structure complète pour les données GPS attendues par l'application
struct GPSData {
    float latitude = 0.0;         // Latitude en degrés décimaux
    float longitude = 0.0;        // Longitude en degrés décimaux
    float altitude = 0.0;         // Altitude en mètres
    float speed = 0.0;            // Vitesse en km/h
    float heading = 0.0;          // Direction/cap en degrés (0-360)
    int satellitesCount = 0;      // Nombre de satellites visibles
    float hdop = 99.9;            // Précision horizontale (plus bas = meilleur)
    String gpsTimestamp = "";     // Horodatage GPS
    String fixType = "No Fix";    // Type de fix: "No Fix", "2D Fix", "3D Fix"
    bool isValid = false;         // Indique si les données GPS sont valides
};

// Classe pour gérer le GPS du module SIM808
class GPSTracker : public IModule {
  public:
    // Constructeur qui prend la référence au port série
    GPSTracker(HardwareSerial& serial);

    // Méthodes héritées de IModule
    void init() override;           // Initialise le GPS
    void update() override;         // Met à jour les données GPS
    void stop() override;           // Arrête le GPS
    bool isReady() const override;  // Vérifie si le GPS est prêt

    // Récupère toutes les données GPS
    GPSData getGPSData() const;

  private:
    HardwareSerial& sim808;    // Référence au port série du SIM808
    GPSData gpsData;            // Données GPS complètes
    bool ready = false;         // État de préparation du GPS
  
    bool readGPS();                      // Lit les données GPS du module
    void parseGPSInfo(const String& response);  // Parse la réponse GPS complète
    void sendAT(const String& cmd);      // Envoie une commande AT au module
    String readResponse();               // Lit la réponse du module
};

#endif
