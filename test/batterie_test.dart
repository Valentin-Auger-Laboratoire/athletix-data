import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/telephone/batterie_ble.dart';
import 'package:athletix_data/services/telephone/montre_podometre.dart';
import 'package:athletix_data/services/telephone/montre_yoho_simulee.dart';

void main() {
  test('service batterie standard 0x2A19 : un octet de 0 à 100', () {
    expect(BatterieBle.lire([72]), 72);
    expect(BatterieBle.lire([0]), 0);
    expect(BatterieBle.lire([100]), 100);
    expect(BatterieBle.lire([101]), isNull);
    expect(BatterieBle.lire([]), isNull);
  });

  test('icône et couleur par paliers', () {
    expect(iconeBatterie(null), Icons.battery_unknown);
    expect(iconeBatterie(8), Icons.battery_alert);
    expect(iconeBatterie(97), Icons.battery_full);
    expect(iconeBatterie(50), Icons.battery_3_bar);
    expect(couleurBatterie(12), Colors.redAccent);
    expect(couleurBatterie(25), Colors.orangeAccent);
    expect(couleurBatterie(80), Colors.lightGreenAccent);
  });

  test('la batterie de la montre YOHO est recopiée dans la montre (affichée partout)', () async {
    final m = await MontrePodometre.simulee(transport: TransportYohoSimule(vitesse: 40));
    expect(m.batterie.value, 76);
    m.yoho!.batterie.value = 14; // la montre envoie un nouveau niveau (CC03)
    expect(m.batterie.value, 14);
    m.fermer();
  });

  testWidgets('pastille : libellé, niveau et inconnu', (t) async {
    await t.pumpWidget(const MaterialApp(home: Column(children: [PastilleBatterie(72, libelle: 'Montre'), PastilleBatterie(null)])));
    expect(find.text('Montre 72 %'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
