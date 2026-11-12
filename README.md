# Athletix-Data

**🇫🇷 Français** · [🇬🇧 English](#english)

Brassard connecté qui mesure l'activité d'un muscle (électromyographie, EMG) et application de suivi sportif. Projet de groupe réalisé à l'EPISEN de février à juin 2026.

**📋 [Feuille de route : ce qu'il reste à faire](FEUILLE-DE-ROUTE.md)** · [Protocole de test du brassard](hardware/PROTOCOLE-DE-TEST.md) · [Démo en ligne](https://valentin-auger-laboratoire.github.io/athletix-data/)

## L'équipe

| Membre | Rôle | Tâches principales |
|---|---|---|
| **Valentin Auger** | Chef de projet, matériel et application | **Projet** : pilotage, planning (MPM), choix du matériel et devis<br>**Brassard** : schéma électrique, [câblage présumé](hardware/README.md), acquisition et calcul RMS<br>**Application Flutter** : accueil, inscription et vérification par e-mail, connexion, questionnaire de profil et historique, conseils, catégories de sports et séances, classement, mode démo<br>**API PHP / MySQL** : comptes et code de vérification par e-mail, connexion par jeton, profils, performances, classement, état du brassard, base de données (`database.sql`)<br>**Démo en ligne** (GitHub Pages) et captures d'écran<br>**Première piste, capteur cardiaque** : montage photopléthysmographe, code ESP32, simulation Wokwi, schéma d'implantation<br>**Documentation** : README, page électronique, page de la simulation (relecture, corrections et limites) |
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

**Le modèle Simulink** (signal du muscle, capteur MyoWare 2.0, puis conversion et calcul sur l'ESP32-S3) :

![Schéma du modèle Simulink de la chaîne EMG](hardware/simulation-emg/schema-modele.png)

**Le résultat** : en haut, l'alerte d'effort intense ; en bas, l'intensité en % de la contraction maximale, avec le seuil de 75 % :

![Résultat de la simulation : alerte d'effort intense et intensité en % MVC](hardware/simulation-emg/resultat-simulation-corrigee.png)

## Où en est le projet

Le matériel, demandé en juin 2026, vient d'être commandé par l'école : livraison attendue **dans un mois au plus tôt**. En attendant, tout ce qui ne dépend pas des pièces est préparé.

- ✅ **Fait** : application et démo en ligne, API PHP / MySQL testée sur une vraie base, format Bluetooth et modèles de données, brassard simulé, simulation Simulink, câblage présumé vérifié sur les fiches SparkFun, boîtier modélisé sous Fusion 360 (fichiers à ajouter). Et depuis le 12 novembre : connexion Bluetooth réelle, écrans Brassard, Calibration, Mes séances et consentement, classement calculé à partir des mesures, projet Android, firmware final, protocole de test.
- 🔜 **Encore sans le matériel** : tester le faux brassard sur un ESP32, valider la règle de score, préparer le câble jack (câble audio recyclé, sans rien commander), ajouter le boîtier, Gantt et rapport du jalon 1.
- ⏳ **À la réception** : le [protocole de test](hardware/PROTOCOLE-DE-TEST.md), étape par étape : batterie, carte seule, application, MyoWare, firmware final, calibration, comparaison avec la simulation, autonomie, boîtier.

Détail, cases à cocher et répartition proposée : **[`FEUILLE-DE-ROUTE.md`](FEUILLE-DE-ROUTE.md)**.

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

| Accueil (mode démo) | Conseils générés par règles | Séance |
|---|---|---|
| ![Accueil](screenshots/accueil-demo.jpg) | ![Conseils](screenshots/conseils.jpg) | ![Séance](screenshots/seance.jpg) |

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
| `migrations/` | Mises à jour de la base (001 : brassard, calibrations, résultats EMG ; 002 : nettoyage) |
| `test/`, `tests/` | Tests de l'application (`flutter test`), de l'API (`tests/api/`) et des calculs du firmware (`tests/firmware/`) |
| `docs/` | Version web compilée, publiée par GitHub Pages |

## Fonctionnalités

- Inscription avec **code de vérification envoyé par e-mail** (6 chiffres, valable 10 minutes, 5 essais maximum, bouton « Renvoyer le code »).
- Connexion avec mot de passe haché (`password_hash`) et **jeton de session** ; un compte non vérifié ne peut pas se connecter.
- 5 familles de sports (environ 25 disciplines), avec un écran de séance par discipline.
- Questionnaire de profil (objectif, niveau, taille, poids, fréquence, blessures, antécédents cardio, sommeil, stress) avec **historique** des profils ; à la mise à jour, il reprend les réponses précédentes.
- Conseils calculés à partir de tout le profil : rythme selon le niveau et la fréquence déclarée, objectif, taille et poids (IMC, protéines), blessures, stress, sommeil, antécédents.
- **Brassard** : recherche et connexion Bluetooth au vrai brassard (application Android, ou Chrome / Edge en HTTPS), batterie, numéro de série ; ou brassard simulé.
- **Calibration** : contraction maximale de 3 s qui devient la référence 100 %, enregistrée dans l'historique des calibrations.
- Séance en direct : intensité en % de la contraction maximale, alerte d'effort intense avec hystérésis, résumé enregistré à la fin.
- **Mes séances** : historique des séances et de leur résumé (durée, intensité moyenne et maximale, temps d'effort intense, alertes).
- Classement des 30 derniers jours, calculé à partir des séances mesurées (10 points par séance + minutes × intensité moyenne ÷ 50 ; les séances simulées ne comptent pas).
- **Consentement** au premier lancement (données de santé, RGPD).
- **Mode démo** utilisable sans backend.

## Ce qui est simulé (à lire avant d'évaluer le projet)

- **Intensité musculaire** : tant que le vrai brassard n'est pas relié, l'écran affiche le % de la contraction maximale (MVC) venant d'un **brassard simulé** (profil repos / 40 % / 95 % / 50 %). Les paquets suivent le vrai format Bluetooth, mais aucun muscle n'est mesuré, et l'écran l'indique. La séance est enregistrée comme « données simulées ». La connexion au vrai brassard est écrite mais **pas encore testée avec une carte**.
- **Mesure propre à chaque discipline** (activité musculaire moyenne, pic de contraction, efforts intenses, relâchement, en % de la contraction maximale), affichée sous l'intensité : valeurs d'exemple fixes, marquées « valeur d'exemple ».
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
Importe ensuite `migrations/001_brassard_emg.sql` (tables du brassard, des calibrations et des résultats de séance), puis `migrations/002_score_et_nettoyage.sql` (suppression des anciennes tables `performances` et `hardware_status`).

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
Le Bluetooth du brassard s'utilise depuis l'application Android (le dossier `android/` est déjà prêt, avec les autorisations Bluetooth).
1. Ouvrir le dossier du projet dans **Android Studio** (avec le plugin Flutter), brancher un téléphone Android en mode développeur.
2. Sur le téléphone, `localhost` désigne le téléphone lui-même : il faut donner l'adresse du PC qui fait tourner XAMPP, sur le même Wi-Fi.
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20/athletix-data/backend
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.20/athletix-data/backend
```
L'APK se trouve ensuite dans `build/app/outputs/flutter-apk/app-release.apk`. Remplacer `192.168.1.20` par l'adresse IP du PC (`ipconfig` sous Windows). Le `http://` est autorisé pour le prototype ; à passer en HTTPS pour un vrai déploiement.

### 5. Tests
```bash
flutter test                                   # application : format Bluetooth, résumé de séance, calibration, démo
ATHLETIX_TEST=1 bash tests/api/test_api.sh     # API sur une base de TEST (le script la vide) : 41 vérifications
g++ -std=c++17 -I hardware/firmware-brassard tests/firmware/test_calcul_emg.cpp -o test_emg && ./test_emg   # calculs du firmware
```

### 6. Version web pour GitHub Pages
```bash
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /athletix-data/
rm -rf docs && cp -r build/web docs && touch docs/.nojekyll
```
Ensuite, sur GitHub : *Settings → Pages → Branch `main`, dossier `/docs`*.

## Données personnelles (RGPD)

Le questionnaire porte sur des **données de santé** (poids, blessures, antécédents cardiaques, stress, sommeil), qui sont des données sensibles au sens du RGPD. Ce projet est pédagogique : **n'utilise que des données fictives**. Le mode démo n'envoie rien à un serveur. Une vraie mise en production demanderait une base légale et un consentement explicite, un hébergement adapté, HTTPS, et des droits d'accès et de suppression des données.

## Licences et crédits

- Code du projet : © 2026 équipe Athletix-Data (Valentin Auger, Maxence Olivier, Othmen Al Bydeoi).
- [PHPMailer](https://github.com/PHPMailer/PHPMailer) (dossier `PHPMailer/`, version 7.0.2) est distribué sous **licence LGPL 2.1** ; voir `PHPMailer/LICENSE`.
- Flutter et ses packages : licences BSD respectives.
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (Bluetooth) : licence FlutterBluePlus, gratuite pour un usage personnel ou éducatif comme ce projet étudiant (`License.nonprofit` dans le code). Un usage commercial demanderait une licence payante. Le package peut envoyer une statistique anonyme au moment de la compilation (nom de l'application, version).

---

<a id="english"></a>

# Athletix-Data (English)

A connected armband that measures muscle activity (electromyography, EMG) and a fitness-tracking app. Group project at EPISEN (French engineering school), February to June 2026.

**📋 [Roadmap (in French)](FEUILLE-DE-ROUTE.md)** · [Armband test protocol](hardware/PROTOCOLE-DE-TEST.md) · [Online demo](https://valentin-auger-laboratoire.github.io/athletix-data/)

**Team:** Valentin Auger (project lead, hardware and app: project management, planning (MPM), hardware choice and quote; armband wiring diagram and presumed wiring, acquisition and RMS; the whole Flutter app: home, e-mail-verified sign-up, login, profile questionnaire and history, advice, sport categories and workouts, leaderboard, demo mode; the PHP/MySQL API and database: accounts and e-mail codes, token login, profiles, performances, leaderboard, armband status; the online demo and screenshots; the first heart-rate sensor track: PPG circuit, ESP32 code, Wokwi simulation, layout diagram; the documentation), Maxence Olivier (simulation and planning: the Simulink model of the EMG chain in `hardware/simulation-emg/`, and the Gantt chart), Othmen Al Bydeoi (system architecture: Bluetooth Low Energy GATT, data models; in the repository: the `architecture/` specification, the simulated armband and EMG workout screen, session and calibration storage in the PHP API and `migrations/`, the `hardware/faux-brassard-ble/` test firmware, and the tests).

**Final armband:** MyoWare 2.0 muscle sensor + Link Shield, SparkFun Thing Plus ESP32-S3 (12-bit ADC at 500 Hz, 200 ms RMS, Bluetooth Low Energy), 3.7 V 1500 mAh LiPo battery. The measurement chain was first modelled in Simulink as an **experiment**: see [`hardware/simulation-emg/`](hardware/simulation-emg/README.md). The final model is included: [`AthletixData_EMG_Simulation.slx`](hardware/simulation-emg/AthletixData_EMG_Simulation.slx) (MATLAB/Simulink R2026b or later).

**Project status.** The hardware, requested in June 2026, has just been ordered by the school (expected in a month at the earliest). Done: app and online demo, PHP/MySQL API tested on a real database, Bluetooth format and data models, simulated armband, Simulink simulation, presumed wiring checked against SparkFun datasheets, enclosure modelled in Fusion 360 (files to be added), real Bluetooth connection, calibration and history screens, EMG-based leaderboard, Android project, final firmware and test protocol. Next: try the test firmware on an ESP32, then follow the test protocol when the hardware arrives. Full roadmap (in French): [`FEUILLE-DE-ROUTE.md`](FEUILLE-DE-ROUTE.md).

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
- Live workout: intensity in % of maximum contraction, high-effort alert with hysteresis, summary saved at the end.
- **My sessions**: history of sessions and their summary.
- 30-day leaderboard computed from measured sessions (10 points per session + minutes × average intensity ÷ 50; simulated sessions do not count).
- **Consent** screen on first launch (health data, GDPR).
- **Demo mode** that works without any backend.

## What is simulated

- **Muscle intensity**: until the real armband is connected, the % of maximum contraction comes from a **simulated armband** that follows the real Bluetooth packet format. No muscle is measured, the screen says so, and the session is saved as simulated data. The real Bluetooth connection is written but **not yet tested with a board**.
- **Discipline-specific reading** (average muscle activity, peak contraction, intense efforts, relaxation, in % of maximum contraction), shown below the intensity: fixed example values, labelled as such.
- **“AI”**: the advice comes from **if/else rules**, not a trained model. It is not medical advice.
- **Demo mode**: **fictional** account and data, kept in memory and lost when the page reloads.
- **Simulink model of the EMG chain**: an experiment. The muscle signal is generated, the 100 % reference (1.85 V) is assumed, and nothing has been measured on the real armband yet.

## Installation

1. **Database**: start MySQL (XAMPP) and import `database.sql`, then `migrations/001_brassard_emg.sql` and `migrations/002_score_et_nettoyage.sql`. This creates a fictional demo account: `demo@exemple.com` / `demo1234`.
2. **PHP backend**: place the repository in `htdocs/athletix-data`. Copy `backend/config.example.php` to `backend/config.local.php` (git-ignored), then fill in the MySQL credentials, the SMTP settings (Gmail address and **app password**) and `allowed_origin`.
3. **Flutter app**: run `flutter pub get`, then `flutter run -d chrome --web-port 5000`. The API URL lives in `lib/config.dart`, or can be passed with `--dart-define=API_BASE_URL=...`.
4. **Android app** (real armband): open the project in Android Studio and build with `--dart-define=API_BASE_URL=http://<PC IP>/athletix-data/backend`.
5. **Tests**: `flutter test`, `ATHLETIX_TEST=1 bash tests/api/test_api.sh` (on a test database only), and the firmware calculation tests in `tests/firmware/`.
6. **GitHub Pages**: `MSYS_NO_PATHCONV=1 flutter build web --release --base-href /athletix-data/`, copy `build/web` to `docs/`, add `docs/.nojekyll`, then enable Pages on `main` / `docs`.

## Personal data (GDPR)

The questionnaire collects **health data**, which is sensitive data under the GDPR. This is an educational project: **use fictional data only**. Demo mode sends nothing to any server.

## Licences

- Project code: © 2026 Athletix-Data team (Valentin Auger, Maxence Olivier, Othmen Al Bydeoi).
- [PHPMailer](https://github.com/PHPMailer/PHPMailer) (`PHPMailer/` folder, v7.0.2) is distributed under the **LGPL 2.1** licence; see `PHPMailer/LICENSE`.
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (Bluetooth): FlutterBluePlus licence, free for personal or educational use such as this student project (`License.nonprofit`); commercial use would require a paid licence.
