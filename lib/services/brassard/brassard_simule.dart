import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analyse_frequence.dart';
import 'codec_gatt.dart';
import 'gatt_athletix.dart';
import 'hors_ligne.dart';
import 'mesure_emg.dart';
import 'mesure_frequence.dart';
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

  /// Enregistrement sans connexion : même calcul que le firmware (copie Dart).
  final EnregistrementHorsLigne _horsLigne = EnregistrementHorsLigne();

  /// Accélération du temps pour la démo de natation (×60 : 1 s réelle = 1 min de nage).
  int accelerationHorsLigne = 1;

  // ---- Signal brut (source RAW) et fatigue ----
  int _source = GattAthletix.sourceEnv;
  final StreamController<MesureFrequence> _fluxFrequences = StreamController<MesureFrequence>.broadcast();
  final AnalyseFrequence _analyse = AnalyseFrequence();
  final PasseBande _filtre = PasseBande(fcRepos);
  late final HasardReproductible _bruit = HasardReproductible(_hasard.nextInt(1 << 30));
  final List<double> _fenetre = [];
  int _sommeIntensiteFenetre = 0;

  /// Fatigue simulée, de 0 (frais) à 1 : monte avec l'effort, redescend au repos.
  double fatigue = 0;

  /// Fréquence centrale du filtre pour un muscle frais (Hz) ; elle baisse jusqu'à −25 % avec la fatigue.
  /// 70 Hz donne une fréquence médiane d'environ 110 Hz (muscle frais) à 90 Hz (très fatigué),
  /// l'ordre de grandeur courant sur le biceps.
  static const double fcRepos = 70;

  /// Échantillons du signal brut à 2 000 Hz fabriqués à chaque mesure (toutes les 20 ms).
  static const int echantillonsParMesure = 40;

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

  final StreamController<EtatLu> _fluxEtats = StreamController<EtatLu>.broadcast();
  DateTime? _calibreLe;

  @override
  Stream<EtatLu> get etats => _fluxEtats.stream;

  /// Pour les tests et la démo : fait comme si le brassard envoyait un avertissement (GATT.md §7).
  void simulerAvertissement(int code) {
    if (!_fluxEtats.isClosed) _fluxEtats.add(EtatLu(_minuteur != null ? EtatBrassard.mesure : EtatBrassard.repos, code));
  }

  /// Le brassard simulé ne perd jamais la liaison.
  @override
  ValueListenable<bool> get reconnexion => const _Toujours(false);

  @override
  DateTime? get calibreLe => _calibreLe;

  @override
  int get source => _source;

  @override
  bool get mesureFatigue => true;

  @override
  Stream<MesureFrequence> get frequences => _fluxFrequences.stream;

  @override
  Future<void> choisirSource(int source) async {
    final commande = CommandeBrassard.choisirSource(source); // mêmes contrôles que le vrai brassard
    if (_minuteur != null) throw ErreurBrassard('Arrête la séance avant de changer de signal');
    if (source == _source) return;
    _source = commande[1];
    // Comme le firmware : la référence change d'échelle, il faut recalibrer
    _refMvcMv = _source == GattAthletix.sourceRaw ? 500 : GattAthletix.refMvcDefautMv;
    _fenetre.clear();
    _sommeIntensiteFenetre = 0;
  }

  /// Effort demandé (en % MVC) à l'instant [tempsS] du cycle.
  static double effortVise(double tempsS) {
    final t = tempsS % dureeCycleS;
    for (final phase in _profil) {
      if (t < phase.finS) return phase.pct;
    }
    return 0;
  }

  /// Profil de natation (temps simulé, en s) : longueurs à 45 %, virages à 15 %,
  /// un sprint à 85 % toutes les 5 min. Jamais au repos, sinon l'arrêt automatique se déclencherait.
  static double effortNage(double tempsS) {
    final t = tempsS % 300;
    if (t >= 240 && t < 270) return 85;
    return (t % 40) < 34 ? 45 : 15;
  }

  @override
  Future<void> demarrer() async {
    if (_minuteur != null || _flux.isClosed) return;
    _chrono.start();
    _minuteur = Timer.periodic(periode, (_) => _envoyerMesure());
  }

  @override
  Future<void> demarrerHorsLigne() async {
    _horsLigne.demarrer(_tempsHorsLigneMs);
    await demarrer();
  }

  @override
  Future<ResumeHorsLigne> lireHorsLigne() async =>
      ResumeHorsLigne.depuisOctets(_horsLigne.encoder(_tempsHorsLigneMs));

  @override
  Future<void> effacerHorsLigne() async => _horsLigne.effacer();

  int get _tempsHorsLigneMs => _chrono.elapsedMilliseconds * accelerationHorsLigne;

  @override
  Future<void> arreter() async {
    _horsLigne.terminer(_tempsHorsLigneMs);
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
    final base = _source == GattAthletix.sourceRaw ? 500 : GattAthletix.refMvcDefautMv;
    _refMvcMv = (base * (0.95 + _hasard.nextDouble() * 0.10)).round();
    _calibreLe = DateTime.now();
    return _refMvcMv;
  }

  @override
  void fermer() {
    arreter();
    _flux.close();
    _fluxFrequences.close();
    _fluxEtats.close();
  }

  /// Fabrique 20 ms de signal brut (bruit filtré dont l'amplitude suit l'intensité et dont le spectre
  /// glisse avec la fatigue), puis, toutes les 1 024 valeurs, calcule la fréquence médiane avec le
  /// MÊME calcul que le firmware et l'envoie en paquet de 8 octets relu par le vrai décodeur.
  void _signalBrut(int intensite, int ms) {
    const dt = 0.02;
    final charge = intensite / 100;
    // Démo : fatigue rapide (quelques % de fréquence médiane en 1 min d'efforts répétés), récupération lente
    fatigue = (fatigue + dt * (charge * charge / 60 - fatigue / 300)).clamp(0.0, 1.0);
    _filtre.regler(fcRepos * (1 - 0.25 * fatigue));
    for (var i = 0; i < echantillonsParMesure; i++) {
      _fenetre.add((2 + intensite * 8) * _filtre.filtrer(_bruit.gauss()));
    }
    _sommeIntensiteFenetre += intensite * echantillonsParMesure;
    if (_fenetre.length < _analyse.n) return;
    final x = _fenetre.sublist(0, _analyse.n);
    _fenetre.removeRange(0, _analyse.n);
    final moyenne = _sommeIntensiteFenetre / _analyse.n;
    _sommeIntensiteFenetre = 0;
    final r = _analyse.analyser(x);
    final travail = r.valide && moyenne >= 20; // même seuil que le firmware
    final paquet = MesureFrequence(horodatageMs: ms, mdfHz: travail ? r.mdfHz : 0, mnfHz: travail ? r.mnfHz : 0).versOctets();
    if (!_fluxFrequences.isClosed) _fluxFrequences.add(MesureFrequence.depuisOctets(paquet));
  }

  void _envoyerMesure() {
    final ms = _chrono.elapsedMilliseconds;

    // Le muscle ne passe pas d'un effort à l'autre instantanément : lissage (≈ 0,15 s)
    final effort = _horsLigne.etat == ResumeHorsLigne.enCours ? effortNage(_tempsHorsLigneMs / 1000) : effortVise(ms / 1000);
    _intensiteLissee += (effort - _intensiteLissee) * 0.15;
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

    if (_source == GattAthletix.sourceRaw && !_calibration) _signalBrut(intensite, ms);

    // Même chemin que le Bluetooth : octets → décodeur
    for (final mesure in MesureEmg.depuisNotification(paquet)) {
      _flux.add(mesure);
      if (_horsLigne.etat == ResumeHorsLigne.enCours) {
        // Avec l'accélération, chaque mesure représente plusieurs mesures réelles (même valeur)
        final t = _tempsHorsLigneMs;
        final pas = periode.inMilliseconds;
        for (var k = accelerationHorsLigne - 1; k >= 0; k--) {
          _horsLigne.ajouter(t - k * pas, mesure.intensitePct, mesure.alerte);
        }
      }
    }
  }
}

/// Valeur fixe qui ne change jamais (ValueListenable sans notification).
class _Toujours<T> implements ValueListenable<T> {
  const _Toujours(this.value);
  @override
  final T value;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
