// Athletix-Data — faux brassard Bluetooth LE (ESP32 / ESP32-S3)
//
// Publie le service GATT décrit dans architecture/GATT.md, pour tester l'application
// AVANT que le vrai brassard (MyoWare 2.0) soit câblé.
//
//   SOURCE_SIMULEE = 1 : signal inventé (profil repos / 40 % / 95 % / 50 %, comme dans Simulink)
//   SOURCE_SIMULEE = 0 : vrai signal, sortie ENV du MyoWare sur la broche PIN_EMG
//
// Test sans application : installer « nRF Connect » sur un téléphone, se connecter à
// « Athletix-XXXX », s'abonner à la caractéristique abad0001, écrire 01 dans abad0002.
//
// Carte : n'importe quel ESP32 avec Bluetooth LE (ESP32 DevKit, ESP32-S3…), cœur Arduino
// « esp32 » d'Espressif. Bibliothèque BLE incluse dans ce cœur, rien à installer.

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SOURCE_SIMULEE 1
const int PIN_EMG = 1;            // sortie ENV du MyoWare : GPIO1 sur ESP32-S3, GPIO34 sur un ESP32 classique

// ---- UUID : identiques à lib/services/brassard/gatt_athletix.dart ----
#define UUID_SERVICE        "abad0000-b097-4a54-8315-c2971fc04ce6"
#define UUID_MESURE         "abad0001-b097-4a54-8315-c2971fc04ce6"
#define UUID_CONTROLE       "abad0002-b097-4a54-8315-c2971fc04ce6"
#define UUID_CONFIGURATION  "abad0003-b097-4a54-8315-c2971fc04ce6"
#define UUID_ETAT           "abad0004-b097-4a54-8315-c2971fc04ce6"

const char *VERSION_FIRMWARE = "0.1.0-test";

// ---- Commandes et états (GATT.md §5 et §7) ----
enum : uint8_t { CMD_DEMARRER = 0x01, CMD_ARRETER = 0x02, CMD_CALIBRER = 0x03, CMD_SEUIL = 0x04 };
enum : uint8_t { ETAT_REPOS = 0, ETAT_MESURE = 1, ETAT_CALIBRATION = 2, ETAT_ERREUR = 3 };
enum : uint8_t { ERR_AUCUNE = 0, ERR_SATURATION = 1, ERR_BATTERIE = 2, ERR_CALIBRATION = 3, ERR_COMMANDE = 4 };
const uint8_t BIT_ALERTE = 0x01, BIT_SATURATION = 0x02, BIT_CALIBRATION = 0x04;

// ---- Configuration (GATT.md §6) ----
uint8_t seuilHaut = 75;
uint8_t seuilBas = 70;
uint16_t refMvcMv = 1850;
uint8_t frequenceHz = 50;

// ---- État ----
BLECharacteristic *carMesure, *carConfiguration, *carEtat, *carBatterie;
volatile bool connecte = false;
uint8_t etat = ETAT_REPOS;
uint8_t codeErreur = ERR_AUCUNE;
bool alerte = false;
uint32_t debutCalibrationMs = 0;
uint16_t maxCalibrationMv = 0;
uint8_t batterie = 100;

// ---- Calcul RMS glissant sur 200 ms (100 échantillons à 500 Hz), comme dans la simulation ----
const int TAILLE_FENETRE = 100;
float carres[TAILLE_FENETRE];
float sommeCarres = 0;
int indexFenetre = 0;

// Écrit un entier en little-endian dans un tableau d'octets
void ecrire16(uint8_t *dst, uint16_t v) { dst[0] = v & 0xFF; dst[1] = v >> 8; }
void ecrire32(uint8_t *dst, uint32_t v) { for (int i = 0; i < 4; i++) dst[i] = (v >> (8 * i)) & 0xFF; }

void publierEtat() {
  uint8_t octets[2] = {etat, codeErreur};
  carEtat->setValue(octets, 2);
  if (connecte) carEtat->notify();
}

void publierConfiguration() {
  uint8_t octets[5];
  octets[0] = seuilHaut;
  octets[1] = seuilBas;
  ecrire16(&octets[2], refMvcMv);
  octets[4] = frequenceHz;
  carConfiguration->setValue(octets, 5);
}

void changerEtat(uint8_t nouvelEtat, uint8_t erreur = ERR_AUCUNE) {
  etat = nouvelEtat;
  codeErreur = erreur;
  publierEtat();
  Serial.printf("État : %u (erreur %u)\n", etat, codeErreur);
}

