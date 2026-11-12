# Partie électronique

## Brassard EMG (version finale) : câblage présumé

Le matériel n'est pas encore reçu. Ce schéma montre comment les composants commandés seront reliés : c'est un schéma d'intention, **non testé**.

![Câblage présumé du brassard EMG](cablage-presume.png)

| Liaison | Détail |
|---|---|
| Électrodes → MyoWare 2.0 | 3 électrodes SEN-12969 à boutons-pression : 2 sur le biceps, la référence sur une zone osseuse (coude) |
| MyoWare 2.0 → Link Shield | le Link Shield s'empile sur le capteur et sort le signal par une prise jack 3,5 mm |
| Câble jack → ESP32-S3 | 3 conducteurs : signal « enveloppe » sur **A0** (entrée analogique 12 bits), **+3,3 V** et **GND** de la carte |
| Batterie → carte | LiPo 3,7 V 1 500 mAh sur la prise batterie JST, avec l'interrupteur DS12LR sur le fil rouge |
| USB-C | recharge de la batterie par la carte et programmation |
| Carte → téléphone | Bluetooth LE vers l'application Flutter |

- Alimenté en 3,3 V par la carte, le capteur sort une tension qui reste dans la plage du convertisseur (0 à 3,3 V).
- Le câble Qwiic du devis est une liaison **I2C** (numérique) : il ne transporte pas ce signal analogique, qui doit arriver sur une entrée analogique comme A0.
- Les inverseurs GR33 / GA55 et les résistances 150 Ω du devis ne sont pas représentés : leur usage reste à définir.
- Brochage exact à vérifier sur les fiches SparkFun à la réception du matériel.
- La chaîne de mesure a été testée en simulation sous Simulink : voir [`simulation-emg/`](simulation-emg/README.md).

Fichiers : `cablage-presume.svg` (source du schéma) et `cablage-presume.png` (image).

## Première piste : capteur cardiaque (photopléthysmographe)

Le projet a d'abord exploré un capteur cardiaque sur un ESP32 classique. Ces fichiers sont gardés pour l'historique ; ils ne correspondent plus au brassard final.

| Fichier | Rôle |
|---|---|
| `sketch.ino` | Programme ESP32 : lit le signal sur **GPIO34** à 50 Hz et l'envoie sur le port série (115 200 bauds) |
| `diagram.json` | Simulation Wokwi : ESP32 DevKit v1 + un **potentiomètre** qui remplace le capteur sur GPIO34 |
| `wokwi.toml` | Utile seulement pour l'extension Wokwi de VS Code (voir plus bas) |
| `schema_montage.py` | Dessine le schéma d'implantation sur breadboard de ce premier capteur (`python schema_montage.py` → `schema_montage.png`) |
| [`schema_montage.png`](schema_montage.png) | Schéma généré par le script (premier capteur, plus d'actualité) |

### Montage réel

LED IR (émetteur) et phototransistor (récepteur) placés contre la peau. Le signal passe par un double ampli op **LM358** (alimentation ±9 V sur le schéma), puis sa sortie (broche 7) va vers **GPIO34**, une entrée analogique de l'ESP32.

> ⚠️ **Attention à la tension** : l'ADC de l'ESP32 accepte **0 à 3,3 V maximum**. Si le LM358 est alimenté en ±9 V, sa sortie peut dépasser 3,3 V ou devenir négative et endommager l'ESP32. Ajoute un pont diviseur et une diode de protection avant GPIO34, ou alimente l'étage de sortie en 0 / 3,3 V.

### Simulation Wokwi

**Le plus simple : wokwi.com**
1. Crée un projet « ESP32 » sur https://wokwi.com.
2. Remplace le contenu de `sketch.ino` et de `diagram.json` par ceux de ce dossier.
3. Lance la simulation, puis tourne le potentiomètre : la valeur lue (0 à 4095) s'affiche dans le moniteur série.

Wokwi n'a pas de capteur PPG : le potentiomètre sert seulement à faire varier la tension sur GPIO34. L'ancien schéma (batterie Li-ion + interrupteur) a été retiré, car ces pièces n'étaient pas correctement câblées dans Wokwi et l'ESP32 y est de toute façon alimenté par l'USB simulé.

**Avec l'extension Wokwi de VS Code**
L'extension ne compile pas le code : elle charge un firmware déjà compilé. `wokwi.toml` pointait vers un build PlatformIO (`.pio/…`) absent du dépôt. Il pointe maintenant vers la sortie d'`arduino-cli` :
```bash
cd hardware
mkdir sketch && cp sketch.ino sketch/
arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir build sketch
```
`hardware/build/` et `hardware/sketch/` sont ignorés par Git.

### Pas fait sur cette piste

L'ESP32 n'envoie pas encore le signal à l'application. L'étape suivante serait de calculer les BPM sur l'ESP32 (détection des pics), puis de les transmettre en Bluetooth LE ou en Wi-Fi. L'état du brassard peut déjà être enregistré avec `backend/update_hardware.php`.
