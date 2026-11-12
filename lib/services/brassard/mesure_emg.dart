import 'dart:typed_data';

/// Un paquet « Mesure EMG » de 8 octets envoyé par le brassard (voir architecture/GATT.md §4).
///
/// | octets | champ       | type   |
/// |--------|-------------|--------|
/// | 0–3    | horodatage  | uint32 (ms) |
/// | 4–5    | rms         | uint16 (mV) |
/// | 6      | intensité   | uint8 (% MVC) |
/// | 7      | drapeaux    | uint8  |
///
/// Tous les entiers sont en little-endian.
class MesureEmg {
  static const int taille = 8;

  static const int bitAlerte = 0x01;
  static const int bitSaturation = 0x02;
  static const int bitCalibration = 0x04;

  final int horodatageMs;
  final int rmsMv;
  final int intensitePct;
  final bool alerte;
  final bool saturation;
  final bool calibrationEnCours;

  const MesureEmg({
    required this.horodatageMs,
    required this.rmsMv,
    required this.intensitePct,
    this.alerte = false,
    this.saturation = false,
    this.calibrationEnCours = false,
  });

  /// Lit un paquet de exactement 8 octets.
  factory MesureEmg.depuisOctets(List<int> octets) {
    if (octets.length != taille) {
      throw FormatException('Paquet EMG de ${octets.length} octets, $taille attendus');
    }
    final donnees = ByteData.sublistView(Uint8List.fromList(octets));
    final drapeaux = donnees.getUint8(7);
    return MesureEmg(
      horodatageMs: donnees.getUint32(0, Endian.little),
      rmsMv: donnees.getUint16(4, Endian.little),
      intensitePct: donnees.getUint8(6),
      alerte: (drapeaux & bitAlerte) != 0,
      saturation: (drapeaux & bitSaturation) != 0,
      calibrationEnCours: (drapeaux & bitCalibration) != 0,
    );
  }

  /// Lit une notification Bluetooth : 1 paquet ou plusieurs paquets groupés
  /// (la longueur doit être un multiple de 8, voir GATT.md « Débit »).
  static List<MesureEmg> depuisNotification(List<int> octets) {
    if (octets.isEmpty || octets.length % taille != 0) {
      throw FormatException('Notification EMG de ${octets.length} octets : multiple de $taille attendu');
    }
    return [
      for (var debut = 0; debut < octets.length; debut += taille)
        MesureEmg.depuisOctets(octets.sublist(debut, debut + taille)),
    ];
  }

  /// Écrit le paquet de 8 octets (utilisé par le brassard simulé et les tests).
  /// Les valeurs trop grandes sont plafonnées, comme dans le firmware.
  Uint8List versOctets() {
    final donnees = ByteData(taille);
    donnees.setUint32(0, horodatageMs % 0x100000000, Endian.little);
    donnees.setUint16(4, rmsMv.clamp(0, 0xFFFF).toInt(), Endian.little);
    donnees.setUint8(6, intensitePct.clamp(0, 255).toInt());
    donnees.setUint8(
      7,
      (alerte ? bitAlerte : 0) | (saturation ? bitSaturation : 0) | (calibrationEnCours ? bitCalibration : 0),
    );
    return donnees.buffer.asUint8List();
  }

  @override
  String toString() =>
      'MesureEmg(t=$horodatageMs ms, rms=$rmsMv mV, $intensitePct %, alerte=$alerte)';
}
