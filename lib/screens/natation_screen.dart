import 'dart:async';

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/file_envoi.dart';
import 'package:athletix_data/services/reglages.dart';
import 'contexte_seance.dart';
import 'historique_screen.dart';
import 'seance_detail_screen.dart';

/// Séance dans l'eau : le Bluetooth ne passe pas sous l'eau, donc le brassard garde
/// lui-même le résumé (architecture/GATT.md §11) et l'application le récupère au retour.
class NatationScreen extends StatefulWidget {
  const NatationScreen({super.key, required this.discipline, required this.couleur});

  final String discipline;
  final Color couleur;

  @override
  State<NatationScreen> createState() => _NatationScreenState();
}

enum _Etape { verification, pret, enregistrement, recuperation, erreur }

class _NatationScreenState extends State<NatationScreen> {
  _Etape _etape = _Etape.verification;
  String? _message;
  ResumeHorsLigne? _trouve; // séance déjà présente dans le brassard
  Timer? _minuteur;
  final Stopwatch _chrono = Stopwatch();

  SourceBrassard get _brassard {
    var b = BrassardActif.source;
    if (b == null) {
      // Pas de brassard choisi : brassard simulé, gardé pour toute l'application
      // (la séance continue si on quitte l'écran, comme avec le vrai brassard)
      b = BrassardSimule();
      BrassardActif.choisir(b);
    }
    if (b is BrassardSimule) b.accelerationHorsLigne = 60; // démo : 1 s = 1 min de nage
    return b;
  }

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    try {
      final r = await _brassard.lireHorsLigne();
      if (!mounted) return;
      setState(() {
        if (r.etat == ResumeHorsLigne.enCours) {
          _etape = _Etape.enregistrement;
          _demarrerChrono();
        } else {
          _trouve = r.etat == ResumeHorsLigne.termine && r.dureeS > 0 ? r : null;
          _etape = _Etape.pret;
        }
      });
    } catch (e) {
      if (mounted) setState(() { _etape = _Etape.erreur; _message = '$e'; });
    }
  }

  void _demarrerChrono() {
    _chrono
      ..reset()
      ..start();
    _minuteur?.cancel();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _demarrer() async {
    try {
      await _brassard.demarrerHorsLigne();
      _demarrerChrono();
      if (mounted) setState(() => _etape = _Etape.enregistrement);
    } catch (e) {
      if (mounted) setState(() { _etape = _Etape.erreur; _message = '$e'; });
    }
  }

  /// Arrêter, lire le résumé, demander le ressenti, enregistrer, effacer le brassard.
  Future<void> _recuperer() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _etape = _Etape.recuperation);
    try {
      final b = _brassard;
      if (_trouve == null) await b.arreter();
      final r = _trouve ?? await b.lireHorsLigne();
      _minuteur?.cancel();
      _chrono.stop();
      if (r.dureeS < 10) {
        await b.effacerHorsLigne();
        messenger.showSnackBar(const SnackBar(content: Text('Séance trop courte : rien à enregistrer')));
        navigator.pop();
        return;
      }
      if (!mounted) return;
      final contexte = await demanderContexte(context);
      final envoi = {
        ...r.versApi(
          discipline: widget.discipline,
          simule: b.simule,
          numeroSerie: b.numeroSerie,
          firmware: b.firmware,
          refMvcMv: b.refMvcMv,
          batteriePct: b.batteriePct,
        ),
        ...contexte,
        'mode_adapte': Reglages.modeAdapte.value ? '1' : '0',
        'client_uuid': FileEnvoi.nouvelUuid(),
      };
      final reponse = await Api.current.saveSeance(envoi);
      if (reponse['status'] == 'success') {
        await b.effacerHorsLigne(); // seulement une fois enregistrée : rien n'est perdu
        Api.seancesModifiees.value++;
        // Par son numéro, pas « la plus récente » : une longue séance (natation) commence avant une
        // séance courte finie juste avant, et ne serait pas la première de la liste.
        final id = (reponse['session_id'] as num?)?.toInt() ?? -1;
        final liste = await Api.current.getSeance(id);
        final seances = liste['seances'] as List? ?? [];
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Séance récupérée et enregistrée'), backgroundColor: Colors.green));
        if (seances.isNotEmpty) {
          navigator.pushReplacement(MaterialPageRoute(
              builder: (_) => SeanceDetailScreen(seance: Map<String, dynamic>.from(seances.first as Map))));
        } else {
          navigator.pop();
        }
      } else if (reponse['reseau'] == true) {
        // Pas de réseau au bord de la piscine : gardée sur le téléphone, envoyée plus tard
        final finMs = DateTime.now().millisecondsSinceEpoch - r.finIlYaS * 1000;
        envoi.remove('fin_il_y_a_s');
        await FileEnvoi.garder(envoi, finMs: finMs);
        await b.effacerHorsLigne();
        Api.seancesModifiees.value++;
        messenger.showSnackBar(const SnackBar(
            content: Text('Pas de réseau : séance gardée sur le téléphone, envoi automatique plus tard'),
            backgroundColor: Colors.orange));
        navigator.pop();
      } else {
        // Le brassard garde la séance : on pourra réessayer
        if (mounted) setState(() { _etape = _Etape.pret; _trouve = r; });
        messenger.showSnackBar(SnackBar(
            content: Text('${reponse['message'] ?? 'Erreur'} : la séance reste dans le brassard'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() { _etape = _Etape.erreur; _message = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final simule = BrassardActif.source?.simule ?? true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.discipline.toUpperCase()), backgroundColor: widget.couleur, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (_etape) {
          _Etape.verification || _Etape.recuperation =>
            const Center(child: CircularProgressIndicator(color: Colors.cyan)),
          _Etape.erreur => Center(
              child: Text('Brassard : $_message', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
          _Etape.pret => _pret(simule),
          _Etape.enregistrement => _enregistrement(simule),
        },
      ),
    );
  }

  Widget _pret(bool simule) => ListView(children: [
        const Icon(Icons.waves, color: Colors.cyan, size: 60),
        const SizedBox(height: 12),
        const Text("Le Bluetooth ne passe pas sous l'eau", textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          "Le brassard enregistre la séance tout seul : intensité moyenne et maximale, efforts intenses, "
          "et une courbe (une valeur toutes les 30 s). Au retour, l'application récupère le résumé.\n\n"
          "S'il reste plus de 5 minutes au repos (sortie de l'eau), il s'arrête de lui-même : "
          "le temps passé au bord ne compte pas.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 12),
        const Text(
          "⚠️ Le prototype n'est pas étanche (carte, batterie) : il faut un boîtier étanche avant d'aller "
          "dans l'eau. En attendant, on teste hors de l'eau en éloignant le téléphone.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_trouve != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('Séance trouvée dans le brassard : ${HistoriqueScreen.duree(_trouve!.dureeS)}, '
                  '${_trouve!.intensiteMoyennePct} % en moyenne',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent)),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _recuperer,
                child: const Text('RÉCUPÉRER CETTE SÉANCE', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700], minimumSize: const Size(double.infinity, 54)),
          onPressed: _trouve != null ? null : _demarrer,
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text("DÉMARRER DANS L'EAU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        if (_trouve != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text("Récupère d'abord la séance gardée dans le brassard.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        if (simule)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              "Brassard simulé : le temps est accéléré (1 s = 1 min de nage), avec des longueurs, des virages "
              "et un sprint toutes les 5 minutes. Le calcul est le même que celui du firmware.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ),
      ]);

  Widget _enregistrement(bool simule) {
    final secondes = _chrono.elapsed.inSeconds * (simule ? 60 : 1);
    return ListView(children: [
      const SizedBox(height: 10),
      const Icon(Icons.pool, color: Colors.cyan, size: 70),
      const SizedBox(height: 16),
      const Text('Enregistrement dans le brassard', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(HistoriqueScreen.duree(secondes), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.cyan, fontSize: 44, fontWeight: FontWeight.bold)),
      if (simule)
        const Text('temps simulé (×60)', textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 12)),
      const SizedBox(height: 16),
      const Text(
        "Tu peux ranger le téléphone : la liaison peut se couper, le brassard continue.\n"
        "Au retour, rouvre cet écran et récupère la séance.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      const SizedBox(height: 30),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 54)),
        onPressed: _recuperer,
        icon: const Icon(Icons.download, color: Colors.white),
        label: const Text("J'AI FINI : RÉCUPÉRER LA SÉANCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}
