import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/telephone/fond_carte.dart';

/// Nombre décimal à la française (virgule).
String decimalFr(num v, int chiffres) => v.toStringAsFixed(chiffres).replaceAll('.', ',');

/// Graphiques communs de l'application (bibliothèque fl_chart, licence MIT).

const _grille = FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25);

Widget _titre(double v, TitleMeta meta, String Function(double) format) {
  // Le maximum de l'axe n'est pas affiché s'il ne tombe pas sur une graduation (il chevauche la précédente)
  final surGraduation = (v / meta.appliedInterval - (v / meta.appliedInterval).round()).abs() < 1e-6;
  if (meta.axisSide == AxisSide.left && v == meta.max && !surGraduation) return const SizedBox();
  return SideTitleWidget(
    meta: meta,
    // Une seule ligne, réduite si besoin (grands caractères)
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(format(v), maxLines: 1, softWrap: false, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ),
  );
}

/// Courbe de l'intensité musculaire (en % MVC) avec le seuil d'alerte.
/// [pasS] : nombre de secondes entre deux points (pour l'axe du temps).
class CourbeIntensite extends StatelessWidget {
  const CourbeIntensite({
    super.key,
    required this.valeurs,
    required this.seuil,
    this.pasS = 1,
    this.couleur = Colors.orange,
    this.hauteur = 180,
    this.enDirect = false,
  });

  final List<num> valeurs;
  final int seuil;
  final double pasS;
  final Color couleur;
  final double hauteur;
  final bool enDirect;

  @override
  Widget build(BuildContext context) {
    if (valeurs.length < 2) {
      return SizedBox(
        height: hauteur,
        child: const Center(child: Text('Pas encore assez de mesures', style: TextStyle(color: Colors.white38))),
      );
    }
    final maxY = [120.0, ...valeurs.map((v) => v.toDouble() + 10)].reduce((a, b) => a > b ? a : b);
    final dureeTotale = (valeurs.length - 1) * pasS;
    String formatTemps(double s) {
      if (enDirect) return '${(s - dureeTotale).round()} s';
      return s >= 120 ? '${(s / 60).round()} min' : '${s.round()} s';
    }

    return SizedBox(
      height: hauteur,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: dureeTotale,
          clipData: const FlClipData.all(),
          gridData: _grille,
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: !enDirect),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: 25,
                getTitlesWidget: (v, m) => _titre(v, m, (x) => '${x.round()} %'),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: dureeTotale <= 0 ? 1 : dureeTotale / 4,
                getTitlesWidget: (v, m) => _titre(v, m, formatTemps),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: seuil.toDouble(), color: Colors.redAccent, strokeWidth: 1.5, dashArray: [6, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < valeurs.length; i++) FlSpot(i * pasS, valeurs[i].toDouble())],
              isCurved: true,
              curveSmoothness: 0.2,
              color: couleur,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: couleur.withValues(alpha: 0.15)),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// Barre empilée du temps passé dans chaque zone d'intensité, avec la légende.
class BarreZones extends StatelessWidget {
  const BarreZones({super.key, required this.secondes});

  /// Repos, modérée, soutenue, intense (en secondes).
  final List<int> secondes;

  static const List<(String, Color)> zones = [
    ('Repos < 20 %', Colors.blueGrey),
    ('Modérée 20–50 %', Colors.green),
    ('Soutenue 50–75 %', Colors.orange),
    ('Intense ≥ 75 %', Colors.redAccent),
  ];

  @override
  Widget build(BuildContext context) {
    final total = secondes.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox();
    String duree(int s) => s >= 60 ? '${s ~/ 60} min ${(s % 60).toString().padLeft(2, '0')}' : '$s s';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              if (secondes[i] > 0)
                Expanded(flex: secondes[i], child: Container(height: 18, color: zones[i].$2)),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (var i = 0; i < 4; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, color: zones[i].$2),
              const SizedBox(width: 4),
              Text('${zones[i].$1} : ${duree(secondes[i])} (${(secondes[i] * 100 / total).round()} %)',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
        ]),
      ],
    );
  }
}

/// Histogramme (une barre par semaine).
class Histogramme extends StatelessWidget {
  const Histogramme({
    super.key,
    required this.valeurs,
    required this.libelles,
    this.couleur = Colors.orange,
    this.unite = '',
    this.hauteur = 170,
    this.couleurs,
  });

  final List<double> valeurs;
  final List<String> libelles;
  final Color couleur;
  final String unite;
  final double hauteur;

  /// Couleur propre à chaque barre (pour marquer une semaine moins bonne).
  final List<Color>? couleurs;

