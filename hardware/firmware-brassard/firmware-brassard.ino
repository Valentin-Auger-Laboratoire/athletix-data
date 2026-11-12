// Athletix-Data — firmware FINAL du brassard EMG (SparkFun Thing Plus ESP32-S3 + MyoWare 2.0)
//
// Différences avec le firmware de test (hardware/faux-brassard-ble/) :
//   - lit le VRAI signal : sortie ENV du MyoWare 2.0 (via le Link Shield) sur PIN_EMG ;
//   - lit le VRAI niveau de batterie avec la jauge MAX17048 de la carte (I2C, adresse 0x36) ;
//   - demande un intervalle de connexion de 15 à 20 ms, nécessaire pour 50 mesures/s (GATT.md §4) ;
//   - signale la saturation prolongée (électrode ?) et la batterie faible (GATT.md §7) ;
//   - les calculs sont dans calcul_emg.h, testés sur ordinateur (tests/firmware/).
//
// ⚠️ Écrit sans le matériel. Avant de l'utiliser : vérifier PIN_EMG et les broches I2C sur la fiche
// SparkFun de la carte, et suivre le protocole de test (hardware/PROTOCOLE-DE-TEST.md).
//
// Arduino IDE : cœur « esp32 » d'Espressif, carte « SparkFun ESP32-S3 Thing Plus ».
// Aucune bibliothèque à installer (BLE et Wire sont inclus dans le cœur).

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

#include "calcul_emg.h"

using namespace athletix;

// ---- Matériel ----
const int PIN_EMG = A0;                // sortie ENV du MyoWare : A0 = GPIO10 sur la Thing Plus ESP32-S3 (schéma SparkFun)
const uint8_t ADRESSE_JAUGE = 0x36;    // MAX17048, jauge de batterie de la Thing Plus ESP32-S3
const uint16_t SATURATION_MV = 3250;   // convertisseur quasiment au maximum (3,3 V)
const uint8_t BATTERIE_FAIBLE = 10;    // en %

// Journal des mesures sur le port USB (CSV, 50 lignes/s pendant une mesure) pour comparer
// le brassard à la simulation : mesures/capturer.py puis mesures/comparer_simulation.py.
// Une ligne : "M,ms,mV brut,RMS mV,intensité %,alerte". Les autres messages ne commencent pas par "M,".
const bool JOURNAL_SERIE = true;

// ---- UUID : identiques à lib/services/brassard/gatt_athletix.dart ----
#define UUID_SERVICE        "abad0000-b097-4a54-8315-c2971fc04ce6"
#define UUID_MESURE         "abad0001-b097-4a54-8315-c2971fc04ce6"
#define UUID_CONTROLE       "abad0002-b097-4a54-8315-c2971fc04ce6"
#define UUID_CONFIGURATION  "abad0003-b097-4a54-8315-c2971fc04ce6"
#define UUID_ETAT           "abad0004-b097-4a54-8315-c2971fc04ce6"
#define UUID_HORS_LIGNE     "abad0005-b097-4a54-8315-c2971fc04ce6"

const char *VERSION_FIRMWARE = "1.1.0";  // 1.1 : enregistrement sans connexion (natation)

enum : uint8_t { CMD_DEMARRER = 0x01, CMD_ARRETER = 0x02, CMD_CALIBRER = 0x03, CMD_SEUIL = 0x04,
                 CMD_DEMARRER_HORS_LIGNE = 0x05, CMD_EFFACER_HORS_LIGNE = 0x06 };
enum : uint8_t { ETAT_REPOS = 0, ETAT_MESURE = 1, ETAT_CALIBRATION = 2, ETAT_ERREUR = 3 };
enum : uint8_t { ERR_AUCUNE = 0, ERR_SATURATION = 1, ERR_BATTERIE = 2, ERR_CALIBRATION = 3, ERR_COMMANDE = 4 };

// ---- État ----
BLECharacteristic *carMesure, *carConfiguration, *carEtat, *carHorsLigne, *carBatterie = nullptr;
volatile bool connecte = false;
uint8_t etat = ETAT_REPOS;
uint8_t codeErreur = ERR_AUCUNE;
uint8_t batterie = 0;
bool jaugePresente = false;

