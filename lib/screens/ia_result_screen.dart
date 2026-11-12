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

  /// Nombre de séances par semaine conseillé selon le niveau : (minimum, maximum).
  static const Map<String, List<int>> _plageSeances = {
    'Débutant': [2, 3],
    'Intermédiaire': [3, 4],
    'Pro': [4, 6],
  };

  /// IMC = poids (kg) / taille (m)². Null si une valeur manque.
  double? _imc(Map<String, dynamic> profil) {
    final poids = double.tryParse(profil['poids']?.toString() ?? '');
    final taille = double.tryParse(profil['taille']?.toString() ?? '');
    if (poids == null || taille == null || taille <= 0) return null;
    final m = taille / 100;
    return poids / (m * m);
  }

  /// 22.1 → « 22,1 » (écriture française).
  String _virgule(double x) => x.toStringAsFixed(1).replaceAll('.', ',');

  /// Conseils produits par des règles simples (pas d'IA entraînée).
  /// Le nombre de séances n'est donné qu'à UN endroit (carte « Rythme »), calculé
  /// à partir du niveau ET de la fréquence déclarée : les cartes ne se contredisent pas.
  List<Map<String, dynamic>> _generateAdvice() {
    final List<Map<String, dynamic>> conseils = [];
    final profil = widget.profil;
    final objectif = profil['objectif_principal']?.toString() ?? '';
    final niveau = profil['niveau_sportif']?.toString() ?? 'Débutant';
    final frequence = int.tryParse(profil['frequence']?.toString() ?? '') ?? 0;
    final poids = double.tryParse(profil['poids']?.toString() ?? '');
    final imc = _imc(profil);
    final plage = _plageSeances[niveau] ?? const [2, 3];
    final mini = plage[0], maxi = plage[1];

    // 1. Rythme : niveau + fréquence déclarée
    String rythme;
    if (frequence > maxi) {
      rythme = 'Tu as indiqué $frequence séances par semaine. Au niveau $niveau, vise plutôt $mini à $maxi séances '
          'avec des jours de repos entre elles : le muscle progresse pendant la récupération.';
    } else if (frequence < mini) {
      rythme = 'Tu as indiqué $frequence séance${frequence > 1 ? 's' : ''} par semaine. Au niveau $niveau, '
          'tu peux monter progressivement jusqu\'à $mini à $maxi séances, en ajoutant une séance à la fois.';
    } else {
      rythme = 'Tes $frequence séances par semaine correspondent au niveau $niveau ($mini à $maxi). Garde ce rythme et '
          'augmente plutôt la durée ou la difficulté petit à petit.';
    }
    if (niveau == 'Débutant') {
      rythme += ' Commence par des séances de 30 minutes et écoute ton corps.';
    } else if (niveau == 'Intermédiaire') {
      rythme += ' Varie les séances (une plus intense, les autres plus faciles) pour continuer à progresser.';
    } else if (niveau == 'Pro') {
      rythme += ' Prévois une semaine plus légère toutes les 3 à 4 semaines.';
    }
    conseils.add({'icon': Icons.calendar_month, 'color': Colors.amber,
      'titre': 'Rythme conseillé — niveau $niveau', 'conseil': rythme,});

    // 2. Objectif (sans nombre de séances, pour ne pas contredire la carte Rythme)
    if (objectif == 'Endurance') {
      String c = 'Fais la plupart de tes séances à allure facile (tu peux parler en courant) et une seule séance plus intense par semaine.';
      if (imc != null && imc >= 30) {
        c += ' Pour ménager tes articulations, alterne avec le vélo ou la natation.';
      }
      conseils.add({'icon': Icons.directions_run, 'color': Colors.blue,
        'titre': 'Objectif Endurance', 'conseil': c,});
    } else if (objectif == 'Prise de masse') {
      String c = 'Travaille en séries lourdes (6 à 12 répétitions) et augmente la charge peu à peu.';
      if (poids != null) {
        final bas = (poids * 1.6).round(), haut = (poids * 2.0).round();
        c += ' Repère courant : environ $bas à $haut g de protéines par jour pour ${poids.round()} kg.';
      }
      conseils.add({'icon': Icons.fitness_center, 'color': Colors.red,
        'titre': 'Objectif Prise de masse', 'conseil': c,});
    } else if (objectif == 'Perte de poids') {
      if (imc != null && imc < 18.5) {
        conseils.add({'icon': Icons.warning_amber, 'color': Colors.red,
          'titre': 'Objectif Perte de poids — à revoir',
          'conseil': 'Ton IMC calculé (${_virgule(imc)}) est déjà sous 18,5. Perdre du poids n\'est pas conseillé : parles-en à un médecin avant.',});
      } else {
        conseils.add({'icon': Icons.local_fire_department, 'color': Colors.orange,
          'titre': 'Objectif Perte de poids',
          'conseil': 'Combine cardio et renforcement musculaire, avec un léger déficit (300 à 500 kcal par jour). '
              'Vise une perte lente, autour de 0,5 kg par semaine.',});
      }
    } else if (objectif == 'Santé') {
      conseils.add({'icon': Icons.favorite, 'color': Colors.pink,
        'titre': 'Objectif Santé',
        'conseil': 'Varie les activités (marche, natation, yoga). L\'important est la régularité, pas l\'intensité.',});
    }

    // 3. Corpulence (poids + taille)
    if (imc != null) {
      String c;
      if (imc < 18.5) {
        c = 'IMC ${_virgule(imc)} : sous la zone habituelle (18,5 à 25). Mange suffisamment autour des séances.';
      } else if (imc < 25) {
        c = 'IMC ${_virgule(imc)} : dans la zone habituelle (18,5 à 25).';
      } else if (imc < 30) {
        c = 'IMC ${_virgule(imc)} : un peu au-dessus de la zone habituelle. Les activités portées (vélo, natation) ménagent les genoux.';
      } else {
        c = 'IMC ${_virgule(imc)} : privilégie les activités portées (vélo, natation, marche) et demande conseil à un médecin pour reprendre.';
      }
      c += ' L\'IMC ne distingue pas le muscle de la graisse : c\'est un repère, pas un diagnostic.';
      conseils.add({'icon': Icons.monitor_weight, 'color': Colors.teal,
        'titre': 'Taille et poids', 'conseil': c,});
    }

    // 4. Blessures
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
        'titre': '⚠️ Blessure $blessure signalée', 'conseil': cb,});
    }

    // 5. Stress et sommeil
    final stress = int.tryParse(profil['niveau_stress']?.toString() ?? '5') ?? 5;
    if (stress >= 7) {
      conseils.add({'icon': Icons.self_improvement, 'color': Colors.purple,
        'titre': 'Stress élevé',
        'conseil': 'Intègre quelques minutes de respiration calme ou de méditation avant ta séance, et garde les séances intenses pour les jours plus sereins.',});
    }
    if (profil['qualite_sommeil'] == 'Mauvaise') {
      conseils.add({'icon': Icons.bedtime, 'color': Colors.indigo,
        'titre': 'Récupération insuffisante',
        'conseil': 'Un sommeil insuffisant freine la récupération et les performances. Évite le sport intense tard le soir et garde des horaires de coucher réguliers.',});
    }

    // 6. Antécédents cardio
    if (profil['antecedents_cardio_perso']?.toString() == '1' ||
        profil['antecedents_cardio_famille']?.toString() == '1') {
      conseils.add({'icon': Icons.monitor_heart, 'color': Colors.red,
        'titre': 'Antécédents cardio-vasculaires signalés',
        'conseil': 'Demande l\'avis d\'un médecin avant de reprendre ou d\'intensifier l\'entraînement.',});
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text("Repères généraux : ils ne remplacent pas un avis médical.",
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),

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
                      builder: (context) => QuestionnaireScreen(initial: widget.profil),
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