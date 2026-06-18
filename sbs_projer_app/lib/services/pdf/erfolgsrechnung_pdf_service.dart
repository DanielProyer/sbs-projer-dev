// lib/services/pdf/erfolgsrechnung_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
    final periode = '${df.format(z.von)} – ${df.format(z.bis)}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (context) => context.pageNumber == 1
          ? BerichtPdfCommon.kopf('Erfolgsrechnung', periode)
          : pw.SizedBox(),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text('Stufengliederung', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        BerichtPdfCommon.zeile('Nettoerlös (3)', er.nettoerloes),
        BerichtPdfCommon.zeile('− Materialaufwand (4)', -er.materialaufwand),
        BerichtPdfCommon.zeile('Bruttoergebnis 1', er.bruttoergebnis1, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Personalaufwand (5)', -er.personalaufwand),
        BerichtPdfCommon.zeile('Bruttoergebnis 2', er.bruttoergebnis2, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand),
        BerichtPdfCommon.zeile('EBITDA', er.ebitda, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Abschreibungen (6800)', -er.abschreibungen),
        BerichtPdfCommon.zeile('EBIT', er.ebit, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('± Finanzerfolg (6900)', er.finanzerfolg),
        BerichtPdfCommon.zeile('EBT (vor Steuern)', er.ebt, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('± Betriebsfremd/a.o.', er.nebenerfolg),
        BerichtPdfCommon.zeile('− Direkte Steuern (8900)', -er.steuern),
        BerichtPdfCommon.zeile('Jahresergebnis', er.jahresergebnis, bold: true, linieOben: true),
        pw.SizedBox(height: 16),
        pw.Text('Kontenklassen', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        for (final kl in konten.klassen) ...[
          pw.SizedBox(height: 4),
          BerichtPdfCommon.zeile(
              'Klasse ${kl.klasse} — ${kontenklasseBeschreibung[kl.klasse] ?? ''}', kl.summe,
              bold: true),
          for (final kt in kl.konten)
            BerichtPdfCommon.zeile('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, indent: 6),
        ],
      ],
    ));
    return pdf.save();
  }
}
