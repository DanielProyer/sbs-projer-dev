import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/heineken_monats_daten.dart';

/// Generiert die Heineken-Monatsrechnung als PDF im exakten Original-Layout.
class HeinekenPdfService {
  // Farben
  static const _black = PdfColor.fromInt(0xFF000000);
  static const _grey = PdfColor.fromInt(0xFF555555);
  static const _heinekenGreen = PdfColor.fromInt(0xFF00843D);
  static const _heinekenRed = PdfColor.fromInt(0xFFE4002B);

  // Firmendaten
  static const _firmaName = 'SBS Projer GmbH';
  static const _firmaStrasse = 'Via Rezia 8';
  static const _firmaPlz = '7013 Domat/Ems';
  static const _mwstNr = 'CHE-413.083.919 ';
  static const _natel = '076 / 566 58 06';
  static const _email = 'sbs.projer@gmail.com';
  static const _bankName = 'Graubündner Kantonalbank';
  static const _bankOrt = '7001 Chur';
  static const _iban = 'CH66 0077 4010 3765 5060 1';

  // Heineken-Empfänger
  static const _heinekenName = 'Heineken Switzerland AG';
  static const _heinekenAbt = 'Finanz- und Rechnungswesen';
  static const _heinekenStrasse = 'Obergrundstrasse 110';
  static const _heinekenOrt = '6005 Luzern';
  static const _heinekenPo = 'PO 6100259429';
  static const _heinekenTel1 = 'Telefon 081 / 256 03 66 Lynn Meier';
  static const _heinekenTel2 = 'Telefon 081 / 256 02 55 Erika Genelin';
  static const _heinekenEmail = 'kreditoren.ch@heineken.com';

  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static final _monatFormat = DateFormat('MMMM yyyy', 'de_CH');

