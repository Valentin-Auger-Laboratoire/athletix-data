# Spécification Bluetooth LE (GATT) du brassard

> Auteur : Othmen Al Bydeoi — architecture système. Version 1.0 (novembre 2026).

Ce document définit **comment le brassard et l'application se parlent en Bluetooth Low Energy**. Le firmware (ESP32-S3) et l'application (Flutter) doivent respecter exactement ce format : c'est le « contrat » entre les deux.

## 1. Rôles

| Rôle BLE | Qui | Ce qu'il fait |
|---|---|---|
| **Périphérique / serveur GATT** | le brassard (ESP32-S3) | publie les services, envoie les mesures par notification |
| **Central / client GATT** | l'application (téléphone ou Chrome) | cherche le brassard, s'y connecte, s'abonne aux mesures, envoie les commandes |

Nom annoncé (advertising) : `Athletix-XXXX`, où `XXXX` sont les 4 derniers caractères du numéro de série. L'UUID du service Athletix est inclus dans l'annonce, pour que l'application puisse filtrer les appareils.

## 2. Vue d'ensemble

```
Brassard Athletix (serveur GATT)
├── Device Information        0x180A   (standard)
│   ├── Serial Number String  0x2A25   Read
│   └── Firmware Revision     0x2A26   Read
├── Battery Service           0x180F   (standard)
│   └── Battery Level         0x2A19   Read, Notify      uint8, 0–100 %
└── Service Athletix EMG      abad0000-b097-4a54-8315-c2971fc04ce6
    ├── Mesure EMG            abad0001-…   Notify          8 octets (§4)
    ├── Point de contrôle     abad0002-…   Write           commandes (§5)
    ├── Configuration         abad0003-…   Read, Write     5 octets (§6)
    ├── État                  abad0004-…   Read, Notify    2 octets (§7)
    ├── Résumé hors ligne     abad0005-…   Read            20 à 220 octets (§11, firmware 1.1)
    └── Fréquence (fatigue)   abad0006-…   Notify          8 octets (§12, firmware 1.2)
```

Tous les UUID du service Athletix partagent la même base, seuls les 8 premiers caractères changent :

| Élément | UUID complet |
|---|---|
| Service Athletix EMG | `abad0000-b097-4a54-8315-c2971fc04ce6` |
| Mesure EMG | `abad0001-b097-4a54-8315-c2971fc04ce6` |
| Point de contrôle | `abad0002-b097-4a54-8315-c2971fc04ce6` |
| Configuration | `abad0003-b097-4a54-8315-c2971fc04ce6` |
| État | `abad0004-b097-4a54-8315-c2971fc04ce6` |
| Résumé hors ligne | `abad0005-b097-4a54-8315-c2971fc04ce6` |
| Fréquence (fatigue) | `abad0006-b097-4a54-8315-c2971fc04ce6` |

**Pourquoi réutiliser les services standards ?** Batterie et informations de l'appareil existent déjà dans la norme Bluetooth. N'importe quel outil (nRF Connect, Chrome, Android) sait les lire sans code spécial.

**Pourquoi un numéro de série et pas l'adresse MAC ?** Dans un navigateur (Web Bluetooth), l'application ne voit jamais l'adresse MAC, seulement un identifiant opaque. Le numéro de série (`0x2A25`) est lisible partout : c'est lui qui identifie le brassard dans la base de données.

## 3. Règles communes

- Tous les entiers sur plusieurs octets sont en **little-endian** (octet de poids faible en premier), comme sur l'ESP32 et dans `ByteData` côté Dart.
- Une caractéristique en **Notify** possède un descripteur CCCD (`0x2902`). L'application écrit dedans pour s'abonner.
- Une valeur inconnue ou un octet réservé est **ignoré** par celui qui lit, pour pouvoir ajouter des champs plus tard sans tout casser.

## 4. Mesure EMG — `abad0001` (Notify)

Envoyée environ **50 fois par seconde** pendant une séance (état « mesure »). Chaque notification contient **un paquet de 8 octets** :

| Octets | Champ | Type | Unité / sens |
|---|---|---|---|
| 0–3 | `horodatage` | uint32 | ms depuis l'allumage du brassard |
| 4–5 | `rms` | uint16 | valeur efficace de l'enveloppe, en mV (0–3300) |
| 6 | `intensite` | uint8 | % de la contraction maximale (MVC), plafonné à 255 |
| 7 | `drapeaux` | uint8 | voir ci-dessous |

