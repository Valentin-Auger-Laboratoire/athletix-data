import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages d'accessibilité et mode adapté, retenus sur l'appareil.
///
/// Issus de la rencontre avec la patiente atteinte de sclérose en plaques (voir le README) :
/// gestes fins et vue parfois difficiles, fatigue rapide, sensibilité à la chaleur.
class Reglages {
  Reglages._();

  /// Texte et boutons agrandis.
  static final ValueNotifier<bool> grandsCaracteres = ValueNotifier(false);

  /// Vibration du téléphone à chaque alerte.
  static final ValueNotifier<bool> alertesVibration = ValueNotifier(true);

  /// Alerte annoncée à voix haute.
  static final ValueNotifier<bool> alertesVoix = ValueNotifier(false);

  /// Mode adapté : seuils d'alerte plus bas, pause conseillée régulièrement, alerte chaleur.
  static final ValueNotifier<bool> modeAdapte = ValueNotifier(false);

  /// Seuils en mode adapté (au lieu de 75 / 70 %).
  static const int seuilHautAdapte = 60;
  static const int seuilBasAdapte = 55;

  /// Pause conseillée toutes les … minutes en mode adapté.
  static const int pauseToutesLesMinutes = 10;

  static final Map<String, ValueNotifier<bool>> _tous = {
    'reglage_grands_caracteres': grandsCaracteres,
    'reglage_vibration': alertesVibration,
    'reglage_voix': alertesVoix,
    'reglage_mode_adapte': modeAdapte,
  };

  /// Objectif de séances par semaine (accueil).
  static final ValueNotifier<int> objectifSeances = ValueNotifier(3);

  static Future<void> changerObjectif(int n) async {
    objectifSeances.value = n.clamp(1, 14);
    try {
      await (await SharedPreferences.getInstance()).setInt('reglage_objectif_seances', objectifSeances.value);
    } catch (_) {}
  }

  static Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      final objectif = p.getInt('reglage_objectif_seances');
      if (objectif != null) objectifSeances.value = objectif;
      _tous.forEach((cle, notif) {
        final v = p.getBool(cle);
        if (v != null) notif.value = v;
      });
    } catch (_) {/* valeurs par défaut */}
  }

  static Future<void> changer(ValueNotifier<bool> reglage, bool valeur) async {
    reglage.value = valeur;
    final cle = _tous.entries.firstWhere((e) => identical(e.value, reglage)).key;
    try {
      await (await SharedPreferences.getInstance()).setBool(cle, valeur);
    } catch (_) {}
  }
}

/// Alertes vibration et voix pendant une séance.
class Alerteur {
  Alerteur();

  FlutterTts? _tts;

  Future<void> signaler(String message) async {
    if (Reglages.alertesVibration.value) {
      try {
        await HapticFeedback.heavyImpact();
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
    if (Reglages.alertesVoix.value) {
      try {
        final tts = _tts ??= FlutterTts();
        await tts.setLanguage('fr-FR');
        await tts.speak(message);
      } catch (_) {}
    }
  }

  void fermer() {
    try {
      _tts?.stop();
    } catch (_) {}
  }
}
