import 'package:flutter/material.dart';
import 'package:athletix_data/services/sensor_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  /// Mesure EMG affichée pendant la séance (voir [_buildMesure]).
  final String mesure;

  const WorkoutDetailScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.mesure,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  // On initialise le service une seule fois ici
  final SensorService _sensorService = SensorService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.categoryName.toUpperCase()),
        backgroundColor: widget.categoryColor,
        centerTitle: true,
      ),
      body: StreamBuilder<int>(
        stream: _sensorService.heartRateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Mention honnête : le brassard n'est pas encore relié à l'appli
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Text("BPM simulés – brassard non relié",
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const Text("FRÉQUENCE CARDIAQUE (SIMULÉE)",
                style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${snapshot.data}",
                    style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: widget.categoryColor)),
                  const SizedBox(width: 10),
                  const Text("BPM", style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
              const Icon(Icons.favorite, color: Colors.red, size: 60),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Divider(color: Colors.white24, indent: 50, endIndent: 50),
              ),
              _buildMesure(),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("TERMINER LA SÉANCE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Ce que le brassard EMG (MyoWare 2.0) peut mesurer selon le type de sport.
  /// % MVC = pourcentage de la contraction maximale volontaire.
  Widget _buildMesure() {
    switch (widget.mesure) {
      case 'ACTIVITE_MOYENNE':
        return _mesureTile(Icons.show_chart, "ACTIVITÉ MUSCULAIRE MOYENNE", "38 % MVC", Colors.blue);
      case 'PIC_CONTRACTION':
        return _mesureTile(Icons.fitness_center, "PIC DE CONTRACTION", "92 % MVC", Colors.red);
      case 'EFFORTS_INTENSES':
        return _mesureTile(Icons.bolt, "EFFORTS INTENSES (> 75 % MVC)", "14", Colors.green);
      case 'HORS_LIGNE':
        return _mesureTile(Icons.waves, "MESURES GARDÉES DANS LE BRASSARD", "Envoi après la séance", Colors.cyan,
          note: "le Bluetooth ne passe pas sous l'eau");
      case 'RELACHEMENT':
        return _mesureTile(Icons.self_improvement, "RELÂCHEMENT MUSCULAIRE", "6 % MVC", Colors.purple);
      default:
        return const SizedBox();
    }
  }

  Widget _mesureTile(IconData icon, String label, String value, Color color, {String? note}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        Text(value, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
        Text(note == null ? "valeur d'exemple" : "valeur d'exemple · $note",
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}