  @override
  Widget build(BuildContext context) {
    if (valeurs.isEmpty) return SizedBox(height: hauteur);
    final maxY = valeurs.reduce((a, b) => a > b ? a : b) * 1.2 + 1;
    final pas = libelles.length > 8 ? (libelles.length / 6).ceil() : 1;
    return SizedBox(
      height: hauteur,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                '${libelles[g.x]}\n${rod.toY.toStringAsFixed(rod.toY < 10 ? 1 : 0)} $unite',
                const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, m) => _titre(v, m, (x) => x.toStringAsFixed(x < 10 && x != x.roundToDouble() ? 1 : 0)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, m) => v.toInt() % pas == 0 && v.toInt() < libelles.length
                    ? _titre(v, m, (_) => libelles[v.toInt()])
                    : const SizedBox(),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < valeurs.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: valeurs[i],
                  color: couleurs?[i] ?? couleur,
                  width: valeurs.length > 12 ? 8 : 14,
                  borderRadius: BorderRadius.circular(3),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Plusieurs courbes sur le même axe (par exemple intensité moyenne et fatigue ressentie).
class CourbesEvolution extends StatelessWidget {
  const CourbesEvolution({super.key, required this.series, required this.libelles, this.maxY, this.hauteur = 180});

  /// (nom, couleur, valeurs ; null = pas de donnée cette semaine)
  final List<(String, Color, List<double?>)> series;
  final List<String> libelles;
  final double? maxY;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    if (libelles.length < 2) return SizedBox(height: hauteur);
    final pas = libelles.length > 8 ? (libelles.length / 6).ceil() : 1;
    return Column(children: [
      SizedBox(
        height: hauteur,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: _grille,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, m) => _titre(v, m, (x) => x.toStringAsFixed(0)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (v, m) => v.toInt() % pas == 0 && v.toInt() < libelles.length
                    ? _titre(v, m, (_) => libelles[v.toInt()])
                    : const SizedBox(),
              ),
            ),
          ),
          lineBarsData: [
            for (final (_, couleur, valeurs) in series)
              LineChartBarData(
                spots: [
                  for (var i = 0; i < valeurs.length; i++)
                    if (valeurs[i] != null) FlSpot(i.toDouble(), valeurs[i]!),
                ],
                color: couleur,
                barWidth: 2,
                isCurved: true,
                curveSmoothness: 0.2,
                dotData: const FlDotData(show: true),
              ),
          ],
        )),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 14, children: [
        for (final (nom, couleur, _) in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 3, color: couleur),
            const SizedBox(width: 4),
            Text(nom, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
      ]),
    ]);
  }
}

/// Couleur de la zone d'intensité (mêmes couleurs que [BarreZones]).
Color couleurZone(num intensite) => intensite < 20
    ? Colors.blueGrey
    : intensite < 50
        ? Colors.green
        : intensite < 75
            ? Colors.orange
            : Colors.redAccent;

/// Point d'un tracé : [lat, lon, secondes, intensité] (format du serveur).
typedef PointTrace = List<num>;

/// Vitesse (km/h) et distance cumulée (km) pour chaque point, vitesse lissée sur ~30 s.
({List<double> distanceKm, List<double> vitesseKmh}) profilTrace(List<PointTrace> t) {
  double d(PointTrace a, PointTrace b) {
    const r = 6371000.0;
    double rad(num x) => x * 3.141592653589793 / 180;
    final dLat = rad(b[0] - a[0]), dLon = rad(b[1] - a[1]);
    final h = _sin2(dLat / 2) + _cos(rad(a[0])) * _cos(rad(b[0])) * _sin2(dLon / 2);
    return 2 * r * _asin(_sqrt(h));
  }

  final cumul = <double>[0];
  for (var i = 1; i < t.length; i++) {
    cumul.add(cumul.last + d(t[i - 1], t[i]));
  }
  final vitesses = <double>[];
  for (var i = 0; i < t.length; i++) {
    // fenêtre de ±15 s autour du point
    var a = i, b = i;
    while (a > 0 && t[i][2] - t[a - 1][2] <= 15) {
      a--;
    }
    while (b < t.length - 1 && t[b + 1][2] - t[i][2] <= 15) {
      b++;
    }
    if (a == b) {
      if (b < t.length - 1) {
        b++;
      } else if (a > 0) {
        a--;
      }
    }
    final dt = (t[b][2] - t[a][2]).toDouble();
    vitesses.add(dt <= 0 ? 0 : (cumul[b] - cumul[a]) / dt * 3.6);
  }
  return (distanceKm: cumul.map((m) => m / 1000).toList(), vitesseKmh: vitesses);
}

double _sin2(double x) => math.pow(math.sin(x), 2).toDouble();
double _cos(double x) => math.cos(x);
double _asin(double x) => math.asin(x.clamp(-1.0, 1.0));
double _sqrt(double x) => math.sqrt(x);

