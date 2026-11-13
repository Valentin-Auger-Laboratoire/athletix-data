import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'montre_yoho.dart';
import 'montre_yoho_simulee.dart';
import 'protocole_yoho.dart';

/// Bracelet ou montre qui compte les pas au format « podomètre WeChat » (service 0xFEE7,
/// caractéristique 0xFEA1). Beaucoup de bracelets d'entrée de gamme l'ont, même sans le service
/// cardio standard : c'est le cas du bracelet MSGM115 (« YOHO ») de Valentin, vérifié avec nRF Connect
/// le 13 novembre 2026 (80 pas faits = `01-50-00-00`, soit 0x50 = 80).
///
/// Format de FEA1 (spécification publique du protocole WeChat pour les podomètres) :
///   octet 0 : drapeaux (bit 0 = pas, bit 1 = distance, bit 2 = calories) ;
///   puis, pour chaque drapeau présent et dans cet ordre, 3 octets little-endian :
///   pas, distance (m), calories (kcal).
///
/// Si le bracelet a aussi le service propre aux bracelets YOHO (0xCC00), [yoho] donne accès au cœur,
/// à la tension estimée, à l'historique (sommeil), à la vibration et aux réglages (voir montre_yoho.dart).
class MontrePodometre {
  MontrePodometre._(this._appareil);

  static const String uuidService = '0000fee7-0000-1000-8000-00805f9b34fb';
  static const String uuidPas = '0000fea1-0000-1000-8000-00805f9b34fb';

  final BluetoothDevice? _appareil;
  final StreamController<MesurePodometre> _flux = StreamController<MesurePodometre>.broadcast();
  final List<StreamSubscription> _abonnements = [];
  final ValueNotifier<MesurePodometre?> derniere = ValueNotifier<MesurePodometre?>(null);
  BluetoothCharacteristic? _carPas;

  /// Service propre aux bracelets YOHO (MSGM115), null si le bracelet ne l'a pas.
  LiaisonYoho? yoho;

  /// Montre choisie dans l'écran « Brassard », partagée par l'application.
  static final ValueNotifier<MontrePodometre?> active = ValueNotifier<MontrePodometre?>(null);

  String get nom {
    final a = _appareil;
    if (a == null) return 'MSGM115 (simulé)';
    return a.platformName.isNotEmpty ? a.platformName : 'Montre';
  }

  /// Bracelet MSGM115 simulé (démo) : mêmes octets que le vrai, décodés par le même code.
  static Future<MontrePodometre> simulee({TransportYohoSimule? transport}) async {
    final m = MontrePodometre._(null);
    final y = LiaisonYoho(transport ?? TransportYohoSimule());
    m.yoho = y;
    m._abonnements.add(y.messages.listen((msg) {
      if (msg is PasYoho) m._recevoirMesure(MesurePodometre(pas: msg.pas));
    }));
    await y.demarrer();
    return m;
  }
  Stream<MesurePodometre> get mesures => _flux.stream;

  /// Lit une valeur de FEA1. Renvoie null si elle est trop courte pour les drapeaux annoncés.
  static MesurePodometre? lire(List<int> o) {
    if (o.isEmpty) return null;
    final drapeaux = o[0];
    var i = 1;
    int? suivant() {
      if (o.length < i + 3) return null;
      final v = o[i] | (o[i + 1] << 8) | (o[i + 2] << 16);
      i += 3;
      return v;
    }

    int? pas, distance, calories;
    if (drapeaux & 0x01 != 0) {
      pas = suivant();
      if (pas == null) return null;
    }
    if (drapeaux & 0x02 != 0) {
      distance = suivant();
      if (distance == null) return null;
    }
    if (drapeaux & 0x04 != 0) {
      calories = suivant();
      if (calories == null) return null;
    }
    return MesurePodometre(pas: pas, distanceM: distance, calories: calories);
  }

  static Stream<List<ScanResult>> rechercher({Duration duree = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(withServices: [Guid(uuidService), Guid(ProtocoleYoho.uuidService)], timeout: duree);
    return FlutterBluePlus.scanResults;
  }

  static Future<MontrePodometre> connecter(BluetoothDevice appareil) async {
    final m = MontrePodometre._(appareil);
    await appareil.connect(license: License.nonprofit, mtu: null, timeout: const Duration(seconds: 15));
    final services = await appareil.discoverServices();
    for (final s in services) {
      if (s.uuid != Guid(uuidService)) continue;
      for (final ch in s.characteristics) {
        if (ch.uuid == Guid(uuidPas)) m._carPas = ch;
      }
    }
    try {
      m.yoho = await LiaisonYoho.ouvrir(services);
    } catch (_) {/* service CC00 présent mais refusé : on garde au moins les pas */}
    final car = m._carPas;
    if (car == null && m.yoho == null) {
      await appareil.disconnect();
      throw Exception('Cet appareil ne compte pas les pas au format attendu (service FEE7 / FEA1 ou CC00)');
    }
    if (car != null) {
      m._abonnements.add(car.onValueReceived.listen(m._recevoir));
      try {
        await car.setNotifyValue(true); // le bracelet prévient à chaque changement (indication)
      } catch (_) {/* certains n'acceptent que la lecture : on relit pendant la séance */}
    }
    // Les pas arrivent aussi par le service YOHO (compteur depuis minuit, comme FEA1)
    final yoho = m.yoho;
    if (yoho != null && car == null) {
      m._abonnements.add(yoho.messages.listen((msg) {
        if (msg is PasYoho) m._recevoirMesure(MesurePodometre(pas: msg.pas));
      }));
    }
    await m.relire();
    return m;
  }

  void _recevoir(List<int> octets) {
    final v = lire(octets);
    if (v != null) _recevoirMesure(v);
  }

  void _recevoirMesure(MesurePodometre v) {
    derniere.value = v;
    if (!_flux.isClosed) _flux.add(v);
  }

  /// Relit le compteur (utile si les indications ne marchent pas).
  Future<void> relire() async {
    final car = _carPas;
    if (car == null) return;
    try {
      _recevoir(await car.read());
    } catch (_) {}
  }

  void fermer() {
    yoho?.fermer();
    for (final a in _abonnements) {
      a.cancel();
    }
    if (!_flux.isClosed) _flux.close();
    _appareil?.disconnect().catchError((_) {});
  }
}

/// Une lecture du podomètre : compteurs DEPUIS MINUIT tenus par le bracelet.
class MesurePodometre {
  const MesurePodometre({this.pas, this.distanceM, this.calories});
  final int? pas;
  final int? distanceM;
  final int? calories;
}

/// Pas pendant une séance : on additionne les augmentations du compteur du bracelet.
/// Le compteur repart à zéro à minuit : une baisse veut dire « remis à zéro », on compte alors
/// la nouvelle valeur entière.
class PasSeance {
  int? _precedent;
  int _total = 0;

  void ajouter(int compteur) {
    final p = _precedent;
    if (p != null) _total += compteur >= p ? compteur - p : compteur;
    _precedent = compteur;
  }

  int get pas => _total;
}
