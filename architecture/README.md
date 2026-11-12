# Architecture système d'Athletix-Data

> Partie d'Othmen Al Bydeoi : architecture Bluetooth Low Energy (GATT), intégration réseau, modèles de données (MCD, MCT).

| Document | Contenu |
|---|---|
| [`GATT.md`](GATT.md) | Le « contrat » Bluetooth entre le brassard et l'application : services, caractéristiques, format des paquets de 8 octets, commandes |
| [`INTEGRATION.md`](INTEGRATION.md) | Le chemin des données du muscle à la base, les nouvelles routes de l'API, le choix web / Android |
| [`MCD_MLD.md`](MCD_MLD.md) | Défauts de la base actuelle, modèle conceptuel et logique cible, règles de gestion |
| [`MCT.md`](MCT.md) | Ce que fait le système quand un événement arrive (inscription, calibration, séance…) |

## Ce qui a été ajouté au code

| Fichier | Rôle |
|---|---|
| `migrations/001_brassard_emg.sql` | ajoute les tables `brassards`, `calibrations`, `resultats_emg` et complète `sessions_entrainement` |
| `backend/brassard.php` | fonction commune : créer ou retrouver un brassard par son numéro de série |
| `backend/save_seance.php` | enregistre une séance et son résumé EMG |
| `backend/save_calibration.php` | enregistre une calibration (référence 100 % MVC) |
| `lib/services/brassard/gatt_athletix.dart` | UUID et codes de commande (les mêmes que dans le firmware) |
| `lib/services/brassard/mesure_emg.dart` | lit et écrit le paquet de 8 octets |
| `lib/services/brassard/source_brassard.dart` | interface commune : brassard simulé aujourd'hui, Bluetooth réel demain |
| `lib/services/brassard/brassard_simule.dart` | brassard simulé qui produit les vrais octets GATT |
| `lib/services/brassard/resume_seance.dart` | calcule le résumé de la séance (moyenne, max, temps en effort intense, alertes) |
| `lib/screens/workout_detail_screen.dart` | l'écran de séance affiche le % MVC au lieu de BPM aléatoires, et enregistre la séance |
| `test/brassard_test.dart` | tests du format des paquets et du résumé (`flutter test`) |
| `hardware/faux-brassard-ble/` | firmware ESP32 de test qui publie le service GATT |

## Installer la mise à jour de la base

Après avoir importé `database.sql` :

```bash
mysql -u root athletix-pro < migrations/001_brassard_emg.sql
```

ou dans phpMyAdmin : base `athletix-pro` → Importer → `migrations/001_brassard_emg.sql`. Le script peut être relancé sans erreur. Il utilise la syntaxe `IF NOT EXISTS` de MariaDB (celle de XAMPP).
