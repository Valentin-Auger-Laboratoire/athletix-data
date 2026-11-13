/// Protocole propre des bracelets « YOHO » (famille MSGM115 / GM115, puce Maxscend), service 0xCC00.
///
/// Retrouvé le 13 novembre 2026 en analysant l'application d'origine du bracelet de Valentin
/// (Yoho Sports, paquet com.uthink.ring), dans le seul but de rendre son propre bracelet compatible
/// avec Athletix-Data (directive 2009/24/CE, article 6). Aucun code de cette application n'est repris :
/// ce fichier décrit seulement le FORMAT des messages, réécrit ici.
///
/// Caractéristiques du service CC00 :
///   CC02 lecture   : informations de l'appareil (version du firmware, fonctions disponibles) ;
///   CC03 lecture + notification : batterie (octet 0 = %, octet 7 = état de charge) ;
///   CC04 notification : messages en temps réel et historique (pas, cœur, tension, inactivité…) ;
///   CC05 notification : ancien format de synchronisation (firmwares ≤ 0x49, pas utilisé ici) ;
///   CC06 écriture   : commandes envoyées au bracelet.
///
/// Ce n'est PAS un dispositif médical : le bracelet ESTIME la tension à partir de son capteur optique,
/// ce n'est pas une mesure au brassard.
library;

class ProtocoleYoho {
  ProtocoleYoho._();

  static const String uuidService = '0000cc00-0000-1000-8000-00805f9b34fb';
  static const String uuidInfos = '0000cc02-0000-1000-8000-00805f9b34fb';
  static const String uuidBatterie = '0000cc03-0000-1000-8000-00805f9b34fb';
  static const String uuidTempsReel = '0000cc04-0000-1000-8000-00805f9b34fb';
  static const String uuidSynchroAncienne = '0000cc05-0000-1000-8000-00805f9b34fb';
  static const String uuidCommande = '0000cc06-0000-1000-8000-00805f9b34fb';

  // ---------------- Commandes (à écrire dans CC06) ----------------

  /// Démarre (ou arrête) la mesure du cœur. Le résultat arrive sur CC04 (voir [lire]).
  static List<int> mesureCoeur(bool marche) => [0x0A, marche ? 1 : 0];

  /// Démarre (ou arrête) l'estimation de la tension. Résultat sur CC04 : F3 14 systolique diastolique.
  static List<int> mesureTension(bool marche) => [0xF1, 0x03, 0x14, marche ? 1 : 0];

  /// Fait vibrer le bracelet (« Trouver band »).
  static const List<int> trouverBracelet = [0x08, 0x01];

  /// Met le bracelet à l'heure : 04 00 année-2000 mois jour heure minute seconde.
  static List<int> heure(DateTime t) =>
      [0x04, 0x00, t.year % 2000, t.month, t.day, t.hour, t.minute, t.second];

  /// Rappel d'inactivité : 07 marche durée(min, 2 octets little-endian). L'appli d'origine propose 60 min.
  static List<int> rappelInactivite(bool marche, {int minutes = 60}) {
    if (minutes < 1 || minutes > 0xFFFF) throw ArgumentError('Durée du rappel hors limites : $minutes min');
    return [0x07, marche ? 1 : 0, minutes & 0xFF, (minutes >> 8) & 0xFF];
  }

  /// Profil, utilisé par le bracelet pour la distance et les calories :
  /// F1 01 sexe âge taille(cm) poids(kg) poignet unité objectif(2 octets little-endian).
  /// Sexe : valeur par défaut de l'appli d'origine = 0 (son profil par défaut est « Mâle ») ;
  /// unité : 0 = km, 1 = miles ; poignet : 0 par défaut.
  static List<int> profil({
    required bool homme,
    required int age,
    required int tailleCm,
    required int poidsKg,
    int objectifPas = 8000,
    bool miles = false,
    int poignet = 0,
  }) {
    void borne(String nom, int v, int min, int max) {
      if (v < min || v > max) throw ArgumentError('$nom hors limites : $v');
    }

    borne('Âge', age, 1, 120);
    borne('Taille', tailleCm, 50, 250);
    borne('Poids', poidsKg, 10, 250);
    borne('Objectif', objectifPas, 0, 0xFFFF);
    return [
      0xF1, 0x01, homme ? 0 : 1, age, tailleCm, poidsKg, poignet, miles ? 1 : 0,
      objectifPas & 0xFF, (objectifPas >> 8) & 0xFF,
    ];
  }

  // Synchronisation de l'historique (activité minute par minute, dont le sommeil)
  static const List<int> synchroDebut = [0xF4, 0x00];
  static const List<int> synchroBaseRecue = [0xF4, 0x01];
  static List<int> synchroPaquetRecu(int numero) => [0xF4, 0x02, numero & 0xFF, (numero >> 8) & 0xFF];
  static const List<int> synchroEtatRecu = [0xF4, 0x03];

