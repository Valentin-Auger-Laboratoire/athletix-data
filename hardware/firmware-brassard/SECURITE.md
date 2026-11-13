# Appairage sécurisé du brassard

Travail de **Valentin Auger** (novembre 2026), préparé avant de recevoir le matériel.

## Pourquoi

Le brassard envoie des **données de santé** (activité d'un muscle, fatigue). Sans appairage, n'importe quel téléphone à portée peut se connecter, lire les mesures et même envoyer des commandes (changer les seuils, effacer une séance de natation). Pour un prototype de salle de TP ce n'est pas grave ; pour un brassard porté par une patiente, si.

## Ce que fait le firmware (réglage `APPAIRAGE_SECURISE` = 1)

| Point | Choix |
|---|---|
| Méthode | **LE Secure Connections** (échange de clés par courbe elliptique), avec protection contre l'homme du milieu et mémorisation (*bonding*) : `ESP_LE_AUTH_REQ_SC_MITM_BOND` |
| Code | **6 chiffres tirés au hasard** (générateur matériel de l'ESP32) au premier démarrage, puis gardés en mémoire non volatile. Un code calculé à partir du numéro de série serait devinable : l'adresse Bluetooth est publique, et ce dépôt aussi |
| Où le lire | moniteur série au démarrage (`Appairage sécurisé : code 123456`) ; à écrire sur une **étiquette collée sous le boîtier** |
| Ce qui est protégé | les 6 caractéristiques du service Athletix (mesures, commandes, configuration, état, natation, fréquence) et leurs descripteurs : lecture et écriture seulement sur une liaison **chiffrée et authentifiée** (`ESP_GATT_PERM_READ_ENC_MITM`, `ESP_GATT_PERM_WRITE_ENC_MITM`) |
| Ce qui reste lisible | numéro de série, version du firmware, batterie : ils ne disent rien de la santé et servent à reconnaître le brassard |
| Appairage sans code | refusé (`ESP_BLE_SM_ONLY_ACCEPT_SPECIFIED_SEC_AUTH`) |

Commandes à taper dans le **moniteur série** (USB, jamais par Bluetooth) :

| Commande | Effet |
|---|---|
| `CODE` | réaffiche le code |
| `OUBLIER` | efface tous les téléphones appairés (le code ne change pas) |
| `NOUVEAU` | tire un nouveau code et efface les appairages (brassard prêté, code divulgué) |

Par défaut, `APPAIRAGE_SECURISE` vaut **0** : liaison ouverte, comme le faux brassard. On garde 0 pour les premiers essais de la carte (étapes 1 à 8 du protocole), puis on passe à 1 (étape 9), une fois le reste validé : si quelque chose ne marche pas, on sait que ce n'est pas l'appairage.

## Ce que fait l'application

- À la première connexion à un brassard sécurisé (Android), l'application demande le code dans une fenêtre (« Code du brassard »), vérifie qu'il a 6 chiffres et le transmet au système (`createBond`). Android peut aussi afficher sa propre fenêtre : il suffit d'y taper le même code.
- Ensuite, le téléphone et le brassard se reconnaissent : plus de code à taper.
- Écran « Brassard » : ligne **Liaison : chiffrée (appairé avec le code)**, et bouton **Oublier l'appairage**.
- Dans Chrome (démo web), c'est le système (Windows, Android) qui gère l'appairage et demande le code.

## Vérifié sans la carte

- `tests/firmware/test_securite.cpp` (15 vérifications) : code toujours à 6 chiffres, tirage uniforme (rejet des valeurs du haut, 900 000 tirages), commandes du moniteur série.
- `tests/firmware/test_firmware_complet.cpp` compilé avec `-DAPPAIRAGE_SECURISE=1` (38 vérifications) : code tiré et gardé en mémoire, transmis à la pile Bluetooth, mode Secure Connections, 6 caractéristiques et leurs descripteurs protégés, informations de l'appareil lisibles, `CODE`, `OUBLIER` et `NOUVEAU`. Avec `-DAPPAIRAGE_SECURISE=0` : liaison ouverte, comme avant.
- `test/securite_test.dart` : même règle de code côté application.

## Limites

- **Pas encore essayé avec un vrai téléphone** : c'est l'étape 9 du [protocole de test](../PROTOCOLE-DE-TEST.md). Les fonctions utilisées (`esp_ble_gap_set_security_param`, `setAccessPermissions`) sont celles de la pile Bluedroid du cœur Arduino ESP32 ; leur nom peut changer d'une version à l'autre.
- Un code fixe écrit sur une étiquette protège contre un inconnu à portée, pas contre quelqu'un qui a le brassard en main (il peut lire l'étiquette). C'est le compromis habituel des objets sans écran ; `NOUVEAU` permet de changer le code.
- Le serveur ne peut toujours pas prouver qu'une séance vient du vrai brassard : il faudrait que le brassard **signe** ses résumés (piste notée dans `architecture/INTEGRATION.md`).
