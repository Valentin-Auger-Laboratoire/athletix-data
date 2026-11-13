import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'package:athletix_data/services/brassard/brassard_ble.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/telephone/cardio.dart';
import 'package:athletix_data/services/telephone/montre_podometre.dart';
import 'package:athletix_data/services/telephone/montre_yoho.dart';
import 'package:athletix_data/services/telephone/protocole_yoho.dart';
import 'package:athletix_data/services/api.dart';
import 'calibration_screen.dart';

/// Choix du brassard : recherche Bluetooth du vrai brassard, ou brassard simulé (démo).
/// Opération O3 du MCT : scan, connexion, lecture du numéro de série et de la batterie.
class BrassardScreen extends StatefulWidget {
  const BrassardScreen({super.key});

  @override
  State<BrassardScreen> createState() => _BrassardScreenState();
}

class _BrassardScreenState extends State<BrassardScreen> {
  bool? _bluetoothDisponible;
  bool _recherche = false;
  bool _connexion = false;
  String? _erreur;
  List<ScanResult> _resultats = [];
  StreamSubscription<List<ScanResult>>? _abonnement;

  @override
  void initState() {
    super.initState();
    BrassardBle.demanderCode = _demanderCode;
    BrassardBle.disponible().then((ok) {
      if (mounted) setState(() => _bluetoothDisponible = ok);
    });
  }

  @override
  void dispose() {
    if (BrassardBle.demanderCode == _demanderCode) BrassardBle.demanderCode = null;
    _abonnement?.cancel();
    if (_recherche) BrassardBle.arreterRecherche();
    super.dispose();
  }

