# Protocole de test du brassard (à la réception du matériel)

> But : vérifier chaque élément **un par un**, du plus simple au plus complet, pour savoir tout de suite d'où vient un problème. Noter chaque résultat dans la colonne « Mesuré » (copier ce fichier ou l'imprimer).
> Les valeurs attendues viennent de la simulation Simulink (Maxence Olivier, [`simulation-emg/`](simulation-emg/README.md)) et des fiches SparkFun.

**Matériel utile :** multimètre, ordinateur avec Arduino IDE, téléphone Android avec l'application gratuite **nRF Connect**, l'application Athletix (APK Android), un rouleau de scotch et un feutre pour étiqueter.

## Étape 0 — Sécurité batterie (avant tout branchement)

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 0.1 | Tension de la batterie LiPo au multimètre | 3,6 à 4,2 V | | |
| 0.2 | **Polarité** : le fil rouge du connecteur de la batterie arrive sur la broche **+** de la prise JST de la carte (voir la sérigraphie) | rouge = + | | |

⚠️ Si la polarité est inversée, **ne pas brancher** : les fabricants ne câblent pas tous ce connecteur dans le même sens. Une inversion peut détruire la carte. Il faut alors inverser les deux fils du connecteur (avec l'aide d'un enseignant).

## Étape 1 — Carte seule, par USB-C

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 1.1 | Téléverser le **faux brassard** ([`faux-brassard-ble/`](faux-brassard-ble/README.md)), moniteur série à 115 200 bauds | `Faux brassard prêt : Athletix-XXXX` | | |
| 1.2 | nRF Connect : le brassard apparaît | nom `Athletix-XXXX`, service `abad0000-…` | | |
| 1.3 | S'abonner à `abad0001`, écrire `01` dans `abad0002` | ≈ 50 paquets de 8 octets par seconde | | |
| 1.4 | Écrire `03` (calibration), attendre 3 s, relire `abad0003` | la référence (octets 2–3) change | | |
| 1.5 | Écrire `02` | les paquets s'arrêtent | | |
| 1.6 | Écrire `09` (commande inconnue) | État `abad0004` = `03 04` (erreur, code 4), la carte ne plante pas | | |

## Étape 2 — Application avec le faux brassard

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 2.1 | Appli → Brassard → Rechercher | `Athletix-XXXX` dans la liste | | |
| 2.2 | Connexion | carte verte, numéro de série `AX-…`, firmware `0.1.0-test` | | |
| 2.3 | Calibrer | nouvelle référence affichée, « Calibration enregistrée » | | |
| 2.4 | Séance de 1 min, puis Terminer | intensité qui suit le profil 0 / 40 / 95 / 50 %, une alerte pendant le 95 %, séance dans « Mes séances » | | |
| 2.5 | Éteindre la carte pendant une séance | message « Liaison Bluetooth perdue », l'appli ne plante pas | | |

## Étape 3 — Alimentation sur batterie

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 3.1 | Souder l'interrupteur DS12LR sur le fil rouge de la batterie, gaine thermo | interrupteur ouvert : 0 V sur la prise JST | | |
| 3.2 | Interrupteur fermé, USB débranché | la carte démarre, le brassard est visible dans nRF Connect | | |
| 3.3 | USB branché, batterie présente | la LED de charge de la carte s'allume | | |

## Étape 4 — Capteur MyoWare 2.0

Link Shield empilé sur le capteur, **interrupteur du Link Shield sur ENV et alimentation sur ON**, câble jack relié à la carte (pointe → A0, bague → 3V3, corps → GND).

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 4.1 | Tension entre bague et corps du jack | ≈ 3,3 V | | |
| 4.2 | Sans électrodes : tension pointe ↔ corps | proche de 0 V | | |
| 4.3 | Électrodes posées (2 sur le biceps dans l'axe du muscle, référence au coude), bras relâché | faible, stable (quelques dizaines de mV) | | |
| 4.4 | Contraction forte | la tension monte nettement (plusieurs centaines de mV), sans rester bloquée vers 3,3 V | | |

Si 4.4 reste bloqué vers 3,3 V : électrodes trop proches ou gain du MyoWare trop fort (petit potentiomètre sur le capteur) → réduire le gain.

## Étape 5 — Firmware final

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 5.1 | Téléverser [`firmware-brassard/`](firmware-brassard/README.md) | `Jauge de batterie : trouvée`, `Brassard prêt` | | |
| 5.2 | Appli → Brassard | firmware `1.0.0`, batterie en % (proche de la jauge) | | |
| 5.3 | Calibrer en serrant au maximum 3 s | référence entre ~500 et ~3 000 mV ; si « signal trop faible », revoir les électrodes | | |
| 5.4 | Repos, bras posé | intensité de quelques % (simulation : ≈ 3 %) | | |
| 5.5 | Effort moyen (porter une bouteille d'eau) | ≈ 40 à 50 % | | |
| 5.6 | Effort fort (serrer fort) | > 75 %, l'alerte s'allume **une seule fois**, ne clignote pas | | |
| 5.7 | Relâcher | l'alerte s'éteint sous 70 % | | |
| 5.8 | Décoller une électrode pendant la mesure | drapeau saturation, puis avertissement après 2 s | | |

## Étape 6 — Séance complète et autonomie

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 6.1 | Séance de 10 min, puis Terminer | séance enregistrée, visible dans « Mes séances » avec la batterie mise à jour | | |
| 6.2 | Classement | la séance (non simulée) rapporte des points : 10 + minutes × intensité moyenne ÷ 50 | | |
| 6.3 | Brassard allumé et connecté en continu | durée avant extinction (objectif : plus de 2 h) | | |
| 6.4 | Brassard dans le boîtier, porté pendant une séance | tient en place, électrodes toujours collées | | |

## Comparer à la simulation

Remplir après l'étape 5, et l'ajouter au README :

| Phase | Simulation | Mesure réelle |
|---|---|---|
| Repos | ≈ 3 % | |
| Effort moyen | 42–45 % (pour 40 % demandé) | |
| Effort fort | 92–108 % (pour 95 % demandé) | |
| Nombre d'alertes pendant l'effort fort | 1 | |
