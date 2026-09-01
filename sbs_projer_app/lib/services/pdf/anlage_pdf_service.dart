import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

/// Erzeugt den Anlagen-Steckbrief als **einseitiges**, professionell gestaltetes
/// PDF (Anthrazit-Text, dezenter grüner Akzent, 2-Spalten-Grunddaten,
/// Zebra-Tabelle, 2×2-Foto-Raster).
class AnlagePdfService {
  static const _akzent = PdfColor.fromInt(0xFF008200); // Marken-Grün (dezent)
  static const _dunkel = PdfColor.fromInt(0xFF2D3748); // Anthrazit
  static const _grau = PdfColor.fromInt(0xFF718096); // Label-Grau
  static const _linie = PdfColor.fromInt(0xFFE2E8F0); // Trennlinien
  static const _zebra = PdfColor.fromInt(0xFFF7FAFC); // Zebra-Zeile

  /// [fotos] = bereits geladene JPEG-Bytes (max 4), Reihenfolge = Anzeige.
  static Future<Uint8List> steckbrief({
    required AnlageLocal anlage,
    BetriebLocal? betrieb,
    List<Uint8List> fotos = const [],
    List<BierleitungLocal> bierleitungen = const [],
  }) async {
    final doc = await pdfDokument();

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
      ['Eissäule', jn(anlage.eissaeule)],
      ['Backpython', jn(anlage.backpython)],
      ['Hauptdruck (bar)', anlage.hauptdruckBar?.toString() ?? '-'],
      ['Niederdruck', jn(anlage.hatNiederdruck)],
      ['Reinigungsrhythmus', s(anlage.reinigungRhythmus)],
      ['Letzte Reinigung', dt(anlage.letzteReinigung)],
      ['Nächste Reinigung', dt(anlage.naechsteReinigung)],
      ['Status', s(anlage.status)],
    ];
    final haelfte = (felder.length / 2).ceil();

    // Bierleitungen aufsteigend nach Leitungsnummer.
    final leitungenSortiert = [...bierleitungen]
      ..sort((x, y) => x.leitungsNummer.compareTo(y.leitungsNummer));

    // Eine Label/Wert-Zeile mit feiner Trennlinie darunter.
    pw.Widget feldZeile(String label, String wert) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _linie, width: 0.5)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 96,
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grau)),
              ),
              pw.Expanded(
                child: pw.Text(wert,
                    style: pw.TextStyle(
                        fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _dunkel)),
              ),
            ],
          ),
        );

    // Sektions-Titel: kleiner grüner Akzent-Balken + Anthrazit-Text + feine Linie.
    pw.Widget sektion(String titel) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              pw.Container(width: 3, height: 11, color: _akzent),
              pw.SizedBox(width: 6),
              pw.Text(titel.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _dunkel,
                      letterSpacing: 1.2)),
            ]),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.8, color: _linie),
          ]),
        );

    // Fotos in 2×2-Raster; die Reihen füllen den restlichen Seitenplatz
    // (Expanded) -> Fotos so gross wie möglich, aber garantiert eine Seite.
    pw.Widget fotoBox(Uint8List? b) => pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(
              border: b == null ? null : pw.Border.all(color: _linie),
              color: b == null ? null : PdfColors.grey50,
            ),
            // contain = ganzes Foto, kein Beschnitt/Verzerrung.
            child: b == null
                ? pw.SizedBox()
                : pw.Image(pw.MemoryImage(b), fit: pw.BoxFit.contain),
          ),
        );
    final fotoZeilen = <pw.Widget>[];
    for (var i = 0; i < fotos.length; i += 2) {
      fotoZeilen.add(pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [
            fotoBox(fotos[i]),
            pw.SizedBox(width: 8),
            fotoBox(i + 1 < fotos.length ? fotos[i + 1] : null),
          ]),
        ),
      ));
    }

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Kopf ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Anlagen-Steckbrief',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold, color: _dunkel)),
                pw.SizedBox(height: 3),
                pw.Text(s(betrieb?.name),
                    style: pw.TextStyle(fontSize: 11, color: _dunkel)),
                if (adresse.isNotEmpty)
                  pw.Text(adresse, style: const pw.TextStyle(fontSize: 9, color: _grau)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('SBS Projer GmbH',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold, color: _dunkel)),
                pw.SizedBox(height: 2),
                pw.Text('Erstellt: ${dt(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: _grau)),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: _akzent),

          // ── Grunddaten (2 Spalten) ──
          sektion('Grunddaten'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(children: [
                  for (final f in felder.sublist(0, haelfte)) feldZeile(f[0], f[1])
                ]),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(children: [
                  for (final f in felder.sublist(haelfte)) feldZeile(f[0], f[1])
                ]),
              ),
            ],
          ),
          if ((anlage.notizen ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            feldZeile('Notizen', s(anlage.notizen)),
          ],

          // ── Bierleitungen ──
          if (bierleitungen.isNotEmpty) ...[
            sektion('Bierleitungen'),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: _linie, width: 0.5),
              headerStyle: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: _dunkel),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDF2F7)),
              headerHeight: 16,
              cellStyle: const pw.TextStyle(fontSize: 8, color: _dunkel),
              cellHeight: 15,
              oddRowDecoration: const pw.BoxDecoration(color: _zebra),
              cellAlignments: const {
                0: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
              cellAlignment: pw.Alignment.centerLeft,
              headers: const ['Nr.', 'Biersorte', 'Hahn', 'Niederdruck', 'FOB', 'Gekoppelt'],
              data: [
                for (final b in leitungenSortiert)
                  [
                    b.leitungsNummer.toString(),
                    s(b.biersorte),
                    s(b.hahnTyp),
                    b.niederdruckBar != null
                        ? b.niederdruckBar!.toStringAsFixed(1)
                        : '-',
                    jn(b.hatFobStop),
                    jn(b.istGekoppelt),
                  ],
              ],
            ),
          ],

          // ── Fotos (2×2, füllen den restlichen Seitenplatz) ──
          if (fotoZeilen.isNotEmpty) ...[
            sektion('Fotos'),
            pw.Expanded(child: pw.Column(children: fotoZeilen)),
          ] else
            pw.Spacer(),

          pw.SizedBox(height: 6),
          pw.Container(height: 0.8, color: _linie),
          pw.SizedBox(height: 4),
          pw.Text('SBS Projer GmbH · Anlagen-Steckbrief · ${dt(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: _grau)),
        ],
      ),
    ));

    return doc.save();
  }
}
