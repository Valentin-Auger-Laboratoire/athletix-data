"""Boîtier d'Athletix-Data, conçu par Valentin Auger (version 4 : SANS VIS, tout tient par des clips), modèle paramétrique (CadQuery).

Tout dans un seul boîtier posé sur le biceps, long et fin, le grand côté le long du bras :
  [ interrupteur | MyoWare + Link Shield (fenêtre dessous) | fiche jack | carte + batterie au-dessus | USB-C ]
  Porté : bout USB-C vers l'épaule (flèche gravée), interrupteur vers le coude.

Chaque pièce est bloquée en X, Y et Z (demande de Valentin Auger : rien ne doit bouger en courant) :
  - MyoWare + Link Shield : poche à 4 parois, rebord sous la carte, 4 picots du couvercle sur les coins du Link Shield ;
  - carte Thing Plus : posée sur 4 plots, 2 pions dans ses trous de fixation (X, Y), 4 doigts sous le bac
    qui appuient sur les anneaux des trous (Z) : la carte est serrée comme avec des vis, sans vis ;
  - batterie : bac à 4 bords posé au-dessus de la carte sur 4 colonnes avec ergots, nervures du couvercle
    qui appuient à travers une mousse de 1,5 mm (une batterie LiPo ne doit pas être écrasée) ;
  - interrupteur : clipsé dans le bout côté coude (il est fait pour ça) ;
  - couvercle : 7 clips (languettes souples avec un bec au bout) qui s'enclenchent dans des logements
    creusés dans l'intérieur des parois. Aucune vis, aucun insert (il n'y en a pas dans la commande).

Deux versions de l'interrupteur : DS12LR (rond Ø 20,5 mm, cotes connues) ou petit interrupteur du devis
(GR33 / GA55, découpe réglable à ajuster après mesure).

    python boitier.py   → ../fichiers/ds12lr/ et ../fichiers/petit-interrupteur/ (CadQuery 2.x)
Les cotes marquées « À VÉRIFIER » se mesurent au pied à coulisse sur les pièces reçues.
"""
from pathlib import Path

import cadquery as cq

PAROI, FOND, JEU, CONGE = 2.0, 2.0, 0.3, 1.5
INT_Y, INT_Z = 39.0, 23.0

# MyoWare 2.0 + Link Shield empilés (À VÉRIFIER : hauteur de la pile, position de la prise jack et de l'interrupteur ENV/RAW)
MYO_X, MYO_Y, MYO_PILE = 37.6, 35.9, 14.0
MYO_JEU = 0.4
FENETRE_X, FENETRE_Y = 30.0, 27.0       # ouverture du fond pour les électrodes (À VÉRIFIER : position des pressions MID / END)
JACK_D, JACK_Z, JACK_Y = 9.0, 9.0, 8.5               # passage de la fiche jack dans la cloison, centre au-dessus du fond intérieur
ENV_FENETRE = (12.0, 7.0)               # fenêtre du couvercle au-dessus de l'interrupteur ENV / RAW
CLOISON_EP = 1.6

# Carte Thing Plus ESP32-S3 : 58,4 × 22,9 mm, trous à 2,54 mm des coins (À VÉRIFIER)
CARTE_X, CARTE_Y, CARTE_EP = 58.4, 22.9, 1.6
TROUS_RETRAIT = 2.54
PLOT_H, PLOT_D, PLOT_TROU = 3.0, 5.0, 2.2
COMPOSANTS_H = 3.5                      # hauteur des composants sur la carte (place sous le bac)
USB_L, USB_H, USB_Z_SUR_CARTE = 10.0, 4.5, 1.6

# Batterie 47 × 29 × 10 mm (+0,5 de jeu par côté), bac au-dessus de la carte
BAT_X, BAT_Y, BAT_Z = 47.0, 29.0, 10.0
BAT_JEU = 0.5
BAC_EP, BAC_BORD = 1.2, 4.0
MOUSSE = 1.5
COLONNE_D, ERGOT_D, ERGOT_H = 5.0, 2.0, 1.1   # ergot plus court que l'épaisseur du bac (1,2)

# Interrupteurs
DS12_D, DS12_PROF, DS12_COLLERETTE = 20.5, 16.0, 23.0
Z_INTER = FOND + INT_Z / 2 - 0.5                      # hauteur de l'axe de l'interrupteur
PETIT_L, PETIT_H, PETIT_PROF = 15.0, 10.0, 12.0   # À MESURER sur le GR33 / GA55 reçu

# Couvercle
COUV_EP, LEVRE_H, LEVRE_EP = 2.0, 2.0, 1.2
# Clips du couvercle : languette de 9 mm × 1,2 mm, bec de 0,9 mm (0,6 mm accroché dans la paroi).
# Allongement maxi à l'enclenchement ≈ 1,5·e·f/L² ≈ 1,3 % : bon en PETG, juste en PLA.
CLIP_L, CLIP_LARG, CLIP_BEC, CLIP_FENTE = 9.0, 8.0, 0.9, 0.8
# Pions et doigts de la carte (trous de la Thing Plus : Ø 2,5 environ, À VÉRIFIER)
PION_D, PION_DEPASSE, DOIGT_D = 2.0, 1.0, 3.6
PICOT_D = 3.0

