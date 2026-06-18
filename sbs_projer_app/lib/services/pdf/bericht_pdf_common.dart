// lib/services/pdf/bericht_pdf_common.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/chf_format.dart';

class BerichtPdfCommon {
  static const firma = 'SBS Projer GmbH';
  static const strasse = 'Via Rezia 8';
  static const ort = '7013 Domat/Ems';
  static const dunkel = PdfColor.fromInt(0xFF1A3A5C);

  static pw.Widget kopf(String titel, String periode,
          {String? firmaName, String? firmaStrasse, String? firmaOrt, String? mwstZeile}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(firmaName ?? firma,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dunkel)),
                pw.Text(firmaStrasse ?? strasse, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(firmaOrt ?? ort, style: const pw.TextStyle(fontSize: 9)),
                if (mwstZeile != null && mwstZeile.isNotEmpty)
                  pw.Text(mwstZeile, style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(titel, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(periode, style: const pw.TextStyle(fontSize: 10)),
              ]),
            ],
          ),
          pw.Divider(color: dunkel, thickness: 1.5),
        ],
      );

  /// Betrags-Zeile (Label links, CHF rechts), optional fett / Linie oben.
  static pw.Widget zeile(String label, double betrag,
          {bool bold = false,
          bool linieOben = false,
          double indent = 0,
          double fontSize = 9}) =>
      pw.Container(
        decoration: linieOben
            ? const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))
            : null,
        padding: pw.EdgeInsets.symmetric(vertical: fontSize * 0.28),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Padding(
                padding: pw.EdgeInsets.only(left: indent),
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              ),
            ),
            pw.Text(chf(betrag),
                style: pw.TextStyle(
                    fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
}
