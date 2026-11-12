import 'dart:typed_data';

/// Résumé d'une séance enregistrée SANS connexion (natation), lu dans la caractéristique
/// abad0005 (architecture/GATT.md §11). Le brassard calcule lui-même ce résumé.
class ResumeHorsLigne {
  const ResumeHorsLigne({
    required this.etat,
    required this.dureeS,
    required this.nbEchantillons,
    required this.intensiteMoyennePct,
    required this.intensiteMaxPct,
    required this.tempsEffortIntenseS,
    required this.nbAlertes,
    required this.finIlYaS,
    required this.pasCourbeS,
    required this.courbe,
  });

  static const int vide = 0, enCours = 1, termine = 2;

  final int etat;
  final int dureeS;
  final int nbEchantillons;
  final int intensiteMoyennePct;
  final int intensiteMaxPct;
  final int tempsEffortIntenseS;
  final int nbAlertes;

  /// Secondes écoulées depuis la fin de la séance, au moment de la lecture.
  final int finIlYaS;
  final int pasCourbeS;
  final List<int> courbe;

  factory ResumeHorsLigne.depuisOctets(List<int> octets) {
    if (octets.length < 20) throw FormatException('Résumé hors ligne de ${octets.length} octets, 20 au moins');
    final d = ByteData.sublistView(Uint8List.fromList(octets));
    final nbPoints = d.getUint8(19);
    if (octets.length < 20 + nbPoints) throw const FormatException('Résumé hors ligne tronqué');
    return ResumeHorsLigne(
      etat: d.getUint8(1),
      dureeS: d.getUint16(2, Endian.little),
      nbEchantillons: d.getUint32(4, Endian.little),
      intensiteMoyennePct: d.getUint8(8),
      intensiteMaxPct: d.getUint8(9),
      tempsEffortIntenseS: d.getUint16(10, Endian.little),
      nbAlertes: d.getUint16(12, Endian.little),
      finIlYaS: d.getUint32(14, Endian.little),
      pasCourbeS: d.getUint8(18),
      courbe: octets.sublist(20, 20 + nbPoints),
    );
  }

  /// Champs de save_seance.php. La courbe du serveur a une valeur toutes les 5 s :
  /// chaque point (30 s) est répété.
  Map<String, String> versApi({required String discipline, required bool simule, String? numeroSerie, String? firmware,
      int? refMvcMv, int? batteriePct}) {
    final duree = dureeS < 1 ? 1 : dureeS;
    final repetition = pasCourbeS ~/ 5 < 1 ? 1 : pasCourbeS ~/ 5;
    final c = [for (final v in courbe) for (var i = 0; i < repetition; i++) v].take(2000).toList();
    return {
      'discipline': discipline,
      'duree_s': '$duree',
      'nb_echantillons': '$nbEchantillons',
      'intensite_moyenne_pct': '$intensiteMoyennePct',
      'intensite_max_pct': '$intensiteMaxPct',
      'temps_effort_intense_s': '${tempsEffortIntenseS > duree ? duree : tempsEffortIntenseS}',
      'nb_alertes': '$nbAlertes',
      'simule': simule ? '1' : '0',
      'fin_il_y_a_s': '${finIlYaS.clamp(0, 2592000)}',
      if (c.isNotEmpty) 'courbe': '[${c.join(',')}]',
      if (numeroSerie != null) 'numero_serie': numeroSerie,
      if (firmware != null) 'firmware': firmware,
      if (refMvcMv != null) 'ref_mvc_mv': '$refMvcMv',
      if (batteriePct != null) 'batterie': '$batteriePct',
    };
  }
}

/// Copie en Dart du calcul fait dans le brassard (hardware/firmware-brassard/calcul_emg.h,
/// classe EnregistrementHorsLigne), pour le brassard simulé. Les tests vérifient que les
/// deux donnent les mêmes octets sur le même scénario.
class EnregistrementHorsLigne {
  static const int maxPoints = 200;
  static const int pasCourbeMs = 30000;
  static const int ecartMaxMs = 1000;
  static const int seuilRepos = 10;
  static const int arretAutoMs = 300000;

