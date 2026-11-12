import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';

/// Historique des séances enregistrées et de leur résumé EMG (backend/get_seances.php).
class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  List<Map<String, dynamic>> _seances = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final data = await Api.current.getSeances();
    if (!mounted) return;
    setState(() {
      _chargement = false;
      if (data['status'] == 'success') {
        _seances = List<Map<String, dynamic>>.from(data['seances'] ?? []);
        _erreur = null;
      } else {
        _erreur = data['message']?.toString() ?? 'Erreur de chargement';
      }
    });
  }

  static String duree(int secondes) {
    final h = secondes ~/ 3600, m = (secondes % 3600) ~/ 60, s = secondes % 60;
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}';
    return '$m min ${s.toString().padLeft(2, '0')} s';
  }

  /// « 2026-11-10 18:05:00 » → « 10/11/2026 à 18:05 »
  static String date(String? brute) {
    if (brute == null || brute.length < 16) return '—';
    return '${brute.substring(8, 10)}/${brute.substring(5, 7)}/${brute.substring(0, 4)} à ${brute.substring(11, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('MES SÉANCES'), backgroundColor: Colors.blueGrey[900], centerTitle: true),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _erreur != null
              ? Center(child: Text(_erreur!, style: const TextStyle(color: Colors.redAccent)))
              : _seances.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text("Aucune séance enregistrée pour l'instant.\nLance une séance depuis l'accueil.",
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      color: Colors.orange,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _seances.length,
                        itemBuilder: (context, i) => _carte(_seances[i]),
                      ),
                    ),
    );
  }

  Widget _carte(Map<String, dynamic> s) {
    final simule = s['donnees_simulees'] == true;
    Widget chiffre(String libelle, String valeur) => Expanded(
          child: Column(children: [
            Text(valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(libelle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        );
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${s['discipline']}',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              if (simule)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(10)),
                  child: const Text('simulée', style: TextStyle(color: Colors.amber, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 2),
            Text('${date(s['debut']?.toString())} · ${duree((s['duree_s'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              chiffre('moyenne', '${s['intensite_moyenne_pct']} %'),
              chiffre('maximum', '${s['intensite_max_pct']} %'),
              chiffre('effort intense', duree((s['temps_effort_intense_s'] as num?)?.toInt() ?? 0)),
              chiffre('alertes', '${s['nb_alertes']}'),
            ]),
          ],
        ),
      ),
    );
  }
}
