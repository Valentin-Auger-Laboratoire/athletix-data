"""Analyse la fatigue mesurée par le vrai brassard : fréquence médiane du signal brut.

Entrée : le journal du firmware 1.2 en source RAW (lignes « F,ms,MDF,MNF », 2 par seconde ;
MDF = 0 quand le muscle est au repos), enregistré avec capturer.py pendant un effort qui fatigue
(par exemple tenir une bouteille d'eau bras à 90° jusqu'à la fatigue, étape 8 du protocole de test).
Même calcul que l'application (lib/services/brassard/suivi_fatigue.dart) : droite des moindres
carrés sur les valeurs valides, baisse entre le début et la fin, repères 5 % et 10 %.
Sortie : une figure et un court rapport. Explications : hardware/firmware-brassard/FATIGUE.md.

  python mesures/analyser_fatigue.py journal.txt --sortie resultats/fatigue-1
"""
import argparse
import os
import sys

import numpy as np

MIN_VALEURS = 20      # comme l'application
MIN_DUREE_S = 60


def lire(chemin):
    """Lit les lignes « F,ms,MDF,MNF ». Renvoie t (s), mdf et mnf (Hz) des fenêtres où le muscle travaillait."""
    lignes = []
    with open(chemin, encoding="utf-8", errors="replace") as f:
        for brut in f:
            champs = brut.strip().split(",")
            if len(champs) != 4 or champs[0] != "F":
                continue
            try:
                lignes.append([float(c) for c in champs[1:]])
            except ValueError:
                continue
    if not lignes:
        raise ValueError(f"{chemin} : aucune ligne « F,… ». Le brassard est-il en source RAW (firmware 1.2) ?")
    d = np.array(lignes)
    ms = d[:, 0] + np.concatenate([[0], np.cumsum(np.diff(d[:, 0]) < -1e6) * 2**32])  # retour à zéro de millis()
    t = (ms - ms[0]) / 1000
    valide = d[:, 1] > 0
    return {"t": t[valide], "mdf": d[valide, 1], "mnf": d[valide, 2], "nb_total": len(d)}


def interpretation(baisse):
    if baisse >= 10:
        return "fatigue nette du muscle"
    if baisse >= 5:
        return "début de fatigue"
    if baisse > -5:
        return "pas de fatigue mesurable"
    return "fréquence en hausse (muscle qui se réchauffe, ou effort différent)"


def analyser(m):
    t, mdf = m["t"], m["mdf"]
    if len(mdf) < MIN_VALEURS or t[-1] - t[0] < MIN_DUREE_S:
        raise ValueError(f"pas assez de valeurs : {len(mdf)} valeurs sur {t[-1] - t[0] if len(t) else 0:.0f} s "
                         f"(au moins {MIN_VALEURS} sur {MIN_DUREE_S} s)")
    pente, origine = np.polyfit(t, mdf, 1)
    debut, fin = origine + pente * t[0], origine + pente * t[-1]
    residus = mdf - (origine + pente * t)
    return {
        "nb": len(mdf), "duree_s": t[-1] - t[0], "debut": debut, "fin": fin,
        "baisse": (debut - fin) / debut * 100, "pente_hz_min": pente * 60,
        "ecart_type": float(np.std(residus)), "mnf_moy": float(np.mean(m["mnf"])),
    }


def figure(m, a, chemin, titre):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(8, 3.6), dpi=150)
    ax.plot(m["t"], m["mdf"], "o", ms=3, color="#0097a7", label="fréquence médiane (une valeur / 0,5 s)")
    ax.plot([m["t"][0], m["t"][-1]], [a["debut"], a["fin"]], "--", color="#e65100", lw=2,
            label=f"tendance : {a['debut']:.0f} → {a['fin']:.0f} Hz ({-a['baisse']:+.1f} %)")
    ax.set_xlabel("temps (s)")
    ax.set_ylabel("Hz")
    ax.set_title(titre, fontsize=10)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=8, loc="upper right")
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


def rapport(a, chemin_md, image, source):
    with open(chemin_md, "w", encoding="utf-8") as f:
        f.write(f"# Fatigue mesurée : {os.path.basename(source)}\n\n")
        f.write(f"![Fréquence médiane]({os.path.basename(image)})\n\n")
        f.write("| Grandeur | Valeur |\n|---|---|\n")
        f.write(f"| Valeurs avec effort | {a['nb']} sur {a['duree_s']:.0f} s |\n")
        f.write(f"| Fréquence médiane au début (tendance) | {a['debut']:.1f} Hz |\n")
        f.write(f"| Fréquence médiane à la fin (tendance) | {a['fin']:.1f} Hz |\n")
        f.write(f"| Baisse | {a['baisse']:.1f} % ({a['pente_hz_min']:+.2f} Hz/min) |\n")
        f.write(f"| Dispersion autour de la tendance | ± {a['ecart_type']:.1f} Hz |\n")
        f.write(f"| Fréquence moyenne (MNF) | {a['mnf_moy']:.1f} Hz |\n\n")
        f.write(f"**Lecture : {interpretation(a['baisse'])}.** Repères usuels : une baisse de 10 à 30 % accompagne un effort "
                "qui fatigue. Repère d'un prototype étudiant, pas un avis médical.\n")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("journal")
    p.add_argument("--sortie", default=None, help="préfixe des fichiers produits (défaut : à côté du journal)")
    p.add_argument("--titre", default="Brassard Athletix-Data : fréquence médiane pendant l'effort")
    a = p.parse_args(argv)
    m = lire(a.journal)
    r = analyser(m)
    prefixe = a.sortie or os.path.splitext(a.journal)[0]
    os.makedirs(os.path.dirname(os.path.abspath(prefixe)), exist_ok=True)
    image, md = prefixe + "-fatigue.png", prefixe + "-fatigue.md"
    figure(m, r, image, a.titre)
    rapport(r, md, image, a.journal)
    print(f"{r['nb']} valeurs : {r['debut']:.1f} → {r['fin']:.1f} Hz, baisse {r['baisse']:.1f} % : {interpretation(r['baisse'])}")
    print(f"Figure : {image}\nRapport : {md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