  /// Generiert das komplette Heineken-Monatsrechnungs-PDF.
  static Future<Uint8List> generate({
    required HeinekenMonatsDaten daten,
    String? rechnungsnummer,
  }) async {
    final pdf = pw.Document();

    // Seite 1: Übersicht
    pdf.addPage(buildUebersichtPage(daten, rechnungsnummer));

    // Seite 2+: Details
    final detailWidgets = buildDetailWidgets(daten);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
        build: (context) => detailWidgets,
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // SEITE 1: ÜBERSICHT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildUebersichtPage(
      HeinekenMonatsDaten daten, String? rechnungsnummer) {
    final rechnungsDatum = DateTime(daten.monat.year, daten.monat.month + 1, 0);
    final monatsName = _capitalize(_monatFormat.format(daten.monat));

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Heineken Logo (Text-basiert)
            _buildHeinekenLogo(),
            pw.SizedBox(height: 20),

            // Absender + Datum/RG-Nr Block
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Links: SBS Projer
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_firmaName,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(_firmaStrasse,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(_firmaPlz,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 6),
                      pw.Text('Natel-Nr.   $_natel',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Email         $_email',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                // Rechts: Datum, RG Nr, MWST
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Datum:', _dateFormat.format(rechnungsDatum)),
                    _infoRow('RG Nr.:', rechnungsnummer ?? ''),
                    _infoRow('MWST Nr.:', _mwstNr),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Rechnungsperiode + Empfänger
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Rechnung an:',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 6),
                      pw.Text(_heinekenName,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_heinekenAbt,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(_heinekenStrasse,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(_heinekenOrt,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(_heinekenPo,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text(_heinekenTel1,
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_heinekenTel2,
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_heinekenEmail,
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Rechnungsperiode',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(monatsName,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Übersicht
            pw.Text('Übersicht:',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            // 8 Kategorien
            ..._buildKategorienUebersicht(daten),

            pw.SizedBox(height: 6),
            pw.Container(height: 0.5, color: _black),
            pw.SizedBox(height: 6),

            // Total
            _uebersichtRow('Total', daten.totalNetto, bold: false),
            pw.SizedBox(height: 4),
            _uebersichtRow('Mehrwertsteur (8.1%)', daten.mwstBetrag,
                bold: false),
            pw.SizedBox(height: 6),
            _uebersichtRow(
                'GESAMTTOTAL INKL. MWST', daten.totalBrutto,
                bold: true),

            pw.Spacer(),

            // Footer
            _buildFooter(),
          ],
        );
      },
    );
  }

  static pw.Widget _buildHeinekenLogo() {
    return pw.Container(
      child: pw.Row(
        children: [
          pw.Text('★',
              style: pw.TextStyle(
                  fontSize: 18, color: _heinekenRed)),
          pw.SizedBox(width: 4),
          pw.Text('HEINEKEN',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _heinekenGreen,
                letterSpacing: 2,
              )),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildKategorienUebersicht(
      HeinekenMonatsDaten daten) {
    return daten.kategorien.map((k) {
      final (name, _, total) = k;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: _uebersichtRow(name, total),
      );
    }).toList();
  }

  static pw.Widget _uebersichtRow(String label, double betrag,
      {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
        : const pw.TextStyle(fontSize: 11);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_chf(betrag), style: style),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Die Detailangaben zu den Störungen sind den beiliegenden Rapporten zu entnehmen.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Die Rechnung ist innerhalb 30 Tagen nach Ausstelldatum zu begleichen.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 100,
              child: pw.Text('Bankverbindung:',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_bankName, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_bankOrt, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(_iban, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_firmaName, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_firmaStrasse,
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_firmaPlz, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Text('VISUM DES REGIONALEN SERVICELEITERS',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEITE 2+: DETAILS
  // ═══════════════════════════════════════════════════════════════

  static List<pw.Widget> buildDetailWidgets(HeinekenMonatsDaten daten) {
    final widgets = <pw.Widget>[];

    // Tabellen-Header
    widgets.add(_buildDetailHeader());
    widgets.add(pw.SizedBox(height: 4));

    // Pro Kategorie
    for (final (name, positionen, total) in daten.kategorien) {
      widgets.add(_buildKategorieBlock(name, positionen, total));
      widgets.add(pw.SizedBox(height: 8));
    }

    return widgets;
  }

  static pw.Widget _buildDetailHeader() {
    return pw.Row(
      children: [
        _headerCell('DATUM', 80),
        _headerCell('STÖR. NR.', 70),
        _headerCell('BEREICH', 80),
        pw.Expanded(child: _headerText('KUNDE')),
        _headerCell('BETRAG', 70, align: pw.TextAlign.right),
      ],
    );
  }

  static pw.Widget _headerCell(String text, double width,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.SizedBox(
      width: width,
      child: _headerText(text, align: align),
    );
  }

  static pw.Widget _headerText(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Text(text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: align);
  }

  static pw.Widget _buildKategorieBlock(
      String name, List<HeinekenPosition> positionen, double total) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Kategorie-Überschrift (kursiv, fett)
        pw.Text(name,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              fontStyle: pw.FontStyle.italic,
            )),
        pw.SizedBox(height: 2),

        // Zeilen
        if (positionen.isNotEmpty)
          ...positionen.map((p) => _buildDetailRow(p)),

        // Zwischensumme (rechtsbündig)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 70,
            padding: const pw.EdgeInsets.only(top: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Text(_chf(total),
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDetailRow(HeinekenPosition p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(_dateFormat.format(p.datum),
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(p.stoerNr ?? '',
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.SizedBox(
            width: 80,
            child: pw.Text(p.bereich ?? '',
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Expanded(
            child: pw.Text(p.kunde,
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(_chf(p.betrag),
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  static String _chf(double value) {
    final formatted = value.toStringAsFixed(2);
    // Schweizer Tausender-Trennzeichen
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    if (intPart.length > 3) {
      final buffer = StringBuffer();
      for (int i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) {
          buffer.write("'");
        }
        buffer.write(intPart[i]);
      }
      return '$buffer.$decPart';
    }
    return formatted;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
