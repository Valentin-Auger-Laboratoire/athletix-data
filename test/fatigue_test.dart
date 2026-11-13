import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/analyse_frequence.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/codec_gatt.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/mesure_frequence.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/brassard/suivi_fatigue.dart';

List<double> sinus(List<List<double>> composantes, {int n = 1024}) => [
      for (var i = 0; i < n; i++)
        composantes.fold(0.0, (s, c) => s + c[1] * sin(2 * pi * c[0] * i / 2000 + 0.3)),
    ];

void main() {
  group('Fréquence médiane (copie de calcul_fatigue.h)', () {
    final analyse = AnalyseFrequence();
    const df = 2000 / 1024;

    test('même résultat que le firmware sur le même signal (référence du test C++)', () {
      // tests/firmware/test_calcul_fatigue.cpp, partie 8 : MDF = 142,210 Hz, MNF = 165,652 Hz
      final filtre = PasseBande(100);
      final h = HasardReproductible(42);
      final x = [for (var i = 0; i < 1024; i++) 300 * filtre.filtrer(h.gauss())];
      final r = analyse.analyser(x);
      expect(r.mdfHz, closeTo(142.210, 0.05));
      expect(r.mnfHz, closeTo(165.652, 0.05));
    });

    test('un sinus : MDF et MNF = sa fréquence', () {
      expect(analyse.analyser(sinus([[51 * df, 300]])).mdfHz, closeTo(51 * df, 0.05));
      for (final f in [37.3, 87.7, 123.4, 211.9, 377.1]) {
        final r = analyse.analyser(sinus([[f, 200]]));
        expect(r.mdfHz, closeTo(f, 0.6 * df));
        expect(r.mnfHz, closeTo(f, 0.6 * df));
      }
    });

    test('secteur 50 Hz, hors bande et composante continue ignorés', () {
      expect(analyse.analyser(sinus([[50, 1000], [150, 50]])).mdfHz, closeTo(150, 1));
      expect(analyse.analyser(sinus([[8, 1000], [600, 1000], [120, 50]])).mdfHz, closeTo(120, 1));
      final decale = sinus([[120, 50]]).map((v) => v + 1650).toList();
      expect(analyse.analyser(decale).mdfHz, closeTo(120, 1));
      expect(analyse.analyser(List.filled(1024, 0.0)).valide, isFalse);
    });

    test('spectre qui glisse (fatigue simulée) : la MDF baisse', () {
      final h = HasardReproductible(11);
      double moyenne(double fc) {
        final f = PasseBande(fc);
        for (var i = 0; i < 500; i++) {
          f.filtrer(h.gauss());
        }
        var s = 0.0;
        for (var w = 0; w < 8; w++) {
          s += analyse.analyser([for (var i = 0; i < 1024; i++) 200 * f.filtrer(h.gauss())]).mdfHz;
        }
        return s / 8;
      }

      expect(moyenne(80), lessThan(moyenne(110) - 15));
    });

    test('taille de fenêtre vérifiée', () {
      expect(() => analyse.analyser([1, 2, 3]), throwsArgumentError);
    });
  });

  group('Paquet Fréquence (GATT §12)', () {
    test('exemple de GATT.md : e8 03 00 00 dc 03 60 04', () {
      final p = const MesureFrequence(horodatageMs: 1000, mdfHz: 98.76, mnfHz: 112.04).versOctets();
      expect(p, [0xe8, 0x03, 0x00, 0x00, 0xdc, 0x03, 0x60, 0x04]);
      final m = MesureFrequence.depuisOctets(p);
      expect(m.horodatageMs, 1000);
      expect(m.mdfHz, 98.8);
      expect(m.mnfHz, 112.0);
      expect(m.valide, isTrue);
    });

    test('MDF nulle = pas de valeur ; mauvaise taille refusée', () {
      expect(MesureFrequence.depuisOctets([0, 0, 0, 0, 0, 0, 0, 0]).valide, isFalse);
      expect(() => MesureFrequence.depuisOctets([1, 2, 3]), throwsFormatException);
    });
  });

  group('Configuration et commande de source (firmware 1.2)', () {
    test('6e octet = source ; absent (firmware 1.1) = ENV', () {
      expect(ConfigurationBrassard.depuisOctets([75, 70, 0x3a, 0x07, 50, 1]).source, GattAthletix.sourceRaw);
      expect(ConfigurationBrassard.depuisOctets([75, 70, 0x3a, 0x07, 50]).source, GattAthletix.sourceEnv);
      expect(ConfigurationBrassard.parDefaut.versOctets().length, 5, reason: "l'application écrit toujours 5 octets");
    });

    test('commande 0x07 et message de l\'erreur 5', () {
      expect(CommandeBrassard.choisirSource(1), [0x07, 1]);
      expect(() => CommandeBrassard.choisirSource(3), throwsArgumentError);
      expect(const EtatLu(EtatBrassard.mesure, 5).message, contains('RAW'));
    });
  });

  group('Suivi de la fatigue', () {
    MesureFrequence m(double t, double mdf) => MesureFrequence(horodatageMs: (t * 1000).round(), mdfHz: mdf, mnfHz: mdf + 15);

    test('MDF qui baisse de 120 à 96 Hz en 2 min : baisse de 20 %', () {
      final s = SuiviFatigue();
      for (var t = 0.0; t <= 120; t += 0.5) {
        s.ajouter(m(t, 120 - 24 * t / 120 + (t * 7 % 3 - 1.5))); // ± 1,5 Hz de bruit
      }
      final r = s.resultat()!;
      expect(r.baissePct, closeTo(20, 1.5));
      expect(r.penteHzParMin, closeTo(-12, 1));
      expect(ResultatFatigue.interpretation(r.baissePct), 'fatigue nette du muscle');
      expect(r.courbe.length, 5);
      expect(r.courbe.first, greaterThan(r.courbe[3]));
      expect(r.versApi()['courbe_mdf'], startsWith('['));
      expect(s.ecartPct!, lessThan(-15));
    });

    test('repos ignoré, trop peu de valeurs : pas de résultat', () {
      final s = SuiviFatigue();
      for (var t = 0.0; t < 30; t += 0.5) {
        s.ajouter(m(t, 0));
      }
      for (var t = 30.0; t < 35; t += 0.5) {
        s.ajouter(m(t, 110));
      }
      expect(s.nbValeurs, 10);
      expect(s.resultat(), isNull);
      expect(s.mdfActuelle, 110);
    });

    test('MDF stable : pas de fatigue mesurable ; horodatage qui repasse à zéro', () {
      final s = SuiviFatigue();
      const depart = 0xFFFFFFFF - 30000;
      for (var t = 0.0; t <= 90; t += 0.5) {
        s.ajouter(MesureFrequence(horodatageMs: (depart + (t * 1000).round()) % 0x100000000, mdfHz: 110, mnfHz: 125));
      }
      final r = s.resultat()!;
      expect(r.baissePct.abs(), lessThan(0.1));
      expect(ResultatFatigue.interpretation(r.baissePct), 'pas de fatigue mesurable');
    });

    test('repères d\'interprétation', () {
      expect(ResultatFatigue.interpretation(6), 'début de fatigue');
      expect(ResultatFatigue.interpretation(-8), contains('hausse'));
    });
  });

  group('Brassard simulé en signal brut', () {
    test('passage en RAW : référence remise à 500 mV, refusé pendant une séance', () async {
      final b = BrassardSimule(hasard: Random(3));
      expect(b.mesureFatigue, isTrue);
      await b.choisirSource(GattAthletix.sourceRaw);
      expect(b.source, GattAthletix.sourceRaw);
      expect(b.refMvcMv, 500);
      await b.demarrer();
      expect(() => b.choisirSource(GattAthletix.sourceEnv), throwsA(isA<ErreurBrassard>()));
      await b.arreter();
      await b.choisirSource(GattAthletix.sourceEnv);
      expect(b.refMvcMv, GattAthletix.refMvcDefautMv);
      b.fermer();
    });

    test('fréquences calculées 2 fois par seconde, valeur seulement pendant l\'effort', () async {
      final b = BrassardSimule(hasard: Random(5));
      await b.choisirSource(GattAthletix.sourceRaw);
      final recues = <MesureFrequence>[];
      final ab = b.frequences.listen(recues.add);
      await b.demarrer();
      await Future.delayed(const Duration(seconds: 12));
      await b.arreter();
      await ab.cancel();
      expect(recues.length, inInclusiveRange(20, 25));
      final valides = recues.where((r) => r.valide).toList();
      expect(valides, isNotEmpty);
      expect(recues.where((r) => !r.valide), isNotEmpty, reason: 'les 3 premières secondes sont au repos');
      for (final v in valides) {
        expect(v.mdfHz, inInclusiveRange(60, 200));
      }
      b.fermer();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('la fatigue simulée monte avec l\'effort', () async {
      final b = BrassardSimule(hasard: Random(8));
      await b.choisirSource(GattAthletix.sourceRaw);
      await b.demarrer();
      await Future.delayed(const Duration(seconds: 4));
      await b.arreter();
      expect(b.fatigue, greaterThan(0));
      b.fermer();
    });
  });

  test('le brassard simulé respecte l\'interface (compile)', () {
    final SourceBrassard s = BrassardSimule();
    expect(s.frequences, isA<Stream<MesureFrequence>>());
    s.fermer();
  });
}
