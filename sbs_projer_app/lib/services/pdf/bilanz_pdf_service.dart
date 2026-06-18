// lib/services/pdf/bilanz_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';

class BilanzPdfService {
  static Future<Uint8List> generate(BilanzDaten b, DateTime stichtag) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');

    pw.Widget seite(String titel, List<BilanzGruppe> gruppen, double total) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final g in gruppen) ...[
              pw.Text(g.titel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              for (final p in g.posten)
                BerichtPdfCommon.zeile('${p.kontonummer}  ${p.bezeichnung}', p.summe, indent: 6),
              BerichtPdfCommon.zeile('Total ${g.titel}', g.summe, bold: true, linieOben: true),
              pw.SizedBox(height: 4),
            ],
            BerichtPdfCommon.zeile('Total $titel', total, bold: true, linieOben: true),
          ],
        );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          BerichtPdfCommon.kopf('Bilanz', 'per ${df.format(stichtag)}'),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: seite('Aktiven', b.aktiven, b.totalAktiven)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: seite('Passiven', b.passiven, b.totalPassiven)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          BerichtPdfCommon.zeile(
            b.differenz.abs() < 0.005 ? 'Aktiven = Passiven' : 'Differenz',
            b.differenz,
            bold: true,
          ),
        ],
      ),
    ));
    return pdf.save();
  }
}