  int etat = ResumeHorsLigne.vide;
  _Cumuls _a = _Cumuls(), _instantane = _Cumuls();
  int _precedentMs = 0, _debutReposMs = 0, _finMs = 0;
  bool _premier = true, _enRepos = false, _alerteAvant = false;

  void demarrer(int maintenantMs) {
    _a = _Cumuls();
    _instantane = _Cumuls();
    etat = ResumeHorsLigne.enCours;
    _precedentMs = maintenantMs;
    _premier = true;
    _enRepos = false;
    _alerteAvant = false;
    _finMs = maintenantMs;
  }

  void effacer() {
    etat = ResumeHorsLigne.vide;
    _a = _Cumuls();
  }

  void ajouter(int maintenantMs, int intensite, bool alerte) {
    if (etat != ResumeHorsLigne.enCours) return;
    var ecart = _premier ? 0 : maintenantMs - _precedentMs;
    _premier = false;
    _precedentMs = maintenantMs;
    if (ecart > ecartMaxMs || ecart < 0) ecart = 0;

    if (intensite < seuilRepos) {
      if (!_enRepos) {
        _enRepos = true;
        _debutReposMs = maintenantMs;
        _instantane = _a.copie();
      } else if (maintenantMs - _debutReposMs >= arretAutoMs) {
        _a = _instantane;
        _finMs = _debutReposMs;
        etat = ResumeHorsLigne.termine;
        return;
      }
    } else {
      _enRepos = false;
    }

    _a.msTotal += ecart;
    _a.somme += intensite;
    _a.nb++;
    if (intensite > _a.max) _a.max = intensite;
    if (alerte) _a.msIntense += ecart;
    if (alerte && !_alerteAvant) _a.alertes++;
    _alerteAvant = alerte;

    _a.sommeBloc += intensite;
    _a.nbBloc++;
    if (_a.msTotal - _a.debutBlocMs >= pasCourbeMs) {
      if (_a.points.length < maxPoints) _a.points.add((_a.sommeBloc + _a.nbBloc ~/ 2) ~/ _a.nbBloc);
      _a.sommeBloc = 0;
      _a.nbBloc = 0;
      _a.debutBlocMs = _a.msTotal;
    }
  }

  void terminer(int maintenantMs) {
    if (etat != ResumeHorsLigne.enCours) return;
    etat = ResumeHorsLigne.termine;
    _finMs = maintenantMs;
  }

  /// Mêmes octets que le firmware (GATT.md §11).
  List<int> encoder(int maintenantMs) {
    final d = ByteData(20 + _a.points.length);
    d.setUint8(0, 1);
    d.setUint8(1, etat);
    d.setUint16(2, (_a.msTotal ~/ 1000).clamp(0, 65535), Endian.little);
    d.setUint32(4, _a.nb, Endian.little);
    d.setUint8(8, _a.nb == 0 ? 0 : (_a.somme + _a.nb ~/ 2) ~/ _a.nb);
    d.setUint8(9, _a.max);
    d.setUint16(10, (_a.msIntense ~/ 1000).clamp(0, 65535), Endian.little);
    d.setUint16(12, _a.alertes, Endian.little);
    d.setUint32(14, etat == ResumeHorsLigne.termine ? (maintenantMs - _finMs) ~/ 1000 : 0, Endian.little);
    d.setUint8(18, pasCourbeMs ~/ 1000);
    d.setUint8(19, _a.points.length);
    for (var i = 0; i < _a.points.length; i++) {
      d.setUint8(20 + i, _a.points[i]);
    }
    return d.buffer.asUint8List();
  }
}

class _Cumuls {
  int msTotal = 0, nb = 0, msIntense = 0, debutBlocMs = 0, somme = 0, sommeBloc = 0, nbBloc = 0, alertes = 0, max = 0;
  List<int> points = [];

  _Cumuls copie() => _Cumuls()
    ..msTotal = msTotal
    ..nb = nb
    ..msIntense = msIntense
    ..debutBlocMs = debutBlocMs
    ..somme = somme
    ..sommeBloc = sommeBloc
    ..nbBloc = nbBloc
    ..alertes = alertes
    ..max = max
    ..points = List.of(points);
}
