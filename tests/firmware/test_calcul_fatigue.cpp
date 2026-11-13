// Tests de la mesure de fatigue (fréquence médiane), sur ordinateur, sans carte.
//   g++ -std=c++17 -Wall -Wextra -I hardware/firmware-brassard tests/firmware/test_calcul_fatigue.cpp -o /tmp/test_fatigue && /tmp/test_fatigue
#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

#include "calcul_fatigue.h"

using namespace athletix;

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

const float FE = 2000.0f;
const int N = 1024;

// Générateur pseudo-aléatoire reproductible (le MÊME en Dart : tests/fatigue_test.dart)
struct Hasard {
  uint32_t etat;
  explicit Hasard(uint32_t graine) : etat(graine) {}
  double uniforme() {  // ]0, 1[
    etat = etat * 1664525u + 1013904223u;
    return (etat + 0.5) / 4294967296.0;
  }
  double gauss() {  // Box-Muller
    double u = uniforme(), v = uniforme();
    return sqrt(-2.0 * log(u)) * cos(2.0 * M_PI * v);
  }
};

// Filtre passe-bande du 2e ordre (formules « RBJ Audio EQ Cookbook », gain unité au centre)
struct PasseBande {
  double b0, b2, a1, a2, x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  PasseBande(double fc, double q, double fe) {
    double w = 2 * M_PI * fc / fe, alpha = sin(w) / (2 * q), a0 = 1 + alpha;
    b0 = alpha / a0;
    b2 = -alpha / a0;
    a1 = -2 * cos(w) / a0;
    a2 = (1 - alpha) / a0;
  }
  double filtrer(double x) {
    double y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x; y2 = y1; y1 = y;
    return y;
  }
  // |H(f)|² théorique
  double gain2(double f, double fe) const {
    double w = 2 * M_PI * f / fe;
    double nr = b0 + b2 * cos(2 * w), ni = -b2 * sin(2 * w);
    double dr = 1 + a1 * cos(w) + a2 * cos(2 * w), di = -(a1 * sin(w) + a2 * sin(2 * w));
    return (nr * nr + ni * ni) / (dr * dr + di * di);
  }
};

// Médiane théorique d'un bruit blanc filtré, dans la même bande que le firmware
double mdfTheorique(const PasseBande &h) {
  const int M = 200000;
  std::vector<double> p(M);
  double total = 0;
  for (int i = 0; i < M; i++) {
    double f = 1000.0 * (i + 0.5) / M;
    p[i] = AnalyseFrequence<N>::garder((float)f) ? h.gain2(f, FE) : 0;
    total += p[i];
  }
  double cumul = 0;
  for (int i = 0; i < M; i++) {
    cumul += p[i];
    if (cumul >= total / 2) return 1000.0 * (i + 0.5) / M;
  }
  return 0;
}

static AnalyseFrequence<N> analyse(FE);

ResultatFrequence sinus(std::vector<std::pair<double, double>> composantes, double decalage = 0) {
  static float x[N];
  for (int i = 0; i < N; i++) {
    double v = decalage;
    for (auto &c : composantes) v += c.second * sin(2 * M_PI * c.first * i / FE + 0.3);
    x[i] = (float)v;
  }
  return analyse.analyser(x);
}

