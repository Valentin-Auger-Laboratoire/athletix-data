import 'dart:typed_data';

/// Paquet « Fréquence » de 8 octets (architecture/GATT.md §12), envoyé 2 fois par seconde
/// quand le brassard lit le signal brut (source RAW).
///
/// | octets | champ | type |
/// |---|---|---|
/// | 0–3 | horodatage | uint32 (ms) |
/// | 4–5 | fréquence médiane (MDF) | uint16 (0,1 Hz), 0 = pas de valeur (muscle au repos) |
/// | 6–7 | fréquence moyenne (MNF) | uint16 (0,1 Hz) |
class MesureFrequence {
  const MesureFrequence({required this.horodatageMs, required this.mdfHz, required this.mnfHz});

  static const int taille = 8;

  final int horodatageMs;
  final double mdfHz;
  final double mnfHz;

  /// Vrai si le muscle travaillait (au repos, le spectre n'est que du bruit : pas de valeur).
  bool get valide => mdfHz > 0;

  factory MesureFrequence.depuisOctets(List<int> octets) {
    if (octets.length != taille) {
      throw FormatException('Paquet Fréquence de ${octets.length} octets, $taille attendus');
    }
    final d = ByteData.sublistView(Uint8List.fromList(octets));
    return MesureFrequence(
      horodatageMs: d.getUint32(0, Endian.little),
      mdfHz: d.getUint16(4, Endian.little) / 10,
      mnfHz: d.getUint16(6, Endian.little) / 10,
    );
  }

  /// Comme le firmware : arrondi au dixième de Hz, plafonné à 6 553,5 Hz.
  Uint8List versOctets() {
    int dixiemes(double f) => f > 0 ? (f * 10 + 0.5).floor().clamp(0, 0xFFFF).toInt() : 0;
    final d = ByteData(taille);
    d.setUint32(0, horodatageMs % 0x100000000, Endian.little);
    d.setUint16(4, dixiemes(mdfHz), Endian.little);
    d.setUint16(6, dixiemes(mnfHz), Endian.little);
    return d.buffer.asUint8List();
  }
}
