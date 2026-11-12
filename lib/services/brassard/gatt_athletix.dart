/// Identifiants Bluetooth LE du brassard Athletix (voir architecture/GATT.md).
///
/// Ces valeurs doivent être EXACTEMENT les mêmes que dans le firmware
/// (hardware/faux-brassard-ble/faux-brassard-ble.ino).
class GattAthletix {
  GattAthletix._();

  // Service propre au brassard et ses caractéristiques
  static const String service = 'abad0000-b097-4a54-8315-c2971fc04ce6';
  static const String mesureEmg = 'abad0001-b097-4a54-8315-c2971fc04ce6'; // Notify, 8 octets
  static const String pointDeControle = 'abad0002-b097-4a54-8315-c2971fc04ce6'; // Write
  static const String configuration = 'abad0003-b097-4a54-8315-c2971fc04ce6'; // Read, Write, 5 octets
  static const String etat = 'abad0004-b097-4a54-8315-c2971fc04ce6'; // Read, Notify, 2 octets
  static const String horsLigne = 'abad0005-b097-4a54-8315-c2971fc04ce6'; // Read, 20 à 220 octets (natation)

  // Services et caractéristiques standards du Bluetooth
  static const String serviceBatterie = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String niveauBatterie = '00002a19-0000-1000-8000-00805f9b34fb';
  static const String serviceInfosAppareil = '0000180a-0000-1000-8000-00805f9b34fb';
  static const String numeroSerie = '00002a25-0000-1000-8000-00805f9b34fb';
  static const String versionFirmware = '00002a26-0000-1000-8000-00805f9b34fb';

  // Commandes du point de contrôle (premier octet écrit)
  static const int cmdDemarrer = 0x01;
  static const int cmdArreter = 0x02;
  static const int cmdCalibrer = 0x03;
  static const int cmdReglerSeuil = 0x04; // suivi de seuil_haut, seuil_bas (en %)
  static const int cmdDemarrerHorsLigne = 0x05; // mesure gardée dans le brassard (natation)
  static const int cmdEffacerHorsLigne = 0x06; // après lecture et enregistrement

  // Valeurs par défaut de la configuration
  static const int seuilHautDefaut = 75;
  static const int seuilBasDefaut = 70;
  static const int refMvcDefautMv = 1850;
  static const int frequenceDefautHz = 50;
}

/// États possibles du brassard (caractéristique État, premier octet).
enum EtatBrassard { repos, mesure, calibration, erreur }
