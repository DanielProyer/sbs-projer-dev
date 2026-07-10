import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';

/// Erzeugt den Anlagen-Steckbrief als **einseitiges** PDF
/// (kompaktes 2-Spalten-Layout: Grunddaten + bis 4 Fotos + Bierleitungen).
class AnlagePdfService {
  static const _gruen = PdfColor.fromInt(0xFF008200);

  /// [fotos] = bereits geladene JPEG-Bytes (max 4), Reihenfolge = Anzeige.
  static Future<Uint8List> steckbrief({
    required AnlageLocal anlage,
    BetriebLocal? betrieb,
    List<Uint8List> fotos = const [],
    List<BierleitungLocal> bierleitungen = const [],
  }) async {
    final doc = pw.Document();

    String s(String? v) => (v == null || v.trim().isEmpty)
        ? '-'
        : v.replaceAll('✓', 'OK').replaceAll('–', '-').replaceAll('—', '-');
    String dt(DateTime? x) => x == null
        ? '-'
        : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
    String jn(bool b) => b ? 'Ja' : 'Nein';

    final adresse = betrieb == null
        ? ''
        : [
            [betrieb.strasse, betrieb.nr].where((e) => e != null && e.isNotEmpty).join(' '),
            [betrieb.plz, betrieb.ort].where((e) => e != null && e.isNotEmpty).join(' '),
          ].where((e) => e.isNotEmpty).join(', ');

    // Grunddaten als Label/Wert-Paare (werden auf 2 Spalten verteilt).
    final felder = <List<String>>[
      ['Bezeichnung', s(anlage.bezeichnung)],
      ['Typ Anlage', s(anlage.typAnlage)],
      ['Typ Säule', s(anlage.typSaeule)],
      ['Seriennummer', s(anlage.seriennummer)],
      ['Anzahl Hähne', anlage.anzahlHaehne.toString()],
      ['Gas-Typ 1 / 2', '${s(anlage.gasTyp1)} / ${s(anlage.gasTyp2)}'],
      ['Vorkühler', s(anlage.vorkuehler)],
      ['Durchlaufkühler', s(anlage.durchlaufkuehler)],
      ['Booster', jn(anlage.booster)],
      ['Backpython', jn(anlage.backpython)],
      ['Hauptdruck (bar)', anlage.hauptdruckBar?.toString() ?? '-'],
      ['Niederdruck', jn(anlage.hatNiederdruck)],
      ['Reinigungsrhythmus', s(anlage.reinigungRhythmus)],
      ['Letzte Reinigung', dt(anlage.letzteReinigung)],
      ['Nächste Reinigung', dt(anlage.naechsteReinigung)],
      ['Status', s(anlage.status)],
    ];
    final haelfte = (felder.length / 2).ceil();
    final linkeSpalte = felder.sublist(0, haelfte);
    final rechteSpalte = felder.sublist(haelfte);

    pw.Widget feldZeile(String label, String wert) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 92,
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
              ),
              pw.Expanded(
                child: pw.Text(wert,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        );

    pw.Widget sektion(String titel) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: _gruen,
          child: pw.Text(titel.toUpperCase(),
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
        );

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Kopf ──
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gruen, width: 2)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Anlagen-Steckbrief',
                      style: pw.TextStyle(
                          fontSize: 17, fontWeight: pw.FontWeight.bold, color: _gruen)),
                  pw.SizedBox(height: 2),
                  pw.Text(s(betrieb?.name), style: const pw.TextStyle(fontSize: 11)),
                  if (adresse.isNotEmpty)
                    pw.Text(adresse,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('SBS Projer GmbH',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Erstellt: ${dt(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ]),
              ],
            ),
          ),

          // ── Grunddaten (2 Spalten) ──
          sektion('Grunddaten'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                    children: [for (final f in linkeSpalte) feldZeile(f[0], f[1])]),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                    children: [for (final f in rechteSpalte) feldZeile(f[0], f[1])]),
              ),
            ],
          ),
          if ((anlage.notizen ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            feldZeile('Notizen', s(anlage.notizen)),
          ],

          // ── Bierleitungen ──
          if (bierleitungen.isNotEmpty) ...[
            sektion('Bierleitungen'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _gruen),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 14,
              cellAlignment: pw.Alignment.centerLeft,
              headers: const ['Nr.', 'Biersorte', 'Hahn', 'Niederdruck', 'FOB', 'Gekoppelt'],
              data: [
                for (final b in bierleitungen)
                  [
                    b.leitungsNummer.toString(),
                    s(b.biersorte),
                    s(b.hahnTyp),
                    b.niederdruckBar?.toString() ?? '-',
                    jn(b.hatFobStop),
                    jn(b.istGekoppelt),
                  ],
              ],
            ),
          ],

          // ── Fotos ──
          if (fotos.isNotEmpty) ...[
            sektion('Fotos'),
            pw.Row(
              children: [
                for (final f in fotos) ...[
                  pw.Expanded(
                    child: pw.Container(
                      height: 95,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Image(pw.MemoryImage(f), fit: pw.BoxFit.cover),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                ],
              ],
            ),
          ],

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.Text('SBS Projer GmbH · Anlagen-Steckbrief',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
        ],
      ),
    ));

    return doc.save();
  }
}
