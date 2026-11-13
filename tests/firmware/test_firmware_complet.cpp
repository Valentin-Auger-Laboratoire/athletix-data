// Fait TOURNER le firmware complet du brassard sur ordinateur, avec des imitations des
// bibliothèques ESP32 (tests/firmware/imitations/) et un muscle simulé sur l'entrée A0.
//
//   g++ -std=c++17 -pthread -Wall -Wextra -I tests/firmware/imitations -I hardware/firmware-brassard
//       tests/firmware/test_firmware_complet.cpp -o /tmp/test_firmware && /tmp/test_firmware
//
// Vérifie le programme ENTIER (setup, loop, commandes Bluetooth, tâche d'analyse) : séance en
// enveloppe (ENV), calibration, passage en signal brut (RAW) et fatigue, interrupteur mal placé,
// natation sans connexion. Ne remplace pas la compilation pour l'ESP32 ni l'essai sur la carte.
#include "Arduino.h"

#include "firmware-brassard.ino"

#include <unistd.h>

#include <chrono>

static int ok = 0, ko = 0;
#define VERIFIER(cond, nom)                                 \
  do {                                                      \
    if (cond) {                                             \
      ok++;                                                 \
    } else {                                                \
      ko++;                                                 \
      printf("ÉCHEC : %s (ligne %d)\n", nom, __LINE__);    \
    }                                                       \
  } while (0)

const char *U_MESURE = "abad0001-b097-4a54-8315-c2971fc04ce6";
const char *U_CONTROLE = "abad0002-b097-4a54-8315-c2971fc04ce6";
const char *U_CONFIG = "abad0003-b097-4a54-8315-c2971fc04ce6";
const char *U_ETAT = "abad0004-b097-4a54-8315-c2971fc04ce6";
const char *U_HORS_LIGNE = "abad0005-b097-4a54-8315-c2971fc04ce6";
const char *U_FREQUENCE = "abad0006-b097-4a54-8315-c2971fc04ce6";

BLECharacteristic *car(const char *u) { return banc::caracteristique(u); }

// Avance le temps simulé de « secondes », en appelant loop() toutes les 20 µs.
// Après chaque fenêtre passée à la tâche d'analyse, on attend (en temps réel) qu'elle ait fini :
// l'ordinateur simule bien plus vite que le temps réel.
void avancer(double secondes) {
  uint64_t fin = banc::micros + (uint64_t)(secondes * 1e6);
  while (banc::micros < fin) {
    banc::micros += 20;
    loop();
    // Une fenêtre vient d'être envoyée à la tâche : attendre (en temps réel) que son résultat revienne
    if (analyseEnCours) {
      auto limite = std::chrono::steady_clock::now() + std::chrono::seconds(2);
      while (elementsEnAttente(fileResultats) == 0 && std::chrono::steady_clock::now() < limite) std::this_thread::yield();
    }
  }
}

void connecter() {
  esp_ble_gatts_cb_param_t p{};
  BLEDevice::serveur()->rappels->onConnect(BLEDevice::serveur(), &p);
}
void deconnecter() { BLEDevice::serveur()->rappels->onDisconnect(BLEDevice::serveur()); }
void commande(std::vector<uint8_t> octets) { car(U_CONTROLE)->ecrireDepuisApplication(octets); }

struct Mesure {
  uint32_t ms;
  uint16_t rms;
  uint8_t pct, drapeaux;
};
std::vector<Mesure> mesures(size_t depuis = 0) {
  std::vector<Mesure> r;
  auto &n = car(U_MESURE)->notifications;
  for (size_t i = depuis; i < n.size(); i++) {
    auto &o = n[i];
    r.push_back({(uint32_t)(o[0] | o[1] << 8 | o[2] << 16 | (uint32_t)o[3] << 24), (uint16_t)(o[4] | o[5] << 8), o[6], o[7]});
  }
  return r;
}
uint8_t codeLu() { return car(U_ETAT)->valeur.size() > 1 ? car(U_ETAT)->valeur[1] : 255; }
uint8_t etatLu() { return car(U_ETAT)->valeur.empty() ? 255 : car(U_ETAT)->valeur[0]; }
uint16_t refLue() { auto &v = car(U_CONFIG)->valeur; return (uint16_t)(v[2] | v[3] << 8); }