  // Synchronisation de l'historique du cœur et de la tension
  static const List<int> synchroMesuresDebut = [0xF4, 0x04];
  static const List<int> synchroMesuresBaseRecue = [0xF4, 0x05];
  static List<int> synchroMesuresPaquetRecu(int numero) => [0xF4, 0x06, numero & 0xFF, (numero >> 8) & 0xFF];
  static const List<int> synchroMesuresFinRecue = [0xF4, 0x07];

  // ---------------- Lecture de CC02 (informations) ----------------

  /// Version du firmware affichée par l'appli d'origine : octets 12.13.14.11 en hexadécimal
  /// (82.78.00.3d pour le bracelet de Valentin).
  static String? versionFirmware(List<int> o) {
    if (o.length < 15) return null;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(o[12])}.${h(o[13])}.${h(o[14])}.${h(o[11])}';
  }

  /// Fonctions annoncées par le bracelet (octets 15 et 17 de CC02).
  static FonctionsYoho fonctions(List<int> o) {
    bool bit(int i, int b) => o.length > i && (o[i] >> b) & 1 == 1;
    return FonctionsYoho(
      coeur: bit(17, 4),
      tension: bit(17, 5),
      historiqueMesures: bit(15, 2),
      // Octet 13 > 0x49 : nouveau format de synchronisation (sur CC04), celui géré ici
      nouvelleSynchro: o.length > 13 && o[13] > 0x49,
    );
  }

  // ---------------- Lecture de CC03 (batterie) ----------------

  static int? batterie(List<int> o) => o.isEmpty ? null : o[0];

  // ---------------- Lecture de CC04 (temps réel + historique) ----------------

  static int _u16(List<int> o, int i) => o[i] | (o[i + 1] << 8);
  static int _u32(List<int> o, int i) => o[i] | (o[i + 1] << 8) | (o[i + 2] << 16) | (o[i + 3] << 24);

  static DateTime? _date(List<int> o, int i) {
    if (o.length < i + 6) return null;
    if (o.sublist(i, i + 6).every((v) => v == 0)) return null; // « pas de données »
    return DateTime(2000 + o[i], o[i + 1], o[i + 2], o[i + 3], o[i + 4], o[i + 5]);
  }

  /// Décode un message reçu sur CC04. Renvoie null pour un message inconnu ou trop court.
  static MessageYoho? lire(List<int> o) {
    if (o.length < 2) return null;
    switch (o[0]) {
      case 0xF3:
        if (o[1] == 0x14 && o.length >= 4) return TensionYoho(o[2], o[3]);
        if (o[1] == 0x18) return const TelephoneCherche();
        if (o[1] == 0x1B && o.length >= 3) return TemperatureYoho(o[2] / 10 + 30);
        return null;
      case 0xF5:
        return MusiqueYoho(o[1]);
      case 0xF1:
        return null; // accusés de réception (météo, informations d'écran) : rien à faire ici
      case 0xF4:
        return _lireSynchro(o);
    }
    if (o.length < 2) return null;
    final drapeaux = _u16(o, 0);
    if (drapeaux == 0x80) return null; // journal de sommeil de mise au point de l'appli d'origine
    if (drapeaux & (1 << 6) != 0) return null; // données brutes de l'accéléromètre (mise au point)
    if (drapeaux & (1 << 3) != 0) return const SelfieYoho();
    if (drapeaux & (1 << 2) != 0) return const InactiviteYoho();
    if (drapeaux & (1 << 5) != 0) return o.length > 10 ? CoeurYoho(o[10]) : null;
    if (o.length < 7) return null;
    return PasYoho(etat: o[2], pas: _u32(o, 3));
  }

  static MessageYoho? _lireSynchro(List<int> o) {
    switch (o[1]) {
      case 0x01:
        return o.length >= 8 ? SynchroBase(_date(o, 2)) : null;
      case 0x02:
        if (o.length < 5) return null;
        final numero = _u16(o, 2), n = o[4];
        final lignes = <LigneActivite>[];
        for (var k = 0; k < n; k++) {
          final i = 5 + 5 * k;
          if (o.length < i + 5) return null;
          lignes.add(LigneActivite(etat: o[i], minutes: _u16(o, i + 1), pas: _u16(o, i + 3)));
        }
        return SynchroPaquet(numero, lignes);
      case 0x03:
        if (o.length < 13) return null;
        return SynchroEtat(etat: o[2], minutes: _u16(o, 3), pas: _u16(o, 5), date: _date(o, 7));
      case 0x05:
        return o.length >= 8 ? SynchroMesuresBase(_date(o, 2)) : null;
      case 0x06:
        if (o.length < 5) return null;
        final numero = _u16(o, 2), n = o[4];
        final lignes = <LigneMesure>[];
        for (var k = 0; k < n; k++) {
          final i = 5 + 6 * k;
          if (o.length < i + 6) return null;
          lignes.add(LigneMesure(secondes: _u32(o, i), valeur1: o[i + 4], valeur2: o[i + 5]));
        }
        return SynchroMesuresPaquet(numero, lignes);
      case 0x07:
        return const SynchroMesuresFin();
    }
    return null;
  }
}

class FonctionsYoho {
  const FonctionsYoho({
    required this.coeur,
    required this.tension,
    required this.historiqueMesures,
    required this.nouvelleSynchro,
  });
  final bool coeur, tension, historiqueMesures, nouvelleSynchro;
}

