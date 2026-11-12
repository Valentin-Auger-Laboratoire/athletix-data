import 'dart:math';

import '../brassard/mesure_emg.dart';

/// Analyse détaillée d'une séance à partir des mesures du brassard (en plus de ResumeSeance) :
/// zones d'intensité, contractions, courbe résumée et indice de fatigue.
///
/// Zones (en % de la contraction maximale) :
/// repos < 20 %, modérée 20–50 %, soutenue 50–75 %, intense ≥ 75 % (déjà compté par ResumeSeance).
class AnalyseSeance {
  AnalyseSeance({this.pasCourbeMs = 5000, this.seuilContractionHaut = 30, this.seuilContractionBas = 20});

  /// Une valeur de la courbe résumée toutes les [pasCourbeMs] (5 s : ≤ 2 000 points pour 2 h 45).
  final int pasCourbeMs;

  /// Une contraction = l'intensité passe au-dessus du seuil haut puis redescend sous le seuil bas.
  final int seuilContractionHaut;
  final int seuilContractionBas;

  static const int ecartMaxMs = 1000;

  int _msRepos = 0, _msModeree = 0, _msSoutenue = 0, _msIntense = 0;
  int _contractions = 0;
  bool _enContraction = false;
  MesureEmg? _precedente;

  final List<int> _courbe = [];

  /// Repos minimal entre deux séries (musculation).
  static const int reposEntreSeriesMs = 20000;
  int _series = 0, _finContractionMs = 0;

  /// Séries : groupes de contractions séparés d'au moins 20 s de repos.
  int get nbSeries => _series;
  int _sommeBloc = 0, _nbBloc = 0, _debutBlocMs = 0, _tempsMs = 0;

  /// Moyennes de chaque minute, pour l'indice de fatigue.
  final List<double> _minutes = [];
  int _sommeMinute = 0, _nbMinute = 0, _debutMinuteMs = 0;

  void ajouter(MesureEmg m) {
    if (m.calibrationEnCours) return;
    final p = _precedente;
    if (p != null) {
      var ecart = m.horodatageMs - p.horodatageMs;
      if (ecart < 0) ecart += 0x100000000;
      if (ecart <= ecartMaxMs) {
        _tempsMs += ecart;
        final i = p.intensitePct;
        if (i < 20) {
          _msRepos += ecart;
        } else if (i < 50) {
          _msModeree += ecart;
        } else if (i < 75) {
          _msSoutenue += ecart;
        } else {
          _msIntense += ecart;
        }
      }
    }
    _precedente = m;

    // Contractions (hystérésis, comme l'alerte du brassard)
    if (!_enContraction && m.intensitePct >= seuilContractionHaut) {
      _enContraction = true;
      // Nouvelle série si le muscle s'est reposé assez longtemps depuis la contraction précédente
      if (_contractions == 0 || _tempsMs - _finContractionMs >= reposEntreSeriesMs) _series++;
      _contractions++;
    } else if (_enContraction && m.intensitePct < seuilContractionBas) {
      _enContraction = false;
      _finContractionMs = _tempsMs;
    }

    // Courbe résumée : moyenne de chaque bloc de 5 s
    _sommeBloc += m.intensitePct;
    _nbBloc++;
    if (_tempsMs - _debutBlocMs >= pasCourbeMs) {
      _courbe.add((_sommeBloc / _nbBloc).round().clamp(0, 255).toInt());
      _sommeBloc = 0;
      _nbBloc = 0;
      _debutBlocMs = _tempsMs;
    }

    _sommeMinute += m.intensitePct;
    _nbMinute++;
    if (_tempsMs - _debutMinuteMs >= 60000) {
      _minutes.add(_sommeMinute / _nbMinute);
      _sommeMinute = 0;
      _nbMinute = 0;
      _debutMinuteMs = _tempsMs;
    }
  }

  int get tempsReposS => (_msRepos / 1000).round();
  int get tempsModereeS => (_msModeree / 1000).round();
  int get tempsSoutenueS => (_msSoutenue / 1000).round();
  int get tempsIntenseS => (_msIntense / 1000).round();
  int get nbContractions => _contractions;

  /// Courbe résumée, avec le dernier bloc incomplet.
  List<int> get courbe => [
        ..._courbe,
        if (_nbBloc > 0) (_sommeBloc / _nbBloc).round().clamp(0, 255).toInt(),
      ];

  /// Indice de fatigue EXPÉRIMENTAL, en % : évolution de l'intensité moyenne entre le premier
  /// et le dernier tiers des minutes actives (≥ 20 %). Pour un même effort, un muscle qui
  /// fatigue doit recruter plus de fibres : l'amplitude de l'EMG monte. Une valeur positive
  /// peut donc signaler de la fatigue, mais elle dépend aussi de l'exercice choisi.
  /// La vraie mesure (baisse de la fréquence médiane) demande le signal RAW du capteur.
  /// Null si la séance a moins de 3 minutes actives.
  int? get indiceFatiguePct {
    final actives = _minutes.where((v) => v >= 20).toList();
    if (actives.length < 3) return null;
    final tiers = max(1, actives.length ~/ 3);
    final debut = actives.take(tiers).reduce((a, b) => a + b) / tiers;
    final fin = actives.skip(actives.length - tiers).reduce((a, b) => a + b) / tiers;
    if (debut <= 0) return null;
    return ((fin - debut) / debut * 100).round().clamp(-100, 1000).toInt();
  }

  /// Champs facultatifs de save_seance.php (migration 003).
  Map<String, String> versApi() {
    final indice = indiceFatiguePct;
    final c = courbe;
    return {
      'temps_zone_repos_s': '$tempsReposS',
      'temps_zone_moderee_s': '$tempsModereeS',
      'temps_zone_soutenue_s': '$tempsSoutenueS',
      'nb_contractions': '$nbContractions',
      'nb_series': '$nbSeries',
      if (indice != null) 'indice_fatigue_pct': '$indice',
      if (c.isNotEmpty) 'courbe': '[${c.take(2000).join(',')}]',
    };
  }
}
