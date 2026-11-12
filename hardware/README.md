# Partie électronique

## Brassard EMG (version finale) : câblage présumé

Le matériel n'est pas encore reçu. Ce schéma montre comment les composants commandés seront reliés, d'après les fiches SparkFun : il reste **non testé**.

![Câblage présumé du brassard EMG](cablage-presume.png)

| Liaison | Détail |
|---|---|
| Électrodes → MyoWare 2.0 | 3 électrodes SEN-12969 à boutons-pression : 2 sur le biceps, la référence sur une zone osseuse (coude) |
| MyoWare 2.0 → Link Shield | le Link Shield s'empile sur le capteur et sort le signal par une prise jack 3,5 mm ; son **interrupteur doit être sur ENV** (enveloppe) et son alimentation sur ON |
| Câble jack → ESP32-S3 | pointe = signal sur **A0 = GPIO10** (entrée analogique 12 bits), bague = **+3,3 V**, corps = **GND** |
| Batterie → carte | LiPo 3,7 V 1 500 mAh sur la prise batterie JST, avec l'interrupteur DS12LR sur le fil rouge. ⚠️ Vérifier la polarité avant de brancher |
| Jauge de batterie | MAX17048 intégrée à la carte (I2C, adresse 0x36, GPIO8 / GPIO9) : niveau lu par le firmware |
| USB-C | recharge de la batterie par la carte et programmation |
| Carte → téléphone | Bluetooth LE vers l'application Flutter |

- Alimenté en 3,3 V par la carte, le capteur sort une tension qui reste dans la plage du convertisseur (0 à 3,3 V).
- Le câble Qwiic du devis est une liaison **I2C** (numérique) : il ne transporte pas ce signal analogique, qui doit arriver sur une entrée analogique comme A0.
- Les inverseurs GR33 / GA55 et les résistances 150 Ω du devis ne sont pas représentés : leur usage reste à définir.
- Brochage vérifié sur les fiches SparkFun : [Thing Plus ESP32-S3](https://docs.sparkfun.com/SparkFun_Thing_Plus_ESP32-S3/hardware_overview/) ([schéma](https://cdn.sparkfun.com/assets/5/e/6/5/0/SparkFun_Thing_Plus_ESP32-S3.pdf)), [Link Shield](https://learn.sparkfun.com/tutorials/getting-started-with-the-myoware-20-muscle-sensor-ecosystem/-myoware-20-link-shield). À confirmer sur la carte reçue.
- La chaîne de mesure a été testée en simulation sous Simulink : voir [`simulation-emg/`](simulation-emg/README.md).

Fichiers : `cablage-presume.svg` (source du schéma) et `cablage-presume.png` (image).

### Pièces qui manquent au devis : comment faire sans commander

La commande est passée. Rien à racheter : tout se fait avec le matériel déjà commandé (kit de soudure WTS100, fils FC25, gaine thermo) et des objets courants.

| Ce qui manque | Solution sans commande |
|---|---|
| **Câble jack 3,5 mm** (le Link Shield sort par un jack, câble vendu à part) | Prendre un **vieux câble audio « aux » stéréo** (voiture, enceinte, ancien casque), 3,5 mm mâle-mâle. Vérifier qu'il a **3 contacts** : la fiche montre **2 anneaux noirs** (pointe / bague / corps). Une fiche à 3 anneaux noirs (câble de casque avec micro, 4 contacts) est à éviter. |
| **Embase jack** pour relier le câble à la carte | Pas besoin : **couper le câble** à un bout, dénuder les 3 fils, repérer au multimètre (mode continuité) lequel va à la pointe, à la bague et au corps de la fiche restante, puis les **souder** sur A0 (pointe), 3V3 (bague) et GND (corps). Gaine thermo sur chaque soudure. |
| **Électrodes de rechange** | Le MyoWare utilise des **électrodes à pression standard**, les mêmes que pour un ECG : celles d'une pharmacie ou de la salle de TP de l'école conviennent. En attendant, une électrode peut resservir quelques fois si on la recolle sur son film protecteur après usage (le gel sèche à l'air). Peau propre et sèche avant de les poser. |

### Programmes et tests

| Dossier / fichier | Rôle |
|---|---|
| [`firmware-brassard/`](firmware-brassard/README.md) | **firmware final** : vrai signal, vraie batterie, calculs testés sur ordinateur |
| [`faux-brassard-ble/`](faux-brassard-ble/README.md) | firmware de test : signal inventé, pour tester l'application sur n'importe quel ESP32 |
| [`PROTOCOLE-DE-TEST.md`](PROTOCOLE-DE-TEST.md) | les essais à faire à la réception du matériel, dans l'ordre, avec les résultats attendus |

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
