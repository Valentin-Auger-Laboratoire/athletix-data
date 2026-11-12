# Firmware final du brassard

Programme de la carte **SparkFun Thing Plus ESP32-S3** du brassard EMG. Il respecte exactement le format Bluetooth de [`architecture/GATT.md`](../../architecture/GATT.md) : l'application ne fait pas la différence avec le [faux brassard](../faux-brassard-ble/README.md), sauf que les mesures viennent d'un vrai muscle.

| Fichier | Rôle |
|---|---|
| `firmware-brassard.ino` | Bluetooth, lecture du MyoWare, jauge de batterie, commandes |
| `calcul_emg.h` | tous les calculs : RMS glissante 200 ms, % MVC, alerte avec hystérésis, calibration, paquets de 8 octets. Aucune dépendance au matériel |

## Ce qu'il fait de plus que le faux brassard

- **Vrai signal** : sortie ENV du MyoWare 2.0 (interrupteur du Link Shield sur **ENV**) lue sur **A0 = GPIO10**, 500 fois par seconde.
- **Vraie batterie** : jauge **MAX17048** de la carte (I2C, adresse `0x36`, GPIO8 / GPIO9), lue toutes les 30 s et envoyée en Bluetooth. Si la jauge ne répond pas, le service batterie n'est pas publié et l'application affiche « — ».
- **Intervalle de connexion court** (15 à 20 ms), demandé au téléphone pour tenir 50 mesures par seconde.
- **Avertissements** (caractéristique État) : saturation pendant plus de 2 s (électrode décollée ?), batterie sous 10 %.
- **Commandes traitées dans `loop()`**, pas dans la tâche Bluetooth : évite les accès simultanés aux variables.

## Vérifications faites sans la carte

- **Les calculs** (`calcul_emg.h`) sont compilés et testés sur ordinateur : 27 vérifications, dont le paquet identique à l'exemple de `GATT.md` et le profil d'effort de la simulation Simulink (une seule alerte, pas de clignotement).
  ```bash
  g++ -std=c++17 -Wall -Wextra -I hardware/firmware-brassard tests/firmware/test_calcul_emg.cpp -o test_emg && ./test_emg
  ```
- **Le programme complet** a été vérifié à la compilation avec des imitations des bibliothèques ESP32 (mêmes fonctions). Il n'a **pas encore été compilé pour l'ESP32 ni testé sur une carte** : c'est la première étape du [protocole de test](../PROTOCOLE-DE-TEST.md).

## Flasher la carte

1. Arduino IDE → *Préférences* → URL de cartes supplémentaires : `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
2. *Gestionnaire de cartes* → installer **esp32** (Espressif).
3. Ouvrir `firmware-brassard.ino` (le dossier doit garder le même nom que le fichier), choisir la carte **SparkFun ESP32-S3 Thing Plus**, téléverser par l'USB-C.
4. Moniteur série à 115 200 bauds : `Jauge de batterie : trouvée`, puis `Brassard prêt : Athletix-XXXX`.

Si la compilation signale une erreur dans la partie Bluetooth (les noms changent parfois d'une version du cœur esp32 à l'autre), comparer avec le faux brassard, qui utilise les mêmes fonctions.