  /// Code d'appairage du brassard (écrit sur l'étiquette du boîtier), demandé une seule fois :
  /// ensuite, le téléphone et le brassard se reconnaissent.
  Future<String?> _demanderCode() {
    final saisie = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, maj) => AlertDialog(
          title: const Text('Code du brassard'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Entre le code à 6 chiffres écrit sur l'étiquette du boîtier. La liaison sera chiffrée, "
                "et personne d'autre ne pourra se connecter à ton brassard."),
            const SizedBox(height: 12),
            TextField(
              controller: saisie,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => maj(() {}),
              decoration: const InputDecoration(hintText: '123456', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: BrassardBle.codeValide(saisie.text) ? () => Navigator.pop(c, saisie.text.trim()) : null,
              child: const Text('Appairer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rechercher() async {
    setState(() {
      _recherche = true;
      _erreur = null;
      _resultats = [];
    });
    try {
      await _abonnement?.cancel();
      _abonnement = BrassardBle.rechercher().listen((r) {
        if (mounted) setState(() => _resultats = r);
      });
      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Recherche impossible : $e');
    }
    if (mounted) setState(() => _recherche = false);
  }

  Future<void> _connecter(ScanResult resultat) async {
    await BrassardBle.arreterRecherche();
    setState(() {
      _connexion = true;
      _erreur = null;
    });
    try {
      final brassard = await BrassardBle.connecter(resultat.device);
      BrassardActif.choisir(brassard);
    } on ErreurBrassard catch (e) {
      _erreur = e.message;
    }
    if (mounted) setState(() => _connexion = false);
  }

  void _utiliserSimule() {
    BrassardActif.choisir(BrassardSimule());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('BRASSARD'), backgroundColor: Colors.orange[800], centerTitle: true),
      body: ValueListenableBuilder<SourceBrassard?>(
        valueListenable: BrassardActif.courant,
        builder: (context, source, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (source != null) _carteBrassard(source) else _aucunBrassard(),
            const SizedBox(height: 24),
            _sectionRecherche(),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_erreur!, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.amber),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _utiliserSimule,
              icon: const Icon(Icons.science, color: Colors.amber),
              label: const Text('Utiliser le brassard simulé', style: TextStyle(color: Colors.amber)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Le brassard simulé produit les mêmes paquets Bluetooth que le vrai, avec le profil d'effort "
              "de la simulation Simulink. Les séances simulées ne comptent pas dans le classement.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            if (_bluetoothDisponible == true) ...[
              const SizedBox(height: 28),
              const _SectionCardio(),
              const SizedBox(height: 28),
              const _SectionPodometre(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aucunBrassard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent),
        ),
        child: const Row(children: [
          Icon(Icons.bluetooth_disabled, color: Colors.redAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text('Aucun brassard relié. Les séances utiliseront le brassard simulé.',
                style: TextStyle(color: Colors.white)),
          ),
        ]),
      );

  Widget _carteBrassard(SourceBrassard source) {
    Widget ligne(String libelle, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text('$libelle : ', style: const TextStyle(color: Colors.white54)),
            Expanded(child: Text(valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: source.simule ? Colors.amber : Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(source.simule ? Icons.science : Icons.bluetooth_connected,
                color: source.simule ? Colors.amber : Colors.green),
            const SizedBox(width: 10),
            Text(source.nom, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          ligne('Numéro de série', source.numeroSerie ?? '—'),
          ligne('Firmware', source.firmware ?? '—'),
          ligne('Batterie', source.batteriePct == null ? '—' : '${source.batteriePct} %'),
          ligne('Référence 100 %', '${source.refMvcMv} mV'),
          if (source is BrassardBle) ligne('Liaison', source.appaire ? 'chiffrée (appairé avec le code)' : 'ouverte'),
          if (source.mesureFatigue) _choixSignal(source),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => CalibrationScreen(source: source)));
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.tune, color: Colors.white),
                label: const Text('Calibrer', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(BrassardActif.liberer),
              child: const Text('Déconnecter', style: TextStyle(color: Colors.redAccent)),
            ),
          ]),
          if (source is BrassardBle && source.appaire)
            TextButton(
              onPressed: () async {
                await source.oublierAppairage();
                if (mounted) setState(BrassardActif.liberer);
              },
              child: const Text("Oublier l'appairage (brassard prêté, nouveau code)",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// Signal lu par le brassard : enveloppe (intensité) ou signal brut (intensité + fatigue).
  /// Il faut AUSSI déplacer l'interrupteur OUTPUT du Link Shield, puis recalibrer.
  Widget _choixSignal(SourceBrassard source) {
    final brut = source.source == GattAthletix.sourceRaw;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Signal lu', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: GattAthletix.sourceEnv, label: Text('Enveloppe'), icon: Icon(Icons.show_chart)),
            ButtonSegment(value: GattAthletix.sourceRaw, label: Text('Brut + fatigue'), icon: Icon(Icons.graphic_eq)),
          ],
          selected: {source.source},
          onSelectionChanged: (choix) => _changerSignal(source, choix.first),
        ),
        const SizedBox(height: 6),
        Text(
          brut
              ? "Signal brut : l'interrupteur OUTPUT du Link Shield doit être sur RAW. Le brassard calcule en plus "
                  "la fréquence médiane, qui baisse quand le muscle fatigue."
              : "Enveloppe : l'interrupteur OUTPUT du Link Shield doit être sur ENV. Intensité seulement, "
                  "comme dans la simulation Simulink.",
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ]),
    );
  }

  Future<void> _changerSignal(SourceBrassard source, int choix) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await source.choisirSource(choix);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      return;
    }
    if (!mounted) return;
    setState(() {});
    final brut = choix == GattAthletix.sourceRaw;
    final calibrer = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Avant la prochaine séance'),
        content: Text(
          "1. Mets l'interrupteur OUTPUT du Link Shield sur ${brut ? 'RAW' : 'ENV'}.\n"
          "2. Refais la calibration : la référence 100 % n'a pas la même échelle avec ce signal.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Plus tard')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Calibrer maintenant')),
        ],
      ),
    );
    if (calibrer == true) {
      await navigator.push(MaterialPageRoute(builder: (_) => CalibrationScreen(source: source)));
      if (mounted) setState(() {});
    }
  }

  Widget _sectionRecherche() {
    if (_bluetoothDisponible == false) {
      return const Text(
        "Bluetooth indisponible ici. Le vrai brassard se relie depuis l'application Android, "
        "ou depuis Chrome / Edge sur un site en HTTPS. Utilise le brassard simulé en attendant.",
        style: TextStyle(color: Colors.white54),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 48)),
          onPressed: (_recherche || _connexion || _bluetoothDisponible == null) ? null : _rechercher,
          icon: _recherche
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bluetooth_searching, color: Colors.white),
          label: Text(_recherche ? 'Recherche…' : 'Rechercher mon brassard',
              style: const TextStyle(color: Colors.white)),
        ),
        if (_connexion)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Connexion au brassard…', style: TextStyle(color: Colors.white70)),
          ),
        for (final r in _resultats)
          Card(
            color: Colors.grey[900],
            child: ListTile(
              leading: const Icon(Icons.watch, color: Colors.blue),
              title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('Signal : ${r.rssi} dBm', style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.link, color: Colors.blue),
              onTap: _connexion ? null : () => _connecter(r),
            ),
          ),
        if (!_recherche && _resultats.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Allume le brassard, puis lance la recherche. Seuls les brassards Athletix s\'affichent.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
      ],
    );
  }
}