Drapeaux (octet 7) :

| Bit | Nom | Sens quand il vaut 1 |
|---|---|---|
| 0 | `ALERTE` | effort intense : au-dessus du seuil haut, et pas encore redescendu sous le seuil bas (hystérésis) |
| 1 | `SATURATION` | le convertisseur est au maximum (3,3 V) : électrode mal posée ou gain trop fort |
| 2 | `CALIBRATION` | une calibration est en cours, l'intensité n'est pas encore fiable |
| 3–7 | réservés | à 0 |

**Exemple.** Le paquet `e8 03 00 00 9e 02 2a 00` se lit ainsi :
- horodatage `0x000003e8` = 1000 ms ;
- rms `0x029e` = 670 mV ;
- intensité `0x2a` = 42 % ;
- drapeaux = 0, donc pas d'alerte.

Pourquoi l'intensité peut dépasser 100 % : la référence 100 % vient de la calibration. Pendant un effort très fort, le signal peut la dépasser un peu (la simulation Simulink montre jusqu'à 108 %).

### Débit et intervalle de connexion

- 8 octets × 50 Hz = **400 octets/s**. C'est très peu pour le Bluetooth LE.
- La vraie contrainte est le **nombre** de notifications. Pour en envoyer 50 par seconde, il faut un intervalle de connexion d'environ **15 à 20 ms**. Le brassard demande cet intervalle après la connexion, mais c'est le téléphone qui décide.
- **Solution de repli, déjà prévue dans le format** : grouper plusieurs paquets dans une même notification (2 paquets = 16 octets). Cela tient dans les 20 octets utiles d'une notification avec la taille par défaut (MTU 23). L'application accepte donc toute notification dont la longueur est un **multiple de 8** et la découpe en paquets.

## 5. Point de contrôle — `abad0002` (Write)

L'application écrit une commande. Le premier octet est le code de la commande, la suite ses paramètres.

| Code | Commande | Paramètres | Effet |
|---|---|---|---|
| `0x01` | DÉMARRER | — | passe à l'état « mesure », les notifications EMG commencent |
| `0x02` | ARRÊTER | — | revient à l'état « repos », les notifications EMG s'arrêtent |
| `0x03` | CALIBRER | — | état « calibration » pendant 3 s : l'utilisateur serre le muscle au maximum. La valeur RMS la plus haute devient la référence 100 % (§6) |
| `0x04` | RÉGLER LE SEUIL | `seuil_haut` uint8, `seuil_bas` uint8 | change les seuils d'alerte (en %). Refusé si `seuil_bas ≥ seuil_haut` |
| `0x05` | DÉMARRER HORS LIGNE | — | comme DÉMARRER, et le brassard garde le résumé de la séance, **même si la liaison se coupe** (§11) |
| `0x06` | EFFACER HORS LIGNE | — | efface le résumé, une fois enregistré par l'application |
| `0x07` | CHOISIR LA SOURCE | `source` uint8 : 0 = ENV, 1 = RAW | signal lu sur l'entrée analogique (§12). **Au repos seulement** (refusé pendant une mesure). La référence 100 % revient à une valeur d'attente (1 850 mV en ENV, 500 mV en RAW) : il faut recalibrer |

Une commande inconnue ou mal formée met l'état en « erreur » avec le code `4` (§7). Le brassard ne plante pas.

## 6. Configuration — `abad0003` (Read, Write)

5 octets écrits par l'application ; **6 octets lus** à partir du firmware 1.2 (le 6e, `source`, en lecture seule, se change par la commande `0x07`). Un 6e octet écrit est ignoré.

| Octets | Champ | Type | Défaut |
|---|---|---|---|
| 0 | `seuil_haut` | uint8, % | 75 |
| 1 | `seuil_bas` | uint8, % | 70 |
| 2–3 | `ref_mvc` | uint16, mV | 1850 (valeur supposée dans la simulation) |
| 4 | `frequence` | uint8, Hz | 50 |
| 5 | `source` (lecture seule) | uint8 : 0 ENV, 1 RAW | 0 |

Après une calibration, le brassard met à jour `ref_mvc`. L'application relit la configuration et envoie la nouvelle référence au serveur (`save_calibration.php`), pour garder l'historique des calibrations.

## 7. État — `abad0004` (Read, Notify)

