import 'mesure_emg.dart';

/// Calcule le résumé d'une séance à partir des mesures reçues (opération O6 du MCT).
///
/// Seul ce résumé est envoyé au serveur : le signal à 50 Hz n'est jamais stocké
/// (voir architecture/MCD_MLD.md, « on ne stocke pas le signal brut »).
class ResumeSeance {
  ResumeSeance({this.refMvcMv});

  /// Référence 100 % MVC utilisée pendant la séance, en mV (facultative).
  final int? refMvcMv;

  /// Au-delà de cet écart entre deux mesures, on considère que la liaison a coupé :
  /// ce trou n'est pas compté comme du temps d'effort intense.
  static const int ecartMaxMs = 1000;

  int _nb = 0;
  int _somme = 0;
  int _max = 0;
  int _nbAlertes = 0;
  int _msEffortIntense = 0;
  int _msTotal = 0;
  MesureEmg? _precedente;

  /// Écart en ms entre deux horodatages uint32 (gère le retour à zéro après ~49 jours).
  static int _ecart(int avantMs, int apresMs) {
    var ecart = apresMs - avantMs;
    if (ecart < 0) ecart += 0x100000000;
    return ecart;
  }

  void ajouter(MesureEmg mesure) {
    // Pendant une calibration, l'intensité n'est pas encore fiable
    if (mesure.calibrationEnCours) return;

    final precedente = _precedente;
    if (precedente == null) {
      if (mesure.alerte) _nbAlertes++;
    } else {
      final ecart = _ecart(precedente.horodatageMs, mesure.horodatageMs);
      _msTotal += ecart;
      if (precedente.alerte && ecart <= ecartMaxMs) _msEffortIntense += ecart;
      // Une alerte compte quand elle s'allume (front montant), pas à chaque mesure
      if (mesure.alerte && !precedente.alerte) _nbAlertes++;
    }

    _nb++;
    _somme += mesure.intensitePct;
    if (mesure.intensitePct > _max) _max = mesure.intensitePct;
    _precedente = mesure;
  }

  int get nbEchantillons => _nb;
  int get nbAlertes => _nbAlertes;
  int get intensiteMaxPct => _max;
  int get intensiteMoyennePct => _nb == 0 ? 0 : (_somme / _nb).round();
  int get dureeS => (_msTotal / 1000).round();
  int get tempsEffortIntenseS => (_msEffortIntense / 1000).round();

  /// Champs attendus par backend/save_seance.php (voir architecture/INTEGRATION.md §2).
  Map<String, String> versApi({
    required String discipline,
    required bool simule,
    String? numeroSerie,
    String? firmware,
  }) {
    final duree = dureeS < 1 ? 1 : dureeS; // le serveur exige au moins 1 s
    return {
      'discipline': discipline,
      'duree_s': '$duree',
      'nb_echantillons': '$nbEchantillons',
      'intensite_moyenne_pct': '$intensiteMoyennePct',
      'intensite_max_pct': '$intensiteMaxPct',
      'temps_effort_intense_s': '${tempsEffortIntenseS > duree ? duree : tempsEffortIntenseS}',
      'nb_alertes': '$nbAlertes',
      'simule': simule ? '1' : '0',
      if (numeroSerie != null) 'numero_serie': numeroSerie,
      if (firmware != null) 'firmware': firmware,
      if (refMvcMv != null) 'ref_mvc_mv': '$refMvcMv',
    };
  }
}
