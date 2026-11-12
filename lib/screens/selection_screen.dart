import 'package:flutter/material.dart';
import 'workout_detail_screen.dart';

class SelectionScreen extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final List<String> subCategories;
  final String categoryMesure;

  const SelectionScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.subCategories,
    required this.categoryMesure,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: categoryColor,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        itemBuilder: (context, index) {
          final sport = subCategories[index];
          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              // ✅ withOpacity → withValues
              side: BorderSide(color: categoryColor.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(
                sport,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: categoryColor, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutDetailScreen(
                      categoryName: sport,
                      categoryColor: categoryColor,
                      mesure: categoryMesure,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}