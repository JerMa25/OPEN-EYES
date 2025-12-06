// IModule.h
#ifndef IMODULE_H
#define IMODULE_H

class IModule {
public:
    virtual ~IModule() {}
    
    // Initialisation du module
    virtual bool init() = 0;
    
    // Mise à jour cyclique (appelée dans loop())
    virtual void update() = 0;
    
    // Arrêt propre du module
    virtual void stop() = 0;
    
    // Vérification de l'état
    virtual bool isReady() const = 0;
};

#endif