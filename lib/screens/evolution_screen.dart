import 'package:flutter/material.dart';
import 'package:athletix_data/services/analyse/evolution.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/widgets/graphiques.dart';

/// Évolution semaine par semaine : volume, intensité, fatigue ressentie, records,
/// et semaines moins bonnes avec leurs causes possibles.
class EvolutionScreen extends StatefulWidget {
  const EvolutionScreen({super.key});

  @override
  State<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends State<EvolutionScreen> {
  Evolution? _evolution;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final data = await Api.current.getSeances(limite: 500);
    if (!mounted) return;
    setState(() {
      if (data['status'] == 'success') {
        final seances = (data['seances'] as List? ?? [])
            .map((m) => SeanceResume.depuisApi(Map<String, dynamic>.from(m as Map)))
            .whereType<SeanceResume>();
        _evolution = Evolution(seances);
      } else {
        _erreur = data['message']?.toString() ?? 'Erreur de chargement';
      }
    });
  }

  static String _jourMois(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final e = _evolution;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('MON ÉVOLUTION'), backgroundColor: Colors.blueGrey[900], centerTitle: true),
      body: e == null
          ? Center(
              child: _erreur != null
                  ? Text(_erreur!, style: const TextStyle(color: Colors.redAccent))
                  : const CircularProgressIndicator(color: Colors.orange))
          : e.seances.isEmpty
              ? const Center(
                  child: Text('Aucune séance pour l\'instant.', style: TextStyle(color: Colors.white54)))
              : _contenu(e),
    );
  }

  Widget _contenu(Evolution e) {
    final semaines = e.semaines;
    final libelles = semaines.map((s) => _jourMois(s.lundi)).toList();
    final moinsBonnes = e.semainesMoinsBonnes();
    final lundisMoinsBons = moinsBonnes.map((m) => m.semaine.lundi).toSet();
    final nbSimulees = e.seances.where((s) => s.simulee).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (nbSimulees > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('$nbSimulees séance(s) sur ${e.seances.length} faites avec le brassard simulé.',
                style: const TextStyle(color: Colors.amber, fontSize: 12)),
          ),
        _section('Points par semaine', 'Même règle que le classement. En rouge : semaine moins bonne.', [
          Histogramme(
            valeurs: semaines.map((s) => s.points.toDouble()).toList(),
            libelles: libelles,
            unite: 'points',
            couleurs: semaines.map((s) => lundisMoinsBons.contains(s.lundi) ? Colors.redAccent : Colors.orange).toList(),
          ),
        ]),
        _section('Volume', 'Temps d\'entraînement par semaine (minutes).', [
          Histogramme(
            valeurs: semaines.map((s) => s.dureeTotaleS / 60).toList(),
            libelles: libelles,
            unite: 'min',
            couleur: Colors.blue,
          ),
        ]),
        _section('Intensité et ressenti', 'Intensité musculaire (% MVC) et fatigue ressentie (×10 pour la même échelle).', [
          CourbesEvolution(
            libelles: libelles,
            series: [
              ('Intensité moyenne', Colors.orange, semaines.map((s) => s.nbSeances == 0 ? null : s.intensiteMoyenne).toList()),
              ('Intensité max', Colors.redAccent, semaines.map((s) => s.nbSeances == 0 ? null : s.intensiteMax.toDouble()).toList()),
              ('Fatigue ressentie ×10', Colors.purpleAccent,
                  semaines.map((s) => s.fatigueRessentie == null ? null : s.fatigueRessentie! * 10).toList()),
            ],
          ),
        ]),
        _section('Semaines moins bonnes', 'Rendement (points par heure) en baisse d\'au moins 15 % par rapport aux semaines précédentes.', [
          if (moinsBonnes.isEmpty)
            const Text('Aucune baisse marquée pour l\'instant.', style: TextStyle(color: Colors.white54))
          else
            for (final m in moinsBonnes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Semaine du ${_jourMois(m.semaine.lundi)} : rendement −${m.baissePct} %',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  for (final c in m.causes)
                    Text('• $c', style: const TextStyle(color: Colors.white70, height: 1.4)),
                ]),
              ),
          const Text('Pistes d\'explication tirées de ce que tu as noté, pas un diagnostic.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        _section('Records personnels', null, [
          for (final r in e.records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(r.libelle, style: const TextStyle(color: Colors.white70))),
                Text(r.valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(_jourMois(r.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
        ]),
      ],
    );
  }

  Widget _section(String titre, String? aide, List<Widget> enfants) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre.toUpperCase(),
              style: const TextStyle(color: Colors.orange, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold)),
          if (aide != null) Text(aide, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          ...enfants,
        ]),
      );
}
