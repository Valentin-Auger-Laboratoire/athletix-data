import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'evolution.dart';

/// Carnet de suivi en PDF, à remettre au médecin ou au kinésithérapeute (bibliothèque pdf, Apache 2.0).
///
/// Police standard du PDF (Helvetica) : elle ne contient que les caractères latins courants,
/// donc les textes saisis sont nettoyés ([texteSur]).
class ExportPdf {
  ExportPdf._();

  /// Remplace ce que la police standard ne sait pas afficher.
  static String texteSur(String t) {
    const remplacements = {'’': "'", '‘': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', '≥': '>=', '≤': '<=',
      '×': 'x', 'œ': 'oe', 'Œ': 'OE', '€': 'EUR'};
    final b = StringBuffer();
    for (final r in t.runes) {
      final c = String.fromCharCode(r);
      b.write(remplacements[c] ?? (r <= 0xFF ? c : '?'));
    }
    return b.toString();
  }

  static String _date(String? brute) =>
      brute == null || brute.length < 10 ? '' : '${brute.substring(8, 10)}/${brute.substring(5, 7)}/${brute.substring(0, 4)}';

  static String _duree(num? s) {
    final v = (s ?? 0).toInt();
    return v >= 3600 ? '${v ~/ 3600} h ${((v % 3600) ~/ 60).toString().padLeft(2, '0')}' : '${v ~/ 60} min';
  }

  static String _val(dynamic v, [String unite = '']) => v == null ? '' : '$v$unite';

  /// Construit le PDF. [seances] au format de get_seances.php (plus récente en premier).
  static Future<Uint8List> construire(List<Map<String, dynamic>> seances, {required String pseudo, DateTime? le}) async {
    final date = le ?? DateTime.now();
    final evolution = Evolution(seances.map(SeanceResume.depuisApi).whereType<SeanceResume>());
    final semaines = evolution.semaines.reversed.where((s) => s.nbSeances > 0).toList();
    final moinsBonnes = {for (final m in evolution.semainesMoinsBonnes()) m.semaine.lundi: m};
    final nbSimulees = seances.where((s) => s['donnees_simulees'] == true).length;
    String j(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    const petit = pw.TextStyle(fontSize: 8);
    final gras = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    final doc = pw.Document(title: 'Carnet de suivi Athletix-Data', author: texteSur(pseudo));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(texteSur("Athletix-Data, projet étudiant EPISEN : ce n'est pas un dispositif médical."), style: petit),
        pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: petit),
      ]),
      build: (c) => [
        pw.Text(texteSur('Carnet de suivi : $pseudo'), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          texteSur('Edité le ${j(date)} · ${seances.length} séance(s)'
              '${seances.isEmpty ? '' : ' du ${_date(seances.last['debut']?.toString())} au ${_date(seances.first['debut']?.toString())}'}'
              '${nbSimulees > 0 ? ' · dont $nbSimulees avec le brassard simulé (pas de vraie mesure)' : ''}'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          texteSur("Intensité musculaire en % de la contraction maximale volontaire (% MVC), mesurée par un brassard "
              "EMG (MyoWare 2.0) et recalibrée à chaque séance. Effort intense : au-dessus du seuil d'alerte "
              "(75 %, ou 60 % en mode adapté). Fatigue et douleur : ressenti noté par la personne, de 0 à 10. "
              "Indice de fatigue : évolution de l'intensité entre le début et la fin de la séance (expérimental)."),
          style: petit,
        ),
        pw.SizedBox(height: 12),
        pw.Text('Par semaine', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: gras,
          cellStyle: petit,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          columnWidths: {
            for (var i = 0; i < 8; i++) i: const pw.FlexColumnWidth(1.1),
            8: const pw.FlexColumnWidth(4.5),
          },
          headers: ['Semaine du', 'Séances', 'Durée', 'Intensité moy.', 'Intensité max', 'Fatigue ressentie',
            'Douleur', 'Mauvaises nuits', 'Remarque'].map(texteSur).toList(),
          data: [
            for (final s in semaines)
              [
                j(s.lundi),
                '${s.nbSeances}',
                _duree(s.dureeTotaleS),
                '${s.intensiteMoyenne.round()} %',
                '${s.intensiteMax} %',
                s.fatigueRessentie == null ? '' : s.fatigueRessentie!.toStringAsFixed(1).replaceAll('.', ','),
                s.douleurMoyenne == null ? '' : s.douleurMoyenne!.toStringAsFixed(1).replaceAll('.', ','),
                '${s.nbNuitsMauvaises}',
                texteSur(moinsBonnes[s.lundi] == null
                    ? ''
                    : 'Rendement -${moinsBonnes[s.lundi]!.baissePct} % : ${moinsBonnes[s.lundi]!.causes.join(', ')}'),
              ],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(texteSur('Séances'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: gras,
          cellStyle: petit,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          columnWidths: {11: const pw.FlexColumnWidth(3)},
          headers: ['Date', 'Activité', 'Durée', 'Moy.', 'Max', 'Effort intense', 'Indice fatigue', 'FC moy/max',
            'Fatigue', 'Douleur', 'Sommeil', 'Commentaire'].map(texteSur).toList(),
          data: [
            for (final s in seances)
              [
                _date(s['debut']?.toString()),
                texteSur('${s['discipline']}${s['donnees_simulees'] == true ? ' (simulée)' : ''}'
                    '${s['mode_adapte'] == true ? ' (adapté)' : ''}'),
                _duree(s['duree_s'] as num?),
                _val(s['intensite_moyenne_pct'], ' %'),
                _val(s['intensite_max_pct'], ' %'),
                _duree(s['temps_effort_intense_s'] as num?),
                s['indice_fatigue_pct'] == null ? '' : '${(s['indice_fatigue_pct'] as num) > 0 ? '+' : ''}${s['indice_fatigue_pct']} %',
                s['fc_moy'] == null ? '' : '${s['fc_moy']}/${s['fc_max'] ?? ''}',
                _val(s['ressenti_fatigue'], '/10'),
                _val(s['douleur'], '/10'),
                texteSur(_val(s['sommeil'])),
                texteSur(_val(s['commentaire'])),
              ],
          ],
        ),
      ],
    ));
    return doc.save();
  }

  static Future<void> partager(List<Map<String, dynamic>> seances, {required String pseudo}) async {
    final octets = await construire(seances, pseudo: pseudo);
    final nom = 'athletix-carnet-${DateTime.now().toIso8601String().substring(0, 10)}.pdf';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(octets, mimeType: 'application/pdf', name: nom)],
      fileNameOverrides: [nom],
      subject: 'Mon carnet de suivi Athletix-Data',
    ));
  }
}
