import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';

class LohnausweisPdfService {
  static const _grey = PdfColor.fromInt(0xFF666666);

  static Future<Uint8List> generate(
    LohnEinstellungen einst,
    Map<String, double> totale,
    int jahr,
  ) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');

    final brutto = totale['brutto'] ?? 0;
    final ahvAn = totale['ahv_an'] ?? 0;
    final alvAn = totale['alv_an'] ?? 0;
    final nbuAn = totale['nbu_an'] ?? 0;
    final bvgAn = totale['bvg_an'] ?? 0;
    final ktgAn = totale['ktg_an'] ?? 0;
    final totalAnAbzuege = totale['total_an_abzuege'] ?? 0;
    final netto = totale['netto'] ?? 0;
    final ahvAg = totale['ahv_ag'] ?? 0;
    final alvAg = totale['alv_ag'] ?? 0;
    final buAg = totale['bu_ag'] ?? 0;
    final fakAg = totale['fak_ag'] ?? 0;
    final bvgAg = totale['bvg_ag'] ?? 0;
    final ktgAg = totale['ktg_ag'] ?? 0;
    final anzahlAuszahlungen = (totale['anzahl_auszahlungen'] ?? 0).toInt();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text('Lohnausweis $jahr',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text(
                    'Formular 11 (vereinfacht)',
                    style: const pw.TextStyle(fontSize: 10, color: _grey)),
              ),
              pw.SizedBox(height: 20),

              // Arbeitgeber
              _sectionTitle('Arbeitgeber'),
              _infoRow('Name', einst.arbeitgeberName ?? 'SBS Projer GmbH'),
              if (einst.arbeitgeberAdresse != null)
                _infoRow('Adresse', einst.arbeitgeberAdresse!),
              if (einst.arbeitgeberPlzOrt != null)
                _infoRow('PLZ / Ort', einst.arbeitgeberPlzOrt!),
              pw.SizedBox(height: 12),

              // Arbeitnehmer
              _sectionTitle('Arbeitnehmer/in'),
              _infoRow('Name',
                  '${einst.arbeitnehmerName ?? ''} ${einst.arbeitnehmerVorname ?? ''}'.trim()),
              if (einst.arbeitnehmerAdresse != null)
                _infoRow('Adresse', einst.arbeitnehmerAdresse!),
              if (einst.arbeitnehmerPlzOrt != null)
                _infoRow('PLZ / Ort', einst.arbeitnehmerPlzOrt!),
              if (einst.arbeitnehmerAhvNr != null)
                _infoRow('AHV-Nr.', einst.arbeitnehmerAhvNr!),
              if (einst.arbeitnehmerGeburtsdatum != null)
                _infoRow('Geburtsdatum',
                    df.format(einst.arbeitnehmerGeburtsdatum!)),
              _infoRow('Beschäftigungsperiode',
                  '01.01.$jahr – 31.12.$jahr ($anzahlAuszahlungen Monate)'),
              pw.SizedBox(height: 16),

              // Lohn
              _sectionTitle('Lohn und Abzüge'),
              pw.SizedBox(height: 4),
              _table([
                ['Pos.', 'Bezeichnung', 'Betrag CHF'],
                ['1', 'Bruttolohn (${anzahlAuszahlungen}x ${einst.bruttolohnMonatlich.toStringAsFixed(2)})', _chf(brutto)],
                ['', '', ''],
                ['', 'Abzüge Arbeitnehmer:', ''],
                ['2', 'AHV/IV/EO ${einst.ahvIvEoAnSatz}%', '– ${_chf(ahvAn)}'],
                ['3', 'ALV ${einst.alvAnSatz}%', '– ${_chf(alvAn)}'],
                ['4', 'NBU ${einst.nbuAnSatz}%', '– ${_chf(nbuAn)}'],
                if (bvgAn > 0)
                  ['5', 'BVG AN (${einst.bvgAnBetrag.toStringAsFixed(2)}/Mt)', '– ${_chf(bvgAn)}'],
                if (ktgAn > 0)
                  ['6', 'KTG ${einst.ktgAnSatz}%', '– ${_chf(ktgAn)}'],
                ['', 'Total Abzüge AN', '– ${_chf(totalAnAbzuege)}'],
                ['', '', ''],
                ['7', 'Nettolohn', _chf(netto)],
              ]),
              pw.SizedBox(height: 16),

              // AG-Beiträge
              _sectionTitle('Arbeitgeberbeiträge (informativ)'),
              pw.SizedBox(height: 4),
              _table([
                ['Pos.', 'Bezeichnung', 'Betrag CHF'],
                ['8', 'AHV/IV/EO AG ${einst.ahvIvEoAgSatz}%', _chf(ahvAg)],
                ['9', 'ALV AG ${einst.alvAgSatz}%', _chf(alvAg)],
                ['10', 'BU/UVG AG ${einst.buAgSatz}%', _chf(buAg)],
                ['11', 'FAK AG ${einst.fakAgSatz}%', _chf(fakAg)],
                if (bvgAg > 0)
                  ['12', 'BVG AG (${einst.bvgAgBetrag.toStringAsFixed(2)}/Mt)', _chf(bvgAg)],
                if (ktgAg > 0)
                  ['13', 'KTG AG ${einst.ktgAgSatz}%', _chf(ktgAg)],
              ]),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Ort, Datum',
                          style: const pw.TextStyle(fontSize: 9, color: _grey)),
                      pw.SizedBox(height: 20),
                      pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(width: 0.5)))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Unterschrift Arbeitgeber',
                          style: const pw.TextStyle(fontSize: 9, color: _grey)),
                      pw.SizedBox(height: 20),
                      pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(width: 0.5)))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: _grey)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _table(List<List<String>> rows) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(35),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(100),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        final isHeader = i == 0;
        return pw.TableRow(
          decoration: isHeader
              ? const pw.BoxDecoration(color: PdfColors.grey100)
              : null,
          children: row.map((cell) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              child: pw.Text(cell,
                  style: pw.TextStyle(
                    fontSize: isHeader ? 9 : 10,
                    fontWeight:
                        isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                  textAlign: row.indexOf(cell) == 2
                      ? pw.TextAlign.right
                      : pw.TextAlign.left),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static String _chf(double betrag) {
    return betrag.toStringAsFixed(2);
  }
}
