// Athletix-Data — mesure de la fatigue musculaire par la fréquence médiane (MDF) du signal brut.
//
// Pourquoi : quand un muscle fatigue, la vitesse de conduction de ses fibres baisse et le spectre
// du signal EMG glisse vers les basses fréquences. La fréquence médiane (la fréquence qui partage
// la puissance du spectre en deux moitiés égales) baisse donc pendant un effort qui fatigue.
// C'est l'indicateur classique de la fatigue en électromyographie de surface.
//
// Il faut le signal BRUT (sortie RAW du MyoWare 2.0, interrupteur OUTPUT du Link Shield sur RAW) :
// l'enveloppe (ENV) est lissée et n'a plus de contenu fréquentiel.
//
// Comme calcul_emg.h, ce fichier ne contient que des calculs : il est compilé dans le firmware
// ET testé sur ordinateur (tests/firmware/test_calcul_fatigue.cpp). La même analyse est recopiée
// en Dart (lib/services/brassard/analyse_frequence.dart) pour le brassard simulé, avec les mêmes tests.
//
// Choix (expliqués dans hardware/firmware-brassard/FATIGUE.md) :
//   - échantillonnage à 2 000 Hz, fenêtres de 1 024 échantillons (0,512 s), soit 2 résultats par seconde ;
//   - suppression de la composante continue (le signal RAW est centré sur ~1,65 V) ;
//   - fenêtre de Hann, transformée de Fourier rapide (FFT radix 2) ;
//   - bande utile 20–450 Hz (bande de l'EMG de surface), en retirant 45–55 Hz (secteur 50 Hz et ses fuites, la fenêtre de Hann étale un pic sur ±2 cases) ;
//   - fréquence médiane interpolée dans la case où la puissance cumulée atteint la moitié.

#pragma once
#include <math.h>
#include <stdint.h>

namespace athletix {

// ---- Suppression de la composante continue (filtre passe-haut du 1er ordre) ----
// y[n] = x[n] − x[n−1] + a·y[n−1], a = 0,995 : coupure ≈ 1,6 Hz à 2 000 Hz.
class FiltreContinu {
 public:
  explicit FiltreContinu(float a = 0.995f) : a_(a) {}
  float filtrer(float x) {
    if (premier_) {  // démarre sur la première valeur : pas de grand saut au départ
      premier_ = false;
      xPrec_ = x;
      return 0;
    }
    float y = x - xPrec_ + a_ * yPrec_;
    xPrec_ = x;
    yPrec_ = y;
    return y;
  }
  void vider() { premier_ = true; xPrec_ = yPrec_ = 0; }

 private:
  float a_;
  float xPrec_ = 0, yPrec_ = 0;
  bool premier_ = true;
};

struct ResultatFrequence {
  float mdfHz = 0;        // fréquence médiane
  float mnfHz = 0;        // fréquence moyenne (barycentre du spectre), donnée en plus
  float puissance = 0;    // puissance dans la bande (unités arbitraires, mV²)
  bool valide = false;
};

// ---- Analyse d'une fenêtre de N échantillons (N puissance de 2) ----
template <int N>
class AnalyseFrequence {
 public:
  static_assert((N & (N - 1)) == 0, "N doit être une puissance de 2");

  static constexpr float BANDE_BASSE_HZ = 20.0f;
  static constexpr float BANDE_HAUTE_HZ = 450.0f;
  static constexpr float SECTEUR_BAS_HZ = 45.0f;
  static constexpr float SECTEUR_HAUT_HZ = 55.0f;

  explicit AnalyseFrequence(float frequenceHz) : fe_(frequenceHz) {
    for (int i = 0; i < N; i++) hann_[i] = 0.5f - 0.5f * cosf(2.0f * (float)M_PI * i / (N - 1));
  }