2 octets : `etat` (uint8) puis `code_erreur` (uint8).

| `etat` | Sens | | `code_erreur` | Sens |
|---|---|---|---|---|
| 0 | repos | | 0 | aucune |
| 1 | mesure | | 1 | saturation prolongée (électrode ?) |
| 2 | calibration | | 2 | batterie faible (< 10 %) |
| 3 | erreur | | 3 | calibration invalide (signal trop faible) |
| | | | 4 | commande inconnue ou mal formée |
| | | | 5 | source RAW demandée, mais le signal n'est pas centré sur ~1,65 V : l'interrupteur OUTPUT du Link Shield est sans doute resté sur ENV (avertissement, la mesure continue) |

## 8. Déroulé d'une séance

```
Application                                  Brassard
    │  scan (filtre : service abad0000)          │
    │──────────────── connexion ────────────────►│
    │  lit 0x2A25 (n° de série), 0x2A19 (batterie)
    │  s'abonne à Mesure EMG et à État (CCCD)    │
    │── Write 0x03 (CALIBRER) ──────────────────►│  état = calibration (3 s)
    │◄──────────── Notify État = repos ──────────│
    │  lit Configuration → ref_mvc               │
    │── Write 0x01 (DÉMARRER) ──────────────────►│  état = mesure
    │◄──── Notify Mesure EMG (×50 par seconde) ──│
    │      … affichage en direct, alertes …      │
    │── Write 0x02 (ARRÊTER) ───────────────────►│  état = repos
    │  calcule le résumé, l'envoie à l'API       │
```

## 9. Sécurité et vie privée

- Ce sont des **données de santé** (RGPD). Le firmware final sait **chiffrer la liaison** : avec `APPAIRAGE_SECURISE = 1`, appairage LE Secure Connections avec un code à 6 chiffres (tiré au hasard, écrit sur l'étiquette du boîtier), et les 6 caractéristiques du service Athletix ne sont accessibles qu'après appairage. Désactivé par défaut pour les premiers essais de la carte, activé à l'étape 9 du protocole. Détails : [`hardware/firmware-brassard/SECURITE.md`](../hardware/firmware-brassard/SECURITE.md). Le faux brassard de test reste ouvert.
- Le brassard n'envoie **rien** sur Internet. Seule l'application parle au serveur, avec le jeton de session de l'utilisateur.

## 10. Ce qui est implémenté

| Élément | Fichier | État |
|---|---|---|
| Format des paquets (lecture/écriture, tests) | `lib/services/brassard/mesure_emg.dart`, `test/brassard_test.dart` | ✅ |
| UUID et codes partagés | `lib/services/brassard/gatt_athletix.dart` | ✅ |
| Brassard simulé dans l'app (même format d'octets) | `lib/services/brassard/brassard_simule.dart` | ✅ |
| Faux brassard ESP32 qui publie ce service | `hardware/faux-brassard-ble/faux-brassard-ble.ino` | ✅ (non compilé ici) |
| Lecture de la configuration et de l'état, commandes (tests) | `lib/services/brassard/codec_gatt.dart`, `test/ajouts_test.dart` | ✅ |
| Connexion Bluetooth réelle dans l'app (Android et Chrome) | `lib/services/brassard/brassard_ble.dart` | ✅ écrite, ⏳ à tester avec une carte |
| Firmware final (vrai MyoWare, jauge de batterie, intervalle 15–20 ms) | `hardware/firmware-brassard/` | ✅ calculs testés sur ordinateur (`tests/firmware/`), ⏳ à flasher |
| Résumé hors ligne (natation, §11) : firmware 1.1, application, brassard simulé | `calcul_emg.h`, `hors_ligne.dart`, `natation_screen.dart` | ✅ testé sur ordinateur et dans l'application (simulé), ⏳ à essayer avec le vrai brassard dans l'eau |
| Source RAW et fatigue par la fréquence médiane (§12) : firmware 1.2, application, brassard simulé | `calcul_fatigue.h`, `analyse_frequence.dart`, `suivi_fatigue.dart` | ✅ calcul testé sur ordinateur (C++ et Dart, même résultat), firmware complet exécuté avec un muscle simulé (`tests/firmware/test_firmware_complet.cpp`), ⏳ à essayer avec le vrai MyoWare en RAW |

## 11. Résumé hors ligne — `abad0005` (Read), natation

