// Athletix-Data — firmware FINAL du brassard EMG (SparkFun Thing Plus ESP32-S3 + MyoWare 2.0)
//
// Différences avec le firmware de test (hardware/faux-brassard-ble/) :
//   - lit le VRAI signal : sortie ENV du MyoWare 2.0 (via le Link Shield) sur PIN_EMG ;
//   - lit le VRAI niveau de batterie avec la jauge MAX17048 de la carte (I2C, adresse 0x36) ;
//   - demande un intervalle de connexion de 15 à 20 ms, nécessaire pour 50 mesures/s (GATT.md §4) ;
//   - signale la saturation prolongée (électrode ?) et la batterie faible (GATT.md §7) ;
//   - les calculs sont dans calcul_emg.h, testés sur ordinateur (tests/firmware/) ;
//   - 1.2 : source RAW (signal brut à 2 000 Hz) en plus de ENV, pour mesurer la FATIGUE par la
//     fréquence médiane (calcul_fatigue.h, caractéristique abad0006, FATIGUE.md). La FFT tourne
//     dans une tâche séparée sur le cœur 0, pour ne pas décaler l'échantillonnage.
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
#include "calcul_fatigue.h"

using namespace athletix;

// ---- Matériel ----
const int PIN_EMG = A0;                // sortie ENV du MyoWare : A0 = GPIO10 sur la Thing Plus ESP32-S3 (schéma SparkFun)
const uint8_t ADRESSE_JAUGE = 0x36;    // MAX17048, jauge de batterie de la Thing Plus ESP32-S3
const uint16_t SATURATION_MV = 3250;   // convertisseur quasiment au maximum (3,3 V)
const uint8_t BATTERIE_FAIBLE = 10;    // en %
// Source RAW : le signal brut du MyoWare est centré sur la moitié de l'alimentation (~1,65 V).
// Une moyenne sous ce seuil veut dire que l'interrupteur OUTPUT du Link Shield n'est pas sur RAW.
const uint16_t RAW_CENTRE_MIN_MV = 900;
const uint16_t RAW_CENTRE_MAX_MV = 2400;

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
#define UUID_FREQUENCE      "abad0006-b097-4a54-8315-c2971fc04ce6"

const char *VERSION_FIRMWARE = "1.2.0";  // 1.1 : natation ; 1.2 : source RAW et fatigue (fréquence médiane)

enum : uint8_t { CMD_DEMARRER = 0x01, CMD_ARRETER = 0x02, CMD_CALIBRER = 0x03, CMD_SEUIL = 0x04,
                 CMD_DEMARRER_HORS_LIGNE = 0x05, CMD_EFFACER_HORS_LIGNE = 0x06, CMD_SOURCE = 0x07 };
enum : uint8_t { ETAT_REPOS = 0, ETAT_MESURE = 1, ETAT_CALIBRATION = 2, ETAT_ERREUR = 3 };
enum : uint8_t { ERR_AUCUNE = 0, ERR_SATURATION = 1, ERR_BATTERIE = 2, ERR_CALIBRATION = 3, ERR_COMMANDE = 4,
                 ERR_SOURCE = 5 };  // 5 : source RAW demandée mais l'interrupteur du Link Shield semble sur ENV

// ---- État ----
BLECharacteristic *carMesure, *carConfiguration, *carEtat, *carHorsLigne, *carFrequence, *carBatterie = nullptr;
volatile bool connecte = false;
uint8_t etat = ETAT_REPOS;
uint8_t codeErreur = ERR_AUCUNE;
uint8_t batterie = 0;
bool jaugePresente = false;

Configuration config;
Alerte alerte;
Calibration calibration;
FenetreRms<100> fenetre;               // 200 ms à 500 Hz, comme la simulation Simulink
FenetreRms<400> fenetreRaw;            // 200 ms à 2 000 Hz (source RAW)
FiltreContinu filtreContinu;           // retire le ~1,65 V du signal brut
float moyenneRawMv = 0;                // moyenne lente du signal brut, en mV (contrôle de l'interrupteur)
SurveillanceSaturation saturation;
EnregistrementHorsLigne horsLigne;    // natation : résumé calculé dans le brassard

// Les commandes arrivent dans la tâche Bluetooth : on les transmet à loop() par ces variables
volatile int commandeEnAttente = -1;
volatile uint8_t seuilHautDemande = 0, seuilBasDemande = 0, sourceDemandee = 0;