/// Tracé du parcours vu de dessus, coloré par l'intensité musculaire.
/// Pas de fond de carte : aucune requête vers un service de cartes, et le tracé
/// arrive déjà sans ses 200 premiers et derniers mètres.
class CarteParcours extends StatelessWidget {
  const CarteParcours({super.key, required this.trace, this.hauteur = 220, this.fondDeCarte = false});

  final List<PointTrace> trace;
  final double hauteur;

  /// Rues d'OpenStreetMap sous le tracé (réglage « Fond de carte », désactivé par défaut).
  final bool fondDeCarte;

  @override
  Widget build(BuildContext context) {
    if (trace.length < 2) return SizedBox(height: hauteur);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: hauteur,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
        child: fondDeCarte
            ? LayoutBuilder(builder: (context, c) => _avecFond(VueCarte(trace, c.maxWidth, hauteur)))
            : CustomPaint(painter: _PeintreParcours(trace)),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (final (nom, c) in BarreZones.zones)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 3, color: c),
            const SizedBox(width: 4),
            Text(nom, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 9, color: Colors.white),
          SizedBox(width: 4),
          Text('départ', style: TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ]),
    ]);
  }

  /// Tuiles OpenStreetMap (grisées et assombries pour que le tracé coloré reste lisible),
  /// tracé par-dessus avec la même projection, crédit obligatoire en bas à droite.
  Widget _avecFond(VueCarte vue) {
    const t = FondCarte.tailleTuile * 1.0;
    return Stack(children: [
      for (final (x, y, gauche, haut) in vue.tuiles())
        Positioned(
          // Pixels entiers et 1 px de recouvrement : pas de fine ligne entre deux tuiles
          left: gauche.floorToDouble(),
          top: haut.floorToDouble(),
          width: t + 1,
          height: t + 1,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.16, 0.32, 0.06, 0, -20, //
              0.16, 0.32, 0.06, 0, -20,
              0.16, 0.32, 0.06, 0, -20,
              0, 0, 0, 1, 0,
            ]),
            child: Image.network(
              FondCarte.urlTuile(vue.zoom, x, y),
              // Le navigateur envoie déjà son identité ; l'application s'identifie (règles d'OSM)
              headers: kIsWeb ? null : const {'User-Agent': FondCarte.agent},
              fit: BoxFit.fill,
              errorBuilder: (context, erreur, pile) => const SizedBox(), // hors ligne : tracé seul
            ),
          ),
        ),
      Positioned.fill(child: CustomPaint(painter: _PeintreParcours(trace, vue: vue))),
      Positioned(
        right: 4,
        bottom: 2,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(FondCarte.lienCredit), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: Colors.black54,
            child: const Text(FondCarte.credit, style: TextStyle(color: Colors.white70, fontSize: 9)),
          ),
        ),
      ),
    ]);
  }
}

class _PeintreParcours extends CustomPainter {
  _PeintreParcours(this.t, {this.vue});

  final List<PointTrace> t;

  /// Avec un fond de carte : projection de Mercator des tuiles, imposée par la carte.
  final VueCarte? vue;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset Function(int) o;
    final double echelle; // pixels par mètre
    final v = vue;
    if (v != null) {
      o = (i) {
        final (x, y) = v.position(t[i]);
        return Offset(x, y);
      };
      final lat0 = t.map((p) => p[0]).reduce((a, b) => a + b) / t.length;
      echelle = 1 / (156543.03392 * math.cos(lat0 * math.pi / 180) / (1 << v.zoom));
    } else {
      // Projection équirectangulaire (suffisante sur quelques kilomètres), mêmes échelles en x et y
      final lat0 = t.map((p) => p[0]).reduce((a, b) => a + b) / t.length;
      final kx = 111195 * math.cos(lat0 * math.pi / 180), ky = 111195.0;
      final xs = t.map((p) => p[1] * kx).toList(), ys = t.map((p) => -p[0] * ky).toList();
      final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
      const marge = 16.0;
      final largeurM = math.max(maxX - minX, 1.0), hauteurM = math.max(maxY - minY, 1.0);
      final e = math.min((size.width - 2 * marge) / largeurM, (size.height - 2 * marge) / hauteurM);
      final dx = (size.width - largeurM * e) / 2, dy = (size.height - hauteurM * e) / 2;
      echelle = e;
      o = (i) => Offset(dx + (xs[i] - minX) * e, dy + (ys[i] - minY) * e);
    }

