import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'package:athletix_data/services/reglages.dart';
import 'package:athletix_data/services/brassard/suivi_fatigue.dart';
import 'package:athletix_data/services/telephone/meteo.dart';
import 'package:athletix_data/widgets/graphiques.dart';
import 'historique_screen.dart';

/// Détail d'une séance : courbe d'intensité, zones, mesures du téléphone, cardio, météo, contexte.
/// [seance] a le format de get_seances.php.
class SeanceDetailScreen extends StatelessWidget {
  const SeanceDetailScreen({super.key, required this.seance});

  final Map<String, dynamic> seance;

  int? _entier(String c) => (seance[c] as num?)?.toInt();
  double? _decimal(String c) => (seance[c] as num?)?.toDouble();

  @override
  Widget build(BuildContext context) {
    final s = seance;
    final simule = s['donnees_simulees'] == true;
    final courbe = (s['courbe'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? [];
    final duree = _entier('duree_s') ?? 0;
    final zones = [
      _entier('temps_zone_repos_s'),
      _entier('temps_zone_moderee_s'),
      _entier('temps_zone_soutenue_s'),
      _entier('temps_effort_intense_s'),
    ];
    final fatigue = _entier('indice_fatigue_pct');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('${s['discipline']}'.toUpperCase()), backgroundColor: Colors.blueGrey[900], centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${HistoriqueScreen.date(s['debut']?.toString())} · ${HistoriqueScreen.duree(duree)}'
              '${simule ? ' · brassard simulé' : ''}${s['mode_adapte'] == true ? ' · mode adapté' : ''}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          _section('Intensité musculaire', [
            Row(children: [
              _chiffre('moyenne', '${s['intensite_moyenne_pct']} %'),
              _chiffre('maximum', '${s['intensite_max_pct']} %'),
              _chiffre('alertes', '${s['nb_alertes']}'),
              if (_entier('nb_contractions') != null) _chiffre('contractions', '${_entier('nb_contractions')}'),
              if ((_entier('nb_series') ?? 0) > 1) _chiffre('séries', '${_entier('nb_series')}'),
            ]),
            const SizedBox(height: 12),
            if (courbe.length >= 2) CourbeIntensite(valeurs: courbe, seuil: s['mode_adapte'] == true ? 60 : 75, pasS: 5),
            if (courbe.length >= 2) const SizedBox(height: 6),
            if (courbe.length >= 2)
              const Text('Une valeur toutes les 5 s · ligne rouge : seuil d\'alerte',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            if (zones.every((z) => z != null)) ...[
              const SizedBox(height: 14),
              BarreZones(secondes: zones.map((z) => z!).toList()),
            ],
          ]),
          if (_decimal('baisse_mdf_pct') != null) _sectionFatigueMesuree(),
          if (fatigue != null && _decimal('baisse_mdf_pct') == null)
            _section('Indice de fatigue (expérimental)', [
              Text(
                fatigue > 10
                    ? "+$fatigue % : l'intensité a monté entre le début et la fin de la séance. Pour un même effort, "
                        "un muscle qui fatigue doit recruter plus de fibres : c'est un signe possible de fatigue."
                    : fatigue < -10
                        ? "$fatigue % : l'intensité a baissé en fin de séance (effort moins fort, ou exercice différent)."
                        : "$fatigue % : intensité stable entre le début et la fin de la séance.",
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 6),
              const Text("Repère seulement : il dépend aussi de l'exercice choisi. La vraie mesure de la fatigue "
                  "(baisse de la fréquence médiane) se fait avec le brassard en « Brut + fatigue » (écran Brassard).",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          if (_entier('distance_m') != null || _entier('nb_pas') != null)
            _section('Téléphone', [
              Wrap(spacing: 8, runSpacing: 12, children: [
                if (_entier('distance_m') != null) _chiffreFixe('distance', '${decimalFr(_entier('distance_m')! / 1000, 2)} km'),
                if (_decimal('vitesse_moy_kmh') != null) _chiffreFixe('vitesse', '${decimalFr(_decimal('vitesse_moy_kmh')!, 1)} km/h'),
                if (_decimal('vitesse_moy_kmh') != null && _decimal('vitesse_moy_kmh')! >= 3)
                  _chiffreFixe('allure', _allure(_decimal('vitesse_moy_kmh')!)),
                if (_entier('denivele_m') != null) _chiffreFixe('dénivelé +', '${_entier('denivele_m')} m'),
                if (_entier('nb_pas') != null) _chiffreFixe('pas', '${_entier('nb_pas')}'),
              ]),
            ]),
          if (_entier('distance_m') != null && s['id'] != null)
            _section('Parcours', [_SectionParcours(id: (s['id'] as num).toInt(), trace: s['trace'] as List?)]),
          if (_entier('fc_moy') != null)
            _section('Cœur (ceinture ou montre)', [
              Row(children: [
                _chiffre('moyenne', '${_entier('fc_moy')} bpm'),
                if (_entier('fc_max') != null) _chiffre('maximum', '${_entier('fc_max')} bpm'),
              ]),
            ]),
          if (_decimal('temperature_c') != null)
            _section('Météo', [
              Text(
                '${decimalFr(_decimal('temperature_c')!, 1)} °C, ${_entier('humidite_pct') ?? '—'} % d\'humidité, '
                '${Meteo.libelle(_entier('meteo_code') ?? 0)}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (_decimal('temperature_c')! >= Meteo.seuilChaleurC)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Chaleur : effort plus coûteux, et symptômes possibles en cas de sclérose en plaques.',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
            ]),
          if (_entier('ressenti_fatigue') != null || s['sommeil'] != null || s['commentaire'] != null)
            _section('Ressenti', [
              Wrap(spacing: 18, runSpacing: 6, children: [
                if (_entier('ressenti_fatigue') != null) _texte('Fatigue', '${_entier('ressenti_fatigue')}/10'),
                if (_entier('douleur') != null) _texte('Douleur', '${_entier('douleur')}/10'),
                if (s['sommeil'] != null) _texte('Sommeil', '${s['sommeil']}'),
              ]),
              if (s['commentaire'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('« ${s['commentaire']} »', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                ),
            ]),
          const SizedBox(height: 12),
          const Text("Athletix-Data est un projet étudiant : ce n'est pas un dispositif médical.",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  /// Fatigue mesurée par la fréquence médiane du signal brut (brassard en source RAW).
  Widget _sectionFatigueMesuree() {
    final baisse = _decimal('baisse_mdf_pct')!;
    final debut = _decimal('mdf_debut_hz'), fin = _decimal('mdf_fin_hz');
    final courbe = (seance['courbe_mdf'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? [];
    final couleur = baisse >= 10 ? Colors.redAccent : (baisse >= 5 ? Colors.orangeAccent : Colors.greenAccent);
    return _section('Fatigue du muscle (fréquence médiane)', [
      Row(children: [
        if (debut != null) _chiffre('début', '${decimalFr(debut, 0)} Hz'),
        if (fin != null) _chiffre('fin', '${decimalFr(fin, 0)} Hz'),
        Expanded(
          child: Column(children: [
            Text('${baisse > 0 ? '−' : '+'}${decimalFr(baisse.abs(), 1)} %',
                style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            const Text('baisse', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Text('${ResultatFatigue.interpretation(baisse)[0].toUpperCase()}${ResultatFatigue.interpretation(baisse).substring(1)}.',
          style: TextStyle(color: couleur, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      if (courbe.isNotEmpty) CourbeFrequence(valeurs: courbe, debutHz: debut, finHz: fin),
      const SizedBox(height: 6),
      const Text(
        "Quand un muscle fatigue, ses fibres conduisent le signal moins vite : le spectre glisse vers les basses "
        "fréquences et la fréquence médiane baisse. Repères usuels : une baisse de 10 à 30 % accompagne un effort "
        "qui fatigue. Points : un par bloc de 30 s avec effort ; pointillés : tendance. Repère d'un prototype, pas un avis médical.",
        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
      ),
    ]);
  }

  static String _allure(double kmh) {
    final minParKm = 60 / kmh;
    final m = minParKm.floor(), sec = ((minParKm - m) * 60).round();
    return "$m'${sec.toString().padLeft(2, '0')}\"/km";
  }

  Widget _section(String titre, List<Widget> enfants) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...enfants,
        ]),
      );

  Widget _chiffre(String libelle, String valeur) => Expanded(
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valeur, maxLines: 1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 2),
          Text(libelle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      );

  Widget _chiffreFixe(String libelle, String valeur) => SizedBox(width: 96, child: Row(children: [_chiffre(libelle, valeur)]));

  Widget _texte(String libelle, String valeur) => RichText(
        text: TextSpan(children: [
          TextSpan(text: '$libelle : ', style: const TextStyle(color: Colors.white54)),
          TextSpan(text: valeur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Tracé et profil vitesse / intensité. La liste des séances ne contient pas le tracé :
/// il est chargé ici, pour cette séance seulement.
class _SectionParcours extends StatefulWidget {
  const _SectionParcours({required this.id, this.trace});

  final int id;
  final List? trace;

  @override
  State<_SectionParcours> createState() => _SectionParcoursState();
}

class _SectionParcoursState extends State<_SectionParcours> {
  List<PointTrace>? _trace;
  bool _charge = false;

  static List<PointTrace>? _lire(List? brut) =>
      brut?.map((p) => (p as List).map((v) => v as num).toList()).toList();

  @override
  void initState() {
    super.initState();
    _trace = _lire(widget.trace);
    if (_trace == null) {
      Api.current.getSeance(widget.id).then((r) {
        final liste = r['seances'] as List? ?? [];
        if (!mounted) return;
        setState(() {
          _charge = true;
          if (liste.isNotEmpty) _trace = _lire((liste.first as Map)['trace'] as List?);
        });
      });
    } else {
      _charge = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _trace;
    if (!_charge) return const Center(child: CircularProgressIndicator(color: Colors.orange));
    if (t == null || t.length < 2) {
      return const Text('Pas de tracé pour cette séance (parcours trop court, ou enregistré avant cette version).',
          style: TextStyle(color: Colors.white38, fontSize: 12));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ValueListenableBuilder<bool>(
        valueListenable: Reglages.fondDeCarte,
        builder: (context, fond, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CarteParcours(trace: t, fondDeCarte: fond),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Reglages.changer(Reglages.fondDeCarte, !fond),
              icon: Icon(fond ? Icons.layers_clear : Icons.map_outlined, size: 16, color: Colors.white54),
              label: Text(fond ? 'Masquer la carte' : 'Afficher la carte (OpenStreetMap)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ]),
      ),
      const Text('Les 200 premiers et derniers mètres ne sont pas enregistrés (domicile). La carte, si elle est '
          "affichée, est demandée à OpenStreetMap pour la zone du parcours (sans compte ni nom).",
          style: TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 14),
      VitesseIntensite(trace: t),
    ]);
  }
}
