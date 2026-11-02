// home_screen.dart

import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'landing_screen.dart';
import 'login_screen.dart';
import 'selection_screen.dart';
import 'questionnaire_screen.dart';
import 'classement_screen.dart';
import 'ia_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String userName = Api.session?.pseudo ?? "Athlète";
  String aiMessage = "Remplis ton profil pour obtenir des conseils personnalisés.";
  int? batteryLevel; // null = inconnu (aucune donnée du brassard)
  bool isConnected = false;
  Map<String, dynamic>? _profilExistant; // ✅ stocke le profil chargé
  List<Map<String, dynamic>> _historiqueProfils = [];

  @override
  void initState() {
    super.initState();
    _fetchHardwareStatus();
    _loadProfilIA(); // ✅ charge le profil au démarrage
  }

  // ✅ Lecture seule : l'ouverture de l'accueil ne modifie plus l'état du brassard
  Future<void> _fetchHardwareStatus() async {
    final data = await Api.current.getHardware();
    if (data['status'] == 'success' && mounted) {
      setState(() {
        isConnected = data['connected'] == true;
        batteryLevel = data['battery'] is int ? data['battery'] : null;
      });
    }
  }

  // ✅ Charge le profil IA depuis la BDD (ou la démo)
  Future<void> _loadProfilIA() async {
    final data = await Api.current.getProfil();
    if (data['status'] == 'success' && mounted) {
      setState(() {
        _profilExistant = Map<String, dynamic>.from(data['profil']);
        _historiqueProfils = List<Map<String, dynamic>>.from(data['historique'] ?? []);
        aiMessage = "Profil chargé ! Appuie pour voir tes conseils personnalisés.";
      });
    }
  }

  final List<Map<String, dynamic>> categories = [
    {'name': 'Endurance & Cardio', 'icon': Icons.directions_run, 'color': Colors.blue, 'desc': '(Running, Trail, Cyclisme, VTT, Ski)', 'subCategories': ['Running', 'Trail', 'Cyclisme', 'VTT', 'Ski', 'Aviron'], 'engine': 'GPS_CARDIO',},
    {'name': 'Force & Intensité', 'icon': Icons.fitness_center, 'color': Colors.red, 'desc': '(Muscu, Crossfit, HIIT, Fitness)', 'subCategories': ['Musculation', 'Crossfit', 'Haltérophilie', 'HIIT', 'Fitness'], 'engine': 'GYRO_POWER',},
    {'name': 'Duel & Collectif', 'icon': Icons.sports_tennis, 'color': Colors.green, 'desc': '(Foot, Tennis, Basket, Boxe)', 'subCategories': ['Football', 'Tennis', 'Basketball', 'Handball', 'Boxe'], 'engine': 'ACCEL_SPRINT',},
    {'name': 'Milieu Aquatique', 'icon': Icons.pool, 'color': Colors.cyan, 'desc': '(Natation, Water-polo, Paddle, Surf)', 'subCategories': ['Natation', 'Aquabike', 'Water-polo', 'Paddle', 'Surf'], 'engine': 'OFFLINE',},
    {'name': 'Zen & Posture', 'icon': Icons.self_improvement, 'color': Colors.purple, 'desc': '(Yoga, Pilates, Tir à l\'arc, Golf)', 'subCategories': ['Yoga', 'Pilates', 'Tir à l\'arc', 'Golf', 'Apnée'], 'engine': 'STABILITY',},
    {'name': 'Performances', 'icon': Icons.analytics, 'color': Colors.orange, 'desc': '(Classement des athlètes)', 'subCategories': [], 'engine': 'NONE',},
  ];

  // ✅ Bloc IA : ouvre IaResultScreen si un profil existe, sinon le questionnaire
  void _onIaTap() {
    if (_profilExistant != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IaResultScreen(
            profil: _profilExistant!,
            historique: _historiqueProfils,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
      );
    }
  }

  // ✅ Déconnexion et changement de compte → écran de connexion
  //    (quitter la démo ramène à l'accueil, d'où l'on peut relancer la démo)
  Future<void> _goToLogin() async {
    final wasDemo = Api.isDemo;
    Navigator.pop(context); // ferme le menu
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => wasDemo ? const LandingScreen() : const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      Text(Api.isDemo ? "Compte de démonstration" : "Compte actif",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.switch_account, color: Colors.blue, size: 22),
                ),
                title: const Text("Changer de compte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: _goToLogin,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 22),
                ),
                title: Text(Api.isDemo ? "Quitter la démo" : "Se déconnecter",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: _goToLogin,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ATHLETIX-DATA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (Api.isDemo)
            Container(
              width: double.infinity,
              color: Colors.amber[700],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                "MODE DÉMO — données fictives, aucun serveur",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _showProfileMenu,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text("Compte", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Icon(batteryLevel == null ? Icons.battery_unknown : Icons.battery_full,
                        color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text(batteryLevel == null ? "—" : "$batteryLevel%",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isConnected ? Colors.green : Colors.red, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    isConnected ? "BRASSARD SYNCHRONISÉ" : "BRASSARD NON RELIÉ",
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: _onIaTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profilExistant != null ? "CONSEILS PERSONNALISÉS" : "CONSEIL DE TON IA",
                            style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(aiMessage, style: TextStyle(color: Colors.blue[100], fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 14),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.9,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return InkWell(
                  onTap: () {
                    if (cat['name'] == 'Performances') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ClassementScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => SelectionScreen(
                          categoryName: cat['name'],
                          categoryColor: cat['color'],
                          subCategories: List<String>.from(cat['subCategories'] ?? []),
                          categoryEngine: cat['engine'] ?? 'GPS_CARDIO',
                        ),
                      ));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: (cat['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cat['color'], width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'], size: 45, color: cat['color']),
                        const SizedBox(height: 10),
                        Text(cat['name'], textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(cat['desc'], textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
