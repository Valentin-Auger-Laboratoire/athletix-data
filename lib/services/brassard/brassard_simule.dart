import 'dart:async';
import 'dart:math';

import 'codec_gatt.dart';
import 'gatt_athletix.dart';
import 'mesure_emg.dart';
import 'source_brassard.dart';

/// Une phase du profil d'effort simulé : jusqu'à [finS] secondes, effort de [pct] % MVC.
class _Phase {
  final double finS;
  final double pct;
  const _Phase(this.finS, this.pct);
}

/// Brassard simulé : produit des mesures 50 fois par seconde, sans matériel.
///
/// Important : chaque mesure est encodée en 8 octets EXACTEMENT comme le ferait le
/// vrai brassard (architecture/GATT.md §4), puis relue avec le vrai décodeur.
/// L'écran de séance utilise donc le même chemin que pour le Bluetooth réel.
///
/// Le profil d'effort reprend celui de la simulation Simulink
/// (repos, 40 %, 95 %, 50 %, repos), en boucle toutes les 18 s.
class BrassardSimule implements SourceBrassard {
  BrassardSimule({Random? hasard}) : _hasard = hasard ?? Random();

  static const List<_Phase> _profil = [
    _Phase(3, 0),
    _Phase(7, 40),
    _Phase(10, 95),
    _Phase(15, 50),
    _Phase(18, 0),
  ];
  static const double dureeCycleS = 18;
  static const Duration periode = Duration(milliseconds: 1000 ~/ GattAthletix.frequenceDefautHz);

  final Random _hasard;
  final StreamController<MesureEmg> _flux = StreamController<MesureEmg>.broadcast();
  final Stopwatch _chrono = Stopwatch();
  Timer? _minuteur;
  double _intensiteLissee = 0;
  bool _alerte = false;
  int _refMvcMv = GattAthletix.refMvcDefautMv;
  int _seuilHaut = GattAthletix.seuilHautDefaut;
  int _seuilBas = GattAthletix.seuilBasDefaut;
  bool _calibration = false;

  /// Durée de la calibration (commande 0x03), comme le vrai brassard.
  static const Duration dureeCalibration = Duration(seconds: 3);

  @override
  String get nom => 'Brassard simulé';

  @override
  bool get simule => true;

  @override
  String? get numeroSerie => null;

  @override
  String? get firmware => null;

  @override
  int get refMvcMv => _refMvcMv;

  @override
  int get seuilHaut => _seuilHaut;

  @override
  int get seuilBas => _seuilBas;

  @override
  Future<void> reglerSeuils(int seuilHaut, int seuilBas) async {
    CommandeBrassard.reglerSeuil(seuilHaut, seuilBas); // mêmes contrôles que le vrai brassard
    _seuilHaut = seuilHaut;
    _seuilBas = seuilBas;
  }

  /// Un brassard simulé n'a pas de batterie.
  @override
  int? get batteriePct => null;

  @override
  Stream<MesureEmg> get mesures => _flux.stream;

  /// Effort demandé (en % MVC) à l'instant [tempsS] du cycle.
  static double effortVise(double tempsS) {
    final t = tempsS % dureeCycleS;
    for (final phase in _profil) {
      if (t < phase.finS) return phase.pct;
    }
    return 0;
  }

  @override
  Future<void> demarrer() async {
    if (_minuteur != null || _flux.isClosed) return;
    _chrono.start();
    _minuteur = Timer.periodic(periode, (_) => _envoyerMesure());
  }

  @override
  Future<void> arreter() async {
    _minuteur?.cancel();
    _minuteur = null;
    _chrono.stop();
  }

  /// Simule une contraction maximale de 3 s : la nouvelle référence varie de ± 5 %
  /// autour de 1 850 mV (valeur supposée dans la simulation Simulink).
  @override
  Future<int> calibrer({Duration? duree}) async {
    _calibration = true;
    await Future.delayed(duree ?? dureeCalibration);
    _calibration = false;
    _refMvcMv = (GattAthletix.refMvcDefautMv * (0.95 + _hasard.nextDouble() * 0.10)).round();
    return _refMvcMv;
  }

  @override
  void fermer() {
    arreter();
    _flux.close();
  }

  void _envoyerMesure() {
    final ms = _chrono.elapsedMilliseconds;

    // Le muscle ne passe pas d'un effort à l'autre instantanément : lissage (≈ 0,15 s)
    _intensiteLissee += (effortVise(ms / 1000) - _intensiteLissee) * 0.15;
    final bruit = (_hasard.nextDouble() * 2 - 1) * 3; // ± 3 %
    final intensite = max(0, (_intensiteLissee + bruit).round());

    // Alerte avec hystérésis : s'allume au seuil haut, s'éteint sous le seuil bas
    if (!_alerte && intensite >= _seuilHaut) _alerte = true;
    if (_alerte && intensite < _seuilBas) _alerte = false;

    final rms = (intensite * refMvcMv / 100).round();
    final paquet = MesureEmg(
      horodatageMs: ms,
      rmsMv: rms,
      intensitePct: intensite,
      alerte: _alerte,
      saturation: rms >= 3300,
      calibrationEnCours: _calibration,
    ).versOctets();

    // Même chemin que le Bluetooth : octets → décodeur
    for (final mesure in MesureEmg.depuisNotification(paquet)) {
      _flux.add(mesure);
    }
  }
}
