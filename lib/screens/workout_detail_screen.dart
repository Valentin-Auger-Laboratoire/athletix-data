import 'package:flutter/material.dart';
import 'package:athletix_data/services/sensor_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  final String engineType;

  const WorkoutDetailScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    this.engineType = 'GPS_CARDIO',
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
              _buildEngineInterface(),
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

  Widget _buildEngineInterface() {
    switch (widget.engineType) {
      case 'GPS_CARDIO':
        return _engineTile(Icons.speed, "VITESSE ESTIMÉE", "12.4 km/h", Colors.blue);
      case 'GYRO_POWER':
        return _engineTile(Icons.fitness_center, "RÉPÉTITIONS", "12 REPS", Colors.red);
      case 'ACCEL_SPRINT':
        return _engineTile(Icons.bolt, "CHARGE D'EXPLOSIVITÉ", "High", Colors.green);
      case 'OFFLINE':
        return _engineTile(Icons.waves, "MODE AQUATIQUE", "Stockage interne...", Colors.cyan);
      case 'STABILITY':
        return _engineTile(Icons.balance, "STABILITÉ / FOCUS", "98%", Colors.purple);
      default:
        return const SizedBox();
    }
  }

  Widget _engineTile(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
        const Text("valeur d'exemple", style: TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}