import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';

class ClassementScreen extends StatefulWidget {
  const ClassementScreen({super.key});

  @override
  State<ClassementScreen> createState() => _ClassementScreenState();
}

class _ClassementScreenState extends State<ClassementScreen> {
  // Liste qui stockera les données provenant de la base de données
  List<dynamic> athletes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClassement();
  }

  // ✅ Même URL d'API que le reste de l'appli (lib/config.dart)
  Future<void> _fetchClassement() async {
    final data = await Api.current.getClassement();
    if (!mounted) return;
    setState(() {
      athletes = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "CLASSEMENT MONDIAL",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : athletes.isEmpty 
          ? const Center(
              child: Text(
                "Aucun athlète trouvé", 
                style: TextStyle(color: Colors.white),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchClassement, // Permet de rafraîchir en glissant vers le bas
              color: Colors.orange,
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: athletes.length,
                itemBuilder: (context, index) {
                  final user = athletes[index];
                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRankColor(index),
                        child: Text(
                          "${index + 1}", 
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        user['pseudo'] ?? 'Anonyme', 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        user['sport'] ?? 'Sportif', 
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        "${user['score'] ?? 0} pts", 
                        style: const TextStyle(
                          color: Colors.orange, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  // Fonction pour attribuer une couleur selon le rang (Or, Argent, Bronze)
  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.yellow[700]!; // Or
      case 1:
        return Colors.grey[400]!;   // Argent
      case 2:
        return Colors.orange[800]!; // Bronze
      default:
        return Colors.blueGrey;     // Autres
    }
  }
}