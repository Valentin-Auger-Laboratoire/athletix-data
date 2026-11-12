import 'dart:convert';

import 'api.dart';
import 'demo_seances.dart';

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

  /// Séances de la démo (en mémoire seulement), au format de get_seances.php :
  /// six semaines FICTIVES faites avec le brassard simulé (voir demo_seances.dart).
  final List<Map<String, dynamic>> _seances = seancesDemo();
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
    final id = _seances.fold<int>(0, (m, s) => (s['id'] as int) > m ? s['id'] as int : m) + 1;
    final duree = int.tryParse(seance['duree_s'] ?? '') ?? 0;
    final ilYa = int.tryParse(seance['fin_il_y_a_s'] ?? '') ?? 0;
    final fin = DateTime.now().subtract(Duration(seconds: ilYa));
    String date(DateTime d) => d.toString().substring(0, 19);
    int? entier(String c) => int.tryParse(seance[c] ?? '');
    double? decimal(String c) => double.tryParse((seance[c] ?? '').replaceAll(',', '.'));
    String? texte(String c) => (seance[c] ?? '').trim().isEmpty ? null : seance[c]!.trim();
    // Renvoi de la même séance : pas de doublon (comme le serveur)
    final uuid = seance['client_uuid'];
    if (uuid != null) {
      for (final s in _seances) {
        if (s['client_uuid'] == uuid) {
          return _later({"status": "success", "session_id": s['id'], "deja_enregistree": true});
        }
      }
    }
    List<dynamic>? trace;
    try {
      if (seance['trace'] != null) trace = jsonDecode(seance['trace']!) as List;
    } catch (_) {}
    List<int>? courbe;
    try {
      final brute = seance['courbe'];
      if (brute != null && brute.length > 2) {
        courbe = brute.substring(1, brute.length - 1).split(',').map((v) => int.parse(v.trim())).toList();
      }
    } catch (_) {}
    _seances.add({
      'id': id,
      'discipline': seance['discipline'] ?? '',
      'debut': date(fin.subtract(Duration(seconds: duree))),
      'fin': date(fin),
      'donnees_simulees': seance['simule'] == '1',
      'duree_s': duree,
      'intensite_moyenne_pct': entier('intensite_moyenne_pct') ?? 0,
      'intensite_max_pct': entier('intensite_max_pct') ?? 0,
      'temps_effort_intense_s': entier('temps_effort_intense_s') ?? 0,
      'nb_alertes': entier('nb_alertes') ?? 0,
      'ref_mvc_mv': entier('ref_mvc_mv'),
      for (final c in const [
        'temps_zone_repos_s', 'temps_zone_moderee_s', 'temps_zone_soutenue_s', 'nb_contractions',
        'indice_fatigue_pct', 'distance_m', 'denivele_m', 'nb_pas', 'fc_moy', 'fc_max', 'humidite_pct',
        'meteo_code', 'ressenti_fatigue', 'douleur',
      ])
        c: entier(c),
      'vitesse_moy_kmh': decimal('vitesse_moy_kmh'),
      'temperature_c': decimal('temperature_c'),
      'sommeil': texte('sommeil'),
      'commentaire': texte('commentaire'),
      'mode_adapte': seance['mode_adapte'] == '1',
      'courbe': courbe,
      'nb_series': entier('nb_series'),
      'trace': trace,
      'client_uuid': seance['client_uuid'],
    });
    _seances.sort((a, b) => (b['debut'] as String).compareTo(a['debut'] as String));
    return _later({
      "status": "success",
      "message": "Séance enregistrée (démo, en mémoire)",
      "session_id": id,
    });
  }

  /// Comme le serveur : la liste ne contient pas le tracé, le détail (getSeance) oui.
  @override
  Future<Map<String, dynamic>> getSeances({int limite = 100}) => _later({
        "status": "success",
        "seances": [for (final s in _seances.take(limite.clamp(1, 500))) {...s, 'trace': null}],
      });

  @override
  Future<Map<String, dynamic>> getSeance(int id) => _later({
        "status": "success",
        "seances": [for (final s in _seances) if (s['id'] == id) Map<String, dynamic>.from(s)],
      });

  @override
  Future<Map<String, dynamic>> exporterDonnees() => _later({
        "status": "success",
        "exporte_le": DateTime.now().toIso8601String(),
        "compte": {"pseudo": "Athlète démo", "email": "demo@exemple.com", "sport": "Running"},
        "profils": _profils,
        "calibrations": _calibrations,
        "seances": _seances,
      });

  @override
  Future<Map<String, dynamic>> supprimerCompte(String motDePasse) => _later(_horsDemo);

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
