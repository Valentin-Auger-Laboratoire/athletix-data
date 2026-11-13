import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/brassard/brassard_ble.dart';

void main() {
  test('code d\'appairage : 6 chiffres de 100000 à 999999, comme le firmware (securite.h)', () {
    expect(BrassardBle.codeValide('123456'), isTrue);
    expect(BrassardBle.codeValide(' 999999 '), isTrue);
    expect(BrassardBle.codeValide('100000'), isTrue);
    expect(BrassardBle.codeValide('099999'), isFalse, reason: 'le firmware ne tire jamais de code commençant par 0');
    expect(BrassardBle.codeValide('12345'), isFalse);
    expect(BrassardBle.codeValide('1234567'), isFalse);
    expect(BrassardBle.codeValide('12a456'), isFalse);
    expect(BrassardBle.codeValide(''), isFalse);
  });
}
