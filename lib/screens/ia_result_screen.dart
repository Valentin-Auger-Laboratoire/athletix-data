// ia_result_screen.dart

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'home_screen.dart';
import 'questionnaire_screen.dart';

class IaResultScreen extends StatefulWidget {
  final Map<String, dynamic> profil;
  // ✅ RAJOUT : On permet au Home d'envoyer l'historique ici
  final List<Map<String, dynamic>> historique; 

  const IaResultScreen({
    super.key,
    required this.profil,
    required this.historique, // ✅ RAJOUT : Obligatoire pour corriger l'erreur du Home
  });

  @override
  State<IaResultScreen> createState() => _IaResultScreenState();
}

class _IaResultScreenState extends State<IaResultScreen> {
  List<Map<String, dynamic>> _historique = [];
  bool _loadingHistorique = true;

  @override
  void initState() {
    super.initState();
    _historique = widget.historique;
    _loadHistorique(); // ✅ charge l'historique depuis la BDD (ou la démo) au démarrage
  }

  Future<void> _loadHistorique() async {
    final data = await Api.current.getProfil();
    if (!mounted) return;
    setState(() {
      if (data['status'] == 'success') {
        _historique = List<Map<String, dynamic>>.from(data['historique'] ?? []);
      }
      _loadingHistorique = false;
    });
  }

  List<Map<String, dynamic>> _generateAdvice() {
    List<Map<String, dynamic>> conseils = [];
    final profil = widget.profil;

    if (profil['objectif_principal'] == 'Endurance') {
      conseils.add({'icon': Icons.directions_run, 'color': Colors.blue,
        'titre': 'Objectif Endurance détecté',
        'conseil': 'Privilégie des séances longues à faible intensité. Vise 3-4 sorties/semaine avec 70% de ta fréquence cardiaque max.',});
    } else if (profil['objectif_principal'] == 'Prise de masse') {
      conseils.add({'icon': Icons.fitness_center, 'color': Colors.red,
        'titre': 'Objectif Force détecté',
        'conseil': 'Concentre-toi sur des séries lourdes (4-6 reps). Assure-toi de consommer suffisamment de protéines après chaque séance.',});
    } else if (profil['objectif_principal'] == 'Perte de poids') {
      conseils.add({'icon': Icons.local_fire_department, 'color': Colors.orange,
        'titre': 'Objectif Minceur détecté',
        'conseil': 'Combine cardio HIIT et musculation légère. Crée un déficit calorique modéré de 300-500 kcal/jour.',});
    } else if (profil['objectif_principal'] == 'Santé') {
      conseils.add({'icon': Icons.favorite, 'color': Colors.pink,
        'titre': 'Objectif Santé détecté',
        'conseil': 'Varie les activités : marche, natation, yoga. L\'important c\'est la régularité, pas l\'intensité !',});
    }

    if (profil['niveau_sportif'] == 'Débutant') {
      conseils.add({'icon': Icons.star_border, 'color': Colors.amber,
        'titre': 'Débutant — Progression douce',
        'conseil': 'Commence par 2-3 séances/semaine de 30 min. Augmente progressivement. Écoute ton corps avant tout.',});
    } else if (profil['niveau_sportif'] == 'Pro') {
      conseils.add({'icon': Icons.star, 'color': Colors.amber,
        'titre': 'Niveau Pro — Intensité maximale',
        'conseil': 'Tu peux viser 5-6 séances/semaine. Intègre des cycles de surcharge progressive et des semaines de décharge.',});
    }

    final blessure = profil['pathologies_blessures']?.toString() ?? '';
    if (blessure != 'Aucune' && blessure.isNotEmpty) {
      String cb = 'Adapte ton entraînement en fonction de cette zone.';
      if (blessure == 'Genou') {
        cb = 'Évite la course en descente et les squats profonds. Privilégie le vélo elliptique et la natation.';
      } else if (blessure == 'Dos') {
        cb = 'Renforce tes abdominaux et évite les soulevés de terre. Le gainage est ton meilleur allié.';
      } else if (blessure == 'Épaule') {
        cb = 'Évite les mouvements au-dessus de la tête. Travaille la coiffe des rotateurs avec des élastiques.';
      } else if (blessure == 'Cheville') {
        cb = 'Fais des exercices de proprioception. Évite les terrains accidentés et préfère la piscine.';
      }
      conseils.add({'icon': Icons.healing, 'color': Colors.red[300],
        'titre': '⚠️ Blessure $blessure détectée', 'conseil': cb,});
    }

    int stress = int.tryParse(profil['niveau_stress']?.toString() ?? '5') ?? 5;
    if (stress >= 7) {
      conseils.add({'icon': Icons.self_improvement, 'color': Colors.purple,
        'titre': 'Stress élevé détecté',
        'conseil': 'Intègre quelques minutes de respiration calme ou de méditation avant ta séance, et garde les séances intenses pour les jours plus sereins.',});
    }

    if (profil['qualite_sommeil'] == 'Mauvaise') {
      conseils.add({'icon': Icons.bedtime, 'color': Colors.indigo,
        'titre': 'Récupération insuffisante',
        'conseil': 'Un sommeil insuffisant freine la récupération et les performances. Évite le sport intense tard le soir et garde des horaires de coucher réguliers.',});
    }

    if (profil['antecedents_cardio_perso']?.toString() == '1' ||
        profil['antecedents_cardio_famille']?.toString() == '1') {
      conseils.add({'icon': Icons.monitor_heart, 'color': Colors.red,
        'titre': 'Antécédents cardio-vasculaires signalés',
        'conseil': 'Demande l\'avis d\'un médecin avant de reprendre ou d\'intensifier l\'entraînement. Ces conseils ne remplacent pas un avis médical.',});
    }

    return conseils;
  }

