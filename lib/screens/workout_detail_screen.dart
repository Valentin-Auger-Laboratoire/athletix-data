import 'dart:async';

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/mesure_emg.dart';
import 'package:athletix_data/services/brassard/resume_seance.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  /// Mesure EMG affichée pendant la séance (voir [_buildMesure]).
  final String mesure;

  /// Source des mesures. Par défaut : le brassard simulé.
  /// Plus tard : un `BrassardBle` (voir architecture/INTEGRATION.md §3).
  /// L'écran ferme la source quand il se ferme.
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
  late final SourceBrassard _brassard = widget.source ?? BrassardSimule();
  late final ResumeSeance _resume = ResumeSeance(refMvcMv: _brassard.refMvcMv);
  StreamSubscription<MesureEmg>? _abonnement;
  MesureEmg? _derniere;
  bool _enregistrement = false;
  bool _echecEnregistrement = false;

  @override
  void initState() {
    super.initState();
    _abonnement = _brassard.mesures.listen(_recevoir);
    _brassard.demarrer();
  }

  void _recevoir(MesureEmg mesure) {
    _resume.ajouter(mesure);
    if (mounted) setState(() => _derniere = mesure);
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    _brassard.fermer();
    super.dispose();
  }

  // Fin de séance : arrêter le brassard, envoyer le résumé (opération O6 du MCT)
  Future<void> _terminer() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await _brassard.arreter();
    if (_resume.nbEchantillons < 2) {
      navigator.pop(); // séance trop courte : rien à enregistrer
      return;
    }

    if (!mounted) return;
    setState(() => _enregistrement = true);
    final reponse = await Api.current.saveSeance(_resume.versApi(
      discipline: widget.categoryName,
      simule: _brassard.simule,
      numeroSerie: _brassard.numeroSerie,
      firmware: _brassard.firmware,
    ));
    if (!mounted) return;

    if (reponse['status'] == 'success') {
      messenger.showSnackBar(SnackBar(
        content: Text("Séance enregistrée : ${_resume.dureeS} s, "
            "${_resume.nbAlertes} alerte(s) d'effort intense"),
        backgroundColor: Colors.green,
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  _bandeauSource(),
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
                  const SizedBox(height: 20),
                  _statistiques(mesure),
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
        const Text(
          "Alerte au-dessus de ${GattAthletix.seuilHautDefaut} %, "
          "fin sous ${GattAthletix.seuilBasDefaut} % · 100 % = ta contraction maximale",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
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

  /// Ce que le brassard EMG (MyoWare 2.0) peut mesurer selon le type de sport.
  /// % MVC = pourcentage de la contraction maximale volontaire.
  Widget _buildMesure() {
    switch (widget.mesure) {
      case 'ACTIVITE_MOYENNE':
        return _mesureTile(Icons.show_chart, "ACTIVITÉ MUSCULAIRE MOYENNE", "38 % MVC", Colors.blue);
      case 'PIC_CONTRACTION':
        return _mesureTile(Icons.fitness_center, "PIC DE CONTRACTION", "92 % MVC", Colors.red);
      case 'EFFORTS_INTENSES':
        return _mesureTile(Icons.bolt, "EFFORTS INTENSES (> 75 % MVC)", "14", Colors.green);
      case 'HORS_LIGNE':
        return _mesureTile(Icons.waves, "MESURES GARDÉES DANS LE BRASSARD", "Envoi après la séance", Colors.cyan,
          note: "le Bluetooth ne passe pas sous l'eau");
      case 'RELACHEMENT':
        return _mesureTile(Icons.self_improvement, "RELÂCHEMENT MUSCULAIRE", "6 % MVC", Colors.purple);
      default:
        return const SizedBox();
    }
  }

  Widget _mesureTile(IconData icon, String label, String value, Color color, {String? note}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        Text(value, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
        Text(note == null ? "valeur d'exemple" : "valeur d'exemple · $note",
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