Le Bluetooth ne passe pas sous l'eau. Pour les sports aquatiques, l'application envoie `0x05` puis peut perdre la liaison : le brassard continue de mesurer et **calcule lui-même** le résumé de la séance. Au retour, l'application envoie `0x02` (ARRÊTER), lit `abad0005`, enregistre la séance sur le serveur, puis envoie `0x06` (EFFACER). Tant que l'effacement n'est pas fait, la séance reste dans le brassard : rien n'est perdu si l'envoi au serveur échoue.

**Arrêt automatique** : après 5 minutes sous 10 % (sortie de l'eau), la séance est close à la **dernière activité** : le temps passé au bord ne compte pas.

| Octets | Champ | Type | Sens |
|---|---|---|---|
| 0 | `version` | uint8 | 1 |
| 1 | `etat` | uint8 | 0 vide, 1 en cours, 2 terminé |
| 2–3 | `duree` | uint16 | s |
| 4–7 | `nb_echantillons` | uint32 | mesures prises en compte |
| 8 | `intensite_moyenne` | uint8 | % MVC |
| 9 | `intensite_max` | uint8 | % MVC |
| 10–11 | `temps_effort_intense` | uint16 | s, alerte allumée |
| 12–13 | `nb_alertes` | uint16 | allumages de l'alerte |
| 14–17 | `fin_il_y_a` | uint32 | s écoulées depuis la fin, au moment de la lecture (0 si en cours) |
| 18 | `pas_courbe` | uint8 | s entre deux points (30) |
| 19 | `nb_points` | uint8 | 0 à 200 |
| 20… | `courbe` | uint8 × `nb_points` | intensité moyenne de chaque bloc de 30 s (200 points = 1 h 40) |

La valeur dépasse les 20 octets d'une MTU par défaut : l'application la lit en **lecture longue** (gérée par Android et par `flutter_blue_plus`). `fin_il_y_a` est une durée mesurée par le brassard : l'application l'envoie au serveur (`fin_il_y_a_s`) pour dater la séance sans dépendre de l'heure du téléphone.

Le calcul est dans `calcul_emg.h` (classe `EnregistrementHorsLigne`, testée sur ordinateur) ; le brassard simulé de l'application en utilise une copie en Dart, et un test vérifie que les deux produisent **les mêmes octets** sur le même scénario (`test/natation_test.dart`).

## 12. Fréquence (fatigue) — `abad0006` (Notify), firmware 1.2

Quand le brassard lit le **signal brut** (source RAW, commande `0x07`, interrupteur OUTPUT du Link Shield sur RAW), il échantillonne à 2 000 Hz et calcule, toutes les 1 024 valeurs (0,512 s), la **fréquence médiane** du spectre (MDF) : elle baisse quand le muscle fatigue. Le calcul et ses choix sont expliqués dans [`hardware/firmware-brassard/FATIGUE.md`](../hardware/firmware-brassard/FATIGUE.md).

Environ 2 notifications par seconde, pendant l'état « mesure » seulement. 8 octets, little-endian :

| Octets | Champ | Type | Sens |
|---|---|---|---|
| 0–3 | `horodatage` | uint32, ms | fin de la fenêtre analysée (même horloge que §4) |
| 4–5 | `mdf` | uint16, 0,1 Hz | fréquence médiane ; **0 = pas de valeur** (intensité moyenne sur la fenêtre < 20 % : au repos, le spectre n'est que du bruit) |
| 6–7 | `mnf` | uint16, 0,1 Hz | fréquence moyenne (barycentre du spectre), donnée en plus |

Exemple : `e8 03 00 00 dc 03 60 04` = à 1 000 ms, MDF = 98,8 Hz, MNF = 112,0 Hz.

Les mesures d'intensité (§4) continuent à 50 Hz en RAW : l'intensité est alors la valeur efficace du signal brut (sans sa composante continue) sur 200 ms, rapportée à la référence 100 % calibrée **dans cette source**.

L'application ne stocke pas ces valeurs une par une : elle ajuste une droite sur la séance et envoie au serveur la MDF du début, celle de la fin, la baisse en % et une courbe (une valeur par bloc de 30 s), voir migration 005. Le brassard simulé de l'application fabrique un vrai signal brut et passe par le même calcul (copie Dart, `lib/services/brassard/analyse_frequence.dart`), testé contre le firmware sur le même signal (`test/fatigue_test.dart`).

