"""Vérifie que les cotes « après » de rdm.py sont bien celles du modèle (../modele/boitier.py), sans CadQuery.
    python test_rdm.py"""
import re
from pathlib import Path

import rdm

src = (Path(__file__).resolve().parent.parent / "modele" / "boitier.py").read_text()
const = {}
for ligne in src.splitlines():
    m = re.match(r"^([A-Z0-9_, ]+) = (.+?)(\s+#.*)?$", ligne)
    if not m:
        continue
    noms = [n.strip() for n in m.group(1).split(",")]
    try:
        vals = eval(m.group(2), {"__builtins__": {}}, dict(const))   # cotes simples ou calculées à partir des précédentes
    except Exception:
        continue
    vals = vals if isinstance(vals, tuple) and len(noms) > 1 else (vals,)
    for n, v in zip(noms, vals):
        const[n] = v
a = rdm.APRES
verifs = {
    "longueur du clip": (a["clip"]["L"], const["CLIP_L"]),
    "épaisseur du clip": (a["clip"]["t"], const["CLIP_EP"]),
    "largeur du clip": (a["clip"]["b"], const["CLIP_LARG"]),
    "bec du clip": (a["clip"]["bec"], const["CLIP_BEC"]),
    "jeu du couvercle": (a["clip"]["jeu"], const["JEU"]),
    "portée de la barre": (a["passant"]["portee"], const["BANDE_L"] + 1),
    "largeur de la barre": (a["passant"]["barre_y"], const["PATTE_BARRE"]),
    "épaisseur du passant": (a["passant"]["barre_z"], const["PATTE_EP"]),
    "milieu de la fente": (a["passant"]["fente_centre"], const["PATTE_RENFORT"] + const["FENTE_EP"] / 2),
    "Ø de la tige": (a["pion"]["tige_d"], const["PION_TIGE_D"]),
    "longueur de la tige": (a["pion"]["tige_l"], const["PION_TIGE_L"]),
    "ailes": ((a["pion"]["aile_r"], a["pion"]["aile_l"], a["pion"]["aile_ep"]), (const["AILE_R"], const["AILE_L"], const["AILE_EP"])),
    "largeur du boîtier": (rdm.BOITE["ext_y"], const["INT_Y"] + 2 * const["PAROI"]),
}
err = [k for k, (x, y) in verifs.items() if x != y]
for k in err:
    print("DIFFÉRENT :", k, verifs[k])
r = rdm.etude()["apres"]
for nom, c, mini in (("clip", r["clip"]["coef_allongement"], 1.5), ("tenue", r["clip"]["coef_tenue"], 2), ("passant 10 N", r["passant_service"]["coef"], 2),
                     ("passant 40 N", r["passant_max"]["coef"], 1.5), ("pion", r["pion"]["coef"], 2)):
    if c < mini:
        err.append(nom)
        print("COEFFICIENT TROP FAIBLE :", nom, round(c, 2))
print(f"{len(verifs) + 5} vérifications, {len(err)} erreur(s)")
raise SystemExit(1 if err else 0)
