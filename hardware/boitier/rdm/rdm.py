"""Étude de résistance des matériaux du boîtier d'Athletix-Data (Valentin Auger, novembre 2026).

Calculs à la main, par la RDM des poutres, des trois pièces qui travaillent :
  1. les clips du couvercle (languettes en porte-à-faux qui plient à la fermeture) ;
  2. la barre extérieure des passants (la bande tourne autour et tire dessus) ;
  3. le pion qui retient le bouchon USB-C.
Chaque pièce est calculée AVANT (premier modèle) et APRÈS (modèle corrigé), avec les mêmes hypothèses.

    python rdm.py   → resultats.json, resultats.md et les figures (dossier courant)
Sans dépendance à CadQuery : les cotes sont recopiées de ../modele/boitier.py (test_rdm.py vérifie qu'elles concordent).
"""
import json
import math
from pathlib import Path

ICI = Path(__file__).resolve().parent

# ---------------------------------------------------------------- matériau : PETG imprimé (valeurs typiques)
# Fiches de filaments PETG (ordre de grandeur, l'impression les change : à confirmer par un essai).
PETG = {
    "E": 2000.0,               # MPa, module d'Young
    "sigma_plan": 45.0,        # MPa, résistance dans le plan des couches
    "sigma_travers": 25.0,     # MPa, résistance en travers des couches (adhérence entre couches ≈ 55 %)
    "eps_plan": 2.0,           # %, allongement admis pour un clip qui plie dans le plan des couches
    "eps_travers": 1.0,        # %, allongement admis en travers des couches
    "mu": 0.3,                 # frottement PETG sur PETG
}
COEF_MINI = {"allongement": 1.5, "contrainte": 2.0}   # coefficients de sécurité visés

# ---------------------------------------------------------------- chargements (hypothèses)
CHARGES = {
    "acc_g": 10.0,             # accélération en course, sur le haut du bras (choc du pied : 3 à 5 g, ×2 de marge)
    "masse_poussee_g": 62.0,   # g : batterie 28 + capteur 10 + bac 4 + carte 8 + couvercle 12 (tout appuie sur le couvercle)
    "mousse_N": 2.0,           # N : mousse sous la batterie, serrée par les nervures
    "T_service_N": 10.0,       # N : tension d'un brassard porté (≈ 2 kPa sur le bras + chocs)
    "T_max_N": 40.0,           # N : brassard tiré très fort au serrage
    "R_bras_mm": 50.0,         # rayon du bras pour la géométrie de la bande (≈ 31 cm de tour)
    "F_bouchon_N": 10.0,       # N : bouchon tiré ou accroché dans un vêtement
}

# ---------------------------------------------------------------- géométrie (recopiée du modèle)
AVANT = {
    "clip": {"L": 9.0, "t": 1.2, "b": 8.0, "bec": 0.9, "jeu": 0.3, "n": 7},
    "passant": {"portee": 51.0, "barre_y": 1.2, "barre_z": 3.0, "fente_centre": 4.8},
    "pion": {"type": "fendu", "tige_d": 2.6, "tete_d": 3.8, "trou_d": 3.0, "fente_l": 3.4, "fente": 0.7},
}
APRES = {
    "clip": {"L": 9.0, "t": 1.0, "b": 8.0, "bec": 0.65, "jeu": 0.3, "n": 7},
    "passant": {"portee": 51.0, "barre_y": 4.0, "barre_z": 3.5, "fente_centre": 4.5},
    "pion": {"type": "baionnette", "tige_d": 3.0, "tige_l": 3.6, "aile_r": 3.0, "aile_l": 2.0, "aile_ep": 2.0},
}
BOITE = {"ext_y": 43.0, "h_couvercle": 29.0}   # largeur du boîtier, hauteur du dessus du couvercle (mm)


