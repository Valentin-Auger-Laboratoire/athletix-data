import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'codec_gatt.dart';
import 'gatt_athletix.dart';
import 'mesure_emg.dart';
import 'source_brassard.dart';

/// Le vrai brassard, relié en Bluetooth Low Energy (architecture/GATT.md).
///
/// Fonctionne sur Android (application installée) et dans Chrome / Edge (Web Bluetooth,
/// site en HTTPS). Les écrans ne voient que [SourceBrassard] : ils ne savent pas
/// s'ils parlent à ce brassard ou au brassard simulé.
///
/// Utilisation :
/// ```dart
/// final resultats = BrassardBle.rechercher();          // liste des brassards à portée
/// final brassard = await BrassardBle.connecter(device); // connexion + lecture des infos
/// ```
///
/// ⚠️ Écrit et vérifié sans le matériel (format testé avec le brassard simulé et les tests).
/// À valider avec le firmware de test `hardware/faux-brassard-ble/` puis le vrai brassard.
class BrassardBle implements SourceBrassard {
  BrassardBle._(this._appareil);

  final BluetoothDevice _appareil;
  final StreamController<MesureEmg> _flux = StreamController<MesureEmg>.broadcast();
  final StreamController<EtatLu> _etats = StreamController<EtatLu>.broadcast();
  final List<StreamSubscription> _abonnements = [];

  late BluetoothCharacteristic _carMesure;
  late BluetoothCharacteristic _carControle;
  late BluetoothCharacteristic _carConfiguration;
  BluetoothCharacteristic? _carEtat;
  BluetoothCharacteristic? _carHorsLigne;
  BluetoothCharacteristic? _carBatterie;

  String? _numeroSerie;
  String? _firmware;
  int? _batterie;
  ConfigurationBrassard _config = ConfigurationBrassard.parDefaut;

  /// Vrai tant que la liaison Bluetooth est active.
  final ValueNotifier<bool> connecte = ValueNotifier<bool>(false);

  static final Guid _service = Guid(GattAthletix.service);

  /// Services lus en plus du service Athletix : dans Chrome, il faut les déclarer
  /// à l'avance, sinon le navigateur refuse d'y accéder (Web Bluetooth).
  static final List<Guid> _servicesOptionnels = [
    Guid(GattAthletix.serviceBatterie),
    Guid(GattAthletix.serviceInfosAppareil),
  ];

  /// Vrai si l'appareil ou le navigateur sait faire du Bluetooth LE.
  static Future<bool> disponible() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Cherche les brassards Athletix à portée pendant [duree].
  /// Le filtre sur l'UUID du service évite d'afficher les autres appareils Bluetooth.
  /// Dans Chrome, c'est le navigateur qui affiche sa propre fenêtre de choix.
  static Stream<List<ScanResult>> rechercher({Duration duree = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(
      withServices: [_service],
      webOptionalServices: _servicesOptionnels,
      timeout: duree,
    );
    return FlutterBluePlus.scanResults;
  }

  static Future<void> arreterRecherche() => FlutterBluePlus.stopScan();

  /// Se connecte au brassard, lit ses informations et s'abonne aux mesures.
  static Future<BrassardBle> connecter(BluetoothDevice appareil) async {
    final brassard = BrassardBle._(appareil);
    try {
      await brassard._ouvrir();
      return brassard;
    } catch (e) {
      brassard.fermer();
      if (e is ErreurBrassard) rethrow;
      throw ErreurBrassard('Connexion impossible : $e');
    }
  }

  Future<void> _ouvrir() async {
    // License.nonprofit : projet étudiant, usage pédagogique (licence FlutterBluePlus, section 2)
    await _appareil.connect(license: License.nonprofit, mtu: null, timeout: const Duration(seconds: 15));
    connecte.value = true;
    _abonnements.add(_appareil.connectionState.listen((etat) {
      connecte.value = etat == BluetoothConnectionState.connected;
      if (!connecte.value && !_flux.isClosed) {
        _flux.addError(ErreurBrassard('Liaison Bluetooth perdue'));
      }
    }));

    // 50 notifications par seconde demandent un intervalle de connexion court (GATT.md §4)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _appareil.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
      } catch (_) {/* le téléphone peut refuser : on garde le mode de repli (paquets groupés) */}
    }

    final services = await _appareil.discoverServices();
    BluetoothCharacteristic? trouver(String service, String caracteristique) {
      for (final s in services) {
        if (s.uuid != Guid(service)) continue;
        for (final c in s.characteristics) {
          if (c.uuid == Guid(caracteristique)) return c;
        }
      }
      return null;
    }

    final mesure = trouver(GattAthletix.service, GattAthletix.mesureEmg);
    final controle = trouver(GattAthletix.service, GattAthletix.pointDeControle);
    final configuration = trouver(GattAthletix.service, GattAthletix.configuration);
    if (mesure == null || controle == null || configuration == null) {
      throw ErreurBrassard("Ce n'est pas un brassard Athletix (service EMG incomplet)");
    }
    _carMesure = mesure;
    _carControle = controle;
    _carConfiguration = configuration;
    _carEtat = trouver(GattAthletix.service, GattAthletix.etat);
    _carHorsLigne = trouver(GattAthletix.service, GattAthletix.horsLigne); // firmware 1.1 et plus
    _carBatterie = trouver(GattAthletix.serviceBatterie, GattAthletix.niveauBatterie);

