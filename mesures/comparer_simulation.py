"""Compare une séance mesurée avec le vrai brassard au modèle de la simulation Simulink.

Entrée : le journal du firmware (lignes « M,ms,mV,RMS,intensité,alerte », voir capturer.py),
pendant que la personne suit le cycle d'effort de la simulation, répété au moins une fois :
  3 s repos · 4 s effort moyen (≈ 40 %) · 3 s effort fort (≈ 95 %) · 5 s effort moyen (≈ 50 %) · 3 s repos.
Sortie : une figure (mesure contre modèle) et un rapport avec les critères du protocole de test
(hardware/PROTOCOLE-DE-TEST.md, « Comparer à la simulation »). Code de sortie 0 si tout est conforme.

  python mesures/comparer_simulation.py journal.txt --sortie resultats/essai-1
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modele  # noqa: E402

SATURATION_MV = 3250

# Critères (repris du protocole de test) : l'effort d'une vraie personne n'est jamais exactement la
# consigne, donc on vérifie que la chaîne de mesure se comporte comme prévu, pas des valeurs exactes.
CRITERES = {
    "repos": (None, 10, "moins de 10 %"),
    "effort moyen": (20, 65, "entre 20 et 65 % (consigne 40–50 %)"),
    "effort fort": (75, None, "au moins 75 % (déclenche l'alerte)"),
}


def lire(chemin):
    """Lit le journal : lignes « M,... » (port série) ou CSV avec en-tête ms,mv,rms,intensite,alerte."""
    lignes = []
    with open(chemin, encoding="utf-8", errors="replace") as f:
        for brut in f:
            champs = brut.strip().split(",")
            if champs and champs[0] == "M":
                champs = champs[1:]
            if len(champs) != 5:
                continue
            try:
                lignes.append([float(c) for c in champs])
            except ValueError:
                continue  # en-tête ou message du firmware
    if len(lignes) < 50:
        raise ValueError(f"{chemin} : moins de 50 mesures lues ({len(lignes)}). Le journal est-il activé (JOURNAL_SERIE) ?")
    d = np.array(lignes)
    ms = d[:, 0]
    ms = ms + np.concatenate([[0], np.cumsum(np.diff(ms) < -1e6) * 2**32])   # retour à zéro de millis()
    return {"t": (ms - ms[0]) / 1000, "mv": d[:, 1], "rms": d[:, 2], "intensite": d[:, 3], "alerte": d[:, 4] > 0}


def reference_alignee(t, decalage):
    """Intensité attendue si le premier cycle commence à `decalage` secondes (repos avant)."""
    tc = t - decalage
    ref = modele.intensite_reference(np.clip(tc, 0, None))
    return np.where(tc < 0, 0.0, ref)


def aligner(t, intensite, pas=0.02):
    """Trouve le début du premier cycle : décalage qui maximise la corrélation avec le modèle."""
    fin = max(0.0, min(30.0, t[-1] - modele.CYCLE_S))
    meilleur, score = 0.0, -2.0
    # Corrélation sur TOUT l'enregistrement (modèle au repos avant le début) : sinon un décalage d'un
    # cycle entier (18 s) aurait le même score, en ignorant le premier cycle.
    for d in np.arange(0, fin + pas / 2, pas):
        ref = reference_alignee(t, d)
        if np.std(ref) == 0 or np.std(intensite) == 0:
            continue
        r = np.corrcoef(ref, intensite)[0, 1]
        if r > score + 1e-9:
            meilleur, score = d, r
    return meilleur, score


def temps_montee(t, y, t0, t1, bas, haut):
    """Temps entre 10 % et 90 % d'une marche de `bas` à `haut`, cherchée entre t0 et t1."""
    m = (t >= t0) & (t <= t1)
    tt, yy = t[m], y[m]
    s10, s90 = bas + 0.1 * (haut - bas), bas + 0.9 * (haut - bas)
    i10 = np.argmax(yy >= s10) if np.any(yy >= s10) else None
    i90 = np.argmax(yy >= s90) if np.any(yy >= s90) else None
    if i10 is None or i90 is None or i90 < i10:
        return None
    return float(tt[i90] - tt[i10])


