import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';

/// Reine Eingabedaten für das Abschluss-PDF (keine Isar-/Provider-Abhängigkeit).
class EventAbschlussDaten {
  final String eventName;
  final String zeitraum;
  final List<({String name, String anlagenText, String inbetriebLabel})> staende;
  final int anlagenTotal;
  final int anlagenInBetrieb;
  final List<({DateTime datum, String kategorie, String? notiz, double stunden})> aufwaende;
  final List<({DateTime zeitpunkt, String beschreibung, String? material, String? standName})> einsaetze;

  const EventAbschlussDaten({
    required this.eventName,
    required this.zeitraum,
    required this.staende,
    required this.anlagenTotal,
    required this.anlagenInBetrieb,
    required this.aufwaende,
    required this.einsaetze,
  });
}

/// Baut den Event-Abschlussbericht als A4-PDF. KEINE Geldbeträge.
class EventAbschlussPdfService {
  static const _kategorieLabel = {
    'anfahrt': 'Anfahrt',
    'inbetriebnahme': 'Inbetriebnahme',
    'pikett': 'Pikettdienst',
    'spesen': 'Spesen',
  };

  static Future<Uint8List> build(EventAbschlussDaten d) async {
    final doc = pw.Document();
    final totalStunden = d.aufwaende.fold<double>(0, (s, a) => s + a.stunden);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          BerichtPdfCommon.kopf('Abschlussbericht', '${d.eventName} · ${d.zeitraum}'),
          pw.SizedBox(height: 12),
          _abschnitt('Zusammenfassung'),
          _infoZeile('Stände', '${d.staende.length}'),
          _infoZeile('Anlagen in Betrieb', '${d.anlagenInBetrieb} / ${d.anlagenTotal}'),
          _infoZeile('Einsätze', '${d.einsaetze.length}'),
          _infoZeile('Erfasste Stunden', '${totalStunden.toStringAsFixed(2)} h'),
          pw.SizedBox(height: 12),
          _abschnitt('Stände'),
          if (d.staende.isEmpty)
            _leer('Keine Stände erfasst.')
          else
            ...d.staende.map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${s.name} — ${s.anlagenText}',
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Text(s.inbetriebLabel, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
          pw.SizedBox(height: 12),
          _abschnitt('Zeit & Aufwand'),
          if (d.aufwaende.isEmpty)
            _leer('Keine Zeiten erfasst.')
          else
            ..._aufwandGruppen(d.aufwaende),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Stunden',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('${totalStunden.toStringAsFixed(2)} h',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _abschnitt('Pikett-Einsätze'),
          if (d.einsaetze.isEmpty)
            _leer('Keine Einsätze erfasst.')
          else
            _einsatzTabelle(d.einsaetze),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _abschnitt(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: BerichtPdfCommon.dunkel)),
      );

  static pw.Widget _infoZeile(String label, String wert) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(wert, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

  static pw.Widget _leer(String t) =>
      pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));

  static List<pw.Widget> _aufwandGruppen(
      List<({DateTime datum, String kategorie, String? notiz, double stunden})> aufw) {
    final widgets = <pw.Widget>[];
    for (final kat in _kategorieLabel.keys) {
      final zeilen = aufw.where((a) => a.kategorie == kat).toList()
        ..sort((a, b) => a.datum.compareTo(b.datum));
      if (zeilen.isEmpty) continue;
      final summe = zeilen.fold<double>(0, (s, a) => s + a.stunden);
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_kategorieLabel[kat]!,
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            pw.Text('${summe.toStringAsFixed(2)} h',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ));
      for (final z in zeilen) {
        final links = '${_ddMM(z.datum)}${(z.notiz != null && z.notiz!.isNotEmpty) ? ' · ${z.notiz}' : ''}';
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 0.5, bottom: 0.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(links, style: const pw.TextStyle(fontSize: 8.5))),
              pw.Text('${z.stunden.toStringAsFixed(2)} h', style: const pw.TextStyle(fontSize: 8.5)),
            ],
          ),
        ));
      }
    }
    return widgets;
  }

  static pw.Widget _einsatzTabelle(
      List<({DateTime zeitpunkt, String beschreibung, String? material, String? standName})> eins) {
    final sorted = [...eins]..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Zeitpunkt', 'Beschreibung', 'Material', 'Stand']
              .map((h) => _zelle(h, bold: true))
              .toList(),
        ),
        ...sorted.map((e) => pw.TableRow(children: [
              _zelle(_ddMMHHmm(e.zeitpunkt)),
              _zelle(e.beschreibung),
              _zelle(e.material ?? '—'),
              _zelle(e.standName ?? '—'),
            ])),
      ],
    );
  }

  static pw.Widget _zelle(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static String _zwei(int v) => v.toString().padLeft(2, '0');
  static String _ddMM(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';
  static String _ddMMHHmm(DateTime d) =>
      '${_zwei(d.day)}.${_zwei(d.month)}. ${_zwei(d.hour)}:${_zwei(d.minute)}';
}
