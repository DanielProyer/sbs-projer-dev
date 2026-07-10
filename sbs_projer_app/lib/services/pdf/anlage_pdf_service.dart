import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';

/// Erzeugt den Anlagen-Steckbrief als PDF (Grunddaten + bis 4 Fotos + Bierleitungen).
class AnlagePdfService {
  /// [fotos] = bereits geladene JPEG-Bytes (max 4), Reihenfolge = Anzeige.
  static Future<Uint8List> steckbrief({
    required AnlageLocal anlage,
    BetriebLocal? betrieb,
    List<Uint8List> fotos = const [],
    List<BierleitungLocal> bierleitungen = const [],
  }) async {
    final doc = pw.Document();
    final gruen = PdfColor.fromInt(0xFF008200);

    String s(String? v) => (v == null || v.trim().isEmpty)
        ? '-'
        : v.replaceAll('✓', 'OK').replaceAll('–', '-').replaceAll('—', '-');
    String d(DateTime? x) => x == null
        ? '-'
        : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
    String jn(bool b) => b ? 'Ja' : 'Nein';

    final adresse = betrieb == null
        ? ''
        : [
            [betrieb.strasse, betrieb.nr]
                .where((e) => e != null && e.isNotEmpty)
                .join(' '),
            [betrieb.plz, betrieb.ort]
                .where((e) => e != null && e.isNotEmpty)
                .join(' '),
          ].where((e) => e.isNotEmpty).join(', ');

    pw.Widget zeile(String label, String wert) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 150,
                child: pw.Text(label,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700))),
            pw.Expanded(
                child: pw.Text(wert,
                    style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    pw.Widget header(String t) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: gruen,
          child: pw.Text(t,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SBS Projer GmbH',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
      build: (ctx) => [
        pw.Text('Anlagen-Steckbrief',
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: gruen)),
        pw.SizedBox(height: 2),
        pw.Text(s(betrieb?.name), style: const pw.TextStyle(fontSize: 12)),
        if (adresse.isNotEmpty)
          pw.Text(adresse,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text('Erstellt: ${d(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),

        header('Grunddaten'),
        zeile('Bezeichnung', s(anlage.bezeichnung)),
        zeile('Typ Anlage', s(anlage.typAnlage)),
        zeile('Typ Säule', s(anlage.typSaeule)),
        zeile('Seriennummer', s(anlage.seriennummer)),
        zeile('Anzahl Hähne', anlage.anzahlHaehne.toString()),
        zeile('Gas-Typ 1 / 2', '${s(anlage.gasTyp1)} / ${s(anlage.gasTyp2)}'),
        zeile('Vorkühler', s(anlage.vorkuehler)),
        zeile('Durchlaufkühler', s(anlage.durchlaufkuehler)),
        zeile('Booster / Backpython',
            '${jn(anlage.booster)} / ${jn(anlage.backpython)}'),
        zeile('Hauptdruck (bar)', anlage.hauptdruckBar?.toString() ?? '-'),
        zeile('Niederdruck', jn(anlage.hatNiederdruck)),
        zeile('Reinigungsrhythmus', s(anlage.reinigungRhythmus)),
        zeile('Letzte / nächste Reinigung',
            '${d(anlage.letzteReinigung)} / ${d(anlage.naechsteReinigung)}'),
        zeile('Status', s(anlage.status)),
        if ((anlage.notizen ?? '').trim().isNotEmpty)
          zeile('Notizen', s(anlage.notizen)),

        if (bierleitungen.isNotEmpty) ...[
          header('Bierleitungen'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: gruen),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headers: [
              'Nr.',
              'Biersorte',
              'Hahn',
              'Niederdruck',
              'FOB',
              'Gekoppelt'
            ],
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

        if (fotos.isNotEmpty) ...[
          header('Fotos'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in fotos)
                pw.Container(
                  width: 240,
                  height: 180,
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Image(pw.MemoryImage(f), fit: pw.BoxFit.cover),
                ),
            ],
          ),
        ],
      ],
    ));

    return doc.save();
  }
}