// Tension de l'enveloppe en mV (simulée ou lue sur le MyoWare)
uint16_t lireEnveloppeMv(uint32_t maintenantMs) {
#if SOURCE_SIMULEE
  static float lissee = 0;
  float t = fmodf(maintenantMs / 1000.0f, 18.0f);
  float vise = t < 3 ? 0 : t < 7 ? 40 : t < 10 ? 95 : t < 15 ? 50 : 0;    // % MVC
  if (etat == ETAT_CALIBRATION) vise = 100;                                // l'utilisateur serre au maximum
  lissee += (vise - lissee) * 0.03f;                                       // ≈ 0,07 s à 500 Hz
  float bruit = ((float)random(-300, 301) / 100.0f);                       // ± 3 %
  float pct = max(0.0f, lissee + bruit);
  return (uint16_t)(pct * 1850.0f / 100.0f);
#else
  (void)maintenantMs;
  return (uint16_t)analogReadMilliVolts(PIN_EMG);                         // 0 à ~3300 mV
#endif
}

// ---- Commandes reçues sur le point de contrôle ----
class ControleCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    uint8_t *d = c->getData();
    size_t n = c->getLength();
    if (n == 0) { changerEtat(ETAT_ERREUR, ERR_COMMANDE); return; }

    switch (d[0]) {
      case CMD_DEMARRER:
        alerte = false;
        changerEtat(ETAT_MESURE);
        break;
      case CMD_ARRETER:
        changerEtat(ETAT_REPOS);
        break;
      case CMD_CALIBRER:
        debutCalibrationMs = millis();
        maxCalibrationMv = 0;
        changerEtat(ETAT_CALIBRATION);
        break;
      case CMD_SEUIL:
        if (n == 3 && d[2] < d[1]) {
          seuilHaut = d[1];
          seuilBas = d[2];
          publierConfiguration();
          Serial.printf("Seuils : %u %% / %u %%\n", seuilHaut, seuilBas);
        } else {
          changerEtat(ETAT_ERREUR, ERR_COMMANDE);
        }
        break;
      default:
        changerEtat(ETAT_ERREUR, ERR_COMMANDE);
    }
  }
};

// Écriture directe de la configuration (5 octets) par l'application
class ConfigurationCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    if (c->getLength() != 5) {          // vérifier la taille AVANT de lire les octets
      changerEtat(ETAT_ERREUR, ERR_COMMANDE);
      publierConfiguration();
      return;
    }
    uint8_t *d = c->getData();
    uint16_t ref = d[2] | (d[3] << 8);
    if (d[1] < d[0] && ref >= 100 && ref <= 3300 && d[4] > 0 && d[4] <= 100) {
      seuilHaut = d[0];
      seuilBas = d[1];
      refMvcMv = ref;
      frequenceHz = d[4];
    } else {
      changerEtat(ETAT_ERREUR, ERR_COMMANDE);
    }
    publierConfiguration();   // remet la valeur valide en place
  }
};

class ServeurCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *) override {
    connecte = true;
    Serial.println("Application connectée");
  }
  void onDisconnect(BLEServer *) override {
    connecte = false;
    etat = ETAT_REPOS;                 // par sécurité : plus personne n'écoute
    Serial.println("Application déconnectée, nouvelle annonce");
    BLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < TAILLE_FENETRE; i++) carres[i] = 0;

  // Numéro de série dérivé de l'adresse de la puce : unique pour chaque carte
  char numeroSerie[16];
  snprintf(numeroSerie, sizeof(numeroSerie), "AX-%08llX", ESP.getEfuseMac() & 0xFFFFFFFFULL);
  char nom[20];
  snprintf(nom, sizeof(nom), "Athletix-%s", numeroSerie + strlen(numeroSerie) - 4);

  BLEDevice::init(nom);
  BLEServer *serveur = BLEDevice::createServer();
  serveur->setCallbacks(new ServeurCallbacks());

  // Device Information (0x180A) : numéro de série et firmware
  BLEService *infos = serveur->createService(BLEUUID((uint16_t)0x180A));
  infos->createCharacteristic(BLEUUID((uint16_t)0x2A25), BLECharacteristic::PROPERTY_READ)->setValue(numeroSerie);
  infos->createCharacteristic(BLEUUID((uint16_t)0x2A26), BLECharacteristic::PROPERTY_READ)->setValue(VERSION_FIRMWARE);
  infos->start();

  // Battery Service (0x180F)
  BLEService *serviceBatterie = serveur->createService(BLEUUID((uint16_t)0x180F));
  carBatterie = serviceBatterie->createCharacteristic(
      BLEUUID((uint16_t)0x2A19), BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  carBatterie->addDescriptor(new BLE2902());
  carBatterie->setValue(&batterie, 1);
  serviceBatterie->start();

  // Service Athletix EMG
  BLEService *service = serveur->createService(UUID_SERVICE);
  carMesure = service->createCharacteristic(UUID_MESURE, BLECharacteristic::PROPERTY_NOTIFY);
  carMesure->addDescriptor(new BLE2902());

  BLECharacteristic *carControle = service->createCharacteristic(UUID_CONTROLE, BLECharacteristic::PROPERTY_WRITE);
  carControle->setCallbacks(new ControleCallbacks());

  carConfiguration = service->createCharacteristic(
      UUID_CONFIGURATION, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  carConfiguration->setCallbacks(new ConfigurationCallbacks());
  publierConfiguration();

  carEtat = service->createCharacteristic(
      UUID_ETAT, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  carEtat->addDescriptor(new BLE2902());
  publierEtat();
  service->start();

  // Annonce : le service Athletix est visible pour que l'application puisse filtrer
  BLEAdvertising *annonce = BLEDevice::getAdvertising();
  annonce->addServiceUUID(UUID_SERVICE);
  annonce->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("Faux brassard prêt : %s (n° de série %s)\n", nom, numeroSerie);
}

void loop() {
  static uint32_t prochainEchantillonUs = micros();
  static uint32_t dernierEnvoiMs = 0;
  static uint32_t dernierBatterieMs = 0;

  // 1. Échantillonnage à 500 Hz et RMS glissant sur 200 ms
  if ((int32_t)(micros() - prochainEchantillonUs) < 0) return;
  prochainEchantillonUs += 2000;

  uint32_t maintenant = millis();
  float mv = lireEnveloppeMv(maintenant);
  sommeCarres += mv * mv - carres[indexFenetre];
  carres[indexFenetre] = mv * mv;
  indexFenetre = (indexFenetre + 1) % TAILLE_FENETRE;
  uint16_t rms = (uint16_t)sqrtf(max(0.0f, sommeCarres / TAILLE_FENETRE));

  // 2. Calibration : garder le maximum pendant 3 s
  if (etat == ETAT_CALIBRATION) {
    if (rms > maxCalibrationMv) maxCalibrationMv = rms;
    if (maintenant - debutCalibrationMs >= 3000) {
      if (maxCalibrationMv >= 100) {
        refMvcMv = maxCalibrationMv;
        publierConfiguration();
        Serial.printf("Calibration : 100 %% = %u mV\n", refMvcMv);
        changerEtat(ETAT_REPOS);
      } else {
        changerEtat(ETAT_ERREUR, ERR_CALIBRATION);
      }
    }
  }

  // 3. Envoi d'un paquet de 8 octets à la fréquence configurée (50 Hz par défaut)
  if (connecte && (etat == ETAT_MESURE || etat == ETAT_CALIBRATION) && maintenant - dernierEnvoiMs >= 1000u / frequenceHz) {
    dernierEnvoiMs = maintenant;
    uint32_t pct = (uint32_t)rms * 100 / refMvcMv;
    uint8_t intensite = pct > 255 ? 255 : pct;

    if (!alerte && intensite >= seuilHaut) alerte = true;     // hystérésis
    if (alerte && intensite < seuilBas) alerte = false;

    uint8_t drapeaux = 0;
    if (alerte) drapeaux |= BIT_ALERTE;
    if (mv >= 3250) drapeaux |= BIT_SATURATION;
    if (etat == ETAT_CALIBRATION) drapeaux |= BIT_CALIBRATION;

    uint8_t paquet[8];
    ecrire32(&paquet[0], maintenant);
    ecrire16(&paquet[4], rms);
    paquet[6] = intensite;
    paquet[7] = drapeaux;
    carMesure->setValue(paquet, 8);
    carMesure->notify();
  }

  // 4. Batterie simulée : -1 % par minute, notifiée
  if (maintenant - dernierBatterieMs >= 60000) {
    dernierBatterieMs = maintenant;
    if (batterie > 5) batterie--;
    carBatterie->setValue(&batterie, 1);
    if (connecte) carBatterie->notify();
  }
}
