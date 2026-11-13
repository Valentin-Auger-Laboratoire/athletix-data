// Tests des calculs du firmware, sur ordinateur (sans carte ESP32).
//   g++ -std=c++17 -Wall -Wextra -I hardware/firmware-brassard tests/firmware/test_calcul_emg.cpp -o /tmp/test_emg && /tmp/test_emg
#include <cmath>
#include <cstdio>
#include <cstring>

#include "calcul_emg.h"

using namespace athletix;

static int ok = 0, ko = 0;
#define VERIFIER(cond, nom)                    \
  do {                                         \
    if (cond) {                                \
      ok++;                                    \
    } else {                                   \
      ko++;                                    \
      printf("ÉCHEC : %s (ligne %d)\n", nom, __LINE__); \
    }                                          \
  } while (0)

int main() {
  // 1. Paquet de l'exemple de GATT.md §4 : e8 03 00 00 9e 02 2a 00
  {
    uint8_t p[8];
    encoderMesure(p, 1000, 670, 42, 0);
    const uint8_t attendu[8] = {0xe8, 0x03, 0x00, 0x00, 0x9e, 0x02, 0x2a, 0x00};
    VERIFIER(memcmp(p, attendu, 8) == 0, "paquet identique à l'exemple de GATT.md");
    encoderMesure(p, 0xFFFFFFFFu, 3300, 255, BIT_ALERTE | BIT_SATURATION | BIT_CALIBRATION);
    VERIFIER(p[0] == 0xFF && p[3] == 0xFF && lire16(&p[4]) == 3300 && p[6] == 255 && p[7] == 0x07, "valeurs extrêmes");
  }

  // 2. RMS : signal constant → RMS = la valeur ; sinus d'amplitude A → A/√2
  {
    FenetreRms<100> f;
    uint16_t r = 0;
    for (int i = 0; i < 100; i++) r = f.ajouter(1000);
    VERIFIER(f.pleine() && r == 1000, "RMS d'un signal constant");
    FenetreRms<100> s;
    for (int i = 0; i < 1000; i++) r = s.ajouter(1000.0f * sinf(2 * 3.14159265f * i / 50.0f));
    VERIFIER(std::abs((int)r - 707) <= 1, "RMS d'un sinus = A/√2");
    // pas de dérive après 1 million d'échantillons (somme glissante en double)
    FenetreRms<100> d;
    for (int i = 0; i < 1000000; i++) d.ajouter((i % 7) * 300.0f);
    for (int i = 0; i < 100; i++) r = d.ajouter(0);
    VERIFIER(r == 0, "pas de dérive de la somme glissante");
    // fenêtre de 200 ms : un échelon met 100 échantillons (200 ms à 500 Hz) à être entièrement pris en compte
    FenetreRms<100> e;
    for (int i = 0; i < 50; i++) r = e.ajouter(1000);
    VERIFIER(std::abs((int)r - 707) <= 1, "échelon à mi-fenêtre : √(1/2) × 1000");
  }

  // 3. Intensité en % MVC
  VERIFIER(intensitePct(925, 1850) == 50, "925 / 1850 = 50 %");
  VERIFIER(intensitePct(1998, 1850) == 108, "dépassement possible au-delà de 100 %");
  VERIFIER(intensitePct(3300, 100) == 255, "plafond à 255");
  VERIFIER(intensitePct(500, 0) == 0, "référence nulle : pas de division par zéro");

  // 4. Hystérésis 75 / 70 : une seule alerte malgré l'oscillation autour du seuil
  {
    Alerte a;
    const uint8_t suite[] = {40, 74, 75, 92, 72, 71, 70, 76, 69, 50, 74};
    const bool attendu[] = {false, false, true, true, true, true, true, true, false, false, false};
    int fronts = 0;
    bool avant = false, toutJuste = true;
    for (unsigned i = 0; i < sizeof(suite); i++) {
      bool etat = a.mettreAJour(suite[i]);
      if (etat != attendu[i]) toutJuste = false;
      if (etat && !avant) fronts++;
      avant = etat;
    }
    VERIFIER(toutJuste, "hystérésis : allumée à 75, éteinte sous 70");
    VERIFIER(fronts == 1, "une seule alerte");
    VERIFIER(!a.regler(70, 70) && a.seuilHaut() == 75, "seuils incohérents refusés");
    VERIFIER(a.regler(85, 60) && a.seuilHaut() == 85 && a.seuilBas() == 60, "nouveaux seuils acceptés");
  }

  // 5. Calibration : maximum sur 3 s, refus si trop faible, gère le retour à zéro de millis()
  {
    Calibration c;
    c.demarrer(1000);
    c.ajouter(1200);
    c.ajouter(1834);
    c.ajouter(1500);
    VERIFIER(!c.terminee(3999), "pas finie avant 3 s");
    VERIFIER(c.terminee(4000), "finie à 3 s");
    VERIFIER(c.terminer() == 1834, "référence = maximum");
    c.demarrer(0xFFFFFF00u);  // 256 ms avant que millis() repasse par 0
    c.ajouter(60);
    VERIFIER(!c.terminee(0x00000100u) && !c.terminee(0x00000A00u) && c.terminee(0x00000C00u),
             "retour à zéro de millis() : 512 ms, 2 816 ms (pas finie), 3 328 ms (finie)");
    VERIFIER(c.terminer() == 0, "signal trop faible → refus");
  }

  // 6. Configuration : 5 octets écrits, 6 lus (source ENV / RAW en plus)
  {
    Configuration cfg;
    uint8_t o[Configuration::TAILLE_LUE];
    cfg.encoder(o);
    VERIFIER(o[0] == 75 && o[1] == 70 && lire16(&o[2]) == 1850 && o[4] == 50 && o[5] == SOURCE_ENV, "configuration par défaut");
    cfg.source = SOURCE_RAW;
    const uint8_t avecSource[6] = {80, 60, 0x08, 0x07, 25, SOURCE_ENV};
    VERIFIER(cfg.appliquer(avecSource, 6) && cfg.source == SOURCE_RAW, "6e octet écrit ignoré : la source ne change que par la commande 0x07");
    const uint8_t bon[5] = {80, 60, 0x08, 0x07, 25};
    VERIFIER(cfg.appliquer(bon, 5) && cfg.refMvcMv == 1800 && cfg.frequenceHz == 25, "configuration valide appliquée");
    const uint8_t mauvais[5] = {60, 80, 0x08, 0x07, 25};
    VERIFIER(!cfg.appliquer(mauvais, 5) && cfg.seuilHaut == 80, "seuils inversés refusés");
    const uint8_t refHorsPlage[5] = {80, 60, 0xFF, 0xFF, 25};
    VERIFIER(!cfg.appliquer(refHorsPlage, 5), "référence hors plage refusée");
    VERIFIER(!cfg.appliquer(bon, 4) && !cfg.appliquer(bon, 7), "taille fausse refusée");
  }

  // 7. Saturation prolongée (2 s)
  {
    SurveillanceSaturation s;
    VERIFIER(!s.mettreAJour(true, 0) && !s.mettreAJour(true, 1999) && s.mettreAJour(true, 2000), "saturation > 2 s");
    VERIFIER(!s.mettreAJour(false, 2100) && !s.mettreAJour(true, 2200), "remise à zéro quand le signal redescend");
  }

  // 8. Chaîne complète sur le profil de la simulation : 40 % puis 95 % → l'alerte s'allume une seule fois
  {
    FenetreRms<100> f;
    Alerte a;
    int fronts = 0;
    bool avant = false;
    unsigned graine = 23341;  // même graine que la simulation Simulink (bruit pseudo-aléatoire)
    for (int i = 0; i < 2500; i++) {  // 5 s à 500 Hz
      float t = i / 500.0f;
      float vise = t < 1 ? 0 : t < 2 ? 40 : t < 3 ? 95 : t < 4 ? 50 : 0;
      graine = graine * 1103515245u + 12345u;
      float bruit = ((int)((graine >> 16) % 601) - 300) / 100.0f;  // ± 3 %
      float mv = (vise + bruit) * 1850.0f / 100.0f;
      if (mv < 0) mv = 0;
      uint16_t rms = f.ajouter(mv);
      if (i % 10 == 0) {  // un paquet toutes les 20 ms (50 Hz)
        bool etat = a.mettreAJour(intensitePct(rms, 1850));
        if (etat && !avant) fronts++;
        avant = etat;
      }
    }
    VERIFIER(fronts == 1, "profil de la simulation : une seule alerte");
  }

  // 9. Enregistrement sans connexion (natation)
  {
    EnregistrementHorsLigne e;
    uint8_t o[EnregistrementHorsLigne::TAILLE_MAX];
    VERIFIER(e.encoder(o, 0) == 20 && o[0] == 1 && o[1] == EnregistrementHorsLigne::VIDE, "vide au départ");
    // 10 min de nage : 40 % (alerte entre 60 et 120 s, à 90 %), puis 6 min au bord à 2 %
    uint32_t t = 5000;
    e.demarrer(t);
    for (uint32_t ms = 0; ms <= 600000; ms += 20) {
      bool fort = ms >= 60000 && ms < 120000;
      e.ajouter(t + ms, fort ? 90 : 40, fort);
    }
    uint32_t finNage = t + 600000;
    for (uint32_t ms = 20; ms <= 360000; ms += 20) e.ajouter(finNage + ms, 2, false);
    VERIFIER(e.etat() == EnregistrementHorsLigne::TERMINE, "arrêt automatique après 5 min de repos");
    unsigned n = e.encoder(o, finNage + 20 + 3600000);  // lu 1 h après la fin (1re mesure de repos)
    VERIFIER(lire16(&o[2]) == 600, "durée = la nage seule (10 min)");
    VERIFIER(o[8] == 45, "intensité moyenne : 40 × 0,9 + 90 × 0,1 = 45 %");
    VERIFIER(o[9] == 90, "maximum");
    VERIFIER(lire16(&o[10]) == 60, "60 s d'effort intense");
    VERIFIER(lire16(&o[12]) == 1, "une alerte");
    uint32_t ilYa = o[14] | (o[15] << 8) | (o[16] << 16) | ((uint32_t)o[17] << 24);
    VERIFIER(ilYa == 3600, "fin il y a 1 h");
    VERIFIER(o[18] == 30 && o[19] == 20 && n == 40, "20 points de courbe (un toutes les 30 s)");
    VERIFIER(o[20] == 40 && o[22] == 90 && o[23] == 90 && o[24] == 40, "courbe : 40 %, puis 90 % de 60 à 120 s");
    e.effacer();
    VERIFIER(e.encoder(o, 0) == 20 && o[1] == EnregistrementHorsLigne::VIDE, "effacé après lecture");
  }
  {
    // Arrêt demandé avant les 5 min, trou de liaison ignoré, plafond de 200 points
    EnregistrementHorsLigne e;
    uint8_t o[EnregistrementHorsLigne::TAILLE_MAX];
    e.demarrer(0);
    for (uint32_t ms = 0; ms <= 120000; ms += 20) e.ajouter(ms, 50, false);
    e.ajouter(130000, 50, false);  // 10 s sans mesure : pas compté
    e.terminer(130000);
    e.encoder(o, 130000);
    VERIFIER(e.etat() == EnregistrementHorsLigne::TERMINE && lire16(&o[2]) == 120, "arrêt demandé, trou non compté");
    EnregistrementHorsLigne longue;
    longue.demarrer(0);
    for (uint32_t ms = 0; ms <= 7200000; ms += 100) longue.ajouter(ms, 30, false);  // 2 h
    VERIFIER(longue.encoder(o, 0) == 20 + 200 && o[19] == 200, "courbe plafonnée à 200 points");
    longue.ajouter(7200100, 30, false);
    longue.terminer(7200100);
    longue.ajouter(7200200, 30, false);
    longue.encoder(o, 7200200);
    VERIFIER(lire16(&o[2]) == 7200, "plus rien n'est ajouté après la fin");
  }

  printf("%d vérifications réussies, %d échecs\n", ok, ko);
  return ko == 0 ? 0 : 1;
}