def clip(g, m=PETG, ch=CHARGES):
    """Languette en porte-à-faux, section rectangulaire (formules classiques des clips à languette).
    Elle plie EN TRAVERS des couches : le couvercle s'imprime face gravée sur le plateau, languettes vers le haut."""
    y = g["bec"] - g["jeu"]                                    # flèche à l'enfoncement (le bec doit passer la paroi)
    eps = 1.5 * g["t"] * y / g["L"] ** 2 * 100                 # %
    I = g["b"] * g["t"] ** 3 / 12
    P = 3 * m["E"] * I * y / g["L"] ** 3                       # N, effort qui fait plier la languette
    rampe = math.atan(g["bec"] / 2.0)                          # rampe d'entrée du bec (2 mm de haut)
    retenue = math.radians(45)                                 # face d'accroche à 45° (démontable au tournevis)
    mu = m["mu"]
    W_in = P * (mu + math.tan(rampe)) / (1 - mu * math.tan(rampe))
    W_out = P * (mu + math.tan(retenue)) / (1 - mu * math.tan(retenue))
    besoin = ch["masse_poussee_g"] / 1000 * 9.81 * ch["acc_g"] + ch["mousse_N"]
    return {
        "fleche_mm": y, "allongement_pct": eps, "allongement_admis_pct": m["eps_travers"],
        "coef_allongement": m["eps_travers"] / eps,
        "effort_flexion_N": P, "fermeture_N": W_in * g["n"], "ouverture_N": W_out * g["n"],
        "besoin_N": besoin, "coef_tenue": W_out * g["n"] / besoin,
    }


def deviation_bande(g, ch=CHARGES):
    """Angle dont la bande tourne autour de la barre extérieure : elle descend du bord du couvercle vers la fente,
    puis repart en suivant le bras (tangente au cercle du bras)."""
    yf = BOITE["ext_y"] / 2 + g["fente_centre"]
    haut = (BOITE["ext_y"] / 2 + 0.5, BOITE["h_couvercle"])    # bord du couvercle
    d1 = (yf - haut[0], 0.0 - haut[1])                         # direction : du couvercle vers la fente
    R = ch["R_bras_mm"]
    cz = -math.sqrt(max(R * R - yf * yf, 1.0))                 # centre du bras, sous le boîtier
    r = (yf, 0.0 - cz)
    t = (r[1], -r[0])                                          # tangente qui descend
    if t[1] > 0:
        t = (-t[0], -t[1])
    n1, n2 = math.hypot(*d1), math.hypot(*t)
    u1, u2 = (d1[0] / n1, d1[1] / n1), (t[0] / n2, t[1] / n2)
    delta = math.acos(max(-1, min(1, u1[0] * u2[0] + u1[1] * u2[1])))
    res = (u2[0] - u1[0], u2[1] - u1[1])                       # force de la bande sur la barre, par newton de tension
    return delta, (-res[0], -res[1])


def passant(g, T, m=PETG, ch=CHARGES):
    """Barre extérieure du passant : poutre encastrée aux deux bouts, charge répartie (la bande fait 50 mm sur 51)."""
    delta, (fy, fz) = deviation_bande(g, ch)
    Ry, Rz = abs(fy) * T, abs(fz) * T
    L = g["portee"]
    by, bz = g["barre_y"], g["barre_z"]
    Wy = bz * by ** 2 / 6                                      # flexion dans le plan horizontal (vers l'extérieur)
    Wz = by * bz ** 2 / 6                                      # flexion verticale
    sigma = (Ry * L / 12) / Wy + (Rz * L / 12) / Wz            # MPa, aux encastrements
    Iy = bz * by ** 3 / 12
    fleche = Ry * L ** 3 / (384 * m["E"] * Iy)
    return {"T_N": T, "deviation_deg": math.degrees(delta), "R_N": math.hypot(Ry, Rz), "contrainte_MPa": sigma,
            "fleche_mm": fleche, "admis_MPa": m["sigma_plan"], "coef": m["sigma_plan"] / sigma if sigma > 0 else float("inf")}