# Pattes pour la bande (À MESURER : largeur de la bande)
# Bande : brassards réfléchissants du devis (réf. Leroy Merlin 99381463) : sangle élastique OUVERTE de 40 × 5 cm,
# fermée par scratch (fiche du produit). Deux brassards, un par paire de passants. La bande passe dans la fente
# d'un passant, par-dessus le couvercle, puis dans la fente d'en face, et fait le tour du bras : elle plaque le
# boîtier (et donc les électrodes) sur la peau, et les passants l'empêchent de glisser le long du boîtier.
# Épaisseur supposée 2 mm (plus au niveau du scratch) : fente de 4 mm pour y glisser le bout avec le scratch.
BANDE_L, BANDE_EP = 50.0, 2.0
PATTE_LONG, PATTE_EP, FENTE_EP = 8.0, 3.0, BANDE_EP + 2.0
# Logement de la fiche USB-C côté extérieur (surmoulage du cordon ≈ 12 × 6,5 mm) : la paroi n'y fait plus que 0,6 mm,
# sinon la fiche ne rentre pas assez loin dans la prise de la carte.
USB_SURMOULE, USB_PAROI_RESTE = (13.0, 8.0), 0.6
# Pluie : le bout USB-C est en haut quand le brassard est porté. Jupe du couvercle (comme une casquette : l'eau qui
# coule sur le couvercle tombe à l'extérieur au lieu d'entrer dans le joint) + bouchon pour l'USB-C, en PETG.
JUPE_EP, JUPE_H, JUPE_JEU = 1.2, 2.5, 0.3

SORTIES = Path(__file__).resolve().parent.parent / "fichiers"


class Plan:
    """Positions calculées selon la version de l'interrupteur (x = 0 : paroi intérieure côté capteur)."""

    def __init__(self, interrupteur: str):
        self.inter = interrupteur
        # Interrupteur dans le bout côté coude (−X) : les grands côtés restent libres pour les brassards.
        self.zone_s = (DS12_PROF if interrupteur == "ds12lr" else PETIT_PROF) + 1.0   # logement de l'interrupteur
        self.a0 = self.zone_s + CLOISON_EP                      # début de la poche du capteur
        self.zone_a = MYO_X + 2 * MYO_JEU                      # poche du capteur
        self.myo_c = self.a0 + self.zone_a / 2                  # milieu du capteur
        self.zone_g = 15.0                                      # fiche jack
        self.x_cloison = self.a0 + self.zone_a
        self.zone_b0 = self.x_cloison + CLOISON_EP + self.zone_g
        self.zone_b = CARTE_X + 1.0                             # carte (et bac au-dessus)
        self.int_x = self.zone_b0 + self.zone_b
        self.ext_x = self.int_x + 2 * PAROI
        self.ext_y = INT_Y + 2 * PAROI
        self.h = FOND + INT_Z
        self.z_carte = FOND + PLOT_H
        self.z_bac = self.z_carte + CARTE_EP + COMPOSANTS_H     # dessous du bac
        self.z_bat = self.z_bac + BAC_EP
        self.x_carte0 = self.int_x - CARTE_X - 0.5              # carte calée contre la paroi USB-C
        self.x_bat0 = self.int_x - (BAT_X + 2 * BAT_JEU + 2 * 1.2) - 4.5   # bac (59,4 mm) entre la zone du milieu et la paroi USB-C

    def X(self, x):  # repère intérieur → repère centré
        return x - self.int_x / 2


def clips(p: Plan) -> list[tuple[float, float, float]]:
    """Position (x, y) du milieu de chaque clip au ras de la paroi intérieure et angle (0 : paroi +Y)."""
    return [(p.X(p.myo_c), 0, 0), (p.X(p.zone_b0 + p.zone_b / 2), 0, 0),
            (p.X(p.myo_c), 0, 180), (p.X(p.zone_b0 + p.zone_b / 2), 0, 180),
            (14.0, 0, 90), (-14.0, 0, 90), (0, 0, -90)]   # bout −X : 2 clips de part et d'autre de l'interrupteur


def placer(p: Plan, piece: cq.Workplane, cx: float, ang: float) -> cq.Workplane:
    """Le modèle est dessiné pour la paroi +Y (paroi intérieure en y = 0) ; on le tourne et le pose sur la bonne paroi."""
    if ang in (0, 180):
        return piece.translate((0, INT_Y / 2, 0)).rotate((0, 0, 0), (0, 0, 1), ang).translate((cx, 0, 0))
    return piece.translate((cx, p.int_x / 2, 0)).rotate((0, 0, 0), (0, 0, 1), ang)


def languette() -> cq.Workplane:
    """Languette du couvercle (repère : dessous du couvercle en z = 0, paroi intérieure en y = 0)."""
    L, e, b = CLIP_L, LEVRE_EP, CLIP_BEC
    bras = cq.Workplane("XY").box(CLIP_LARG, e, L, centered=(True, False, False)).translate((0, -JEU - e, -L))
    bec = (cq.Workplane("YZ").polyline([(-JEU, -L + 0.3), (-JEU + b, -L + 2.3), (-JEU + b, -L + 2.8), (-JEU, -L + 3.7)]).close()
           .extrude(CLIP_LARG).translate((-CLIP_LARG / 2, 0, 0)))
    return bras.union(bec)


