// Athletix-Data — calculs du brassard EMG, sans dépendance au matériel.
//
// Ce fichier ne contient que des calculs : il est compilé dans le firmware ESP32-S3
// ET testé sur un ordinateur (tests/firmware/test_calcul_emg.cpp), sans carte.
// Les choix reprennent la simulation Simulink (hardware/simulation-emg/) :
//   - échantillonnage à 500 Hz, valeur efficace (RMS) glissante sur 200 ms = 100 échantillons ;
//   - intensité en % de la référence 100 % (contraction maximale, MVC) ;
//   - alerte d'effort intense avec hystérésis : s'allume au seuil haut, s'éteint sous le seuil bas.
// Le format des paquets suit architecture/GATT.md §4 (8 octets, little-endian).

#pragma once
#include <stdint.h>
#include <math.h>

namespace athletix {

const uint8_t BIT_ALERTE = 0x01;
const uint8_t BIT_SATURATION = 0x02;
const uint8_t BIT_CALIBRATION = 0x04;

// ---- Valeur efficace glissante (RMS) sur N échantillons ----
template <int N>
class FenetreRms {
 public:
  FenetreRms() { vider(); }

  void vider() {
    for (int i = 0; i < N; i++) carres_[i] = 0;
    somme_ = 0;
    index_ = 0;
    remplis_ = 0;
  }

  // Ajoute un échantillon (en mV) et renvoie la RMS actuelle (en mV).
  // La somme est en double pour éviter que les erreurs d'arrondi s'accumulent.
  uint16_t ajouter(float mv) {
    double carre = (double)mv * mv;
    somme_ += carre - carres_[index_];
    carres_[index_] = carre;
    index_ = (index_ + 1) % N;
    if (remplis_ < N) remplis_++;
    double moyenne = somme_ / N;  // tant que la fenêtre n'est pas pleine, les cases vides valent 0
    if (moyenne < 0) moyenne = 0;
    double rms = sqrt(moyenne);
    return rms > 65535 ? 65535 : (uint16_t)(rms + 0.5);
  }

  bool pleine() const { return remplis_ == N; }

 private:
  double carres_[N];
  double somme_;
  int index_;
  int remplis_;
};

// ---- Intensité en % de la référence, plafonnée à 255 (1 octet) ----
inline uint8_t intensitePct(uint16_t rmsMv, uint16_t refMvcMv) {
  if (refMvcMv == 0) return 0;
  uint32_t pct = ((uint32_t)rmsMv * 100 + refMvcMv / 2) / refMvcMv;  // arrondi au plus proche
  return pct > 255 ? 255 : (uint8_t)pct;
}

// ---- Alerte d'effort intense avec hystérésis (comme le bloc Relay de Simulink) ----
class Alerte {
 public:
  Alerte(uint8_t seuilHaut = 75, uint8_t seuilBas = 70) : haut_(seuilHaut), bas_(seuilBas), active_(false) {}

  // Refuse des seuils incohérents (GATT.md §5) : renvoie false sans rien changer.
  bool regler(uint8_t seuilHaut, uint8_t seuilBas) {
    if (seuilBas >= seuilHaut) return false;
    haut_ = seuilHaut;
    bas_ = seuilBas;
    return true;
  }

  bool mettreAJour(uint8_t intensite) {
    if (!active_ && intensite >= haut_) active_ = true;
    if (active_ && intensite < bas_) active_ = false;
    return active_;
  }

  void reinitialiser() { active_ = false; }
  bool active() const { return active_; }
  uint8_t seuilHaut() const { return haut_; }
  uint8_t seuilBas() const { return bas_; }

 private:
  uint8_t haut_, bas_;
  bool active_;
};

// ---- Calibration : maximum de la RMS pendant 3 s ----
class Calibration {
 public:
  static const uint32_t DUREE_MS = 3000;
  static const uint16_t MINIMUM_MV = 100;  // en dessous : signal trop faible (électrodes ?)

  void demarrer(uint32_t maintenantMs) {
    debutMs_ = maintenantMs;
    max_ = 0;
    enCours_ = true;
  }

  void ajouter(uint16_t rmsMv) {
    if (enCours_ && rmsMv > max_) max_ = rmsMv;
  }

  // Vrai quand les 3 s sont écoulées (gère le retour à zéro de millis()).
  bool terminee(uint32_t maintenantMs) const { return enCours_ && (uint32_t)(maintenantMs - debutMs_) >= DUREE_MS; }

  // Termine la calibration. Renvoie la nouvelle référence, ou 0 si le signal était trop faible.
  uint16_t terminer() {
    enCours_ = false;
    return max_ >= MINIMUM_MV ? max_ : 0;
  }

  bool enCours() const { return enCours_; }

 private:
  uint32_t debutMs_ = 0;
  uint16_t max_ = 0;
  bool enCours_ = false;
};

// ---- Encodage little-endian ----
inline void ecrire16(uint8_t *dst, uint16_t v) {
  dst[0] = v & 0xFF;
  dst[1] = v >> 8;
}
inline void ecrire32(uint8_t *dst, uint32_t v) {
  for (int i = 0; i < 4; i++) dst[i] = (v >> (8 * i)) & 0xFF;
}
inline uint16_t lire16(const uint8_t *src) { return (uint16_t)(src[0] | (src[1] << 8)); }

// Paquet Mesure EMG de 8 octets (GATT.md §4)
inline void encoderMesure(uint8_t paquet[8], uint32_t horodatageMs, uint16_t rmsMv, uint8_t intensite,
                          uint8_t drapeaux) {
  ecrire32(&paquet[0], horodatageMs);
  ecrire16(&paquet[4], rmsMv);
  paquet[6] = intensite;
  paquet[7] = drapeaux;
}

// Configuration de 5 octets (GATT.md §6)
struct Configuration {
  uint8_t seuilHaut = 75;
  uint8_t seuilBas = 70;
  uint16_t refMvcMv = 1850;
  uint8_t frequenceHz = 50;

  void encoder(uint8_t octets[5]) const {
    octets[0] = seuilHaut;
    octets[1] = seuilBas;
    ecrire16(&octets[2], refMvcMv);
    octets[4] = frequenceHz;
  }

  // Applique 5 octets reçus s'ils sont valides. Renvoie false (et ne change rien) sinon.
  bool appliquer(const uint8_t *d, unsigned taille) {
    if (taille != 5) return false;
    uint16_t ref = lire16(&d[2]);
    if (d[1] >= d[0] || ref < 100 || ref > 3300 || d[4] == 0 || d[4] > 100) return false;
    seuilHaut = d[0];
    seuilBas = d[1];
    refMvcMv = ref;
    frequenceHz = d[4];
    return true;
  }
};

// Saturation prolongée : le convertisseur est au maximum pendant plus de dureeMs (électrode décollée ?)
class SurveillanceSaturation {
 public:
  explicit SurveillanceSaturation(uint32_t dureeMs = 2000) : duree_(dureeMs) {}

  // Renvoie vrai si la saturation dure depuis plus de dureeMs.
  bool mettreAJour(bool sature, uint32_t maintenantMs) {
    if (!sature) {
      depuis_ = 0;
      enCours_ = false;
      return false;
    }
    if (!enCours_) {
      enCours_ = true;
      depuis_ = maintenantMs;
    }
    return (uint32_t)(maintenantMs - depuis_) >= duree_;
  }

 private:
  uint32_t duree_;
  uint32_t depuis_ = 0;
  bool enCours_ = false;
};

}  // namespace athletix