def pion(g, m=PETG, ch=CHARGES):
    if g["type"] == "fendu":
        # 4 branches de tête fendue : chacune plie de (Ø tête − Ø trou)/2 à l'enfoncement
        t = g["tige_d"] / 2 - g["fente"] / 2
        y = (g["tete_d"] - g["trou_d"]) / 2
        eps = 1.5 * t * y / g["fente_l"] ** 2 * 100
        return {"type": "fendu", "allongement_pct": eps, "admis_pct": m["eps_plan"], "coef": m["eps_plan"] / eps}
    F = ch["F_bouchon_N"]
    d, l = g["tige_d"], g["tige_l"]
    s_tige = 32 * F * l / (math.pi * d ** 3)                   # tige : fibres dans le plan des couches
    porte = g["aile_r"] - d / 2
    s_aile = F * porte / (g["aile_l"] * g["aile_ep"] ** 2 / 6)  # une seule aile prend tout (cas défavorable)
    return {"type": "baionnette", "tige_MPa": s_tige, "coef_tige": m["sigma_plan"] / s_tige,
            "aile_MPa": s_aile, "coef_aile": m["sigma_travers"] / s_aile,   # l'aile du haut plie en travers des couches
            "coef": min(m["sigma_plan"] / s_tige, m["sigma_travers"] / s_aile)}


def etude():
    out = {"materiau": PETG, "charges": CHARGES, "coef_mini": COEF_MINI}
    for nom, g in (("avant", AVANT), ("apres", APRES)):
        out[nom] = {"clip": clip(g["clip"]),
                    "passant_service": passant(g["passant"], CHARGES["T_service_N"]),
                    "passant_max": passant(g["passant"], CHARGES["T_max_N"]),
                    "pion": pion(g["pion"])}
    return out


def ok(c, mini):
    return "✅" if c >= mini else "❌"


def tableau(r):
    a, p = r["avant"], r["apres"]
    lignes = [
        "| Pièce | Critère | Avant | Après | Visé |",
        "|---|---|---|---|---|",
        f"| Clip du couvercle | allongement à la fermeture (en travers des couches, admis {PETG['eps_travers']} %) | {a['clip']['allongement_pct']:.2f} % → coef. {a['clip']['coef_allongement']:.2f} {ok(a['clip']['coef_allongement'], 1.5)} | {p['clip']['allongement_pct']:.2f} % → coef. {p['clip']['coef_allongement']:.2f} {ok(p['clip']['coef_allongement'], 1.5)} | ≥ 1,5 |",
        f"| Clips (×7) | tenue du couvercle / effort à tenir ({p['clip']['besoin_N']:.1f} N) | {a['clip']['ouverture_N']:.0f} N → coef. {a['clip']['coef_tenue']:.1f} | {p['clip']['ouverture_N']:.0f} N → coef. {p['clip']['coef_tenue']:.1f} {ok(p['clip']['coef_tenue'], 2)} | ≥ 2 |",
        f"| Clips (×7) | effort pour fermer à la main | {a['clip']['fermeture_N']:.0f} N | {p['clip']['fermeture_N']:.0f} N | facile |",
        f"| Barre du passant | brassard porté, T = {CHARGES['T_service_N']:.0f} N | {a['passant_service']['contrainte_MPa']:.0f} MPa → coef. {a['passant_service']['coef']:.2f} {ok(a['passant_service']['coef'], 2)} | {p['passant_service']['contrainte_MPa']:.1f} MPa → coef. {p['passant_service']['coef']:.1f} {ok(p['passant_service']['coef'], 2)} | ≥ 2 |",
        f"| Barre du passant | brassard tiré très fort, T = {CHARGES['T_max_N']:.0f} N | {a['passant_max']['contrainte_MPa']:.0f} MPa → coef. {a['passant_max']['coef']:.2f} {ok(a['passant_max']['coef'], 1.5)} | {p['passant_max']['contrainte_MPa']:.0f} MPa → coef. {p['passant_max']['coef']:.2f} {ok(p['passant_max']['coef'], 1.5)} | ≥ 1,5 |",
        f"| Pion du bouchon | avant : enfoncer la tête fendue (admis {PETG['eps_plan']} %) ; après : bouchon tiré à {CHARGES['F_bouchon_N']:.0f} N | {a['pion']['allongement_pct']:.1f} % → coef. {a['pion']['coef']:.2f} {ok(a['pion']['coef'], 1.5)} | tige {p['pion']['tige_MPa']:.0f} MPa, aile {p['pion']['aile_MPa']:.0f} MPa → coef. {p['pion']['coef']:.1f} {ok(p['pion']['coef'], 2)} | ≥ 2 |",
    ]
    return "\n".join(lignes)


