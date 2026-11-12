import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
