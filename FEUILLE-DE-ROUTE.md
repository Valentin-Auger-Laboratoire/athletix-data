# Feuille de route : ce qu'il reste à faire

> Mise à jour : 12 novembre 2026. Le matériel a été demandé en juin 2026 ; l'école vient de passer la commande. Livraison attendue **dans un mois au plus tôt** (mi-décembre 2026).
> Cochez les cases au fur et à mesure (bouton ✏️ de GitHub, puis remplacer `[ ]` par `[x]`).

## Où en est le projet

| Partie | État |
|---|---|
| Application Flutter (comptes, profil, conseils, séances, classement, mode démo) | ✅ fait, démo en ligne |
| API PHP / MySQL (comptes, profils, séances, calibrations) | ✅ écrite, ⚠️ jamais exécutée sur un vrai serveur (seulement vérifiée en syntaxe) |
| Format Bluetooth (GATT), modèles de données, migration | ✅ fait ([`architecture/`](architecture/README.md)) |
| Brassard simulé dans l'application (vrais paquets Bluetooth) | ✅ fait, testé |
| Simulation Simulink de la chaîne EMG | ✅ faite ([`hardware/simulation-emg/`](hardware/simulation-emg/README.md)) |
| Câblage du brassard | ✅ schéma présumé ([`hardware/`](hardware/README.md)), non testé |
| Firmware de test ESP32 (faux brassard) | ✅ écrit, ⚠️ jamais testé sur une carte |
| Connexion Bluetooth réelle dans l'application | ❌ à faire |
| Écran de calibration dans l'application | ❌ à faire |
| Historique des séances dans l'application | ❌ à faire |
| Règle de score du classement à partir des mesures EMG | ❌ à décider puis coder |
| Boîtier (Fusion 360) | ✅ modélisé (Valentin), ⏳ fichiers pas encore ajoutés au dépôt |
| Brassard réel câblé, mesuré, calibré | ❌ attend le matériel |

## 1. À faire maintenant, sans le matériel

L'objectif : quand les pièces arrivent, il ne reste plus qu'à souder, flasher et mesurer.

### Décisions d'équipe
- [ ] **Web ou Android pour le Bluetooth réel** ([`INTEGRATION.md`](architecture/INTEGRATION.md) §3). Recommandé : garder le web pour la démo en ligne, faire une version Android pour l'usage avec le brassard.
- [ ] **Règle de score du classement** fondée sur les résultats EMG (par exemple temps passé dans la bonne zone d'intensité, régularité des séances), voir [`MCD_MLD.md`](architecture/MCD_MLD.md) §5.

### Application
- [ ] **`BrassardBle`** : la vraie connexion Bluetooth, qui remplace le brassard simulé. Elle implémente l'interface existante `SourceBrassard`, donc aucun écran n'est à modifier (piste : package `flutter_blue_plus`).
- [ ] **Écran de calibration** : consignes (« contracte ton biceps au maximum pendant 3 s »), bouton, envoi de la commande `0x03` au brassard, enregistrement par `save_calibration.php`. La route serveur existe déjà, il manque l'écran et la méthode dans `api.dart`.
- [ ] **Historique des séances** : une route `get_seances.php` et un écran qui liste les séances enregistrées (durée, intensité moyenne et maximale, alertes).
- [ ] **Classement** : coder la règle de score choisie dans `get_classement.php`, puis supprimer la table `performances` devenue inutile (défaut D1).
- [ ] **Consentement** au premier lancement : les mesures sont des données de santé (RGPD), et l'application n'est pas un dispositif médical.

### Serveur
- [ ] **Faire tourner l'API pour de vrai** : XAMPP, import de `database.sql` puis de `migrations/001_brassard_emg.sql`, application lancée **hors mode démo**. Tester chaque parcours : inscription, code par e-mail, connexion, profil, séance enregistrée.
- [ ] Noter les erreurs trouvées et les corriger (jusqu'ici le PHP n'a été vérifié qu'en syntaxe).

### Brassard (préparation)
- [ ] **Tester le faux brassard** ([`hardware/faux-brassard-ble/`](hardware/faux-brassard-ble/README.md)) : un **ESP32 classique suffit** (celui de la première piste par exemple). Le flasher et vérifier avec l'appli gratuite nRF Connect que les paquets arrivent, puis avec l'application quand `BrassardBle` est prêt.
- [ ] **Firmware final** : partir du faux brassard, `SOURCE_SIMULEE 0`, broche du MyoWare, et ajouter le niveau de batterie dans le service Bluetooth (remplace `hardware_status`).
- [ ] **Vérifier les fiches techniques** (SparkFun Thing Plus ESP32-S3, MyoWare 2.0, Link Shield) et corriger le [câblage présumé](hardware/README.md) si besoin : broche analogique exacte, alimentation, sortie du Link Shield.
- [ ] **Compléter la commande si possible** : le Link Shield sort le signal par un jack 3,5 mm (câble jack et petite embase à prévoir), les électrodes sont à usage unique (prévoir un paquet de rechange). Le câble Qwiic ne sert pas pour le signal.
- [ ] **Boîtier** : le modèle Fusion 360 est fait (Valentin). Reste à l'exporter en STEP et STL, avec quelques captures, et à l'ajouter au dépôt. Prévoir de vérifier les cotes une fois les pièces en main.
- [ ] **Protocole de test écrit** (voir §2) avec les résultats attendus, pour comparer la mesure réelle à la simulation.

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

## Proposition de répartition

| Qui | Sans le matériel | À la réception |
|---|---|---|
| **Valentin** | API testée sur XAMPP, écrans calibration et historique, firmware final, export du boîtier | soudure, câblage, firmware, intégration dans le boîtier |
| **Othmen** | `BrassardBle`, test du faux brassard avec nRF Connect | connexion Bluetooth réelle avec l'application |
| **Maxence** | Gantt, protocole de test et résultats attendus (d'après sa simulation) | mesures, comparaison avec la simulation |
