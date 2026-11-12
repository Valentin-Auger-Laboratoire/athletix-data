import 'dart:async';

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';

/// Calibration : mesure de la contraction maximale (référence 100 % MVC), opération O4 du MCT.
///
/// La force change d'un jour à l'autre (fatigue, et c'est encore plus vrai pour une personne
/// atteinte de sclérose en plaques) : il vaut mieux recalibrer au début de chaque séance.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.source});

  final SourceBrassard source;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _Etape { consignes, compteARebours, contraction, resultat, erreur }

class _CalibrationScreenState extends State<CalibrationScreen> {
  _Etape _etape = _Etape.consignes;
  int _decompte = 3;
  double _progression = 0;
  int? _nouvelleRef;
  String _message = '';
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _lancer() async {
    setState(() {
      _etape = _Etape.compteARebours;
      _decompte = 3;
    });
    // 3, 2, 1… pour que la personne se prépare
    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _decompte = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      _etape = _Etape.contraction;
      _progression = 0;
    });
    final debut = DateTime.now();
    _minuteur = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final t = DateTime.now().difference(debut).inMilliseconds / 3000;
      if (mounted) setState(() => _progression = t.clamp(0, 1).toDouble());
    });

    try {
      final ref = await widget.source.calibrer();
      _minuteur?.cancel();
      if (!mounted) return;
      setState(() {
        _nouvelleRef = ref;
        _etape = _Etape.resultat;
      });
      await _enregistrer(ref);
    } catch (e) {
      _minuteur?.cancel();
      if (!mounted) return;
      setState(() {
        _etape = _Etape.erreur;
        _message = e.toString();
      });
    }
  }

  /// Garde l'historique des calibrations côté serveur (vrai brassard seulement).
  Future<void> _enregistrer(int ref) async {
    final source = widget.source;
    if (source.simule || source.numeroSerie == null) {
      setState(() => _message = "Brassard simulé : calibration utilisée pour la séance, mais pas enregistrée.");
      return;
    }
    final reponse = await Api.current.saveCalibration({
      'numero_serie': source.numeroSerie!,
      if (source.firmware != null) 'firmware': source.firmware!,
      'ref_mvc_mv': '$ref',
      if (source.batteriePct != null) 'batterie': '${source.batteriePct}',
    });
    if (!mounted) return;
    setState(() => _message = reponse['status'] == 'success'
        ? 'Calibration enregistrée dans ton historique.'
        : "Calibration faite, mais non enregistrée : ${reponse['message'] ?? 'erreur'}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('CALIBRATION'),
        backgroundColor: Colors.orange[800],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: _contenu()),
      ),
    );
  }

  Widget _contenu() {
    switch (_etape) {
      case _Etape.consignes:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, color: Colors.orange, size: 60),
            const SizedBox(height: 20),
            const Text('Mesure de ta force maximale',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              "1. Brassard bien serré sur le biceps, électrodes collées sur la peau propre.\n"
              "2. Assieds-toi, coude plié à 90°.\n"
              "3. Au signal, serre le biceps le plus fort possible pendant 3 secondes.\n\n"
              "Cette valeur devient ton 100 % pour la séance. Refais-la à chaque séance : "
              "la force change d'un jour à l'autre.",
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text('Référence actuelle : ${widget.source.refMvcMv} mV',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 28),
            _bouton('COMMENCER', _lancer),
          ],
        );
      case _Etape.compteARebours:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Prépare-toi…', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 12),
            Text('$_decompte',
                style: const TextStyle(color: Colors.orange, fontSize: 96, fontWeight: FontWeight.bold)),
          ],
        );
      case _Etape.contraction:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SERRE AU MAXIMUM !',
                style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progression, minHeight: 16, color: Colors.redAccent, backgroundColor: Colors.white12),
            ),
            const SizedBox(height: 10),
            Text('${(3 - _progression * 3).ceil()} s', style: const TextStyle(color: Colors.white70)),
          ],
        );
      case _Etape.resultat:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text('Calibration terminée', style: TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 8),
            Text('Nouvelle référence 100 % : $_nouvelleRef mV',
                style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 28),
            _bouton('TERMINÉ', () => Navigator.pop(context, _nouvelleRef)),
          ],
        );
      case _Etape.erreur:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            const Text('Calibration impossible', style: TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 8),
            Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 28),
            _bouton('RÉESSAYER', _lancer),
          ],
        );
    }
  }

  Widget _bouton(String texte, VoidCallback action) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: action,
          child: Text(texte, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
}
