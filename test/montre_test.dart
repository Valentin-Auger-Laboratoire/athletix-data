import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/telephone/montre_podometre.dart';

void main() {
  group('Bracelet podomètre (FEE7 / FEA1, format WeChat)', () {
    test('valeurs réelles du bracelet MSGM115 (nRF Connect, 13 nov. 2026)', () {
      expect(MontrePodometre.lire([0x01, 0x00, 0x00, 0x00])!.pas, 0);
      final apres = MontrePodometre.lire([0x01, 0x50, 0x00, 0x00])!;
      expect(apres.pas, 80, reason: '80 pas faits, 80 affichés par le bracelet');
      expect(apres.distanceM, isNull);
      expect(apres.calories, isNull);
    });

    test('pas, distance et calories quand le bracelet les envoie', () {
      final m = MontrePodometre.lire([0x07, 0x10, 0x27, 0x00, 0x40, 0x1F, 0x00, 0xC8, 0x01, 0x00])!;
      expect(m.pas, 10000);
      expect(m.distanceM, 8000);
      expect(m.calories, 456);
      expect(MontrePodometre.lire([0x01, 0xFF, 0xFF, 0xFF])!.pas, 16777215, reason: '3 octets');
    });

    test('valeur trop courte ou vide : ignorée', () {
      expect(MontrePodometre.lire([]), isNull);
      expect(MontrePodometre.lire([0x01, 0x50]), isNull);
      expect(MontrePodometre.lire([0x03, 0x50, 0x00, 0x00]), isNull, reason: 'distance annoncée mais absente');
    });

    test('pas de la séance = augmentations du compteur, remise à zéro à minuit', () {
      final s = PasSeance();
      expect(s.pas, 0);
      s.ajouter(1200); // compteur au départ : pas faits avant la séance
      s.ajouter(1250);
      s.ajouter(1250);
      s.ajouter(1400);
      expect(s.pas, 200);
      s.ajouter(30); // minuit : le bracelet repart de 0 et en est à 30
      s.ajouter(100);
      expect(s.pas, 300);
    });
  });
}
