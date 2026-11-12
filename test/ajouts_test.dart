import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/codec_gatt.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/brassard/resume_seance.dart';
import 'package:athletix_data/services/demo_api.dart';

void main() {
  group('Configuration (GATT.md §6)', () {
    test('lit les 5 octets en little-endian', () {
      // seuil haut 75, seuil bas 70, ref 1850 mV (0x073A), 50 Hz
      final c = ConfigurationBrassard.depuisOctets([75, 70, 0x3A, 0x07, 50]);
      expect(c.seuilHaut, 75);
      expect(c.seuilBas, 70);
      expect(c.refMvcMv, 1850);
      expect(c.frequenceHz, 50);
    });

    test('écrit puis relit sans rien perdre', () {
      const c = ConfigurationBrassard(seuilHaut: 80, seuilBas: 60, refMvcMv: 3300, frequenceHz: 25);
      final relue = ConfigurationBrassard.depuisOctets(c.versOctets());
      expect([relue.seuilHaut, relue.seuilBas, relue.refMvcMv, relue.frequenceHz], [80, 60, 3300, 25]);
    });

    test('ignore les octets en plus, refuse un paquet trop court', () {
      expect(ConfigurationBrassard.depuisOctets([75, 70, 0x3A, 0x07, 50, 99, 99]).refMvcMv, 1850);
      expect(() => ConfigurationBrassard.depuisOctets([75, 70]), throwsFormatException);
    });
  });

  group('État (GATT.md §7)', () {
    test('lit état et code d\'erreur', () {
      final e = EtatLu.depuisOctets([3, 3]);
      expect(e.etat, EtatBrassard.erreur);
      expect(e.codeErreur, 3);
      expect(e.message, contains('signal trop faible'));
    });

    test('un état inconnu est traité comme une erreur', () {
      expect(EtatLu.depuisOctets([9]).etat, EtatBrassard.erreur);
      expect(EtatLu.depuisOctets([1]).etat, EtatBrassard.mesure);
    });
  });

  group('Commandes (GATT.md §5)', () {
    test('codes des commandes', () {
      expect(CommandeBrassard.demarrer(), [0x01]);
      expect(CommandeBrassard.arreter(), [0x02]);
      expect(CommandeBrassard.calibrer(), [0x03]);
      expect(CommandeBrassard.reglerSeuil(80, 65), [0x04, 80, 65]);
    });

    test('refuse un seuil bas supérieur ou égal au seuil haut', () {
      expect(() => CommandeBrassard.reglerSeuil(70, 70), throwsArgumentError);
      expect(() => CommandeBrassard.reglerSeuil(60, 70), throwsArgumentError);
    });
  });

  group('Brassard simulé : calibration', () {
    test('la nouvelle référence reste à ± 5 % de 1 850 mV', () async {
      final b = BrassardSimule();
      for (var i = 0; i < 20; i++) {
        final ref = await b.calibrer(duree: Duration.zero);
        expect(ref, inInclusiveRange(1757, 1943));
        expect(b.refMvcMv, ref);
      }
      expect(b.batteriePct, isNull);
      b.fermer();
    });

    test('les mesures prises pendant la calibration portent le drapeau', () async {
      final b = BrassardSimule();
      final recues = <MesureEmg>[];
      final abo = b.mesures.listen(recues.add);
      await b.demarrer();
      final calibration = b.calibrer(duree: const Duration(milliseconds: 200));
      await Future.delayed(const Duration(milliseconds: 120));
      expect(recues.any((m) => m.calibrationEnCours), isTrue);
      await calibration;
      recues.clear();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(recues, isNotEmpty);
      expect(recues.every((m) => !m.calibrationEnCours), isTrue);
      await abo.cancel();
      b.fermer();
    });
  });

  test('versApi envoie la batterie quand elle est connue', () {
    final r = ResumeSeance(refMvcMv: GattAthletix.refMvcDefautMv)
      ..ajouter(const MesureEmg(horodatageMs: 0, rmsMv: 500, intensitePct: 27))
      ..ajouter(const MesureEmg(horodatageMs: 2000, rmsMv: 600, intensitePct: 32));
    expect(r.versApi(discipline: 'Running', simule: false, batteriePct: 64)['batterie'], '64');
    expect(r.versApi(discipline: 'Running', simule: false).containsKey('batterie'), isFalse);
  });

  group('Mode démo', () {
    test("une séance enregistrée apparaît en tête de l'historique", () async {
      final api = DemoApi();
      final avant = (await api.getSeances())['seances'] as List;
      await api.saveSeance({
        'discipline': 'Boxe', 'duree_s': '120', 'nb_echantillons': '6000', 'intensite_moyenne_pct': '55',
        'intensite_max_pct': '99', 'temps_effort_intense_s': '20', 'nb_alertes': '3', 'simule': '1',
      });
      final apres = (await api.getSeances())['seances'] as List;
      expect(apres.length, avant.length + 1);
      expect(apres.first['discipline'], 'Boxe');
      expect(apres.first['donnees_simulees'], isTrue);
      expect(apres.first['intensite_max_pct'], 99);
    });

    test('le classement de démo indique le nombre de séances', () async {
      final c = await DemoApi().getClassement();
      expect(c, isNotEmpty);
      expect(c.every((a) => a['nb_seances'] is int), isTrue);
    });
  });
}
