import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'trace_gps.dart';

/// Mesures du téléphone pendant une séance : GPS (distance, vitesse, dénivelé) et pas.
///
/// En mode démo (ou si le GPS est refusé), [simuler] produit un parcours inventé à ~10 km/h,
/// signalé comme tel à l'écran.
class SuiviTelephone {
  SuiviTelephone({required this.gps, required this.pas, this.simuler = false, this.intensiteActuelle});

  /// Intensité musculaire du moment, gardée avec chaque point GPS (tracé coloré).
  final int Function()? intensiteActuelle;

  final bool gps;
  final bool pas;
  final bool simuler;

  final TraceGps trace = TraceGps();
  final Podometre podometre = Podometre();
  final List<StreamSubscription> _abonnements = [];
  Timer? _simulation;
  final Stopwatch _chrono = Stopwatch();

  /// Message à afficher si le GPS n'est pas disponible.
  String? probleme;

  /// Dernière position connue (pour la météo).
  PointGps? get position => trace.points.isEmpty ? null : trace.points.last;

  bool get parcoursSimule => simuler;

  Future<void> demarrer() async {
    _chrono.start();
    if (simuler) {
      _simulerParcours();
      return;
    }
    if (gps) await _demarrerGps();
    if (pas) {
      try {
        _abonnements.add(userAccelerometerEventStream().listen(
          (e) => podometre.ajouter(e.x, e.y, e.z, _chrono.elapsedMilliseconds),
          onError: (_) {},
          cancelOnError: true,
        ));
      } catch (_) {/* pas d'accéléromètre (ordinateur) */}
    }
  }

  Future<void> _demarrerGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        probleme = 'Localisation désactivée sur le téléphone';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        probleme = 'Accès à la position refusé';
        return;
      }
      _abonnements.add(Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
      ).listen(
        (p) => trace.ajouter(PointGps(p.latitude, p.longitude,
            altitude: p.altitude, precisionM: p.accuracy, tempsMs: _chrono.elapsedMilliseconds,
            intensite: intensiteActuelle?.call())),
        onError: (_) => probleme = 'Signal GPS perdu',
      ));
    } catch (e) {
      probleme = 'GPS indisponible';
    }
  }

  /// Parcours inventé (démo) : boucle dans Paris à ~10 km/h avec une petite côte, et 165 pas/min.
  void _simulerParcours() {
    const lat0 = 48.8566, lon0 = 2.3522;
    _simulation = Timer.periodic(const Duration(seconds: 1), (_) {
      final t = _chrono.elapsedMilliseconds / 1000;
      final angle = t / 600 * 2 * pi; // un tour de ~1,7 km en 10 min
      const rayonDeg = 0.0024;
      trace.ajouter(PointGps(
        lat0 + rayonDeg * sin(angle),
        lon0 + rayonDeg * 1.5 * cos(angle),
        altitude: 35 + 8 * sin(angle),
        precisionM: 5,
        tempsMs: _chrono.elapsedMilliseconds,
        intensite: intensiteActuelle?.call(),
      ));
      if (pas) podometre.pas += (t.round() % 4 == 0) ? 2 : 3; // ≈ 165 pas/min
    });
  }

  int get dureeS => (_chrono.elapsedMilliseconds / 1000).round();

  Map<String, String> versApi() => {
        if (gps) ...trace.versApi(),
        if (pas && podometre.pas > 0) 'nb_pas': '${podometre.pas}',
      };

  void arreter() {
    _chrono.stop();
    _simulation?.cancel();
    for (final a in _abonnements) {
      a.cancel();
    }
    _abonnements.clear();
  }
}
