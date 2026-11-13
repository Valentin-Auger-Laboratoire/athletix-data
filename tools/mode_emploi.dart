// Génère le mode d'emploi du brassard (mode-emploi/mode-emploi.pdf), avec la même mise en page
// que le carnet PDF de l'application (lib/services/analyse/export_pdf.dart) : police standard,
// titres, tableaux gris, pied de page « projet étudiant, pas un dispositif médical ».
//
//   dart run tools/mode_emploi.dart        (depuis la racine du dépôt)
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// La police standard du PDF ne connaît que les caractères latins courants (comme dans le carnet).
String sur(String t) {
  const r = {'’': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', '≥': '>=', '≤': '<=', '→': '->', 'œ': 'oe', '×': 'x'};
  return t.runes.map((c) => r[String.fromCharCode(c)] ?? (c <= 0xFF ? String.fromCharCode(c) : '?')).join();
}

const _rouge = PdfColor.fromInt(0xFFC8102E);
const _gris = PdfColors.grey700;

pw.Widget titre(String numero, String texte) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
      child: pw.Row(children: [
        pw.Container(
          width: 16,
          height: 16,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(color: _rouge, shape: pw.BoxShape.circle),
          child: pw.Text(numero, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 6),
        pw.Text(sur(texte), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ]),
    );

pw.Widget etapes(List<String> lignes) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lignes.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2.5),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 12, child: pw.Text('${i + 1}.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text(sur(lignes[i]), style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2))),
            ]),
          ),
      ],
    );

pw.Widget note(String texte, {PdfColor couleur = _gris}) =>
    pw.Text(sur(texte), style: pw.TextStyle(fontSize: 8, color: couleur, fontStyle: pw.FontStyle.italic));

