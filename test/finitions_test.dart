import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:athletix_data/services/analyse/analyse_seance.dart';
import 'package:athletix_data/services/analyse/export_pdf.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/demo_api.dart';
import 'package:athletix_data/services/demo_seances.dart';
import 'package:athletix_data/services/file_envoi.dart';
import 'package:athletix_data/services/telephone/trace_gps.dart';
import 'package:athletix_data/widgets/graphiques.dart';

/// API qui n'a pas de réseau (pour la file d'envoi), puis qui en retrouve.
class ApiSansReseau extends DemoApi {
  bool reseau = false;
  final recus = <Map<String, String>>[];

  @override
  Future<Map<String, dynamic>> saveSeance(Map<String, String> seance) async {
    if (!reseau) return {"status": "error", "message": "Impossible de joindre le serveur", "reseau": true};
    recus.add(seance);
    return super.saveSeance(seance);
  }
}

Map<String, String> seanceMinimale(String uuid) => {
      'discipline': 'Running', 'duree_s': '600', 'nb_echantillons': '30000', 'intensite_moyenne_pct': '40',
      'intensite_max_pct': '80', 'temps_effort_intense_s': '30', 'nb_alertes': '1', 'simule': '1', 'client_uuid': uuid,
    };

void main() {
  group('Tracé GPS à envoyer', () {
    TraceGps parcoursDroit(int metres) {
      final t = TraceGps();
      for (var m = 0; m <= metres; m += 5) {
        t.ajouter(PointGps(48.85 + m / 111195, 2.35, precisionM: 5, tempsMs: m * 360, intensite: m % 100));
      }
      return t;
    }

    test('les 200 premiers et derniers mètres sont retirés', () {
      final t = parcoursDroit(2000);
      final tr = t.traceAEnvoyer()!;
      final debut = TraceGps.distance(t.points.first, PointGps(tr.first[0].toDouble(), tr.first[1].toDouble(), tempsMs: 0));
      final fin = TraceGps.distance(t.points.last, PointGps(tr.last[0].toDouble(), tr.last[1].toDouble(), tempsMs: 0));
      expect(debut, inInclusiveRange(199, 206));
      expect(fin, inInclusiveRange(199, 206));
    });

    test('500 points au plus, temps croissant, intensité gardée', () {
      final tr = parcoursDroit(10000).traceAEnvoyer()!;
      expect(tr.length, lessThanOrEqualTo(500));
      for (var i = 1; i < tr.length; i++) {
        expect(tr[i][2], greaterThanOrEqualTo(tr[i - 1][2]));
      }
      expect(tr.every((p) => p[3] >= 0 && p[3] <= 255), isTrue);
    });

    test('parcours de moins de 400 m : pas de tracé', () {
      final t = parcoursDroit(350);
      expect(t.traceAEnvoyer(), isNull);
      expect(t.versApi().containsKey('trace'), isFalse);
      expect(parcoursDroit(1000).versApi()['trace'], startsWith('[['));
    });

    test('profil de vitesse : 10 km/h retrouvés', () {
      // 2,778 m/s, un point toutes les 10 s
      final tr = [for (var s = 0; s <= 600; s += 10) <num>[48.85 + s * 2.7778 / 111195, 2.35, s, 50]];
      final p = profilTrace(tr);
      expect(p.distanceKm.last, closeTo(1.6667, 0.005));
      expect(p.vitesseKmh[30], closeTo(10, 0.1));
    });
  });

  group('Séries en musculation', () {
    test('3 séries de 5 répétitions, 60 s de repos entre les séries', () {
      final a = AnalyseSeance();
      var ms = 0;
      void tenir(int duree, int pct) {
        for (var i = 0; i < duree ~/ 20; i++) {
          a.ajouter(MesureEmg(horodatageMs: ms, rmsMv: 0, intensitePct: pct));
          ms += 20;
        }
      }

      for (var serie = 0; serie < 3; serie++) {
        for (var rep = 0; rep < 5; rep++) {
          tenir(1500, 70); // contraction
          tenir(1500, 5); // relâchement entre deux répétitions
        }
        tenir(60000, 5); // repos entre séries
      }
      expect(a.nbContractions, 15);
      expect(a.nbSeries, 3);
      expect(a.versApi()['nb_series'], '3');
    });
  });

  group('Envoi différé', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('identifiant UUID v4', () {
      final u = FileEnvoi.nouvelUuid();
      expect(u, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(FileEnvoi.nouvelUuid(), isNot(u));
    });

    test('séance gardée sans réseau, envoyée au retour du réseau avec le temps écoulé', () async {
      final api = ApiSansReseau();
      Api.current = api;
      final fin = DateTime(2026, 11, 12, 10, 0);
      await FileEnvoi.garder(seanceMinimale(FileEnvoi.nouvelUuid()), finMs: fin.millisecondsSinceEpoch);
      expect(await FileEnvoi.nombre(), 1);
      expect(await FileEnvoi.envoyer(maintenant: () => fin.add(const Duration(hours: 2))), 0);
      expect(await FileEnvoi.nombre(), 1, reason: 'toujours pas de réseau : gardée');
      api.reseau = true;
      expect(await FileEnvoi.envoyer(maintenant: () => fin.add(const Duration(hours: 3))), 1);
      expect(await FileEnvoi.nombre(), 0);
      expect(api.recus.single['fin_il_y_a_s'], '10800');
    });

    test('une séance refusée par le serveur n\'est pas gardée indéfiniment', () async {
      final api = ApiSansReseau()..reseau = true;
      Api.current = api;
      await FileEnvoi.garder({'discipline': 'x'}); // la démo l'accepte, on simule donc un refus :
      Api.current = _ApiQuiRefuse();
      expect(await FileEnvoi.envoyer(), 0);
      expect(await FileEnvoi.nombre(), 0);
    });
  });

  group('Démo : comme le serveur', () {
    test('renvoi de la même séance : pas de doublon', () async {
      final api = DemoApi();
      final u = FileEnvoi.nouvelUuid();
      final a = await api.saveSeance(seanceMinimale(u));
      final b = await api.saveSeance(seanceMinimale(u));
      expect(b['session_id'], a['session_id']);
      expect(b['deja_enregistree'], isTrue);
    });

    test('la liste n\'a pas le tracé, le détail oui', () async {
      final api = DemoApi();
      final liste = (await api.getSeances())['seances'] as List;
      final course = liste.firstWhere((s) => s['discipline'] == 'Running') as Map;
      expect(course['trace'], isNull);
      final detail = ((await api.getSeance(course['id'] as int))['seances'] as List).single as Map;
      expect((detail['trace'] as List).length, greaterThan(100));
    });

    test('export de mes données', () async {
      final r = await DemoApi().exporterDonnees();
      expect(r['status'], 'success');
      expect((r['seances'] as List).length, greaterThanOrEqualTo(15)); // dépend du jour de la semaine
      expect(jsonEncode(r).contains('password'), isFalse);
    });

    test('suppression du compte impossible en démo', () async {
      expect((await DemoApi().supprimerCompte('x'))['status'], 'error');
    });
  });

  group('Carnet PDF', () {
    test('texte sans caractères hors de la police standard', () {
      expect(ExportPdf.texteSur('Fatigue ≥ 7 — « genou » œdème 😀'), 'Fatigue >= 7 - « genou » oedème ?');
    });

    test('le PDF est produit avec les 18 séances de la démo', () async {
      final octets = await ExportPdf.construire(seancesDemo(derniere: DateTime(2026, 11, 8, 20)), pseudo: 'Athlète démo', le: DateTime(2026, 11, 12));
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
      expect(octets.length, greaterThan(5000));
      final dossier = Directory('build/test');
      dossier.createSync(recursive: true);
      File('build/test/carnet-demo.pdf').writeAsBytesSync(octets);
    });
  });
}

class _ApiQuiRefuse extends DemoApi {
  @override
  Future<Map<String, dynamic>> saveSeance(Map<String, String> seance) async =>
      {"status": "error", "message": "Champ manquant : duree_s"};
}
