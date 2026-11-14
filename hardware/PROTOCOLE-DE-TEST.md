# Protocole de test du brassard (à la réception du matériel)

> **Version à imprimer** (cases à cocher, colonnes « Mesuré » vides) : [`fiche-de-test.pdf`](fiche-de-test.pdf), générée à partir de ce fichier par `dart run tools/fiche_test.dart`.
>
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

Préparation du câble (pas d'embase à acheter) : couper un câble audio stéréo 3,5 mm à 3 contacts, repérer les fils au multimètre (continuité avec la pointe, la bague et le corps de la fiche restante), étiqueter, souder, gainer.

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 4.0 | Câble coupé : chaque fil repéré au multimètre, aucun court-circuit entre deux fils | 3 fils distincts | | |
| 4.1 | Tension entre bague et corps du jack | ≈ 3,3 V | | |
| 4.2 | Sans électrodes : tension pointe ↔ corps | proche de 0 V | | |
| 4.3 | Électrodes posées (2 sur le biceps dans l'axe du muscle, référence au coude), bras relâché | faible, stable (quelques dizaines de mV) | | |
| 4.4 | Contraction forte | la tension monte nettement (plusieurs centaines de mV), sans rester bloquée vers 3,3 V | | |

Si 4.4 reste bloqué vers 3,3 V : électrodes trop proches ou gain du MyoWare trop fort (petit potentiomètre sur le capteur) → réduire le gain.

## Étape 5 — Firmware final

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 5.1 | Téléverser [`firmware-brassard/`](firmware-brassard/README.md) | `Jauge de batterie : trouvée`, `Brassard prêt` | | |
| 5.2 | Appli → Brassard | firmware `1.2.0`, batterie en % (proche de la jauge) | | |
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
| 6.4 | Brassard monté dans le boîtier selon la [notice](boitier/notice-boitier.pdf), porté pendant une séance de course | rien ne bouge à l'intérieur (secouer le boîtier), couvercle toujours clipsé, brassards droits, électrodes toujours collées | | |
| 6.5 | Pendant une séance, éteindre le brassard 5 s puis le rallumer (ou s'éloigner) | bandeau « reconnexion… », puis la séance reprend toute seule ; au-delà de 30 s : message « brassard introuvable » | | |
| 6.6 | Brassard rallumé, choisir un sport sans calibrer | l'application propose « Calibrer avant la séance ? » | | |
| 6.7 | Batterie sous 10 % (fin du test d'autonomie) | bandeau « batterie faible » et vibration pendant la séance | | |
| 6.8 | Ceinture ou montre qui diffuse sa fréquence cardiaque, écran Brassard → Rechercher | fréquence cardiaque affichée pendant la séance et dans son détail | | |
| 6.9 | Bracelet MSGM115 : écran Brassard → « Rechercher un bracelet podomètre », puis séance en marchant 100 pas comptés | « PAS (BRACELET) » ≈ 100 pendant la séance, et dans son détail | | |

## Étape 7 — Séance sans connexion (natation), HORS DE L'EAU

Le prototype n'est **pas étanche** : ce test se fait à sec, en éloignant le téléphone.

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 7.1 | Sport « Natation », Démarrer dans l'eau | moniteur série : `Enregistrement sans connexion démarré` | | |
| 7.2 | Téléphone dans une autre pièce (ou Bluetooth coupé) 5 à 10 min, en contractant le biceps de temps en temps | le brassard continue (moniteur série) | | |
| 7.3 | Retour, Récupérer la séance | durée et intensité moyenne cohérentes avec ce qui a été fait, séance visible dans « Mes séances » | | |
| 7.4 | Nouvel essai, puis repos de plus de 5 min avant de revenir | moniteur série : `Enregistrement sans connexion terminé (5 min de repos)` ; la durée récupérée n'inclut pas ces 5 min | | |

## Étape 8 — Fatigue : signal brut et fréquence médiane

Détails : [`firmware-brassard/FATIGUE.md`](firmware-brassard/FATIGUE.md). À faire après l'étape 5.

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 8.1 | Appli → Brassard → « Brut + fatigue », SANS toucher l'interrupteur (resté sur ENV) | au bout de quelques secondes, avertissement « l'interrupteur OUTPUT du Link Shield semble sur ENV » (code 5) | | |
| 8.2 | Interrupteur OUTPUT du Link Shield sur **RAW** | l'avertissement disparaît ; multimètre sur la pointe du jack au repos : environ 1,65 V | | |
| 8.3 | Calibration (serrer fort 3 s) | nouvelle référence, plus basse qu'en ENV (signal brut sans sa composante continue) | | |
| 8.4 | Moniteur série pendant une mesure | aucune ligne « échantillons/s au lieu de 2000 » ; lignes `F,ms,MDF,MNF` 2 fois par seconde | | |
| 8.5 | Repos, puis contraction moyenne | au repos : `F,…,0.0,0.0` (pas de valeur) ; en contraction : MDF entre ~50 et ~200 Hz | | |
| 8.6 | Tenir une charge (bouteille d'eau, bras à 90°) jusqu'à la fatigue, 1 à 2 min | dans l'appli, l'écart de la fréquence médiane devient négatif (fatigue) ; noter la baisse finale | | |
| 8.7 | Terminer la séance | détail de la séance : courbe de la fréquence médiane et baisse en % | | |
| 8.8 | Retour en « Enveloppe », interrupteur sur ENV, recalibrer | séance normale, plus de valeurs de fréquence | | |

## Étape 9 — Appairage sécurisé (liaison chiffrée)

Détails : [`firmware-brassard/SECURITE.md`](firmware-brassard/SECURITE.md). Seulement quand les étapes 1 à 8 marchent.

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 9.1 | Mettre `APPAIRAGE_SECURISE` à 1 dans le firmware, téléverser | moniteur série : `Appairage sécurisé : code ……` ; noter le code sur l'étiquette du boîtier | | |
| 9.2 | Redémarrer le brassard | même code qu'en 9.1 (gardé en mémoire) | | |
| 9.3 | nRF Connect (téléphone non appairé) : lire `abad0003` | lecture refusée, ou demande d'appairage du système | | |
| 9.4 | Application → Brassard → connexion, taper un code FAUX | appairage refusé, message « code faux ? » | | |
| 9.5 | Se reconnecter avec le bon code | « Liaison : chiffrée (appairé avec le code) », séance normale | | |
| 9.6 | Déconnecter puis reconnecter | pas de code redemandé | | |
| 9.7 | Moniteur série : `OUBLIER`, puis se reconnecter | le code est redemandé (sur Android, « Oublier l'appairage » dans l'appli aussi) | | |
| 9.8 | Moniteur série : `NOUVEAU` | nouveau code affiché ; mettre l'étiquette à jour | | |

## Étape 10 — Montre MSGM115 (faisable dès maintenant, sans le brassard)

Il faut seulement l'APK (release « apk » du dépôt), un téléphone Android et la montre chargée. **Forcer l'arrêt de Yoho Sports** avant (la montre n'accepte qu'une application à la fois). Garder Yoho Sports installée pour comparer les valeurs, puis la refermer. Format décrit dans [`architecture/BRACELET-YOHO.md`](../architecture/BRACELET-YOHO.md).

| # | Vérification | Attendu | Mesuré | OK ? |
|---|---|---|---|---|
| 10.1 | Écran Brassard → « Rechercher un bracelet podomètre » → MSGM115 | carte de la montre avec ses pas ; panneau « Bracelet YOHO · firmware 82.78.00.3d » | | |
| 10.2 | Batterie | pastille sur la carte, sur l'accueil (« Montre … % ») ; même valeur que Yoho Sports | | |
| 10.3 | « Faire vibrer » | la montre vibre | | |
| 10.4 | « Mesurer le cœur », bras immobile | valeur en 30 à 60 s ; écart de moins de 5 bpm avec une mesure Yoho Sports faite juste après | | |
| 10.5 | « Estimer la tension » | deux valeurs (estimation) proches de celles de Yoho Sports | | |
| 10.6 | Le matin : « Synchroniser (sommeil) » | durée de la nuit, profond, léger, réveils ; comparer avec Yoho Sports (le calcul est simplifié : quelques minutes d'écart possibles) | | |
| 10.7 | « Envoyer mon profil », puis marcher 100 pas comptés | profil accepté ; distance et calories de la montre cohérentes avec la taille et le poids | | |
| 10.8 | Rappel d'inactivité à 15 min, rester assis | la montre vibre après 15 min | | |
| 10.9 | Séance (marche) sans ceinture cardio | « PAS (BRACELET) » et « CŒUR » viennent de la montre ; batterie de la montre sous les pas | | |
| 10.10 | Appui long sur l'écran musique de la montre (montre appairée dans les réglages Bluetooth d'Android) | lecture / pause, morceau suivant | | |

## Comparer à la simulation

⚠️ Électrodes sur la peau et brassard relié en USB : **PC portable débranché du secteur** (ou isolateur USB).

**Automatique** : enregistrer une séance par le port USB pendant qu'on suit deux fois le cycle d'effort de la simulation, puis lancer `python mesures/comparer_simulation.py essai.txt`. Le script produit la figure (mesure et modèle superposés) et vérifie tous les critères ci-dessous : marche à suivre dans [`mesures/`](../mesures/README.md).

Puis reporter les valeurs ici, et les ajouter au README :

| Phase | Simulation | Mesure réelle |
|---|---|---|
| Repos | ≈ 3 % | |
| Effort moyen | 42–45 % (pour 40 % demandé) | |
| Effort fort | 92–108 % (pour 95 % demandé) | |
| Nombre d'alertes pendant l'effort fort | 1 | |
