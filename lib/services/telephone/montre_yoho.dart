import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'protocole_yoho.dart';

/// Déroulement de la synchronisation de l'historique, sans Bluetooth (testé dans test/montre_yoho_test.dart).
///
/// Échange (vu côté téléphone) :
///   → F4 00                      ← F4 01 date de base       → F4 01
///   ← F4 02 n° + lignes (×N)     → F4 02 n°                 ← F4 03 état actuel   → F4 03
/// puis, si le bracelet garde l'historique du cœur et de la tension :
///   → F4 04                      ← F4 05 date de base       → F4 05
///   ← F4 06 n° + mesures (×N)    → F4 06 n°                 ← F4 07               → F4 07
class SynchroYoho {
  SynchroYoho({required this.avecMesures});

  final bool avecMesures;
  DateTime? _baseActivite, _baseMesures;
  final List<PeriodeActivite> periodes = [];
  final List<MesureHistorique> mesures = [];
  bool terminee = false;

  /// Commandes à envoyer au début.
  List<int> get debut => ProtocoleYoho.synchroDebut;

  /// Traite un message reçu et renvoie la (ou les) commande(s) à envoyer en réponse.
  List<List<int>> recevoir(MessageYoho m) {
    switch (m) {
      case SynchroBase(:final date):
        _baseActivite = date;
        return [ProtocoleYoho.synchroBaseRecue];
      case SynchroPaquet(:final numero, :final lignes):
        final base = _baseActivite;
        if (base != null) {
          for (final l in lignes) {
            periodes.add(PeriodeActivite(base.add(Duration(minutes: l.minutes)), l.etat, l.pas));
          }
        }
        return [ProtocoleYoho.synchroPaquetRecu(numero)];
      case SynchroEtat():
        if (!avecMesures) {
          terminee = true;
          return [ProtocoleYoho.synchroEtatRecu];
        }
        return [ProtocoleYoho.synchroEtatRecu, ProtocoleYoho.synchroMesuresDebut];
      case SynchroMesuresBase(:final date):
        _baseMesures = date;
        return [ProtocoleYoho.synchroMesuresBaseRecue];
      case SynchroMesuresPaquet(:final numero, :final lignes):
        final base = _baseMesures;
        if (base != null) {
          for (final l in lignes) {
            mesures.add(MesureHistorique.depuis(base.add(Duration(seconds: l.secondes)), l));
          }
        }
        return [ProtocoleYoho.synchroMesuresPaquetRecu(numero)];
      case SynchroMesuresFin():
        terminee = true;
        return [ProtocoleYoho.synchroMesuresFinRecue];
      default:
        return const [];
    }
  }
}

/// Une mesure de l'historique du bracelet.
class MesureHistorique {
  const MesureHistorique({required this.date, this.bpm, this.systolique, this.diastolique, this.temperature});
  final DateTime date;
  final int? bpm, systolique, diastolique;
  final double? temperature;

  static MesureHistorique depuis(DateTime date, LigneMesure l) {
    switch (l.valeur2) {
      case 0:
        return MesureHistorique(date: date, bpm: l.valeur1);
      case 1:
        return MesureHistorique(date: date); // oxygène : pas mesuré par ce bracelet
      case 3:
        return MesureHistorique(date: date, temperature: l.valeur1 / 10 + 30);
      default:
        return MesureHistorique(date: date, systolique: l.valeur1, diastolique: l.valeur2);
    }
  }
}

/// Liaison avec le service CC00 d'un bracelet YOHO (MSGM115) : cœur, tension estimée, historique
/// (dont le sommeil), vibration, heure, profil, rappel d'inactivité.
///
/// Format retrouvé dans l'appli d'origine (voir protocole_yoho.dart) ; essayé seulement dans les tests
/// tant que Valentin ne l'a pas lancé sur son téléphone avec le bracelet.
class LiaisonYoho {
  LiaisonYoho._(this._commande, this._tempsReel, this._infos, this._batterie);

  final BluetoothCharacteristic _commande, _tempsReel;
  final BluetoothCharacteristic? _infos, _batterie;
  final StreamController<MessageYoho> _messages = StreamController<MessageYoho>.broadcast();
  final List<StreamSubscription> _abonnements = [];

  final ValueNotifier<int?> batterie = ValueNotifier<int?>(null);
  final ValueNotifier<int?> coeur = ValueNotifier<int?>(null);
  final ValueNotifier<TensionYoho?> tension = ValueNotifier<TensionYoho?>(null);
  final ValueNotifier<NuitYoho?> nuit = ValueNotifier<NuitYoho?>(null);
  final ValueNotifier<bool> occupe = ValueNotifier<bool>(false);
  final List<MesureHistorique> historique = [];
  String? firmware;
  FonctionsYoho fonctions = const FonctionsYoho(coeur: true, tension: true, historiqueMesures: true, nouvelleSynchro: true);

  Stream<MessageYoho> get messages => _messages.stream;