// ---- Fatigue : fenêtres de 1 024 échantillons RAW analysées par une tâche à part ----
const int N_FFT = 1024;                         // 0,512 s à 2 000 Hz
AnalyseFrequence<N_FFT> *analyseFrequence;      // ~16 Ko, alloué au démarrage
float tampons[2][N_FFT];                        // l'un se remplit pendant que l'autre est analysé
int tamponEcrit = 0, indexTampon = 0;
uint32_t sommeIntensiteFenetre = 0;             // pour savoir si le muscle travaillait
// Échanges entre loop() (cœur 1) et la tâche d'analyse (cœur 0) : deux files FreeRTOS,
// qui copient les données et garantissent l'ordre entre les deux cœurs (pas de variable partagée).
struct FenetreAAnalyser {
  int8_t tampon;        // 0 ou 1
  uint8_t intensite;    // intensité moyenne sur la fenêtre, en %
  uint32_t finMs;
};
struct ResultatAEnvoyer {
  uint32_t finMs;
  float mdfHz, mnfHz;   // 0 = pas de valeur (muscle au repos)
};
QueueHandle_t fileFenetres, fileResultats;
uint32_t debutCompteMs = 0, nbEchantillons = 0;  // contrôle du rythme d'échantillonnage
bool analyseEnCours = false;  // une fenêtre envoyée dont le résultat n'est pas encore revenu (loop() seulement)

void tacheFrequence(void *) {
  FenetreAAnalyser f;
  for (;;) {
    if (xQueueReceive(fileFenetres, &f, portMAX_DELAY) != pdTRUE) continue;
    ResultatFrequence r = analyseFrequence->analyser(tampons[f.tampon]);
    bool travail = r.valide && f.intensite >= SEUIL_INTENSITE_FATIGUE;
    ResultatAEnvoyer e = {f.finMs, travail ? r.mdfHz : 0, travail ? r.mnfHz : 0};
    xQueueSend(fileResultats, &e, portMAX_DELAY);  // loop() vide la file à chaque tour
  }
}

void publierEtat() {
  uint8_t octets[2] = {etat, codeErreur};
  carEtat->setValue(octets, 2);
  if (connecte) carEtat->notify();
}

