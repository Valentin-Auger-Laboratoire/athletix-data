import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'package:athletix_data/services/brassard/brassard_ble.dart';
import 'package:athletix_data/services/brassard/brassard_simule.dart';
import 'package:athletix_data/services/brassard/gatt_athletix.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/telephone/cardio.dart';
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
    BrassardBle.disponible().then((ok) {
      if (mounted) setState(() => _bluetoothDisponible = ok);
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    if (_recherche) BrassardBle.arreterRecherche();
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
          const Text('CEINTURE CARDIO (FACULTATIF)', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          const Text(
            "Le brassard mesure l'effort des muscles, pas le cœur. Une ceinture cardio Bluetooth standard "
            "(Polar, Garmin, Decathlon…) ajoute la fréquence cardiaque aux séances.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
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
