# Athletix-Data

**🇫🇷 Français** · [🇬🇧 English](#english)

Brassard connecté qui mesure l'activité d'un muscle (électromyographie, EMG) et application de suivi sportif. Projet de groupe réalisé à l'EPISEN de février à juin 2026.

**📋 [Feuille de route : ce qui est fait, ce qu'il reste à faire](FEUILLE-DE-ROUTE.md)** · [Protocole de test du brassard](hardware/PROTOCOLE-DE-TEST.md) · [Démo en ligne](https://valentin-auger-laboratoire.github.io/athletix-data/)

[![Tests](https://github.com/Valentin-Auger-Laboratoire/athletix-data/actions/workflows/tests.yml/badge.svg)](https://github.com/Valentin-Auger-Laboratoire/athletix-data/actions/workflows/tests.yml)

## L'équipe

| Membre | Rôle | Tâches principales |
|---|---|---|
| **Valentin Auger** | Chef de projet, matériel et application | **Projet** : pilotage, planning (MPM), choix du matériel et devis<br>**Brassard** : schéma électrique, [câblage présumé](hardware/README.md), acquisition et calcul RMS<br>**Application Flutter** : accueil, inscription et vérification par e-mail, connexion, questionnaire de profil et historique, conseils, catégories de sports et séances, classement, mode démo<br>**API PHP / MySQL** : comptes et code de vérification par e-mail, connexion par jeton, profils, performances, classement, état du brassard, base de données (`database.sql`)<br>**Application (suite, novembre 2026)** : connexion Bluetooth réelle, calibration, historique et détail des séances, graphiques et évolution, GPS, pas, météo et ceinture cardio, natation (résumé gardé dans le brassard), accessibilité et mode adapté, carnet PDF pour les soignants, séances envoyées plus tard sans réseau, RGPD (export et suppression du compte)<br>**Firmware final** du brassard (calculs testés sur ordinateur) et protocole de test<br>**Comparaison automatique avec la simulation** ([`mesures/`](mesures/README.md)), **analyse des risques**, **mode d'emploi** et **vidéo de démonstration**<br>**Gantt mis à jour** (2e année)<br>**Tests** de l'application, de l'API et du firmware, lancés automatiquement par GitHub<br>**Démo en ligne** (GitHub Pages) et captures d'écran<br>**Première piste, capteur cardiaque** : montage photopléthysmographe, code ESP32, simulation Wokwi, schéma d'implantation<br>**Documentation** : README, page électronique, page de la simulation (relecture, corrections et limites) |
| **Maxence Olivier** | Simulation et planning | **simulation Simulink de la chaîne EMG** ([`hardware/simulation-emg/`](hardware/simulation-emg/README.md)) : modèle et résultats ; diagramme de Gantt |
| **Othmen Al Bydeoi** | Architecture système | architecture Bluetooth Low Energy (GATT), intégration réseau, modèles de données (MCD, MLD, MCT), schémas ; dans le dépôt : la spécification [`architecture/`](architecture/README.md), le brassard simulé et l'écran de séance EMG de l'appli, l'enregistrement des séances et des calibrations (API PHP + [`migrations/`](migrations/001_brassard_emg.sql)), le firmware de test [`hardware/faux-brassard-ble/`](hardware/faux-brassard-ble/README.md) et les tests |

## Le brassard (version finale)

| Composant | Rôle |
|---|---|
| Capteur musculaire **MyoWare 2.0** + électrodes de surface | amplifie, redresse et lisse le signal du muscle (sortie analogique « enveloppe ») |
| **MyoWare 2.0 Link Shield** | relie le capteur au microcontrôleur |
| **SparkFun Thing Plus ESP32-S3** | conversion 12 bits à 500 Hz, valeur efficace sur 200 ms, envoi en Bluetooth Low Energy (~50 Hz, paquets de 8 octets) |
| Batterie **LiPo 3,7 V 1 500 mAh** + interrupteur | autonomie visée : plus de 2 h (environ 10 h estimées) |
| Brassard élastique | maintien sur le biceps |

La chaîne de mesure a été modélisée sous Simulink par Maxence Olivier avant le câblage, à titre d'**expérimentation** : voir [`hardware/simulation-emg/`](hardware/simulation-emg/README.md). Dans ce modèle d'essai, l'intensité calculée suit l'effort demandé, et l'alerte d'effort intense (75 %, avec hystérésis) ne clignote pas. Le modèle final est fourni : [`AthletixData_EMG_Simulation.slx`](hardware/simulation-emg/AthletixData_EMG_Simulation.slx) (MATLAB/Simulink R2026b ou plus récent).

**Le câblage présumé** : le matériel n'est pas encore reçu, ce schéma montre comment les composants commandés seront reliés (non testé) :

![Câblage présumé du brassard : électrodes, MyoWare 2.0 et Link Shield, câble jack vers l'ESP32-S3, batterie LiPo avec interrupteur, Bluetooth vers le téléphone](hardware/cablage-presume.png)

**Le boîtier** : cahier des charges préparé par **Valentin Auger** pour le modéliser sous Fusion 360 avant de recevoir les pièces (dimensions des cartes, de la batterie et de l'interrupteur, ouvertures, fixation au bras, pistes pour une version étanche) : [`hardware/boitier/`](hardware/boitier/README.md).

![Implantation proposée du boîtier principal, à l'échelle](hardware/boitier/implantation.png)

**Le modèle Simulink** (signal du muscle, capteur MyoWare 2.0, puis conversion et calcul sur l'ESP32-S3) :

![Schéma du modèle Simulink de la chaîne EMG](hardware/simulation-emg/schema-modele.png)

**Le résultat** : en haut, l'alerte d'effort intense ; en bas, l'intensité en % de la contraction maximale, avec le seuil de 75 % :

![Résultat de la simulation : alerte d'effort intense et intensité en % MVC](hardware/simulation-emg/resultat-simulation-corrigee.png)

### Comparer le vrai brassard à la simulation (prêt avant le matériel)

Outil réalisé par **Valentin Auger** ([`mesures/`](mesures/README.md)). Pendant une mesure, le firmware écrit chaque valeur sur le port USB ; un script l'enregistre, puis un autre la compare au modèle de la simulation : il retrouve tout seul le début de l'effort, superpose la mesure et le modèle, et vérifie les critères du [protocole de test](hardware/PROTOCOLE-DE-TEST.md) (repos sous 10 %, effort fort au-dessus de 75 %, une seule alerte par effort fort, pas de clignotement ni de saturation, temps de montée, ressemblance avec le modèle). Le jour de la réception, la comparaison prendra quelques minutes.

**Exemple sur des données simulées** (ce n'est pas une vraie mesure : le matériel n'est pas encore reçu) :

![Exemple de comparaison entre une séance simulée et le modèle de la simulation : intensité et alertes](mesures/exemple/seance-simulee-comparaison.png)

## Où en est le projet

Le matériel, demandé en juin 2026, a été commandé par l'école en novembre : livraison attendue **mi-décembre au plus tôt**. En attendant, **tout ce qui ne dépend pas des pièces est fait**.

- ✅ **L'application est quasiment finie** et testée (dans le navigateur) : séances en direct avec le brassard simulé, natation, graphiques, évolution, téléphone (GPS, pas, météo, cardio), accessibilité, carnets pour les soignants, RGPD, envoi différé sans réseau.
- ✅ **L'API** est testée sur une vraie base (77 vérifications), le **firmware final** est écrit et ses calculs sont testés sur ordinateur (41 vérifications), et GitHub relance tous les tests à chaque envoi.
- 🔜 **Encore sans le matériel** : essayer l'application sur un téléphone Android ([APK](https://github.com/Valentin-Auger-Laboratoire/athletix-data/releases/tag/apk)), ajouter le boîtier, rapport du jalon 1. Planning : [diagramme de Gantt](gestion-projet/README.md).
- ⏳ **À la réception** : le [protocole de test](hardware/PROTOCOLE-DE-TEST.md) ([fiche à imprimer](hardware/fiche-de-test.pdf)), étape par étape : batterie, carte seule, application, MyoWare, firmware final, calibration, comparaison avec la simulation ([automatique](mesures/README.md)), autonomie, boîtier.

Tout le détail (ce qui est fait, ce qui reste, cases à cocher, répartition) : **[`FEUILLE-DE-ROUTE.md`](FEUILLE-DE-ROUTE.md)**.

### Planning (diagramme de Gantt)

Fichier modifiable et détails : [`gestion-projet/`](gestion-projet/README.md). Dates à confirmer : livraison du matériel et soutenance. Voir aussi l'**[analyse des risques](gestion-projet/analyse-des-risques.md)** (batterie, électrodes, eau, données de santé, projet).

**2e année** (septembre 2026 → janvier 2027) :

![Gantt de la 2e année : travail fait sans le matériel, attente de la commande, étapes à la réception, fin du projet](gestion-projet/gantt-annee2.png)

**1re année** : le plan d'origine et ce que chaque tâche est devenue :

![Gantt de la 1re année : plan d'origine (tâches A à I) et statut de chaque tâche](gestion-projet/gantt-annee1.png)

## Rencontre avec une patiente atteinte de sclérose en plaques

> [!NOTE]
> Pendant le projet, l'équipe s'est entretenue avec **une personne atteinte de sclérose en plaques**, à l'initiative d'**un médecin retraité spécialiste de cette maladie**, qui nous a poussés à orienter le brassard vers ce besoin. Cet échange nous a aidés à avancer. Ses suggestions n'ont pas été notées sur le moment : les pistes ci-dessous ont été **rédigées après coup** à partir de ce que l'on sait de la maladie. Ce ne sont ni ses mots, ni un avis médical.

| Ce que vit la personne | Ce qu'il faudrait ajouter au brassard et à l'application |
|---|---|
| **Fatigue** : c'est le symptôme le plus fréquent, et elle arrive vite | suivre la fatigue musculaire (baisse de la fréquence médiane du signal brut, sortie RAW du MyoWare lue à 1 kHz ou plus) et proposer une pause **avant** l'épuisement, pas seulement une alerte d'effort intense |
| **Sensibilité à la chaleur** : les symptômes s'aggravent quand le corps chauffe | ajouter un capteur de température de la peau, une alerte de pause et des conseils pour se rafraîchir |
| **Force qui change d'un jour à l'autre** | refaire la calibration (contraction maximale) au début de chaque séance au lieu d'une référence fixe, avec des seuils réglables plus bas que 75 % |
| **Raideurs et spasmes**, souvent d'un seul côté | repérer une activité du muscle au repos, comparer le côté gauche et le côté droit avec deux capteurs |
| **Gestes fins et vue parfois difficiles** | grands boutons, texte grand et bien contrasté, alertes par vibration ou par la voix, séances courtes |
| **Suivi avec les soignants** | un carnet (fatigue notée de 0 à 10, séances, pauses) exportable pour le neurologue ou le kinésithérapeute |

Ce brassard n'est **pas un dispositif médical**. Une activité physique adaptée se fait avec l'accord et le suivi des soignants, et ces données de santé devraient être protégées (consentement, RGPD).

> **Historique :** la première piste du projet utilisait un capteur cardiaque (photopléthysmographe : LED infrarouge, phototransistor, LM358) sur un ESP32 classique. Son code et sa simulation Wokwi sont conservés dans [`hardware/`](hardware/README.md). L'application a d'abord été construite à cette étape ; l'écran de séance affiche maintenant l'intensité musculaire (simulée).

▶️ **Démo en ligne (sans serveur, données fictives) :** https://valentin-auger-laboratoire.github.io/athletix-data/ puis « Essayer la démo ».

**Mode d'emploi** (2 pages, réalisé par **Valentin Auger**) : poser le brassard et les électrodes, calibrer, faire une séance, récupérer une séance de natation, donner le carnet à un soignant, problèmes fréquents. À imprimer pour les essais : **[`mode-emploi/mode-emploi.pdf`](mode-emploi/mode-emploi.pdf)**.

<img src="mode-emploi/apercu-page-1.png" alt="Mode d'emploi, page 1 : sécurité, pose des électrodes, calibration, séance" width="380"> <img src="mode-emploi/apercu-page-2.png" alt="Mode d'emploi, page 2 : natation, carnet pour les soignants, problèmes fréquents" width="380">

Il s'ouvre aussi depuis l'application (menu du profil, « Mode d'emploi »).

**Fiche de test à imprimer** (réalisée par **Valentin Auger**) : le protocole de test avec des cases à cocher et des colonnes « Mesuré » vides, à remplir à la main le jour de la réception : **[`hardware/fiche-de-test.pdf`](hardware/fiche-de-test.pdf)**. Elle est générée à partir du protocole (`dart run tools/fiche_test.dart`), donc les deux restent identiques.

<img src="hardware/fiche-de-test-apercu.png" alt="Fiche de test, page 1 : sécurité batterie, carte seule, application avec le faux brassard" width="380">

**La démo en vidéo** (70 s, brassard simulé) : séance en direct, ressenti, détail d'une course avec son parcours, évolution, natation. Version MP4 pour une présentation : [`media/demo-application.mp4`](media/demo-application.mp4).

<img src="media/demo-application.gif" alt="Démonstration de l'application : séance en direct, détail d'une séance, évolution et natation" width="270">

| Accueil et objectif de la semaine | Séance en direct (brassard simulé) | Détail : parcours et intensité |
|---|---|---|
| ![Accueil](screenshots/accueil-demo.jpg) | ![Séance](screenshots/seance.jpg) | ![Parcours](screenshots/parcours.jpg) |

| Mon évolution | Natation (le brassard enregistre seul) | Conseils générés par règles |
|---|---|---|
| ![Évolution](screenshots/evolution.jpg) | ![Natation](screenshots/natation.jpg) | ![Conseils](screenshots/conseils.jpg) |

## Architecture

```
Muscle ──► MyoWare 2.0 ──► ESP32-S3 ══ Bluetooth LE (GATT) ══► Application Flutter ══ HTTPS ══► API PHP ──► MySQL
                           (RMS, % MVC, alerte)                 (affichage, résumé)             (backend/)  (database.sql
                                                                                                            + migrations/)
```

Le format Bluetooth, les modèles de données (MCD, MLD, MCT) et l'intégration réseau sont décrits dans [`architecture/`](architecture/README.md). En attendant le matériel, l'application utilise un **brassard simulé** qui produit les vrais paquets Bluetooth. La connexion au vrai brassard (`lib/services/brassard/brassard_ble.dart`), le [firmware final](hardware/firmware-brassard/README.md) et un [firmware de test](hardware/faux-brassard-ble/README.md) sont prêts, à tester avec la carte.

| Dossier | Contenu |
|---|---|
| `lib/` | Application Flutter (écrans, `config.dart`, couche API, mode démo, Bluetooth) |
| `android/` | Projet Android (autorisations Bluetooth), à ouvrir dans Android Studio |
| `backend/` | API PHP : inscription, vérification par e-mail, connexion, profils, séances, calibrations, historique, classement, état du brassard |
| `hardware/` | Câblage présumé du brassard EMG, firmware final et firmware de test, protocole de test, simulation Simulink, et fichiers du premier capteur cardiaque ([détails](hardware/README.md)) |
| `architecture/` | Spécification Bluetooth (GATT), MCD / MLD, MCT, intégration réseau |
| `FEUILLE-DE-ROUTE.md` | Ce qu'il reste à faire, avant et après la réception du matériel |
| `database.sql` | Structure de la base + 1 compte de démo fictif |
| `migrations/` | Mises à jour de la base (001 : brassard, calibrations, résultats EMG ; 002 : nettoyage ; 003 : téléphone, contexte, courbe ; 004 : tracé, séries, envoi différé) |
| `test/`, `tests/` | Tests de l'application (`flutter test`), de l'API (`tests/api/`) et des calculs du firmware (`tests/firmware/`) |
| `docs/` | Version web compilée, publiée par GitHub Pages |
| `tools/` | `build_web.sh` : compile la version web et la copie dans `docs/` |
| `media/` | Vidéo de démonstration de l'application (MP4 et GIF) |
| `mode-emploi/` | Mode d'emploi en PDF (2 pages) ; il se régénère avec `dart run tools/mode_emploi.dart` |
| `gestion-projet/` | Diagramme de Gantt (Excel modifiable et images) et [analyse des risques](gestion-projet/analyse-des-risques.md) |
| `mesures/` | Outils pour comparer le vrai brassard à la simulation (enregistrement par USB, figure et rapport automatiques) |
| `.github/workflows/` | Tests lancés par GitHub à chaque envoi (application, API sur MariaDB, firmware) |

## Fonctionnalités

- Inscription avec **code de vérification envoyé par e-mail** (6 chiffres, valable 10 minutes, 5 essais maximum, bouton « Renvoyer le code »).
- Connexion avec mot de passe haché (`password_hash`) et **jeton de session** ; un compte non vérifié ne peut pas se connecter.
- 5 familles de sports (environ 25 disciplines), avec un écran de séance par discipline.
- Questionnaire de profil (objectif, niveau, taille, poids, fréquence, blessures, antécédents cardio, sommeil, stress) avec **historique** des profils ; à la mise à jour, il reprend les réponses précédentes.
- Conseils calculés à partir de tout le profil : rythme selon le niveau et la fréquence déclarée, objectif, taille et poids (IMC, protéines), blessures, stress, sommeil, antécédents.
- **Brassard** : recherche et connexion Bluetooth au vrai brassard (application Android, ou Chrome / Edge en HTTPS), batterie, numéro de série ; ou brassard simulé.
- **Calibration** : contraction maximale de 3 s qui devient la référence 100 %, enregistrée dans l'historique des calibrations.
- Séance en direct : intensité en % de la contraction maximale, **courbe des 30 dernières secondes** avec le seuil, alerte d'effort intense avec hystérésis (vibration du téléphone, et voix si activée), mesure propre à chaque famille de sports calculée sur la séance en cours.
- **Le téléphone en plus du brassard** : GPS pour les sports d'endurance (distance, vitesse, allure, dénivelé, points imprécis et sauts ignorés), **nombre de pas** par l'accéléromètre (course, trail), **météo** au départ (Open-Meteo, position arrondie à ~1 km), **ceinture cardio** Bluetooth standard facultative (service `0x180D`) pour la fréquence cardiaque, que le brassard ne mesure pas.
- **Ressenti après chaque séance** (facultatif) : fatigue et douleur de 0 à 10, sommeil de la nuit, commentaire.
- **Détail d'une séance** : courbe complète (une valeur toutes les 5 s), temps passé dans chaque zone d'intensité, contractions, GPS, cœur, météo, ressenti, et un **indice de fatigue expérimental** (évolution de l'intensité entre le début et la fin, expliquée à l'écran avec ses limites).
- **Natation et sports d'eau** : le Bluetooth ne passe pas sous l'eau, donc le brassard calcule et garde lui-même le résumé de la séance (intensité, efforts intenses, courbe toutes les 30 s) ; l'application le récupère au retour. Arrêt automatique après 5 min de repos (le temps au bord ne compte pas), rien n'est effacé du brassard avant d'être enregistré.
- **Parcours** : tracé GPS coloré par l'intensité musculaire, vitesse et intensité le long du parcours. Les 200 premiers et derniers mètres ne sont pas enregistrés (souvent le domicile), et aucun service de cartes n'est appelé.
- **Musculation** : contractions (répétitions) et **séries** comptées par le brassard.
- **Mes séances** : historique, chaque séance ouvre son détail ; **carnet PDF** (par semaine et par séance) et **tableau CSV** (Excel) à donner au médecin ou au kinésithérapeute.
- **Sans réseau** : une séance qui ne peut pas être envoyée est gardée sur le téléphone et envoyée automatiquement plus tard, **sans doublon** et avec la bonne date.
- **Accueil** : la semaine en cours face à l'**objectif** de séances (réglable).
- **Mon compte (RGPD)** : télécharger toutes ses données (fichier JSON), supprimer son compte et toutes ses données (mot de passe redemandé).
- **Mon évolution** : points et volume par semaine, intensité et fatigue ressentie, **records personnels**, et **semaines moins bonnes** repérées (rendement en baisse d'au moins 15 %) avec leurs causes possibles tirées du ressenti (fatigue, sommeil, douleur, chaleur, trop de séances).
- **Réglages et accessibilité** : grands caractères, alertes par vibration et à voix haute, **mode adapté** (alerte à 60 % au lieu de 75 %, pause conseillée toutes les 10 minutes, avertissement chaleur au-delà de 25 °C), issus de la rencontre avec la patiente atteinte de sclérose en plaques.
- Classement des 30 derniers jours, calculé à partir des séances mesurées (10 points par séance + minutes × intensité moyenne ÷ 50 ; les séances simulées ne comptent pas).
- **Consentement** au premier lancement (données de santé, RGPD).
- **Mode démo** utilisable sans backend, avec six semaines de séances fictives (dont une semaine volontairement moins bonne) pour voir les graphiques.

## Ce qui est simulé (à lire avant d'évaluer le projet)

- **Intensité musculaire** : tant que le vrai brassard n'est pas relié, l'écran affiche le % de la contraction maximale (MVC) venant d'un **brassard simulé** (profil repos / 40 % / 95 % / 50 %). Les paquets suivent le vrai format Bluetooth, mais aucun muscle n'est mesuré, et l'écran l'indique. La séance est enregistrée comme « données simulées ». La connexion au vrai brassard est écrite mais **pas encore testée avec une carte**.
- **Mode démo** : parcours GPS **inventé** (boucle à ~10 km/h, signalée « parcours simulé ») et séances fictives ; la météo, elle, est la vraie météo de Paris au moment de la séance.
- **Indice de fatigue** : repère expérimental tiré de l'intensité (pour un même effort, un muscle fatigué recrute plus de fibres). La vraie mesure (baisse de la fréquence médiane) demandera le signal brut du capteur, lu bien plus vite, donc un changement du firmware.
- **GPS, pas, ceinture cardio, vibration et voix** : écrits pour Android, testés seulement dans le navigateur (le GPS et les capteurs y sont simulés) ; à essayer sur un téléphone.
- **Natation** : le calcul dans le brassard est écrit (firmware 1.1) et testé sur ordinateur ; dans la démo, le brassard simulé fait le même calcul en **temps accéléré** (1 s = 1 min de nage). Le prototype **n'est pas étanche** : il faudra un boîtier étanche avant d'aller dans l'eau.
- **Tracé du parcours de la démo** : boucle **inventée** autour d'un point fictif.
- **« IA »** : les conseils sont produits par des **règles `if/else`**, pas par un modèle entraîné (mention « Conseils générés par règles »). Ils ne remplacent pas un avis médical.
- **Mode démo** : compte et données **fictifs**, gardés en mémoire et perdus au rechargement de la page.
- **Simulation Simulink de la chaîne EMG** : c'est une expérimentation. Le signal du muscle est généré, la référence des 100 % (1,85 V) est supposée, et rien n'a encore été mesuré sur le vrai brassard.

## Installation

### Prérequis
- [Flutter](https://docs.flutter.dev/get-started/install) 3.x (Dart 3)
- [XAMPP](https://www.apachefriends.org/) (Apache + PHP 8 + MySQL/MariaDB)

### 1. Base de données
Démarre MySQL dans XAMPP, puis importe `database.sql` (phpMyAdmin → Importer, ou `mysql -u root < database.sql`).
Cela crée la base `athletix-pro` et un compte de démo fictif : `demo@exemple.com` / `demo1234`.
Importe ensuite `migrations/001_brassard_emg.sql` (tables du brassard, des calibrations et des résultats de séance), puis `migrations/002_score_et_nettoyage.sql` (suppression des anciennes tables `performances` et `hardware_status`), puis `migrations/003_contexte_telephone.sql` (GPS, pas, cardio, météo, ressenti, zones d'intensité, courbe de la séance), puis `migrations/004_trace_series_hors_ligne.sql` (tracé du parcours, séries, envoi différé sans doublon).

### 2. Backend PHP
1. Copie (ou clone) le dépôt dans `htdocs/athletix-data` pour que l'API réponde sur `http://localhost/athletix-data/backend/`.
2. Copie `backend/config.example.php` en `backend/config.local.php` (ce fichier est ignoré par Git), puis remplis :
   - les accès MySQL ;
   - le SMTP : adresse Gmail et **mot de passe d'application** ([à créer ici](https://myaccount.google.com/apppasswords)), jamais ton vrai mot de passe ;
   - `allowed_origin` : l'origine de l'appli Flutter (par défaut `http://localhost:5000`).

### 3. Application Flutter
```bash
flutter pub get
flutter run -d chrome --web-port 5000
```
L'URL de l'API est définie à un seul endroit, `lib/config.dart`. Elle peut aussi être changée à la compilation :
```bash
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=https://mon-serveur.exemple/backend
```

### 4. Application Android (pour le vrai brassard)
Le Bluetooth du brassard s'utilise depuis l'application Android (le dossier `android/` est déjà prêt, avec les autorisations Bluetooth, localisation pour le GPS et vibration).

**Le plus simple : l'APK déjà compilé.** GitHub compile l'application à chaque envoi et la publie ici : **[athletix-data.apk](https://github.com/Valentin-Auger-Laboratoire/athletix-data/releases/tag/apk)**. Le télécharger sur le téléphone, l'ouvrir et accepter l'installation depuis cette source. Le mode démo marche sans serveur ; pour un vrai compte, l'adresse de l'API se règle dans la variable du dépôt `API_BASE_URL` (*Settings → Secrets and variables → Actions → Variables*), puis relancer le workflow « APK Android ».

**Pour compiler soi-même :**
1. Ouvrir le dossier du projet dans **Android Studio** (avec le plugin Flutter), brancher un téléphone Android en mode développeur.
2. Sur le téléphone, `localhost` désigne le téléphone lui-même : il faut donner l'adresse du PC qui fait tourner XAMPP, sur le même Wi-Fi.
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20/athletix-data/backend
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.20/athletix-data/backend
```
L'APK se trouve ensuite dans `build/app/outputs/flutter-apk/app-release.apk`. Remplacer `192.168.1.20` par l'adresse IP du PC (`ipconfig` sous Windows). Le `http://` est autorisé pour le prototype ; à passer en HTTPS pour un vrai déploiement.

### 5. Héberger l'API sur son PC (XAMPP + ngrok)

Pas besoin de serveur : l'API tourne sur un PC avec XAMPP, et **ngrok** la rend joignable depuis Internet en HTTPS (le téléphone n'a pas besoin d'être sur le même Wi-Fi). L'application envoie déjà l'en-tête qui évite la page d'avertissement de ngrok.
1. XAMPP : démarrer Apache et MySQL, dépôt dans `htdocs/athletix-data`, base et migrations importées (étapes 1 et 2).
2. Installer ngrok (site officiel, compte gratuit), puis une seule fois : `ngrok config add-authtoken <jeton du compte>`.
3. Lancer le tunnel vers Apache. Le compte gratuit donne **un domaine fixe** (tableau de bord ngrok → *Domains*) : avec lui, l'adresse ne change pas à chaque lancement.
```bash
ngrok http --url=mon-domaine.ngrok-free.app 80
```
4. L'adresse de l'API devient `https://mon-domaine.ngrok-free.app/athletix-data/backend`. La mettre dans la variable du dépôt `API_BASE_URL` (*Settings → Secrets and variables → Actions → Variables*), puis relancer la compilation (*Actions → APK Android → Run workflow*) et réinstaller l'APK.
5. Le PC doit rester allumé, avec XAMPP et ngrok lancés, pendant que l'application est utilisée.

### 6. Tests
```bash
flutter test                                   # application (68 tests) : Bluetooth, séance, natation, GPS, évolution, exports, envoi différé, démo
ATHLETIX_TEST=1 bash tests/api/test_api.sh     # API sur une base de TEST (le script la vide) : 77 vérifications
g++ -std=c++17 -I hardware/firmware-brassard tests/firmware/test_calcul_emg.cpp -o test_emg && ./test_emg   # calculs du firmware : 41 vérifications
```
Les trois sont relancés par GitHub à chaque envoi ([`.github/workflows/tests.yml`](.github/workflows/tests.yml), badge en haut de page).

### 7. Version web pour GitHub Pages
```bash
bash tools/build_web.sh
```
Le script compile, copie le résultat dans `docs/` et ajoute un numéro de version aux fichiers : le navigateur charge toujours la nouvelle version, sans vider son cache. Ensuite, sur GitHub : *Settings → Pages → Branch `main`, dossier `/docs`*.

## Données personnelles (RGPD)

Le questionnaire porte sur des **données de santé** (poids, blessures, antécédents cardiaques, stress, sommeil), qui sont des données sensibles au sens du RGPD. Ce projet est pédagogique : **n'utilise que des données fictives**. Le mode démo n'envoie rien à un serveur. Déjà en place : consentement au premier lancement, seul un **résumé** de l'effort est stocké (jamais le signal brut du muscle), position météo arrondie à ~1 km, tracé sans les 200 premiers et derniers mètres, **téléchargement de toutes ses données** et **suppression du compte** (écran « Mon compte et mes données »). Une vraie mise en production demanderait en plus une base légale écrite, un hébergement de données de santé adapté, HTTPS et un appairage Bluetooth sécurisé.

## Licences et crédits

- Code du projet : © 2026 équipe Athletix-Data (Valentin Auger, Maxence Olivier, Othmen Al Bydeoi).
- [PHPMailer](https://github.com/PHPMailer/PHPMailer) (dossier `PHPMailer/`, version 7.0.2) est distribué sous **licence LGPL 2.1** ; voir `PHPMailer/LICENSE`.
- Flutter et ses packages : [shared_preferences](https://pub.dev/packages/shared_preferences), [sensors_plus](https://pub.dev/packages/sensors_plus), [share_plus](https://pub.dev/packages/share_plus) (BSD-3) ; [fl_chart](https://pub.dev/packages/fl_chart) (graphiques), [geolocator](https://pub.dev/packages/geolocator) (GPS), [flutter_tts](https://pub.dev/packages/flutter_tts) (voix) (MIT).
- Météo : [Open-Meteo](https://open-meteo.com/), données sous licence **CC BY 4.0**, service gratuit pour un usage non commercial.
- [pdf](https://pub.dev/packages/pdf) (carnet PDF) : licence **Apache 2.0**.
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (Bluetooth) : licence FlutterBluePlus, gratuite pour un usage personnel ou éducatif comme ce projet étudiant (`License.nonprofit` dans le code). Un usage commercial demanderait une licence payante. Le package peut envoyer une statistique anonyme au moment de la compilation (nom de l'application, version).

---

<a id="english"></a>

# Athletix-Data (English)

A connected armband that measures muscle activity (electromyography, EMG) and a fitness-tracking app. Group project at EPISEN (French engineering school), February to June 2026.

**📋 [Roadmap: done and to do (in French)](FEUILLE-DE-ROUTE.md)** · [Armband test protocol](hardware/PROTOCOLE-DE-TEST.md) · [Online demo](https://valentin-auger-laboratoire.github.io/athletix-data/)

**Team:** Valentin Auger (project lead, hardware and app: project management, planning (MPM), hardware choice and quote; armband wiring diagram and presumed wiring, acquisition and RMS; the whole Flutter app: home, e-mail-verified sign-up, login, profile questionnaire and history, advice, sport categories and workouts, leaderboard, demo mode; the PHP/MySQL API and database: accounts and e-mail codes, token login, profiles, performances, leaderboard, armband status; then (November 2026) the real Bluetooth connection, calibration, session history and detail, charts and progress, GPS, steps, weather and heart-rate strap, swimming (summary kept in the armband), accessibility and adapted mode, PDF log for carers, deferred sending without network, GDPR (export and account deletion), the final armband firmware, the automated tests; the online demo and screenshots; the first heart-rate sensor track: PPG circuit, ESP32 code, Wokwi simulation, layout diagram; the documentation), Maxence Olivier (simulation and planning: the Simulink model of the EMG chain in `hardware/simulation-emg/`, and the Gantt chart), Othmen Al Bydeoi (system architecture: Bluetooth Low Energy GATT, data models; in the repository: the `architecture/` specification, the simulated armband and EMG workout screen, session and calibration storage in the PHP API and `migrations/`, the `hardware/faux-brassard-ble/` test firmware, and the tests).

**Final armband:** MyoWare 2.0 muscle sensor + Link Shield, SparkFun Thing Plus ESP32-S3 (12-bit ADC at 500 Hz, 200 ms RMS, Bluetooth Low Energy), 3.7 V 1500 mAh LiPo battery. The measurement chain was first modelled in Simulink as an **experiment**: see [`hardware/simulation-emg/`](hardware/simulation-emg/README.md). The final model is included: [`AthletixData_EMG_Simulation.slx`](hardware/simulation-emg/AthletixData_EMG_Simulation.slx) (MATLAB/Simulink R2026b or later).

**Project status.** The hardware, requested in June 2026, was ordered by the school in November (expected mid-December at the earliest). Everything that does not depend on the parts is done: the **app is nearly finished** and tested in the browser, the API passes 77 checks on a real database, the final firmware is written and its calculations pass 41 checks on a computer, and GitHub reruns all tests on every push. The leaderboard rule was validated on 12 November 2026. Next: try the app on an Android phone (the APK is built by GitHub), then follow the test protocol when the hardware arrives. Full roadmap (in French): [`FEUILLE-DE-ROUTE.md`](FEUILLE-DE-ROUTE.md). Valentin Auger also built a tool that compares the real armband with the simulation automatically (USB log, figure and report against the test protocol): [`mesures/`](mesures/README.md). Planning (Gantt charts) and risk analysis: [`gestion-projet/`](gestion-projet/README.md). Demo video: [`media/demo-application.mp4`](media/demo-application.mp4). Two-page user guide (in French): [`mode-emploi/mode-emploi.pdf`](mode-emploi/mode-emploi.pdf).

**Meeting with a person living with multiple sclerosis.** During the project, the team talked with a person living with multiple sclerosis, at the suggestion of a retired doctor specialised in the disease, who pushed us towards this need. Her suggestions were not written down at the time; the ideas below were **written afterwards** from what is known about the disease. They are neither her words nor medical advice:
- **Fatigue** (the most common symptom): track muscle fatigue (median frequency of the raw signal, MyoWare RAW output read at 1 kHz or more) and suggest a break before exhaustion.
- **Heat sensitivity**: add a skin temperature sensor and a break alert.
- **Strength that varies from day to day**: recalibrate the maximum contraction at the start of each session, with adjustable thresholds below 75 %.
- **Stiffness and spasms, often on one side**: detect muscle activity at rest, compare left and right with two sensors.
- **Fine movements and vision**: large buttons, large high-contrast text, vibration or voice alerts, short sessions.
- **Follow-up with carers**: an exportable log (fatigue 0–10, sessions, breaks) for the neurologist or physiotherapist.

The armband is **not a medical device**; adapted physical activity should be supervised by carers, and health data must be protected (consent, GDPR).

**History:** the project first explored a heart-rate sensor (photoplethysmograph on an ESP32); its code and Wokwi simulation are kept in `hardware/`. The app was first built at that stage; the workout screen now shows (simulated) muscle intensity.

▶️ **Live demo (no server, fictional data):** https://valentin-auger-laboratoire.github.io/athletix-data/ then “Essayer la démo” (Try the demo).

## Architecture

```
Muscle ──► MyoWare 2.0 ──► ESP32-S3 ══ Bluetooth LE (GATT) ══► Flutter app ══ HTTPS ══► PHP API ──► MySQL
```

The Bluetooth format, data models and network integration are described (in French) in [`architecture/`](architecture/README.md). For now the app uses a **simulated armband** that produces the real Bluetooth packets; a test firmware for the ESP32 is in [`hardware/faux-brassard-ble/`](hardware/faux-brassard-ble/README.md).

## Features

- Sign-up with an **e-mailed verification code** (6 digits, valid for 10 minutes, at most 5 attempts, resend button).
- Login with hashed passwords (`password_hash`) and a **session token**; unverified accounts cannot log in.
- 5 sport families (about 25 disciplines), each with a workout screen.
- Profile questionnaire (goal, level, height, weight, frequency, injuries, cardiac history, sleep, stress) with a **history** of profiles; when updating, it starts from the previous answers.
- Advice computed from the whole profile: pace from level and declared frequency, goal, height and weight (BMI, protein), injuries, stress, sleep, history.
- **Armband**: Bluetooth search and connection to the real armband (Android app, or Chrome / Edge over HTTPS), battery, serial number; or a simulated armband.
- **Calibration**: a 3 s maximum contraction becomes the 100 % reference, stored in the calibration history.
- Live workout: intensity in % of maximum contraction, **last-30-seconds curve** with the threshold, high-effort alert with hysteresis (phone vibration, and voice if enabled), discipline-specific reading computed on the current session.
- **The phone on top of the armband**: GPS for endurance sports (distance, speed, pace, elevation gain), **step count** from the accelerometer, **weather** at the start (Open-Meteo, position rounded to ~1 km), optional standard Bluetooth **heart-rate strap** (`0x180D` service), since the armband does not measure the heart.
- **How it felt** after each session (optional): fatigue and pain 0–10, last night's sleep, comment.
- **Session detail**: full curve, time in each intensity zone, contractions, GPS, heart rate, weather, feeling, and an **experimental fatigue index** explained on screen with its limits.
- **Swimming and water sports**: Bluetooth does not work under water, so the armband computes and keeps the session summary itself (intensity, intense efforts, a curve every 30 s); the app retrieves it afterwards. Automatic stop after 5 min of rest; nothing is erased from the armband before it is saved.
- **Route**: GPS track coloured by muscle intensity, speed and intensity along the route. The first and last 200 m are not recorded (often the home address) and no map service is called.
- **Weight training**: contractions (repetitions) and **sets** counted by the armband.
- **My sessions**: history, each session opens its detail; **PDF log** (per week and per session) and **CSV table** for a doctor or physiotherapist.
- **No network**: a session that cannot be sent is kept on the phone and sent automatically later, **without duplicates** and with the right date.
- **Home screen**: the current week against the weekly session **goal**.
- **My account (GDPR)**: download all my data (JSON), delete my account and all its data (password asked again).
- **My progress**: points and volume per week, intensity and perceived fatigue, **personal records**, and **weaker weeks** detected (efficiency down by 15 % or more) with possible causes taken from the feelings entered.
- **Settings and accessibility**: large text, vibration and spoken alerts, **adapted mode** (alert at 60 % instead of 75 %, break reminder every 10 minutes, heat warning above 25 °C), from the meeting with a patient with multiple sclerosis.
- 30-day leaderboard computed from measured sessions (10 points per session + minutes × average intensity ÷ 50; simulated sessions do not count).
- **Consent** screen on first launch (health data, GDPR).
- **Demo mode** that works without any backend, with six weeks of fictional sessions (including one deliberately weaker week).

## What is simulated

- **Muscle intensity**: until the real armband is connected, the % of maximum contraction comes from a **simulated armband** that follows the real Bluetooth packet format. No muscle is measured, the screen says so, and the session is saved as simulated data. The real Bluetooth connection is written but **not yet tested with a board**.
- **Demo mode**: **made-up** GPS route (loop at ~10 km/h, labelled as simulated) and fictional sessions; the weather is the real weather in Paris.
- **Fatigue index**: an experimental cue from intensity; the real measure (median-frequency drop) needs the raw sensor signal and a firmware change.
- **GPS, steps, heart-rate strap, vibration and voice**: written for Android, only tested in the browser so far.
- **Swimming**: the in-armband calculation is written (firmware 1.1) and tested on a computer; in the demo, the simulated armband runs the same calculation in **accelerated time** (1 s = 1 min). The prototype is **not waterproof**: a waterproof enclosure is needed before going in the water. The demo route is a **made-up** loop.
- **“AI”**: the advice comes from **if/else rules**, not a trained model. It is not medical advice.
- **Demo mode**: **fictional** account and data, kept in memory and lost when the page reloads.
- **Simulink model of the EMG chain**: an experiment. The muscle signal is generated, the 100 % reference (1.85 V) is assumed, and nothing has been measured on the real armband yet.

## Installation

1. **Database**: start MySQL (XAMPP) and import `database.sql`, then the migrations `001` to `004` in `migrations/`, in order. This creates a fictional demo account: `demo@exemple.com` / `demo1234`.
2. **PHP backend**: place the repository in `htdocs/athletix-data`. Copy `backend/config.example.php` to `backend/config.local.php` (git-ignored), then fill in the MySQL credentials, the SMTP settings (Gmail address and **app password**) and `allowed_origin`.
3. **Flutter app**: run `flutter pub get`, then `flutter run -d chrome --web-port 5000`. The API URL lives in `lib/config.dart`, or can be passed with `--dart-define=API_BASE_URL=...`.
4. **Hosting the API on a PC**: XAMPP plus an **ngrok** tunnel (`ngrok http --url=<free static domain> 80`), then set the repository variable `API_BASE_URL` to `https://<domain>/athletix-data/backend` and rerun the “APK Android” workflow.
5. **Android app** (real armband): download the ready-made [athletix-data.apk](https://github.com/Valentin-Auger-Laboratoire/athletix-data/releases/tag/apk) built by GitHub, or open the project in Android Studio and build with `--dart-define=API_BASE_URL=...`.
6. **Tests**: `flutter test` (68 tests), `ATHLETIX_TEST=1 bash tests/api/test_api.sh` (77 checks, on a test database only), and the firmware calculation tests in `tests/firmware/` (41 checks). GitHub reruns all three on every push.
7. **GitHub Pages**: `bash tools/build_web.sh` (builds, copies to `docs/`, adds a version number so browsers never keep an old copy), then enable Pages on `main` / `docs`.

## Personal data (GDPR)

The questionnaire collects **health data**, which is sensitive data under the GDPR. This is an educational project: **use fictional data only**. Demo mode sends nothing to any server. In place: consent on first launch, only an effort **summary** is stored (never the raw muscle signal), weather position rounded to ~1 km, route without its first and last 200 m, **download of all my data** and **account deletion**.

## Licences

- Project code: © 2026 Athletix-Data team (Valentin Auger, Maxence Olivier, Othmen Al Bydeoi).
- [PHPMailer](https://github.com/PHPMailer/PHPMailer) (`PHPMailer/` folder, v7.0.2) is distributed under the **LGPL 2.1** licence; see `PHPMailer/LICENSE`.
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (Bluetooth): FlutterBluePlus licence, free for personal or educational use such as this student project (`License.nonprofit`); commercial use would require a paid licence.
- Packages: shared_preferences, sensors_plus, share_plus (BSD-3); fl_chart, geolocator, flutter_tts (MIT); pdf (Apache 2.0). Weather: [Open-Meteo](https://open-meteo.com/), data under **CC BY 4.0**.