/// Ceinture cardio Bluetooth standard (service 0x180D), facultative :
/// le brassard EMG mesure les muscles, pas le cœur.
class _SectionCardio extends StatefulWidget {
  const _SectionCardio();

  @override
  State<_SectionCardio> createState() => _SectionCardioState();
}

class _SectionCardioState extends State<_SectionCardio> {
  bool _recherche = false;
  bool _connexion = false;
  String? _erreur;
  List<ScanResult> _resultats = [];
  StreamSubscription<List<ScanResult>>? _abonnement;

  @override
  void dispose() {
    _abonnement?.cancel();
    if (_recherche) FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _rechercher() async {
    setState(() {
      _recherche = true;
      _erreur = null;
      _resultats = [];
    });
    try {
      await _abonnement?.cancel();
      _abonnement = CeintureCardio.rechercher().listen((r) {
        if (mounted) setState(() => _resultats = r);
      });
      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Recherche impossible : $e');
    }
    if (mounted) setState(() => _recherche = false);
  }

  Future<void> _connecter(ScanResult r) async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _connexion = true;
      _erreur = null;
    });
    try {
      CeintureCardio.active.value?.fermer();
      CeintureCardio.active.value = await CeintureCardio.connecter(r.device);
    } catch (e) {
      _erreur = '$e';
    }
    if (mounted) setState(() => _connexion = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CeintureCardio?>(
      valueListenable: CeintureCardio.active,
      builder: (context, ceinture, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('CEINTURE OU MONTRE CARDIO (FACULTATIF)', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          const Text(
            "Le brassard mesure l'effort des muscles, pas le cœur. Une ceinture cardio Bluetooth (Polar, Garmin, "
            "Decathlon…) ou une MONTRE qui diffuse sa fréquence cardiaque ajoute le cœur aux séances.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const _AideMontre(),
          const SizedBox(height: 10),
          if (ceinture != null)
            Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: Text(ceinture.nom, style: const TextStyle(color: Colors.white)),
                subtitle: StreamBuilder<int>(
                  stream: ceinture.bpm,
                  builder: (context, s) => Text(s.hasData ? '${s.data} bpm' : 'en attente de mesure…',
                      style: const TextStyle(color: Colors.white54)),
                ),
                trailing: IconButton(
                  tooltip: 'Déconnecter',
                  icon: const Icon(Icons.link_off, color: Colors.white54),
                  onPressed: () async {
                    ceinture.fermer();
                    CeintureCardio.active.value = null;
                  },
                ),
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: (_recherche || _connexion) ? null : _rechercher,
              icon: const Icon(Icons.favorite_border, color: Colors.redAccent),
              label: Text(_recherche ? 'Recherche…' : 'Rechercher une ceinture cardio',
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          if (ceinture == null)
            for (final r in _resultats)
              Card(
                color: Colors.grey[900],
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.redAccent),
                  title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Signal : ${r.rssi} dBm', style: const TextStyle(color: Colors.white54)),
                  onTap: _connexion ? null : () => _connecter(r),
                ),
              ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// Comment faire apparaître sa montre : elle doit DIFFUSER sa fréquence cardiaque en Bluetooth
/// standard (service 0x180D), comme une ceinture. Toutes les montres ne le font pas.
class _AideMontre extends StatelessWidget {
  const _AideMontre();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white54, fontSize: 12, height: 1.4);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: const ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(bottom: 8),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        title: Text('Utiliser ma montre', style: TextStyle(color: Colors.white70, fontSize: 13)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sur la montre, active la diffusion de la fréquence cardiaque, puis appuie sur « Rechercher » ci-dessous. "
            "Le menu dépend de la marque (son nom exact peut varier selon le modèle) :\n"
            "• Garmin : Paramètres → Capteurs → Fréquence cardiaque → « Diffuser la fréquence cardiaque ».\n"
            "• Polar : réglages → « Partager la FC avec d'autres appareils ».\n"
            "• Coros, Suunto : « Diffusion de la fréquence cardiaque » dans les réglages ou au départ d'une activité.\n"
            "• Amazfit (Zepp) : application Zepp → profil → la montre → « Diffusion de la fréquence cardiaque ».\n"
            "• Huawei, Honor : selon le modèle, « Partage de la fréquence cardiaque » dans les réglages de la montre.\n"
            "Les Apple Watch, Galaxy Watch et Fitbit ne diffusent pas en Bluetooth standard sans application en plus.",
            style: style,
          ),
        ],
      ),
    );
  }
}