def fentes_languette() -> cq.Workplane:
    """Deux fentes dans la lèvre, de chaque côté de la languette, pour qu'elle plie."""
    f = cq.Workplane("XY")
    for s in (-1, 1):
        f = f.union(cq.Workplane("XY").box(CLIP_FENTE, 4, LEVRE_H + 0.2, centered=(True, True, False))
                    .translate((s * (CLIP_LARG / 2 + CLIP_FENTE / 2), -JEU - LEVRE_EP / 2, -LEVRE_H - 0.1)))
    return f


def logement(p: Plan) -> cq.Workplane:
    """Logement du bec creusé dans la paroi (repère absolu en z : dessous du couvercle en z = p.h)."""
    L = CLIP_L
    return (cq.Workplane("YZ").polyline([(0, -L + 0.1), (0.8, -L + 0.1), (0.8, -L + 2.75), (0, -L + 3.55)]).close()
            .extrude(CLIP_LARG + 1).translate((-(CLIP_LARG + 1) / 2, -0.01, p.h)))


def boite(p: Plan) -> cq.Workplane:
    c = (cq.Workplane("XY").box(p.ext_x, p.ext_y, p.h, centered=(True, True, False))
         .edges("|Z").fillet(CONGE + PAROI).edges("<Z").fillet(CONGE))
    c = c.cut(cq.Workplane("XY").box(p.int_x, INT_Y, INT_Z + 1, centered=(True, True, False)).translate((0, 0, FOND))
              .edges("|Z").fillet(CONGE))

    # --- Zone capteur : fenêtre dans le fond + cales pour serrer le MyoWare en Y
    fen = cq.Workplane("XY").box(FENETRE_X, FENETRE_Y, FOND * 3, centered=True).translate((p.X(p.myo_c), 0, FOND / 2)).edges("|Z").fillet(3)
    c = c.cut(fen)
    cale = (INT_Y - (MYO_Y + 2 * MYO_JEU)) / 2
    if cale > 0.05:
        for s in (-1, 1):
            c = c.union(cq.Workplane("XY").box(p.zone_a, cale, MYO_PILE, centered=(True, True, False))
                        .translate((p.X(p.myo_c), s * (INT_Y / 2 - cale / 2), FOND)))
    # Cloison entre le logement de l'interrupteur et le capteur (les fils de l'interrupteur passent au-dessus)
    c = c.union(cq.Workplane("XY").box(CLOISON_EP, INT_Y, MYO_PILE, centered=(True, True, False)).translate((p.X(p.zone_s + CLOISON_EP / 2), 0, FOND)))
    # Cloison entre le capteur et le reste, avec passage de la fiche jack et fente pour collier
    cl = cq.Workplane("XY").box(CLOISON_EP, INT_Y, MYO_PILE, centered=(True, True, False)).translate((p.X(p.x_cloison + CLOISON_EP / 2), 0, FOND))
    cl = cl.cut(cq.Workplane("YZ").circle(JACK_D / 2).extrude(10).translate((p.X(p.x_cloison - 3), JACK_Y, FOND + JACK_Z)))
    cl = cl.cut(cq.Workplane("XY").box(4, JACK_D, JACK_Z + 0.01, centered=(True, True, False)).translate((p.X(p.x_cloison + CLOISON_EP / 2), JACK_Y, FOND + JACK_Z)))
    c = c.union(cl)

    # --- Plots de la carte
    x0 = p.X(p.x_carte0)
    trous = [(x0 + TROUS_RETRAIT, -CARTE_Y / 2 + TROUS_RETRAIT), (x0 + CARTE_X - TROUS_RETRAIT, -CARTE_Y / 2 + TROUS_RETRAIT),
             (x0 + TROUS_RETRAIT, CARTE_Y / 2 - TROUS_RETRAIT), (x0 + CARTE_X - TROUS_RETRAIT, CARTE_Y / 2 - TROUS_RETRAIT)]
    for i, (tx, ty) in enumerate(trous):
        c = c.union(cq.Workplane("XY").circle(PLOT_D / 2).extrude(PLOT_H).translate((tx, ty, FOND)))
        if i in (0, 3):   # 2 pions en diagonale : ils placent la carte sans la contraindre si un trou est un peu décalé
            c = c.union(cq.Workplane("XY").circle(PION_D / 2).extrude(CARTE_EP + PION_DEPASSE).translate((tx, ty, p.z_carte)))
    p.trous = trous
    # USB-C dans la paroi d'extrémité (+X)
    zu = p.z_carte + CARTE_EP + USB_Z_SUR_CARTE
    c = c.cut(cq.Workplane("YZ").rect(USB_L, USB_H).extrude(PAROI * 3).edges("|X").fillet(1.2).translate((p.ext_x / 2 - PAROI * 1.5, 0, zu)))
    c = c.cut(cq.Workplane("YZ").rect(*USB_SURMOULE).extrude(PAROI).edges("|X").fillet(2).translate((p.ext_x / 2 - PAROI + USB_PAROI_RESTE, 0, zu)))

    # --- Colonnes du bac à batterie (dans les bandes libres de chaque côté de la carte) avec ergots
    yc = (CARTE_Y / 2 + INT_Y / 2) / 2
    for xc in (p.X(p.x_bat0 + 4), p.X(p.int_x - 4)):
        for s in (-1, 1):
            col = cq.Workplane("XY").circle(COLONNE_D / 2).extrude(p.z_bac - FOND).translate((xc, s * yc, FOND))
            erg = cq.Workplane("XY").circle(ERGOT_D / 2).extrude(ERGOT_H).translate((xc, s * yc, p.z_bac))
            c = c.union(col).union(erg)

    # --- Interrupteur dans le bout côté coude (−X)
    zi = Z_INTER
    if p.inter == "ds12lr":
        c = c.cut(cq.Workplane("YZ").circle(DS12_D / 2).extrude(PAROI * 3).translate((-p.ext_x / 2 - PAROI, 0, zi)))
    else:
        c = c.cut(cq.Workplane("YZ").rect(PETIT_L, PETIT_H).extrude(PAROI * 3).translate((-p.ext_x / 2 - PAROI, 0, zi)))

    # --- Œillet pour la ficelle du bouchon USB-C (bout +X, à côté du logement)
    yo, zo = 15.0, 12.0
    oeil = cq.Workplane("XY").box(3.5, 5.0, 6.0, centered=(False, True, True)).edges("|Y").fillet(1.2).translate((p.ext_x / 2 - 0.01, yo, zo))
    oeil = oeil.cut(cq.Workplane("XZ").circle(1.0).extrude(4, both=True).translate((p.ext_x / 2 + 1.9, yo, zo)))
    c = c.union(oeil)

    # --- Logements des clips du couvercle, creusés dans l'intérieur des parois
    for (cx, _, ang) in clips(p):
        c = c.cut(placer(p, logement(p), cx, ang))

    # --- Pattes : 2 de chaque côté (±Y), près des extrémités, au ras du fond
    # Deux paires de passants symétriques, entièrement sous le corps du boîtier : chaque brassard passe en entier
    # sur le couvercle (il reste droit) et chaque passant est tenu par la paroi sur toute sa longueur.
    demi = (BANDE_L + 7) / 2
    xl = p.ext_x / 2 - demi - 2.0
    xa, xb = -xl, xl
    p.pattes = (xa, xb)
    for xp in (xa, xb):
        for s in (-1, 1):
            yp = s * (p.ext_y / 2 + PATTE_LONG / 2 - 0.01)
            pat = cq.Workplane("XY").box(BANDE_L + 7, PATTE_LONG + 0.02, PATTE_EP, centered=(True, True, False)).translate((xp, yp, 0)).edges("|Z").fillet(2)
            fen_b = cq.Workplane("XY").box(BANDE_L + 1, FENTE_EP, PATTE_EP + 2, centered=(True, True, False)).translate((xp, yp + s * 0.8, -1)).edges("|Z").fillet(FENTE_EP / 2 - 0.01)
            # renfort (congé triangulaire) entre le passant et la paroi, sur toute la longueur
            g = (cq.Workplane("YZ").polyline([(0, 0), (s * 2.5, 0), (0, 2.5)]).close().extrude(BANDE_L + 3)
                 .translate((xp - (BANDE_L + 3) / 2, s * (p.ext_y / 2 - 0.01), PATTE_EP - 0.01)))
            c = c.union(pat).union(g).cut(fen_b)
    return c


