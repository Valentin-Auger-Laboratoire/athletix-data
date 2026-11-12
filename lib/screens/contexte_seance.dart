import 'package:flutter/material.dart';

/// Questions rapides en fin de séance : elles servent à expliquer les séances moins bonnes
/// (fatigue, douleur, sommeil). Tout est facultatif : « Passer » enregistre sans contexte.
Future<Map<String, String>> demanderContexte(BuildContext context) async {
  final resultat = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _FormulaireContexte(),
  );
  return resultat ?? {};
}

class _FormulaireContexte extends StatefulWidget {
  const _FormulaireContexte();

  @override
  State<_FormulaireContexte> createState() => _FormulaireContexteState();
}

class _FormulaireContexteState extends State<_FormulaireContexte> {
  double _fatigue = 5;
  double _douleur = 0;
  String? _sommeil;
  final _commentaire = TextEditingController();

  static const sommeils = ['Mauvais', 'Moyen', 'Bon'];

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Widget _curseur(String titre, double valeur, ValueChanged<double> changer, String bas, String haut, Color couleur) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$titre : ${valeur.round()} / 10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      Slider(value: valeur, min: 0, max: 10, divisions: 10, activeColor: couleur, onChanged: changer),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(bas, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Text(haut, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comment ça s\'est passé ?',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Ces réponses aident à comprendre les séances moins bonnes. Tout est facultatif.",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 18),
            _curseur('Fatigue ressentie', _fatigue, (v) => setState(() => _fatigue = v), 'en forme', 'épuisé·e',
                Colors.orange),
            const SizedBox(height: 10),
            _curseur('Douleur', _douleur, (v) => setState(() => _douleur = v), 'aucune', 'très forte', Colors.redAccent),
            const SizedBox(height: 14),
            const Text('Sommeil la nuit dernière', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final s in sommeils)
                ChoiceChip(
                  label: Text(s),
                  selected: _sommeil == s,
                  onSelected: (_) => setState(() => _sommeil = _sommeil == s ? null : s),
                ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _commentaire,
              maxLength: 500,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Commentaire (blessure, météo, matériel…)',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context, <String, String>{}),
                child: const Text('Passer', style: TextStyle(color: Colors.white54)),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], minimumSize: const Size(150, 48)),
                onPressed: () => Navigator.pop(context, {
                  'ressenti_fatigue': '${_fatigue.round()}',
                  'douleur': '${_douleur.round()}',
                  if (_sommeil != null) 'sommeil': _sommeil!,
                  if (_commentaire.text.trim().isNotEmpty) 'commentaire': _commentaire.text.trim(),
                }),
                child: const Text('ENREGISTRER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
