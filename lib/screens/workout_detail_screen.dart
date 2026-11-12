import 'dart:async';

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/file_envoi.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/brassard/resume_seance.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/analyse/analyse_seance.dart';
import 'package:athletix_data/services/reglages.dart';
import 'package:athletix_data/services/telephone/cardio.dart';
import 'package:athletix_data/services/telephone/meteo.dart';
import 'package:athletix_data/services/telephone/suivi_telephone.dart';
import 'package:athletix_data/widgets/graphiques.dart';
import 'contexte_seance.dart';
import 'seance_detail_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  /// Mesure EMG affichée pendant la séance (voir [_buildMesure]).
  final String mesure;

  /// Source des mesures. Par défaut : le brassard choisi dans l'écran « Brassard »
  /// (BrassardActif), sinon un brassard simulé créé pour la séance.
  /// L'écran ne ferme que le brassard simulé qu'il a créé lui-même.
  final SourceBrassard? source;

  const WorkoutDetailScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.mesure,
    this.source,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final SourceBrassard? _fourni = widget.source ?? BrassardActif.source;
  late final SourceBrassard _brassard = _fourni ?? BrassardSimule();
  bool get _creeIci => _fourni == null;
  String? _erreurLiaison;
  late final ResumeSeance _resume = ResumeSeance(refMvcMv: _brassard.refMvcMv);
  final AnalyseSeance _analyse = AnalyseSeance();
  StreamSubscription<MesureEmg>? _abonnement;
  MesureEmg? _derniere;
  bool _enregistrement = false;
  bool _echecEnregistrement = false;

  // Courbe en direct : une moyenne toutes les 500 ms, 30 dernières secondes
  static const int _pasDirectMs = 500, _nbDirect = 60;
  final List<int> _direct = [];
  int _sommeDirect = 0, _nbDansDirect = 0, _debutDirectMs = -1;

  // Téléphone : GPS et pas pour les sports d'endurance, météo au départ, ceinture cardio si connectée
  static const _sportsAPas = {'Running', 'Trail'};
  late final bool _gps = widget.mesure == 'ACTIVITE_MOYENNE';
  late final SuiviTelephone? _telephone = _gps
      ? SuiviTelephone(
          gps: true,
          pas: _sportsAPas.contains(widget.categoryName),
          simuler: Api.isDemo,
          intensiteActuelle: () => _derniere?.intensitePct ?? 0,
        )
      : null;
  Meteo? _meteo;
  bool _meteoDemandee = false;
  final StatsCardio _cardio = StatsCardio();
  StreamSubscription<int>? _abonnementCardio;
  int? _fcActuelle;

  // Alertes vibration / voix et mode adapté
  final Alerteur _alerteur = Alerteur();
  late final bool _modeAdapte = Reglages.modeAdapte.value;
  Timer? _minuteurPause;
  int _pausesSignalees = 0;
  String? _conseilPause;

  int get _seuilHaut => _modeAdapte ? Reglages.seuilHautAdapte : GattAthletix.seuilHautDefaut;
  int get _seuilBas => _modeAdapte ? Reglages.seuilBasAdapte : GattAthletix.seuilBasDefaut;

  @override
  void initState() {
    super.initState();
    _abonnement = _brassard.mesures.listen(_recevoir, onError: (Object e) {
      if (mounted) setState(() => _erreurLiaison = e.toString());
    });
    _demarrer();
    _telephone?.demarrer().then((_) {
      if (mounted) setState(() {});
    });
    final ceinture = CeintureCardio.active.value;
    if (ceinture != null) {
      _abonnementCardio = ceinture.bpm.listen((bpm) {
        _cardio.ajouter(bpm);
        if (mounted) setState(() => _fcActuelle = bpm);
      });
    }
    if (_modeAdapte) {
      _minuteurPause = Timer.periodic(const Duration(seconds: 15), (_) => _verifierPause());
    }
  }

  Future<void> _demarrer() async {
    try {
      // Les seuils suivent le mode adapté (le vrai brassard les garde en mémoire)
      if (_brassard.seuilHaut != _seuilHaut || _brassard.seuilBas != _seuilBas) {
        await _brassard.reglerSeuils(_seuilHaut, _seuilBas);
      }
    } catch (e) {
      if (mounted) setState(() => _erreurLiaison = 'Seuils non modifiés : $e');
    }
    _brassard.demarrer().catchError((Object e) {
      if (mounted) setState(() => _erreurLiaison = e.toString());
    });
  }

  void _verifierPause() {
    final minutes = _resume.dureeS ~/ 60;
    final dues = minutes ~/ Reglages.pauseToutesLesMinutes;
    if (dues > _pausesSignalees) {
      _pausesSignalees = dues;
      _alerteur.signaler('Pense à faire une pause');
      if (mounted) setState(() => _conseilPause = '$minutes min d\'effort : pense à faire une pause et à boire.');
    }
  }

  void _recevoir(MesureEmg mesure) {
    final avant = _derniere;
    _resume.ajouter(mesure);
    _analyse.ajouter(mesure);
    if (mesure.alerte && !(avant?.alerte ?? false)) _alerteur.signaler('Effort intense');

    if (_debutDirectMs < 0) _debutDirectMs = mesure.horodatageMs;
    _sommeDirect += mesure.intensitePct;
    _nbDansDirect++;
    if (mesure.horodatageMs - _debutDirectMs >= _pasDirectMs || mesure.horodatageMs < _debutDirectMs) {
      _direct.add((_sommeDirect / _nbDansDirect).round());
      if (_direct.length > _nbDirect) _direct.removeAt(0);
      _sommeDirect = 0;
      _nbDansDirect = 0;
      _debutDirectMs = mesure.horodatageMs;
    }

    // Météo une seule fois, dès que le GPS donne une position
    final position = _telephone?.position;
    if (!_meteoDemandee && position != null) {
      _meteoDemandee = true;
      Meteo.actuelle(position.latitude, position.longitude).then((m) {
        if (mounted) setState(() => _meteo = m);
      });
    }
    if (mounted) setState(() => _derniere = mesure);
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    _abonnementCardio?.cancel();
    _minuteurPause?.cancel();
    _telephone?.arreter();
    _alerteur.fermer();
    if (_creeIci) {
      _brassard.fermer();
    } else {
      _brassard.arreter().catchError((_) {}); // la connexion Bluetooth reste ouverte
    }
    super.dispose();
  }

  Map<String, String>? _envoi; // gardé pour réessayer sans reposer les questions
  int _finMs = 0; // heure de fin, pour un envoi différé

  // Fin de séance : arrêter le brassard, demander le ressenti, envoyer le résumé (opération O6 du MCT)
  Future<void> _terminer() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_envoi == null) {
      try {
        await _brassard.arreter();
      } catch (_) {/* liaison perdue : on enregistre quand même ce qui a été reçu */}
      _telephone?.arreter();
      _minuteurPause?.cancel();
      if (_resume.nbEchantillons < 2) {
        navigator.pop(); // séance trop courte : rien à enregistrer
        return;
      }
      if (!mounted) return;
      final contexte = await demanderContexte(context);
      _envoi = {
        ..._resume.versApi(
          discipline: widget.categoryName,
          simule: _brassard.simule,
          numeroSerie: _brassard.numeroSerie,
          firmware: _brassard.firmware,
          batteriePct: _brassard.batteriePct,
        ),
        ..._analyse.versApi(),
        ...?_telephone?.versApi(),
        ...?_meteo?.versApi(),
        ..._cardio.versApi(),
        ...contexte,
        'mode_adapte': _modeAdapte ? '1' : '0',
        'client_uuid': FileEnvoi.nouvelUuid(),
      };
      _finMs = DateTime.now().millisecondsSinceEpoch;
    }

    if (!mounted) return;
    setState(() => _enregistrement = true);
    final reponse = await Api.current.saveSeance(_envoi!);
    if (!mounted) return;

    if (reponse['status'] == 'success') {
      messenger.showSnackBar(SnackBar(
        content: Text("Séance enregistrée : ${_resume.dureeS} s, "
            "${_resume.nbAlertes} alerte(s) d'effort intense"),
        backgroundColor: Colors.green,
      ));
      Api.seancesModifiees.value++;
      // Ouvre le détail de la séance qui vient d'être enregistrée
      // Par son numéro, pas « la plus récente » : une longue séance (natation) commence avant une
      // séance courte finie juste avant, et ne serait pas la première de la liste.
      final id = (reponse['session_id'] as num?)?.toInt() ?? -1;
      final liste = await Api.current.getSeance(id);
      final seances = liste['seances'] as List? ?? [];
      if (!mounted) return;
      if (seances.isNotEmpty) {
        navigator.pushReplacement(MaterialPageRoute(
            builder: (_) => SeanceDetailScreen(seance: Map<String, dynamic>.from(seances.first as Map))));
      } else {
        navigator.pop();
      }
    } else if (reponse['reseau'] == true) {
      // Pas de réseau : la séance est gardée sur le téléphone et partira toute seule plus tard
      await FileEnvoi.garder(_envoi!, finMs: _finMs);
      Api.seancesModifiees.value++;
      messenger.showSnackBar(const SnackBar(
        content: Text("Pas de réseau : séance gardée sur le téléphone, elle sera envoyée automatiquement."),
        backgroundColor: Colors.orange,
      ));
      navigator.pop();
    } else {
      // On reste sur l'écran pour ne pas perdre la séance : le bouton permet de réessayer
      setState(() {
        _enregistrement = false;
        _echecEnregistrement = true;
      });
      messenger.showSnackBar(SnackBar(
        content: Text(reponse['message']?.toString() ?? "Erreur lors de l'enregistrement"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesure = _derniere;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.categoryName.toUpperCase()),
        backgroundColor: widget.categoryColor,
        centerTitle: true,
      ),
      body: mesure == null
          ? Center(
              child: _erreurLiaison != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Brassard : $_erreurLiaison',
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                    )
                  : const CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  _bandeauSource(),
                  if (_erreurLiaison != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_erreurLiaison!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 24),
                  const Text("INTENSITÉ MUSCULAIRE",
                      style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _intensite(mesure),
                  const SizedBox(height: 16),
                  _jauge(mesure),
                  const SizedBox(height: 16),
                  if (mesure.alerte) _bandeauAlerte(),
                  if (mesure.saturation)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text("Signal saturé : vérifie la position des électrodes",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    ),
                  if (_conseilPause != null) _bandeau(_conseilPause!, Icons.local_cafe, Colors.lightBlueAccent),
                  if (_modeAdapte && (_meteo?.chaud ?? false))
                    _bandeau('${decimalFr(_meteo!.temperatureC, 0)} °C : la chaleur fatigue plus vite. '
                        'Ralentis, bois, fais des pauses à l\'ombre.', Icons.wb_sunny, Colors.orangeAccent),
                  const SizedBox(height: 20),
                  _statistiques(mesure),
                  const SizedBox(height: 18),
                  CourbeIntensite(
                    valeurs: _direct,
                    seuil: _seuilHaut,
                    pasS: _pasDirectMs / 1000,
                    couleur: widget.categoryColor,
                    hauteur: 150,
                    enDirect: true,
                  ),
                  const Text("30 dernières secondes", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  if (_telephone != null || _fcActuelle != null) ...[
                    const SizedBox(height: 18),
                    _mesuresTelephone(),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(color: Colors.white24, indent: 50, endIndent: 50),
                  ),
                  _buildMesure(),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _enregistrement ? null : _terminer,
                    child: _enregistrement
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_echecEnregistrement ? "RÉESSAYER L'ENREGISTREMENT" : "TERMINER LA SÉANCE",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bandeauSource() {
    final texte = _brassard.simule
        ? "Brassard simulé · format Bluetooth réel (GATT)"
        : "Brassard ${_brassard.nom}";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber),
      ),
      child: Text(texte,
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _intensite(MesureEmg mesure) {
    final couleur = mesure.alerte ? Colors.redAccent : widget.categoryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text("${mesure.intensitePct}",
            style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: couleur)),
        const SizedBox(width: 10),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text("% MVC", style: TextStyle(color: Colors.white, fontSize: 20)),
        ),
      ],
    );
  }

  // Jauge de 0 à 120 % avec le seuil d'alerte indiqué
  Widget _jauge(MesureEmg mesure) {
    const maxJauge = 120.0;
    final remplissage = (mesure.intensitePct / maxJauge).clamp(0.0, 1.0).toDouble();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: remplissage,
            minHeight: 14,
            backgroundColor: Colors.white12,
            color: mesure.alerte ? Colors.redAccent : widget.categoryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Alerte au-dessus de $_seuilHaut %, fin sous $_seuilBas %"
          "${_modeAdapte ? ' (mode adapté)' : ''} · 100 % = ta contraction maximale",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _bandeauAlerte() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text("EFFORT INTENSE",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statistiques(MesureEmg mesure) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat("SIGNAL", "${mesure.rmsMv} mV"),
        _stat("DURÉE", "${_resume.dureeS} s"),
        _stat("ALERTES", "${_resume.nbAlertes}"),
        _stat("MAX", "${_resume.intensiteMaxPct} %"),
      ],
    );
  }

  Widget _stat(String libelle, String valeur) {
    return Column(
      children: [
        Text(libelle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(valeur,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _bandeau(String texte, IconData icone, Color couleur) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur),
        ),
        child: Row(children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: TextStyle(color: couleur, fontSize: 13))),
        ]),
      );

  Widget _mesuresTelephone() {
    final t = _telephone;
    final trace = t?.trace;
    final simule = t?.parcoursSimule ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          if (trace != null) _stat("DISTANCE", "${decimalFr(trace.distanceM / 1000, 2)} km"),
          if (trace != null) _stat("VITESSE", "${decimalFr(trace.vitesseMoyKmh, 1)} km/h"),
          if (t != null && t.pas) _stat("PAS", "${t.podometre.pas}"),
          if (_fcActuelle != null) _stat("CŒUR", "$_fcActuelle bpm"),
        ]),
        const SizedBox(height: 6),
        Text(
          [
            if (t?.probleme != null) t!.probleme!,
            if (simule) 'parcours simulé (démo)',
            if (_meteo != null) 'météo : ${decimalFr(_meteo!.temperatureC, 0)} °C, ${Meteo.libelle(_meteo!.code)}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ]),
    );
  }

  /// Ce que le brassard EMG (MyoWare 2.0) mesure selon le type de sport (valeurs de la séance en cours).
  /// % MVC = pourcentage de la contraction maximale volontaire.
  Widget _buildMesure() {
    final duree = _analyse.tempsReposS + _analyse.tempsModereeS + _analyse.tempsSoutenueS + _analyse.tempsIntenseS;
    switch (widget.mesure) {
      case 'ACTIVITE_MOYENNE':
        return _mesureTile(Icons.show_chart, "ACTIVITÉ MUSCULAIRE MOYENNE", "${_resume.intensiteMoyennePct} % MVC", Colors.blue);
      case 'PIC_CONTRACTION':
        return _mesureTile(Icons.fitness_center, "PIC DE CONTRACTION", "${_resume.intensiteMaxPct} % MVC", Colors.red,
            note: "${_analyse.nbContractions} contraction(s)");
      case 'EFFORTS_INTENSES':
        return _mesureTile(Icons.bolt, "EFFORTS INTENSES (> $_seuilHaut % MVC)", "${_resume.nbAlertes}", Colors.green,
            note: "${_resume.tempsEffortIntenseS} s au total");
      case 'HORS_LIGNE':
        return _mesureTile(Icons.waves, "MESURES GARDÉES DANS LE BRASSARD", "Envoi après la séance", Colors.cyan,
            note: "le Bluetooth ne passe pas sous l'eau (pas encore programmé dans le brassard)");
      case 'RELACHEMENT':
        return _mesureTile(Icons.self_improvement, "TEMPS RELÂCHÉ (< 20 % MVC)",
            duree == 0 ? "—" : "${(_analyse.tempsReposS * 100 / duree).round()} %", Colors.purple);
      default:
        return const SizedBox();
    }
  }

  Widget _mesureTile(IconData icon, String label, String value, Color color, {String? note}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        Text(value, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
        if (note != null)
          Text(note, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
