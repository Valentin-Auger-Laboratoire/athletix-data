# Feuille de route : ce qu'il reste à faire

> Mise à jour : 12 novembre 2026. Le matériel a été demandé en juin 2026 ; l'école vient de passer la commande. Livraison attendue **dans un mois au plus tôt** (mi-décembre 2026).
> Cochez les cases au fur et à mesure (bouton ✏️ de GitHub, puis remplacer `[ ]` par `[x]`).

## Où en est le projet

| Partie | État |
|---|---|
| Application Flutter (comptes, profil, conseils, séances, classement, mode démo) | ✅ fait, démo en ligne |
| API PHP / MySQL | ✅ testée sur une vraie base MariaDB : 41 vérifications ([`tests/api/`](tests/api/test_api.sh)) |
| Format Bluetooth (GATT), modèles de données, migrations | ✅ fait ([`architecture/`](architecture/README.md)) |
| Brassard simulé dans l'application (vrais paquets Bluetooth) | ✅ fait, testé |
| Simulation Simulink de la chaîne EMG | ✅ faite ([`hardware/simulation-emg/`](hardware/simulation-emg/README.md)) |
| Câblage du brassard | ✅ schéma présumé vérifié sur les fiches SparkFun ([`hardware/`](hardware/README.md)), non testé |
| Connexion Bluetooth réelle dans l'application (`BrassardBle`) | ✅ écrite, ⏳ à tester avec une carte |
| Écrans Brassard, Calibration, Mes séances, consentement | ✅ faits, testés dans le navigateur |
| Règle de score du classement à partir des mesures EMG | ✅ proposée et codée, ⏳ à valider en équipe |
| Projet Android | ✅ prêt (autorisations Bluetooth), ⏳ APK à compiler dans Android Studio |
| Firmware de test ESP32 (faux brassard) | ✅ écrit, ⏳ jamais testé sur une carte |
| Firmware final (vrai MyoWare, batterie) | ✅ écrit, calculs testés sur ordinateur, ⏳ à flasher |
| Protocole de test | ✅ écrit ([`hardware/PROTOCOLE-DE-TEST.md`](hardware/PROTOCOLE-DE-TEST.md)) |
| Boîtier (Fusion 360) | ✅ modélisé (Valentin), ⏳ fichiers pas encore ajoutés au dépôt |
| Brassard réel câblé, mesuré, calibré | ❌ attend le matériel |

## 1. À faire maintenant, sans le matériel

L'objectif : quand les pièces arrivent, il ne reste plus qu'à souder, flasher et mesurer.

### Décisions d'équipe
- [x] **Web ou Android pour le Bluetooth réel** : **décidé**, web pour la démo en ligne, **Android** (Android Studio) pour l'usage avec le brassard.
- [ ] **Valider la règle de score du classement** : proposée et codée (10 points par séance mesurée + minutes × intensité moyenne ÷ 50, sur 30 jours, séances simulées exclues), voir [`MCD_MLD.md`](architecture/MCD_MLD.md) §5. À garder ou à changer en équipe.

### Application
- [x] **`BrassardBle`** (fait : `lib/services/brassard/brassard_ble.dart`, à tester avec une carte) : la vraie connexion Bluetooth, qui remplace le brassard simulé. Elle implémente l'interface existante `SourceBrassard`, donc aucun écran n'est à modifier (piste : package `flutter_blue_plus`).
- [x] **Écran de calibration** (fait) : consignes (« contracte ton biceps au maximum pendant 3 s »), bouton, envoi de la commande `0x03` au brassard, enregistrement par `save_calibration.php`. La route serveur existe déjà, il manque l'écran et la méthode dans `api.dart`.
- [x] **Historique des séances** (fait) : une route `get_seances.php` et un écran qui liste les séances enregistrées (durée, intensité moyenne et maximale, alertes).
- [x] **Classement** (fait, migration `002`) : coder la règle de score choisie dans `get_classement.php`, puis supprimer la table `performances` devenue inutile (défaut D1).
- [x] **Consentement** (fait) au premier lancement : les mesures sont des données de santé (RGPD), et l'application n'est pas un dispositif médical.

### Serveur
- [x] **Faire tourner l'API pour de vrai** (fait sur MariaDB, script `tests/api/test_api.sh`, 41 vérifications ; à refaire une fois sur votre XAMPP avec l'application Android) : XAMPP, import de `database.sql` puis de `migrations/001_brassard_emg.sql`, application lancée **hors mode démo**. Tester chaque parcours : inscription, code par e-mail, connexion, profil, séance enregistrée.
- [x] Noter les erreurs trouvées et les corriger : aucune erreur de fonctionnement trouvée ; réponses JSON rendues lisibles (accents).