  // Analyse N échantillons (en mV, déjà sans composante continue). Le tableau n'est pas modifié.
  ResultatFrequence analyser(const float *x) {
    // Moyenne retirée une seconde fois : le filtre laisse un petit reste au démarrage
    double moyenne = 0;
    for (int i = 0; i < N; i++) moyenne += x[i];
    moyenne /= N;
    for (int i = 0; i < N; i++) {
      re_[i] = (float)(x[i] - moyenne) * hann_[i];
      im_[i] = 0;
    }
    fft(re_, im_);

    const float df = fe_ / N;
    double total = 0, moment = 0;
    for (int k = 1; k < N / 2; k++) {
      float f = k * df;
      p_[k] = garder(f) ? re_[k] * re_[k] + im_[k] * im_[k] : 0;
      total += p_[k];
      moment += (double)p_[k] * f;
    }
    ResultatFrequence r;
    r.puissance = (float)total;
    if (total <= 0) return r;
    r.mnfHz = (float)(moment / total);
    // Médiane : chaque case représente la puissance répartie sur [f − df/2, f + df/2]
    double moitie = total / 2, cumul = 0;
    for (int k = 1; k < N / 2; k++) {
      if (p_[k] <= 0) continue;
      if (cumul + p_[k] >= moitie) {
        double part = (moitie - cumul) / p_[k];
        r.mdfHz = (float)((k - 0.5 + part) * df);
        break;
      }
      cumul += p_[k];
    }
    r.valide = true;
    return r;
  }

  static bool garder(float f) {
    return f >= BANDE_BASSE_HZ && f <= BANDE_HAUTE_HZ && !(f >= SECTEUR_BAS_HZ && f <= SECTEUR_HAUT_HZ);
  }

  // FFT complexe sur place, radix 2, décimation temporelle (Cooley-Tukey)
  static void fft(float *re, float *im) {
    for (int i = 1, j = 0; i < N; i++) {  // permutation par inversion des bits
      int bit = N >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) {
        float t = re[i]; re[i] = re[j]; re[j] = t;
        t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }
    for (int longueur = 2; longueur <= N; longueur <<= 1) {
      double angle = -2.0 * M_PI / longueur;
      float wr = (float)cos(angle), wi = (float)sin(angle);
      for (int debut = 0; debut < N; debut += longueur) {
        float cr = 1, ci = 0;
        for (int k = 0; k < longueur / 2; k++) {
          int a = debut + k, b = a + longueur / 2;
          float tr = re[b] * cr - im[b] * ci;
          float ti = re[b] * ci + im[b] * cr;
          re[b] = re[a] - tr; im[b] = im[a] - ti;
          re[a] += tr; im[a] += ti;
          float ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }
  }

 private:
  float fe_;
  float hann_[N];
  float re_[N], im_[N], p_[N / 2];
};

// ---- Paquet « Fréquence » de 8 octets (GATT.md §12), little-endian ----
// 0–3 horodatage (ms) · 4–5 MDF (0,1 Hz) · 6–7 MNF (0,1 Hz). MDF = 0 : pas de valeur (muscle au repos).
inline uint16_t dixiemesHz(float f) {
  if (!(f > 0)) return 0;
  float d = f * 10 + 0.5f;
  return d > 65535 ? 65535 : (uint16_t)d;
}

inline void encoderFrequence(uint8_t paquet[8], uint32_t horodatageMs, float mdfHz, float mnfHz) {
  for (int i = 0; i < 4; i++) paquet[i] = (horodatageMs >> (8 * i)) & 0xFF;
  uint16_t m = dixiemesHz(mdfHz), n = dixiemesHz(mnfHz);
  paquet[4] = m & 0xFF;
  paquet[5] = m >> 8;
  paquet[6] = n & 0xFF;
  paquet[7] = n >> 8;
}

// Une fenêtre ne compte que si le muscle travaille : au repos, le spectre n'est que du bruit.
const uint8_t SEUIL_INTENSITE_FATIGUE = 20;  // % de la contraction maximale, moyenne sur la fenêtre

}  // namespace athletix