/// Bracelet qui compte les pas au format « podomètre WeChat » (service FEE7), comme le bracelet
/// MSGM115 de Valentin. Ses pas remplacent ceux de l'accéléromètre du téléphone pendant la séance.
class _SectionPodometre extends StatefulWidget {
  const _SectionPodometre();

  @override
  State<_SectionPodometre> createState() => _SectionPodometreState();
}

class _SectionPodometreState extends State<_SectionPodometre> {
  bool _recherche = false;
  bool _connexion = false;
  String? _erreur;
  List<ScanResult> _resultats = [];
  StreamSubscription<List<ScanResult>>? _abonnement;

  @override
  void dispose() {
    _abonnement?.cancel();
    if (_recherche) FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _rechercher() async {
    setState(() {
      _recherche = true;
      _erreur = null;
      _resultats = [];
    });
    try {
      await _abonnement?.cancel();
      _abonnement = MontrePodometre.rechercher().listen((r) {
        if (mounted) setState(() => _resultats = r);
      });
      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Recherche impossible : $e');
    }
    if (mounted) setState(() => _recherche = false);
  }

  Future<void> _connecter(ScanResult r) async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _connexion = true;
      _erreur = null;
    });
    try {
      MontrePodometre.active.value?.fermer();
      MontrePodometre.active.value = await MontrePodometre.connecter(r.device);
    } catch (e) {
      _erreur = '$e';
    }
    if (mounted) setState(() => _connexion = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MontrePodometre?>(
      valueListenable: MontrePodometre.active,
      builder: (context, montre, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('BRACELET PODOMÈTRE (FACULTATIF)', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          const Text(
            "Pour les bracelets qui ne diffusent pas le cœur en Bluetooth standard mais comptent les pas "
            "(format « WeChat », service FEE7) : leurs pas remplacent ceux du téléphone pendant la séance. "
            "Testé avec un bracelet MSGM115. Sur les bracelets YOHO (MSGM115), l'appli lit aussi le cœur, "
            "la tension estimée et le sommeil.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (montre != null)
            Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.directions_walk, color: Colors.lightGreenAccent),
                title: Text(montre.nom, style: const TextStyle(color: Colors.white)),
                subtitle: ValueListenableBuilder<MesurePodometre?>(
                  valueListenable: montre.derniere,
                  builder: (context, m, _) => Text(
                      m?.pas == null ? 'en attente du compteur…' : "${m!.pas} pas aujourd'hui (compteur du bracelet)",
                      style: const TextStyle(color: Colors.white54)),
                ),
                trailing: IconButton(
                  tooltip: 'Déconnecter',
                  icon: const Icon(Icons.link_off, color: Colors.white54),
                  onPressed: () {
                    montre.fermer();
                    MontrePodometre.active.value = null;
                  },
                ),
              ),
            ),
          if (montre != null && montre.yoho != null) _PanneauYoho(montre.yoho!),
          if (montre == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.lightGreenAccent),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: (_recherche || _connexion) ? null : _rechercher,
              icon: const Icon(Icons.directions_walk, color: Colors.lightGreenAccent),
              label: Text(_recherche ? 'Recherche…' : 'Rechercher un bracelet podomètre',
                  style: const TextStyle(color: Colors.lightGreenAccent)),
            ),
          if (montre == null)
            for (final r in _resultats)
              Card(
                color: Colors.grey[900],
                child: ListTile(
                  leading: const Icon(Icons.watch, color: Colors.lightGreenAccent),
                  title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Signal : ${r.rssi} dBm', style: const TextStyle(color: Colors.white54)),
                  onTap: _connexion ? null : () => _connecter(r),
                ),
              ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}


/// Fonctions des bracelets YOHO (service CC00) : format retrouvé dans l'appli d'origine du bracelet.
class _PanneauYoho extends StatefulWidget {
  const _PanneauYoho(this.yoho);
  final LiaisonYoho yoho;

  @override
  State<_PanneauYoho> createState() => _PanneauYohoState();
}

class _PanneauYohoState extends State<_PanneauYoho> {
  String? _enCours;
  String? _message;
  bool _inactivite = false;
  int _minutesInactivite = 60;

  Future<void> _faire(String quoi, Future<String> Function() action) async {
    setState(() {
      _enCours = quoi;
      _message = null;
    });
    try {
      final m = await action();
      if (mounted) setState(() => _message = m);
    } on TimeoutException {
      if (mounted) setState(() => _message = "$quoi : pas de réponse du bracelet. Garde-le bien serré au poignet et réessaie.");
    } catch (e) {
      if (mounted) setState(() => _message = '$quoi impossible : $e');
    }
    if (mounted) setState(() => _enCours = null);
  }

  String _duree(Duration d) => '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';

  Future<void> _profil() async {
    var taille = 170, poids = 60;
    try {
      final p = (await Api.current.getProfil())['profil'] as Map?;
      taille = int.tryParse('${p?['taille']}'.split('.').first) ?? taille;
      poids = int.tryParse('${p?['poids']}'.split('.').first) ?? poids;
    } catch (_) {}
    if (!mounted) return;
    var age = 20;
    var homme = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, maj) => AlertDialog(
          title: const Text('Profil envoyé au bracelet'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Taille $taille cm et poids $poids kg (questionnaire). Le bracelet s\'en sert pour la distance et les calories.'),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Âge'),
              Expanded(
                child: Slider(min: 10, max: 90, divisions: 80, value: age.toDouble(), label: '$age ans', onChanged: (v) => maj(() => age = v.round())),
              ),
              Text('$age ans'),
            ]),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Homme')), ButtonSegment(value: false, label: Text('Femme'))],
              selected: {homme},
              onSelectionChanged: (v) => maj(() => homme = v.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _faire('Profil', () async {
      await widget.yoho.envoyerProfil(homme: homme, age: age, tailleCm: taille, poidsKg: poids);
      return 'Profil envoyé au bracelet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yoho;
    final occupe = _enCours != null;
    Widget bouton(IconData icone, String texte, VoidCallback action) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
          onPressed: occupe ? null : action,
          icon: Icon(icone, size: 18, color: Colors.lightGreenAccent),
          label: Text(texte, style: const TextStyle(color: Colors.white70)),
        );
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ValueListenableBuilder<int?>(
            valueListenable: y.batterie,
            builder: (context, b, _) => Text(
              'Bracelet YOHO${y.firmware != null ? ' · firmware ${y.firmware}' : ''}${b != null ? ' · batterie $b %' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ValueListenableBuilder<int?>(
              valueListenable: y.coeur,
              builder: (context, bpm, _) => _Valeur(Icons.favorite, 'Cœur', bpm == null ? '—' : '$bpm bpm', Colors.redAccent),
            ),
            ValueListenableBuilder<TensionYoho?>(
              valueListenable: y.tension,
              builder: (context, t, _) => _Valeur(Icons.speed, 'Tension (estimée)', t == null ? '—' : '${t.systolique}/${t.diastolique}', Colors.orangeAccent),
            ),
            ValueListenableBuilder<NuitYoho?>(
              valueListenable: y.nuit,
              builder: (context, n, _) => _Valeur(Icons.bedtime, 'Dernière nuit', n == null ? 'synchroniser' : _duree(n.total), Colors.lightBlueAccent),
            ),
          ]),
          ValueListenableBuilder<NuitYoho?>(
            valueListenable: y.nuit,
            builder: (context, n, _) => n == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Profond ${_duree(n.profond)} · léger ${_duree(n.leger)} · ${n.reveils} réveil(s)',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            bouton(Icons.favorite_border, 'Mesurer le cœur', () => _faire('Mesure du cœur', () async => 'Cœur : ${await y.mesurerCoeur()} bpm')),
            bouton(Icons.speed, 'Estimer la tension', () => _faire('Estimation de la tension', () async {
                  final t = await y.mesurerTension();
                  return 'Tension estimée : ${t.systolique}/${t.diastolique} mmHg (estimation du bracelet, pas une mesure médicale)';
                })),
            bouton(Icons.vibration, 'Faire vibrer', () => _faire('Vibration', () async {
                  await y.faireVibrer();
                  return 'Le bracelet doit vibrer.';
                })),
            bouton(Icons.sync, 'Synchroniser (sommeil)', () => _faire('Synchronisation', () async {
                  final s = await y.synchroniser();
                  return '${s.periodes.length} périodes d\'activité et ${s.mesures.length} mesures récupérées.';
                })),
            bouton(Icons.person, 'Envoyer mon profil', _profil),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Rappel d'inactivité", style: TextStyle(color: Colors.white)),
            subtitle: Text('Le bracelet vibre après $_minutesInactivite min sans bouger', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            value: _inactivite,
            onChanged: occupe
                ? null
                : (v) => _faire("Rappel d'inactivité", () async {
                      await y.reglerInactivite(v, _minutesInactivite);
                      if (mounted) setState(() => _inactivite = v);
                      return v ? 'Rappel activé ($_minutesInactivite min).' : 'Rappel désactivé.';
                    }),
          ),
          if (_inactivite)
            Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: _minutesInactivite.toDouble(),
              label: '$_minutesInactivite min',
              onChanged: (v) => setState(() => _minutesInactivite = v.round()),
              onChangeEnd: (_) => _faire("Rappel d'inactivité", () async {
                await y.reglerInactivite(true, _minutesInactivite);
                return 'Rappel réglé sur $_minutesInactivite min.';
              }),
            ),
          if (_enCours != null)
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('$_enCours…', style: const TextStyle(color: Colors.white54)),
            ]),
          if (_message != null) Text(_message!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          const Text(
            'La musique se commande depuis le bracelet (appui long sur son écran musique) si le bracelet est aussi '
            'appairé dans les réglages Bluetooth du téléphone. Le bracelet n\'est pas un dispositif médical.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ]),
      ),
    );
  }
}

class _Valeur extends StatelessWidget {
  const _Valeur(this.icone, this.titre, this.valeur, this.couleur);
  final IconData icone;
  final String titre, valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, color: couleur, size: 18),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ]),
      );
}