def couvercle(p: Plan) -> cq.Workplane:
    d = JUPE_JEU + JUPE_EP
    cv = (cq.Workplane("XY").box(p.ext_x + 2 * d, p.ext_y + 2 * d, COUV_EP, centered=(True, True, False))
          .edges("|Z").fillet(CONGE + PAROI + d).edges(">Z").fillet(1.0))
    jupe = (cq.Workplane("XY").box(p.ext_x + 2 * d, p.ext_y + 2 * d, JUPE_H, centered=(True, True, False)).edges("|Z").fillet(CONGE + PAROI + d)
            .cut(cq.Workplane("XY").box(p.ext_x + 2 * JUPE_JEU, p.ext_y + 2 * JUPE_JEU, JUPE_H + 2, centered=(True, True, False)).edges("|Z").fillet(CONGE + PAROI + JUPE_JEU).translate((0, 0, -1)))
            .translate((0, 0, -JUPE_H)))
    # dégagement autour de la collerette de l'interrupteur (bout −X)
    zi = Z_INTER - p.h
    if p.inter == "ds12lr":
        jupe = jupe.cut(cq.Workplane("YZ").circle(DS12_COLLERETTE / 2 + 0.6).extrude(8).translate((-p.ext_x / 2 - 5, 0, zi)))
    else:
        jupe = jupe.cut(cq.Workplane("YZ").rect(PETIT_L + 4.2, PETIT_H + 4.2).extrude(8).translate((-p.ext_x / 2 - 5, 0, zi)))
    # ouverture au bout côté coude (−X, en bas quand on le porte), à côté de l'interrupteur, pour le tournevis
    jupe = jupe.cut(cq.Workplane("XY").box(8, 6, JUPE_H + 1, centered=(True, True, False)).translate((-p.ext_x / 2 - 2, 16.0, -JUPE_H - 0.5)))
    cv = cv.union(jupe)
    lev = (cq.Workplane("XY").box(p.int_x - 2 * JEU, INT_Y - 2 * JEU, LEVRE_H, centered=(True, True, False)).edges("|Z").fillet(CONGE - JEU).translate((0, 0, -LEVRE_H))
           .cut(cq.Workplane("XY").box(p.int_x - 2 * JEU - 2 * LEVRE_EP, INT_Y - 2 * JEU - 2 * LEVRE_EP, LEVRE_H + 1, centered=(True, True, False)).translate((0, 0, -LEVRE_H - 0.5))))
    cv = cv.union(lev)
    # Clips : fentes dans la lèvre + languette avec son bec
    for (cx, _, ang) in clips(p):
        cv = cv.cut(placer(p, fentes_languette(), cx, ang)).union(placer(p, languette(), cx, ang))
    # Encoche au bout côté coude, sous le bord du couvercle, pour glisser un tournevis plat et l'ouvrir
    cv = cv.cut(cq.Workplane("XY").box(3.0, 5, 1.0, centered=(True, True, False)).translate((-(p.ext_x / 2 - 0.5), 16.0, -0.01)))
    # Picots sur les 4 coins du Link Shield (blocage Z du capteur)
    long_picot = INT_Z - MYO_PILE
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = p.X(p.myo_c) + sx * (MYO_X / 2 - 2.5), sy * (MYO_Y / 2 - 2.5)
            cv = cv.union(cq.Workplane("XY").circle(PICOT_D / 2).extrude(long_picot).translate((px, py, -long_picot)))
    # Pas de fenêtre au-dessus de l'interrupteur ENV / RAW : il reste sur RAW (firmware 1.2), une ouverture de moins.
    # Nervures qui appuient sur la batterie à travers la mousse (blocage Z)
    haut_bat = p.z_bat + BAT_Z + MOUSSE
    long_nerv = p.h - haut_bat
    if long_nerv > 0.2:
        xb = p.X(p.x_bat0 + (BAT_X + 2 * BAT_JEU + 2.4) / 2)
        for sy in (-1, 1):
            cv = cv.union(cq.Workplane("XY").box(BAT_X - 6, 2.0, long_nerv, centered=(True, True, False)).translate((xb, sy * BAT_Y / 4, -long_nerv)))
    # Texte décalé vers le capteur pour laisser la place à une flèche gravée qui montre le sens de pose :
    # la flèche pointe vers l'épaule (bout USB-C en haut, capteur vers le coude).
    cv = cv.cut(cq.Workplane("XY").text("ATHLETIX", 7, -0.6, kind="bold").translate((p.X(p.zone_b0 + p.zone_b / 2) - 8, 0, COUV_EP)))
    xf = p.ext_x / 2 - 12
    fleche = (cq.Workplane("XY").polyline([(xf - 5, -1.5), (xf + 1, -1.5), (xf + 1, -4), (xf + 7, 0), (xf + 1, 4), (xf + 1, 1.5), (xf - 5, 1.5)]).close()
              .extrude(-0.6).translate((0, 0, COUV_EP)))
    cv = cv.cut(fleche)
    return cv


