# Intégration réseau : du muscle à la base de données

> Auteur : Othmen Al Bydeoi — architecture système. Version 1.0 (novembre 2026).

## 1. Le chemin des données

```
 Muscle ──► MyoWare 2.0 ──► ESP32-S3 ══ Bluetooth LE ══► Application ══ HTTPS ══► API PHP ──► MySQL
          (enveloppe        (RMS, % MVC,  (GATT, 50 Hz)   (affichage,    (POST +    (backend/)  (résultats,
           analogique)       alerte)                       résumé)        jeton)                  calibrations)
```

Il y a **deux liaisons**, chacune avec son rôle :

| Liaison | Technologie | Ce qui passe | Fréquence |
|---|---|---|---|
| Brassard → application | Bluetooth Low Energy, GATT (voir `GATT.md`) | chaque mesure, 8 octets | ~50 par seconde |
| Application → serveur | HTTPS, formulaire POST + jeton de session | un **résumé** par séance, une ligne par calibration | quelques fois par jour |

**Le brassard ne parle jamais directement au serveur.** Il n'a pas d'accès Internet, ni de compte. C'est l'application, déjà connectée avec le jeton de l'utilisateur, qui relaie. Cela corrige une incohérence de la version précédente : `update_hardware.php` demandait au brassard le jeton de session d'un utilisateur, ce qu'un objet connecté ne peut pas avoir.

## 2. Routes de l'API ajoutées

Toutes en `POST`, avec le champ `token` (jeton de session), comme le reste de l'API.

### `save_seance.php`

Enregistre une séance terminée et son résumé EMG, dans une transaction (soit tout est enregistré, soit rien).

| Champ | Obligatoire | Contrôle |
|---|---|---|
| `discipline` | oui | 1 à 50 caractères |
| `duree_s` | oui | 1 à 21 600 (6 h) |
| `nb_echantillons` | oui | ≥ 0 |
| `intensite_moyenne_pct`, `intensite_max_pct` | oui | 0 à 255, moyenne ≤ max |
| `temps_effort_intense_s` | oui | 0 à `duree_s` |
| `nb_alertes` | oui | ≥ 0 |
| `simule` | non | `1` si les données viennent du brassard simulé |
| `numero_serie`, `firmware` | non | si présents : le brassard est créé ou mis à jour et lié à l'utilisateur |
| `ref_mvc_mv` | non | 100 à 3300 |

Réponse : `{"status":"success","session_id":12}` ou `{"status":"error","message":"…"}` avec un message précis.

### `save_calibration.php`

| Champ | Contrôle |
|---|---|
| `numero_serie` | 4 à 32 caractères (lettres, chiffres, tirets) |
| `firmware` | facultatif |
| `ref_mvc_mv` | 100 à 3300 |

## 3. Le choix à trancher : Bluetooth dans le navigateur ou application Android ?

L'application est aujourd'hui en **Flutter Web**. Le Bluetooth dans un navigateur passe par l'API **Web Bluetooth**, qui a des limites fortes :

| | Web Bluetooth (Chrome) | Application Android (Flutter) |
|---|---|---|
| Navigateurs / appareils | Chrome et Edge sur ordinateur et Android. **Pas** sur iPhone, **pas** sur Firefox | tous les Android récents |
| Conditions | site en HTTPS, l'utilisateur doit cliquer pour choisir l'appareil | permissions Bluetooth à demander |
| Identifiant de l'appareil | opaque (pas d'adresse MAC) → on utilise le numéro de série GATT | adresse MAC disponible |
| Démo en ligne (GitHub Pages) | ✅ fonctionne tel quel | ❌ il faut installer l'APK |
| Effort | moyen : appels JavaScript depuis Dart | moyen : un package BLE (par ex. `flutter_blue_plus`) |

**Recommandation :** garder la version web pour la démo, et viser une **version Android** pour l'usage réel avec le brassard. Le code est déjà préparé pour les deux : l'écran de séance ne dépend que de l'interface `SourceBrassard` (`lib/services/brassard/source_brassard.dart`). Il suffit d'écrire une classe `BrassardBle` qui implémente cette interface avec le package choisi, sans toucher aux écrans. Vérifier au moment du choix le support web et Android du package dans sa documentation.

## 4. Ce qui marche déjà sans le vrai brassard

1. **Dans l'application :** `BrassardSimule` produit des paquets **au format GATT exact** (mêmes octets), les décode avec le vrai décodeur, et l'écran de séance affiche le % MVC. À la fin, le résumé est envoyé à `save_seance.php`. Tout le chemin est testé, sauf la radio.
2. **Avec un ESP32 :** `hardware/faux-brassard-ble/` publie le service GATT complet avec un signal simulé (ou le vrai signal du MyoWare si on change une ligne). On peut le tester avec l'application gratuite **nRF Connect** : on doit voir le service `abad0000-…`, s'abonner à la mesure et voir arriver les paquets.

## 5. Étapes suivantes

| Étape | Qui | Dépend de |
|---|---|---|
| Tester le faux brassard ESP32 avec nRF Connect | Othmen | une carte ESP32 |
| Choisir web ou Android (§3) | équipe | — |
| Écrire `BrassardBle` (connexion réelle) | Othmen | choix ci-dessus |
| Remplacer la source simulée par le MyoWare dans le firmware | Valentin | brassard câblé |
| Nouvelle règle de score du classement | équipe | `MCD_MLD.md` §5 |