Configuration config;
Alerte alerte;
Calibration calibration;
FenetreRms<100> fenetre;               // 200 ms à 500 Hz, comme la simulation Simulink
SurveillanceSaturation saturation;
EnregistrementHorsLigne horsLigne;    // natation : résumé calculé dans le brassard

// Les commandes arrivent dans la tâche Bluetooth : on les transmet à loop() par ces variables
volatile int commandeEnAttente = -1;
volatile uint8_t seuilHautDemande = 0, seuilBasDemande = 0;

void publierEtat() {
  uint8_t octets[2] = {etat, codeErreur};
  carEtat->setValue(octets, 2);
  if (connecte) carEtat->notify();
}

void publierConfiguration() {
  uint8_t octets[5];
  config.seuilHaut = alerte.seuilHaut();
  config.seuilBas = alerte.seuilBas();
  config.encoder(octets);
  carConfiguration->setValue(octets, 5);
}

void changerEtat(uint8_t nouvelEtat, uint8_t erreur = ERR_AUCUNE) {
  etat = nouvelEtat;
  codeErreur = erreur;
  publierEtat();
  Serial.printf("État : %u (erreur %u)\n", etat, codeErreur);
}

// Signale un problème sans arrêter la mesure (l'état reste le même, seul le code change)
void signaler(uint8_t erreur) {
  if (codeErreur == erreur) return;
  codeErreur = erreur;
  publierEtat();
  Serial.printf("Avertissement : code %u\n", erreur);
}

// ---- Jauge de batterie MAX17048 : registre SOC (0x04), octet de poids fort = % ----
bool lireBatterie(uint8_t &pourcentage) {
  Wire.beginTransmission(ADRESSE_JAUGE);
  Wire.write(0x04);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)ADRESSE_JAUGE, 2) != 2) return false;
  uint8_t fort = Wire.read();
  Wire.read();  // octet de poids faible : 1/256 de % (inutile ici)
  pourcentage = fort > 100 ? 100 : fort;
  return true;
}

// ---- Bluetooth ----
class ControleCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    uint8_t *d = c->getData();
    size_t n = c->getLength();
    if (n == 0) {
      commandeEnAttente = 0xFF;
      return;
    }
    if (d[0] == CMD_SEUIL) {
      if (n != 3) {
        commandeEnAttente = 0xFF;
        return;
      }
      seuilHautDemande = d[1];
      seuilBasDemande = d[2];
    }
    commandeEnAttente = d[0];
  }
};

class ConfigurationCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    Configuration nouvelle = config;
    if (nouvelle.appliquer(c->getData(), c->getLength()) && alerte.regler(nouvelle.seuilHaut, nouvelle.seuilBas)) {
      config = nouvelle;
    } else {
      changerEtat(ETAT_ERREUR, ERR_COMMANDE);
    }
    publierConfiguration();  // remet toujours une valeur valide en place
  }
};

// Résumé hors ligne : la valeur est recalculée au moment où l'application la lit
class HorsLigneCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic *c) override {
    static uint8_t octets[EnregistrementHorsLigne::TAILLE_MAX];
    unsigned n = horsLigne.encoder(octets, millis());
    c->setValue(octets, n);
  }
};

class ServeurCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *serveur, esp_ble_gatts_cb_param_t *param) override {
    connecte = true;
    // Intervalle 15–20 ms (unités de 1,25 ms), latence 0, délai de coupure 4 s (unités de 10 ms).
    // C'est le téléphone qui décide : s'il refuse, l'application accepte les paquets groupés.
    serveur->updateConnParams(param->connect.remote_bda, 12, 16, 0, 400);
    Serial.println("Application connectée");
  }
  void onDisconnect(BLEServer *) override {
    connecte = false;
    // Plus personne n'écoute : on arrête la mesure, SAUF pendant un enregistrement sans connexion
    // (natation) qui continue jusqu'à ARRÊTER ou à l'arrêt automatique.
    if (horsLigne.etat() != EnregistrementHorsLigne::EN_COURS) commandeEnAttente = CMD_ARRETER;
    Serial.println("Application déconnectée, nouvelle annonce");
    BLEDevice::startAdvertising();
  }
};