    // Informations de l'appareil (facultatives : un firmware de test peut ne pas les avoir)
    _numeroSerie = await _lireTexte(trouver(GattAthletix.serviceInfosAppareil, GattAthletix.numeroSerie));
    _firmware = await _lireTexte(trouver(GattAthletix.serviceInfosAppareil, GattAthletix.versionFirmware));
    await _lireConfiguration();

    // Batterie : lecture, puis notifications si le brassard les envoie
    final batterie = _carBatterie;
    if (batterie != null) {
      final octets = await batterie.read();
      if (octets.isNotEmpty) _batterie = octets.first.clamp(0, 100).toInt();
      if (batterie.properties.notify) {
        _abonnements.add(batterie.onValueReceived.listen((o) {
          if (o.isNotEmpty) _batterie = o.first.clamp(0, 100).toInt();
        }));
        await batterie.setNotifyValue(true);
      }
    }

    // État (repos, mesure, calibration, erreur)
    final etat = _carEtat;
    if (etat != null) {
      _abonnements.add(etat.onValueReceived.listen((o) {
        try {
          _etats.add(EtatLu.depuisOctets(o));
        } on FormatException {/* valeur ignorée (GATT.md §3) */}
      }));
      await etat.setNotifyValue(true);
    }

    // Mesures EMG : une notification = un ou plusieurs paquets de 8 octets
    _abonnements.add(_carMesure.onValueReceived.listen((octets) {
      try {
        for (final m in MesureEmg.depuisNotification(octets)) {
          if (!_flux.isClosed) _flux.add(m);
        }
      } on FormatException catch (e) {
        debugPrint('Paquet EMG ignoré : $e');
      }
    }));
    await _carMesure.setNotifyValue(true);
  }

  Future<String?> _lireTexte(BluetoothCharacteristic? c) async {
    if (c == null) return null;
    try {
      final texte = utf8.decode(await c.read(), allowMalformed: true).trim();
      return texte.isEmpty ? null : texte;
    } catch (_) {
      return null;
    }
  }

  Future<void> _lireConfiguration() async {
    try {
      _config = ConfigurationBrassard.depuisOctets(await _carConfiguration.read());
    } on FormatException {
      _config = ConfigurationBrassard.parDefaut;
    }
  }

  Future<void> _envoyer(List<int> commande) async {
    if (!connecte.value) throw ErreurBrassard('Brassard déconnecté');
    await _carControle.write(commande, withoutResponse: false);
  }

  @override
  String get nom => _appareil.platformName.isNotEmpty ? _appareil.platformName : 'Brassard Athletix';

  @override
  bool get simule => false;

  @override
  String? get numeroSerie => _numeroSerie;

  @override
  String? get firmware => _firmware;

  @override
  int get refMvcMv => _config.refMvcMv;

  @override
  int? get batteriePct => _batterie;

  @override
  int get seuilHaut => _config.seuilHaut;

  @override
  int get seuilBas => _config.seuilBas;

  @override
  Stream<MesureEmg> get mesures => _flux.stream;

  @override
  Future<void> demarrer() => _envoyer(CommandeBrassard.demarrer());

  @override
  Future<void> arreter() async {
    if (connecte.value) await _envoyer(CommandeBrassard.arreter());
  }

  /// Change les seuils d'alerte (commande 0x04), puis relit la configuration.
  @override
  Future<void> demarrerHorsLigne() async {
    if (_carHorsLigne == null) {
      throw ErreurBrassard("Ce brassard ne sait pas enregistrer sans connexion (firmware 1.1 nécessaire)");
    }
    await _envoyer(CommandeBrassard.demarrerHorsLigne());
  }

  @override
  Future<ResumeHorsLigne> lireHorsLigne() async {
    final c = _carHorsLigne;
    if (c == null) {
      throw ErreurBrassard("Ce brassard ne sait pas enregistrer sans connexion (firmware 1.1 nécessaire)");
    }
    return ResumeHorsLigne.depuisOctets(await c.read()); // lecture longue : jusqu'à 220 octets
  }

  @override
  Future<void> effacerHorsLigne() => _envoyer(CommandeBrassard.effacerHorsLigne());

  @override
  Future<void> reglerSeuils(int seuilHaut, int seuilBas) async {
    await _envoyer(CommandeBrassard.reglerSeuil(seuilHaut, seuilBas));
    await _lireConfiguration();
  }

  @override
  Future<int> calibrer() async {
    // On écoute l'état AVANT d'envoyer la commande, pour ne pas rater la fin
    final fin = Completer<EtatLu>();
    final ecoute = _etats.stream.listen((e) {
      if (fin.isCompleted) return;
      if (e.etat == EtatBrassard.erreur || (e.etat == EtatBrassard.repos)) fin.complete(e);
    });
    try {
      await _envoyer(CommandeBrassard.calibrer());
      if (_carEtat != null) {
        // 3 s de calibration + marge ; sans réponse, on relit quand même la configuration
        final e = await fin.future.timeout(const Duration(seconds: 8), onTimeout: () => const EtatLu(EtatBrassard.repos, 0));
        if (e.etat == EtatBrassard.erreur) throw ErreurBrassard(e.message);
      } else {
        await Future.delayed(const Duration(milliseconds: 3500));
      }
      await _lireConfiguration();
      return _config.refMvcMv;
    } finally {
      await ecoute.cancel();
    }
  }

  @override
  void fermer() {
    for (final a in _abonnements) {
      a.cancel();
    }
    _abonnements.clear();
    if (!_flux.isClosed) _flux.close();
    if (!_etats.isClosed) _etats.close();
    connecte.value = false;
    _appareil.disconnect().catchError((_) {});
  }
}
