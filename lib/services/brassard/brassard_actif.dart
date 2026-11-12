import 'package:flutter/foundation.dart';

import 'source_brassard.dart';

/// Le brassard choisi dans l'écran « Brassard » (réel ou simulé), partagé par toute l'application.
///
/// La connexion reste ouverte d'une séance à l'autre : l'écran de séance ne ferme
/// que le brassard simulé qu'il a créé lui-même, jamais celui-ci.
class BrassardActif {
  BrassardActif._();

  static final ValueNotifier<SourceBrassard?> courant = ValueNotifier<SourceBrassard?>(null);

  static SourceBrassard? get source => courant.value;

  static void choisir(SourceBrassard source) {
    final ancien = courant.value;
    if (ancien != null && !identical(ancien, source)) ancien.fermer();
    courant.value = source;
  }

  static void liberer() {
    courant.value?.fermer();
    courant.value = null;
  }
}