def bac(p: Plan) -> cq.Workplane:
    """Bac à batterie : posé sur les 4 colonnes (trous pour les ergots), bords sur les 4 côtés, encoche pour le câble."""
    lx, ly = BAT_X + 2 * BAT_JEU + 2.4, INT_Y - 2 * JEU
    b = cq.Workplane("XY").box(lx + 8, ly, BAC_EP, centered=(True, True, False)).edges("|Z").fillet(1.5)
    poche_x, poche_y = BAT_X + 2 * BAT_JEU, BAT_Y + 2 * BAT_JEU
    bord = (cq.Workplane("XY").box(poche_x + 2.4, poche_y + 2.4, BAC_BORD, centered=(True, True, False))
            .cut(cq.Workplane("XY").box(poche_x, poche_y, BAC_BORD + 1, centered=(True, True, False))).translate((-4 + 0, 0, BAC_EP)))
    b = b.union(bord)
    b = b.cut(cq.Workplane("XY").box(8, 6, BAC_BORD + 1, centered=(True, True, False)).translate((-4 - poche_x / 2 - 1.2, 0, BAC_EP)))  # encoche câble JST
    # trous des ergots
    yc = (CARTE_Y / 2 + INT_Y / 2) / 2
    centre = p.X(p.x_bat0 + lx / 2)
    for xc in (p.X(p.x_bat0 + 4), p.X(p.int_x - 4)):
        for s in (-1, 1):
            b = b.cut(cq.Workplane("XY").circle(ERGOT_D / 2 + 0.2).extrude(BAC_EP + 1).translate((xc - centre, s * yc, -0.5)))
    # Doigts qui appuient sur les anneaux des 4 trous de la carte (blocage Z), percés pour les pions
    for (tx, ty) in p.trous:
        d = cq.Workplane("XY").circle(DOIGT_D / 2).extrude(COMPOSANTS_H + 0.01).translate((tx - centre, ty, -COMPOSANTS_H))
        d = d.cut(cq.Workplane("XY").circle(PION_D / 2 + 0.25).extrude(PION_DEPASSE + 0.5).translate((tx - centre, ty, -COMPOSANTS_H - 0.01)))
        b = b.union(d)
    return b.translate((centre, 0, p.z_bac))


