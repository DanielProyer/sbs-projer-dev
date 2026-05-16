import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

class BestellungPdfService {
  static const _heinekenGreen = PdfColor.fromInt(0xFF00843D);
  static const _darkGrey = PdfColor.fromInt(0xFF333333);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const _lineGrey = PdfColor.fromInt(0xFFDDDDDD);

  static const _firmaName = 'SBS Projer GmbH';
  static const _firmaStrasse = 'Via Rezia 8';
  static const _firmaOrt = '7013 Domat/Ems';
  static const _firmaTel = '076 566 58 06';
  static const _firmaEmail = 'sbs.projer@gmail.com';

  static final _dateFormat = DateFormat('dd.MM.yyyy');

  static Future<Uint8List> generate({
    required MaterialBestellung bestellung,
    required List<MaterialBestellposition> positionen,
  }) async {
    final pdf = pw.Document();

    final verbrauch = positionen
        .where((p) => p.kategorieName == 'Verbrauchsmaterial')
        .toList();
    final reinigung = positionen
        .where((p) => p.kategorieName == 'Reinigungsmaterial')
        .toList();
    final sonstige = positionen
        .where((p) =>
            p.kategorieName != 'Verbrauchsmaterial' &&
            p.kategorieName != 'Reinigungsmaterial')
        .toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(bestellung),
              pw.SizedBox(height: 24),
              _buildEmpfaenger(bestellung),
              pw.SizedBox(height: 24),
              _buildBestellInfo(bestellung),
              pw.SizedBox(height: 20),
              if (reinigung.isNotEmpty) ...[
                _buildSektionHeader('Reinigungsmaterial'),
                pw.SizedBox(height: 6),
                _buildPositionenTabelle(reinigung),
                pw.SizedBox(height: 16),
              ],
              if (verbrauch.isNotEmpty) ...[
                _buildSektionHeader('Verbrauchsmaterial'),
                pw.SizedBox(height: 6),
                _buildPositionenTabelle(verbrauch),
                pw.SizedBox(height: 16),
              ],
              if (sonstige.isNotEmpty) ...[
                _buildSektionHeader('Weitere Artikel'),
                pw.SizedBox(height: 6),
                _buildPositionenTabelle(sonstige),
                pw.SizedBox(height: 16),
              ],
              pw.SizedBox(height: 8),
              _buildSummary(positionen),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(MaterialBestellung bestellung) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_firmaName,
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _heinekenGreen)),
            pw.SizedBox(height: 2),
            pw.Text('$_firmaStrasse, $_firmaOrt',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text('$_firmaTel  |  $_firmaEmail',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _heinekenGreen,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('MATERIALBESTELLUNG',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text(bestellung.bestellNr,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.white)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildEmpfaenger(MaterialBestellung bestellung) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lineGrey),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text('An:',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGrey)),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (bestellung.empfaengerName != null)
                pw.Text(bestellung.empfaengerName!,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (bestellung.empfaengerEmail != null)
                pw.Text(bestellung.empfaengerEmail!,
                    style: const pw.TextStyle(fontSize: 10, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBestellInfo(MaterialBestellung bestellung) {
    return pw.Row(
      children: [
        _infoBlock('Bestelldatum', _dateFormat.format(bestellung.datum)),
        pw.SizedBox(width: 40),
        _infoBlock('Bestell-Nr.', bestellung.bestellNr),
      ],
    );
  }

  static pw.Widget _infoBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _grey)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildSektionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _heinekenGreen,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  static pw.Widget _buildPositionenTabelle(List<MaterialBestellposition> pos) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(50),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _lineGrey, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightGrey),
          children: [
            _headerCell('DBO-Nr.'),
            _headerCell('Artikel'),
            _headerCell('Menge', align: pw.Alignment.centerRight),
            _headerCell('Einheit'),
          ],
        ),
        ...pos.map((p) => pw.TableRow(
              children: [
                _dataCell(p.dboNr ?? '-'),
                _dataCell(p.name),
                _dataCell(p.menge.toStringAsFixed(0),
                    align: pw.Alignment.centerRight,
                    bold: true),
                _dataCell(p.einheit),
              ],
            )),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {pw.Alignment? align}) {
    return pw.Container(
      alignment: align ?? pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkGrey)),
    );
  }

  static pw.Widget _dataCell(String text,
      {pw.Alignment? align, bool bold = false}) {
    return pw.Container(
      alignment: align ?? pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : null)),
    );
  }

  static pw.Widget _buildSummary(List<MaterialBestellposition> positionen) {
    final total = positionen.fold<double>(0, (s, p) => s + p.menge);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Positionen: ${positionen.length}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Menge: ${total.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _heinekenGreen, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_firmaName,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _heinekenGreen)),
          pw.Text('$_firmaStrasse, $_firmaOrt',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text('$_firmaTel  |  $_firmaEmail',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    );
  }
}
