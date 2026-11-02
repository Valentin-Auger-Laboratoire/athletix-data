import 'package:flutter/material.dart';
import 'package:athletix_data/screens/landing_screen.dart';

void main() => runApp(const AthletixDataApp());

class AthletixDataApp extends StatelessWidget {
  const AthletixDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athletix-Data',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
      ),
      home: const LandingScreen(), 
    );
  }
}