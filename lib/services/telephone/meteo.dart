import 'dart:convert';

import 'package:http/http.dart' as http;

/// Météo au moment de la séance, à partir de la position du téléphone.
///
/// Service Open-Meteo (open-meteo.com) : gratuit, sans compte ni clé, données sous licence
/// CC BY 4.0. Seules la latitude et la longitude arrondies (≈ 1 km) sont envoyées.
class Meteo {
  const Meteo({required this.temperatureC, required this.humiditePct, required this.code});

  final double temperatureC;
  final int humiditePct;

  /// Code météo WMO (0 = ciel clair, 61 = pluie…).
  final int code;

  /// Au-delà, la chaleur peut aggraver les symptômes de la sclérose en plaques (phénomène d'Uhthoff).
  static const double seuilChaleurC = 25;

  bool get chaud => temperatureC >= seuilChaleurC;

  static Future<Meteo?> actuelle(double latitude, double longitude) async {
    final lat = latitude.toStringAsFixed(2), lon = longitude.toStringAsFixed(2);
    try {
      final r = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&current=temperature_2m,relative_humidity_2m,weather_code'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return depuisJson(json.decode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Meteo? depuisJson(Map<String, dynamic> data) {
    final c = data['current'];
    if (c is! Map) return null;
    final t = c['temperature_2m'], h = c['relative_humidity_2m'], w = c['weather_code'];
    if (t is! num || h is! num || w is! num) return null;
    return Meteo(temperatureC: t.toDouble(), humiditePct: h.round(), code: w.round());
  }

  /// Libellé court d'un code WMO.
  static String libelle(int code) {
    if (code == 0) return 'ciel clair';
    if (code <= 3) return 'nuageux';
    if (code <= 48) return 'brouillard';
    if (code <= 57) return 'bruine';
    if (code <= 67) return 'pluie';
    if (code <= 77) return 'neige';
    if (code <= 82) return 'averses';
    if (code <= 86) return 'averses de neige';
    return 'orage';
  }

  Map<String, String> versApi() => {
        'temperature_c': temperatureC.toStringAsFixed(1),
        'humidite_pct': '$humiditePct',
        'meteo_code': '$code',
      };
}