void publierConfiguration() {
  uint8_t octets[Configuration::TAILLE_LUE];
  config.seuilHaut = alerte.seuilHaut();
  config.seuilBas = alerte.seuilBas();
  config.encoder(octets);
  carConfiguration->setValue(octets, Configuration::TAILLE_LUE);
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
    if (d[0] == CMD_SOURCE) {
      if (n != 2 || d[1] > SOURCE_RAW) {
        commandeEnAttente = 0xFF;
        return;
      }
      sourceDemandee = d[1];
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

// Nouvelle mesure : la fenêtre de fatigue repart de zéro (pas de reste d'une calibration)
void viderFenetreFatigue() {
  indexTampon = 0;
  sommeIntensiteFenetre = 0;
}

// La référence 100 % n'a pas la même échelle en ENV (enveloppe) et en RAW (valeur efficace du
// signal brut) : une nouvelle calibration est nécessaire après un changement de source.
void changerSource(uint8_t source) {
  if (source == config.source) return;
  config.source = source;
  config.refMvcMv = source == SOURCE_RAW ? 500 : 1850;  // valeurs d'attente : calibrer ensuite
  fenetre.vider();
  fenetreRaw.vider();
  filtreContinu.vider();
  moyenneRawMv = 0;
  debutCompteMs = 0;  // le rythme change : on recommence à compter
  viderFenetreFatigue();
  publierConfiguration();
  Serial.printf("Source : %s (interrupteur OUTPUT du Link Shield sur %s), calibrer de nouveau\n",
                source == SOURCE_RAW ? "RAW" : "ENV", source == SOURCE_RAW ? "RAW" : "ENV");
}

void executerCommande(int commande) {
  switch (commande) {
    case CMD_DEMARRER:
      viderFenetreFatigue();
      alerte.reinitialiser();
      changerEtat(ETAT_MESURE);
      break;
    case CMD_ARRETER:
      horsLigne.terminer(millis());
      if (etat != ETAT_REPOS) changerEtat(ETAT_REPOS);
      break;
    case CMD_DEMARRER_HORS_LIGNE:
      viderFenetreFatigue();
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
    case CMD_SOURCE:
      // Seulement au repos : changer de signal en pleine séance mélangerait deux échelles
      if (etat != ETAT_REPOS) {
        changerEtat(ETAT_ERREUR, ERR_COMMANDE);
        break;
      }
      changerSource(sourceDemandee);
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
  carFrequence = service->createCharacteristic(UUID_FREQUENCE, BLECharacteristic::PROPERTY_NOTIFY);
  carFrequence->addDescriptor(new BLE2902());
  service->start();

  // Analyse de fréquence (fatigue) : tâche de faible priorité sur le cœur 0 (loop() tourne sur le cœur 1)
  analyseFrequence = new AnalyseFrequence<N_FFT>(2000.0f);
  fileFenetres = xQueueCreate(1, sizeof(FenetreAAnalyser));
  fileResultats = xQueueCreate(4, sizeof(ResultatAEnvoyer));
  xTaskCreatePinnedToCore(tacheFrequence, "frequence", 4096, nullptr, 1, nullptr, 0);

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

  // 1. Échantillonnage et RMS glissante sur 200 ms :
  //    ENV : 500 Hz (toutes les 2 ms) ; RAW : 2 000 Hz (toutes les 0,5 ms), composante continue retirée
  const bool raw = config.source == SOURCE_RAW;
  if ((int32_t)(micros() - prochainEchantillonUs) < 0) return;
  prochainEchantillonUs += raw ? 500 : 2000;
  uint32_t maintenant = millis();
  uint16_t mv = (uint16_t)analogReadMilliVolts(PIN_EMG);
  uint16_t rms;

  // Contrôle du rythme : nombre d'échantillons pris chaque seconde (2 000 attendus en RAW, 500 en ENV).
  // S'il en manque (loop() trop lente sur la vraie carte), la fréquence médiane serait fausse : on le dit.
  nbEchantillons++;
  if (maintenant - debutCompteMs >= 1000) {
    uint32_t attendu = raw ? 2000 : 500;
    if (debutCompteMs != 0 && nbEchantillons < attendu * 97 / 100) {
      Serial.printf("Avertissement : %lu échantillons/s au lieu de %lu (loop() trop lente)\n",
                    (unsigned long)nbEchantillons, (unsigned long)attendu);
    }
    debutCompteMs = maintenant;
    nbEchantillons = 0;
  }
  if (raw) {
    float ac = filtreContinu.filtrer(mv);
    rms = fenetreRaw.ajouter(ac);
    moyenneRawMv = moyenneRawMv == 0 ? mv : moyenneRawMv + (mv - moyenneRawMv) / 2000.0f;  // moyenne lente (~1 s)
    // Fenêtre pour la fatigue : quand elle est pleine, elle passe à la tâche d'analyse
    tampons[tamponEcrit][indexTampon++] = ac;
    sommeIntensiteFenetre += intensitePct(rms, config.refMvcMv);
    if (indexTampon == N_FFT) {
      // Une seule analyse à la fois : si la précédente n'est pas revenue (elle prend quelques ms
      // pour 512 ms de signal, ça ne devrait pas arriver), cette fenêtre est sautée. Ainsi le
      // tampon en cours d'analyse n'est jamais réécrit.
      FenetreAAnalyser f = {(int8_t)tamponEcrit, (uint8_t)(sommeIntensiteFenetre / N_FFT), maintenant};
      if (etat == ETAT_MESURE && !analyseEnCours && xQueueSend(fileFenetres, &f, 0) == pdTRUE) {
        analyseEnCours = true;
        tamponEcrit ^= 1;
      }
      indexTampon = 0;
      sommeIntensiteFenetre = 0;
    }
  } else {
    rms = fenetre.ajouter(mv);
  }

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

  // 3 bis. Source RAW : le signal brut doit tourner autour de ~1,65 V. Sinon, l'interrupteur
  //        OUTPUT du Link Shield est sans doute resté sur ENV (vérifié une fois par seconde).
  static uint32_t dernierControleSourceMs = 0;
  if (raw && maintenant - dernierControleSourceMs >= 1000) {
    dernierControleSourceMs = maintenant;
    bool horsCentre = moyenneRawMv > 0 && (moyenneRawMv < RAW_CENTRE_MIN_MV || moyenneRawMv > RAW_CENTRE_MAX_MV);
    if (horsCentre) signaler(ERR_SOURCE);
    else if (codeErreur == ERR_SOURCE) signaler(ERR_AUCUNE);
  }

  // 3 ter. Fatigue : résultat de la tâche d'analyse (2 par seconde), envoyé sur abad0006
  ResultatAEnvoyer res;
  if (xQueueReceive(fileResultats, &res, 0) == pdTRUE) {
    analyseEnCours = false;
    if (JOURNAL_SERIE) Serial.printf("F,%lu,%.1f,%.1f\n", (unsigned long)res.finMs, res.mdfHz, res.mnfHz);
    if (connecte) {
      uint8_t paquet[8];
      encoderFrequence(paquet, res.finMs, res.mdfHz, res.mnfHz);
      carFrequence->setValue(paquet, 8);
      carFrequence->notify();
    }
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