### Brassard (préparation)
- [ ] **Tester le faux brassard** ([`hardware/faux-brassard-ble/`](hardware/faux-brassard-ble/README.md)) : un **ESP32 classique suffit** (celui de la première piste par exemple). Le flasher et vérifier avec l'appli gratuite nRF Connect que les paquets arrivent, puis avec l'application quand `BrassardBle` est prêt.
- [x] **Firmware final** (fait : [`hardware/firmware-brassard/`](hardware/firmware-brassard/README.md), calculs testés sur ordinateur, à flasher) : partir du faux brassard, `SOURCE_SIMULEE 0`, broche du MyoWare, et ajouter le niveau de batterie dans le service Bluetooth (remplace `hardware_status`).
- [x] **Vérifier les fiches techniques** (fait : A0 = GPIO10, jauge MAX17048 en I2C, Link Shield sur ENV, jack pointe / bague / corps ; à confirmer sur la carte reçue) (SparkFun Thing Plus ESP32-S3, MyoWare 2.0, Link Shield) et corriger le [câblage présumé](hardware/README.md) si besoin : broche analogique exacte, alimentation, sortie du Link Shield.
- [ ] **Compléter la commande si possible** (liste dans [`hardware/README.md`](hardware/README.md#à-compléter-dans-la-commande)) : le Link Shield sort le signal par un jack 3,5 mm (câble jack et petite embase à prévoir), les électrodes sont à usage unique (prévoir un paquet de rechange). Le câble Qwiic ne sert pas pour le signal.
- [ ] **Boîtier** : le modèle Fusion 360 est fait (Valentin). Reste à l'exporter en STEP et STL, avec quelques captures, et à l'ajouter au dépôt. Prévoir de vérifier les cotes une fois les pièces en main.
- [x] **Protocole de test écrit** ([`hardware/PROTOCOLE-DE-TEST.md`](hardware/PROTOCOLE-DE-TEST.md)) (voir §2) avec les résultats attendus, pour comparer la mesure réelle à la simulation.

### Projet
- [ ] Mettre à jour le **diagramme de Gantt** avec la nouvelle date de livraison (Maxence).
- [ ] Rédiger le rapport du jalon 1 (voir §3) : ce qui est fait, ce qui bloque (le matériel), ce qui est prévu.

## 2. À la réception du matériel

Dans cet ordre, en notant chaque résultat :

- [ ] **Inventaire** : tout est là ? (comparer au devis)
- [ ] ⚠️ **Polarité de la batterie** : avant de la brancher, vérifier que le rouge du connecteur de la batterie arrive bien sur le **+** de la prise JST de la carte. Les fabricants ne câblent pas tous ce connecteur dans le même sens, et une inversion peut détruire la carte.
- [ ] **Carte seule** par USB-C : téléverser le faux brassard, vérifier le Bluetooth avec nRF Connect.
- [ ] **Soudure** de l'interrupteur sur le fil rouge de la batterie (kit WTS100, gaine thermo), test de mise sous tension sur batterie.
- [ ] **MyoWare sans électrodes** : alimentation 3,3 V, tension de sortie au multimètre (proche de 0 V au repos).
- [ ] **MyoWare avec électrodes** sur le biceps : la tension monte quand on contracte.
- [ ] **Firmware final** (`SOURCE_SIMULEE 0`), puis **calibration** (contraction maximale).
- [ ] **Comparer à la simulation** : au repos ≈ quelques %, effort moyen ≈ 40 à 50 %, effort fort > 75 % avec l'alerte qui s'allume une seule fois. Ajuster les seuils si besoin.
- [ ] **Séance complète** avec l'application : connexion Bluetooth, mesure, résumé enregistré en base.
- [ ] **Autonomie** : brassard allumé en continu, noter la durée (objectif : plus de 2 h).
- [ ] **Boîtier** : impression en PETG, montage, essai porté sur le bras.

## 3. Pour finaliser

- [ ] Vidéo de démonstration du brassard réel avec l'application.
- [ ] README et captures mis à jour avec les vraies mesures (remplacer « câblage présumé » par le câblage réel, photo du montage sans visage).
- [ ] **Jalon 1 du MESPI (2e année)** : rapport d'avancement, dans la continuité des jalons 1 à 4 de 1re année. Ce qui a été fait depuis le jalon 4 (devis), pourquoi ces choix, les perspectives (cette feuille de route) et une courte conclusion.
- [ ] Jalons suivants et soutenance : objectif du semestre impair (S3), un **prototype** qui fonctionne. Le projet est terminé quand le brassard réel marche avec l'application.
- [ ] Ensuite, si le temps le permet : pistes issues de la rencontre avec la patiente atteinte de sclérose en plaques (fatigue musculaire, température, vibration), voir le [README](README.md#rencontre-avec-une-patiente-atteinte-de-sclérose-en-plaques).

## 4. Compléter l'application : le téléphone en plus du brassard

L'application n'est pas qu'un écran pour le brassard : le **téléphone** apporte ses propres mesures, et les deux ensemble doivent donner un suivi complet. Ces idées viennent des jalons de 1re année (« dashboard performances : historique, graphiques de progression, records personnels », « score de fatigue », « GPS ou accéléromètre », « interface médecin / kinésithérapeute ») et de la rencontre avec la patiente atteinte de sclérose en plaques. **Tout ceci peut se faire sans le matériel.**

### Ce que le téléphone peut mesurer
- [ ] **GPS** pour la course, le vélo, le ski : distance, vitesse, allure, dénivelé, tracé du parcours.
- [ ] **Accéléromètre** : cadence et nombre de pas en course, nombre de répétitions en musculation.
- [ ] **Météo** à l'heure de la séance (température, humidité), récupérée en ligne avec la position : elle aide à expliquer une baisse de forme, et la chaleur compte beaucoup pour la sclérose en plaques.
- [ ] **Fréquence cardiaque** : le brassard EMG sur le biceps **ne mesure pas** le rythme cardiaque. Solution simple : relier en Bluetooth une ceinture ou une montre cardio du commerce (service Bluetooth standard « Heart Rate », `0x180D`, que l'application peut lire avec le même package).

### Graphiques
- [ ] **Pendant la séance** : courbe de l'intensité musculaire en direct, avec le seuil d'alerte.
- [ ] **Après la séance** : courbe complète, temps passé par zone d'intensité, et, avec le GPS, vitesse et intensité musculaire superposées.
- [ ] **Évolution** semaine par semaine : nombre de séances, durée, intensité moyenne, temps d'effort intense, records personnels.
- [ ] **Fatigue** : repérer les séances ou les semaines « moins bonnes » (intensité qui baisse pour un même effort, record pas atteint) et les relier au contexte.

### Contexte de chaque séance (pour comprendre les baisses)
- [ ] Après chaque séance : ressenti de fatigue (0 à 10), douleur ou blessure, sommeil de la nuit, avec la météo ajoutée automatiquement.
- [ ] Graphique qui superpose la performance et ce contexte (« cette semaine-là : mauvais sommeil, chaleur, moins bon rendement »).

### Pistes issues de la rencontre avec la patiente atteinte de sclérose en plaques
| Piste (README) | Où on en est |
|---|---|
| Force qui change d'un jour à l'autre : recalibrer à chaque séance | ✅ fait (écran de calibration, historique des calibrations) |
| Données de santé protégées, consentement | ✅ fait (consentement au premier lancement, seul un résumé est stocké) |
| **Fatigue** : la suivre et proposer une pause avant l'épuisement | ⏳ à faire : indicateur dans l'application à partir des séances ; la vraie mesure (baisse de la fréquence médiane) demande le signal **RAW** du MyoWare, lu à 1 kHz ou plus, donc un changement du firmware |
| **Chaleur** : symptômes aggravés quand le corps chauffe | ⏳ à faire : météo par le téléphone (sans matériel) ; un capteur de température de la peau devrait être ajouté à la commande |
| Raideurs et spasmes, asymétrie gauche / droite | ⏳ plus tard : activité au repos détectable avec un capteur ; la comparaison gauche / droite demande un **deuxième** brassard |
| Gestes fins et vue parfois difficiles | ⏳ à faire : mode « grands boutons et texte agrandi », alertes par vibration du téléphone et par la voix |
| Suivi avec les soignants | ⏳ à faire : export des séances et du carnet (PDF ou CSV) à donner au neurologue ou au kinésithérapeute |

## Proposition de répartition

| Qui | Sans le matériel | À la réception |
|---|---|---|
| **Valentin** | API testée sur XAMPP, écrans calibration et historique, firmware final, export du boîtier | soudure, câblage, firmware, intégration dans le boîtier |
| **Othmen** | `BrassardBle`, test du faux brassard avec nRF Connect | connexion Bluetooth réelle avec l'application |
| **Maxence** | Gantt, protocole de test et résultats attendus (d'après sa simulation) | mesures, comparaison avec la simulation |
