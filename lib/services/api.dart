import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:athletix_data/config.dart';
import 'demo_api.dart';

/// Utilisateur connecté (en mémoire uniquement).
class Session {
  final int userId;
  final String pseudo;
  final String token;
  final bool demo;

  const Session({
    required this.userId,
    required this.pseudo,
    required this.token,
    this.demo = false,
  });
}

/// Toutes les réponses sont des Map JSON avec au moins une clé `status`.
abstract class AthletixApi {
  Future<Map<String, dynamic>> register(String pseudo, String email, String password, String sport);
  Future<Map<String, dynamic>> verifyCode(String email, String code);
  Future<Map<String, dynamic>> resendCode(String email);
  Future<Map<String, dynamic>> login(String email, String password);
  Future<void> logout();
  Future<Map<String, dynamic>> getProfil();
  Future<Map<String, dynamic>> saveProfil(Map<String, String> profil);
  Future<Map<String, dynamic>> getHardware();
  Future<List<dynamic>> getClassement();
}

/// Point d'accès unique : backend PHP réel ou données de démo en mémoire.
class Api {
  static AthletixApi current = HttpApi();
  static Session? session;

  static bool get isDemo => session?.demo ?? false;

  static void startDemo() {
    current = DemoApi();
    session = const Session(userId: 1, pseudo: 'Athlète démo', token: 'demo', demo: true);
  }

  /// Ouvre une session à partir d'une réponse `login.php` ou `verify_code.php`.
  static void openSession(Map<String, dynamic> data) {
    session = Session(
      userId: data['id'] is int ? data['id'] : int.tryParse(data['id'].toString()) ?? 0,
      pseudo: data['pseudo']?.toString() ?? 'Athlète',
      token: data['token']?.toString() ?? '',
    );
  }

  static Future<void> logout() async {
    await current.logout();
    session = null;
    current = HttpApi();
  }
}

class HttpApi implements AthletixApi {
  static const Map<String, String> _headers = {
    "ngrok-skip-browser-warning": "true",
    "Content-Type": "application/x-www-form-urlencoded",
  };

  Future<Map<String, dynamic>> _post(String script, Map<String, String> body, {bool auth = false}) async {
    if (auth) body = {...body, "token": Api.session?.token ?? ''};
    try {
      final response = await http.post(Uri.parse("$apiBaseUrl/$script"), headers: _headers, body: body);
      final text = response.body.trim();
      if (!text.startsWith('{')) {
        debugPrint("Réponse non-JSON de $script : $text");
        return {"status": "error", "message": "Réponse inattendue du serveur (${response.statusCode})"};
      }
      return json.decode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Erreur $script : $e");
      return {"status": "error", "message": "Impossible de joindre le serveur"};
    }
  }

  @override
  Future<Map<String, dynamic>> register(String pseudo, String email, String password, String sport) =>
      _post("register.php", {"pseudo": pseudo, "email": email, "password": password, "sport": sport});

  @override
  Future<Map<String, dynamic>> verifyCode(String email, String code) =>
      _post("verify_code.php", {"email": email, "code": code});

  @override
  Future<Map<String, dynamic>> resendCode(String email) => _post("resend_code.php", {"email": email});

  @override
  Future<Map<String, dynamic>> login(String email, String password) =>
      _post("login.php", {"email": email, "password": password});

  @override
  Future<void> logout() async {
    if (Api.session != null) await _post("logout.php", {}, auth: true);
  }

  @override
  Future<Map<String, dynamic>> getProfil() => _post("get_profil_ia.php", {}, auth: true);

  @override
  Future<Map<String, dynamic>> saveProfil(Map<String, String> profil) =>
      _post("ia_profile_save.php", profil, auth: true);

  @override
  Future<Map<String, dynamic>> getHardware() => _post("get_hardware.php", {}, auth: true);

  @override
  Future<List<dynamic>> getClassement() async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/get_classement.php"),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (response.statusCode == 200) return json.decode(response.body) as List<dynamic>;
      debugPrint("Erreur Serveur: ${response.statusCode}");
    } catch (e) {
      debugPrint("Erreur connexion classement: $e");
    }
    return [];
  }
}
