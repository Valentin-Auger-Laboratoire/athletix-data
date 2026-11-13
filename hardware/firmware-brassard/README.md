# Firmware final du brassard

Programme de la carte **SparkFun Thing Plus ESP32-S3** du brassard EMG. Il respecte exactement le format Bluetooth de [`architecture/GATT.md`](../../architecture/GATT.md) : l'application ne fait pas la différence avec le [faux brassard](../faux-brassard-ble/README.md), sauf que les mesures viennent d'un vrai muscle.

| Fichier | Rôle |
|---|---|
| `firmware-brassard.ino` | Bluetooth, lecture du MyoWare, jauge de batterie, commandes |
| `calcul_emg.h` | tous les calculs : RMS glissante 200 ms, % MVC, alerte avec hystérésis, calibration, paquets de 8 octets, résumé hors ligne (natation). Aucune dépendance au matériel |
| `calcul_fatigue.h` | fatigue : suppression de la composante continue, FFT, **fréquence médiane** du signal brut (version 1.2, voir [`FATIGUE.md`](FATIGUE.md)) |

## Ce qu'il fait de plus que le faux brassard

- **Vrai signal** : sortie ENV du MyoWare 2.0 (interrupteur du Link Shield sur **ENV**) lue sur **A0 = GPIO10**, 500 fois par seconde.
- **Vraie batterie** : jauge **MAX17048** de la carte (I2C, adresse `0x36`, GPIO8 / GPIO9), lue toutes les 30 s et envoyée en Bluetooth. Si la jauge ne répond pas, le service batterie n'est pas publié et l'application affiche « — ».
- **Intervalle de connexion court** (15 à 20 ms), demandé au téléphone pour tenir 50 mesures par seconde.
- **Avertissements** (caractéristique État) : saturation pendant plus de 2 s (électrode décollée ?), batterie sous 10 %.
- **Natation (version 1.1)** : commande `0x05`, le brassard continue de mesurer même si la liaison se coupe et garde le résumé de la séance (caractéristique `abad0005`, [`GATT.md`](../../architecture/GATT.md) §11). Arrêt automatique après 5 min sous 10 %, à la dernière activité. Le résumé n'est effacé que sur la commande `0x06`, envoyée par l'application une fois la séance enregistrée.
- **Journal USB** (`JOURNAL_SERIE`) : pendant une mesure, chaque valeur est aussi écrite sur le port USB (`M,ms,mV,RMS,intensité,alerte`), pour la [comparaison automatique avec la simulation](../../mesures/README.md). Électrodes sur la peau : PC portable débranché du secteur.
- **Fatigue (version 1.2)** : commande `0x07` pour lire le **signal brut** (interrupteur du Link Shield sur **RAW**) à 2 000 Hz. Le brassard calcule alors la fréquence médiane 2 fois par seconde (caractéristique `abad0006`) dans une tâche à part sur le second cœur. Explications et vérifications : [`FATIGUE.md`](FATIGUE.md).
- **Commandes traitées dans `loop()`**, pas dans la tâche Bluetooth : évite les accès simultanés aux variables.

## Vérifications faites sans la carte

- **Les calculs** (`calcul_emg.h`) sont compilés et testés sur ordinateur : 41 vérifications, dont le paquet identique à l'exemple de `GATT.md`, le profil d'effort de la simulation Simulink (une seule alerte, pas de clignotement) et la séance de natation (durée sans le temps au bord, moyenne, courbe, arrêt automatique). La copie en Dart du calcul de natation, utilisée par le brassard simulé, donne **les mêmes octets** (`test/natation_test.dart`). GitHub relance ces tests à chaque envoi.
  ```bash
  g++ -std=c++17 -Wall -Wextra -I hardware/firmware-brassard tests/firmware/test_calcul_emg.cpp -o test_emg && ./test_emg
  ```
- **La fatigue** (`calcul_fatigue.h`) : 34 vérifications, dont la comparaison avec la fréquence médiane théorique sur des signaux qui ressemblent à l'EMG.
- **Le programme complet** est compilé ET **exécuté** sur ordinateur avec des imitations des bibliothèques ESP32 (mêmes fonctions, dans [`tests/firmware/imitations/`](../../tests/firmware/imitations/Arduino.h)) et un muscle simulé sur A0 : `setup()`, `loop()`, commandes Bluetooth, tâche d'analyse, natation (28 vérifications, aussi sous ThreadSanitizer). Il n'a **pas encore été compilé pour l'ESP32 ni testé sur une carte** : c'est la première étape du [protocole de test](../PROTOCOLE-DE-TEST.md).
  ```bash
  g++ -std=c++17 -pthread -I tests/firmware/imitations -I hardware/firmware-brassard tests/firmware/test_firmware_complet.cpp -o test_complet && ./test_complet
  ```

## Flasher la carte

1. Arduino IDE → *Préférences* → URL de cartes supplémentaires : `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
2. *Gestionnaire de cartes* → installer **esp32** (Espressif).
3. Ouvrir `firmware-brassard.ino` (le dossier doit garder le même nom que le fichier), choisir la carte **SparkFun ESP32-S3 Thing Plus**, téléverser par l'USB-C.
4. Moniteur série à 115 200 bauds : `Jauge de batterie : trouvée`, puis `Brassard prêt : Athletix-XXXX`.

Si la compilation signale une erreur dans la partie Bluetooth (les noms changent parfois d'une version du cœur esp32 à l'autre), comparer avec le faux brassard, qui utilise les mêmes fonctions.
