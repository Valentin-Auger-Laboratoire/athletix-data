"""Modèle de référence : ce que le brassard DEVRAIT mesurer d'après la simulation Simulink.

Même chaîne que hardware/simulation-emg/ (Maxence Olivier), réduite à l'essentiel pour être
calculée sans MATLAB :
  profil d'effort (repos, 40 %, 95 %, 50 %, repos ; transitions de 0,3 s ; cycle de 18 s)
  → signal musculaire dont l'amplitude suit l'effort
  → valeur efficace (RMS) glissante sur 200 ms, comme le firmware (500 Hz, 100 échantillons)
  → intensité en % de la contraction maximale, alerte avec hystérésis 75 % / 70 %.
Le même profil sert au brassard simulé de l'application (lib/services/brassard/brassard_simule.dart).
"""
import numpy as np

# (fin de la phase en s, effort en % MVC, nom)
PHASES = [(3.0, 0.0, "repos"), (7.0, 40.0, "effort moyen"), (10.0, 95.0, "effort fort"),
          (15.0, 50.0, "effort moyen"), (18.0, 0.0, "repos")]
CYCLE_S = 18.0
TRANSITION_S = 0.3
FE_HZ = 500          # échantillonnage du firmware
FENETRE_RMS = 100    # 200 ms
SEUIL_HAUT, SEUIL_BAS = 75, 70


def effort_vise(t):
    """Effort demandé (% MVC) à l'instant t (s), avec des transitions linéaires de 0,3 s."""
    t = np.mod(np.asarray(t, dtype=float), CYCLE_S)
    debuts = [0.0] + [p[0] for p in PHASES[:-1]]
    niveaux = [p[1] for p in PHASES]
    y = np.zeros_like(t)
    for i, (d, n) in enumerate(zip(debuts, niveaux)):
        precedent = niveaux[i - 1] if i > 0 else niveaux[-1]
        dans = (t >= d) & (t < PHASES[i][0])
        rampe = np.clip((t - d) / TRANSITION_S, 0, 1)
        y = np.where(dans, precedent + (n - precedent) * rampe, y)
    return y


def phase_de(t):
    """Indice de la phase à l'instant t (s)."""
    t = np.mod(np.asarray(t, dtype=float), CYCLE_S)
    fins = np.array([p[0] for p in PHASES])
    return np.searchsorted(fins, t, side="right").clip(0, len(PHASES) - 1)


def rms_glissante(x, n=FENETRE_RMS):
    """RMS glissante sur n échantillons (fenêtre causale, comme FenetreRms du firmware)."""
    carres = np.concatenate([np.zeros(n - 1), np.asarray(x, dtype=float) ** 2])
    noyau = np.ones(n) / n
    return np.sqrt(np.convolve(carres, noyau, mode="valid"))


def intensite_reference(t):
    """Intensité attendue (% MVC) : l'amplitude efficace suit l'effort, lissée par la fenêtre de 200 ms.

    Pour un signal dont l'écart type vaut a(t), la RMS sur 200 ms vaut la racine de la moyenne
    de a² sur la fenêtre : on la calcule directement, sans tirage aléatoire.
    """
    t = np.asarray(t, dtype=float)
    dt = 1.0 / FE_HZ
    tt = np.arange(t.min() - 0.2, t.max() + dt, dt)
    a = effort_vise(tt)
    r = rms_glissante(a)
    return np.interp(t, tt, r)


def alerte(intensite, haut=SEUIL_HAUT, bas=SEUIL_BAS):
    """Alerte avec hystérésis, comme la classe Alerte du firmware."""
    out = np.zeros(len(intensite), dtype=bool)
    active = False
    for i, v in enumerate(intensite):
        if not active and v >= haut:
            active = True
        if active and v < bas:
            active = False
        out[i] = active
    return out
