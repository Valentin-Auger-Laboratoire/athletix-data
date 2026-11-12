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

  /// Niveau de batterie en % (caractéristique standard 0x2A19), ou null si inconnu.
  int? get batteriePct;

  /// Seuils de l'alerte d'effort intense (en %) : s'allume au seuil haut, s'éteint sous le bas.
  int get seuilHaut;
  int get seuilBas;

  /// Commande 0x04 : change les seuils (mode adapté par exemple).
  Future<void> reglerSeuils(int seuilHaut, int seuilBas);

  /// Flux des mesures reçues (environ 50 par seconde pendant une séance).
  Stream<MesureEmg> get mesures;

  /// Commande 0x01 : démarre l'envoi des mesures.
  Future<void> demarrer();

  /// Commande 0x02 : arrête l'envoi des mesures.
  Future<void> arreter();

  /// Commande 0x03 : calibration de 3 s pendant laquelle l'utilisateur serre le muscle
  /// au maximum. Renvoie la nouvelle référence 100 % MVC, en mV.
  /// Lève une [ErreurBrassard] si le brassard refuse (signal trop faible…).
  Future<int> calibrer();

  /// Libère les ressources (connexion, minuteurs).
  void fermer();
}

/// Erreur signalée par le brassard (caractéristique État, GATT.md §7) ou par la liaison.
class ErreurBrassard implements Exception {
  ErreurBrassard(this.message);
  final String message;

  @override
  String toString() => message;
}
