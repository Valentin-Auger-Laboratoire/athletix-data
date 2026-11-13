import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Ceinture ou montre cardio du commerce, reliée en Bluetooth (service standard « Heart Rate »).
///
/// Le brassard EMG sur le biceps mesure le muscle, pas le cœur : pour la fréquence cardiaque,
/// l'application lit ce service standard, que proposent la plupart des ceintures cardio.
class CeintureCardio {
  CeintureCardio._(this._appareil);

  static const String uuidService = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String uuidMesure = '00002a37-0000-1000-8000-00805f9b34fb';

  final BluetoothDevice _appareil;
  final StreamController<int> _flux = StreamController<int>.broadcast();
  final List<StreamSubscription> _abonnements = [];
  final ValueNotifier<int?> derniere = ValueNotifier<int?>(null);

  /// Ceinture choisie dans l'écran « Brassard », partagée par l'application.
  static final ValueNotifier<CeintureCardio?> active = ValueNotifier<CeintureCardio?>(null);

  String get nom => _appareil.platformName.isNotEmpty ? _appareil.platformName : 'Capteur cardio';
  Stream<int> get bpm => _flux.stream;

  /// Lit une valeur de la caractéristique 0x2A37 (norme Bluetooth « Heart Rate Measurement ») :
  /// bit 0 des drapeaux = 0 → fréquence sur 1 octet, = 1 → sur 2 octets (little-endian).
  static int? lireMesure(List<int> octets) {
    if (octets.length < 2) return null;
    final seizeBits = (octets[0] & 0x01) != 0;
    if (seizeBits) {
      if (octets.length < 3) return null;
      return octets[1] | (octets[2] << 8);
    }
    return octets[1];
  }

  static Stream<List<ScanResult>> rechercher({Duration duree = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(withServices: [Guid(uuidService)], timeout: duree);
    return FlutterBluePlus.scanResults;
  }

  static Future<CeintureCardio> connecter(BluetoothDevice appareil) async {
    final c = CeintureCardio._(appareil);
    await appareil.connect(license: License.nonprofit, mtu: null, timeout: const Duration(seconds: 15));
    final services = await appareil.discoverServices();
    BluetoothCharacteristic? mesure;
    for (final s in services) {
      if (s.uuid != Guid(uuidService)) continue;
      for (final ch in s.characteristics) {
        if (ch.uuid == Guid(uuidMesure)) mesure = ch;
      }
    }
    if (mesure == null) {
      await appareil.disconnect();
      throw Exception("Cet appareil ne propose pas la fréquence cardiaque");
    }
    c._abonnements.add(mesure.onValueReceived.listen((o) {
      final v = lireMesure(o);
      if (v != null && v > 0) {
        c.derniere.value = v;
        if (!c._flux.isClosed) c._flux.add(v);
      }
    }));
    await mesure.setNotifyValue(true);
    return c;
  }

  void fermer() {
    for (final a in _abonnements) {
      a.cancel();
    }
    if (!_flux.isClosed) _flux.close();
    _appareil.disconnect().catchError((_) {});
  }
}

/// Moyenne et maximum de la fréquence cardiaque pendant une séance.
class StatsCardio {
  int _somme = 0, _nb = 0, _max = 0;

  void ajouter(int bpm) {
    if (bpm < 30 || bpm > 240) return; // valeur aberrante
    _somme += bpm;
    _nb++;
    if (bpm > _max) _max = bpm;
  }

  int? get moyenne => _nb == 0 ? null : (_somme / _nb).round();
  int? get maximum => _nb == 0 ? null : _max;

  Map<String, String> versApi() => {
        if (moyenne != null) 'fc_moy': '$moyenne',
        if (maximum != null) 'fc_max': '$maximum',
      };
}