  @override
  Widget build(BuildContext context) {
    final conseils = _generateAdvice();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 25),
              decoration: BoxDecoration(
                color: Colors.orange[800],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 45),
                  const SizedBox(height: 8),
                  Text("Profil de ${Api.session?.pseudo ?? 'Athlète'}",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Conseils générés par règles (pas d'IA entraînée)",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ONGLET 1 : TES INFORMATIONS
            _buildSectionTitle(Icons.person, "TES INFORMATIONS", Colors.blue),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.flag, "Objectif", widget.profil['objectif_principal']),
                  _buildInfoRow(Icons.bar_chart, "Niveau", widget.profil['niveau_sportif']),
                  _buildInfoRow(Icons.monitor_weight, "Poids", "${widget.profil['poids']} kg"),
                  _buildInfoRow(Icons.height, "Taille", "${widget.profil['taille']} cm"),
                  _buildInfoRow(Icons.calendar_today, "Fréquence", "${widget.profil['frequence']}x / semaine"),
                  _buildInfoRow(Icons.healing, "Blessures", widget.profil['pathologies_blessures']),
                  _buildInfoRow(Icons.bedtime, "Sommeil", widget.profil['qualite_sommeil']),
                  _buildInfoRow(Icons.psychology, "Stress", "${widget.profil['niveau_stress']}/10"),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ONGLET 2 : CONSEILS IA
            _buildSectionTitle(Icons.auto_awesome, "CONSEILS GÉNÉRÉS PAR RÈGLES", Colors.blue),
            ...conseils.map((conseil) => _buildConseilCard(conseil)),

            const SizedBox(height: 25),

            // ONGLET 3 : HISTORIQUE chargé depuis la BDD
            _buildSectionTitle(Icons.history, "HISTORIQUE DES PROFILS", Colors.purple),

            _loadingHistorique
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Colors.purple),
                )
              : _historique.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Aucun historique disponible",
                      style: TextStyle(color: Colors.white38)),
                  )
                : Column(
                    children: _historique.asMap().entries.map((entry) {
                      final index = entry.key;
                      final h = entry.value;
                      final isLatest = index == 0;
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(14),
                          border: isLatest
                              ? Border.all(color: Colors.orange, width: 1.5)
                              : Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLatest ? Icons.fiber_new : Icons.history,
                              color: isLatest ? Colors.orange : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLatest
                                      ? "Profil actuel"
                                      : (h['created_at']?.toString().substring(0, 10) ?? 'Ancien profil'),
                                    style: TextStyle(
                                      color: isLatest ? Colors.orange : Colors.white54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "${h['objectif_principal']} • ${h['niveau_sportif']} • ${h['poids']} kg",
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 25),

            // BOUTON METTRE À JOUR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuestionnaireScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, color: Colors.orange),
                label: const Text("Mettre à jour mon profil",
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 15),

            // BOUTON RETOUR HOME
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 55),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text("RETOUR À L'ACCUEIL",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Text("$label :", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value?.toString() ?? '-',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildConseilCard(Map<String, dynamic> conseil) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: (conseil['color'] as Color).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (conseil['color'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(conseil['icon'], color: conseil['color'], size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conseil['titre'],
                  style: TextStyle(color: conseil['color'], fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(conseil['conseil'],
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}