// Athletix-Data — appairage sécurisé du brassard : petits calculs testables sur ordinateur.
// L'utilisation (pile Bluetooth de l'ESP32, mémoire NVS) est dans firmware-brassard.ino,
// activée par APPAIRAGE_SECURISE. Explications : hardware/firmware-brassard/SECURITE.md.
#pragma once
#include <stdint.h>
#include <string.h>

namespace athletix {

// Code d'appairage à 6 chiffres (100000 à 999999), tiré au hasard UNE fois au premier démarrage
// puis gardé en mémoire (NVS). Un code dérivé du numéro de série serait devinable : l'adresse
// Bluetooth est publique et ce dépôt aussi.
// `tirer` doit renvoyer des nombres aléatoires de 32 bits (esp_random() sur la carte : vrai hasard
// matériel quand la radio est active). Rejet des valeurs du haut pour un tirage uniforme.
template <typename Tirage>
uint32_t genererCodeAppairage(Tirage tirer) {
  const uint32_t etendue = 900000;
  const uint32_t limite = 0xFFFFFFFFu - (0xFFFFFFFFu % etendue);  // multiple de 900000
  uint32_t v;
  do {
    v = tirer();
  } while (v >= limite);
  return 100000 + v % etendue;
}

inline bool codeAppairageValide(uint32_t code) { return code >= 100000 && code <= 999999; }

// Commandes tapées dans le moniteur série (USB), jamais par Bluetooth :
//   CODE     réaffiche le code d'appairage
//   OUBLIER  efface tous les téléphones appairés (le code ne change pas)
//   NOUVEAU  tire un nouveau code ET efface les appairages (brassard prêté, code divulgué)
enum CommandeSerie : uint8_t { SERIE_AUCUNE = 0, SERIE_CODE, SERIE_OUBLIER, SERIE_NOUVEAU, SERIE_INCONNUE };

// Lit une ligne (sans le retour à la ligne), sans tenir compte des majuscules ni des espaces autour.
inline CommandeSerie lireCommandeSerie(const char *ligne) {
  char mot[16];
  size_t n = 0;
  while (*ligne == ' ' || *ligne == '\t') ligne++;
  while (*ligne && *ligne != ' ' && *ligne != '\r' && *ligne != '\n' && n < sizeof(mot) - 1) {
    char c = *ligne++;
    mot[n++] = (c >= 'a' && c <= 'z') ? (char)(c - 32) : c;
  }
  mot[n] = 0;
  while (*ligne == ' ' || *ligne == '\t' || *ligne == '\r' || *ligne == '\n') ligne++;
  if (n == 0) return SERIE_AUCUNE;
  if (*ligne) return SERIE_INCONNUE;  // un mot de trop : on ne devine pas
  if (strcmp(mot, "CODE") == 0) return SERIE_CODE;
  if (strcmp(mot, "OUBLIER") == 0) return SERIE_OUBLIER;
  if (strcmp(mot, "NOUVEAU") == 0) return SERIE_NOUVEAU;
  return SERIE_INCONNUE;
}

}  // namespace athletix
