import 'dart:math';

/// Calculs du fond de carte du parcours : projection de Mercator « web » utilisée par les
/// tuiles OpenStreetMap (256 × 256 pixels, https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames).
///
/// Écrit à la main (pas de bibliothèque de cartes) : la carte n'a besoin que de quelques tuiles fixes
/// sous le tracé, sans zoom ni déplacement.
class FondCarte {
  FondCarte._();

  static const int tailleTuile = 256;
  static const int zoomMax = 17; // au-delà : peu d'intérêt pour un parcours, et règles d'usage d'OSM
  static const int zoomMin = 3;

  /// Serveur de tuiles d'OpenStreetMap. Règles d'usage : crédit visible, application identifiée,
  /// pas d'usage intensif (https://operations.osmfoundation.org/policies/tiles/).
  static String urlTuile(int z, int x, int y) => 'https://tile.openstreetmap.org/$z/$x/$y.png';

  static const String credit = '© contributeurs OpenStreetMap';
  static const String lienCredit = 'https://www.openstreetmap.org/copyright';
  static const String agent = 'AthletixData/1.0 (projet etudiant EPISEN)';

  /// Position « monde » en pixels au zoom [z] (0 à 256·2^z).
  static double xMonde(double lon, int z) => (lon + 180) / 360 * tailleTuile * (1 << z);

  static double yMonde(double lat, int z) {
    final l = lat.clamp(-85.05112878, 85.05112878) * pi / 180;
    return (1 - log(tan(l) + 1 / cos(l)) / pi) / 2 * tailleTuile * (1 << z);
  }

  /// Plus grand zoom où le parcours (avec une marge) tient dans [largeur] × [hauteur] pixels.
  static int zoomPour(List<List<num>> points, double largeur, double hauteur, {double marge = 16}) {
    for (var z = zoomMax; z > zoomMin; z--) {
      final xs = points.map((p) => xMonde(p[1].toDouble(), z)), ys = points.map((p) => yMonde(p[0].toDouble(), z));
      final l = xs.reduce(max) - xs.reduce(min), h = ys.reduce(max) - ys.reduce(min);
      if (l <= largeur - 2 * marge && h <= hauteur - 2 * marge) return z;
    }
    return zoomMin;
  }
}

/// Vue de la carte : zoom et coin haut-gauche en pixels « monde », pour une zone de [largeur] × [hauteur].
class VueCarte {
  VueCarte(List<List<num>> points, this.largeur, this.hauteur) : zoom = FondCarte.zoomPour(points, largeur, hauteur) {
    final xs = points.map((p) => FondCarte.xMonde(p[1].toDouble(), zoom));
    final ys = points.map((p) => FondCarte.yMonde(p[0].toDouble(), zoom));
    // Parcours centré dans la zone
    origineX = (xs.reduce(max) + xs.reduce(min)) / 2 - largeur / 2;
    origineY = (ys.reduce(max) + ys.reduce(min)) / 2 - hauteur / 2;
  }

  final double largeur, hauteur;
  final int zoom;
  late final double origineX, origineY;

  /// Position d'un point [lat, lon, …] dans la zone, en pixels.
  (double, double) position(List<num> p) =>
      (FondCarte.xMonde(p[1].toDouble(), zoom) - origineX, FondCarte.yMonde(p[0].toDouble(), zoom) - origineY);

  /// Tuiles qui recouvrent la zone : (x, y, gauche, haut) en pixels dans la zone.
  List<(int, int, double, double)> tuiles() {
    const t = FondCarte.tailleTuile;
    final n = 1 << zoom;
    final x0 = (origineX / t).floor(), y0 = (origineY / t).floor();
    final x1 = ((origineX + largeur) / t).floor(), y1 = ((origineY + hauteur) / t).floor();
    return [
      for (var y = max(0, y0); y <= min(n - 1, y1); y++)
        for (var x = x0; x <= x1; x++) ((x % n + n) % n, y, x * t - origineX, y * t - origineY),
    ];
  }
}
