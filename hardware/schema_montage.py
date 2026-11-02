import matplotlib.pyplot as plt
import matplotlib.patches as patches

# Création de la figure
fig, ax = plt.subplots(figsize=(14, 8))
ax.set_xlim(-2, 35)
ax.set_ylim(-10, 15)
ax.axis('off')

# 1. Dessin de la Breadboard (Plaque d'essai)
breadboard = patches.Rectangle((0, -6), 32, 12, edgecolor='gray', facecolor='#f0f0f0', lw=2)
ax.add_patch(breadboard)
ax.text(1, 5.2, "RAIL POSITIF (+9V) - LIGNE ROUGE HAUT", color='red', fontsize=9, weight='bold')
ax.text(1, 4.2, "RAIL MASSE (GND)  - LIGNE BLEUE HAUT", color='blue', fontsize=9, weight='bold')
ax.text(1, -5.8, "RAIL NÉGATIF (-9V) - LIGNE BLEUE BAS", color='navy', fontsize=9, weight='bold')

# Rainure centrale
ax.plot([0, 32], [0, 0], color='gray', linestyle='--', lw=2)
ax.text(0.5, 0.2, "RAINURE CENTRALE (Lignes E / F)", color='gray', fontsize=8)

# 2. Dessin du Circuit Intégré LM358
lm358 = patches.Rectangle((15, -1.5), 6, 3, edgecolor='black', facecolor='#333333')
ax.add_patch(lm358)
ax.text(17.5, -0.2, "LM358", color='white', fontsize=12, weight='bold')
# Broches (Pins) du LM358
pins_bas = ["1:Out1", "2:In1-", "3:In1+", "4:-9V"]
pins_haut = ["8:+9V", "7:Out2", "6:In2-", "5:In2+"]
for i in range(4):
    ax.text(15.2 + i*1.5, -2.2, pins_bas[i], fontsize=8, color='black', weight='bold')
    ax.text(15.2 + i*1.5, 1.8, pins_haut[i], fontsize=8, color='black', weight='bold')

# 3. Composants : Émetteur / Récepteur (Colonnes 2 et 6)
# LED IR
ax.errorbar(2, 2.5, yerr=1.5, fmt='o', color='green', label='LED IR', lw=2)
ax.text(1.5, 2.5, "LED IR", color='green', fontsize=9)
# Phototransistor
ax.errorbar(6, 2.5, yerr=1.5, fmt='o', color='black', label='Phototransistor', lw=2)
ax.text(5.5, 2.5, "Photo-\ntrans.", color='black', fontsize=9)

# 4. Dessin des Connexions Majeures (Fils)
# Alimentation LM358
ax.plot([15.5, 15.5, 5], [1.5, 4.5, 4.5], color='red', lw=2, label='+9V') # Pin 8 au +9V
ax.plot([19.7, 19.7, 5], [-1.5, -5.5, -5.5], color='blue', lw=2, label='-9V') # Pin 4 au -9V
# Masses (Pins 3 et 5)
ax.plot([18.5, 18.5], [-1.5, 4.2], color='black', lw=1.5, linestyle=':') # Pin 3 à la Masse
ax.plot([19.7, 19.7], [1.5, 4.2], color='black', lw=1.5, linestyle=':') # Pin 5 à la Masse

# 5. Dessin de la carte ESP32 DevKit v1 (En bas à droite)
esp32 = patches.Rectangle((24, -9), 7, 4, edgecolor='orange', facecolor='#d1e7dd', lw=2)
ax.add_patch(esp32)
ax.text(24.5, -7.5, "ESP32 DevKit v1\nMICROCONTRÔLEUR", color='darkgreen', fontsize=10, weight='bold')

# Connexion Sortie Finale (Pin 7) vers GPIO34 (entrée analogique) de l'ESP32
# Attention : l'ADC de l'ESP32 accepte 0 à 3,3 V maximum (voir hardware/README.md)
ax.plot([17, 17, 24], [1.5, 3, -6.5], color='purple', lw=2.5, linestyle='-', label='Signal GPIO34')
ax.text(20.5, -6.3, "Vers GPIO34", color='purple', fontsize=10, weight='bold')

# Masse commune vers l'ESP32
ax.plot([24, 22, 22], [-8, -8, 4.2], color='black', lw=2, label='GND Carte')
ax.text(22.2, -8.8, "GND", color='black', fontsize=9)

# Titre de la fenêtre graphique
plt.title("Schéma Complet d'Implantation du Photo-Pléthysmographe (TP)", fontsize=14, weight='bold', pad=20)
plt.savefig("schema_montage.png", dpi=150, bbox_inches="tight")
plt.show()
