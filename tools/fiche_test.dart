// Génère la fiche de test à imprimer (hardware/fiche-de-test.pdf) À PARTIR du protocole
// (hardware/PROTOCOLE-DE-TEST.md) : les deux restent identiques. Même mise en page que le carnet
// et le mode d'emploi. Colonnes « Mesuré » laissées vides et cases à cocher, pour écrire à la main.
//
//   dart run tools/fiche_test.dart        (depuis la racine du dépôt)
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _rouge = PdfColor.fromInt(0xFFC8102E);

/// Police standard : caractères latins courants seulement (comme le carnet).
String sur(String t) {
  const r = {'’': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', '≥': '>=', '≤': '<=', '→': '->', '↔': '<->',
    'œ': 'oe', '×': 'x', '≈': '~', '⚠️': '(!)', '⚠': '(!)', 'Ω': ' ohms', 'µ': 'u'};
  var s = t;
  r.forEach((a, b) => s = s.replaceAll(a, b));
  return s.runes.map((c) => c <= 0xFF ? String.fromCharCode(c) : '?').join();
}

/// Retire la syntaxe Markdown : liens, code, gras.
String texte(String md) => sur(md
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!)
    .replaceAll('`', '')
    .replaceAll('**', '')
    .trim());

/// Paragraphe : retire aussi la marque de citation « > » en début de ligne (pas dans les tableaux,
/// où « > 75 % » veut dire « plus de 75 % »).
String paragraphe(String md) => texte(md.replaceFirst(RegExp(r'^>\s*'), ''));

class Bloc {
  Bloc.titre(this.contenu) : lignes = null, paragraphe = false;
  Bloc.paragraphe(this.contenu) : lignes = null, paragraphe = true;
  Bloc.tableau(this.lignes) : contenu = '', paragraphe = false;
  final String contenu;
  final List<List<String>>? lignes;
  final bool paragraphe;
}

List<Bloc> lire(String md) {
  final blocs = <Bloc>[];
  final lignes = md.split('\n');
  for (var i = 0; i < lignes.length; i++) {
    final l = lignes[i].trimRight();
    if (l.startsWith('# ')) continue; // titre du document : remplacé par celui de la fiche
    if (l.startsWith('## ')) {
      blocs.add(Bloc.titre(texte(l.substring(3))));
    } else if (l.startsWith('|')) {
      final tableau = <List<String>>[];
      while (i < lignes.length && lignes[i].trimLeft().startsWith('|')) {
        final cellules = lignes[i].trim().split('|');
        final c = cellules.sublist(1, cellules.length - 1).map((x) => x.trim()).toList();
        if (!c.every((x) => RegExp(r'^:?-+:?$').hasMatch(x))) tableau.add(c.map(texte).toList());
        i++;
      }
      i--;
      blocs.add(Bloc.tableau(tableau));
    } else if (l.trim().isNotEmpty) {
      blocs.add(Bloc.paragraphe(paragraphe(l)));
    }
  }
  return blocs;
}

pw.Widget caseACocher(String libelle) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8))),
      pw.SizedBox(width: 2),
      pw.Text(libelle, style: const pw.TextStyle(fontSize: 7)),
    ]);

pw.Widget tableau(List<List<String>> lignes) {
  final entete = lignes.first;
  final iMesure = entete.indexWhere((h) => h.startsWith('Mesur'));
  final iOk = entete.indexWhere((h) => h.startsWith('OK'));
  pw.Widget cellule(String t, int col, {bool tete = false}) {
    final style = pw.TextStyle(fontSize: 8, fontWeight: tete ? pw.FontWeight.bold : pw.FontWeight.normal);
    if (!tete && col == iOk) {
      return pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [caseACocher('oui'), pw.SizedBox(height: 3), caseACocher('non')]));
    }
    return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t, style: style));
  }

  final largeurs = <int, pw.TableColumnWidth>{};
  for (var c = 0; c < entete.length; c++) {
    if (c == 0 && entete[0] == '#') {
      largeurs[c] = const pw.FixedColumnWidth(24);
    } else if (c == iOk) {
      largeurs[c] = const pw.FixedColumnWidth(36);
    } else if (c == iMesure) {
      largeurs[c] = const pw.FlexColumnWidth(2.2);
    } else {
      largeurs[c] = const pw.FlexColumnWidth(3);
    }
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
    columnWidths: largeurs,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [for (var c = 0; c < entete.length; c++) cellule(entete[c], c, tete: true)],
      ),
      for (final l in lignes.skip(1))
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [for (var c = 0; c < entete.length; c++) pw.ConstrainedBox(constraints: const pw.BoxConstraints(minHeight: 24), child: cellule(c < l.length ? l[c] : '', c))],
        ),
    ],
  );
}

Future<void> main() async {
  final md = File('hardware/PROTOCOLE-DE-TEST.md').readAsStringSync();
  final blocs = lire(md);
  const petit = pw.TextStyle(fontSize: 8);
  pw.Widget champ(String libelle) => pw.Expanded(
        child: pw.Row(children: [
          pw.Text(sur(libelle), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Expanded(child: pw.Container(height: 12, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))))),
        ]),
      );

  final contenu = <pw.Widget>[
    pw.Text(sur('Fiche de test du brassard Athletix-Data'), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 3),
    pw.Text(sur('À imprimer et remplir à la main à la réception du matériel. Tirée du protocole de test (hardware/PROTOCOLE-DE-TEST.md).'),
        style: const pw.TextStyle(fontSize: 10)),
    pw.SizedBox(height: 10),
    pw.Row(children: [champ('Date :'), pw.SizedBox(width: 16), champ('Testé par :'), pw.SizedBox(width: 16), champ('N° de série du brassard :')]),
    pw.SizedBox(height: 8),
  ];
  // Chaque étape (titre, textes, tableau) est gardée d'un seul tenant sur une page
  var section = <pw.Widget>[];
  void fermer() {
    if (section.isNotEmpty) {
      contenu.add(pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: section)));
      section = <pw.Widget>[];
    }
  }

  for (final b in blocs) {
    if (b.lignes == null && !b.paragraphe) fermer();
    final cible = section;
    if (b.lignes != null) {
      cible.add(tableau(b.lignes!));
    } else if (b.paragraphe) {
      final alerte = b.contenu.startsWith('(!)');
      cible.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3, bottom: 3),
        child: pw.Text(b.contenu,
            style: pw.TextStyle(fontSize: 8.5, color: alerte ? _rouge : PdfColors.black, fontWeight: alerte ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ));
    } else {
      cible.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(b.contenu, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ));
    }
  }
  fermer();
  contenu.addAll([
    pw.Padding(padding: const pw.EdgeInsets.only(top: 12, bottom: 4), child: pw.Text(sur('Remarques'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
    for (var i = 0; i < 6; i++)
      pw.Container(height: 18, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600)))),
  ]);

  final doc = pw.Document(title: 'Fiche de test du brassard Athletix-Data', author: 'Valentin Auger');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
    footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(sur("Athletix-Data, projet étudiant EPISEN : ce n'est pas un dispositif médical."), style: petit),
      pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: petit),
    ]),
    build: (_) => contenu,
  ));
  final sortie = File('hardware/fiche-de-test.pdf');
  await sortie.writeAsBytes(await doc.save());
  stdout.writeln('Écrit : ${sortie.path}');
}
