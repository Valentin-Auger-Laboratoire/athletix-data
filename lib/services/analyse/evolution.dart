/// Analyse de l'évolution sur plusieurs semaines, à partir des séances de get_seances.php.
/// Calculs purs (sans écran), testés dans test/evolution_test.dart.
library;

/// Une séance telle que renvoyée par l'API (champs utiles à l'évolution).
class SeanceResume {
  SeanceResume({
    required this.debut,
    required this.discipline,
    required this.dureeS,
    required this.intensiteMoyenne,
    required this.intensiteMax,
    required this.tempsIntenseS,
    this.simulee = false,
    this.distanceM,
    this.vitesseKmh,
    this.fcMoy,
    this.temperatureC,
    this.ressentiFatigue,
    this.douleur,
    this.sommeil,
    this.indiceFatigue,
  });

  final DateTime debut;
  final String discipline;
  final int dureeS;
  final int intensiteMoyenne;
  final int intensiteMax;
  final int tempsIntenseS;
  final bool simulee;
  final int? distanceM;
  final double? vitesseKmh;
  final int? fcMoy;
  final double? temperatureC;
  final int? ressentiFatigue;
  final int? douleur;
  final String? sommeil;
  final int? indiceFatigue;

  /// Points de la séance, avec la règle du classement (backend/get_classement.php).
  int get points => 10 + (dureeS / 60 * intensiteMoyenne / 50).round();

  /// « Rendement » : points par heure d'entraînement, pour comparer des séances de durées différentes.
  double get pointsParHeure => dureeS <= 0 ? 0 : points / (dureeS / 3600);

  static SeanceResume? depuisApi(Map<String, dynamic> m) {
    final debut = DateTime.tryParse((m['debut'] ?? '').toString().replaceFirst(' ', 'T'));
    if (debut == null) return null;
    int? entier(String c) => (m[c] as num?)?.toInt();
    return SeanceResume(
      debut: debut,
      discipline: (m['discipline'] ?? '').toString(),
      dureeS: entier('duree_s') ?? 0,
      intensiteMoyenne: entier('intensite_moyenne_pct') ?? 0,
      intensiteMax: entier('intensite_max_pct') ?? 0,
      tempsIntenseS: entier('temps_effort_intense_s') ?? 0,
      simulee: m['donnees_simulees'] == true,
      distanceM: entier('distance_m'),
      vitesseKmh: (m['vitesse_moy_kmh'] as num?)?.toDouble(),
      fcMoy: entier('fc_moy'),
      temperatureC: (m['temperature_c'] as num?)?.toDouble(),
      ressentiFatigue: entier('ressenti_fatigue'),
      douleur: entier('douleur'),
      sommeil: m['sommeil']?.toString(),
      indiceFatigue: entier('indice_fatigue_pct'),
    );
  }
}

/// Bilan d'une semaine (du lundi au dimanche).
class Semaine {
  Semaine(this.lundi, this.seances);

  final DateTime lundi;
  final List<SeanceResume> seances;

  int get nbSeances => seances.length;
  int get dureeTotaleS => seances.fold(0, (s, x) => s + x.dureeS);
  int get points => seances.fold(0, (s, x) => s + x.points);
  int get distanceM => seances.fold(0, (s, x) => s + (x.distanceM ?? 0));

  double _moyenne(Iterable<num> v) => v.isEmpty ? 0 : v.fold<double>(0, (a, b) => a + b) / v.length;

  /// Intensité moyenne pondérée par la durée.
  double get intensiteMoyenne {
    final d = dureeTotaleS;
    if (d == 0) return 0;
    return seances.fold<double>(0, (s, x) => s + x.intensiteMoyenne * x.dureeS) / d;
  }

  int get intensiteMax => seances.fold(0, (m, x) => x.intensiteMax > m ? x.intensiteMax : m);
  double get rendement => _moyenne(seances.map((x) => x.pointsParHeure));

  double? get fatigueRessentie {
    final v = seances.map((x) => x.ressentiFatigue).whereType<int>();
    return v.isEmpty ? null : _moyenne(v);
  }

  double? get douleurMoyenne {
    final v = seances.map((x) => x.douleur).whereType<int>();
    return v.isEmpty ? null : _moyenne(v);
  }

  double? get temperatureMax {
    final v = seances.map((x) => x.temperatureC).whereType<double>();
    return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
  }

  int get nbNuitsMauvaises => seances.where((x) => x.sommeil == 'Mauvais').length;
}

/// Une semaine nettement moins bonne que les précédentes, avec les causes possibles relevées.
class SemaineMoinsBonne {
  SemaineMoinsBonne(this.semaine, this.baissePct, this.causes);

  final Semaine semaine;

  /// Baisse du rendement par rapport à la moyenne des semaines précédentes, en %.
  final int baissePct;
  final List<String> causes;
}

class Record {
  const Record(this.libelle, this.valeur, this.date);

  final String libelle;
  final String valeur;
  final DateTime date;
}

class Evolution {
  Evolution(Iterable<SeanceResume> seances, {this.inclureSimulees = true})
      : seances = seances.where((s) => inclureSimulees || !s.simulee).toList()
          ..sort((a, b) => a.debut.compareTo(b.debut));

  final List<SeanceResume> seances;
  final bool inclureSimulees;

  static DateTime lundiDe(DateTime d) {
    final jour = DateTime(d.year, d.month, d.day);
    return jour.subtract(Duration(days: jour.weekday - DateTime.monday));
  }

