import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Séances terminées sans réseau : gardées sur le téléphone et envoyées plus tard.
///
/// Chaque séance porte un `client_uuid` : si la réponse du serveur s'est perdue alors que la
/// séance était bien enregistrée, le renvoi ne crée pas de doublon (save_seance.php).
/// L'heure de fin est envoyée comme une DURÉE écoulée (`fin_il_y_a_s`), calculée sur le
/// téléphone : la date reste juste même si l'horloge du téléphone n'est pas à l'heure.
class FileEnvoi {
  FileEnvoi._();

  static const _cle = 'seances_en_attente';

  /// Identifiant aléatoire (UUID version 4).
  static String nouvelUuid() {
    final r = Random.secure();
    final o = List<int>.generate(16, (_) => r.nextInt(256));
    o[6] = (o[6] & 0x0f) | 0x40;
    o[8] = (o[8] & 0x3f) | 0x80;
    final h = o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Future<List<Map<String, dynamic>>> _lire() async {
    try {
      final brut = (await SharedPreferences.getInstance()).getString(_cle);
      if (brut == null) return [];
      return (jsonDecode(brut) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _ecrire(List<Map<String, dynamic>> liste) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cle, jsonEncode(liste));
    } catch (_) {}
  }

  /// Nombre de séances qui attendent le réseau.
  static Future<int> nombre() async => (await _lire()).length;

  /// Garde une séance pour plus tard. [finMs] : heure de fin (horloge du téléphone).
  static Future<void> garder(Map<String, String> seance, {int? finMs}) async {
    final liste = await _lire();
    liste.add({'seance': seance, 'fin_ms': finMs ?? DateTime.now().millisecondsSinceEpoch});
    await _ecrire(liste);
  }

  /// Essaie d'envoyer les séances en attente. Renvoie le nombre de séances envoyées.
  /// Une séance refusée par le serveur (donnée invalide) est retirée : la renvoyer ne servirait à rien.
  static Future<int> envoyer({DateTime Function()? maintenant}) async {
    final liste = await _lire();
    if (liste.isEmpty) return 0;
    final restantes = <Map<String, dynamic>>[];
    var envoyees = 0;
    for (final e in liste) {
      final seance = Map<String, String>.from(e['seance'] as Map);
      final ecoule = ((maintenant ?? DateTime.now)().millisecondsSinceEpoch - (e['fin_ms'] as int)) ~/ 1000;
      seance['fin_il_y_a_s'] = '${ecoule.clamp(0, 2592000)}';
      final r = await Api.current.saveSeance(seance);
      if (r['status'] == 'success') {
        envoyees++;
      } else if (r['reseau'] == true) {
        restantes.add(e); // toujours pas de réseau : on garde
      }
    }
    await _ecrire(restantes);
    return envoyees;
  }
}
