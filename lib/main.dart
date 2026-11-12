import 'package:flutter/material.dart';
import 'package:athletix_data/screens/landing_screen.dart';
import 'package:athletix_data/services/reglages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Reglages.charger();
  runApp(const AthletixDataApp());
}

class AthletixDataApp extends StatelessWidget {
  const AthletixDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Reglages.grandsCaracteres,
      builder: (context, grands, _) => MaterialApp(
        title: 'Athletix-Data',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.orange,
          // Grands caractères : boutons et zones de toucher plus grands aussi
          visualDensity: grands ? VisualDensity.comfortable : null,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
        // Grands caractères : texte agrandi de 30 % (en plus du réglage du téléphone)
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: grands ? mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 1.3)) : mq,
            child: child!,
          );
        },
        home: const LandingScreen(),
      ),
    );
  }
}
