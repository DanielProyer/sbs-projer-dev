import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generiert die 6 Heineken-Rapport-Formulare als PDFs.
///
/// Templates basierend auf den F_-Sheets der Hauptexcel:
/// 1. F_Störung        → Störungsrapport
/// 2. F_Eigenauftrag   → Eigenauftrag-Rapport
/// 3. F_EE_Reinigung   → Eröffnungs-/Endreinigung-Rapport
/// 4. F_Montage        → Montage-Rapport
/// 5. F_Pikett         → Pikett-Rapport
/// 6. F_Pauschale      → Anfahrtspauschale-Rapport
class HeinekenRapportService {
  // ─── Konstanten ───
  static const _firmaName = 'SBS Projer GmbH';
  static const _black = PdfColor.fromInt(0xFF000000);
  static const _grey = PdfColor.fromInt(0xFF555555);

  static final _dateFormat = DateFormat('dd.MM.yyyy');

  // ═══════════════════════════════════════════════════════════════
  // 1. STÖRUNGSRAPPORT (F_Störung)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildStoerungPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    int? stoerungBereich,
    String? serienNrKuehler,
    String? uhrzeitStart,
    bool istPikettEinsatz = false,
    bool istBergkunde = false,
    int anfahrtKm = 0,
    double? preisBasis,
    double? preisAnfahrt,
    double? preisWochenende,
    double? komplexitaetZuschlag,
    double? preisNetto,
    List<(String name, double menge)> materialien = const [],
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader('Störung'),

