// lib/services/pdf/erfolgsrechnung_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart' show Zeitraum;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';

class ErfolgsrechnungPdfService {
  static Future<Uint8List> generate(
    ErfolgsrechnungDaten er,
    ErKontenAufstellung konten,
    Zeitraum z,
  ) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');
    final periode = '${df.format(z.von)} - ${df.format(z.bis)}';

    // Hauptübersicht-Zeile (grösser) bzw. Zwischenergebnis (fett mit Linie).
    pw.Widget pos(String l, double v) => BerichtPdfCommon.zeile(l, v, fontSize: 11);
    pw.Widget sub(String l, double v) =>
        BerichtPdfCommon.zeile(l, v, bold: true, linieOben: true, fontSize: 11);

    // === Seite 1: Hauptübersicht (Stufengliederung) ===
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          BerichtPdfCommon.kopf('Erfolgsrechnung', periode),
          pw.SizedBox(height: 24),
          pos('Nettoerlös (3)', er.nettoerloes),
          pos('- Materialaufwand (4)', -er.materialaufwand),
          sub('Bruttoergebnis 1', er.bruttoergebnis1),
          pos('- Personalaufwand (5)', -er.personalaufwand),
          sub('Bruttoergebnis 2', er.bruttoergebnis2),
          pos('- Übriger Aufwand (6000-6799)', -er.uebrigerAufwand),
          sub('EBITDA', er.ebitda),
          pos('- Abschreibungen (6800)', -er.abschreibungen),
          sub('EBIT', er.ebit),
          pos('+/- Finanzerfolg (6900)', er.finanzerfolg),
          sub('EBT (vor Steuern)', er.ebt),
          pos('+/- Betriebsfremd / a.o. (7 / 8000-8800)', er.nebenerfolg),
          pos('- Direkte Steuern (8900)', -er.steuern),
          pw.SizedBox(height: 10),
          // Jahresergebnis hervorgehoben
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEFF3F7),
              border: pw.Border(
                top: pw.BorderSide(width: 1.4, color: BerichtPdfCommon.dunkel),
                bottom: pw.BorderSide(width: 1.4, color: BerichtPdfCommon.dunkel),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Jahresergebnis',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${chf(er.jahresergebnis)} CHF',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ));

    // === Seite 2+: Kontenklassen (Detail) ===
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        BerichtPdfCommon.kopf('Erfolgsrechnung - Kontenklassen', periode),
        pw.SizedBox(height: 16),
        for (final kl in konten.klassen) ...[
          pw.SizedBox(height: 8),
          BerichtPdfCommon.zeile(
            'Klasse ${kl.klasse} - ${kontenklasseBeschreibungDetail[kl.klasse] ?? ''}',
            kl.summe,
            bold: true,
            fontSize: 10,
          ),
          for (final kt in kl.konten)
            BerichtPdfCommon.zeile('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, indent: 8),
        ],
      ],
    ));

    return pdf.save();
  }
}
