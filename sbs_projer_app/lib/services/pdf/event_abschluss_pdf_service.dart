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
    final jetzt = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Erstellt am ${_ddMMyyyy(jetzt)}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Seite ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (context) => [
          BerichtPdfCommon.kopf('Abschlussbericht', _s('${d.eventName} · ${d.zeitraum}')),
          pw.SizedBox(height: 16),

          ..._kategorie(
            'Zusammenfassung',
            _summaryGrid([
              ('Stände', '${d.staende.length}'),
              ('Anlagen in Betrieb', '${d.anlagenInBetrieb} / ${d.anlagenTotal}'),
              ('Einsätze', '${d.einsaetze.length}'),
              ('Erfasste Stunden', '${totalStunden.toStringAsFixed(2)} h'),
            ]),
            zeilen: 2,
          ),
          pw.SizedBox(height: 16),

          ..._kategorie(
            'Stände',
            d.staende.isEmpty
                ? _leer('Keine Stände erfasst.')
                : _staendeTabelle(d.staende),
            zeilen: d.staende.length,
          ),
          pw.SizedBox(height: 16),

          ..._kategorie(
            'Zeit & Aufwand',
            d.aufwaende.isEmpty
                ? _leer('Keine Zeiten erfasst.')
                : pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      ..._aufwandGruppen(d.aufwaende),
                      pw.SizedBox(height: 6),
                      _totalRow('Total Stunden',
                          '${totalStunden.toStringAsFixed(2)} h'),
                    ],
                  ),
            zeilen: d.aufwaende.length + 4,
          ),
          pw.SizedBox(height: 16),

          ..._kategorie(
            'Pikett-Einsätze',
            d.einsaetze.isEmpty
                ? _leer('Keine Einsätze erfasst.')
                : _einsatzTabelle(d.einsaetze),
            zeilen: d.einsaetze.length,
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ── Bausteine ──────────────────────────────────────────────

  /// Hält eine Kategorie (Titel + Inhalt) auf EINER Seite zusammen: Passt
  /// sie nicht mehr auf die aktuelle Seite, rutscht sie KOMPLETT auf die
  /// nächste (Regel Daniel 26.07.2026 — kein Umbruch mitten in z. B. den
  /// Pikett-Einsätzen). Braucht zwingend [_BlockOhneUmbruch]: pw.Column ist
  /// ein SpanningWidget, und pw.Container/StatelessWidget DELEGIEREN canSpan
  /// ans Kind (widget.dart:271) — beide Wrapper wurden von MultiPage
  /// weiterhin zwischen Titel und Tabelle gesplittet (zwei Fehlversuche am
  /// 26.07.). Nur überlange Kategorien (> [maxZeilen] Einträge, mehr als
  /// eine Seite) bleiben teilbar — ein unteilbarer Block höher als eine
  /// Seite würde «Widget won't fit» werfen.
  static List<pw.Widget> _kategorie(String titel, pw.Widget inhalt,
      {required int zeilen, int maxZeilen = 20}) {
    if (zeilen > maxZeilen) {
      return [_sectionHeader(titel), pw.SizedBox(height: 6), inhalt];
    }
    return [
      _BlockOhneUmbruch(
        kind: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionHeader(titel),
            pw.SizedBox(height: 6),
            inhalt,
          ],
        ),
      ),
    ];
  }

  static pw.Widget _sectionHeader(String t) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: BerichtPdfCommon.dunkel,
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      );

  static pw.Widget _summaryGrid(List<(String, String)> items) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(pw.Row(children: [
        pw.Expanded(child: _kv(left.$1, left.$2)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: right == null ? pw.SizedBox() : _kv(right.$1, right.$2)),
      ]));
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(children: rows),
    );
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_s(k), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(_s(v), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _leer(String t) => pw.Text(_s(t),
      style: pw.TextStyle(
          fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic));

  static pw.Widget _totalRow(String label, String wert) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            pw.Text(wert, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _staendeTabelle(
      List<({String name, String anlagenText, String inbetriebLabel})> staende) {
    return _tabelle(
      ['Stand', 'Anlagen', 'Inbetriebnahme'],
      const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3.2),
        2: pw.FlexColumnWidth(1.6),
      },
      [
        for (final s in staende) [_s(s.name), _s(s.anlagenText), _s(s.inbetriebLabel)],
      ],
    );
  }

  static List<pw.Widget> _aufwandGruppen(
      List<({DateTime datum, String kategorie, String? notiz, double stunden})> aufw) {
    final widgets = <pw.Widget>[];
    for (final kat in _kategorieLabel.keys) {
      final zeilen = aufw.where((a) => a.kategorie == kat).toList()
        ..sort((a, b) => a.datum.compareTo(b.datum));
      if (zeilen.isEmpty) continue;
      final summe = zeilen.fold<double>(0, (s, a) => s + a.stunden);
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
        child: pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: BerichtPdfCommon.dunkel, width: 0.8)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_kategorieLabel[kat]!,
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: BerichtPdfCommon.dunkel)),
              pw.Text('${summe.toStringAsFixed(2)} h',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ));
      for (final z in zeilen) {
        final links =
            '${_ddMM(z.datum)}${(z.notiz != null && z.notiz!.isNotEmpty) ? ' · ${z.notiz}' : ''}';
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 1, bottom: 1),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(_s(links), style: const pw.TextStyle(fontSize: 8.5))),
              pw.Text('${z.stunden.toStringAsFixed(2)} h',
                  style: const pw.TextStyle(fontSize: 8.5)),
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
    return _tabelle(
      ['Zeitpunkt', 'Beschreibung', 'Material', 'Stand'],
      const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.6),
      },
      [
        for (final e in sorted)
          [_ddMMHHmm(e.zeitpunkt), _s(e.beschreibung), _s(e.material ?? '-'), _s(e.standName ?? '-')],
      ],
    );
  }

  /// Generische Tabelle mit dunkler Kopfzeile (weiss) + Zebra-Zeilen.
  static pw.Widget _tabelle(
      List<String> header, Map<int, pw.TableColumnWidth> widths, List<List<String>> rows) {
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: BerichtPdfCommon.dunkel),
          children: [for (final h in header) _zelle(h, bold: true, color: PdfColors.white)],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : PdfColors.grey100),
            children: [for (final c in rows[i]) _zelle(c)],
          ),
      ],
    );
  }

  static pw.Widget _zelle(String t, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  /// Ersetzt Zeichen, die die Standard-Helvetica im pdf-Paket nicht rendert.
  static String _s(String t) => t
      .replaceAll('✓', 'OK')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('‹', '<')
      .replaceAll('›', '>');

  static String _zwei(int v) => v.toString().padLeft(2, '0');
  static String _ddMM(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';
  static String _ddMMyyyy(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';
  static String _ddMMHHmm(DateTime d) =>
      '${_zwei(d.day)}.${_zwei(d.month)}. ${_zwei(d.hour)}:${_zwei(d.minute)}';
}

/// Block, den MultiPage NIE über Seiten splitten darf: `canSpan` ist hart
/// `false` — StatelessWidget würde es sonst ans (spannende) Column-Kind
/// delegieren. MultiPage verschiebt den Block dadurch als Ganzes auf die
/// nächste Seite (multi_page.dart:338).
class _BlockOhneUmbruch extends pw.StatelessWidget {
  _BlockOhneUmbruch({required this.kind});

  final pw.Widget kind;

  @override
  bool get canSpan => false;

  @override
  pw.Widget build(pw.Context context) => kind;
}
