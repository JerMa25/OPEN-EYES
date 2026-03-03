// ============================================
// GSMEmergency.h - Gestion complète GSM/SMS avec EEPROM
// ============================================
#ifndef GSM_EMERGENCY_H
#define GSM_EMERGENCY_H

#include <Arduino.h>
#include <EEPROM.h>
#include "IModule.h"
#include "GPSTracker.h"

// Classe pour gérer les urgences via GSM/SMS avec contacts multiples
class GSMEmergency : public IModule {
  public:
    // Constructeur prenant le port série et le tracker GPS
    GSMEmergency(HardwareSerial& serial, GPSTracker& gps);
    
    // Méthodes héritées de IModule
    void init() override;           // Initialise le module GSM et EEPROM
    void update() override;         // Traitement des SMS entrants
    void stop() override;           // Arrête le module GSM
    bool isReady() const override;  // Vérifie si le GSM est prêt
    
    // Gestion des alertes
    void sendSOS();                                    // Envoie SOS au numéro d'urgence principal
    void sendAlertToAll(const String& message);        // Envoie alerte à tous les contacts EEPROM
    
    // Gestion des contacts d'urgence
    bool ajouterContact(const String& numero);
    bool supprimerContact(const String& numero);
    void listerContacts();
    int getNombreContacts() const;

  private:
    HardwareSerial& sim808;  // Référence au port série du SIM808
    GPSTracker& gps;         // Référence au tracker GPS
    bool ready = false;      // État du module GSM
    
    // Gestion EEPROM
    void initialiserEEPROM();
    bool contactExiste(const String& numero);
    void sauvegarderContact(int slot, const String& numero);
    String lireContact(int slot);
    
    // Gestion SMS
    bool sendSMS(const String& number, const String& message);
    void traiterSMSEntrants();
    void traiterCommandeAdmin(const String& sms);
    String extraireNumeroExpediteur(const String& sms);
    
    // Vérification admin
    bool estNumeroAdmin(const String& numero);
};

#endif