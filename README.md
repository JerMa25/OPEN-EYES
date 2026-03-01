# 🦯 OPEN EYES — Canne Intelligente (ESP32 / SIM808)

Firmware Arduino pour une canne d'assistance intelligente destinée aux personnes malvoyantes. Le système embarque la détection d'obstacles par ultrasons, un capteur d'humidité, la géolocalisation GPS, une centrale inertielle (IMU/magnétomètre), la communication d'urgence par SMS et une interface Bluetooth Low Energy (BLE) vers une application mobile.

---

## 📋 Table des matières

- [Architecture du projet](#-architecture-du-projet)
- [Matériel requis](#-matériel-requis)
- [Brochage (Pinout)](#-brochage-pinout)
- [Modules logiciels](#-modules-logiciels)
- [Fonctionnement détaillé](#-fonctionnement-détaillé)
- [Protocole BLE](#-protocole-ble)
- [Gestion des contacts SMS](#-gestion-des-contacts-sms)
- [Configuration](#-configuration)
- [Compilation et téléversement](#-compilation-et-téléversement)
- [Dépendances](#-dépendances)

---

## 🗂 Architecture du projet

```
canne-intelligente/
├── Main.ino               # Point d'entrée : setup() et loop()
├── Config.h               # Toute la configuration (pins, seuils, timings)
├── IModule.h              # Interface abstraite commune à tous les modules
├── Logger.h               # Système de journalisation série
├── ObstacleDetector.h/.cpp  # Détection obstacles + capteur eau + servo
├── GPSTracker.h/.cpp        # Acquisition GPS via SIM808 (AT+CGPSINF)
├── GPSAssistance.h/.cpp     # IMU MPU-9250 + magnétomètre AK8963
├── GSMEmergency.h/.cpp      # Alertes SMS + gestion contacts EEPROM
├── BluetoothManager.h/.cpp  # Serveur BLE ESP32 (4 caractéristiques)
```

Tous les modules implémentent l'interface `IModule` (`init()`, `update()`, `stop()`, `isReady()`). La boucle principale `loop()` appelle `update()` sur chaque module à chaque itération, garantissant un comportement non-bloquant.

---

## 🛠 Matériel requis

| Composant | Rôle |
|---|---|
| ESP32 (DevKit) | Microcontrôleur principal |
| SIM808 | GPS + GSM/SMS |
| MPU-9250 (+ AK8963) | IMU 9 axes (accéléro + gyro + magnéto) |
| HC-SR04 × 2 | Capteurs ultrasons (haut et bas) |
| Servo moteur | Balayage latéral du capteur bas |
| Buzzer actif × 2 | Alertes sonores obstacles et eau |
| Capteur d'humidité analogique | Détection eau à la base de la canne |
| LED × 2 | LED d'alimentation + LED de statut |
| Bouton poussoir | Bouton SOS |
| Carte SIM avec forfait SMS/données | Urgences et GPS |

---

## 🔌 Brochage (Pinout)

| Signal | GPIO ESP32 |
|---|---|
| SIM808 RX | 17 |
| SIM808 TX | 16 |
| Capteur ultrason HAUT — TRIG | 5 |
| Capteur ultrason HAUT — ECHO | 18 |
| Capteur ultrason BAS — TRIG | 19 |
| Capteur ultrason BAS — ECHO | 0 |
| Servo moteur | 2 |
| Buzzer 1 (obstacles haut) | 26 |
| Buzzer 2 (obstacles bas / eau) | 25 |
| Capteur eau (analogique) | 34 |
| Bouton SOS | 13 |
| LED statut | 14 |
| LED alimentation | 27 |
| MPU-9250 SDA | 21 |
| MPU-9250 SCL | 22 |

---

## 🧩 Modules logiciels

### `ObstacleDetector`

Gère les deux capteurs ultrasons HC-SR04, le servomoteur de balayage et le capteur d'eau.

- **Capteur haut** : fixe, détecte les obstacles en hauteur (branches, panneaux, rétroviseurs). Déclenche le **Buzzer 1**.
- **Capteur bas** : monté sur servomoteur, balaye de 0° à 180° par pas de 30° (`OBSTACLE_ANGLE_STEP`). Déclenche le **Buzzer 2**.
- **Filtrage des mesures** : double mesure avec rejet si l'écart dépasse 50 cm, buffer circulaire de 3 valeurs, calcul de la médiane par tri à bulles. Les mesures dépassant 400 cm ou inférieures à 2 cm sont rejetées.
- **Alertes sonores non-bloquantes** : les buzzers sont pilotés par des machines à états (`BuzzerState`, `WaterAlertState`) basées sur `millis()`. Aucun `delay()` n'est utilisé dans `update()`.
- **Priorité eau** : si une alerte eau est active, le Buzzer 2 est exclusivement réservé à `updateWaterAlert()` ; la détection d'obstacle bas est suspendue.

**Seuils de distance (Buzzer 1 et 2) :**

| Distance | Comportement |
|---|---|
| > 30 cm | Silence |
| ≤ 30 cm | Bips réguliers (1 bip toutes les 500 ms, durée 100 ms) |
| < 12 cm | Son continu |

**Capteur d'eau :**

| Niveau ADC | Comportement |
|---|---|
| < `WATER_THRESHOLD_LOW` (1000) | Pas d'alerte |
| > `WATER_THRESHOLD_LOW` | Deux bips courts sur Buzzer 2 (150 ms ON / 100 ms OFF / 150 ms ON) |
| > `WATER_THRESHOLD_HIGH` (3000) | Idem (seuil haut actuellement mappé sur le même pattern) |

Un cooldown de 2 secondes (`WATER_ALERT_COOLDOWN`) empêche les alertes répétées en cas de contact prolongé.

---

### `GPSTracker`

Communique avec le module SIM808 via UART (115200 bauds) en utilisant les commandes AT.

- Interroge le GPS toutes les 10 secondes (`GPS_READ_INTERVAL`) via `AT+CGPSINF=32`.
- Parse la réponse pour extraire : latitude, longitude, altitude, vitesse, cap, nombre de satellites, horodatage, type de fix (`No Fix` / `2D Fix` / `3D Fix`).
- Calcule un HDOP approximatif à partir du nombre de satellites (valeur estimée, non fournie directement par le SIM808).

---

### `GPSAssistance` (IMU)

Gère la centrale inertielle MPU-9250 via I2C.

- **Accéléromètre** : calcule le roulis (`roll`) et le tangage (`pitch`) via `atan2`.
- **Magnétomètre AK8963** : calcule le cap magnétique (`yaw`) avec compensation d'inclinaison (tilt-compensated heading). ⚠️ Aucune calibration hard iron / soft iron n'est implémentée ; le yaw peut être biaisé selon l'environnement.
- Les données IMU sont lues dans `update()` et exposées via `getIMUData()`. L'envoi BLE est délégué à `BluetoothManager`.

---

### `BluetoothManager`

Serveur BLE ESP32 exposant 4 caractéristiques NOTIFY/READ sous un service unique.

| Caractéristique | UUID (suffixe) | Contenu | Intervalle |
|---|---|---|---|
| GPS | `...26a8` | JSON : lat, lon, alt, speed, heading, sats, hdop, timestamp, fixType | 5 s |
| IMU | `...26ab` | JSON : yaw, pitch, roll | 200 ms |
| Obstacles | `...26aa` | JSON : upper, lower, servoAngle | 500 ms |
| Eau | `...26a9` | JSON : humidityLevel (%), rawData | 1 s |

En cas de déconnexion d'un client, l'advertising redémarre automatiquement via le callback `onDisconnect()`.

---

### `GSMEmergency`

Gère les alertes SMS et les contacts d'urgence stockés en EEPROM (5 contacts max, 20 caractères chacun).

**Bouton SOS :**

| Action | Résultat |
|---|---|
| Appui court (< 2 s) | Message « Tout va bien » (log uniquement dans la version actuelle) |
| Appui long (≥ 2 s) | SMS SOS au `NUMERO_URGENCE` avec position GPS |

---

## 📡 Protocole BLE

**Service UUID :** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

Toutes les caractéristiques envoient du JSON UTF-8. Exemple pour le GPS :

```json
{
  "latitude": 3.848034,
  "longitude": 11.502075,
  "altitude": 750.00,
  "speed": 0.00,
  "heading": 0.00,
  "satellitesCount": 7,
  "hdop": 2.00,
  "gpsTimestamp": "20250315120000.000",
  "fixType": "3D Fix"
}
```

---

## 📞 Gestion des contacts SMS

Les contacts sont gérés par SMS depuis le numéro administrateur (`NUMERO_ADMIN` dans `Config.h`). Jusqu'à 5 contacts peuvent être enregistrés en EEPROM (persistants après redémarrage).

| Commande SMS | Action |
|---|---|
| `ADMIN:ADD:+237XXXXXXXXX` | Ajouter un contact d'urgence |
| `ADMIN:DEL:+237XXXXXXXXX` | Supprimer un contact |
| `ADMIN:LIST` | Recevoir la liste des contacts enregistrés |
| `ADMIN:LOC` | Recevoir la position GPS actuelle |
| `ADMIN:HELP` | Recevoir la liste des commandes |

---

## ⚙️ Configuration

Tous les paramètres sont centralisés dans `Config.h`. Les principaux :

```c
// Numéros de téléphone
#define NUMERO_URGENCE   "+237XXXXXXXXXXX"  // Destinataire SOS
#define NUMERO_ADMIN     "+237XXXXXXXXXXX"  // Numéro autorisé à envoyer des commandes

// Seuils obstacles
#define BUZZER_DISTANCE_SEUIL    30   // cm — déclenchement des bips
#define BUZZER_DISTANCE_RAPIDE   12   // cm — passage en son continu
#define BUZZER_INTERVAL          500  // ms — intervalle entre bips
#define BUZZER_BIP_DURATION      100  // ms — durée d'un bip

// Seuils eau
#define WATER_THRESHOLD_LOW      1000  // Valeur ADC minimale pour alerte
#define WATER_THRESHOLD_HIGH     3000  // Valeur ADC pour alerte niveau élevé
#define WATER_ALERT_COOLDOWN     2000  // ms — délai minimum entre deux alertes

// Bouton SOS
#define DELAI_APPUI_LONG         2000  // ms — durée pour déclencher le SOS

// Intervalles BLE
#define GPS_UPDATE_INTERVAL      5000   // ms
#define IMU_UPDATE_INTERVAL      200    // ms
#define OBSTACLE_BLE_UPDATE_INTERVAL  500   // ms
#define WATER_BLE_UPDATE_INTERVAL     1000  // ms
```

---

## 🔨 Compilation et téléversement

1. Ouvrir le projet dans l'**Arduino IDE** (≥ 2.x) ou **PlatformIO**.
2. Sélectionner la carte **ESP32 Dev Module**.
3. Installer les bibliothèques listées ci-dessous.
4. Renseigner les numéros de téléphone dans `Config.h` avant compilation.
5. Compiler et téléverser. Ouvrir le moniteur série à **9600 bauds** pour suivre les logs.

---

## 📦 Dépendances

| Bibliothèque | Usage |
|---|---|
| `ESP32 Arduino Core` | Support ESP32 (BLE, EEPROM, HardwareSerial, WDT) |
| `ESP32Servo` | Pilotage du servomoteur |
| `BLEDevice / BLEServer / BLE2902` | Bluetooth Low Energy (inclus dans le core ESP32) |
| `Wire` | Communication I2C avec le MPU-9250 |
| `EEPROM` | Persistance des contacts d'urgence |
| `esp_task_wdt.h` | Gestion du Watchdog Timer |

---

## 📝 Limitations connues

- **HDOP GPS** : valeur estimée à partir du nombre de satellites, non calculée par le module SIM808.
- **Calibration magnétomètre** : aucune correction hard iron / soft iron implémentée. Le yaw peut présenter des biais selon l'environnement électromagnétique de la canne.
- **Bouton SOS — appui court** : le clic court est détecté mais ne déclenche pas encore d'envoi SMS (log console uniquement).
- **Double-clic** : les constantes `DELAI_DOUBLE_CLIC` sont définies dans `Config.h` mais la logique de détection du double-clic n'est pas implémentée.

---

*Projet développé dans le cadre de la conception d'une aide technique pour personnes malvoyantes.*
