import 'dart:math';

/// Séances FICTIVES de la démo, au format de get_seances.php, toutes faites avec le brassard simulé.
///
/// Six semaines d'entraînement, toujours identiques (graine fixe), pour montrer les graphiques :
/// la 4e semaine est volontairement moins bonne (mauvaises nuits, fatigue, douleur au genou)
/// pour que l'écran « Mon évolution » ait quelque chose à expliquer.
List<Map<String, dynamic>> seancesDemo({DateTime? derniere}) {
  final alea = Random(2026);
  final fin = derniere ?? DateTime(2026, 11, 8, 20, 0); // dimanche soir : six semaines complètes
  final lundiFin = DateTime(fin.year, fin.month, fin.day).subtract(Duration(days: fin.weekday - 1));
  final seances = <Map<String, dynamic>>[];
  String date(DateTime d) => d.toString().substring(0, 19);

  // (jour de la semaine 1 = lundi, heure, discipline)
  const planning = [
    (1, 18, 'Musculation'),
    (3, 7, 'Running'),
    (6, 10, 'Trail'),
  ];

  for (var semaine = 0; semaine < 6; semaine++) {
    final lundi = lundiFin.subtract(Duration(days: 7 * (5 - semaine)));
    final mauvaise = semaine == 3;
    final progres = semaine * 0.03; // légère progression d'une semaine à l'autre

    for (final (jour, heure, discipline) in planning) {
      final debut = lundi.add(Duration(days: jour - 1, hours: heure, minutes: alea.nextInt(40)));
      if (debut.isAfter(fin)) continue;
      final course = discipline != 'Musculation';
      final dureeS = (course ? 2400 + alea.nextInt(1500) : 1800 + alea.nextInt(900)) * (mauvaise ? 0.9 : 1);
      final duree = dureeS.round();

      // Courbe d'intensité : une valeur toutes les 5 s
      final nb = duree ~/ 5;
      final base = (course ? 30 : 42) * (1 + progres) * (mauvaise ? 0.55 : 1);
      final courbe = <int>[];
      for (var i = 0; i < nb; i++) {
        final t = i / nb;
        double v;
        if (course) {
          v = base + 6 * sin(t * 2 * pi * 3) + (discipline == 'Trail' ? 14 * max(0, sin(t * 2 * pi * 2)) : 0);
        } else {
          // séries de 40 s d'effort, 80 s de repos
          final dansSerie = (i * 5) % 120 < 40;
          v = dansSerie ? base * 1.9 + 8 * t : 8;
        }
        v += (alea.nextDouble() - 0.5) * 10;
        if (t < 0.06) v *= t / 0.06 + 0.3; // échauffement
        courbe.add(v.round().clamp(0, 140));
      }
      final moyenne = (courbe.reduce((a, b) => a + b) / courbe.length).round();
      final maximum = courbe.reduce(max);
      int zone(bool Function(int) f) => courbe.where(f).length * 5;
      final intense = zone((v) => v >= 75);
      var alertes = 0;
      var enAlerte = false;
      var contractions = 0;
      var contracte = false;
      for (final v in courbe) {
        if (!enAlerte && v > 75) {
          enAlerte = true;
          alertes++;
        } else if (enAlerte && v < 70) {
          enAlerte = false;
        }
        if (!contracte && v >= 30) {
          contracte = true;
          contractions++;
        } else if (contracte && v < 20) {
          contracte = false;
        }
      }
      final distance = course ? (duree / 3600 * (discipline == 'Trail' ? 8.5 : 10.5) * (1 + progres) * (mauvaise ? 0.85 : 1) * 1000).round() : null;
      final ressenti = mauvaise ? 7 + alea.nextInt(2) : 3 + alea.nextInt(3);

      seances.add({
        'id': 0,
        'discipline': discipline,
        'debut': date(debut),
        'fin': date(debut.add(Duration(seconds: duree))),
        'donnees_simulees': true,
        'duree_s': duree,
        'intensite_moyenne_pct': moyenne,
        'intensite_max_pct': maximum,
        'temps_effort_intense_s': intense,
        'nb_alertes': alertes,
        'ref_mvc_mv': 1850,
        'temps_zone_repos_s': zone((v) => v < 20),
        'temps_zone_moderee_s': zone((v) => v >= 20 && v < 50),
        'temps_zone_soutenue_s': zone((v) => v >= 50 && v < 75),
        'nb_contractions': course ? null : contractions,
        'indice_fatigue_pct': course ? (mauvaise ? 14 : 2 + alea.nextInt(6)) : (mauvaise ? 18 : 6 + alea.nextInt(6)),
        'courbe': courbe,
        'distance_m': distance,
        'denivele_m': discipline == 'Trail' ? 180 + alea.nextInt(150) : (course ? 15 + alea.nextInt(20) : null),
        'vitesse_moy_kmh': distance == null ? null : double.parse((distance / duree * 3.6).toStringAsFixed(1)),
        'nb_pas': course ? (duree / 60 * (160 + alea.nextInt(12))).round() : null,
        'fc_moy': course ? (mauvaise ? 158 : 146) + alea.nextInt(8) : null,
        'fc_max': course ? (mauvaise ? 182 : 172) + alea.nextInt(8) : null,
        'temperature_c': double.parse((12 - semaine * 0.8 + alea.nextDouble() * 3).toStringAsFixed(1)),
        'humidite_pct': 65 + alea.nextInt(25),
        'meteo_code': [0, 2, 3, 61][alea.nextInt(4)],
        'ressenti_fatigue': ressenti,
        'douleur': mauvaise ? 4 + alea.nextInt(2) : alea.nextInt(2),
        'sommeil': mauvaise ? 'Mauvais' : (alea.nextBool() ? 'Bon' : 'Moyen'),
        'commentaire': mauvaise && discipline == 'Running' ? 'Genou droit douloureux, nuits courtes cette semaine' : null,
        'mode_adapte': false,
      });
    }
  }

  // Plus récente en premier, comme get_seances.php
  seances.sort((a, b) => (b['debut'] as String).compareTo(a['debut'] as String));
  for (var i = 0; i < seances.length; i++) {
    seances[i]['id'] = seances.length - i;
  }
  return seances;
}
