# Simulation Simulink de la chaîne EMG

**🇫🇷 Français** · [🇬🇧 English](#english)

Avant de câbler le brassard, l'équipe a modélisé sous **Simulink** toute la chaîne de mesure musculaire : du signal du muscle jusqu'à l'alerte envoyée à l'application. Le modèle s'appelle `AthletixData_EMG_Simulation`.

C'est une **expérimentation** : un modèle d'essai pour choisir les réglages avant le montage, pas une mesure sur le vrai brassard. Le signal du muscle est simulé et la référence des 100 % est supposée.

![Résultat de la simulation corrigée : alerte d'effort intense (haut) et intensité en % MVC avec le seuil de 75 % (bas)](resultat-simulation-corrigee.png)

## La chaîne modélisée (version finale)

![Schéma du modèle Simulink : signal EMG brut, capteur MyoWare 2.0, puis conversion de l'ESP32-S3, calcul RMS et alerte](schema-modele.png)

| Étape | Bloc Simulink | Réglage |
|---|---|---|
| **Signal du muscle** | bruit blanc limité en bande | échantillonné à 2 kHz (période 0,0005 s), puissance 7,1·10⁻⁹, graine 23341 |
| | filtre passe-bande (Butterworth 2 + 2) | 20 à 450 Hz, la bande d'un vrai signal musculaire |
| | profil d'effort (horloge + table) | repos, 40 %, 95 %, 50 %, repos, avec des transitions de 0,3 s |
| Parasite du secteur | sinusoïde | 50 Hz, 0,08 mV |
| **MyoWare 2.0** | amplification | ×1000 (le signal sur la peau est de l'ordre du millivolt) |
| | redressement double alternance (\|u\|) | |
| | filtre passe-bas d'ordre 2 (enveloppe) | 5 Hz |
| **ESP32-S3** | échantillonneur | 500 Hz (2 ms) |
| | quantification du convertisseur | 12 bits sur 0–3,3 V (0,806 mV par pas) |
| | saturation | 0 à 3,3 V |
| | valeur efficace glissante de l'enveloppe | carré, moyenne sur 100 échantillons (200 ms), racine |
| | normalisation | ×100 / 1,85 V → % de la contraction maximale (MVC) |
| | **alerte d'effort intense** (bloc Relay) | s'allume à 75 % MVC, s'éteint sous 70 % |

## Résultat (5 s simulées)

| Phase | Effort demandé | Intensité affichée |
|---|---|---|
| Repos (0–1 s) | 0 % | ≈ 3 % (résidu du 50 Hz) |
| Contraction moyenne (1,3–2 s) | 40 % | ≈ 42–45 % |
| Contraction forte (2,3–3 s) | 95 % | ≈ 92–108 % |
| Contraction légère (3,3–4 s) | 50 % | ≈ 50–55 % |
| Retour au repos | 0 % | ≈ 3 % |

L'intensité suit l'effort demandé. L'alerte s'allume **une seule fois**, d'environ 2,3 s à 3,3 s : l'intensité redescend vers 92 % au milieu de la contraction forte, mais l'hystérésis (fin d'alerte seulement sous 70 %) l'empêche de clignoter.

## À savoir pour lire ce résultat

- **Le dépassement de 100 %** pendant la contraction forte (≈ 104 % et 108 %) vient des variations naturelles du signal autour d'un effort de 95 %. En vrai, la référence des 100 % se mesure pendant une contraction maximale de calibration, propre à chaque personne. Ici, elle est **supposée** (1,85 V).
- **L'alerte mesure l'intensité, pas la fatigue.** La fatigue musculaire se détecte autrement, par exemple par la baisse de la fréquence médiane du signal brut. Il faudrait alors lire la sortie RAW du MyoWare à 1 kHz ou plus.
- **Le calcul RMS porte sur l'enveloppe** déjà lissée par le MyoWare : c'est une moyenne efficace glissante de l'enveloppe, pas la valeur efficace du signal brut.
- Les réglages ont été vérifiés par une reproduction de la chaîne en Python : sur plusieurs tirages aléatoires, un effort de 40 % donne 40 à 43 % et un effort de 95 % donne 95 à 97 %.

## Historique

La première version du modèle utilisait un bruit qui ne changeait de valeur que toutes les 0,1 s, avec un effort constant après 1 s : les pics venaient du tirage aléatoire, et non d'un effort plus fort. Elle a été corrigée en novembre 2026 (bruit à 2 kHz, filtre 20–450 Hz, profil d'effort, gain du MyoWare, hystérésis sur l'alerte). Son résultat est conservé pour comparaison : [`resultat-simulation.png`](resultat-simulation.png).

Le modèle final est dans ce dossier : [`AthletixData_EMG_Simulation.slx`](AthletixData_EMG_Simulation.slx) (enregistré avec MATLAB/Simulink R2026b ; il faut cette version ou une plus récente pour l'ouvrir).

---

<a id="english"></a>

## Simulink simulation of the EMG chain (English)

Before wiring the armband, the team modelled the whole muscle-measurement chain in **Simulink**. This is an **experiment**: a test model used to choose the settings before building, not a measurement on the real armband.

The chain:
- **Muscle signal:** 2 kHz noise, 20–450 Hz band-pass filter, an effort profile (rest, 40 %, 95 %, 50 %, rest) and 50 Hz interference.
- **MyoWare 2.0:** ×1000 gain, full-wave rectification, 5 Hz envelope filter.
- **ESP32-S3:** 500 Hz sampling, 12-bit ADC on 0–3.3 V, 200 ms moving RMS of the envelope, normalisation to % of maximum voluntary contraction (MVC).
- **Alert:** a high-effort alert with hysteresis (on at 75 %, off below 70 %).

![Simulink model diagram](schema-modele.png)

**Result:** the displayed intensity follows the requested effort (≈ 3 % at rest, 42–45 % for 40 %, 92–108 % for 95 %, 50–55 % for 50 %), and the alert turns on once, from about 2.3 s to 3.3 s, without flickering.

**Limits:**
- The 100 % reference (1.85 V) is assumed.
- The alert measures intensity, not fatigue.
- The first version of the model (10 Hz staircase noise, constant effort) was corrected in November 2026. Its result is kept in `resultat-simulation.png`.

**Model file:** [`AthletixData_EMG_Simulation.slx`](AthletixData_EMG_Simulation.slx) (saved with MATLAB/Simulink R2026b; open it with that version or later).
