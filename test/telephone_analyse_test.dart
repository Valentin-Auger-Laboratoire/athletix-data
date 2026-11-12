import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/analyse/analyse_seance.dart';
import 'package:athletix_data/services/analyse/evolution.dart';
import 'package:athletix_data/services/analyse/export_soignants.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/demo_seances.dart';
import 'package:athletix_data/services/telephone/cardio.dart';
import 'package:athletix_data/services/telephone/meteo.dart';
import 'package:athletix_data/services/telephone/trace_gps.dart';

/// Mesures à 50 Hz (20 ms) avec une intensité donnée par [f] (temps en s → %).
List<MesureEmg> mesures(int dureeS, int Function(double t) f) => [
      for (var i = 0; i <= dureeS * 50; i++)
        MesureEmg(horodatageMs: i * 20, rmsMv: 0, intensitePct: f(i * 0.02)),
    ];

void main() {
  group('AnalyseSeance', () {
    test('zones : le temps est rangé dans la bonne zone', () {
      final a = AnalyseSeance();
      // 10 s à 10 %, 10 s à 30 %, 10 s à 60 %, 10 s à 90 %
      for (final m in mesures(40, (t) => [10, 30, 60, 90][min(3, t ~/ 10)])) {
        a.ajouter(m);
      }
      expect(a.tempsReposS, 10);
      expect(a.tempsModereeS, 10);
      expect(a.tempsSoutenueS, 10);
      expect(a.tempsIntenseS, 10);
    });

    test('contractions comptées avec hystérésis (30 / 20 %)', () {
      final a = AnalyseSeance();
      // 5 contractions de 2 s séparées de 2 s de repos, + un bruit à 25 % qui ne compte pas
      for (final m in mesures(19, (t) => (t % 4) < 2 ? 50 : (t > 18.5 ? 25 : 5))) {
        a.ajouter(m);
      }
      expect(a.nbContractions, 5);
    });

    test('courbe : une moyenne par bloc de 5 s', () {
      final a = AnalyseSeance();
      for (final m in mesures(20, (t) => t < 10 ? 40 : 80)) {
        a.ajouter(m);
      }
      expect(a.courbe.length, inInclusiveRange(4, 5));
      expect(a.courbe.first, 40);
      expect(a.courbe[3], 80);
      expect(a.versApi()['courbe'], startsWith('[40,40,'));
    });

    test('indice de fatigue : positif si l\'intensité monte, absent sous 3 minutes', () {
      final monte = AnalyseSeance();
      for (final m in mesures(6 * 60, (t) => 40 + (t / 60 * 4).round())) {
        monte.ajouter(m);
      }
      expect(monte.indiceFatiguePct, greaterThan(10));
      final court = AnalyseSeance();
      for (final m in mesures(90, (_) => 50)) {
        court.ajouter(m);
      }
      expect(court.indiceFatiguePct, isNull);
      expect(court.versApi().containsKey('indice_fatigue_pct'), isFalse);
    });

    test('une mesure pendant la calibration est ignorée', () {
      final a = AnalyseSeance();
      a.ajouter(const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 90, calibrationEnCours: true));
      expect(a.nbContractions, 0);
    });
  });

  group('TraceGps', () {
    test('distance par haversine : 0,01° de latitude ≈ 1 112 m', () {
      final d = TraceGps.distance(const PointGps(48.85, 2.35, tempsMs: 0), const PointGps(48.86, 2.35, tempsMs: 0));
      expect(d, closeTo(1112, 2));
    });

    test('parcours à 10 km/h : vitesse, points imprécis et sauts ignorés', () {
      final t = TraceGps();
      // 10 km/h = 2,778 m/s ; 1 m de latitude ≈ 1/111195 degré
      for (var s = 0; s <= 600; s += 5) {
        t.ajouter(PointGps(48.85 + s * 2.7778 / 111195, 2.35, precisionM: 5, tempsMs: s * 1000));
      }
      t.ajouter(const PointGps(48.95, 2.35, precisionM: 5, tempsMs: 601000)); // saut de 11 km en 1 s
      t.ajouter(const PointGps(48.851, 2.36, precisionM: 80, tempsMs: 602000)); // en intérieur
      expect(t.distanceM, closeTo(1666.7, 3));
      expect(t.vitesseMoyKmh, closeTo(10, 0.05));
      expect(t.allureMinParKm, closeTo(6, 0.05));
    });

    test('dénivelé : le bruit de ±2 m ne compte pas, une côte de 20 m oui', () {
      final t = TraceGps();
      final alea = Random(1);
      for (var s = 0; s < 100; s++) {
        t.ajouter(PointGps(48.85, 2.35, altitude: 30 + alea.nextDouble() * 2 - 1, tempsMs: s * 1000));
      }
      expect(t.deniveleM, 0);
      for (var s = 0; s <= 20; s++) {
        t.ajouter(PointGps(48.85, 2.35, altitude: 30.0 + s, tempsMs: (100 + s) * 1000));
      }
      expect(t.deniveleM, closeTo(20, 3.5));
      expect(t.versApi()['denivele_m'], isNotNull);
    });
  });

  group('Podometre', () {
    test('pics à 2,75 pas/s comptés, vibrations faibles ignorées', () {
      final p = Podometre();
      // 60 s, un pic de 6 m/s² toutes les 364 ms, et du bruit de 1 m/s²
      for (var ms = 0; ms < 60000; ms += 10) {
        final pic = ms % 364 < 40;
        p.ajouter(pic ? 6 : 1, 0, 0, ms);
      }
      expect(p.pas, inInclusiveRange(164, 166));
      expect(p.cadence(60), closeTo(165, 1.5));
    });

    test('deux pics à moins de 250 ms ne font qu\'un pas', () {
      final p = Podometre();
      p.ajouter(5, 0, 0, 0);
      p.ajouter(0, 0, 0, 50);
      p.ajouter(5, 0, 0, 100);
      expect(p.pas, 1);
    });
  });

  group('Ceinture cardio (0x2A37)', () {
    test('fréquence sur 8 bits', () => expect(CeintureCardio.lireMesure([0x00, 72]), 72));
    test('fréquence sur 16 bits', () => expect(CeintureCardio.lireMesure([0x01, 0x2C, 0x01]), 300));
    test('paquet trop court', () {
      expect(CeintureCardio.lireMesure([0x00]), isNull);
      expect(CeintureCardio.lireMesure([0x01, 0x2C]), isNull);
    });
    test('statistiques sans les valeurs aberrantes', () {
      final s = StatsCardio();
      for (final b in [120, 140, 160, 0, 300]) {
        s.ajouter(b);
      }
      expect(s.moyenne, 140);
      expect(s.maximum, 160);
      expect(s.versApi(), {'fc_moy': '140', 'fc_max': '160'});
    });
  });

  group('Météo (Open-Meteo)', () {
    test('lecture de la réponse', () {
      final m = Meteo.depuisJson({
        'current': {'temperature_2m': 27.4, 'relative_humidity_2m': 40, 'weather_code': 1},
      })!;
      expect(m.temperatureC, 27.4);
      expect(m.chaud, isTrue);
      expect(Meteo.libelle(m.code), 'nuageux');
      expect(m.versApi()['temperature_c'], '27.4');
    });
    test('réponse incomplète', () => expect(Meteo.depuisJson({'current': {'temperature_2m': 20}}), isNull));
  });

  group('Évolution', () {
    final evolution = Evolution(seancesDemo().map(SeanceResume.depuisApi).whereType<SeanceResume>());

    test('six semaines, trois séances par semaine', () {
      expect(evolution.semaines.length, 6);
      expect(evolution.semaines.every((s) => s.nbSeances == 3), isTrue);
    });

    test('la 4e semaine de la démo est repérée, avec ses causes', () {
      final moinsBonnes = evolution.semainesMoinsBonnes();
      expect(moinsBonnes.map((m) => m.semaine.lundi), contains(evolution.semaines[3].lundi));
      final m = moinsBonnes.firstWhere((m) => m.semaine.lundi == evolution.semaines[3].lundi);
      expect(m.causes.any((c) => c.startsWith('fatigue')), isTrue);
      expect(m.causes.any((c) => c.startsWith('mauvais sommeil')), isTrue);
      expect(m.causes.any((c) => c.startsWith('douleur')), isTrue);
    });

    test('points identiques à la règle du classement', () {
      final s = SeanceResume.depuisApi({
        'debut': '2026-11-10 18:00:00', 'discipline': 'Running', 'duree_s': 1800,
        'intensite_moyenne_pct': 50, 'intensite_max_pct': 80, 'temps_effort_intense_s': 0,
      })!;
      expect(s.points, 40); // 10 + 30 min × 50 / 50
    });

    test('records', () {
      final libelles = evolution.records.map((r) => r.libelle).toList();
      expect(libelles, containsAll(['Contraction la plus forte', 'Séance la plus longue', 'Plus longue distance', 'Meilleure semaine']));
    });
  });

  group('Export CSV pour les soignants', () {
    test('format français et cellules protégées', () {
      final csv = ExportSoignants.versCsv([
        {'debut': '2026-11-10 18:00:00', 'discipline': 'Running', 'vitesse_moy_kmh': 10.5,
         'commentaire': 'genou; un peu "raide"', 'mode_adapte': true},
      ]);
      expect(csv.startsWith('﻿'), isTrue);
      final lignes = csv.substring(1).trim().split('\r\n');
      expect(lignes.length, 2);
      expect(lignes[0].split(';').length, ExportSoignants.colonnes.length);
      expect(lignes[1], contains('10,5'));
      expect(lignes[1], contains('"genou; un peu ""raide"""'));
      expect(lignes[1], contains('oui'));
    });
  });

  group('Séances de démo', () {
    test('toujours identiques et cohérentes', () {
      final a = seancesDemo(), b = seancesDemo();
      expect(a.length, 18);
      expect(a.first['debut'], b.first['debut']);
      for (final s in a) {
        expect(s['donnees_simulees'], isTrue);
        expect((s['courbe'] as List).length, (s['duree_s'] as int) ~/ 5);
        expect(s['intensite_max_pct'] as int, greaterThanOrEqualTo(s['intensite_moyenne_pct'] as int));
        if (s['fc_moy'] != null) expect(s['fc_max'] as int, greaterThanOrEqualTo(s['fc_moy'] as int));
      }
    });
  });
}
