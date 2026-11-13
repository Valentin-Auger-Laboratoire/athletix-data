import 'dart:math';

import 'mesure_frequence.dart';

/// Suivi de la fatigue musculaire pendant une séance, à partir de la fréquence médiane (MDF)
/// envoyée par le brassard en source RAW (voir hardware/firmware-brassard/FATIGUE.md).
///
/// Principe : on ajuste une droite MDF = a + b·t sur les valeurs valides (muscle au travail).
/// La baisse entre le début et la fin, en %, est l'indicateur de fatigue. Une droite plutôt que
/// « première valeur / dernière valeur » : la MDF varie d'une fenêtre à l'autre, la droite lisse ce bruit.
class SuiviFatigue {
  final List<double> _t = []; // s depuis le début de la séance
  final List<double> _mdf = [];
  int? _origineMs;
  int? _precedentMs;
  double _decalageS = 0; // horodatage uint32 qui repasse à zéro

  /// Au moins 20 valeurs (10 s de travail) étalées sur 60 s pour donner un résultat.
  static const int minimumValeurs = 20;
  static const double minimumDureeS = 60;

  /// Pas de la courbe enregistrée (moyenne par bloc).
  static const int pasCourbeS = 30;

  void ajouter(MesureFrequence m) {
    final origine = _origineMs ??= m.horodatageMs;
    final precedent = _precedentMs;
    if (precedent != null && m.horodatageMs < precedent) _decalageS += 0x100000000 / 1000;
    _precedentMs = m.horodatageMs;
    if (!m.valide) return;
    _t.add((m.horodatageMs - origine) / 1000 + _decalageS);
    _mdf.add(m.mdfHz);
  }

  int get nbValeurs => _mdf.length;

  /// MDF actuelle : moyenne des 6 dernières valeurs valides (3 s), ou null.
  double? get mdfActuelle {
    if (_mdf.isEmpty) return null;
    final n = min(6, _mdf.length);
    return _mdf.sublist(_mdf.length - n).reduce((a, b) => a + b) / n;
  }

  /// MDF de référence : moyenne des 10 premières valeurs valides (début de séance, muscle frais).
  double? get mdfReference {
    if (_mdf.length < 10) return null;
    return _mdf.sublist(0, 10).reduce((a, b) => a + b) / 10;
  }

  /// Écart de la MDF actuelle à la référence, en % (négatif = baisse = fatigue).
  double? get ecartPct {
    final r = mdfReference, a = mdfActuelle;
    if (r == null || a == null || r == 0) return null;
    return (a - r) / r * 100;
  }

  /// Résultat de la séance, ou null s'il n'y a pas assez de valeurs.
  ResultatFatigue? resultat() {
    if (_mdf.length < minimumValeurs) return null;
    final duree = _t.last - _t.first;
    if (duree < minimumDureeS) return null;
    final n = _mdf.length;
    final mt = _t.reduce((a, b) => a + b) / n, mm = _mdf.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (_t[i] - mt) * (_mdf[i] - mm);
      sxx += (_t[i] - mt) * (_t[i] - mt);
    }
    final b = sxx == 0 ? 0.0 : sxy / sxx, a = mm - b * mt;
    final debut = a + b * _t.first, fin = a + b * _t.last;
    // Courbe : moyenne des valeurs valides par bloc de 30 s (0 = bloc sans travail)
    final nbBlocs = (_t.last / pasCourbeS).floor() + 1;
    final sommes = List<double>.filled(nbBlocs, 0), nombres = List<int>.filled(nbBlocs, 0);
    for (var i = 0; i < n; i++) {
      final k = (_t[i] / pasCourbeS).floor();
      sommes[k] += _mdf[i];
      nombres[k]++;
    }
    final courbe = [for (var k = 0; k < nbBlocs; k++) nombres[k] == 0 ? 0.0 : sommes[k] / nombres[k]];
    return ResultatFatigue(
      mdfDebutHz: debut,
      mdfFinHz: fin,
      baissePct: debut <= 0 ? 0 : (debut - fin) / debut * 100,
      penteHzParMin: b * 60,
      nbValeurs: n,
      courbe: courbe.length > 200 ? courbe.sublist(0, 200) : courbe,
    );
  }
}

class ResultatFatigue {
  const ResultatFatigue({
    required this.mdfDebutHz,
    required this.mdfFinHz,
    required this.baissePct,
    required this.penteHzParMin,
    required this.nbValeurs,
    required this.courbe,
  });

  final double mdfDebutHz;
  final double mdfFinHz;

  /// Baisse de la MDF entre le début et la fin de la séance, en % (positive = fatigue).
  final double baissePct;
  final double penteHzParMin;
  final int nbValeurs;

  /// MDF moyenne par bloc de 30 s (0 = bloc sans travail).
  final List<double> courbe;

  /// Repères usuels en EMG de surface : une baisse de 10 à 30 % accompagne un effort qui fatigue.
  /// Ce sont des repères pour un prototype, pas des seuils médicaux.
  static String interpretation(double baissePct) {
    if (baissePct >= 10) return 'fatigue nette du muscle';
    if (baissePct >= 5) return 'début de fatigue';
    if (baissePct > -5) return 'pas de fatigue mesurable';
    return 'fréquence en hausse (muscle qui se réchauffe, ou effort différent)';
  }

  /// Champs ajoutés à l'envoi au serveur (save_seance.php, migration 005).
  Map<String, String> versApi() => {
        'mdf_debut_hz': mdfDebutHz.toStringAsFixed(1),
        'mdf_fin_hz': mdfFinHz.toStringAsFixed(1),
        'baisse_mdf_pct': baissePct.toStringAsFixed(1),
        'courbe_mdf': '[${courbe.map((v) => v.toStringAsFixed(1)).join(',')}]',
      };
}