  /// Semaines successives, y compris les semaines sans séance entre deux semaines actives.
  List<Semaine> get semaines {
    if (seances.isEmpty) return [];
    final parLundi = <DateTime, List<SeanceResume>>{};
    for (final s in seances) {
      parLundi.putIfAbsent(lundiDe(s.debut), () => []).add(s);
    }
    final premier = lundiDe(seances.first.debut), dernier = lundiDe(seances.last.debut);
    final resultat = <Semaine>[];
    // DateTime(…, jour + 7) plutôt qu'add(7 jours) : sûr aux changements d'heure
    for (var l = premier; !l.isAfter(dernier); l = DateTime(l.year, l.month, l.day + 7)) {
      resultat.add(Semaine(l, parLundi[l] ?? []));
    }
    return resultat;
  }

  /// Semaines dont le rendement baisse de plus de [seuilPct] % par rapport à la moyenne
  /// des [nbReference] semaines actives précédentes, avec les causes possibles.
  List<SemaineMoinsBonne> semainesMoinsBonnes({int seuilPct = 15, int nbReference = 3}) {
    final actives = semaines.where((s) => s.nbSeances > 0).toList();
    final resultat = <SemaineMoinsBonne>[];
    for (var i = 1; i < actives.length; i++) {
      final ref = actives.sublist(i - nbReference < 0 ? 0 : i - nbReference, i);
      final moyenneRef = ref.map((s) => s.rendement).reduce((a, b) => a + b) / ref.length;
      if (moyenneRef <= 0) continue;
      final baisse = ((moyenneRef - actives[i].rendement) / moyenneRef * 100).round();
      if (baisse >= seuilPct) {
        resultat.add(SemaineMoinsBonne(actives[i], baisse, causesPossibles(actives[i], ref)));
      }
    }
    return resultat;
  }

  /// Ce qui distingue cette semaine des précédentes : piste d'explication, pas un diagnostic.
  static List<String> causesPossibles(Semaine s, List<Semaine> reference) {
    final causes = <String>[];
    double? moyenne(Iterable<double?> v) {
      final ok = v.whereType<double>();
      return ok.isEmpty ? null : ok.reduce((a, b) => a + b) / ok.length;
    }

    final f = s.fatigueRessentie, fRef = moyenne(reference.map((x) => x.fatigueRessentie));
    if (f != null && (f >= 7 || (fRef != null && f - fRef >= 2))) {
      causes.add('fatigue ressentie élevée (${f.toStringAsFixed(1).replaceAll('.', ',')}/10)');
    }
    if (s.nbNuitsMauvaises > 0) {
      causes.add('mauvais sommeil (${s.nbNuitsMauvaises} nuit${s.nbNuitsMauvaises > 1 ? 's' : ''})');
    }
    final t = s.temperatureMax;
    if (t != null && t >= 25) causes.add('chaleur (jusqu\'à ${t.toStringAsFixed(0)} °C)');
    final d = s.douleurMoyenne;
    if (d != null && d >= 4) causes.add('douleur signalée (${d.toStringAsFixed(1).replaceAll('.', ',')}/10)');
    final nbRef = reference.isEmpty ? 0 : reference.map((x) => x.nbSeances).reduce((a, b) => a + b) / reference.length;
    if (nbRef > 0 && s.nbSeances >= nbRef + 2) causes.add('plus de séances que d\'habitude (récupération courte)');
    if (causes.isEmpty) causes.add('aucune cause notée : penser à remplir le ressenti en fin de séance');
    return causes;
  }

  /// Records personnels.
  List<Record> get records {
    if (seances.isEmpty) return [];
    String duree(int s) => s >= 3600 ? '${s ~/ 3600} h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')}' : '${s ~/ 60} min';
    final r = <Record>[];
    final pic = seances.reduce((a, b) => b.intensiteMax > a.intensiteMax ? b : a);
    r.add(Record('Contraction la plus forte', '${pic.intensiteMax} %', pic.debut));
    final longue = seances.reduce((a, b) => b.dureeS > a.dureeS ? b : a);
    r.add(Record('Séance la plus longue', duree(longue.dureeS), longue.debut));
    final intense = seances.reduce((a, b) => b.tempsIntenseS > a.tempsIntenseS ? b : a);
    if (intense.tempsIntenseS > 0) r.add(Record("Plus long temps d'effort intense", duree(intense.tempsIntenseS), intense.debut));
    final avecDistance = seances.where((s) => (s.distanceM ?? 0) > 0);
    if (avecDistance.isNotEmpty) {
      final loin = avecDistance.reduce((a, b) => b.distanceM! > a.distanceM! ? b : a);
      r.add(Record('Plus longue distance', '${(loin.distanceM! / 1000).toStringAsFixed(2).replaceAll('.', ',')} km', loin.debut));
      final avecVitesse = avecDistance.where((s) => s.vitesseKmh != null && s.dureeS >= 600);
      if (avecVitesse.isNotEmpty) {
        final vite = avecVitesse.reduce((a, b) => b.vitesseKmh! > a.vitesseKmh! ? b : a);
        r.add(Record('Vitesse moyenne la plus haute (≥ 10 min)', '${vite.vitesseKmh!.toStringAsFixed(1).replaceAll('.', ',')} km/h', vite.debut));
      }
    }
    final semainesActives = semaines.where((s) => s.nbSeances > 0);
    if (semainesActives.isNotEmpty) {
      final meilleure = semainesActives.reduce((a, b) => b.points > a.points ? b : a);
      r.add(Record('Meilleure semaine', '${meilleure.points} points', meilleure.lundi));
    }
    return r;
  }
}
