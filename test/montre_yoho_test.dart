import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/telephone/montre_podometre.dart';
import 'package:athletix_data/services/telephone/montre_yoho.dart';
import 'package:athletix_data/services/telephone/montre_yoho_simulee.dart';
import 'package:athletix_data/services/telephone/protocole_yoho.dart';

void main() {
  group('Commandes envoyées au bracelet (CC06)', () {
    test('cœur, tension, vibration', () {
      expect(ProtocoleYoho.mesureCoeur(true), [0x0A, 0x01]);
      expect(ProtocoleYoho.mesureCoeur(false), [0x0A, 0x00]);
      expect(ProtocoleYoho.mesureTension(true), [0xF1, 0x03, 0x14, 0x01]);
      expect(ProtocoleYoho.mesureTension(false), [0xF1, 0x03, 0x14, 0x00]);
      expect(ProtocoleYoho.trouverBracelet, [0x08, 0x01]);
    });

    test('heure : année sur 2 chiffres', () {
      expect(ProtocoleYoho.heure(DateTime(2026, 11, 13, 21, 26, 59)), [0x04, 0x00, 26, 11, 13, 21, 26, 59]);
    });

    test("rappel d'inactivité : durée sur 2 octets little-endian", () {
      expect(ProtocoleYoho.rappelInactivite(true), [0x07, 1, 60, 0]);
      expect(ProtocoleYoho.rappelInactivite(false, minutes: 300), [0x07, 0, 0x2C, 0x01]);
      expect(() => ProtocoleYoho.rappelInactivite(true, minutes: 0), throwsArgumentError);
    });

    test('profil de Valentin dans l\'appli d\'origine (homme, 20 ans, 170 cm, 60 kg, 8 000 pas, km)', () {
      expect(ProtocoleYoho.profil(homme: true, age: 20, tailleCm: 170, poidsKg: 60),
          [0xF1, 0x01, 0, 20, 170, 60, 0, 0, 0x40, 0x1F]);
      expect(ProtocoleYoho.profil(homme: false, age: 30, tailleCm: 160, poidsKg: 55, objectifPas: 9000, miles: true)[2], 1);
      expect(() => ProtocoleYoho.profil(homme: true, age: 20, tailleCm: 300, poidsKg: 60), throwsArgumentError);
    });

    test('accusés de synchronisation', () {
      expect(ProtocoleYoho.synchroDebut, [0xF4, 0x00]);
      expect(ProtocoleYoho.synchroPaquetRecu(0x0102), [0xF4, 0x02, 0x02, 0x01]);
      expect(ProtocoleYoho.synchroMesuresDebut, [0xF4, 0x04]);
      expect(ProtocoleYoho.synchroMesuresPaquetRecu(5), [0xF4, 0x06, 5, 0]);
    });
  });

  group('Informations de l\'appareil (CC02) et batterie (CC03)', () {
    test('version 82.78.00.3d et fonctions', () {
      final o = List<int>.filled(18, 0);
      o[11] = 0x3d;
      o[12] = 0x82;
      o[13] = 0x78;
      o[14] = 0x00;
      o[15] = 1 << 2; // historique cœur/tension
      o[17] = (1 << 4) | (1 << 5); // cœur + tension
      expect(ProtocoleYoho.versionFirmware(o), '82.78.00.3d');
      final f = ProtocoleYoho.fonctions(o);
      expect(f.coeur && f.tension && f.historiqueMesures && f.nouvelleSynchro, isTrue);
      expect(ProtocoleYoho.versionFirmware([1, 2, 3]), isNull);
      expect(ProtocoleYoho.batterie([42, 0, 0, 0, 0, 0, 0, 1]), 42);
    });
  });

  group('Messages reçus (CC04)', () {
    test('tension : F3 14 systolique diastolique (114/74 vu dans l\'appli)', () {
      final m = ProtocoleYoho.lire([0xF3, 0x14, 114, 74]);
      expect(m, isA<TensionYoho>());
      expect((m as TensionYoho).systolique, 114);
      expect(m.diastolique, 74);
    });

    test('cœur : drapeau bit 5, valeur à l\'octet 10 (67 bpm vu dans l\'appli)', () {
      final o = List<int>.filled(16, 0);
      o[0] = 1 << 5;
      o[10] = 67;
      final m = ProtocoleYoho.lire(o);
      expect(m, isA<CoeurYoho>());
      expect((m as CoeurYoho).bpm, 67);
    });

    test('pas en temps réel : état + compteur sur 4 octets (177 pas)', () {
      final m = ProtocoleYoho.lire([0x00, 0x00, 1, 177, 0, 0, 0]);
      expect(m, isA<PasYoho>());
      expect((m as PasYoho).pas, 177);
      expect(m.etat, EtatActivite.marche);
    });

    test('inactivité, selfie, température, musique, téléphone cherché', () {
      expect(ProtocoleYoho.lire([1 << 2, 0, 0, 0, 0, 0, 0]), isA<InactiviteYoho>());
      expect(ProtocoleYoho.lire([1 << 3, 0, 0, 0, 0, 0, 0]), isA<SelfieYoho>());
      expect((ProtocoleYoho.lire([0xF3, 0x1B, 65]) as TemperatureYoho).degres, closeTo(36.5, 1e-9));
      expect((ProtocoleYoho.lire([0xF5, 2]) as MusiqueYoho).commande, 2);
      expect(ProtocoleYoho.lire([0xF3, 0x18]), isA<TelephoneCherche>());
    });

    test('messages courts ou inconnus ignorés sans erreur', () {
      expect(ProtocoleYoho.lire([]), isNull);
      expect(ProtocoleYoho.lire([0xF3]), isNull);
      expect(ProtocoleYoho.lire([0xF3, 0x14, 1]), isNull);
      expect(ProtocoleYoho.lire([1 << 5, 0, 0]), isNull);
      expect(ProtocoleYoho.lire([0xF4, 0x02, 0, 0, 3, 1]), isNull); // annonce 3 lignes, en contient 0
      expect(ProtocoleYoho.lire([0x80, 0x00, 0, 0, 0, 0, 0]), isNull);
    });

    test('date de base nulle = rien à synchroniser', () {
      final m = ProtocoleYoho.lire([0xF4, 0x01, 0, 0, 0, 0, 0, 0]);
      expect((m as SynchroBase).date, isNull);
    });
  });

  group('Synchronisation complète (sans Bluetooth)', () {
    List<int> paquetActivite(int numero, List<List<int>> lignes) => [
          0xF4, 0x02, numero & 0xFF, numero >> 8, lignes.length,
          for (final l in lignes) ...[l[0], l[1] & 0xFF, l[1] >> 8, l[2] & 0xFF, l[2] >> 8],
        ];

    test('activité + sommeil + mesures, avec les bons accusés', () {
      final s = SynchroYoho(avecMesures: true);
      expect(s.debut, [0xF4, 0x00]);
      final envoyes = <List<int>>[];
      void recoit(List<int> o) => envoyes.addAll(s.recevoir(ProtocoleYoho.lire(o)!));

      // Base : 12/11/2026 21:00:00
      recoit([0xF4, 0x01, 26, 11, 12, 21, 0, 0]);
      // Nuit : léger à 23 h (+120 min), profond à 2 h (+300), léger à 2 h 15 (+315),
      // réveil à 4 h (+420), léger à 4 h 05 (+425), marche à 7 h 21 (+621)
      recoit(paquetActivite(1, [
        [EtatActivite.marche, 0, 50],
        [EtatActivite.sommeilLeger, 120, 0],
        [EtatActivite.sommeilProfond, 300, 0],
      ]));
      recoit(paquetActivite(2, [
        [EtatActivite.sommeilLeger, 315, 0],
        [EtatActivite.reveil, 420, 0],
        [EtatActivite.sommeilLeger, 425, 0],
        [EtatActivite.marche, 621, 127],
      ]));
      recoit([0xF4, 0x03, 1, 0, 0, 177, 0, 26, 11, 13, 7, 30, 0]);
      expect(s.terminee, isFalse); // il reste l'historique des mesures
      recoit([0xF4, 0x05, 26, 11, 13, 21, 0, 0]);
      // 2 mesures : cœur 67 bpm à +1619 s, tension 114/74 à +1619 s
      recoit([0xF4, 0x06, 1, 0, 2, 0x53, 0x06, 0, 0, 67, 0, 0x53, 0x06, 0, 0, 114, 74]);
      recoit([0xF4, 0x07]);
      expect(s.terminee, isTrue);

      expect(envoyes, [
        [0xF4, 0x01],
        [0xF4, 0x02, 1, 0],
        [0xF4, 0x02, 2, 0],
        [0xF4, 0x03],
        [0xF4, 0x04],
        [0xF4, 0x05],
        [0xF4, 0x06, 1, 0],
        [0xF4, 0x07],
      ]);
      expect(s.periodes, hasLength(7));
      expect(s.periodes[1].debut, DateTime(2026, 11, 12, 23));
      expect(s.mesures[0].bpm, 67);
      expect(s.mesures[0].date, DateTime(2026, 11, 13, 21, 26, 59));
      expect(s.mesures[1].systolique, 114);
      expect(s.mesures[1].diastolique, 74);

      final nuit = NuitYoho.calculer(s.periodes, DateTime(2026, 11, 13, 10))!;
      expect(nuit.profond, const Duration(minutes: 15));
      // léger : 23 h → 2 h (180) + 2 h 15 → 4 h (105) + 4 h 05 → 7 h 21 (196) = 481 min = 8 h 01
      expect(nuit.leger, const Duration(minutes: 481));
      expect(nuit.reveils, 1);
      expect(nuit.total, const Duration(hours: 8, minutes: 16));
    });

    test('bracelet sans historique de mesures : fin après l\'état actuel', () {
      final s = SynchroYoho(avecMesures: false);
      s.recevoir(ProtocoleYoho.lire([0xF4, 0x01, 0, 0, 0, 0, 0, 0])!);
      final r = s.recevoir(ProtocoleYoho.lire([0xF4, 0x03, 0, 0, 0, 0, 0, 26, 11, 13, 7, 30, 0])!);
      expect(r, [
        [0xF4, 0x03]
      ]);
      expect(s.terminee, isTrue);
      expect(s.periodes, isEmpty);
    });

    test('pas de sommeil : pas de nuit', () {
      final p = [PeriodeActivite(DateTime(2026, 11, 13, 1), EtatActivite.marche, 10), PeriodeActivite(DateTime(2026, 11, 13, 2), EtatActivite.immobile, 0)];
      expect(NuitYoho.calculer(p, DateTime(2026, 11, 13, 10)), isNull);
    });
  });

  group('Bracelet MSGM115 simulé, de bout en bout (mêmes octets que le vrai)', () {
    test('firmware, cœur, tension, pas, vibration et nuit', () async {
      final t = TransportYohoSimule(vitesse: 40);
      final m = await MontrePodometre.simulee(transport: t);
      final y = m.yoho!;
      expect(y.firmware, '82.78.00.3d');
      expect(y.batterie.value, 76);
      expect(y.fonctions.coeur && y.fonctions.tension, isTrue);

      final bpm = await y.mesurerCoeur();
      expect(bpm, inInclusiveRange(64, 72));
      expect(y.coeur.value, bpm);

      final tension = await y.mesurerTension();
      expect(tension.systolique, inInclusiveRange(112, 116));
      expect(y.tension.value, isNotNull);

      await y.faireVibrer();
      expect(t.vibre, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(m.derniere.value?.pas, greaterThan(177));

      final s = await y.synchroniser();
      expect(s.periodes, hasLength(10));
      expect(s.mesures, hasLength(2));
      final nuit = y.nuit.value!;
      expect(nuit.profond, const Duration(minutes: 15));
      expect(nuit.leger, const Duration(minutes: 482));
      expect(nuit.reveils, 1);
      m.fermer();
    });
  });
}
