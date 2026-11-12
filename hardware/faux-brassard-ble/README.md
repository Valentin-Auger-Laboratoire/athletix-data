# Faux brassard Bluetooth LE

Firmware de test qui transforme n'importe quel ESP32 en « brassard Athletix ». Il publie exactement le service décrit dans [`architecture/GATT.md`](../../architecture/GATT.md), avec un signal inventé, pour tester l'application **avant** que le vrai brassard soit câblé.

## Flasher la carte

1. Arduino IDE → *Préférences* → URL de cartes supplémentaires : `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
2. *Gestionnaire de cartes* → installer **esp32** (Espressif).
3. Ouvrir `faux-brassard-ble.ino`, choisir la carte (ESP32 Dev Module, ou ESP32-S3 Dev Module), téléverser.
4. Moniteur série à 115 200 bauds : on doit lire `Faux brassard prêt : Athletix-XXXX`.

## Tester sans l'application, avec nRF Connect (Android ou iPhone)

1. Scanner, se connecter à **Athletix-XXXX**.
2. Ouvrir le service `abad0000-…`.
3. Sur `abad0001` (Mesure EMG), appuyer sur l'icône d'abonnement (les flèches).
4. Sur `abad0002` (Point de contrôle), écrire la valeur `01` (en hexadécimal) : les paquets de 8 octets arrivent, environ 50 par seconde.
5. Écrire `03` : calibration de 3 s, puis relire `abad0003` pour voir la nouvelle référence.
6. Écrire `02` : arrêt.

Pour lire un paquet, voir l'exemple dans `GATT.md` §4 (tout est en little-endian).

## Passer au vrai signal

Mettre `#define SOURCE_SIMULEE 0` et brancher la sortie **ENV** du MyoWare 2.0 sur `PIN_EMG` (A0 = GPIO10 sur la SparkFun Thing Plus ESP32-S3, GPIO34 sur ESP32 classique). Le calcul (500 Hz, RMS sur 200 ms, % MVC, alerte 75 % / 70 %) reprend celui de la simulation Simulink.

> Ce sketch n'a pas encore été testé sur une vraie carte : sa syntaxe a été vérifiée, mais pas son fonctionnement avec la bibliothèque BLE de l'ESP32. Note ici les résultats du premier essai.
