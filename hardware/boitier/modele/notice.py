"""Notice de montage et de pose du boîtier (2 pages A4).   cd hardware/boitier && python modele/notice.py notice-boitier.pdf"""
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak, KeepTogether
from reportlab.lib.styles import ParagraphStyle
pdfmetrics.registerFont(TTFont('DV', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DVB', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
from reportlab.lib.fonts import addMapping
addMapping('DV',0,0,'DV'); addMapping('DV',1,0,'DVB')
ROUGE = colors.HexColor('#c8102e')
t = ParagraphStyle('t', fontName='DVB', fontSize=17, leading=21, spaceAfter=2)
st = ParagraphStyle('st', fontName='DV', fontSize=9, textColor=colors.HexColor('#555555'), spaceAfter=6)
h = ParagraphStyle('h', fontName='DVB', fontSize=12, leading=15, textColor=ROUGE, spaceBefore=8, spaceAfter=4)
p = ParagraphStyle('p', fontName='DV', fontSize=9, leading=12)
c = ParagraphStyle('c', fontName='DV', fontSize=8.5, leading=11)
img = lambda f, w: Image(f, width=w, height=w * __import__('PIL.Image', fromlist=['x']).open(f).size[1] / __import__('PIL.Image', fromlist=['x']).open(f).size[0])
def tab(rows, widths):
    tb = Table([[Paragraph(str(x), c) for x in r] for r in rows], colWidths=widths)
    tb.setStyle(TableStyle([('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#999999')), ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#eeeeee')),
                            ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('TOPPADDING', (0, 0), (-1, -1), 2), ('BOTTOMPADDING', (0, 0), (-1, -1), 2)]))
    return tb
I = 'images/'
s = []
s += [Paragraph('Athletix-Data · Boîtier du brassard : montage et pose', t),
      Paragraph('Conçu par Valentin Auger, novembre 2026. Prototype : pas un dispositif médical. Cotes « à vérifier » au pied à coulisse sur les pièces reçues avant d\'imprimer.', st)]
s.append(img(I + 'apercu.jpg', 180 * mm))
s.append(Paragraph('1. Pièces à imprimer (PETG du devis, aucune vis, aucun insert)', h))
s.append(tab([['Pièce', 'Fichier', 'Sens d\'impression', 'Rôle'],
              ['Boîtier', 'boitier.stl', 'fond sur le plateau', 'poche du capteur, plots et pions de la carte, passants renforcés, pion en baïonnette du bouchon'],
              ['Couvercle', 'couvercle.stl', 'face gravée sur le plateau', '7 clips, jupe contre la pluie, picots et nervures qui plaquent tout'],
              ['Bac à batterie', 'bac-batterie.stl', 'à plat', 'tient la batterie, ses 4 doigts serrent la carte'],
              ['Bouchon USB-C', 'bouchon-usb.stl', 'collerette sur le plateau', 'ferme la prise contre la pluie'],
              ['Boucle 3 barres', 'serre-bande.stl', 'à plat', 'de secours, si le scratch ne serre pas assez']],
             [26 * mm, 30 * mm, 36 * mm, 88 * mm]))
s.append(Paragraph('Deux versions : <b>fichiers/ds12lr/</b> (interrupteur rond DS12LR) ou <b>fichiers/petit-interrupteur/</b> (GR33 / GA55). À prévoir en plus : une mousse de 1,5 mm pour la batterie.', p))
s.append(Paragraph('2. Montage (dans l\'ordre)', h))
etapes = [
    '<b>Interrupteur</b> : le clipser dans le bout côté coude. Ses fils passent au-dessus du capteur jusqu\'à la carte.',
    '<b>Capteur</b> : MyoWare + Link Shield dans la poche (interrupteur du Link Shield sur <b>RAW</b>, firmware 1.2). Fiche jack par le passage de la cloison.',
    '<b>Carte</b> : sur ses 4 plots, deux pions dans les trous de fixation, prise USB-C face à l\'ouverture.',
    '<b>Bac</b> : sur ses 4 colonnes (ergots dans les trous). Batterie dans le bac, mousse dessus. Brancher la prise JST : <b>vérifier la polarité</b> (rouge = +).',
    '<b>Bouchon</b>, <b>avant de poser le couvercle</b> : le retourner (tête en haut), enfiler sa languette sur le pion du boîtier (les 2 ailes passent dans les 2 encoches), le redescendre et l\'enfoncer dans la prise USB-C. Couvercle posé, il ne peut plus se détacher. Pour charger : le sortir de la prise et le faire pivoter sur le pion.',
    '<b>Fermer</b> (après le bouchon) : poser le couvercle, flèche vers le bout USB, appuyer jusqu\'aux 7 clics. <b>Ouvrir</b> : tournevis plat dans l\'encoche côté coude, à côté de l\'interrupteur.'
]
for i, e in enumerate(etapes, 1):
    s.append(Paragraph(f'{i}. {e}', p))
s.append(PageBreak())
s.append(Paragraph('3. Pose sur le bras', h))
gauche = [img(I + 'pose-sur-le-bras.png', 86 * mm)]
droite = [img(I + 'dessous-electrodes.jpg', 86 * mm), Spacer(1, 3 * mm), img(I + 'brassards.jpg', 86 * mm)]
s.append(Table([[gauche, droite]], colWidths=[90 * mm, 90 * mm], style=[('VALIGN', (0, 0), (-1, -1), 'TOP')]))
pose = [
    'Peau propre et sèche. Clipser les <b>3 électrodes</b> sous le capteur, par l\'ouverture du fond (pas besoin d\'ouvrir) : <b>MID et END dans la longueur du bras</b>, REF sur sa pastille. Retirer les films.',
    'Poser le boîtier sur le <b>devant du biceps</b>, électrodes sur la partie la plus bombée quand on contracte. <b>Flèche et bout USB-C vers l\'épaule</b>, interrupteur vers le coude : le coude se plie sans toucher le boîtier.',
    'Passer chaque brassard (40 × 5 cm, scratch) dans un passant, <b>par-dessus le couvercle</b>, dans le passant d\'en face, puis autour du bras. Serrer sans couper la circulation.',
    'Bras gauche ou droit : même pose. Bras fin : fermer le scratch plus loin ; s\'il ne tient pas, ajouter la boucle 3 barres (surplus plié autour de la barre du milieu). Gros bras : accrocher un 2e brassard du lot au bout.',
    'Allumer avec l\'interrupteur, puis calibrer dans l\'application (mode d\'emploi).']
for i, e in enumerate(pose, 1):
    s.append(Paragraph(f'{i}. {e}', p))
s.append(Paragraph('4. Pluie et transpiration', h))
s.append(Paragraph('Le boîtier <b>résiste à la pluie et à la transpiration</b> : jupe du couvercle qui écarte l\'eau du joint, lèvre intérieure, bouchon USB-C, plus de fenêtre sur le couvercle, interrupteur en bas. Il <b>n\'est pas étanche</b> : pas de douche, pas de piscine (il faudrait un joint et des électrodes déportées, non commandés). Le mode natation de l\'application se teste à sec.', p))
s.append(Paragraph('Résistance : étude RDM des clips, des passants et du pion dans <b>rdm/</b> (et page interactive), modèle corrigé en conséquence.', p))
s.append(Paragraph('5. À vérifier à la réception, avant d\'imprimer', h))
s.append(tab([['Cote', 'Valeur du modèle', 'Si elle est fausse'],
              ['Pile MyoWare + Link Shield, prise jack', 'hauteur 14 mm, jack à 9 mm du fond', 'changer MYO_PILE, JACK_Z, JACK_Y'],
              ['Pressions des électrodes', 'dans l\'ouverture 30 × 27 mm', 'changer FENETRE_X, FENETRE_Y'],
              ['Trous de la carte Thing Plus', 'Ø 2,5 à 2,54 mm des coins', 'changer TROUS_RETRAIT, PION_D'],
              ['Petit interrupteur GR33 / GA55', '15 × 10 mm, 12 mm de profondeur', 'changer PETIT_L, PETIT_H, PETIT_PROF'],
              ['Brassard', '50 mm de large, 2 mm d\'épaisseur', 'changer BANDE_L, BANDE_EP']],
             [52 * mm, 58 * mm, 70 * mm]))
s.append(Paragraph('Chaque cote est un chiffre en haut de <b>modele/boitier.py</b> (CadQuery) : on le change, on relance le script, tous les fichiers sont refaits et le script vérifie qu\'aucune pièce n\'en touche une autre. Les fichiers STEP s\'ouvrent dans Fusion 360 ou SolidWorks.', p))
doc = SimpleDocTemplate(sys.argv[1], pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=12 * mm, bottomMargin=12 * mm,
                        title='Athletix-Data - boîtier : montage et pose', author='Valentin Auger')
doc.build(s)