// ---- Muscle simulé ----
struct Hasard {
  uint32_t etat = 2026;
  double uniforme() { etat = etat * 1664525u + 1013904223u; return (etat + 0.5) / 4294967296.0; }
  double gauss() { double u = uniforme(), v = uniforme(); return sqrt(-2 * log(u)) * cos(2 * M_PI * v); }
};
// Passe-bande du 2e ordre dont la fréquence centrale peut changer (spectre qui glisse = fatigue)
struct BruitEmg {
  Hasard h;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0, dernierT = -1, valeur = 0;
  double echantillon(double t, double fc, double fe) {
    if (t == dernierT) return valeur;  // le firmware lit une fois par échantillon
    dernierT = t;
    double w = 2 * M_PI * fc / fe, alpha = sin(w) / (2 * 0.7), a0 = 1 + alpha;
    double b0 = alpha / a0, b2 = -alpha / a0, a1 = -2 * cos(w) / a0, a2 = (1 - alpha) / a0;
    double x = h.gauss();
    double y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x; y2 = y1; y1 = y;
    return valeur = y;
  }
};

int main() {
  // ---------------------------------------------------------------- démarrage
  banc::signalMv = [](double) { return 30.0; };
  setup();
  VERIFIER(BLEDevice::nomAppareil() == "Athletix-E5F6", "nom annoncé dérivé du numéro de série");
  VERIFIER(car(U_MESURE) && car(U_CONTROLE) && car(U_CONFIG) && car(U_ETAT) && car(U_HORS_LIGNE) && car(U_FREQUENCE),
           "les 6 caractéristiques du service existent");
  VERIFIER(car(U_CONFIG)->valeur.size() == 6 && car(U_CONFIG)->valeur[5] == SOURCE_ENV, "configuration lue sur 6 octets, source ENV");
  VERIFIER(etatLu() == ETAT_REPOS, "au repos après le démarrage");
  auto *version = banc::caracteristique("00002a26-0000-1000-8000-00805f9b34fb");
  VERIFIER(version && std::string(version->valeur.begin(), version->valeur.end()) == "1.2.0", "version 1.2.0 publiée");

  connecter();
  VERIFIER(BLEDevice::serveur()->intervalleMin == 12 && BLEDevice::serveur()->intervalleMax == 16, "intervalle de connexion 15–20 ms demandé");

  // ---------------------------------------------------------------- séance ENV
  // repos 2 s (50 mV), effort moyen 3 s (1 000 mV ≈ 54 %), effort fort 3 s (1 700 mV ≈ 92 %), repos 2 s
  banc::signalMv = [](double t) {
    static double debut = -1;
    if (debut < 0) debut = t;
    double u = t - debut;
    return u < 2 ? 50.0 : u < 5 ? 1000.0 : u < 8 ? 1700.0 : 50.0;
  };
  commande({0x01});
  avancer(10);
  commande({0x02});
  auto m = mesures();
  VERIFIER(m.size() >= 480 && m.size() <= 510, "≈ 50 mesures par seconde pendant 10 s");
  int alertes = 0, maxPct = 0;
  bool avant = false;
  for (auto &x : m) {
    bool a = x.drapeaux & BIT_ALERTE;
    if (a && !avant) alertes++;
    avant = a;
    if (x.pct > maxPct) maxPct = x.pct;
  }
  VERIFIER(alertes == 1, "une seule alerte pendant l'effort fort");
  VERIFIER(maxPct >= 90 && maxPct <= 94, "effort fort ≈ 92 % de la référence 1 850 mV");
  VERIFIER(car(U_FREQUENCE)->notifications.empty(), "pas de fréquence en source ENV");
  int lignesM = 0;
  for (auto &l : banc::lignesSerie) lignesM += l.rfind("M,", 0) == 0;
  VERIFIER(lignesM >= 480, "journal série « M,… » pour la comparaison avec la simulation");

  // ---------------------------------------------------------------- commandes refusées
  commande({0x07, 0x05});
  avancer(0.01);
  VERIFIER(codeLu() == ERR_COMMANDE, "source inconnue refusée");
  commande({0x01});
  avancer(0.1);
  commande({0x07, 0x01});
  avancer(0.01);
  VERIFIER(codeLu() == ERR_COMMANDE, "changement de source refusé pendant une mesure");
  commande({0x02});
  avancer(0.1);

  // ---------------------------------------------------------------- passage en RAW
  static BruitEmg bruit;
  static double amplitude = 5, fc = 110;  // au repos : quelques mV de bruit
  banc::signalMv = [](double t) { return 1650 + amplitude * bruit.echantillon(t, fc, 2000) * 3.0; };
  commande({0x07, 0x01});
  avancer(0.01);
  VERIFIER(car(U_CONFIG)->valeur[5] == SOURCE_RAW, "source RAW publiée dans la configuration");
  VERIFIER(refLue() == 500, "référence remise à une valeur d'attente : il faut calibrer");
  avancer(2);
  VERIFIER(codeLu() != ERR_SOURCE, "signal centré sur 1,65 V : interrupteur bien sur RAW");

  // Calibration en serrant fort (amplitude 300)
  amplitude = 300;
  commande({0x03});
  avancer(3.2);
  uint16_t ref = refLue();
  VERIFIER(etatLu() == ETAT_REPOS && ref > 300 && ref < 1400, "calibration RAW : référence = RMS du signal brut");

  // Effort soutenu 60 s : le spectre glisse de 110 à 80 Hz (fatigue simulée)
  size_t avantF = car(U_FREQUENCE)->notifications.size();
  size_t avantM = car(U_MESURE)->notifications.size();
  amplitude = 5;
  avancer(1);  // on relâche le muscle après la calibration
  commande({0x01});
  avancer(2);  // repos : pas de fréquence (muscle au repos)
  size_t pendantRepos = car(U_FREQUENCE)->notifications.size();
  amplitude = 180;
  for (int s = 0; s < 60; s++) {
    fc = 110 - 30.0 * s / 60;
    avancer(1);
  }
  commande({0x02});
  avancer(0.1);
  auto &nf = car(U_FREQUENCE)->notifications;
  std::vector<double> mdf;
  int nuls = 0;
  for (size_t i = avantF; i < nf.size(); i++) {
    double v = (nf[i][4] | nf[i][5] << 8) / 10.0;
    if (v == 0) nuls++;
    else mdf.push_back(v);
  }
  size_t nbFreq = nf.size() - avantF;
  VERIFIER(nbFreq >= 115 && nbFreq <= 125, "≈ 2 valeurs de fréquence par seconde");
  bool reposSansValeur = true;
  for (size_t i = avantF; i < pendantRepos; i++) reposSansValeur &= (nf[i][4] | nf[i][5]) == 0;
  VERIFIER(reposSansValeur, "au repos, la fréquence est envoyée à 0 (pas de valeur)");
  double debut = 0, fin = 0;
  int n10 = 0;
  for (size_t i = 0; i < mdf.size() && i < 20; i++, n10++) debut += mdf[i];
  debut /= n10 ? n10 : 1;
  for (size_t i = mdf.size() - 20; i < mdf.size(); i++) fin += mdf[i];
  fin /= 20;
  char texte[120];
  snprintf(texte, sizeof texte, "la fréquence médiane baisse avec la fatigue simulée (%.0f → %.0f Hz)", debut, fin);
  printf("%s\n", texte);
  VERIFIER(mdf.size() > 100 && fin < debut - 15, texte);
  auto mr = mesures(avantM);
  VERIFIER(mr.size() > 2900, "les mesures d'intensité continuent à 50 Hz en RAW");
  int fLignes = 0;
  for (auto &l : banc::lignesSerie) fLignes += l.rfind("F,", 0) == 0;
  VERIFIER(fLignes >= 115, "journal série « F,… » pour la fatigue");

  int retards = 0;
  for (auto &l : banc::lignesSerie) retards += l.find("trop lente") != std::string::npos;
  for (auto &l : banc::lignesSerie) if (l.find("trop lente") != std::string::npos) printf("  %s\n", l.c_str());
  VERIFIER(retards == 0, "rythme d'échantillonnage tenu (2 000 par seconde en RAW)");

  // ---------------------------------------------------------------- interrupteur resté sur ENV
  amplitude = 0;
  banc::signalMv = [](double) { return 40.0; };  // enveloppe au repos : ~0 V, pas 1,65 V
  avancer(4);
  VERIFIER(codeLu() == ERR_SOURCE, "signal non centré : « interrupteur du Link Shield sur ENV ? »");
  banc::signalMv = [](double t) { return 1650 + 5 * bruit.echantillon(t, 110, 2000); };
  avancer(4);
  VERIFIER(codeLu() != ERR_SOURCE, "l'avertissement disparaît quand l'interrupteur est remis sur RAW");

  // ---------------------------------------------------------------- retour en ENV, natation
  commande({0x07, 0x00});
  avancer(0.01);
  VERIFIER(car(U_CONFIG)->valeur[5] == SOURCE_ENV && refLue() == 1850, "retour en ENV");
  banc::signalMv = [](double) { return 1000.0; };
  commande({0x05});
  avancer(0.5);
  deconnecter();
  avancer(60);  // une minute de nage sans connexion
  connecter();
  commande({0x02});
  avancer(0.1);
  auto resume = car(U_HORS_LIGNE)->lireDepuisApplication();
  uint16_t duree = resume[2] | resume[3] << 8;
  VERIFIER(resume[1] == EnregistrementHorsLigne::TERMINE && duree >= 59 && duree <= 61, "natation : 1 min gardée dans le brassard");
  VERIFIER(resume[8] >= 52 && resume[8] <= 56, "natation : intensité moyenne ≈ 54 %");

  printf("%d vérifications OK, %d échec(s)\n", ok, ko);
  fflush(stdout);
  _exit(ko == 0 ? 0 : 1);  // la tâche d'analyse tourne en boucle : on sort sans l'attendre
}
