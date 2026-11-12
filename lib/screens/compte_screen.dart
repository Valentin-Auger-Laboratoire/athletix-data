import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:athletix_data/services/api.dart';
import 'landing_screen.dart';

/// Mon compte et mes données (RGPD) : télécharger toutes ses données, supprimer son compte.
class CompteScreen extends StatefulWidget {
  const CompteScreen({super.key});

  @override
  State<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends State<CompteScreen> {
  bool _occupe = false;

  Future<void> _exporter() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _occupe = true);
    final r = await Api.current.exporterDonnees();
    if (!mounted) return;
    setState(() => _occupe = false);
    if (r['status'] != 'success') {
      messenger.showSnackBar(SnackBar(content: Text('${r['message'] ?? 'Export impossible'}'), backgroundColor: Colors.red));
      return;
    }
    final texte = const JsonEncoder.withIndent('  ').convert(r..remove('status'));
    final nom = 'athletix-mes-donnees-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(Uint8List.fromList(utf8.encode(texte)), mimeType: 'application/json', name: nom)],
        fileNameOverrides: [nom],
        subject: 'Mes données Athletix-Data',
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Partage impossible : $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _supprimer() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final champ = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Supprimer mon compte ?', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Ton compte, tes profils, tes séances, tes calibrations et ton classement seront effacés "
            "définitivement. Pense à télécharger tes données avant.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: champ,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Mot de passe', labelStyle: TextStyle(color: Colors.white54)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    final motDePasse = champ.text;
    champ.dispose();
    if (confirme != true || !mounted) return;
    setState(() => _occupe = true);
    final r = await Api.current.supprimerCompte(motDePasse);
    if (!mounted) return;
    setState(() => _occupe = false);
    if (r['status'] != 'success') {
      messenger.showSnackBar(SnackBar(content: Text('${r['message'] ?? 'Suppression impossible'}'), backgroundColor: Colors.red));
      return;
    }
    Api.session = null;
    await Api.logout();
    messenger.showSnackBar(const SnackBar(content: Text('Compte et données supprimés'), backgroundColor: Colors.green));
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LandingScreen()), (_) => false);
  }

  Widget _carte(IconData icone, Color couleur, String titre, String texte, String bouton, VoidCallback? action) => Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icone, color: couleur),
              const SizedBox(width: 10),
              Expanded(child: Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
            const SizedBox(height: 8),
            Text(texte, style: const TextStyle(color: Colors.white60, height: 1.4)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: couleur)),
                onPressed: _occupe ? null : action,
                child: Text(bouton, style: TextStyle(color: couleur)),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final demo = Api.isDemo;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('MON COMPTE'), backgroundColor: Colors.blueGrey[900], centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(Api.session?.pseudo ?? 'Athlète',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(demo ? 'Compte de démonstration (données fictives)' : 'Compte connecté',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          _carte(Icons.download, Colors.lightBlueAccent, 'Télécharger mes données',
              "Un fichier JSON avec tout ce que le serveur garde sur toi : compte, profils, séances (avec courbes "
                  "et tracés), calibrations, brassard. Le mot de passe n'y figure pas (il n'est stocké que haché).",
              'TÉLÉCHARGER', _exporter),
          _carte(Icons.delete_forever, Colors.redAccent, 'Supprimer mon compte',
              demo
                  ? "Indisponible en démo : les données de la démo sont en mémoire et disparaissent quand tu la quittes."
                  : "Efface ton compte et toutes tes données du serveur, sans retour possible. "
                      "Ton mot de passe est redemandé.",
              'SUPPRIMER', demo ? null : _supprimer),
          const SizedBox(height: 6),
          const Text(
            "Données de santé (RGPD) : elles servent seulement à ton suivi et au classement (pseudo et score). "
            "Rien n'est revendu ni partagé. Le signal brut du muscle n'est jamais stocké, seulement un résumé. "
            "Projet étudiant, pas un dispositif médical.",
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
