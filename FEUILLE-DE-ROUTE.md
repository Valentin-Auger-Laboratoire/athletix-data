# Feuille de route

> Mise à jour : 13 novembre 2026 (après-midi : fatigue, appairage chiffré, fond de carte, limite des essais).
> Le matériel a été demandé en juin 2026 et commandé par l'école en novembre : livraison attendue **mi-décembre 2026 au plus tôt**.
> En attendant, **tout ce qui ne dépend pas des pièces est fait** : l'application est quasiment finie et testée, le firmware est écrit et ses calculs sont testés sur ordinateur. Quand les pièces arrivent, il reste à souder, flasher, mesurer et comparer à la simulation.
> Cochez les cases au fur et à mesure (bouton ✏️ de GitHub, puis remplacer `[ ]` par `[x]`).

## Où en est le projet

| Partie | État |
|---|---|
| **Application Flutter** : comptes, profil, conseils, séances en direct, natation, historique, détail d'une séance, évolution, classement, réglages, mon compte, mode démo | ✅ faite, testée dans le navigateur ([démo en ligne](https://valentin-auger-laboratoire.github.io/athletix-data/)), ⏳ à essayer sur un téléphone Android |
| **API PHP / MySQL** | ✅ testée sur une vraie base MariaDB : 93 vérifications ([`tests/api/`](tests/api/test_api.sh)), limite des essais de mot de passe |
| **Tests automatiques sur GitHub** (application, API, firmware) à chaque envoi | ✅ ([`.github/workflows/tests.yml`](.github/workflows/tests.yml)) |
| Format Bluetooth (GATT), modèles de données, migrations 001 à 004 | ✅ ([`architecture/`](architecture/README.md), [`migrations/`](migrations/)) |
| Brassard simulé dans l'application (vrais paquets Bluetooth) | ✅ |
| Simulation Simulink de la chaîne EMG | ✅ ([`hardware/simulation-emg/`](hardware/simulation-emg/README.md)) |
| Connexion Bluetooth réelle (`BrassardBle`) et ceinture cardio | ✅ écrites, ⏳ à tester avec une carte |
| Firmware final 1.2 (vrai MyoWare, batterie, natation, **fatigue**, **appairage chiffré**) | ✅ écrit, calculs testés sur ordinateur (42 + 34 + 15 vérifications), **programme entier exécuté sur ordinateur** avec un muscle simulé (38 vérifications), ⏳ à flasher |
| Firmware de test (faux brassard) | ✅ écrit, ⏳ jamais testé sur une carte |
| Câblage | ✅ schéma présumé vérifié sur les fiches SparkFun ([`hardware/`](hardware/README.md)), ⏳ non testé |
| Protocole de test | ✅ ([`hardware/PROTOCOLE-DE-TEST.md`](hardware/PROTOCOLE-DE-TEST.md)) |
| Projet Android | ✅ prêt (Bluetooth, GPS, vibration), APK compilé par GitHub ([release « apk »](https://github.com/Valentin-Auger-Laboratoire/athletix-data/releases/tag/apk)), ⏳ à installer sur un téléphone |
| Règle de score du classement | ✅ validée (12 novembre 2026) et codée |
| Boîtier | ✅ cahier des charges et implantation à l'échelle ([`hardware/boitier/`](hardware/boitier/README.md)), ⏳ modèle Fusion 360 à finir et à ajouter (STEP + STL), ⏳ pas étanche |
| Documents pour les essais : mode d'emploi, fiche de test à imprimer | ✅ ([`mode-emploi/`](mode-emploi/mode-emploi.pdf), [`hardware/fiche-de-test.pdf`](hardware/fiche-de-test.pdf)), visibles en haut du README |
| Comparaison automatique mesure / simulation, analyse des risques, Gantt, vidéo | ✅ ([`mesures/`](mesures/README.md), [`gestion-projet/`](gestion-projet/README.md), [`media/`](media/demo-application.mp4)) |
| Brassard réel câblé, mesuré, calibré | ❌ attend le matériel |

## Ce qui est fait

### Application
- **Comptes** : inscription avec code par e-mail, connexion par jeton, questionnaire de profil avec historique et pré-remplissage, conseils calculés par règles, consentement au premier lancement.
- **Brassard** : recherche et connexion Bluetooth, batterie, numéro de série, **calibration** de 3 s, brassard simulé avec les vrais paquets.
- **Séance en direct** : intensité en % de la contraction maximale, courbe des 30 dernières secondes, alerte d'effort intense (vibration, voix), mesure propre à chaque sport calculée en direct, **GPS** (distance, vitesse, allure, dénivelé), **pas**, **météo** au départ, **ceinture cardio** facultative, ressenti en fin de séance (fatigue, douleur, sommeil, commentaire).
- **Natation** : le Bluetooth ne passe pas sous l'eau, donc le brassard garde lui-même le résumé de la séance et l'application le récupère au retour ; arrêt automatique après 5 min de repos ; rien n'est effacé du brassard avant d'être enregistré.
- **Détail d'une séance** : courbe, zones d'intensité, contractions et **séries** (musculation), **tracé du parcours** coloré par l'intensité (sans les 200 premiers et derniers mètres, pour ne pas montrer le domicile), vitesse et intensité le long du parcours, cœur, météo, ressenti, indice de fatigue expérimental expliqué.
- **Mon évolution** : points et volume par semaine, intensité et fatigue ressentie, records personnels, **semaines moins bonnes** repérées avec leurs causes possibles.
- **Accueil** : la semaine en cours face à l'**objectif** (séances par semaine, réglable).
- **Sans réseau** : une séance qui ne peut pas être envoyée est gardée sur le téléphone et envoyée toute seule plus tard, **sans doublon** et avec la bonne date.
- **Pour les soignants** : export du carnet en **PDF** (par semaine et par séance) et en **CSV** (Excel).
- **Accessibilité et mode adapté** (rencontre avec la patiente atteinte de sclérose en plaques) : grands caractères, alertes par vibration et à voix haute, seuils plus bas, pause conseillée, avertissement chaleur.
- **RGPD** : télécharger toutes ses données (JSON), supprimer son compte et ses données (mot de passe redemandé).
- **Mode d'emploi** accessible depuis l'application (menu du profil).
- **Fatigue du muscle** (13 novembre) : choix du signal brut dans l'écran Brassard, fréquence médiane en direct et écart au début, baisse en fin de séance, courbe dans le détail, fatigue par semaine dans « Mon évolution » (et cause possible d'une semaine moins bonne), colonnes dans le PDF et le CSV ([`FATIGUE.md`](hardware/firmware-brassard/FATIGUE.md)).
- **Appairage chiffré** : code à 6 chiffres demandé une fois, état de la liaison, « Oublier l'appairage » ([`SECURITE.md`](hardware/firmware-brassard/SECURITE.md)).
- **Fond de carte OpenStreetMap** sous le parcours (désactivé par défaut, réglage et bouton dans le détail).
- **Prêt pour le vrai brassard** (13 novembre, soir) : reconnexion automatique pendant une séance, avertissements du brassard affichés (batterie, électrode, interrupteur), rappel de calibration avant la séance, **montre** qui diffuse sa fréquence cardiaque reliée comme une ceinture (aide par marque dans l'écran Brassard). À tester : étapes 6.5 à 6.9 du protocole.
- **Bracelet podomètre MSGM115** (13 novembre) : format des pas identifié avec nRF Connect (service FEE7, caractéristique FEA1, 80 pas vérifiés) et lecture codée ; le cœur et le bouton musique de ce bracelet passent par un format du fabricant, à décoder plus tard avec le journal Bluetooth d'Android et l'appli d'origine.
- **Démo en ligne** sans serveur, avec six semaines de séances fictives ; elle se met à jour sans vider le cache du navigateur.

### Serveur
- API PHP / MySQL : comptes, profils, séances (résumé EMG, téléphone, contexte, courbe, tracé), calibrations, historique et détail, classement calculé à partir des mesures, état du brassard, export et suppression du compte.
- Migrations `001` à `006` (relançables sans erreur) : `005` fatigue (fréquence médiane), `006` limite du nombre d'essais (connexion, renvoi du code, suppression du compte).
- 93 vérifications sur une vraie base, relancées automatiquement par GitHub à chaque envoi.

### Préparation des essais et gestion de projet
- **Analyse de la fatigue mesurée** ([`mesures/analyser_fatigue.py`](mesures/README.md)) : lignes `F,…` du port USB → tendance, baisse, figure et rapport. Testé sur des données simulées.
- **Comparaison automatique avec la simulation** ([`mesures/`](mesures/README.md)) : le firmware écrit ses mesures sur le port USB, un script les enregistre, puis un autre les compare au modèle de la simulation (figure et rapport avec les critères du protocole). Testé sur des données simulées.
- **Analyse des risques** ([`gestion-projet/analyse-des-risques.md`](gestion-projet/analyse-des-risques.md)) : gravité × apparition × détection, et actions prioritaires (pas d'essai dans l'eau sans boîtier étanche, PC portable débranché du secteur pendant une capture USB, polarité de la batterie).
- **Mode d'emploi** de 2 pages ([`mode-emploi/mode-emploi.pdf`](mode-emploi/mode-emploi.pdf)) : pose des électrodes, calibration, séance, natation, carnet pour les soignants, problèmes fréquents. À imprimer pour les essais.
- **Fiche de test à imprimer** ([`hardware/fiche-de-test.pdf`](hardware/fiche-de-test.pdf)), générée à partir du protocole.
- **Cahier des charges du boîtier** ([`hardware/boitier/`](hardware/boitier/README.md)) : dimensions des pièces, implantation à l'échelle, ouvertures, fixation, pistes pour une version étanche.
- **Diagramme de Gantt** mis à jour et **vidéo de démonstration** de l'application ([`media/`](media/demo-application.mp4)).

### Brassard
- Choix du matériel et devis (jalon 4 de 1re année), schéma de câblage présumé vérifié sur les fiches techniques, solutions pour les pièces manquantes sans rien commander.
- Format Bluetooth complet ([`GATT.md`](architecture/GATT.md)), firmware de test et **firmware final 1.2** (RMS, % MVC, alerte, calibration, saturation, batterie, natation, signal brut et fréquence médiane sur le second cœur, appairage chiffré), calculs testés sur ordinateur et **programme entier exécuté sur ordinateur** avec des imitations des bibliothèques ESP32 (aussi sous ThreadSanitizer, qui a permis de corriger un échange non protégé entre les deux cœurs).
- Simulation Simulink de la chaîne de mesure (Maxence Olivier), relue et corrigée.

## 1. Reste à faire sans le matériel

- [x] **Règle de score du classement validée** (12 novembre 2026) : 10 points par séance mesurée + minutes × intensité moyenne ÷ 50, sur 30 jours, séances simulées exclues ([`MCD_MLD.md`](architecture/MCD_MLD.md) §5).
- [ ] **Héberger l'API sur le PC portable** (Valentin) : XAMPP + ngrok avec le domaine fixe gratuit, puis mettre l'adresse dans la variable `API_BASE_URL` du dépôt et relancer la compilation de l'APK (marche à suivre : README, Installation §5).
- [ ] **Essayer l'application sur un téléphone Android** ([APK compilé par GitHub](https://github.com/Valentin-Auger-Laboratoire/athletix-data/releases/tag/apk), à installer directement) : connexion à l'API sur XAMPP, GPS, pas, vibration, voix, export PDF et CSV, ceinture cardio si quelqu'un en a une.
- [ ] **Tester le faux brassard** sur un ESP32 classique ([`hardware/faux-brassard-ble/`](hardware/faux-brassard-ble/README.md)) avec nRF Connect, puis avec l'application.
- [ ] **Boîtier** ([cahier des charges et implantation à l'échelle](hardware/boitier/README.md)) : exporter le modèle Fusion 360 en STEP et STL, avec quelques captures, et l'ajouter au dépôt. Pour la natation : prévoir une version **étanche** (joint, passe-câble pour les électrodes) ou la garder pour plus tard.
- [x] **Diagramme de Gantt** mis à jour ([`gestion-projet/`](gestion-projet/README.md)) : plan de la 1re année et ce qu'il est devenu, 2e année jusqu'à la soutenance (dates de livraison et de soutenance à confirmer).
- [ ] **Rapport du jalon 1** (2e année, à rendre le lundi 16 novembre) : ce qui a été fait depuis le jalon 4, pourquoi ces choix, les perspectives (cette feuille de route) et une courte conclusion.

## 2. À la réception du matériel

Dans cet ordre, en notant chaque résultat (détail dans le [protocole de test](hardware/PROTOCOLE-DE-TEST.md)) :

- [ ] **Inventaire** : tout est là ? (comparer au devis)
- [ ] ⚠️ **Polarité de la batterie** : avant de la brancher, vérifier que le rouge du connecteur de la batterie arrive bien sur le **+** de la prise JST de la carte. Les fabricants ne câblent pas tous ce connecteur dans le même sens, et une inversion peut détruire la carte.
- [ ] **Carte seule** par USB-C : téléverser le faux brassard, vérifier le Bluetooth avec nRF Connect.
- [ ] **Soudure** de l'interrupteur sur le fil rouge de la batterie (kit WTS100, gaine thermo), test de mise sous tension sur batterie.
- [ ] **MyoWare sans électrodes** : alimentation 3,3 V, tension de sortie au multimètre (proche de 0 V au repos).
- [ ] **MyoWare avec électrodes** sur le biceps : la tension monte quand on contracte.
- [ ] **Firmware final**, puis **calibration** (contraction maximale).
- [ ] **Comparer à la simulation** (script prêt : [`mesures/`](mesures/README.md), enregistrement par USB puis figure et rapport automatiques) : au repos ≈ quelques %, effort moyen ≈ 40 à 50 %, effort fort > 75 % avec l'alerte qui s'allume une seule fois. Ajuster les seuils si besoin.
- [ ] **Séance complète** avec l'application : connexion Bluetooth, mesure, résumé enregistré en base.
- [ ] **Séance sans connexion** (natation, mais **hors de l'eau**) : démarrer, éloigner le téléphone, revenir, récupérer le résumé.
- [ ] **Fatigue** (étape 8) : interrupteur du Link Shield sur RAW, « Brut + fatigue », recalibrer ; tenir une charge jusqu'à la fatigue et vérifier que la fréquence médiane baisse ([`analyser_fatigue.py`](mesures/README.md) pour la figure).
- [ ] **Appairage chiffré** (étape 9) : `APPAIRAGE_SECURISE` à 1, noter le code sur l'étiquette, appairer avec l'application.
- [ ] **Autonomie** : brassard allumé en continu, noter la durée (objectif : plus de 2 h ; à refaire en signal brut, qui demande plus de calcul).
- [ ] **Boîtier** : impression en PETG, montage, essai porté sur le bras.

## 3. Pour finaliser

- [ ] Vidéo de démonstration du brassard réel avec l'application.
- [ ] README et captures mis à jour avec les vraies mesures (câblage réel à la place du câblage présumé, photo du montage sans visage).
- [ ] Jalons suivants et soutenance : objectif du semestre impair (S3), un **prototype** qui fonctionne. Le projet est terminé quand le brassard réel marche avec l'application.

## 4. Plus tard (améliorations, pas nécessaires au prototype)

- [x] **Vraie mesure de la fatigue** (13 novembre) : fréquence médiane du signal brut, firmware 1.2 + application + serveur. ⏳ À valider avec le vrai MyoWare (étape 8 du protocole).
- [ ] **Capteur de température de la peau** (chaleur et sclérose en plaques), à ajouter à une future commande.
- ~~Deux brassards pour comparer le côté gauche et le côté droit~~ : non retenu (13 novembre 2026), le matériel commandé ne suffit pas pour un second brassard.
- [ ] **Bracelet MSGM115 : cœur et bouton musique** (noté le 13 novembre, pour plus tard). Les pas marchent déjà. Le cœur et la musique passent par un format du fabricant (services FD00 / FFE0) que le bracelet n'envoie pas sans son appli d'origine. Marche à suivre : retrouver le nom de l'appli d'origine (boîte ou notice, sans doute « YOHO Sports »), activer le **journal HCI Bluetooth** d'Android (options pour développeurs), utiliser l'appli d'origine (mesure du cœur, musique), récupérer le journal et le décoder, puis l'ajouter à `montre_podometre.dart`.
- [x] Fond de carte sous le tracé du parcours (13 novembre, OpenStreetMap, désactivé par défaut).
- [x] Appairage Bluetooth sécurisé (13 novembre, `APPAIRAGE_SECURISE`). ⏳ À essayer avec un téléphone (étape 9 du protocole). API en HTTPS : fournie par l'adresse ngrok.
- [x] Limite du nombre d'essais de mot de passe côté serveur (13 novembre, migration `006`).
- ~~Version anglaise de l'application~~ : non retenue (décision du 13 novembre 2026).

### Pistes issues de la rencontre avec la patiente atteinte de sclérose en plaques

| Piste ([README](README.md#rencontre-avec-une-patiente-atteinte-de-sclérose-en-plaques)) | Où on en est |
|---|---|
| Force qui change d'un jour à l'autre : recalibrer à chaque séance | ✅ écran de calibration, historique des calibrations |
| Données de santé protégées | ✅ consentement, résumé seulement (pas de signal brut), export et suppression des données |
| **Fatigue** : la suivre, proposer une pause avant l'épuisement | ✅ **fréquence médiane** du signal brut (firmware 1.2, en direct et par semaine), semaines moins bonnes, pause conseillée en mode adapté ; ⏳ à valider avec le vrai capteur |
| **Chaleur** | ✅ météo et avertissement en mode adapté ; ⏳ capteur de température de la peau (§4) |
| Raideurs et spasmes, asymétrie gauche / droite | non retenu : il faudrait un second brassard, le matériel commandé ne suffit pas |
| Gestes fins et vue parfois difficiles | ✅ grands caractères, alertes par vibration et à voix haute |
| Suivi avec les soignants | ✅ carnet PDF et tableau CSV |

## Proposition de répartition (ce qui reste)

| Qui | Sans le matériel | À la réception |
|---|---|---|
| **Valentin** | rapport du jalon 1, boîtier, essai de l'application sur Android | soudure, câblage, firmware final, intégration dans le boîtier |
| **Othmen** | test du faux brassard avec nRF Connect | connexion Bluetooth réelle avec l'application |
| **Maxence** | | mesures, comparaison avec sa simulation |
| **Équipe** | | séance complète, vidéo de démonstration |
