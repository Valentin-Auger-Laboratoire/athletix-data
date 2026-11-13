import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'codec_gatt.dart';
import 'gatt_athletix.dart';
import 'mesure_emg.dart';
import 'mesure_frequence.dart';
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
  final StreamController<MesureFrequence> _frequences = StreamController<MesureFrequence>.broadcast();
  final List<StreamSubscription> _abonnements = [];

  late BluetoothCharacteristic _carMesure;
  late BluetoothCharacteristic _carControle;
  late BluetoothCharacteristic _carConfiguration;
  BluetoothCharacteristic? _carEtat;
  BluetoothCharacteristic? _carHorsLigne;
  BluetoothCharacteristic? _carFrequence;
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

  /// Demande à l'utilisateur le code d'appairage à 6 chiffres (étiquette du boîtier), ou null s'il annule.
  /// Fourni par l'écran « Brassard ». Utilisé seulement si le firmware exige l'appairage (SECURITE.md).
  static Future<String?> Function()? demanderCode;

  /// Code d'appairage valide : exactement 6 chiffres, de 100000 à 999999 (comme securite.h).
  static bool codeValide(String code) => RegExp(r'^[1-9][0-9]{5}$').hasMatch(code.trim());

  bool _appaire = false;

  /// Vrai si la liaison est appairée et chiffrée (Android seulement ; ailleurs, le système s'en charge).
  bool get appaire => _appaire;

  /// Oublie l'appairage sur le téléphone (Android). Le brassard, lui, s'oublie avec « OUBLIER »
  /// dans le moniteur série.
  Future<void> oublierAppairage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _appareil.removeBond();
    _appaire = false;
  }

  /// Firmware avec APPAIRAGE_SECURISE : le service Athletix refuse toute lecture tant que le téléphone
  /// n'est pas appairé avec le code. Sur Android, on demande le code dans l'application et on le
  /// transmet au système (qui peut aussi afficher sa propre fenêtre de saisie).
  Future<void> _appairerSiBesoin() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _appaire = await _appareil.bondState.first == BluetoothBondState.bonded;
    } catch (_) {}
    if (_appaire) return;
    try {
      await _carConfiguration.read(); // brassard sans appairage obligatoire : la lecture passe
      return;
    } catch (_) {/* lecture refusée : appairage nécessaire */}
    final code = await demanderCode?.call();
    if (code == null) throw ErreurBrassard('Appairage annulé : le brassard demande son code à 6 chiffres');
    if (!codeValide(code)) throw ErreurBrassard('Le code d\'appairage a 6 chiffres (étiquette du boîtier)');
    try {
      await _appareil.createBond(pin: Uint8List.fromList(utf8.encode(code.trim())));
      _appaire = true;
    } catch (e) {
      throw ErreurBrassard('Appairage refusé (code faux ?). Réessaie ; si besoin, « OUBLIER » sur le brassard. ($e)');
    }
  }

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

  // ---- Reconnexion automatique (séance sur terre seulement) ----
  // Le firmware arrête la mesure quand la liaison se coupe. Si une séance était en cours, on
  // essaie de se reconnecter pendant [dureeReconnexion], puis on relance la mesure : la séance
  // continue (le trou n'est pas compté comme effort intense, ResumeSeance.ecartMaxMs).
  static const Duration dureeReconnexion = Duration(seconds: 30);
  bool _mesureEnCours = false;
  bool _ferme = false;
  StreamSubscription? _abonnementConnexion;
  final ValueNotifier<bool> _reconnexion = ValueNotifier<bool>(false);
  DateTime? _calibreLe;

  @override
  ValueListenable<bool> get reconnexion => _reconnexion;

  @override
  Stream<EtatLu> get etats => _etats.stream;

  @override
  DateTime? get calibreLe => _calibreLe;

  Future<void> _ouvrir() async {
    await _connecterEtAbonner();
    _abonnementConnexion = _appareil.connectionState.listen((etat) {
      connecte.value = etat == BluetoothConnectionState.connected;
      if (connecte.value || _ferme || _reconnexion.value) return;
      if (_mesureEnCours) {
        _reconnecter();
      } else if (!_flux.isClosed) {
        _flux.addError(ErreurBrassard('Liaison Bluetooth perdue'));
      }
    });
  }

  Future<void> _reconnecter() async {
    _reconnexion.value = true;
    final limite = DateTime.now().add(dureeReconnexion);
    while (!_ferme && DateTime.now().isBefore(limite)) {
      try {
        await _connecterEtAbonner();
        await _envoyer(CommandeBrassard.demarrer()); // le firmware avait arrêté la mesure
        _reconnexion.value = false;
        return;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    _reconnexion.value = false;
    _mesureEnCours = false;
    if (!_flux.isClosed && !_ferme) {
      _flux.addError(ErreurBrassard('Liaison Bluetooth perdue : brassard introuvable pendant 30 s (éteint ou trop loin ?)'));
    }
  }

  /// Connexion, lecture des informations et abonnements. Rappelée à chaque reconnexion.
  Future<void> _connecterEtAbonner() async {
    for (final a in _abonnements) {
      await a.cancel();
    }
    _abonnements.clear();
    // License.nonprofit : projet étudiant, usage pédagogique (licence FlutterBluePlus, section 2)
    await _appareil.connect(license: License.nonprofit, mtu: null, timeout: const Duration(seconds: 15));
    connecte.value = true;

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
    _carFrequence = trouver(GattAthletix.service, GattAthletix.frequence); // firmware 1.2 et plus
    _carBatterie = trouver(GattAthletix.serviceBatterie, GattAthletix.niveauBatterie);

    // Appairage avec le code si le firmware l'exige (APPAIRAGE_SECURISE, SECURITE.md)
    await _appairerSiBesoin();

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

    // Fréquence médiane (fatigue) : seulement envoyée en source RAW, mais on s'abonne toujours
    final frequence = _carFrequence;
    if (frequence != null) {
      _abonnements.add(frequence.onValueReceived.listen((octets) {
        try {
          if (!_frequences.isClosed) _frequences.add(MesureFrequence.depuisOctets(octets));
        } on FormatException catch (e) {
          debugPrint('Paquet Fréquence ignoré : $e');
        }
      }));
      await frequence.setNotifyValue(true);
    }
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
  int get source => _config.source;

  @override
  bool get mesureFatigue => _carFrequence != null;

  @override
  Stream<MesureFrequence> get frequences => _frequences.stream;

  @override
  Future<void> choisirSource(int source) async {
    if (!mesureFatigue && source == GattAthletix.sourceRaw) {
      throw ErreurBrassard('Ce brassard ne sait pas lire le signal brut (firmware 1.2 nécessaire)');
    }
    await _envoyer(CommandeBrassard.choisirSource(source));
    await Future.delayed(const Duration(milliseconds: 200)); // le temps que loop() traite la commande
    await _lireConfiguration();
    if (_config.source != source) throw ErreurBrassard('Le brassard a refusé le changement de signal (séance en cours ?)');
  }

  @override
  Future<void> demarrer() async {
    await _envoyer(CommandeBrassard.demarrer());
    _mesureEnCours = true;
  }

  @override
  Future<void> arreter() async {
    _mesureEnCours = false;
    if (connecte.value) await _envoyer(CommandeBrassard.arreter());
  }

  /// Change les seuils d'alerte (commande 0x04), puis relit la configuration.
  @override
  Future<void> demarrerHorsLigne() async {
    if (_carHorsLigne == null) {
      throw ErreurBrassard("Ce brassard ne sait pas enregistrer sans connexion (firmware 1.1 nécessaire)");
    }
    _mesureEnCours = false; // natation : la coupure est normale, le brassard continue seul
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
      _calibreLe = DateTime.now();
      return _config.refMvcMv;
    } finally {
      await ecoute.cancel();
    }
  }

  @override
  void fermer() {
    _ferme = true;
    _mesureEnCours = false;
    _abonnementConnexion?.cancel();
    for (final a in _abonnements) {
      a.cancel();
    }
    _abonnements.clear();
    if (!_flux.isClosed) _flux.close();
    if (!_etats.isClosed) _etats.close();
    if (!_frequences.isClosed) _frequences.close();
    connecte.value = false;
    _appareil.disconnect().catchError((_) {});
  }
}
