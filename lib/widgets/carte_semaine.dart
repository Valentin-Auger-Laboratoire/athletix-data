import 'package:flutter/material.dart';
import 'package:athletix_data/services/analyse/evolution.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/file_envoi.dart';
import 'package:athletix_data/services/reglages.dart';

/// Accueil : la semaine en cours face à l'objectif, et les séances qui attendent le réseau.
class CarteSemaine extends StatefulWidget {
  const CarteSemaine({super.key, this.onOuvrir});

  /// Appelé au toucher (ouvre « Mon évolution »).
  final VoidCallback? onOuvrir;

  @override
  State<CarteSemaine> createState() => _CarteSemaineState();
}

class _CarteSemaineState extends State<CarteSemaine> {
  Semaine? _semaine;
  int _enAttente = 0;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    Api.seancesModifiees.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    Api.seancesModifiees.removeListener(_charger);
    super.dispose();
  }

  Future<void> _charger() async {
    // D'abord renvoyer ce qui attend le réseau, puis compter
    final envoyees = await FileEnvoi.envoyer();
    final data = await Api.current.getSeances(limite: 60);
    final attente = await FileEnvoi.nombre();
    if (!mounted) return;
    final lundi = Evolution.lundiDe(DateTime.now());
    final seances = (data['seances'] as List? ?? [])
        .map((m) => SeanceResume.depuisApi(Map<String, dynamic>.from(m as Map)))
        .whereType<SeanceResume>()
        .where((s) => !s.debut.isBefore(lundi))
        .toList();
    setState(() {
      _charge = true;
      _semaine = Semaine(lundi, seances);
      _enAttente = attente;
    });
    if (envoyees > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$envoyees séance(s) gardée(s) hors connexion envoyée(s)'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _semaine;
    return ValueListenableBuilder<int>(
      valueListenable: Reglages.objectifSeances,
      builder: (context, objectif, _) {
        final fait = s?.nbSeances ?? 0;
        final progression = (fait / objectif).clamp(0.0, 1.0);
        return Semantics(
          button: true,
          label: 'Cette semaine : $fait séance${fait > 1 ? 's' : ''} sur $objectif, '
              '${(s?.dureeTotaleS ?? 0) ~/ 60} minutes, ${s?.points ?? 0} points. Ouvre mon évolution.',
          excludeSemantics: true,
          child: InkWell(
          onTap: widget.onOuvrir,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
            child: !_charge
                ? const SizedBox(height: 40, child: Center(child: LinearProgressIndicator(color: Colors.orange)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('CETTE SEMAINE',
                          style: TextStyle(color: Colors.orange, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(fait >= objectif ? 'objectif atteint ✓' : '$fait / $objectif séances',
                          style: TextStyle(
                              color: fait >= objectif ? Colors.greenAccent : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progression,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: fait >= objectif ? Colors.greenAccent : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(s?.dureeTotaleS ?? 0) ~/ 60} min · ${s?.points ?? 0} points'
                      '${(s?.distanceM ?? 0) > 0 ? ' · ${((s!.distanceM) / 1000).toStringAsFixed(1).replaceAll('.', ',')} km' : ''}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (_enAttente > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('☁ $_enAttente séance(s) en attente de réseau, envoi automatique',
                            style: const TextStyle(color: Colors.amber, fontSize: 12)),
                      ),
                  ]),
          ),
        ),
        );
      },
    );
  }
}