def bouchon_usb(p: Plan) -> cq.Workplane:
    """Bouchon de la prise USB-C, posé dans le logement extérieur (repère : face extérieure du bout +X en x = 0).
    Il remplit le logement (jeu 0,05 mm par côté : il tient serré), entre un peu dans l'ouverture sans toucher la prise,
    et sa collerette couvre les bords. Languette pour le retirer avant de charger."""
    zu = p.z_carte + CARTE_EP + USB_Z_SUR_CARTE
    prof = PAROI - USB_PAROI_RESTE
    corps = cq.Workplane("YZ").rect(USB_SURMOULE[0] - 0.1, USB_SURMOULE[1] - 0.1).extrude(prof).edges("|X").fillet(1.95).translate((-prof, 0, zu))
    nez = cq.Workplane("YZ").rect(USB_L - 0.2, USB_H - 0.2).extrude(USB_PAROI_RESTE - 0.2).edges("|X").fillet(1.1).translate((-prof - USB_PAROI_RESTE + 0.2, 0, zu))
    coll = cq.Workplane("YZ").rect(USB_SURMOULE[0] + 4, USB_SURMOULE[1] + 4).extrude(1.2).edges("|X").fillet(3).translate((0, 0, zu))
    lang = cq.Workplane("YZ").center(0, USB_SURMOULE[1] / 2 + 5).rect(6, 8).extrude(1.2).edges("|X").fillet(2.9).translate((0, 0, zu))
    lang = lang.cut(cq.Workplane("YZ").circle(1.5).extrude(3).translate((-1, 0, zu + USB_SURMOULE[1] / 2 + 6.5)))
    return corps.union(nez).union(coll).union(lang).translate((p.ext_x / 2, 0, 0))


