import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Consentement au premier lancement : les mesures du muscle sont des données de santé (RGPD).
///
/// L'accord est retenu sur l'appareil. Version dans la clé : si le texte change,
/// on redemande l'accord.
class Consentement {
  Consentement._();

  static const String cle = 'athletix_consentement_v1';

  static Future<bool> dejaDonne() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(cle) ?? false;
    } catch (_) {
      return false; // stockage indisponible (navigation privée…) : on redemande
    }
  }

  static Future<void> enregistrer() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(cle, true);
    } catch (_) {/* l'accord vaut pour cette ouverture seulement */}
  }

  /// Affiche la fenêtre si l'accord n'a pas encore été donné.
  /// Renvoie false si la personne refuse : l'appelant doit alors fermer la session.
  static Future<bool> demanderSiBesoin(BuildContext context, {required bool demo}) async {
    if (await dejaDonne()) return true;
    if (!context.mounted) return false;
    final accord = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Tes données', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            "Athletix-Data mesure l'activité de ton muscle et enregistre ton profil (taille, poids, "
            "blessures, sommeil…). Ce sont des données de santé.\n\n"
            "• Elles servent uniquement à t'afficher tes mesures, tes séances et tes conseils.\n"
            "• Seul un résumé de chaque séance est enregistré, jamais le signal complet.\n"
            "• Tu peux demander leur suppression à tout moment à l'équipe du projet.\n"
            "• Athletix-Data est un projet étudiant : ce n'est pas un dispositif médical, "
            "il ne remplace pas l'avis d'un médecin.\n"
            "${demo ? "\nMode démo : utilise uniquement des données fictives, rien n'est envoyé à un serveur." : ""}",
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Refuser', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("J'accepte", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (accord == true) await enregistrer();
    return accord == true;
  }
}
