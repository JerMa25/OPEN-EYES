// ============================================
// GSMEmergency.h - En-tête GSM
// ============================================
#ifndef GSM_EMERGENCY_H
#define GSM_EMERGENCY_H

#include <Arduino.h>
#include "IModule.h"
#include "GPSTracker.h"

// Classe pour gérer les urgences via GSM/SMS
class GSMEmergency : public IModule {
  public:
    // Constructeur prenant le port série et le tracker GPS
    GSMEmergency(HardwareSerial& serial, GPSTracker& gps);
    
    // Méthodes héritées de IModule
    void init() override;       // Initialise le module GSM
    void update() override;     // Mise à jour (traitement SMS futurs)
    void stop() override;       // Arrête le module GSM
    bool isReady() const override; // Vérifie si le GSM est prêt
    
    // Envoie une alerte SOS avec position GPS
    void sendSOS();

  private:
    HardwareSerial& sim808;  // Référence au port série du SIM808
    GPSTracker& gps;         // Référence au tracker GPS
    bool ready = false;      // État du module GSM
    
    // Envoie un SMS
    bool sendSMS(const String& number, const String& message);
};

#endif
