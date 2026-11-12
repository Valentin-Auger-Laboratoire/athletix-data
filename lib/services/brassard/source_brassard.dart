import 'mesure_emg.dart';

/// Ce que l'application attend d'un brassard, qu'il soit simulé ou réel.
///
/// Les écrans ne connaissent que cette interface. Pour brancher le vrai brassard
/// Bluetooth, il suffit d'écrire une classe `BrassardBle implements SourceBrassard`
/// (voir architecture/INTEGRATION.md §3), sans modifier les écrans.
abstract class SourceBrassard {
  /// Nom affiché (par ex. « Athletix-3C4D » ou « Brassard simulé »).
  String get nom;

  /// Vrai si les données ne viennent pas d'un vrai muscle.
  bool get simule;

  /// Numéro de série lu en Bluetooth (GATT 0x2A25), ou null s'il n'y en a pas.
  String? get numeroSerie;

  /// Version du firmware (GATT 0x2A26), ou null.
  String? get firmware;

  /// Référence 100 % MVC actuelle, en mV (caractéristique Configuration).
  int get refMvcMv;

  /// Flux des mesures reçues (environ 50 par seconde pendant une séance).
  Stream<MesureEmg> get mesures;

  /// Commande 0x01 : démarre l'envoi des mesures.
  Future<void> demarrer();

  /// Commande 0x02 : arrête l'envoi des mesures.
  Future<void> arreter();

  /// Libère les ressources (connexion, minuteurs).
  void fermer();
}