    final trait = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < t.length; i++) {
      trait.color = couleurZone(t[i][3]);
      canvas.drawLine(o(i - 1), o(i), trait);
    }
    canvas.drawCircle(o(0), 6, Paint()..color = Colors.white);
    canvas.drawCircle(o(t.length - 1), 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    // Barre d'échelle : longueur ronde la plus proche du quart de la largeur
    final cible = (size.width / 4) / echelle;
    final options = [50, 100, 200, 250, 500, 1000, 2000, 5000];
    final m = options.lastWhere((v) => v <= cible, orElse: () => 50);
    final px = m * echelle;
    final y = size.height - 10;
    final p = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    canvas.drawLine(Offset(10, y), Offset(10 + px, y), p);
    final texte = TextPainter(
      text: TextSpan(text: m >= 1000 ? '${m ~/ 1000} km' : '$m m', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    texte.paint(canvas, Offset(14 + px, y - 7));
  }

  @override
  bool shouldRepaint(_PeintreParcours old) => !identical(old.t, t) || old.vue?.zoom != vue?.zoom;
}

/// Vitesse et intensité musculaire le long du parcours (axe commun : la distance).
class VitesseIntensite extends StatelessWidget {
  const VitesseIntensite({super.key, required this.trace});

  final List<PointTrace> trace;

  Widget _courbe(List<double> x, List<double> y, Color c, String unite, double hauteur,
      {bool axeX = false, required double pas}) {
    // Échelle ronde : un multiple du pas au-dessus du maximum
    final maxY = math.max(pas, (y.reduce(math.max) / pas).ceil() * pas).toDouble();
    return SizedBox(
      height: hauteur,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: x.last,
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: pas,
              // le 0 du graphique du haut chevaucherait le maximum de celui du bas
              getTitlesWidget: (v, m) => v == 0 && !axeX ? const SizedBox() : _titre(v, m, (z) => '${z.round()} $unite'),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: axeX,
              reservedSize: 22,
              interval: x.last <= 0 ? 1 : x.last / 4,
              getTitlesWidget: (v, m) => _titre(v, m, (z) => '${decimalFr(z, 1)} km'),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < x.length; i++) FlSpot(x[i], y[i])],
            isCurved: true,
            curveSmoothness: 0.2,
            color: c,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trace.length < 3) return const SizedBox();
    final p = profilTrace(trace);
    return Column(children: [
      _courbe(p.distanceKm, p.vitesseKmh, Colors.lightBlueAccent, 'km/h', 110, pas: 4),
      const SizedBox(height: 8),
      _courbe(p.distanceKm, [for (final pt in trace) pt[3].toDouble()], Colors.orange, '%', 130, axeX: true, pas: 25),
      const SizedBox(height: 4),
      const Text('En haut : vitesse (GPS) · en bas : intensité musculaire (brassard)',
          style: TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }
}

/// Fréquence médiane du signal brut au fil de la séance (un point par bloc de 30 s où le muscle
/// travaillait), avec la droite ajustée du début à la fin (pointillés) : elle descend si le muscle fatigue.
class CourbeFrequence extends StatelessWidget {
  const CourbeFrequence({
    super.key,
    required this.valeurs,
    this.debutHz,
    this.finHz,
    this.pasS = 30,
    this.hauteur = 170,
  });

  /// Une valeur par bloc (0 = bloc sans effort, non tracé).
  final List<num> valeurs;
  final double? debutHz;
  final double? finHz;
  final double pasS;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (var i = 0; i < valeurs.length; i++)
        if (valeurs[i] > 0) FlSpot(i * pasS + pasS / 2, valeurs[i].toDouble()),
    ];
    if (points.length < 2) {
      return SizedBox(
        height: hauteur,
        child: const Center(child: Text('Pas assez de blocs avec effort', style: TextStyle(color: Colors.white38))),
      );
    }
    final ys = <double>[...points.map((p) => p.y), if (debutHz != null) debutHz!, if (finHz != null) finHz!];
    final minY = (ys.reduce(math.min) / 10).floor() * 10.0 - 10;
    final maxY = (ys.reduce(math.max) / 10).ceil() * 10.0 + 10;
    final duree = valeurs.length * pasS;
    String temps(double s) => s >= 120 ? '${(s / 60).round()} min' : '${s.round()} s';
    return SizedBox(
      height: hauteur,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: duree,
          minY: math.max(0, minY),
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: maxY - minY > 60 ? 20 : 10,
                getTitlesWidget: (v, m) => _titre(v, m, (x) => '${x.round()} Hz'),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: duree / 4,
                getTitlesWidget: (v, m) => _titre(v, m, temps),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              color: Colors.cyanAccent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, x, b, i) => FlDotCirclePainter(radius: 3, color: Colors.cyanAccent, strokeWidth: 0),
              ),
            ),
            if (debutHz != null && finHz != null)
              LineChartBarData(
                spots: [FlSpot(points.first.x, debutHz!), FlSpot(points.last.x, finHz!)],
                color: Colors.orangeAccent,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