/// Message reçu du bracelet sur CC04.
sealed class MessageYoho {
  const MessageYoho();
}

class CoeurYoho extends MessageYoho {
  const CoeurYoho(this.bpm);
  final int bpm; // 0 tant que la mesure n'est pas terminée
}

class TensionYoho extends MessageYoho {
  const TensionYoho(this.systolique, this.diastolique);
  final int systolique, diastolique; // estimation du bracelet, en mmHg
}

class TemperatureYoho extends MessageYoho {
  const TemperatureYoho(this.degres);
  final double degres;
}

class PasYoho extends MessageYoho {
  const PasYoho({required this.etat, required this.pas});
  final int etat; // voir EtatActivite
  final int pas; // compteur depuis minuit
}

class InactiviteYoho extends MessageYoho {
  const InactiviteYoho();
}

class SelfieYoho extends MessageYoho {
  const SelfieYoho();
}

class TelephoneCherche extends MessageYoho {
  const TelephoneCherche();
}

class MusiqueYoho extends MessageYoho {
  const MusiqueYoho(this.commande);
  final int commande;
}

class SynchroBase extends MessageYoho {
  const SynchroBase(this.date);
  final DateTime? date; // null : le bracelet n'a rien à envoyer
}

class SynchroPaquet extends MessageYoho {
  const SynchroPaquet(this.numero, this.lignes);
  final int numero;
  final List<LigneActivite> lignes;
}

class SynchroEtat extends MessageYoho {
  const SynchroEtat({required this.etat, required this.minutes, required this.pas, required this.date});
  final int etat, minutes, pas;
  final DateTime? date;
}

class SynchroMesuresBase extends MessageYoho {
  const SynchroMesuresBase(this.date);
  final DateTime? date;
}

class SynchroMesuresPaquet extends MessageYoho {
  const SynchroMesuresPaquet(this.numero, this.lignes);
  final int numero;
  final List<LigneMesure> lignes;
}

class SynchroMesuresFin extends MessageYoho {
  const SynchroMesuresFin();
}

/// Une ligne de l'historique d'activité : à partir de « base + minutes », le bracelet est dans [etat].
class LigneActivite {
  const LigneActivite({required this.etat, required this.minutes, required this.pas});
  final int etat, minutes, pas;
}

/// Une ligne de l'historique des mesures : « base + secondes ».
/// valeur2 = 0 : cœur (valeur1 = bpm) ; 1 : oxygène ; 3 : température (valeur1/10 + 30) ;
/// sinon : tension (valeur1 = systolique, valeur2 = diastolique).
class LigneMesure {
  const LigneMesure({required this.secondes, required this.valeur1, required this.valeur2});
  final int secondes, valeur1, valeur2;
}

/// États d'activité du bracelet (constantes de l'appli d'origine).
class EtatActivite {
  EtatActivite._();
  static const int immobile = 0;
  static const int marche = 1;
  static const int course = 2;
  static const int sommeilProfond = 3;
  static const int reveil = 4;
  static const int sommeilLeger = 5;
}

/// Un état daté, reconstitué depuis la synchronisation (base + minutes).
class PeriodeActivite {
  const PeriodeActivite(this.debut, this.etat, this.pas);
  final DateTime debut;
  final int etat;
  final int pas;
}

/// Résumé d'une nuit, calcul proche de celui de l'écran Sommeil de l'appli d'origine (simplifié) :
/// fenêtre de 21 h la veille à 9 h ; chaque état dure jusqu'au suivant ;
/// profond = état 3, léger = état 5, un réveil = un passage par l'état 4 ou 0 après le début du sommeil.
class NuitYoho {
  const NuitYoho({required this.profond, required this.leger, required this.reveils});
  final Duration profond;
  final Duration leger;
  final int reveils;
  Duration get total => profond + leger;

  static NuitYoho? calculer(List<PeriodeActivite> periodes, DateTime matin) {
    final debut = DateTime(matin.year, matin.month, matin.day).subtract(const Duration(hours: 3));
    final fin = DateTime(matin.year, matin.month, matin.day, 9);
    final p = periodes.where((e) => !e.debut.isBefore(debut) && e.debut.isBefore(fin)).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    var profond = Duration.zero, leger = Duration.zero;
    var reveils = 0;
    var endormi = false, eveille = false;
    for (var i = 0; i < p.length; i++) {
      if (i + 1 >= p.length) break; // le dernier état n'a pas de durée connue
      final d = p[i + 1].debut.difference(p[i].debut);
      switch (p[i].etat) {
        case EtatActivite.sommeilProfond:
          profond += d;
          if (eveille) reveils++;
          endormi = true;
          eveille = false;
        case EtatActivite.sommeilLeger:
          leger += d;
          if (eveille) reveils++;
          endormi = true;
          eveille = false;
        case EtatActivite.reveil:
        case EtatActivite.immobile:
          if (endormi) eveille = true;
      }
    }
    if (profond + leger == Duration.zero) return null;
    return NuitYoho(profond: profond, leger: leger, reveils: reveils);
  }
}
