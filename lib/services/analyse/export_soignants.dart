import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Export des séances pour le médecin ou le kinésithérapeute (fichier CSV, lisible dans Excel).
class ExportSoignants {
  ExportSoignants._();

  static const List<(String, String)> colonnes = [
    ('debut', 'Date'),
    ('discipline', 'Activité'),
    ('duree_s', 'Durée (s)'),
    ('intensite_moyenne_pct', 'Intensité moyenne (% MVC)'),
    ('intensite_max_pct', 'Intensité max (% MVC)'),
    ('temps_effort_intense_s', 'Effort intense (s)'),
    ('nb_alertes', 'Alertes'),
    ('nb_contractions', 'Contractions'),
    ('indice_fatigue_pct', 'Indice de fatigue (%)'),
    ('distance_m', 'Distance (m)'),
    ('vitesse_moy_kmh', 'Vitesse (km/h)'),
    ('fc_moy', 'FC moyenne'),
    ('fc_max', 'FC max'),
    ('temperature_c', 'Température (°C)'),
    ('ressenti_fatigue', 'Fatigue ressentie (0-10)'),
    ('douleur', 'Douleur (0-10)'),
    ('sommeil', 'Sommeil'),
    ('commentaire', 'Commentaire'),
    ('mode_adapte', 'Mode adapté'),
    ('donnees_simulees', 'Données simulées'),
  ];

  /// CSV au format français (séparateur « ; », virgule décimale), avec BOM pour qu'Excel lise les accents.
  static String versCsv(List<Map<String, dynamic>> seances) {
    String cellule(dynamic v) {
      if (v == null) return '';
      if (v is bool) return v ? 'oui' : 'non';
      var t = v is double ? v.toString().replaceAll('.', ',') : v.toString();
      if (t.contains(';') || t.contains('"') || t.contains('\n')) t = '"${t.replaceAll('"', '""')}"';
      return t;
    }

    final lignes = <String>[
      colonnes.map((c) => c.$2).join(';'),
      for (final s in seances) colonnes.map((c) => cellule(s[c.$1])).join(';'),
    ];
    return '﻿${lignes.join('\r\n')}\r\n';
  }

  /// Ouvre le partage du téléphone (ou télécharge le fichier dans un navigateur).
  static Future<void> partager(List<Map<String, dynamic>> seances) async {
    final octets = Uint8List.fromList(utf8.encode(versCsv(seances)));
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(octets, mimeType: 'text/csv', name: 'athletix-seances-$date.csv')],
      fileNameOverrides: ['athletix-seances-$date.csv'],
      subject: 'Mes séances Athletix-Data',
      text: "Mes séances Athletix-Data (intensité musculaire en % de ma contraction maximale). "
          "Projet étudiant, ce n'est pas un dispositif médical.",
    ));
  }
}
