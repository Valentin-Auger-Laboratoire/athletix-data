// Tests de l'appairage sécurisé (code, commandes série), sur ordinateur.
//   g++ -std=c++17 -Wall -Wextra -I hardware/firmware-brassard tests/firmware/test_securite.cpp -o /tmp/test_securite && /tmp/test_securite
#include <cstdio>
#include <set>

#include "securite.h"

using namespace athletix;

static int ok = 0, ko = 0;
#define VERIFIER(cond, nom)                              \
  do {                                                   \
    if (cond) ok++;                                      \
    else {                                               \
      ko++;                                              \
      printf("ÉCHEC : %s (ligne %d)\n", nom, __LINE__); \
    }                                                    \
  } while (0)

int main() {
  // 1. Code toujours à 6 chiffres, y compris aux bornes du hasard
  uint32_t suite[] = {0, 899999, 900000, 0xFFFFFFFFu, 0xFF000000u, 12345};
  int i = 0;
  uint32_t c = genererCodeAppairage([&] { return suite[i++]; });
  VERIFIER(c == 100000, "hasard 0 → 100000");
  c = genererCodeAppairage([&] { return suite[i++]; });
  VERIFIER(c == 999999, "hasard 899999 → 999999");
  c = genererCodeAppairage([&] { return suite[i++]; });
  VERIFIER(c == 100000, "900000 → 100000 (modulo)");
  c = genererCodeAppairage([&] { return suite[i++]; });  // 0xFFFFFFFF rejeté, puis 0xFF000000
  VERIFIER(codeAppairageValide(c) && i == 5, "valeur du haut rejetée (tirage uniforme), tirage suivant utilisé");

  // 2. Répartition : sur 900 000 tirages d'un générateur, tous les codes restent valides et variés
  uint32_t etat = 2026;
  std::set<uint32_t> vus;
  bool tousValides = true;
  long dizaines[10] = {0};
  for (int k = 0; k < 900000; k++) {
    uint32_t code = genererCodeAppairage([&] { etat = etat * 1664525u + 1013904223u; return etat; });
    tousValides &= codeAppairageValide(code);
    vus.insert(code);
    dizaines[(code - 100000) / 90000]++;
  }
  VERIFIER(tousValides, "900 000 codes valides");
  VERIFIER(vus.size() > 550000, "codes variés (≈ 63 % de valeurs distinctes attendues)");
  bool equilibre = true;
  for (long d : dizaines) equilibre &= d > 88000 && d < 92000;
  VERIFIER(equilibre, "répartition uniforme sur les 10 tranches");

  VERIFIER(!codeAppairageValide(99999) && !codeAppairageValide(1000000) && codeAppairageValide(123456), "bornes du code");

  // 3. Commandes du moniteur série
  VERIFIER(lireCommandeSerie("CODE") == SERIE_CODE, "CODE");
  VERIFIER(lireCommandeSerie("  oublier\r\n") == SERIE_OUBLIER, "minuscules et espaces acceptés");
  VERIFIER(lireCommandeSerie("Nouveau") == SERIE_NOUVEAU, "NOUVEAU");
  VERIFIER(lireCommandeSerie("") == SERIE_AUCUNE && lireCommandeSerie(" \r\n") == SERIE_AUCUNE, "ligne vide");
  VERIFIER(lireCommandeSerie("CODE 123") == SERIE_INCONNUE, "mot de trop refusé");
  VERIFIER(lireCommandeSerie("CODEX") == SERIE_INCONNUE, "commande inconnue");
  VERIFIER(lireCommandeSerie("UNMOTBEAUCOUPTROPLONGPOURLETAMPON") == SERIE_INCONNUE, "mot trop long sans débordement");

  printf("%d vérifications OK, %d échec(s)\n", ok, ko);
  return ko == 0 ? 0 : 1;
}