pw.Widget ecran(pw.MemoryImage image, String legende, {double largeur = 78}) => pw.Column(children: [
      pw.Container(
        width: largeur,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
        child: pw.Image(image, width: largeur),
      ),
      pw.SizedBox(height: 2),
      pw.SizedBox(width: largeur, child: pw.Text(sur(legende), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
    ]);

pw.MemoryImage img(String nom) => pw.MemoryImage(File('mode-emploi/images/$nom').readAsBytesSync());

Future<void> main() async {
  final doc = pw.Document(title: "Mode d'emploi du brassard Athletix-Data", author: 'Valentin Auger');
  const petit = pw.TextStyle(fontSize: 8);
  final gras = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
    footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(sur("Athletix-Data, projet étudiant EPISEN : ce n'est pas un dispositif médical."), style: petit),
      pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: petit),
    ]),
    build: (c) => [
      pw.Text(sur("Mode d'emploi du brassard Athletix-Data"), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text(sur('Prototype : brassard EMG (MyoWare 2.0, ESP32-S3) et application Android. Version du 13 novembre 2026.'),
          style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 8),
      // Sécurité, en premier
      pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _rouge, width: 1), color: const PdfColor.fromInt(0xFFFDF0F1)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(sur('Avant de commencer'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _rouge)),
          pw.SizedBox(height: 3),
          for (final l in [
            "Ce n'est pas un dispositif médical : les mesures ne remplacent pas l'avis d'un médecin ou d'un kinésithérapeute.",
            "Le prototype n'est pas étanche : pas d'essai dans l'eau sans boîtier étanche.",
            'Électrodes sur la peau et brassard branché en USB : PC portable débranché du secteur (sur sa batterie).',
            'Peau qui rougit ou démange : retirer les électrodes. Ne pas laisser la batterie charger sans surveillance.',
          ])
            pw.Bullet(text: sur(l), style: const pw.TextStyle(fontSize: 8.5), bulletSize: 2.5, bulletMargin: const pw.EdgeInsets.only(top: 3.5, right: 5)),
        ]),
      ),
      titre('1', 'Poser le brassard'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 5,
          child: etapes([
            "Peau propre et sèche (pas de crème). Prévoir 3 électrodes à pression neuves : celles du kit, ou des électrodes d'ECG standard (pharmacie, salle de TP).",
            'Clipser deux électrodes sous le capteur MyoWare : MID et END.',
            "Coller le capteur sur le biceps, aligné avec le bras : MID au milieu du muscle, sur la partie la plus bombée quand on contracte ; END à côté, côté coude.",
            "Coller la troisième électrode (REF) sur l'os du coude, avec le câble de référence. Sans câble : pastille REF du capteur.",
            "Serrer le brassard élastique sans couper la circulation, puis allumer avec l'interrupteur.",
          ]),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 4, child: pw.Image(img('pose-electrodes.png'))),
      ]),
      titre('2', 'Relier le brassard et faire la calibration'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            etapes([
              "Dans l'application : toucher « Brassard non relié », puis « Rechercher mon brassard » et choisir Athletix-XXXX (Bluetooth et localisation autorisés).",
              'Toucher « Calibrer ». Assis, coude plié à 90°, bras détendu.',
              'Toucher « Commencer » : au signal, serrer le biceps le plus fort possible pendant 3 secondes.',
              "La valeur mesurée devient 100 % pour la séance. La refaire à chaque séance : la force change d'un jour à l'autre.",
            ]),
            pw.SizedBox(height: 3),
            note("« Calibration impossible » : signal trop faible. Vérifier que les électrodes collent bien et que l'interrupteur du Link Shield est sur ENV."),
          ]),
        ),
        pw.SizedBox(width: 8),
        ecran(img('brassard.jpg'), 'Écran Brassard', largeur: 70),
        pw.SizedBox(width: 6),
        ecran(img('calibration.jpg'), 'Consignes', largeur: 70),
        pw.SizedBox(width: 6),
        ecran(img('calibration-effort.jpg'), 'Serrer 3 s', largeur: 70),
      ]),
      titre('3', 'Faire une séance'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            etapes([
              "À l'accueil : choisir une famille de sports, puis le sport.",
              "L'écran affiche l'intensité en % de la contraction maximale, une jauge et la courbe des 30 dernières secondes.",
              "Au-dessus de 75 % (60 % en mode adapté), l'alerte « Effort intense » s'allume et le téléphone vibre (et parle, si c'est réglé). Elle s'éteint sous 70 %.",
              "Pour la course et le vélo, le téléphone ajoute la distance, la vitesse et les pas. Une ceinture cardio Bluetooth peut ajouter le cœur.",
              "« Terminer la séance », répondre aux questions (fatigue, douleur, sommeil : facultatif) : le détail de la séance s'ouvre.",
            ]),
            pw.SizedBox(height: 3),
            note('Pas de réseau à la fin : la séance est gardée sur le téléphone et envoyée toute seule plus tard.'),
          ]),
        ),
        pw.SizedBox(width: 10),
        ecran(img('seance.jpg'), 'Séance en direct', largeur: 68),
      ]),
      pw.NewPage(), // la section natation commence la page 2 (pas de titre seul en bas de page)
      titre('4', 'Récupérer une séance de natation'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            note("Le prototype actuel n'est pas étanche : ces étapes se font à sec en attendant un boîtier étanche.", couleur: _rouge),
            pw.SizedBox(height: 3),
            etapes([
              "Le Bluetooth ne passe pas sous l'eau : c'est le brassard qui enregistre la séance.",
              '« Milieu aquatique », puis le sport, puis « Démarrer dans l\'eau ». Le téléphone peut ensuite rester au vestiaire.',
              "Après 5 minutes au repos (sortie de l'eau), le brassard arrête l'enregistrement tout seul : le temps passé au bord ne compte pas.",
              "Au retour, rouvrir le même écran et toucher « J'ai fini : récupérer la séance ». Si le brassard garde une séance plus ancienne, l'écran le propose.",
              "La séance n'est effacée du brassard qu'une fois enregistrée : rien n'est perdu si l'envoi échoue.",
            ]),
          ]),
        ),
        pw.SizedBox(width: 10),
        ecran(img('natation.jpg'), 'Natation', largeur: 68),
      ]),
      titre('5', 'Donner le carnet à un soignant'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: etapes([
            "« Mes séances » (icône d'horloge en haut de l'accueil), puis le bouton de partage en haut à droite.",
            "« Carnet PDF » : un résumé par semaine et par séance (intensité, efforts intenses, fatigue et douleur notées, sommeil, commentaires), à envoyer par e-mail ou à imprimer.",
            "« Tableau CSV » : les mêmes données, à ouvrir dans Excel.",
            "Toutes ses données (fichier complet) ou suppression du compte : menu du profil, « Mon compte et mes données ».",
          ]),
        ),
        pw.SizedBox(width: 10),
        ecran(img('export.jpg'), 'Exporter', largeur: 68),
      ]),
      titre('6', 'Relier sa montre (facultatif)'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            etapes([
              "Écran Brassard, partie « Bracelet podomètre » : « Rechercher un bracelet podomètre » et choisir la montre. Fermer d'abord l'application d'origine de la montre (forcer l'arrêt) : une montre n'accepte qu'une application à la fois.",
              "Pendant les séances, les pas de la montre remplacent ceux du téléphone ; sans ceinture cardio, le cœur vient de la montre. Sa batterie s'affiche sur l'accueil et pendant la séance (alerte à 15 %).",
              "Bracelet MSGM115 (« YOHO ») : « Mesurer le cœur », « Estimer la tension », « Synchroniser (sommeil) » pour la dernière nuit, « Faire vibrer », envoi du profil et rappel d'inactivité.",
              "Autre montre ou ceinture : le cœur passe si elle le diffuse en Bluetooth standard (aide par marque dans l'écran Brassard).",
            ]),
            pw.SizedBox(height: 3),
            note("La tension donnée par la montre est une estimation de son capteur optique, pas une mesure au brassard."),
          ]),
        ),
        pw.SizedBox(width: 10),
        ecran(img('montre.jpg'), 'Montre MSGM115', largeur: 76),
      ]),
      titre('7', 'En cas de problème'),
      pw.TableHelper.fromTextArray(
        headerStyle: gras,
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(5)},
        headers: ['Ce qui se passe', 'Quoi faire'].map(sur).toList(),
        data: [
          ['Le brassard ne se trouve pas', "Interrupteur allumé ? Bluetooth et localisation autorisés pour l'application ? Rapprocher le téléphone."],
          ['Intensité élevée au repos', "Électrodes décollées ou peau grasse : nettoyer, recoller. Éloigner les câbles d'un chargeur branché au secteur."],
          ['Alerte sans gros effort', 'Calibration trop faible : la refaire en serrant vraiment au maximum.'],
          ['« Signal saturé »', "Électrode décollée : la remplacer. Vérifier l'interrupteur ENV du Link Shield."],
          ['Batterie faible (sous 10 %)', "Recharger par l'USB-C, sous surveillance."],
          ['La montre ne se connecte pas', "Forcer l'arrêt de son application d'origine, puis relancer la recherche. Montre chargée et proche du téléphone."],
          ['Séance pas encore dans « Mes séances »', "Pas de réseau : elle partira toute seule. L'accueil indique les séances en attente."],
        ].map((l) => l.map(sur).toList()).toList(),
      ),
    ],
  ));

  final sortie = File('mode-emploi/mode-emploi.pdf');
  await sortie.writeAsBytes(await doc.save());
  stdout.writeln('Écrit : ${sortie.path}');
}
