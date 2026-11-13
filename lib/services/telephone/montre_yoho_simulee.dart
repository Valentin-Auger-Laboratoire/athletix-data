import 'dart:async';
import 'dart:math';

import 'montre_yoho.dart';
import 'protocole_yoho.dart';

/// Bracelet MSGM115 SIMULÉ, pour la démo et les captures du README.
///
/// Il répond aux commandes avec les MÊMES OCTETS que le vrai bracelet (format du service CC00,
/// voir architecture/BRACELET-YOHO.md) : l'appli les décode avec le même code que pour le vrai
/// bracelet (ProtocoleYoho.lire, SynchroYoho). Les valeurs (cœur, tension, nuit) sont FICTIVES,
/// choisies proches de celles vues dans l'appli d'origine sur le bracelet de Valentin.
class TransportYohoSimule extends TransportYoho {
  TransportYohoSimule({Random? hasard, this.vitesse = 1}) : _hasard = hasard ?? Random();

  final Random _hasard;

  /// > 1 pour accélérer les délais (tests).
  final int vitesse;
  final StreamController<List<int>> _tempsReel = StreamController<List<int>>.broadcast();
  final List<Timer> _minuteurs = [];
  int _pas = 177;
  int _paquetSuivant = 0;
  late List<List<int>> _paquetsActivite;
  bool vibre = false;

  @override
  Stream<List<int>> get tempsReel => _tempsReel.stream;

  @override
  Stream<List<int>> get batterie => const Stream.empty();

  /// CC02 : firmware 82.78.00.3d (celui du bracelet de Valentin), cœur + tension + historique des mesures.
  @override
  Future<List<int>?> lireInfos() async {
    final o = List<int>.filled(18, 0);
    o[11] = 0x3d;
    o[12] = 0x82;
    o[13] = 0x78;
    o[15] = 1 << 2;
    o[17] = (1 << 4) | (1 << 5);
    return o;
  }

  @override
  Future<List<int>?> lireBatterie() async => [76, 0, 0, 0, 0, 0, 0, 0];

  @override
  Future<void> activer() async {
    // Le compteur de pas avance comme si on marchait un peu
    _minuteurs.add(Timer.periodic(Duration(milliseconds: 3000 ~/ vitesse), (_) {
      _pas += 2 + _hasard.nextInt(5);
      _envoyer([0x00, 0x00, EtatActivite.marche, _pas & 0xFF, (_pas >> 8) & 0xFF, 0, 0]);
    }));
  }

  void _envoyer(List<int> o) {
    if (!_tempsReel.isClosed) _tempsReel.add(o);
  }

  void _plusTard(int ms, void Function() f) => _minuteurs.add(Timer(Duration(milliseconds: ms ~/ vitesse), f));

  List<int> _coeur(int bpm) {
    final o = List<int>.filled(16, 0);
    o[0] = 1 << 5;
    o[10] = bpm;
    return o;
  }

  static List<int> _date(DateTime t) => [t.year % 2000, t.month, t.day, t.hour, t.minute, t.second];

  /// Nuit fictive (base = la veille à 21 h) : coucher 23 h 10, sommeil profond vers 1 h 40 et 5 h,
  /// un réveil vers 3 h 50, lever 7 h 31. États : voir EtatActivite.
  static const List<List<int>> _nuit = [
    [EtatActivite.marche, 0, 950],
    [EtatActivite.immobile, 95, 0],
    [EtatActivite.sommeilLeger, 130, 0],
    [EtatActivite.sommeilProfond, 280, 0],
    [EtatActivite.sommeilLeger, 290, 0],
    [EtatActivite.reveil, 410, 0],
    [EtatActivite.sommeilLeger, 414, 0],
    [EtatActivite.sommeilProfond, 480, 0],
    [EtatActivite.sommeilLeger, 485, 0],
    [EtatActivite.marche, 631, 177],
  ];

  List<List<int>> _decouper() {
    final paquets = <List<int>>[];
    for (var i = 0; i < _nuit.length; i += 3) {
      final lignes = _nuit.sublist(i, min(i + 3, _nuit.length));
      final n = paquets.length + 1;
      paquets.add([
        0xF4, 0x02, n & 0xFF, n >> 8, lignes.length,
        for (final l in lignes) ...[l[0], l[1] & 0xFF, l[1] >> 8, l[2] & 0xFF, l[2] >> 8],
      ]);
    }
    return paquets;
  }

  @override
  Future<void> ecrire(List<int> c) async {
    if (c.length >= 2 && c[0] == 0x0A && c[1] == 1) {
      _plusTard(400, () => _envoyer(_coeur(0))); // mesure en cours
      _plusTard(4000, () => _envoyer(_coeur(64 + _hasard.nextInt(9))));
    } else if (c.length >= 4 && c[0] == 0xF1 && c[1] == 0x03 && c[2] == 0x14 && c[3] == 1) {
      _plusTard(5000, () => _envoyer([0xF3, 0x14, 112 + _hasard.nextInt(5), 72 + _hasard.nextInt(4)]));
    } else if (c.length >= 2 && c[0] == 0x08) {
      vibre = true;
    } else if (c.length >= 2 && c[0] == 0xF4) {
      _synchro(c);
    }
  }

  void _synchro(List<int> c) {
    final maintenant = DateTime.now();
    final hier21h = DateTime(maintenant.year, maintenant.month, maintenant.day).subtract(const Duration(hours: 3));
    switch (c[1]) {
      case 0x00:
        _paquetsActivite = _decouper();
        _paquetSuivant = 0;
        _plusTard(150, () => _envoyer([0xF4, 0x01, ..._date(hier21h)]));
      case 0x01:
      case 0x02:
        if (_paquetSuivant < _paquetsActivite.length) {
          final p = _paquetsActivite[_paquetSuivant++];
          _plusTard(150, () => _envoyer(p));
        } else {
          _plusTard(150, () => _envoyer([0xF4, 0x03, EtatActivite.marche, 0, 0, _pas & 0xFF, _pas >> 8, ..._date(maintenant)]));
        }
      case 0x04:
        _plusTard(150, () => _envoyer([0xF4, 0x05, ..._date(hier21h)]));
      case 0x05:
        // Deux mesures de la veille au soir : cœur 67 bpm et tension 114/74 à 21 h 26 min 59 s
        _plusTard(150, () => _envoyer([0xF4, 0x06, 1, 0, 2, 0x53, 0x06, 0, 0, 67, 0, 0x53, 0x06, 0, 0, 114, 74]));
      case 0x06:
        _plusTard(150, () => _envoyer([0xF4, 0x07]));
    }
  }

  @override
  void fermer() {
    for (final m in _minuteurs) {
      m.cancel();
    }
    _tempsReel.close();
  }
}
