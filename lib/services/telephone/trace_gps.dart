import 'dart:convert';
import 'dart:math';

/// Un point GPS (degrés, mètres, ms).
class PointGps {
  const PointGps(this.latitude, this.longitude,
      {this.altitude, this.precisionM = 10, required this.tempsMs, this.intensite});

  final double latitude;
  final double longitude;
  final double? altitude;
  final double precisionM;
  final int tempsMs;

  /// Intensité musculaire (% MVC) au moment du point, pour colorer le tracé.
  final int? intensite;
}

/// Calculs sur un parcours GPS : distance, dénivelé positif, vitesse. Sans dépendance au GPS
/// lui-même (testé avec des parcours inventés).
class TraceGps {
  TraceGps({this.precisionMaxM = 30, this.seuilDeniveleM = 3});

  /// Les points moins précis que ça (en m) sont ignorés : en intérieur, le GPS « saute ».
  final double precisionMaxM;

  /// Le dénivelé ne compte une montée qu'au-delà de ce seuil, pour ne pas additionner le bruit
  /// de l'altitude GPS (qui varie de quelques mètres même à l'arrêt).
  final double seuilDeniveleM;

  final List<PointGps> points = [];
  double distanceM = 0;
  double deniveleM = 0;
  double? _altitudeReference;

  static const double rayonTerreM = 6371000;

  /// Distance en mètres entre deux points (formule de haversine).
  static double distance(PointGps a, PointGps b) {
    double rad(double d) => d * pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h = pow(sin(dLat / 2), 2) + cos(rad(a.latitude)) * cos(rad(b.latitude)) * pow(sin(dLon / 2), 2);
    return 2 * rayonTerreM * asin(sqrt(h));
  }

  void ajouter(PointGps p) {
    if (p.precisionM > precisionMaxM) return;
    if (points.isNotEmpty) {
      final d = distance(points.last, p);
      final dt = (p.tempsMs - points.last.tempsMs) / 1000;
      // Saut impossible (> 15 m/s ≈ 54 km/h à pied ou à vélo) : point aberrant ignoré
      if (dt > 0 && d / dt > 15) return;
      distanceM += d;
    }
    final alt = p.altitude;
    if (alt != null) {
      final ref = _altitudeReference;
      if (ref == null) {
        _altitudeReference = alt;
      } else if (alt - ref >= seuilDeniveleM) {
        deniveleM += alt - ref;
        _altitudeReference = alt;
      } else if (ref - alt >= seuilDeniveleM) {
        _altitudeReference = alt; // descente : on recale la référence sans compter
      }
    }
    points.add(p);
  }

  int get dureeS => points.length < 2 ? 0 : ((points.last.tempsMs - points.first.tempsMs) / 1000).round();

  /// Vitesse moyenne en km/h sur le parcours.
  double get vitesseMoyKmh => dureeS == 0 ? 0 : distanceM / dureeS * 3.6;

  /// Allure en minutes par km (course à pied), ou null à l'arrêt.
  double? get allureMinParKm => vitesseMoyKmh < 1 ? null : 60 / vitesseMoyKmh;

  /// Tracé à envoyer : [[lat, lon, secondes, intensité], …], au plus [maxPoints] points.
  /// Les [masquerM] premiers et derniers mètres sont retirés : le départ et l'arrivée
  /// sont souvent le domicile. Null si le parcours est trop court pour en garder quelque chose.
  List<List<num>>? traceAEnvoyer({int maxPoints = 500, double masquerM = 200}) {
    if (points.length < 2) return null;
    // distance cumulée de chaque point
    final cumul = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumul.add(cumul.last + distance(points[i - 1], points[i]));
    }
    final total = cumul.last;
    final gardes = [
      for (var i = 0; i < points.length; i++)
        if (cumul[i] >= masquerM && cumul[i] <= total - masquerM) points[i],
    ];
    if (gardes.length < 2) return null;
    final pas = (gardes.length / maxPoints).ceil();
    final t0 = points.first.tempsMs;
    double arrondi(double v) => (v * 100000).round() / 100000; // ≈ 1 m
    return [
      for (var i = 0; i < gardes.length; i += pas)
        [arrondi(gardes[i].latitude), arrondi(gardes[i].longitude), ((gardes[i].tempsMs - t0) / 1000).round(),
         (gardes[i].intensite ?? 0).clamp(0, 255)],
    ];
  }

  Map<String, String> versApi() => {
        if (points.length >= 2) 'distance_m': '${distanceM.round()}',
        if (points.length >= 2) 'denivele_m': '${deniveleM.round()}',
        if (points.length >= 2) 'vitesse_moy_kmh': vitesseMoyKmh.toStringAsFixed(1),
        if (traceAEnvoyer() case final t?) 'trace': jsonEncode(t),
      };
}

/// Compte les pas à partir de l'accélération (norme, en m/s², sans la gravité).
/// Un pas = un pic au-dessus du seuil, au moins 250 ms après le précédent (≤ 4 pas/s).
class Podometre {
  Podometre({this.seuil = 2.5, this.intervalleMinMs = 250});

  final double seuil;
  final int intervalleMinMs;
  int pas = 0;
  bool _auDessus = false;
  int _dernierPasMs = -1000000;

  void ajouter(double x, double y, double z, int tempsMs) {
    final norme = sqrt(x * x + y * y + z * z);
    if (!_auDessus && norme >= seuil) {
      _auDessus = true;
      if (tempsMs - _dernierPasMs >= intervalleMinMs) {
        pas++;
        _dernierPasMs = tempsMs;
      }
    } else if (_auDessus && norme < seuil * 0.6) {
      _auDessus = false;
    }
  }

  /// Cadence en pas par minute sur une durée donnée.
  double cadence(int dureeS) => dureeS <= 0 ? 0 : pas * 60 / dureeS;
}
