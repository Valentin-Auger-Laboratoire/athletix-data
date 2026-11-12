import 'api.dart';

/// Mode démo : aucune requête réseau, toutes les données sont FICTIVES et vivent en mémoire.
/// Elles disparaissent quand on quitte la démo ou qu'on recharge la page.
class DemoApi implements AthletixApi {
  final List<Map<String, dynamic>> _profils = [
    {
      'objectif_principal': 'Endurance',
      'niveau_sportif': 'Intermédiaire',
      'poids': '70',
      'taille': '178',
      'frequence': '3',
      'pathologies_blessures': 'Genou',
      'antecedents_cardio_perso': '0',
      'antecedents_cardio_famille': '0',
      'qualite_sommeil': 'Moyenne',
      'niveau_stress': '7',
      'created_at': '2026-05-12 18:30:00',
    },
    {
      'objectif_principal': 'Santé',
      'niveau_sportif': 'Débutant',
      'poids': '73',
      'taille': '178',
      'frequence': '2',
      'pathologies_blessures': 'Aucune',
      'antecedents_cardio_perso': '0',
      'antecedents_cardio_famille': '0',
      'qualite_sommeil': 'Bonne',
      'niveau_stress': '4',
      'created_at': '2026-04-20 09:15:00',
    },
  ];

  /// Séances de la démo (en mémoire seulement), au format de get_seances.php.
  /// Deux séances d'exemple FICTIVES, faites avec le brassard simulé.
  final List<Map<String, dynamic>> _seances = [
    {
      'id': 2, 'discipline': 'Musculation', 'debut': '2026-11-10 18:05:00', 'fin': '2026-11-10 18:35:00',
      'donnees_simulees': true, 'duree_s': 1800, 'intensite_moyenne_pct': 46, 'intensite_max_pct': 104,
      'temps_effort_intense_s': 240, 'nb_alertes': 6, 'ref_mvc_mv': 1850,
    },
    {
      'id': 1, 'discipline': 'Running', 'debut': '2026-11-08 09:30:00', 'fin': '2026-11-08 10:10:00',
      'donnees_simulees': true, 'duree_s': 2400, 'intensite_moyenne_pct': 31, 'intensite_max_pct': 78,
      'temps_effort_intense_s': 35, 'nb_alertes': 1, 'ref_mvc_mv': 1850,
    },
  ];
  final List<Map<String, String>> _calibrations = [];

  Future<T> _later<T>(T value) => Future.delayed(const Duration(milliseconds: 300), () => value);

  Map<String, dynamic> get _horsDemo =>
      {"status": "error", "message": "Indisponible en mode démo"};

  @override
  Future<Map<String, dynamic>> register(String pseudo, String email, String password, String sport) =>
      _later(_horsDemo);

  @override
  Future<Map<String, dynamic>> verifyCode(String email, String code) => _later(_horsDemo);

  @override
  Future<Map<String, dynamic>> resendCode(String email) => _later(_horsDemo);

  @override
  Future<Map<String, dynamic>> login(String email, String password) => _later(_horsDemo);

  @override
  Future<void> logout() async {}

  @override
  Future<Map<String, dynamic>> getProfil() => _later({
        "status": "success",
        "profil": _profils.first,
        "historique": _profils
            .map((p) => {
                  'objectif_principal': p['objectif_principal'],
                  'niveau_sportif': p['niveau_sportif'],
                  'poids': p['poids'],
                  'created_at': p['created_at'],
                })
            .toList(),
      });

  @override
  Future<Map<String, dynamic>> saveProfil(Map<String, String> profil) {
    _profils.insert(0, {...profil, 'created_at': DateTime.now().toString().substring(0, 19)});
    return _later({"status": "success", "message": "Profil enregistré (démo, en mémoire)"});
  }

  @override
  Future<Map<String, dynamic>> saveSeance(Map<String, String> seance) {
    final id = _seances.length + 1;
    final duree = int.tryParse(seance['duree_s'] ?? '') ?? 0;
    final fin = DateTime.now();
    String date(DateTime d) => d.toString().substring(0, 19);
    _seances.insert(0, {
      'id': id,
      'discipline': seance['discipline'] ?? '',
      'debut': date(fin.subtract(Duration(seconds: duree))),
      'fin': date(fin),
      'donnees_simulees': seance['simule'] == '1',
      'duree_s': duree,
      'intensite_moyenne_pct': int.tryParse(seance['intensite_moyenne_pct'] ?? '') ?? 0,
      'intensite_max_pct': int.tryParse(seance['intensite_max_pct'] ?? '') ?? 0,
      'temps_effort_intense_s': int.tryParse(seance['temps_effort_intense_s'] ?? '') ?? 0,
      'nb_alertes': int.tryParse(seance['nb_alertes'] ?? '') ?? 0,
      'ref_mvc_mv': int.tryParse(seance['ref_mvc_mv'] ?? ''),
    });
    return _later({
      "status": "success",
      "message": "Séance enregistrée (démo, en mémoire)",
      "session_id": id,
    });
  }

  @override
  Future<Map<String, dynamic>> getSeances() =>
      _later({"status": "success", "seances": List<Map<String, dynamic>>.from(_seances)});

  @override
  Future<Map<String, dynamic>> saveCalibration(Map<String, String> calibration) {
    _calibrations.add(calibration);
    return _later({"status": "success", "message": "Calibration enregistrée (démo, en mémoire)"});
  }

  @override
  Future<Map<String, dynamic>> getHardware() =>
      _later({"status": "success", "connected": false, "battery": null, "last_sync": null});

  @override
  Future<List<dynamic>> getClassement() => _later([
        {'pseudo': 'Léa_Trail', 'sport': 'Endurance & Cardio', 'score': 1840, 'nb_seances': 30},
        {'pseudo': 'MaxPower', 'sport': 'Force & Intensité', 'score': 1625, 'nb_seances': 27},
        {'pseudo': 'Nageur42', 'sport': 'Milieu Aquatique', 'score': 990, 'nb_seances': 16},
        {'pseudo': 'ZenYogi', 'sport': 'Zen & Posture', 'score': 760, 'nb_seances': 12},
      ]);
}
