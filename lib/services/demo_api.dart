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

  /// Séances enregistrées pendant la démo (en mémoire seulement).
  final List<Map<String, String>> _seances = [];

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
    _seances.add(seance);
    return _later({
      "status": "success",
      "message": "Séance enregistrée (démo, en mémoire)",
      "session_id": _seances.length,
    });
  }

  @override
  Future<Map<String, dynamic>> getHardware() =>
      _later({"status": "success", "connected": false, "battery": null, "last_sync": null});

  @override
  Future<List<dynamic>> getClassement() => _later([
        {'pseudo': 'Léa_Trail', 'sport': 'Endurance & Cardio', 'score': 1840},
        {'pseudo': 'MaxPower', 'sport': 'Force & Intensité', 'score': 1625},
        {'pseudo': 'Athlète démo', 'sport': 'Endurance & Cardio', 'score': 1310},
        {'pseudo': 'Nageur42', 'sport': 'Milieu Aquatique', 'score': 990},
        {'pseudo': 'ZenYogi', 'sport': 'Zen & Posture', 'score': 760},
      ]);
}
