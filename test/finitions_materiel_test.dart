import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/codec_gatt.dart';
import 'package:athletix_data/services/telephone/cardio.dart';

void main() {
  test('avertissements du brassard transmis à l\'écran de séance (batterie, interrupteur)', () async {
    final b = BrassardSimule(hasard: Random(1));
    final recus = <EtatLu>[];
    final ab = b.etats.listen(recus.add);
    b.simulerAvertissement(2);
    b.simulerAvertissement(5);
    b.simulerAvertissement(0);
    await Future<void>.delayed(Duration.zero);
    expect(recus.map((e) => e.codeErreur), [2, 5, 0]);
    expect(recus[0].message, contains('batterie'));
    expect(recus[1].message, contains('RAW'));
    await ab.cancel();
    b.fermer();
  });

  test('calibration datée : le rappel avant la séance sait si elle a été faite', () async {
    final b = BrassardSimule(hasard: Random(2));
    expect(b.calibreLe, isNull);
    await b.calibrer(duree: const Duration(milliseconds: 10));
    expect(DateTime.now().difference(b.calibreLe!).inSeconds, lessThan(2));
    expect(b.reconnexion.value, isFalse, reason: 'le brassard simulé ne perd jamais la liaison');
    b.fermer();
  });

  test('montre qui diffuse sa fréquence cardiaque : même format que la ceinture (0x2A37)', () {
    expect(CeintureCardio.lireMesure([0x00, 72]), 72); // 8 bits
    expect(CeintureCardio.lireMesure([0x01, 0x2C, 0x01]), 300); // 16 bits
    expect(CeintureCardio.lireMesure([0x16, 64, 0x10, 0x03]), 64); // contact peau + intervalles RR (montres)
  });
}
