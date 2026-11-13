import 'package:flutter/material.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'calibration_screen.dart';
import 'natation_screen.dart';
import 'workout_detail_screen.dart';

class SelectionScreen extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final List<String> subCategories;
  final String categoryMesure;

  const SelectionScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.subCategories,
    required this.categoryMesure,
  });

  /// Le vrai brassard oublie sa référence 100 % quand il s'éteint, et la force change d'un jour à
  /// l'autre (rencontre avec la patiente atteinte de sclérose en plaques) : on propose de calibrer
  /// si ce n'est pas fait depuis la connexion, ou depuis plus de 4 h. Renvoie false si on annule.
  static Future<bool> _calibrationFaite(BuildContext context) async {
    final source = BrassardActif.source;
    if (source == null || source.simule) return true;
    final le = source.calibreLe;
    if (le != null && DateTime.now().difference(le) < const Duration(hours: 4)) return true;
    final choix = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Calibrer avant la séance ?'),
        content: Text(le == null
            ? "Le brassard n'a pas été calibré depuis qu'il est allumé : les % affichés seraient faux."
            : 'Dernière calibration il y a plus de 4 h : la force change au fil de la journée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, 'sans'), child: const Text('Commencer quand même')),
          ElevatedButton(onPressed: () => Navigator.pop(c, 'calibrer'), child: const Text('Calibrer (3 s)')),
        ],
      ),
    );
    if (choix == 'sans') return true;
    if (choix != 'calibrer' || !context.mounted) return false;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CalibrationScreen(source: source)));
    return source.calibreLe != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: categoryColor,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        itemBuilder: (context, index) {
          final sport = subCategories[index];
          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              // ✅ withOpacity → withValues
              side: BorderSide(color: categoryColor.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(
                sport,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: categoryColor, size: 18),
              onTap: () async {
                if (!await _calibrationFaite(context)) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Sports dans l'eau : le brassard enregistre seul (pas de Bluetooth sous l'eau)
                    builder: (context) => categoryMesure == 'HORS_LIGNE'
                        ? NatationScreen(discipline: sport, couleur: categoryColor)
                        : WorkoutDetailScreen(
                            categoryName: sport,
                            categoryColor: categoryColor,
                            mesure: categoryMesure,
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}