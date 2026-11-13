"""Génère une FAUSSE séance de mesure, au format du journal du firmware, pour tester la comparaison
avant d'avoir le brassard. Ce n'est PAS une vraie mesure.

Imite ce qu'on attend d'une vraie personne et de la sortie ENV (enveloppe) du MyoWare : niveaux d'effort un peu
différents de la consigne, léger retard, bruit du capteur, perturbation du secteur à 50 Hz,
même calcul que le firmware (500 Hz, RMS sur 200 ms, % de la référence, alerte 75 / 70).
"""
import argparse
import numpy as np
import modele


def generer(nb_cycles=3, decalage_s=1.2, niveaux=(2, 36, 88, 47, 2), retard_s=0.15, ref_mv=1850,
            bruit_mv=20, secteur_mv=8, hysteresis=True, graine=2026):
    alea = np.random.default_rng(graine)
    duree = decalage_s + nb_cycles * modele.CYCLE_S + 3.0   # quelques secondes de repos à la fin
    dt = 1.0 / modele.FE_HZ
    t = np.arange(0, duree, dt)
    tp = t - decalage_s - retard_s                     # temps dans le cycle de la personne
    idx = np.where((tp < 0) | (tp >= nb_cycles * modele.CYCLE_S), 0, modele.phase_de(np.clip(tp, 0, None)))
    effort = np.array(niveaux, dtype=float)[idx]
    effort = np.convolve(effort, np.ones(150) / 150, mode="same")   # muscle : ~0,3 s pour changer d'effort
    effort *= 1 + 0.06 * np.sin(2 * np.pi * 0.4 * t)                 # effort pas parfaitement constant
    # Le firmware lit la sortie ENV du MyoWare : le signal du muscle déjà redressé et lissé (l'« enveloppe »),
    # proportionnelle à l'effort, avec une ondulation, le bruit du capteur et un reste de secteur à 50 Hz.
    amplitude_mv = effort / 100 * ref_mv
    ondulation = np.convolve(alea.standard_normal(len(t)), np.ones(25) / 5, mode="same")   # ~ 0,05 s
    mv = (amplitude_mv * (1 + 0.10 * ondulation) + bruit_mv * alea.standard_normal(len(t))
          + secteur_mv * np.sin(2 * np.pi * 50 * t))
    mv = np.clip(mv, 0, 3300)
    rms = np.clip(np.round(modele.rms_glissante(mv)), 0, 65535)
    intensite = np.clip(np.round(rms * 100 / ref_mv), 0, 255)
    if hysteresis:
        al = modele.alerte(intensite)
    else:
        al = intensite >= modele.SEUIL_HAUT
    # Le firmware écrit une ligne toutes les 20 ms (50 Hz)
    pas = modele.FE_HZ // 50
    lignes = ["Brassard prêt : Athletix-0000 (exemple)", "État : 1 (erreur 0)"]
    for i in range(0, len(t), pas):
        lignes.append(f"M,{int(5000 + t[i] * 1000)},{int(mv[i])},{int(rms[i])},{int(intensite[i])},{int(al[i])}")
    return lignes


def generer_fatigue(debut_hz=112.0, baisse_pct=18.0, duree_effort_s=90.0, repos_s=5.0, bruit_hz=3.0, graine=2026):
    """FAUX journal de fatigue (source RAW, firmware 1.2) : lignes « F,ms,MDF,MNF » toutes les 0,512 s.
    Repos (MDF = 0), puis un effort tenu pendant lequel la fréquence médiane baisse de baisse_pct %."""
    alea = np.random.default_rng(graine)
    lignes = ["Source : RAW (interrupteur OUTPUT du Link Shield sur RAW), calibrer de nouveau"]
    t = 0.0
    while t < repos_s + duree_effort_s + 3:
        ms = int(5000 + t * 1000)
        if repos_s <= t < repos_s + duree_effort_s:
            mdf = debut_hz * (1 - baisse_pct / 100 * (t - repos_s) / duree_effort_s) + bruit_hz * alea.standard_normal()
            lignes.append(f"F,{ms},{mdf:.1f},{mdf + 15 + bruit_hz * alea.standard_normal():.1f}")
        else:
            lignes.append(f"F,{ms},0.0,0.0")
        t += 0.512
    return lignes


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("sortie", nargs="?", default="exemple/seance-simulee.txt")
    p.add_argument("--fatigue", action="store_true", help="journal de fatigue (lignes F) au lieu de la séance ENV")
    a = p.parse_args()
    with open(a.sortie, "w", encoding="utf-8") as f:
        f.write("\n".join(generer_fatigue() if a.fatigue else generer()) + "\n")
    print("Écrit :", a.sortie)