void executerCommande(int commande) {
  switch (commande) {
    case CMD_DEMARRER:
      alerte.reinitialiser();
      changerEtat(ETAT_MESURE);
      break;
    case CMD_ARRETER:
      horsLigne.terminer(millis());
      if (etat != ETAT_REPOS) changerEtat(ETAT_REPOS);
      break;
    case CMD_DEMARRER_HORS_LIGNE:
      alerte.reinitialiser();
      horsLigne.demarrer(millis());
      changerEtat(ETAT_MESURE);
      Serial.println("Enregistrement sans connexion démarré");
      break;
    case CMD_EFFACER_HORS_LIGNE:
      horsLigne.effacer();  // l'application l'a bien reçu et enregistré
      break;
    case CMD_CALIBRER:
      calibration.demarrer(millis());
      changerEtat(ETAT_CALIBRATION);
      break;
    case CMD_SEUIL:
      if (alerte.regler(seuilHautDemande, seuilBasDemande)) {
        publierConfiguration();
        Serial.printf("Seuils : %u %% / %u %%\n", alerte.seuilHaut(), alerte.seuilBas());
      } else {
        changerEtat(ETAT_ERREUR, ERR_COMMANDE);
      }
      break;
    default:
      changerEtat(ETAT_ERREUR, ERR_COMMANDE);
  }
}

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_EMG, ADC_11db);  // plage 0 à ~3,1 V

  Wire.begin();  // I2C par défaut de la carte : SDA = GPIO8, SCL = GPIO9 (bus Qwiic, partagé avec la jauge)
  jaugePresente = lireBatterie(batterie);
  Serial.printf("Jauge de batterie : %s\n", jaugePresente ? "trouvée" : "absente");

  // Numéro de série dérivé de l'adresse de la puce : unique pour chaque carte
  char numeroSerie[16];
  snprintf(numeroSerie, sizeof(numeroSerie), "AX-%08llX", ESP.getEfuseMac() & 0xFFFFFFFFULL);
  char nom[20];
  snprintf(nom, sizeof(nom), "Athletix-%s", numeroSerie + strlen(numeroSerie) - 4);

  BLEDevice::init(nom);
  BLEServer *serveur = BLEDevice::createServer();
  serveur->setCallbacks(new ServeurCallbacks());

  BLEService *infos = serveur->createService(BLEUUID((uint16_t)0x180A));
  infos->createCharacteristic(BLEUUID((uint16_t)0x2A25), BLECharacteristic::PROPERTY_READ)->setValue(numeroSerie);
  infos->createCharacteristic(BLEUUID((uint16_t)0x2A26), BLECharacteristic::PROPERTY_READ)->setValue(VERSION_FIRMWARE);
  infos->start();

  // Service batterie seulement si la jauge répond (sinon l'application affiche « — »)
  if (jaugePresente) {
    BLEService *serviceBatterie = serveur->createService(BLEUUID((uint16_t)0x180F));
    carBatterie = serviceBatterie->createCharacteristic(
        BLEUUID((uint16_t)0x2A19), BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    carBatterie->addDescriptor(new BLE2902());
    carBatterie->setValue(&batterie, 1);
    serviceBatterie->start();
  }

  BLEService *service = serveur->createService(UUID_SERVICE);
  carMesure = service->createCharacteristic(UUID_MESURE, BLECharacteristic::PROPERTY_NOTIFY);
  carMesure->addDescriptor(new BLE2902());
  BLECharacteristic *carControle = service->createCharacteristic(UUID_CONTROLE, BLECharacteristic::PROPERTY_WRITE);
  carControle->setCallbacks(new ControleCallbacks());
  carConfiguration = service->createCharacteristic(
      UUID_CONFIGURATION, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  carConfiguration->setCallbacks(new ConfigurationCallbacks());
  publierConfiguration();
  carEtat = service->createCharacteristic(UUID_ETAT, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  carEtat->addDescriptor(new BLE2902());
  publierEtat();
  carHorsLigne = service->createCharacteristic(UUID_HORS_LIGNE, BLECharacteristic::PROPERTY_READ);
  carHorsLigne->setCallbacks(new HorsLigneCallbacks());
  service->start();

  BLEAdvertising *annonce = BLEDevice::getAdvertising();
  annonce->addServiceUUID(UUID_SERVICE);
  annonce->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("Brassard prêt : %s (n° de série %s, firmware %s)\n", nom, numeroSerie, VERSION_FIRMWARE);
}

void loop() {
  static uint32_t prochainEchantillonUs = micros();
  static uint32_t dernierEnvoiMs = 0;
  static uint32_t derniereBatterieMs = 0;

  // 0. Commande reçue en Bluetooth (traitée ici, pas dans la tâche Bluetooth)
  int commande = commandeEnAttente;
  if (commande >= 0) {
    commandeEnAttente = -1;
    executerCommande(commande);
  }

  // 1. Échantillonnage à 500 Hz (toutes les 2 ms) et RMS glissante sur 200 ms
  if ((int32_t)(micros() - prochainEchantillonUs) < 0) return;
  prochainEchantillonUs += 2000;
  uint32_t maintenant = millis();
  uint16_t mv = (uint16_t)analogReadMilliVolts(PIN_EMG);
  uint16_t rms = fenetre.ajouter(mv);

  // 2. Calibration : maximum de la RMS pendant 3 s
  if (etat == ETAT_CALIBRATION) {
    calibration.ajouter(rms);
    if (calibration.terminee(maintenant)) {
      uint16_t ref = calibration.terminer();
      if (ref > 0) {
        config.refMvcMv = ref;
        publierConfiguration();
        Serial.printf("Calibration : 100 %% = %u mV\n", ref);
        changerEtat(ETAT_REPOS);
      } else {
        changerEtat(ETAT_ERREUR, ERR_CALIBRATION);
      }
    }
  }

  // 3. Saturation prolongée : électrode décollée ou gain trop fort
  if (saturation.mettreAJour(mv >= SATURATION_MV, maintenant)) {
    signaler(ERR_SATURATION);
  } else if (codeErreur == ERR_SATURATION) {
    signaler(ERR_AUCUNE);
  }

  // 4. Mesure à la fréquence configurée (50 Hz par défaut) : paquet de 8 octets si l'application
  //    écoute, et résumé gardé dans le brassard pendant un enregistrement sans connexion.
  if ((etat == ETAT_MESURE || etat == ETAT_CALIBRATION) && maintenant - dernierEnvoiMs >= 1000u / config.frequenceHz) {
    dernierEnvoiMs = maintenant;
    uint8_t intensite = intensitePct(rms, config.refMvcMv);
    uint8_t drapeaux = 0;
    bool enAlerte = etat == ETAT_MESURE && alerte.mettreAJour(intensite);
    if (enAlerte) drapeaux |= BIT_ALERTE;
    if (mv >= SATURATION_MV) drapeaux |= BIT_SATURATION;
    if (etat == ETAT_CALIBRATION) drapeaux |= BIT_CALIBRATION;
    if (etat == ETAT_MESURE && horsLigne.etat() == EnregistrementHorsLigne::EN_COURS) {
      horsLigne.ajouter(maintenant, intensite, enAlerte);
      if (horsLigne.etat() == EnregistrementHorsLigne::TERMINE) {
        Serial.println("Enregistrement sans connexion terminé (5 min de repos)");
        changerEtat(ETAT_REPOS);  // économise la batterie en attendant la lecture
      }
    }
    if (JOURNAL_SERIE && etat == ETAT_MESURE) {
      Serial.printf("M,%lu,%u,%u,%u,%u\n", (unsigned long)maintenant, mv, rms, intensite, enAlerte ? 1 : 0);
    }
    if (connecte) {
      uint8_t paquet[8];
      encoderMesure(paquet, maintenant, rms, intensite, drapeaux);
      carMesure->setValue(paquet, 8);
      carMesure->notify();
    }
  }

  // 5. Batterie : lue toutes les 30 s, notifiée, alerte sous 10 %
  if (jaugePresente && maintenant - derniereBatterieMs >= 30000) {
    derniereBatterieMs = maintenant;
    uint8_t niveau;
    if (lireBatterie(niveau)) {
      batterie = niveau;
      carBatterie->setValue(&batterie, 1);
      if (connecte) carBatterie->notify();
      if (batterie < BATTERIE_FAIBLE) signaler(ERR_BATTERIE);
    }
  }
}