def serre_bande() -> cq.Workplane:
    """Boucle de réglage à 3 barres (comme sur une sangle de sacoche) pour resserrer la bande sur un bras fin :
    on pince le surplus de bande, on passe le pli dans une fente, autour de la barre du milieu, et on le ressort par
    l'autre fente ; en glissant la boucle vers le bras, les deux épaisseurs sont pincées et la bande reste tendue.
    La barre du milieu a des crans pour que ça ne glisse pas. Imprimée à plat, sans support."""
    barre, fente, bord = 3.0, 2 * BANDE_EP + 1.2, 3.0          # chaque fente reçoit le pli (2 épaisseurs)
    lx, ly, ep = BANDE_L + 1.0 + 2 * bord, 3 * barre + 2 * fente, 3.0
    b = cq.Workplane("XY").box(lx, ly, ep, centered=(True, True, False)).edges("|Z").fillet(2.5).edges(">Z or <Z").fillet(0.8)
    for s in (-1, 1):
        b = b.cut(cq.Workplane("XY").box(BANDE_L + 1.0, fente, ep + 2, centered=(True, True, False))
                  .translate((0, s * (barre / 2 + fente / 2), -1)).edges("|Z").fillet(0.6))
    # crans sur le dessus de la barre du milieu
    for i in range(int((BANDE_L - 4) // 3)):
        x = -BANDE_L / 2 + 3 + i * 3
        b = b.union(cq.Workplane("XZ").polyline([(-0.6, ep), (0.6, ep), (0, ep + 0.6)]).close().extrude(barre / 2, both=True).translate((x, 0, 0)))
    return b


def bandes(p: Plan) -> cq.Workplane:
    """Pour l'image seulement : trajet des deux bandes (fente → dessus du couvercle → fente d'en face → tour du bras)."""
    import math
    yf = p.ext_y / 2 + PATTE_LONG / 2 + 0.8          # milieu de la fente
    ht = p.h + COUV_EP + BANDE_EP / 2
    pts = [(-yf, -1.0), (-yf, PATTE_EP + 1), (-p.ext_y / 2 - 0.5, ht - 2), (-p.ext_y / 2 + 3, ht), (p.ext_y / 2 - 3, ht),
           (p.ext_y / 2 + 0.5, ht - 2), (yf, PATTE_EP + 1), (yf, -1.0)]
    R = 50.0                                          # bras d'environ 31 cm de tour, pour le dessin
    cz = -math.sqrt(R * R - yf * yf)
    a0 = math.atan2(-1.0 - cz, yf)
    for i in range(1, 24):
        a = a0 - i * (2 * math.pi - 2 * (a0 - math.atan2(-1.0 - cz, -yf) + math.pi) / 2) / 24
        pts.append((R * math.cos(a), cz + R * math.sin(a)))
    pts.append(pts[0])
    out = cq.Workplane("XY")
    for xp in p.pattes:
        for (y1, z1), (y2, z2) in zip(pts, pts[1:]):
            L = math.hypot(y2 - y1, z2 - z1)
            if L < 1e-6:
                continue
            ang = math.degrees(math.atan2(z2 - z1, y2 - y1))
            seg = (cq.Workplane("XY").box(BANDE_L, L + 0.6, BANDE_EP).rotate((0, 0, 0), (1, 0, 0), ang)
                   .translate((xp, (y1 + y2) / 2, (z1 + z2) / 2)))
            out = out.union(seg)
    return out


def electrodes(p: Plan) -> cq.Workplane:
    """Pour l'image seulement : 3 pastilles Ø 24 mm sous le fond (MID et END dans la longueur du bras, REF à côté).
    Position INDICATIVE : elle dépend de l'emplacement des pressions sur le MyoWare reçu."""
    out = cq.Workplane("XY")
    for (dx, dy) in ((-13.0, -6.0), (13.0, -6.0), (0.0, 15.0)):
        out = out.union(cq.Workplane("XY").circle(12.0).extrude(1.0).translate((p.X(p.myo_c) + dx, dy, -1.0)))
    return out


def temoins(p: Plan) -> dict[str, cq.Workplane]:
    x0 = p.X(p.x_carte0)
    carte = cq.Workplane("XY").box(CARTE_X, CARTE_Y, CARTE_EP, centered=(False, True, False)).translate((x0, 0, p.z_carte))
    for (tx, ty) in p.trous:
        carte = carte.cut(cq.Workplane("XY").circle(2.5 / 2).extrude(5).translate((tx, ty, p.z_carte - 1)))
    # composants : pas sur les anneaux des trous de fixation (zone réservée sur les cartes au format Feather, À VÉRIFIER)
    comp = cq.Workplane("XY").box(CARTE_X - 10, CARTE_Y - 4, COMPOSANTS_H - 0.3, centered=(False, True, False)).translate((x0 + 5, 0, p.z_carte + CARTE_EP))
    usb = cq.Workplane("XY").box(7.5, 9.0, 3.2, centered=(False, True, False)).translate((x0 + CARTE_X - 7.0, 0, p.z_carte + CARTE_EP))
    lx = BAT_X + 2 * BAT_JEU + 2.4
    centre = p.X(p.x_bat0 + lx / 2) - 4
    bat = cq.Workplane("XY").box(BAT_X, BAT_Y, BAT_Z, centered=(True, True, False)).translate((centre, 0, p.z_bat))
    mousse = cq.Workplane("XY").box(BAT_X, BAT_Y, MOUSSE - 0.2, centered=(True, True, False)).translate((centre, 0, p.z_bat + BAT_Z))
    myo = cq.Workplane("XY").box(MYO_X, MYO_Y, MYO_PILE - 0.3, centered=(True, True, False)).translate((p.X(p.myo_c), 0, FOND))
    zi = Z_INTER
    xe = -p.int_x / 2
    if p.inter == "ds12lr":
        inter = (cq.Workplane("YZ").circle(19.0 / 2).extrude(DS12_PROF).translate((xe, 0, zi))
                 .union(cq.Workplane("YZ").circle(DS12_COLLERETTE / 2).extrude(2.0).translate((-p.ext_x / 2 - 2.0, 0, zi))))
    else:
        inter = (cq.Workplane("YZ").rect(PETIT_L - 0.6, PETIT_H - 0.6).extrude(PETIT_PROF).translate((xe, 0, zi))
                 .union(cq.Workplane("YZ").rect(PETIT_L + 3, PETIT_H + 3).extrude(2.0).translate((-p.ext_x / 2 - 2.0, 0, zi))))
    fiche = cq.Workplane("YZ").circle(3.5).extrude(16).translate((p.X(p.x_cloison - MYO_JEU + 0.01), JACK_Y, FOND + JACK_Z))
    return {"carte": carte.union(comp).union(usb), "batterie": bat, "mousse": mousse, "myoware+link": myo, "interrupteur": inter, "fiche jack": fiche}


def construire(version: str) -> dict:
    p = Plan(version)
    b = boite(p)
    cv = couvercle(p)
    bc = bac(p)
    t = temoins(p)
    dossier = SORTIES / ('ds12lr' if version == 'ds12lr' else 'petit-interrupteur')
    dossier.mkdir(parents=True, exist_ok=True)
    bu = bouchon_usb(p)
    for nom, piece in {"boitier": b, "couvercle": cv, "bac-batterie": bc, "serre-bande": serre_bande(),
                       "bouchon-usb": bu.rotate((0, 0, 0), (0, 1, 0), 90)}.items():
        cq.exporters.export(piece, str(dossier / f"{nom}.step"))
        cq.exporters.export(piece, str(dossier / f"{nom}.stl"), tolerance=0.05, angularTolerance=0.2)
    # Vérifications : volume commun nul entre chaque pièce et les pièces imprimées (couvercle posé)
    couv_pose = cv.translate((0, 0, p.h))
    imprime = {"boîtier": b, "couvercle": couv_pose, "bac": bc, "bouchon USB": bu}
    collisions = {}
    for nt, piece in t.items():
        for ni, hote in imprime.items():
            if nt == "mousse" and ni == "couvercle":
                continue  # la mousse est faite pour être serrée par les nervures
            inter = hote.intersect(piece)
            v = inter.val().Volume() if inter.vals() else 0.0
            if v > 0.5:
                collisions[f"{nt} / {ni}"] = round(v, 1)
    for (na, pa, nb, pb) in (("couvercle", couv_pose, "boîtier", b), ("bouchon USB", bu, "boîtier", b), ("bouchon USB", bu, "couvercle", couv_pose)):
        inter = pa.intersect(pb)
        v = inter.val().Volume() if inter.vals() else 0.0
        if v > 0.05:
            collisions[f"{na} / {nb}"] = round(v, 2)
    for ni, hote in {"boîtier": b, "couvercle": couv_pose}.items():
        inter = hote.intersect(bc)
        v = inter.val().Volume() if inter.vals() else 0.0
        if v > 0.5:
            collisions[f"bac / {ni}"] = round(v, 1)
    noms_t = list(t)
    for i in range(len(noms_t)):
        for j in range(i + 1, len(noms_t)):
            if {noms_t[i], noms_t[j]} == {"batterie", "mousse"}:
                continue
            inter = t[noms_t[i]].intersect(t[noms_t[j]])
            v = inter.val().Volume() if inter.vals() else 0.0
            if v > 0.5:
                collisions[f"{noms_t[i]} / {noms_t[j]}"] = round(v, 1)
    # Blocage en Z : jeu entre le haut de chaque pièce et ce qui la retient (couvercle posé)
    jeux = {
        "MyoWare : haut de la pile → picots": round((p.h - (INT_Z - MYO_PILE)) - (FOND + MYO_PILE), 2),
        "batterie + mousse → nervures": round((p.h - max(0, p.h - (p.z_bat + BAT_Z + MOUSSE))) - (p.z_bat + BAT_Z + MOUSSE), 2),
        "composants de la carte → dessous du bac": round(p.z_bac - (p.z_carte + CARTE_EP + COMPOSANTS_H - 0.3), 2),
        "carte → doigts du bac": round((p.z_bac - COMPOSANTS_H) - (p.z_carte + CARTE_EP), 2),
    }
    a = cq.Assembly(name=f"Athletix-Data boitier clips {version}")
    a.add(b, name="boitier", color=cq.Color(0.23, 0.48, 0.84, 0.5))
    a.add(cv, name="couvercle", loc=cq.Location((0, 0, p.h + 30)), color=cq.Color(0.37, 0.56, 0.88))
    a.add(bc, name="bac batterie", color=cq.Color(0.55, 0.55, 0.6))
    a.add(bu, name="bouchon USB", color=cq.Color(0.78, 0.06, 0.18))
    couleurs = {"carte": (0.18, 0.62, 0.27), "batterie": (0.85, 0.69, 0.16), "mousse": (0.95, 0.95, 0.9), "myoware+link": (0.78, 0.06, 0.18),
                "interrupteur": (0.1, 0.1, 0.1), "fiche jack": (0.6, 0.6, 0.65)}
    for n, piece in t.items():
        a.add(piece, name=f"{n} (volume)", color=cq.Color(*couleurs[n]))
    a.export(str(dossier / "assemblage-complet.step"))
    verif = dossier / "verification"
    verif.mkdir(exist_ok=True)
    for n, piece in t.items():
        cq.exporters.export(piece, str(verif / f"{n.replace('+', '-').replace(' ', '-')}.stl"), tolerance=0.1, angularTolerance=0.3)
    cq.exporters.export(couv_pose, str(verif / "couvercle-pose.stl"), tolerance=0.1, angularTolerance=0.3)
    cq.exporters.export(bandes(p), str(verif / "bandes.stl"), tolerance=0.1, angularTolerance=0.3)
    cq.exporters.export(electrodes(p), str(verif / "electrodes.stl"), tolerance=0.1, angularTolerance=0.3)
    cq.exporters.export(bu, str(verif / "bouchon-pose.stl"), tolerance=0.05, angularTolerance=0.2)
    bb = b.val().BoundingBox()
    return {"dossier": dossier, "taille": (round(bb.xlen, 1), round(bb.ylen, 1), round(p.h + COUV_EP, 1)),
            "corps": (round(p.ext_x, 1), round(p.ext_y, 1)), "collisions": collisions, "jeux": jeux,
            "volume_cm3": round((b.val().Volume() + cv.val().Volume() + bc.val().Volume()) / 1000, 1)}


if __name__ == "__main__":
    for v in ("ds12lr", "petit"):
        r = construire(v)
        print(f"\n== version {v} : corps {r['corps'][0]} × {r['corps'][1]} mm, hauteur {r['taille'][2]} mm (avec pattes {r['taille'][0]} × {r['taille'][1]}), "
              f"plastique {r['volume_cm3']} cm³")
        print("   collisions :", r["collisions"] or "aucune")
        for k, j in r["jeux"].items():
            print(f"   jeu {k} : {j} mm")