def analyser(m):
    t, y = m["t"], m["intensite"]
    decalage, correlation = aligner(t, y)
    nb_cycles = int((t[-1] - decalage) // modele.CYCLE_S)
    if nb_cycles < 1:
        raise ValueError("Il faut au moins un cycle complet de 18 s après le début de l'effort.")
    ref = reference_alignee(t, decalage)
    phases = []
    fronts = np.flatnonzero(np.diff(m["alerte"].astype(int)) == 1) + 1
    fin_analyse = decalage + nb_cycles * modele.CYCLE_S
    fronts = fronts[t[fronts] < fin_analyse + 1.0]          # cycles complets seulement
    for c in range(nb_cycles):
        debut_cycle = decalage + c * modele.CYCLE_S
        d = debut_cycle
        for i, (fin, cible, nom) in enumerate(modele.PHASES):
            f = debut_cycle + fin
            sel = (t >= d + 0.5) & (t <= f - 0.3)      # sans les transitions
            v = y[sel]
            phases.append({"cycle": c + 1, "phase": nom, "cible": cible, "debut": d, "fin": f,
                           "moyenne": float(v.mean()), "ecart_type": float(v.std()), "max": float(v.max())})
            d = f
    # Alertes : une par cycle, pendant l'effort fort (ou dans la seconde qui suit)
    alertes = []
    for c in range(nb_cycles):
        fort = [p for p in phases if p["cycle"] == c + 1 and p["phase"] == "effort fort"][0]
        dans = [t[k] for k in fronts if fort["debut"] - 0.5 <= t[k] <= fort["fin"] + 1.0]
        alertes.append(len(dans))
    montees, montees_ref = [], []
    for c in range(nb_cycles):
        fort = [p for p in phases if p["cycle"] == c + 1 and p["phase"] == "effort fort"][0]
        avant = [p for p in phases if p["cycle"] == c + 1 and p["phase"] == "effort moyen"][0]
        tm = temps_montee(t, y, fort["debut"] - 0.5, fort["fin"], avant["moyenne"], fort["moyenne"])
        tr = temps_montee(t, ref, fort["debut"] - 0.5, fort["fin"], 40, 95)
        if tm is not None:
            montees.append(tm)
        if tr is not None:
            montees_ref.append(tr)
    return {
        "decalage": decalage, "correlation": correlation, "nb_cycles": nb_cycles, "phases": phases,
        "alertes_par_cycle": alertes, "nb_fronts_alerte": int(len(fronts)),
        "saturation_pct": float(np.mean(m["mv"] >= SATURATION_MV) * 100),
        "montee_s": float(np.median(montees)) if montees else None,
        "montee_ref_s": float(np.median(montees_ref)) if montees_ref else None,
        "ecart_rms": float(np.sqrt(np.mean((y[t >= decalage] - ref[t >= decalage]) ** 2))),
        "ref": ref,
    }


def verdicts(a):
    """Liste de (critère, valeur, attendu, conforme)."""
    v = []
    for nom, (mini, maxi, texte) in CRITERES.items():
        moyennes = [p["moyenne"] for p in a["phases"] if p["phase"] == nom]
        val = float(np.mean(moyennes))
        ok = (mini is None or val >= mini) and (maxi is None or val <= maxi)
        v.append((f"Intensité, {nom}", f"{val:.0f} %", texte, ok))
    al = a["alertes_par_cycle"]
    v.append(("Alerte pendant l'effort fort", " / ".join(map(str, al)) + " par cycle", "exactement 1 par cycle", all(n == 1 for n in al)))
    v.append(("Alerte qui clignote", f"{a['nb_fronts_alerte']} allumage(s) pour {a['nb_cycles']} cycle(s)",
              "autant d'allumages que de cycles", a["nb_fronts_alerte"] == a["nb_cycles"]))
    v.append(("Saturation du convertisseur", f"{a['saturation_pct']:.1f} % du temps", "moins de 1 %", a["saturation_pct"] < 1))
    if a["montee_s"] is not None:
        ok = a["montee_s"] <= 1.0
        v.append(("Temps de montée vers l'effort fort", f"{a['montee_s']:.2f} s (modèle {a['montee_ref_s']:.2f} s)",
                  "au plus 1 s (fenêtre RMS de 200 ms + réaction du muscle)", ok))
    v.append(("Ressemblance avec le modèle", f"corrélation {a['correlation']:.2f}", "au moins 0,8", a["correlation"] >= 0.8))
    return v


def figure(m, a, chemin, titre):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    t = m["t"]
    fig, (h, b) = plt.subplots(2, 1, figsize=(11, 6), sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    couleurs = {"repos": "#eeeeee", "effort moyen": "#e3f1e3", "effort fort": "#fbe3e3"}
    for p in a["phases"]:
        h.axvspan(p["debut"], p["fin"], color=couleurs[p["phase"]], lw=0)
    h.plot(t, m["intensite"], color="#e67e00", lw=1.2, label="mesure (brassard)")
    h.plot(t, a["ref"], color="#333", lw=1.6, ls="--", label="modèle de la simulation")
    h.axhline(modele.SEUIL_HAUT, color="#c8102e", lw=1, ls=":", label="seuil d'alerte 75 %")
    h.set_ylabel("intensité (% MVC)")
    h.set_ylim(0, max(120, float(m["intensite"].max()) + 10))
    h.legend(loc="upper right", fontsize=8)
    h.set_title(titre, fontsize=11)
    b.fill_between(t, m["alerte"].astype(int), step="post", color="#c8102e", alpha=0.6, label="alerte mesurée")
    b.plot(t, modele.alerte(a["ref"]).astype(int) * 0.6, color="#333", ls="--", lw=1.2, label="alerte du modèle")
    b.set_yticks([0, 1])
    b.set_yticklabels(["non", "oui"])
    b.set_xlabel("temps (s)")
    b.legend(loc="upper right", fontsize=8)
    fig.tight_layout()
    fig.savefig(chemin, dpi=130)
    plt.close(fig)


def rapport(m, a, v, chemin_md, image, source):
    lignes = [
        "# Comparaison avec la simulation", "",
        f"Journal : `{source}` · {len(m['t'])} mesures · {m['t'][-1]:.1f} s · "
        f"{a['nb_cycles']} cycle(s) complet(s), début du premier cycle à {a['decalage']:.2f} s.", "",
        f"![Mesure et modèle]({image})", "",
        "| Critère | Mesuré | Attendu | Conforme |", "|---|---|---|---|",
    ]
    lignes += [f"| {c} | {val} | {att} | {'✅' if ok else '❌'} |" for c, val, att, ok in v]
    lignes += ["", "| Cycle | Phase | Consigne | Moyenne mesurée | Écart type | Maximum |", "|---|---|---|---|---|---|"]
    lignes += [f"| {p['cycle']} | {p['phase']} | {p['cible']:.0f} % | {p['moyenne']:.1f} % | {p['ecart_type']:.1f} | {p['max']:.0f} % |"
               for p in a["phases"]]
    lignes += ["", f"Écart moyen avec le modèle (RMS) : {a['ecart_rms']:.1f} points. "
               "Il dépend surtout de l'effort réellement fourni par la personne : le modèle suit exactement la consigne."]
    with open(chemin_md, "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("journal")
    p.add_argument("--sortie", default=None, help="préfixe des fichiers produits (défaut : à côté du journal)")
    p.add_argument("--titre", default="Brassard Athletix-Data : mesure et modèle de la simulation")
    a = p.parse_args(argv)
    sortie = a.sortie or os.path.splitext(a.journal)[0]
    os.makedirs(os.path.dirname(os.path.abspath(sortie)), exist_ok=True)
    m = lire(a.journal)
    an = analyser(m)
    v = verdicts(an)
    image = sortie + "-comparaison.png"
    figure(m, an, image, a.titre)
    rapport(m, an, v, sortie + "-rapport.md", os.path.basename(image), os.path.basename(a.journal))
    for c, val, att, ok in v:
        print(f"{'OK ' if ok else 'NON'}  {c} : {val} (attendu : {att})")
    print(f"Figure : {image}\nRapport : {sortie}-rapport.md")
    return 0 if all(ok for *_, ok in v) else 1


if __name__ == "__main__":
    sys.exit(main())