  /// Cherche le service CC00 parmi les services découverts ; null si le bracelet ne l'a pas.
  static Future<LiaisonYoho?> ouvrir(List<BluetoothService> services) async {
    BluetoothCharacteristic? commande, tempsReel, infos, batterie;
    for (final s in services) {
      if (s.uuid != Guid(ProtocoleYoho.uuidService)) continue;
      for (final c in s.characteristics) {
        if (c.uuid == Guid(ProtocoleYoho.uuidCommande)) commande = c;
        if (c.uuid == Guid(ProtocoleYoho.uuidTempsReel)) tempsReel = c;
        if (c.uuid == Guid(ProtocoleYoho.uuidInfos)) infos = c;
        if (c.uuid == Guid(ProtocoleYoho.uuidBatterie)) batterie = c;
      }
    }
    if (commande == null || tempsReel == null) return null;
    final l = LiaisonYoho._(commande, tempsReel, infos, batterie);
    await l._demarrer();
    return l;
  }

  /// Même ordre que l'appli d'origine : informations, batterie, notifications, puis l'heure.
  Future<void> _demarrer() async {
    try {
      final o = await _infos?.read();
      if (o != null) {
        firmware = ProtocoleYoho.versionFirmware(o);
        fonctions = ProtocoleYoho.fonctions(o);
      }
    } catch (_) {}
    final bat = _batterie;
    if (bat != null) {
      try {
        batterie.value = ProtocoleYoho.batterie(await bat.read());
        _abonnements.add(bat.onValueReceived.listen((o) => batterie.value = ProtocoleYoho.batterie(o)));
        await bat.setNotifyValue(true);
      } catch (_) {}
    }
    _abonnements.add(_tempsReel.onValueReceived.listen(_recevoir));
    await _tempsReel.setNotifyValue(true);
    await envoyer(ProtocoleYoho.heure(DateTime.now()));
  }

  void _recevoir(List<int> octets) {
    final m = ProtocoleYoho.lire(octets);
    if (m == null) return;
    if (m is CoeurYoho && m.bpm > 0) coeur.value = m.bpm;
    if (m is TensionYoho && m.systolique > 0) tension.value = m;
    if (!_messages.isClosed) _messages.add(m);
  }

  Future<void> envoyer(List<int> commande) => _commande.write(commande, withoutResponse: false);

  /// Lance une mesure du cœur et attend un résultat non nul (le bracelet mesure en ~30 s).
  Future<int> mesurerCoeur({Duration attente = const Duration(seconds: 60)}) async {
    final resultat = messages.where((m) => m is CoeurYoho && m.bpm > 0).cast<CoeurYoho>().first.timeout(attente);
    await envoyer(ProtocoleYoho.mesureCoeur(true));
    try {
      return (await resultat).bpm;
    } finally {
      envoyer(ProtocoleYoho.mesureCoeur(false)).catchError((_) {});
    }
  }

  /// Lance l'estimation de la tension (ESTIMATION du bracelet, pas une mesure médicale).
  Future<TensionYoho> mesurerTension({Duration attente = const Duration(seconds: 90)}) async {
    final resultat =
        messages.where((m) => m is TensionYoho && m.systolique > 0).cast<TensionYoho>().first.timeout(attente);
    await envoyer(ProtocoleYoho.mesureTension(true));
    try {
      return await resultat;
    } finally {
      envoyer(ProtocoleYoho.mesureTension(false)).catchError((_) {});
    }
  }

  Future<void> faireVibrer() => envoyer(ProtocoleYoho.trouverBracelet);

  Future<void> reglerInactivite(bool marche, int minutes) =>
      envoyer(ProtocoleYoho.rappelInactivite(marche, minutes: minutes));

  Future<void> envoyerProfil({required bool homme, required int age, required int tailleCm, required int poidsKg, int objectifPas = 8000}) =>
      envoyer(ProtocoleYoho.profil(homme: homme, age: age, tailleCm: tailleCm, poidsKg: poidsKg, objectifPas: objectifPas));

  /// Récupère l'historique (activité minute par minute et mesures), puis calcule la dernière nuit.
  Future<SynchroYoho> synchroniser({Duration attente = const Duration(seconds: 90)}) async {
    occupe.value = true;
    final s = SynchroYoho(avecMesures: fonctions.historiqueMesures);
    final fini = Completer<void>();
    final abo = messages.listen((m) async {
      final reponses = s.recevoir(m);
      for (final r in reponses) {
        await Future.delayed(const Duration(milliseconds: 100)); // l'appli d'origine attend aussi 100 ms
        await envoyer(r);
      }
      if (s.terminee && !fini.isCompleted) fini.complete();
    });
    try {
      await envoyer(s.debut);
      await fini.future.timeout(attente);
    } finally {
      await abo.cancel();
      occupe.value = false;
    }
    historique
      ..clear()
      ..addAll(s.mesures);
    final derniereMesureCoeur = s.mesures.where((m) => m.bpm != null && m.bpm! > 0).toList();
    if (derniereMesureCoeur.isNotEmpty && coeur.value == null) coeur.value = derniereMesureCoeur.last.bpm;
    nuit.value = NuitYoho.calculer(s.periodes, DateTime.now());
    return s;
  }

  void fermer() {
    for (final a in _abonnements) {
      a.cancel();
    }
    if (!_messages.isClosed) _messages.close();
  }
}