              pw.SizedBox(height: 12),
              // Referenz-Nr + Bergkunde
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(referenzNr,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      'Bergrestaurant: ${istBergkunde ? "Ja" : "Nein"}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 12),

              // Kundendaten
              _labelValue('Kunde / Rest.', kunde),
              _labelValue('PLZ / Ort', ort),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue(
                        'Störungs Nr. / Datum',
                        '$stoerungsnummer   ${_dateFormat.format(datum)}'),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              if (serienNrKuehler != null)
                _labelValue('Seriennummer Kühler', serienNrKuehler),
              if (uhrzeitStart != null)
                _labelValue('Zeit der Störungsmeldung', uhrzeitStart),
              pw.SizedBox(height: 12),

              // Bereich Checkboxen
              _buildBereichCheckboxes(stoerungBereich),
              pw.SizedBox(height: 12),

              // Material
              _buildMaterialTabelle(materialien),
              pw.SizedBox(height: 12),

              // Störungspositionen (6 Bereiche)
              _buildStoerungsPositionen(stoerungBereich, preisBasis),
              pw.SizedBox(height: 8),

              // Anfahrt
              _buildAnfahrt(anfahrtKm, preisAnfahrt),
              pw.SizedBox(height: 8),

              // Pikett falls zutreffend
              if (istPikettEinsatz) ...[
                _buildPikettZeile(preisWochenende),
                pw.SizedBox(height: 8),
              ],

              pw.Spacer(),

              // Total
              _buildTotalZeile(preisNetto ?? 0),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generateStoerung({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    int? stoerungBereich,
    String? serienNrKuehler,
    String? uhrzeitStart,
    bool istPikettEinsatz = false,
    bool istBergkunde = false,
    int anfahrtKm = 0,
    double? preisBasis,
    double? preisAnfahrt,
    double? preisWochenende,
    double? komplexitaetZuschlag,
    double? preisNetto,
    List<(String name, double menge)> materialien = const [],
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildStoerungPage(
      referenzNr: referenzNr,
      stoerungsnummer: stoerungsnummer,
      datum: datum,
      kunde: kunde,
      ort: ort,
      stoerungBereich: stoerungBereich,
      serienNrKuehler: serienNrKuehler,
      uhrzeitStart: uhrzeitStart,
      istPikettEinsatz: istPikettEinsatz,
      istBergkunde: istBergkunde,
      anfahrtKm: anfahrtKm,
      preisBasis: preisBasis,
      preisAnfahrt: preisAnfahrt,
      preisWochenende: preisWochenende,
      komplexitaetZuschlag: komplexitaetZuschlag,
      preisNetto: preisNetto,
      materialien: materialien,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. EIGENAUFTRAG-RAPPORT (F_Eigenauftrag)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildEigenauftragPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    required String problemBeschreibung,
    String? loesungBeschreibung,
    double? pauschale,
    List<(String name, double menge)> materialien = const [],
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('Eigener Auftrag'),
              pw.SizedBox(height: 12),

              pw.Text(referenzNr,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),

              _labelValue('Kunde / Rest.', kunde),
              _labelValue('PLZ / Ort', ort),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue(
                        'Störungs Nr. / Datum',
                        '$stoerungsnummer   ${_dateFormat.format(datum)}'),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Material
              _buildMaterialTabelle(materialien),
              pw.SizedBox(height: 16),

              // Umschreibung der Arbeit
              pw.Text('Umschreibung der Arbeit',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Text(
                  problemBeschreibung +
                      (loesungBeschreibung != null
                          ? '\n\n$loesungBeschreibung'
                          : ''),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 16),

              // Eigenauftrag-Position
              _buildPositionsZeile(
                  'Eigener Auftrag', 1, pauschale ?? 0, pauschale ?? 0),

              pw.Spacer(),
              _buildTotalZeile(pauschale ?? 0),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generateEigenauftrag({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    required String problemBeschreibung,
    String? loesungBeschreibung,
    double? pauschale,
    List<(String name, double menge)> materialien = const [],
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildEigenauftragPage(
      referenzNr: referenzNr,
      stoerungsnummer: stoerungsnummer,
      datum: datum,
      kunde: kunde,
      ort: ort,
      problemBeschreibung: problemBeschreibung,
      loesungBeschreibung: loesungBeschreibung,
      pauschale: pauschale,
      materialien: materialien,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. EE-REINIGUNG-RAPPORT (F_EE_Reinigung)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildEEReinigungPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    required bool istBergkunde,
    required double preis,
    List<(String name, double menge)> materialien = const [],
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                  'Eröffnungen / Endreinigungen Berg-\nrestaurant im Auftrag von Heineken'),
              pw.SizedBox(height: 12),

              // Referenz + Bergkunde
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(referenzNr,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      'Bergrestaurant: ${istBergkunde ? "Ja" : "Nein"}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 12),

              _labelValue('Eröffnung/Endreinigung', 'Eröffnung'),
              pw.SizedBox(height: 4),
              _labelValue('Kunde / Rest.', kunde),
              _labelValue('PLZ / Ort', ort),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue(
                        'Störungs Nr. / Datum',
                        '$stoerungsnummer   ${_dateFormat.format(datum)}'),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Material
              _buildMaterialTabelle(materialien),
              pw.SizedBox(height: 16),

              // Anfahrtspauschale
              _buildPositionsZeile(
                  'Anfahrtspauschale', 1, preis, preis),
              if (istBergkunde)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20),
                  child: pw.Text('(inkl. Bergbahnentschädigung)',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: _grey)),
                ),

              pw.Spacer(),
              _buildTotalZeile(preis),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generateEEReinigung({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    required String ort,
    required bool istBergkunde,
    required double preis,
    List<(String name, double menge)> materialien = const [],
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildEEReinigungPage(
      referenzNr: referenzNr,
      stoerungsnummer: stoerungsnummer,
      datum: datum,
      kunde: kunde,
      ort: ort,
      istBergkunde: istBergkunde,
      preis: preis,
      materialien: materialien,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. MONTAGE-RAPPORT (F_Montage)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildMontagePage({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    required String ort,
    required String montageTyp,
    required String beschreibung,
    double? stundensatz,
    double? dauerStunden,
    double? kostenArbeit,
    List<(String name, double menge)> materialien = const [],
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('Montageaufträge'),
              pw.SizedBox(height: 12),

              pw.Text(referenzNr,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),

              _labelValue('Art der Montage:', _montageTypLabel(montageTyp)),
              pw.SizedBox(height: 4),
              _labelValue('Kunde / Rest.', kunde),
              _labelValue('PLZ / Ort', ort),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue(
                        'Auftrags Nr. / Datum',
                        '${_dateFormat.format(datum)}'),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Material (7 Positionen bei Montage)
              _buildMaterialTabelle(materialien),
              pw.SizedBox(height: 16),

              // Beschreibung
              pw.Text('Beschreibung',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Text(beschreibung,
                    style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.SizedBox(height: 16),

              // Stunden-Position
              if (dauerStunden != null && stundensatz != null)
                _buildPositionsZeile('Anzahl Stunden',
                    dauerStunden, stundensatz, kostenArbeit ?? 0),

              pw.Spacer(),
              _buildTotalZeile(kostenArbeit ?? 0),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generateMontage({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    required String ort,
    required String montageTyp,
    required String beschreibung,
    double? stundensatz,
    double? dauerStunden,
    double? kostenArbeit,
    List<(String name, double menge)> materialien = const [],
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildMontagePage(
      referenzNr: referenzNr,
      datum: datum,
      kunde: kunde,
      ort: ort,
      montageTyp: montageTyp,
      beschreibung: beschreibung,
      stundensatz: stundensatz,
      dauerStunden: dauerStunden,
      kostenArbeit: kostenArbeit,
      materialien: materialien,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. PIKETT-RAPPORT (F_Pikett)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildPikettPage({
    required String referenzNr,
    required DateTime datumStart,
    required DateTime datumEnde,
    required int kalenderwoche,
    double? pauschale,
    int anzahlFeiertage = 0,
    double? feiertagZuschlag,
    double? pauschaleGesamt,
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          final pauschalePro = pauschale ?? 160;
          final feiertagPro = feiertagZuschlag != null && anzahlFeiertage > 0
              ? feiertagZuschlag! / anzahlFeiertage
              : 80.0;
          final pikettTotal = pauschalePro;
          final feiertagTotal =
              anzahlFeiertage > 0 ? anzahlFeiertage * feiertagPro : 0.0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('Störung'),
              pw.SizedBox(height: 12),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(referenzNr,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Bergrestaurant: nein',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 12),

              _labelValue('Kunde / Rest.', ''),
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text('Vorname',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Text('Pikett KW $kalenderwoche',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue('Störungs Nr. / Datum', ''),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Leere Störungspositionen
              _buildStoerungsPositionenLeer(),
              pw.SizedBox(height: 8),

              // Leere Anfahrt
              _buildAnfahrtLeer(),
              pw.SizedBox(height: 12),

              // Pikett-Position
              _buildPositionsZeile(
                  'Pikettbereitschaft KW $kalenderwoche',
                  1,
                  pauschalePro,
                  pikettTotal),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 250),
                child: pw.Text('(pro Woche)',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 4),

              // Feiertag
              _buildPositionsZeile(
                  'Pikett Feiertag',
                  anzahlFeiertage.toDouble(),
                  feiertagPro,
                  feiertagTotal),

              pw.Spacer(),
              _buildTotalZeile(pauschaleGesamt ?? (pikettTotal + feiertagTotal)),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generatePikett({
    required String referenzNr,
    required DateTime datumStart,
    required DateTime datumEnde,
    required int kalenderwoche,
    double? pauschale,
    int anzahlFeiertage = 0,
    double? feiertagZuschlag,
    double? pauschaleGesamt,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildPikettPage(
      referenzNr: referenzNr,
      datumStart: datumStart,
      datumEnde: datumEnde,
      kalenderwoche: kalenderwoche,
      pauschale: pauschale,
      anzahlFeiertage: anzahlFeiertage,
      feiertagZuschlag: feiertagZuschlag,
      pauschaleGesamt: pauschaleGesamt,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. ANFAHRTSPAUSCHALE-RAPPORT (F_Pauschale)
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildAnfahrtspauschPage({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    required String ort,
  }) {
    return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 30, 50, 40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('Anfahrtspauschale Bergrestaurant'),
              pw.SizedBox(height: 12),

              pw.Text(referenzNr,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),

              _labelValue('Art der Pauschale:', '-'),
              pw.SizedBox(height: 4),
              _labelValue('Kunde / Rest.', kunde),
              _labelValue('PLZ / Ort', ort),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _labelValue(
                        'Datum', _dateFormat.format(datum)),
                  ),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text('Kontrolliert RSL',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Material (leer)
              _buildMaterialTabelle([]),
              pw.SizedBox(height: 16),

              // Anfahrtspauschale
              _buildPositionsZeile('Anfahrtspauschale', 1, 180, 180),

              pw.Spacer(),
              _buildTotalZeile(180),
            ],
          );
        },
    );
  }

  static Future<Uint8List> generateAnfahrtspauschale({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    required String ort,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(buildAnfahrtspauschPage(
      referenzNr: referenzNr,
      datum: datum,
      kunde: kunde,
      ort: ort,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  /// Header: "SBS Projer GmbH" rechtsbündig + Titel links
  static pw.Widget _buildHeader(String titel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(_firmaName,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),
        pw.Text(titel,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            )),
        pw.Container(height: 0.5, color: _black),
      ],
    );
  }

  /// Label-Value Zeile
  static pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Bereich-Checkboxen (K/B/D/H/O)
  static pw.Widget _buildBereichCheckboxes(int? bereich) {
    final bereiche = [
      (1, 'K = Konventionell'),
      (2, 'B = Blade'),
      (3, 'D = David'),
      (4, 'H = Heigenie'),
      (5, 'O = Orion'),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: bereiche.map((b) {
        final isSelected = bereich == b.$1;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: isSelected
                    ? pw.Center(
                        child: pw.Text('X',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold)))
                    : pw.SizedBox(),
              ),
              pw.SizedBox(width: 6),
              pw.Text(b.$2, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Material-Tabelle
  static pw.Widget _buildMaterialTabelle(
      List<(String name, double menge)> materialien) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          children: [
            pw.SizedBox(width: 300),
            pw.SizedBox(
              width: 120,
              child: pw.Text('Art. Nr. verbrauchtes Mat.',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(
              width: 50,
              child: pw.Text('Anzahl',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        // Zeilen (min 3, max je nach Typ)
        ...List.generate(
          materialien.length < 3 ? 3 : materialien.length,
          (i) {
            final mat = i < materialien.length ? materialien[i] : null;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 300),
                  pw.SizedBox(
                    width: 120,
                    child: pw.Text(mat?.$1 ?? '-',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                        mat != null
                            ? mat.$2.toStringAsFixed(0)
                            : '-',
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Störungspositionen (6 Bereiche mit Preisen)
  static pw.Widget _buildStoerungsPositionen(
      int? bereich, double? preisBasis) {
    final positionen = [
      ('Störung 1', 55.0),
      ('Störung 2', 55.0),
      ('Störung 3', 90.0),
      ('Störung 4', 45.0),
      ('Störung 5', 45.0),
      ('Störung 6 – Reinigung gem.DBO-Handbuch', 0.0),
    ];

    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.SizedBox(width: 200),
            pw.SizedBox(
              width: 60,
              child: pw.Text('Menge',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
            ),
            pw.SizedBox(width: 60),
            pw.SizedBox(
              width: 80,
              child: pw.Text('CHF',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        ...positionen.asMap().entries.map((e) {
          final idx = e.key;
          final name = e.value.$1;
          final einzelpreis = e.value.$2;
          // Bereich 1-5 mappt auf Störung 1-5 (vereinfacht)
          final menge = (bereich != null && bereich == idx + 1) ? 1 : 0;
          final total = menge * einzelpreis;

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 200,
                  child: pw.Text(name,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(
                  width: 60,
                  child: pw.Text('$menge',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center),
                ),
                pw.SizedBox(
                  width: 60,
                  child: pw.Text(einzelpreis > 0
                          ? einzelpreis.toStringAsFixed(0)
                          : '',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right),
                ),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(total.toStringAsFixed(0),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Leere Störungspositionen für Pikett
  static pw.Widget _buildStoerungsPositionenLeer() {
    return _buildStoerungsPositionen(null, null);
  }

  /// Anfahrt-Sektion
  static pw.Widget _buildAnfahrt(int km, double? preisAnfahrt) {
    final istLangstrecke = km > 80;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (!istLangstrecke) ...[
          pw.Text('Fahrweg kürzer als 80 Km',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
          _buildPositionsZeile(
              'Anfahrt Pauschal',
              preisAnfahrt != null && preisAnfahrt > 0 ? 1 : 0,
              60,
              preisAnfahrt ?? 0),
        ] else ...[
          pw.Text('Fahrweg länger als 80 Km',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
          _buildPositionsZeile(
              'Anfahrt in Km (berechnet)',
              km.toDouble(),
              0.72,
              preisAnfahrt ?? (km * 0.72)),
        ],
      ],
    );
  }

  /// Leere Anfahrt für Pikett
  static pw.Widget _buildAnfahrtLeer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Fahrweg kürzer als 80 Km',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        _buildPositionsZeile('Anfahrt Pauschal', 0, 60, 0),
      ],
    );
  }

  /// Pikett-Zeile (Wochenend-/Pikettbereitschaft)
  static pw.Widget _buildPikettZeile(double? zuschlag) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Zusatz Pikett',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        _buildPositionsZeile(
            'Pikettbereitschaft',
            zuschlag != null && zuschlag > 0 ? 1 : 0,
            160,
            zuschlag ?? 0),
      ],
    );
  }

  /// Positions-Zeile: Name | Menge | Einzelpreis | Total
  static pw.Widget _buildPositionsZeile(
      String name, double menge, double einzelpreis, double total) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 200,
            child: pw.Text(name,
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.SizedBox(
            width: 60,
            child: pw.Text(
                menge == menge.roundToDouble()
                    ? menge.toInt().toString()
                    : menge.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(
            width: 60,
            child: pw.Text(
                einzelpreis == einzelpreis.roundToDouble()
                    ? einzelpreis.toInt().toString()
                    : einzelpreis.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
          pw.SizedBox(
            width: 80,
            child: pw.Text(
                total == total.roundToDouble()
                    ? total.toInt().toString()
                    : total.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  /// Total-Zeile am Ende
  static pw.Widget _buildTotalZeile(double total) {
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: _black),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 20),
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                  total == total.roundToDouble()
                      ? total.toInt().toString()
                      : total.toStringAsFixed(2),
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }

  /// Montage-Typ Label
  static String _montageTypLabel(String typ) {
    switch (typ) {
      case 'neu_installation':
        return 'Neumontage';
      case 'umbau':
        return 'Abänderung';
      case 'erweiterung':
        return 'Erweiterung';
      case 'abbau':
        return 'Demontage';
      case 'heigenie_service':
        return 'HeiGenie Service';
      case 'anlass_mitarbeit':
        return 'Anlass-Mitarbeit';
      case 'mehraufwand':
        return 'Mehraufwand';
      case 'spesen':
        return 'Spesen';
      case 'sonstiges':
        return 'Sonstiges';
      default:
        return typ;
    }
  }
}