def figures(r):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(1, 3, figsize=(13, 3.8))
    # 1. clip : allongement selon la flèche, pour les deux épaisseurs
    ys = [i / 100 for i in range(0, 91)]
    for g, lab, c in ((AVANT["clip"], "avant (1,2 mm)", "#888888"), (APRES["clip"], "après (1,0 mm)", "#c8102e")):
        ax[0].plot(ys, [1.5 * g["t"] * y / g["L"] ** 2 * 100 for y in ys], color=c, label=lab)
        yy = g["bec"] - g["jeu"]
        ax[0].plot([yy], [1.5 * g["t"] * yy / g["L"] ** 2 * 100], "o", color=c)
    ax[0].axhline(PETG["eps_travers"], color="k", ls="--", lw=1)
    ax[0].axhline(PETG["eps_travers"] / 1.5, color="k", ls=":", lw=1)
    ax[0].set(title="Clip du couvercle", xlabel="flèche à la fermeture (mm)", ylabel="allongement (%)")
    ax[0].text(0.02, PETG["eps_travers"] + 0.03, "admis en travers des couches", fontsize=8)
    ax[0].legend(fontsize=8)
    # 2. passant : contrainte selon la tension de la bande
    Ts = list(range(0, 61, 2))
    for g, lab, c in ((AVANT["passant"], "avant (barre 1,2 × 3)", "#888888"), (APRES["passant"], "après (barre 4 × 3,5)", "#c8102e")):
        ax[1].plot(Ts, [passant(g, T)["contrainte_MPa"] for T in Ts], color=c, label=lab)
    ax[1].axhline(PETG["sigma_plan"], color="k", ls="--", lw=1)
    ax[1].axvline(CHARGES["T_service_N"], color="#2e9e44", lw=1)
    ax[1].axvline(CHARGES["T_max_N"], color="#d8b02a", lw=1)
    ax[1].set(title="Barre extérieure du passant", xlabel="tension du brassard (N)", ylabel="contrainte (MPa)", ylim=(0, 150))
    ax[1].legend(fontsize=8)
    # 3. coefficients de sécurité avant / après
    noms = ["clip\n(allongement)", "passant\nT = 10 N", "passant\nT = 40 N", "pion"]
    av = [r["avant"]["clip"]["coef_allongement"], r["avant"]["passant_service"]["coef"], r["avant"]["passant_max"]["coef"], r["avant"]["pion"]["coef"]]
    ap = [r["apres"]["clip"]["coef_allongement"], r["apres"]["passant_service"]["coef"], r["apres"]["passant_max"]["coef"], r["apres"]["pion"]["coef"]]
    x = range(len(noms))
    ax[2].bar([i - 0.2 for i in x], av, 0.4, color="#888888", label="avant")
    ax[2].bar([i + 0.2 for i in x], ap, 0.4, color="#c8102e", label="après")
    ax[2].axhline(1, color="k", lw=1)
    ax[2].set_xticks(list(x), noms, fontsize=8)
    ax[2].set(title="Coefficient de sécurité (1 = rupture)", ylim=(0, 6))
    ax[2].legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(ICI / "rdm-avant-apres.png", dpi=150)


if __name__ == "__main__":
    r = etude()
    (ICI / "resultats.json").write_text(json.dumps(r, indent=2, ensure_ascii=False))
    import re
    (ICI / "resultats.md").write_text(re.sub(r"(\d)\.(\d)", r"\1,\2", tableau(r)) + "\n")
    figures(r)
    print(tableau(r))
