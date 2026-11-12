// Tests du format Bluetooth (architecture/GATT.md) et du résumé de séance.
// Lancer avec : flutter test
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/brassard/resume_seance.dart';

MesureEmg m(int ms, int pct, {bool alerte = false}) =>
    MesureEmg(horodatageMs: ms, rmsMv: pct * 1850 ~/ 100, intensitePct: pct, alerte: alerte);

void main() {
  group('MesureEmg (paquet de 8 octets)', () {
    test("décode l'exemple de GATT.md", () {
      final mesure = MesureEmg.depuisOctets([0xe8, 0x03, 0x00, 0x00, 0x9e, 0x02, 0x2a, 0x00]);
      expect(mesure.horodatageMs, 1000);
      expect(mesure.rmsMv, 670);
      expect(mesure.intensitePct, 42);
      expect(mesure.alerte, isFalse);
    });

    test('encode puis décode sans rien perdre', () {
      const origine = MesureEmg(
        horodatageMs: 4000000000, // proche du maximum d'un uint32
        rmsMv: 1998,
        intensitePct: 108,
        alerte: true,
        saturation: false,
        calibrationEnCours: true,
      );
      final octets = origine.versOctets();
      expect(octets.length, 8);
      final relu = MesureEmg.depuisOctets(octets);
      expect(relu.horodatageMs, 4000000000);
      expect(relu.rmsMv, 1998);
      expect(relu.intensitePct, 108);
      expect(relu.alerte, isTrue);
      expect(relu.saturation, isFalse);
      expect(relu.calibrationEnCours, isTrue);
    });

    test('les drapeaux sont bien placés (octet 7)', () {
      expect(const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 0, alerte: true).versOctets()[7], 0x01);
      expect(const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 0, saturation: true).versOctets()[7], 0x02);
      expect(const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 0, calibrationEnCours: true).versOctets()[7],
          0x04);
    });

    test("plafonne l'intensité à 255", () {
      final octets = const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 400).versOctets();
      expect(octets[6], 255);
    });

    test('refuse un paquet de mauvaise taille', () {
      expect(() => MesureEmg.depuisOctets([1, 2, 3]), throwsFormatException);
    });

    test('découpe une notification qui groupe 2 paquets', () {
      final notification = [...m(0, 10).versOctets(), ...m(20, 20).versOctets()];
      final mesures = MesureEmg.depuisNotification(notification);
      expect(mesures.map((x) => x.intensitePct), [10, 20]);
      expect(() => MesureEmg.depuisNotification(notification.sublist(0, 12)), throwsFormatException);
    });
  });

  group('ResumeSeance', () {
    test('moyenne, maximum, durée', () {
      final resume = ResumeSeance();
      for (var i = 0; i <= 50; i++) {
        resume.ajouter(m(i * 20, i < 25 ? 40 : 60)); // 1 s à 50 Hz
      }
      expect(resume.nbEchantillons, 51);
      expect(resume.dureeS, 1);
      expect(resume.intensiteMaxPct, 60);
      expect(resume.intensiteMoyennePct, 50);
    });

    test("compte une alerte quand elle s'allume, pas à chaque mesure", () {
      final resume = ResumeSeance();
      var t = 0;
      for (final alerte in [false, true, true, true, false, false, true, true, false]) {
        resume.ajouter(m(t, alerte ? 90 : 30, alerte: alerte));
        t += 500;
      }
      expect(resume.nbAlertes, 2);
      // 3 intervalles de 500 ms puis 2 intervalles de 500 ms en alerte = 2,5 s
      expect(resume.tempsEffortIntenseS, 3); // 2,5 arrondi
      expect(resume.tempsEffortIntenseS <= resume.dureeS, isTrue);
    });

    test("une coupure de liaison n'est pas comptée comme effort intense", () {
      final resume = ResumeSeance()
        ..ajouter(m(0, 90, alerte: true))
        ..ajouter(m(5000, 90, alerte: true)); // 5 s sans nouvelles
      expect(resume.tempsEffortIntenseS, 0);
      expect(resume.dureeS, 5);
    });

    test('ignore les mesures prises pendant une calibration', () {
      final resume = ResumeSeance()
        ..ajouter(const MesureEmg(horodatageMs: 0, rmsMv: 0, intensitePct: 100, calibrationEnCours: true))
        ..ajouter(m(20, 30));
      expect(resume.nbEchantillons, 1);
      expect(resume.intensiteMaxPct, 30);
    });

    test("versApi produit les champs de save_seance.php", () {
      final resume = ResumeSeance(refMvcMv: 1850)
        ..ajouter(m(0, 40))
        ..ajouter(m(20, 80, alerte: true));
      final champs = resume.versApi(discipline: 'Musculation', simule: true);
      expect(champs['discipline'], 'Musculation');
      expect(champs['duree_s'], '1'); // au moins 1 s pour le serveur
      expect(champs['intensite_max_pct'], '80');
      expect(champs['nb_alertes'], '1');
      expect(champs['simule'], '1');
      expect(champs['ref_mvc_mv'], '1850');
      expect(champs.containsKey('numero_serie'), isFalse);
    });
  });

  group('BrassardSimule', () {
    test("suit le profil d'effort de la simulation Simulink", () {
      expect(BrassardSimule.effortVise(1), 0);
      expect(BrassardSimule.effortVise(5), 40);
      expect(BrassardSimule.effortVise(8), 95);
      expect(BrassardSimule.effortVise(12), 50);
      expect(BrassardSimule.effortVise(18 + 8), 95); // le cycle recommence
    });

    test('envoie des mesures après démarrer(), plus après arreter()', () async {
      final brassard = BrassardSimule(hasard: Random(1));
      final recues = <MesureEmg>[];
      final abonnement = brassard.mesures.listen(recues.add);
      await brassard.demarrer();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await brassard.arreter();
      final nombre = recues.length;
      expect(nombre, greaterThan(2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(recues.length, nombre);
      await abonnement.cancel();
      brassard.fermer();
    });
  });
}
