import 'dart:typed_data';

import 'gatt_athletix.dart';

/// Contenu de la caractéristique Configuration (GATT.md §6), 5 octets.
class ConfigurationBrassard {
  const ConfigurationBrassard({
    required this.seuilHaut,
    required this.seuilBas,
    required this.refMvcMv,
    required this.frequenceHz,
  });

  final int seuilHaut;
  final int seuilBas;
  final int refMvcMv;
  final int frequenceHz;

  static const int taille = 5;

  static const ConfigurationBrassard parDefaut = ConfigurationBrassard(
    seuilHaut: GattAthletix.seuilHautDefaut,
    seuilBas: GattAthletix.seuilBasDefaut,
    refMvcMv: GattAthletix.refMvcDefautMv,
    frequenceHz: GattAthletix.frequenceDefautHz,
  );

  /// Lit les 5 octets (little-endian). Les octets en plus sont ignorés (GATT.md §3).
  factory ConfigurationBrassard.depuisOctets(List<int> octets) {
    if (octets.length < taille) {
      throw FormatException('Configuration de ${octets.length} octets, $taille attendus');
    }
    final d = ByteData.sublistView(Uint8List.fromList(octets.sublist(0, taille)));
    return ConfigurationBrassard(
      seuilHaut: d.getUint8(0),
      seuilBas: d.getUint8(1),
      refMvcMv: d.getUint16(2, Endian.little),
      frequenceHz: d.getUint8(4),
    );
  }

  Uint8List versOctets() {
    final d = ByteData(taille);
    d.setUint8(0, seuilHaut);
    d.setUint8(1, seuilBas);
    d.setUint16(2, refMvcMv, Endian.little);
    d.setUint8(4, frequenceHz);
    return d.buffer.asUint8List();
  }
}

/// Contenu de la caractéristique État (GATT.md §7), 2 octets.
class EtatLu {
  const EtatLu(this.etat, this.codeErreur);

  final EtatBrassard etat;
  final int codeErreur;

  factory EtatLu.depuisOctets(List<int> octets) {
    if (octets.isEmpty) throw const FormatException('État vide');
    final valeur = octets[0];
    final etat = valeur < EtatBrassard.values.length ? EtatBrassard.values[valeur] : EtatBrassard.erreur;
    return EtatLu(etat, octets.length > 1 ? octets[1] : 0);
  }

  /// Message lisible pour un code d'erreur du brassard.
  String get message => switch (codeErreur) {
        0 => 'aucune erreur',
        1 => 'signal saturé trop longtemps : vérifie la position des électrodes',
        2 => 'batterie faible (moins de 10 %)',
        3 => 'calibration invalide : signal trop faible, serre plus fort ou vérifie les électrodes',
        4 => 'commande refusée par le brassard',
        _ => 'erreur inconnue (code $codeErreur)',
      };
}

/// Commandes du point de contrôle (GATT.md §5).
class CommandeBrassard {
  CommandeBrassard._();

  static List<int> demarrer() => [GattAthletix.cmdDemarrer];
  static List<int> arreter() => [GattAthletix.cmdArreter];
  static List<int> calibrer() => [GattAthletix.cmdCalibrer];

  /// Refusée côté application si seuilBas ≥ seuilHaut, comme côté brassard.
  static List<int> reglerSeuil(int seuilHaut, int seuilBas) {
    if (seuilBas >= seuilHaut || seuilHaut > 255 || seuilBas < 0) {
      throw ArgumentError('Seuils invalides : bas ($seuilBas) doit être inférieur à haut ($seuilHaut)');
    }
    return [GattAthletix.cmdReglerSeuil, seuilHaut, seuilBas];
  }
}
