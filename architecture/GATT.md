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
    └── État                  abad0004-…   Read, Notify    2 octets (§7)
```

Tous les UUID du service Athletix partagent la même base, seuls les 8 premiers caractères changent :

| Élément | UUID complet |
|---|---|
| Service Athletix EMG | `abad0000-b097-4a54-8315-c2971fc04ce6` |
| Mesure EMG | `abad0001-b097-4a54-8315-c2971fc04ce6` |
| Point de contrôle | `abad0002-b097-4a54-8315-c2971fc04ce6` |
| Configuration | `abad0003-b097-4a54-8315-c2971fc04ce6` |
| État | `abad0004-b097-4a54-8315-c2971fc04ce6` |

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

Une commande inconnue ou mal formée met l'état en « erreur » avec le code `4` (§7). Le brassard ne plante pas.

## 6. Configuration — `abad0003` (Read, Write)

5 octets :

| Octets | Champ | Type | Défaut |
|---|---|---|---|
| 0 | `seuil_haut` | uint8, % | 75 |
| 1 | `seuil_bas` | uint8, % | 70 |
| 2–3 | `ref_mvc` | uint16, mV | 1850 (valeur supposée dans la simulation) |
| 4 | `frequence` | uint8, Hz | 50 |

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

- Ce sont des **données de santé** (RGPD). Pour un prototype pédagogique, la connexion n'est pas chiffrée. Pour un vrai produit, il faudrait un appairage sécurisé (LE Secure Connections) et des caractéristiques accessibles seulement après appairage.
- Le brassard n'envoie **rien** sur Internet. Seule l'application parle au serveur, avec le jeton de session de l'utilisateur.

## 10. Ce qui est implémenté

| Élément | Fichier | État |
|---|---|---|
| Format des paquets (lecture/écriture, tests) | `lib/services/brassard/mesure_emg.dart`, `test/brassard_test.dart` | ✅ |
| UUID et codes partagés | `lib/services/brassard/gatt_athletix.dart` | ✅ |
| Brassard simulé dans l'app (même format d'octets) | `lib/services/brassard/brassard_simule.dart` | ✅ |
| Faux brassard ESP32 qui publie ce service | `hardware/faux-brassard-ble/faux-brassard-ble.ino` | ✅ (non compilé ici, à tester sur carte) |
| Lecture de la configuration et de l'état, commandes (tests) | `lib/services/brassard/codec_gatt.dart`, `test/ajouts_test.dart` | ✅ |
| Connexion Bluetooth réelle dans l'app (Android et Chrome) | `lib/services/brassard/brassard_ble.dart` | ✅ écrite, ⏳ à tester avec une carte |
| Firmware final (vrai MyoWare, jauge de batterie, intervalle 15–20 ms) | `hardware/firmware-brassard/` | ✅ calculs testés sur ordinateur (`tests/firmware/`), ⏳ à flasher |
