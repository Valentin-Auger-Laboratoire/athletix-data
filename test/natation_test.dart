import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/codec_gatt.dart';
import 'package:athletix_data/services/brassard/hors_ligne.dart';

String hex(List<int> o) => o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('Enregistrement sans connexion (GATT §11)', () {
    test('mêmes octets que le firmware (calcul_emg.h) sur le même scénario', () {
      // Scénario identique au programme C++ : 10 min de nage (37 à 43 %, effort intense de 60 à 120 s),
      // puis 6 min au bord. Octets attendus = sortie du firmware compilé sur ordinateur.
      final e = EnregistrementHorsLigne();
      const t = 5000;
      e.demarrer(t);
      for (var ms = 0; ms <= 600000; ms += 20) {
        final fort = ms >= 60000 && ms < 120000;
        e.ajouter(t + ms, fort ? 90 : (ms ~/ 20) % 7 + 37, fort);
      }
      const fin = t + 600000;
      for (var ms = 20; ms <= 360000; ms += 20) {
        e.ajouter(fin + ms, 2, false);
      }
      expect(hex(e.encoder(fin + 20 + 3600000)),
          '01025802317500002d5a3c000100100e00001e1428285a5a28282828282828282828282828282828');
    });

    test('lecture du résumé', () {
      final r = ResumeHorsLigne.depuisOctets(
          [1, 2, 0x58, 0x02, 0x31, 0x75, 0, 0, 0x2d, 0x5a, 0x3c, 0, 1, 0, 0x10, 0x0e, 0, 0, 30, 2, 40, 90]);
      expect(r.etat, ResumeHorsLigne.termine);
      expect(r.dureeS, 600);
      expect(r.nbEchantillons, 30001);
      expect(r.intensiteMoyennePct, 45);
      expect(r.intensiteMaxPct, 90);
      expect(r.tempsEffortIntenseS, 60);
      expect(r.nbAlertes, 1);
      expect(r.finIlYaS, 3600);
      expect(r.courbe, [40, 90]);
      final api = r.versApi(discipline: 'Natation', simule: false, numeroSerie: 'AX-1');
      expect(api['fin_il_y_a_s'], '3600');
      expect(api['courbe'], '[40,40,40,40,40,40,90,90,90,90,90,90]'); // 30 s → 6 valeurs de 5 s
      expect(api['simule'], '0');
    });

    test('résumé tronqué ou trop court refusé', () {
      expect(() => ResumeHorsLigne.depuisOctets([1, 2, 3]), throwsFormatException);
      expect(() => ResumeHorsLigne.depuisOctets([...List.filled(19, 0), 5, 1]), throwsFormatException);
    });

    test('commandes 0x05 et 0x06', () {
      expect(CommandeBrassard.demarrerHorsLigne(), [0x05]);
      expect(CommandeBrassard.effacerHorsLigne(), [0x06]);
    });

    test('brassard simulé : la nage continue sans écouter les mesures, puis se récupère', () async {
      final b = BrassardSimule()..accelerationHorsLigne = 60;
      await b.demarrerHorsLigne();
      await Future.delayed(const Duration(seconds: 3)); // ≈ 3 min de nage simulée
      final enCours = await b.lireHorsLigne();
      expect(enCours.etat, ResumeHorsLigne.enCours);
      await b.arreter();
      final r = await b.lireHorsLigne();
      expect(r.etat, ResumeHorsLigne.termine);
      expect(r.dureeS, inInclusiveRange(150, 200));
      expect(r.intensiteMoyennePct, inInclusiveRange(30, 50)); // longueurs à 45 %, virages à 15 %
      expect(r.courbe.length, inInclusiveRange(5, 6));
      await b.effacerHorsLigne();
      expect((await b.lireHorsLigne()).etat, ResumeHorsLigne.vide);
      b.fermer();
    });

    test('profil de nage : jamais au repos (pas d\'arrêt automatique pendant la nage)', () {
      for (var s = 0; s < 600; s++) {
        expect(BrassardSimule.effortNage(s.toDouble()), greaterThanOrEqualTo(15));
      }
    });
  });
}
