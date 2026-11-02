// questionnaire_screen.dart

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'ia_result_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final String userName = Api.session?.pseudo ?? "Athlète";
  String _selectedGoal = 'Endurance';
  String _selectedLevel = 'Débutant';
  double _weight = 75;
  double _height = 175;
  int _frequency = 3;
  String _selectedInjury = 'Aucune';
  bool _hasPersonalCardioIssue = false;
  bool _hasFamilyCardioHistory = false;
  String _sleepQuality = 'Moyenne';
  int _stressLevel = 5;
  bool _isLoading = false;

  Future<void> _saveProfileToDatabase() async {
    setState(() => _isLoading = true);

    // ✅ Tous les champs du questionnaire sont envoyés, y compris fréquence et antécédents cardio
    final profil = <String, String>{
      "objectif_principal":         _selectedGoal,
      "niveau_sportif":             _selectedLevel,
      "poids":                      _weight.toInt().toString(),
      "taille":                     _height.toInt().toString(),
      "frequence":                  _frequency.toString(),
      "pathologies_blessures":      _selectedInjury,
      "antecedents_cardio_perso":   _hasPersonalCardioIssue ? '1' : '0',
      "antecedents_cardio_famille": _hasFamilyCardioHistory ? '1' : '0',
      "qualite_sommeil":            _sleepQuality,
      "niveau_stress":              _stressLevel.toString(),
    };

    final data = await Api.current.saveProfil(profil);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (data['status'] == 'success') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => IaResultScreen(profil: profil, historique: const []),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ ${data['message'] ?? 'Erreur'}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Profil de $userName"),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PERSONNALISATION DES CONSEILS",
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              Api.isDemo
                  ? "Mode démo : utilise des valeurs fictives, rien n'est envoyé à un serveur."
                  : "Données de santé : n'entre que des valeurs fictives sur une instance de test.",
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 25),

            // 1. OBJECTIF
            const Text("Quel est ton objectif principal ?", style: TextStyle(color: Colors.white)),
            DropdownButton<String>(
              value: _selectedGoal,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.orange, fontSize: 16),
              items: <String>['Endurance', 'Prise de masse', 'Perte de poids', 'Santé']
                  .map((String value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedGoal = val!),
            ),

            const SizedBox(height: 25),

            // 2. TAILLE
            Text("Ta taille : ${_height.toInt()} cm", style: const TextStyle(color: Colors.white)),
            Slider(
              value: _height, min: 120, max: 220, activeColor: Colors.cyan,
              onChanged: (val) => setState(() => _height = val),
            ),

            // 3. POIDS
            Text("Ton poids : ${_weight.toInt()} kg", style: const TextStyle(color: Colors.white)),
            Slider(
              value: _weight, min: 40, max: 160, activeColor: Colors.blue,
              onChanged: (val) => setState(() => _weight = val),
            ),

            const SizedBox(height: 20),

            // 4. FRÉQUENCE
            Text("Fréquence d'entraînement : $_frequency fois / semaine",
                style: const TextStyle(color: Colors.white)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: List.generate(7, (index) {
                int val = index + 1;
                return ChoiceChip(
                  label: Text("$val"),
                  selected: _frequency == val,
                  onSelected: (selected) => setState(() => _frequency = val),
                );
              }),
            ),

            const SizedBox(height: 25),

            // 5. NIVEAU
            const Text("Ton niveau actuel :", style: TextStyle(color: Colors.white)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Débutant', 'Intermédiaire', 'Pro'].map((level) {
                return ChoiceChip(
                  label: Text(level),
                  selected: _selectedLevel == level,
                  onSelected: (selected) => setState(() => _selectedLevel = level),
                );
              }).toList(),
            ),

            const SizedBox(height: 25),

            // 6. BLESSURES
            const Text("Anciennes blessures ou actuelles ?", style: TextStyle(color: Colors.white)),
            Wrap(
              spacing: 8,
              children: ['Aucune', 'Genou', 'Dos', 'Épaule', 'Cheville'].map((injury) {
                return ChoiceChip(
                  label: Text(injury),
                  selected: _selectedInjury == injury,
                  selectedColor: Colors.orange,
                  onSelected: (selected) => setState(() => _selectedInjury = injury),
                );
              }).toList(),
            ),

            const SizedBox(height: 25),

            // 7. CARDIO
            const Text("Santé Cardio-vasculaire :",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Antécédents personnels ?",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _hasPersonalCardioIssue,
              activeTrackColor: Colors.red,
              onChanged: (val) => setState(() => _hasPersonalCardioIssue = val),
            ),
            SwitchListTile(
              title: const Text("Antécédents familiaux ?",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _hasFamilyCardioHistory,
              activeTrackColor: Colors.orange,
              onChanged: (val) => setState(() => _hasFamilyCardioHistory = val),
            ),

            const SizedBox(height: 25),

            // 8. RÉCUPÉRATION
            const Text("Récupération & Bien-être :",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            const Text("Qualité du sommeil", style: TextStyle(color: Colors.white70)),
            DropdownButton<String>(
              value: _sleepQuality,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: ['Mauvaise', 'Moyenne', 'Bonne', 'Excellente']
                  .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                  .toList(),
              onChanged: (val) => setState(() => _sleepQuality = val!),
            ),

            const SizedBox(height: 10),
            Text("Niveau de stress ressenti (1-10) : $_stressLevel",
                style: const TextStyle(color: Colors.white)),
            Slider(
              value: _stressLevel.toDouble(),
              min: 1, max: 10, divisions: 9,
              activeColor: Colors.purple,
              onChanged: (val) => setState(() => _stressLevel = val.toInt()),
            ),

            const SizedBox(height: 40),

            // BOUTON SAUVEGARDER
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isLoading ? null : _saveProfileToDatabase,
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAUVEGARDER MES INFOS",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
