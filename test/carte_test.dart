import 'package:flutter_test/flutter_test.dart';
import 'package:athletix_data/services/telephone/fond_carte.dart';

void main() {
  group('Fond de carte (tuiles OpenStreetMap, Mercator)', () {
    test('tuile de Paris (Notre-Dame) au zoom 15 : 16597 / 11273 (valeurs du wiki OSM)', () {
      expect((FondCarte.xMonde(2.3499, 15) / 256).floor(), 16597);
      expect((FondCarte.yMonde(48.8530, 15) / 256).floor(), 11273);
    });

    test('bords du monde', () {
      expect(FondCarte.xMonde(-180, 0), 0);
      expect(FondCarte.xMonde(180, 0), 256);
      expect(FondCarte.yMonde(0, 0), closeTo(128, 1e-9));
      expect(FondCarte.yMonde(90, 2), closeTo(0, 1e-6), reason: 'latitude bornée à 85,05°');
    });

    final parcours = [
      [48.8350, 2.4350, 0, 40],
      [48.8420, 2.4480, 300, 55],
      [48.8300, 2.4520, 600, 60],
    ];

    test('zoom : le plus grand où le parcours tient dans la zone', () {
      final z = FondCarte.zoomPour(parcours, 360, 220);
      double hauteur(int z) => FondCarte.yMonde(48.8300, z) - FondCarte.yMonde(48.8420, z);
      expect(hauteur(z), lessThanOrEqualTo(220 - 32));
      expect(hauteur(z + 1), greaterThan(220 - 32), reason: 'au zoom suivant, il ne tiendrait plus');
      expect(FondCarte.zoomPour([parcours[0], parcours[0]], 360, 220), FondCarte.zoomMax, reason: 'un seul point : zoom maximal');
    });

    test('vue : parcours centré, tous les points dans la zone, tuiles qui la recouvrent', () {
      final v = VueCarte(parcours, 360, 220);
      for (final p in parcours) {
        final (x, y) = v.position(p);
        expect(x, inInclusiveRange(0, 360));
        expect(y, inInclusiveRange(0, 220));
      }
      final tuiles = v.tuiles();
      // Chaque pixel de la zone est couvert par une tuile
      for (final (px, py) in [(0.0, 0.0), (359.0, 0.0), (0.0, 219.0), (359.0, 219.0), (180.0, 110.0)]) {
        expect(tuiles.where((t) => px >= t.$3 && px < t.$3 + 256 && py >= t.$4 && py < t.$4 + 256).length, 1);
      }
      expect(tuiles.length, lessThanOrEqualTo(6), reason: 'quelques tuiles seulement (règles d\'usage d\'OSM)');
    });

    test('adresse des tuiles et crédit', () {
      expect(FondCarte.urlTuile(15, 16597, 11273), 'https://tile.openstreetmap.org/15/16597/11273.png');
      expect(FondCarte.credit, contains('OpenStreetMap'));
    });
  });
}