int main() {
  const float df = FE / N;  // 1,953 Hz

  // 1. FFT : un sinus pile sur une case donne un pic dans cette case
  {
    float re[N], im[N];
    for (int i = 0; i < N; i++) { re[i] = sinf(2 * (float)M_PI * 64 * i / N); im[i] = 0; }
    AnalyseFrequence<N>::fft(re, im);
    int kMax = 0;
    float pMax = 0;
    for (int k = 0; k < N / 2; k++) {
      float p = re[k] * re[k] + im[k] * im[k];
      if (p > pMax) { pMax = p; kMax = k; }
    }
    VERIFIER(kMax == 64, "pic de la FFT dans la bonne case");
    VERIFIER(fabsf(sqrtf(pMax) - N / 2.0f) < 0.01f * N, "amplitude du pic = N/2");
    // Parseval : Σ|x|² = Σ|X|² / N
    double et = 0, ef = 0;
    float r2[N], i2[N];
    Hasard h(7);
    for (int i = 0; i < N; i++) { r2[i] = (float)h.gauss(); i2[i] = 0; et += r2[i] * r2[i]; }
    AnalyseFrequence<N>::fft(r2, i2);
    for (int k = 0; k < N; k++) ef += r2[k] * r2[k] + i2[k] * i2[k];
    VERIFIER(fabs(ef / N - et) / et < 1e-4, "égalité de Parseval");
  }

  // 2. Un sinus seul : la médiane et la moyenne valent sa fréquence
  {
    ResultatFrequence r = sinus({{51 * df, 300}});
    VERIFIER(r.valide && fabsf(r.mdfHz - 51 * df) < 0.05f, "sinus sur une case : MDF exacte");
    VERIFIER(fabsf(r.mnfHz - 51 * df) < 0.05f, "sinus sur une case : MNF exacte");
    for (double f : {37.3, 87.7, 123.4, 211.9, 377.1}) {
      ResultatFrequence s = sinus({{f, 200}});
      VERIFIER(fabs(s.mdfHz - f) < 0.6 * df, "sinus quelconque : MDF à moins d'une demi-case");
      VERIFIER(fabs(s.mnfHz - f) < 0.6 * df, "sinus quelconque : MNF à moins d'une demi-case");
    }
  }

  // 3. Deux sinus : MNF au barycentre, MDF du côté du plus fort
  {
    ResultatFrequence r = sinus({{80, 100}, {200, 100}});
    VERIFIER(fabsf(r.mnfHz - 140) < 1.0f, "deux sinus égaux : MNF au milieu (140 Hz)");
    // la moitié de la puissance est atteinte entre les deux pics : toute valeur entre eux est une médiane
    VERIFIER(r.mdfHz > 80 && r.mdfHz < 200, "deux sinus égaux : MDF entre les deux pics");
    ResultatFrequence s = sinus({{80, 100}, {200, 300}});
    VERIFIER(s.mdfHz > 195 && s.mdfHz < 200, "le plus fort l'emporte : MDF près de 200 Hz");
  }

  // 4. Le secteur (50 Hz) et ce qui sort de la bande ne comptent pas
  {
    ResultatFrequence r = sinus({{50, 1000}, {150, 50}});
    VERIFIER(fabsf(r.mdfHz - 150) < 1.0f, "50 Hz très fort retiré : la MDF reste à 150 Hz");
    ResultatFrequence s = sinus({{8, 1000}, {600, 1000}, {120, 50}});
    VERIFIER(fabsf(s.mdfHz - 120) < 1.0f, "8 Hz (mouvement) et 600 Hz hors bande ignorés");
    ResultatFrequence d = sinus({{120, 50}}, 1650);
    VERIFIER(fabsf(d.mdfHz - 120) < 1.0f, "composante continue de 1,65 V sans effet");
    ResultatFrequence z = sinus({});
    VERIFIER(!z.valide, "signal nul : pas de résultat");
  }

  // 5. Filtre de la composante continue
  {
    FiltreContinu f;
    float y = 0;
    for (int i = 0; i < 4000; i++) y = f.filtrer(1650);
    VERIFIER(fabsf(y) < 1e-3f, "continu 1 650 mV supprimé");
    FiltreContinu g;
    double maxi = 0;
    for (int i = 0; i < 8000; i++) {
      float v = g.filtrer(1650 + 100 * sinf(2 * (float)M_PI * 100 * i / FE));
      if (i > 4000 && fabs(v) > maxi) maxi = fabs(v);
    }
    VERIFIER(fabs(maxi - 100) < 1.0, "100 Hz passe sans perte (< 1 %)");
    FiltreContinu h;
    for (int i = 0; i < 8000; i++) y = h.filtrer(1650 + 100 * sinf(2 * (float)M_PI * 20 * i / FE));
    double maxi20 = 0;
    for (int i = 0; i < 2000; i++) {
      float v = h.filtrer(1650 + 100 * sinf(2 * (float)M_PI * 20 * (i + 8000) / FE));
      if (fabs(v) > maxi20) maxi20 = fabs(v);
    }
    VERIFIER(maxi20 > 99, "20 Hz (bas de la bande) passe aussi");
  }

  // 6. Signal ressemblant à l'EMG : bruit filtré, comparé à la médiane calculée par la théorie
  {
    for (double fc : {70.0, 90.0, 110.0, 130.0}) {
      PasseBande filtre(fc, 0.7, FE);
      double attendu = mdfTheorique(filtre);
      Hasard h(2026);
      FiltreContinu dc;
      static float x[N];
      double somme = 0;
      const int fenetres = 60;
      for (int i = 0; i < 2000; i++) dc.filtrer((float)(1650 + 200 * filtre.filtrer(h.gauss())));  // régime établi
      for (int w = 0; w < fenetres; w++) {
        for (int i = 0; i < N; i++) x[i] = dc.filtrer((float)(1650 + 200 * filtre.filtrer(h.gauss())));
        somme += analyse.analyser(x).mdfHz;
      }
      double mesure = somme / fenetres;
      char nom[96];
      snprintf(nom, sizeof nom, "bruit filtré fc = %.0f Hz : MDF mesurée %.1f / théorie %.1f Hz", fc, mesure, attendu);
      VERIFIER(fabs(mesure - attendu) < 3.0, nom);
    }
  }

  // 7. Une fatigue simulée (spectre qui glisse de 110 à 80 Hz) fait bien baisser la MDF
  {
    Hasard h(11);
    static float x[N];
    double premiere = 0, derniere = 0;
    for (int etape = 0; etape <= 10; etape++) {
      PasseBande filtre(110 - 3 * etape, 0.7, FE);
      for (int i = 0; i < 500; i++) filtre.filtrer(h.gauss());
      double s = 0;
      for (int w = 0; w < 8; w++) {
        for (int i = 0; i < N; i++) x[i] = (float)(200 * filtre.filtrer(h.gauss()));
        s += analyse.analyser(x).mdfHz;
      }
      if (etape == 0) premiere = s / 8;
      if (etape == 10) derniere = s / 8;
    }
    VERIFIER(derniere < premiere - 15, "spectre qui glisse de 30 Hz : la MDF baisse nettement");
  }

  // 8. Valeur de référence partagée avec la version Dart (même hasard, même filtre)
  {
    PasseBande filtre(100, 0.7, FE);
    Hasard h(42);
    static float x[N];
    for (int i = 0; i < N; i++) x[i] = (float)(300 * filtre.filtrer(h.gauss()));
    ResultatFrequence r = analyse.analyser(x);
    printf("Référence pour tests/fatigue_test.dart : MDF = %.3f Hz, MNF = %.3f Hz\n", r.mdfHz, r.mnfHz);
    VERIFIER(r.valide && r.mdfHz > 60 && r.mdfHz < 160, "référence plausible");
  }

  // 9. Paquet Fréquence de 8 octets (GATT.md §12)
  {
    uint8_t p[8];
    encoderFrequence(p, 1000, 98.76f, 112.04f);
    const uint8_t attendu[8] = {0xe8, 0x03, 0x00, 0x00, 0xdc, 0x03, 0x60, 0x04};  // 988 et 1120 dixièmes
    VERIFIER(memcmp(p, attendu, 8) == 0, "paquet Fréquence identique à l'exemple de GATT.md");
    encoderFrequence(p, 5, 0, 0);
    VERIFIER(p[4] == 0 && p[5] == 0, "MDF nulle : pas de valeur");
    VERIFIER(dixiemesHz(-3) == 0 && dixiemesHz(NAN) == 0 && dixiemesHz(1e9f) == 65535, "bornes");
  }

  printf("%d vérifications OK, %d échec(s)\n", ok, ko);
  return ko == 0 ? 0 : 1;
}
