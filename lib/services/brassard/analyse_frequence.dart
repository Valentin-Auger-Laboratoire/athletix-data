import 'dart:math';
import 'dart:typed_data';

/// Fréquence médiane (MDF) d'une fenêtre de signal EMG brut : COPIE en Dart de
/// hardware/firmware-brassard/calcul_fatigue.h (mêmes choix, mêmes tests, voir FATIGUE.md).
///
/// Sert au brassard simulé, qui fabrique un vrai signal brut et le passe dans ce calcul :
/// la démo montre donc une fréquence médiane CALCULÉE, pas inventée.
class AnalyseFrequence {
  AnalyseFrequence({this.n = 1024, this.frequenceHz = 2000}) : assert(n > 1 && (n & (n - 1)) == 0) {
    _hann = Float64List(n);
    for (var i = 0; i < n; i++) {
      _hann[i] = 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
    }
  }

  final int n;
  final double frequenceHz;
  late final Float64List _hann;

  static const double bandeBasseHz = 20;
  static const double bandeHauteHz = 450;
  static const double secteurBasHz = 45;
  static const double secteurHautHz = 55;

  static bool garder(double f) =>
      f >= bandeBasseHz && f <= bandeHauteHz && !(f >= secteurBasHz && f <= secteurHautHz);

  ResultatFrequence analyser(List<double> x) {
    if (x.length != n) throw ArgumentError('$n échantillons attendus, ${x.length} reçus');
    final moyenne = x.reduce((a, b) => a + b) / n;
    final re = Float64List(n), im = Float64List(n);
    for (var i = 0; i < n; i++) {
      re[i] = (x[i] - moyenne) * _hann[i];
    }
    fft(re, im);
    final df = frequenceHz / n;
    final p = Float64List(n ~/ 2);
    var total = 0.0, moment = 0.0;
    for (var k = 1; k < n ~/ 2; k++) {
      final f = k * df;
      p[k] = garder(f) ? re[k] * re[k] + im[k] * im[k] : 0;
      total += p[k];
      moment += p[k] * f;
    }
    if (total <= 0) return const ResultatFrequence(0, 0, 0, valide: false);
    final moitie = total / 2;
    var cumul = 0.0, mdf = 0.0;
    for (var k = 1; k < n ~/ 2; k++) {
      if (p[k] <= 0) continue;
      if (cumul + p[k] >= moitie) {
        mdf = (k - 0.5 + (moitie - cumul) / p[k]) * df;
        break;
      }
      cumul += p[k];
    }
    return ResultatFrequence(mdf, moment / total, total, valide: true);
  }

  /// FFT complexe sur place, radix 2 (même algorithme que le firmware).
  static void fft(Float64List re, Float64List im) {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        var t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }
    for (var longueur = 2; longueur <= n; longueur <<= 1) {
      final angle = -2 * pi / longueur;
      final wr = cos(angle), wi = sin(angle);
      for (var debut = 0; debut < n; debut += longueur) {
        var cr = 1.0, ci = 0.0;
        for (var k = 0; k < longueur ~/ 2; k++) {
          final a = debut + k, b = a + longueur ~/ 2;
          final tr = re[b] * cr - im[b] * ci;
          final ti = re[b] * ci + im[b] * cr;
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
          final ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }
  }
}

class ResultatFrequence {
  const ResultatFrequence(this.mdfHz, this.mnfHz, this.puissance, {required this.valide});
  final double mdfHz;
  final double mnfHz;
  final double puissance;
  final bool valide;
}

/// Générateur reproductible (le MÊME que tests/firmware/test_calcul_fatigue.cpp).
class HasardReproductible {
  HasardReproductible(this.etat);
  int etat;

  double uniforme() {
    etat = (etat * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (etat + 0.5) / 4294967296.0;
  }

  double gauss() {
    final u = uniforme(), v = uniforme();
    return sqrt(-2 * log(u)) * cos(2 * pi * v);
  }
}

/// Passe-bande du 2e ordre (formules « RBJ Audio EQ Cookbook ») : bruit blanc filtré = signal
/// qui ressemble à l'EMG brut. La fatigue est simulée en baissant la fréquence centrale.
class PasseBande {
  PasseBande(double fc, {this.q = 0.7, this.frequenceHz = 2000}) {
    regler(fc);
  }
  final double q;
  final double frequenceHz;
  double _b0 = 0, _b2 = 0, _a1 = 0, _a2 = 0, _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  void regler(double fc) {
    final w = 2 * pi * fc / frequenceHz, alpha = sin(w) / (2 * q), a0 = 1 + alpha;
    _b0 = alpha / a0;
    _b2 = -alpha / a0;
    _a1 = -2 * cos(w) / a0;
    _a2 = (1 - alpha) / a0;
  }

  double filtrer(double x) {
    final y = _b0 * x + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
