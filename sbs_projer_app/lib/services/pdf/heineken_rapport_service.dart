import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generiert die 6 Heineken-Rapport-Formulare als PDFs.
/// Design matcht die Original-Heineken-Excel-Vorlagen mit Logo,
/// gelben Hintergründen, Umrandungen und strukturiertem Layout.
class HeinekenRapportService {
  // ─── Farben (Original-Heineken-Design) ───
  static const _yellowTitle = PdfColor(1.0, 0.78, 0.0);
  static const _yellowCell = PdfColor(1.0, 1.0, 0.76);
  static const _black = PdfColor.fromInt(0xFF000000);

  static const _firmaName = 'SBS Projer GmbH';
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  // ═══════════════════════════════════════════════════════════════
  // 1. STÖRUNGSRAPPORT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildStoerungPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    String adresse = '',
    required String ort,
    List<int>? stoerungBereiche,
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
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader('Störung', logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            // Kundendaten + Zeit
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Kunde / Rest.', kunde),
                      _formField('Name', ''),
                      _formField('Vorname', ''),
                      _formField('Adresse', adresse),
                      _formField('PLZ / Ort', ort),
                      _formFieldDual('Störungs Nr. / Datum',
                          stoerungsnummer, _dateFormat.format(datum)),
                      _formField('Seriennummer Kühler',
                          serienNrKuehler ?? '-'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Zeit der Störungsmeldung:',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      _borderedBox(uhrzeitStart != null && uhrzeitStart.length >= 5 ? uhrzeitStart.substring(0, 5) : uhrzeitStart ?? '', width: 80),
                      pw.SizedBox(height: 50),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            // Bereich + Material
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                    width: 150,
                    child: _buildBereichCheckboxes(stoerungBereiche)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _buildMaterialTabelle(materialien, 3)),
              ],
            ),
            pw.SizedBox(height: 4),
            // Störungspositionen
            _buildStoerungsPositionen(stoerungBereiche, preisBasis),
            pw.SizedBox(height: 2),
            // Anfahrt
            _buildAnfahrt(anfahrtKm, preisAnfahrt),
            pw.SizedBox(height: 2),
            // Pikett
            _buildPikettPositionen(
                istPikettEinsatz ? 1 : 0, preisWochenende, 0, null),
            pw.Spacer(),
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
    List<int>? stoerungBereiche,
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
    final logo = await _loadLogo();
    final pdf = pw.Document();
    pdf.addPage(buildStoerungPage(
      referenzNr: referenzNr,
      stoerungsnummer: stoerungsnummer,
      datum: datum,
      kunde: kunde,
      ort: ort,
      stoerungBereiche: stoerungBereiche,
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
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. EIGENAUFTRAG-RAPPORT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildEigenauftragPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    String adresse = '',
    required String ort,
    required String problemBeschreibung,
    String? loesungBeschreibung,
    double? pauschale,
    List<(String name, double menge)> materialien = const [],
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader('Eigener Auftrag', logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Kunde / Rest.', kunde),
                      _formField('Name', ''),
                      _formField('Vorname', ''),
                      _formField('Adresse', adresse),
                      _formField('PLZ / Ort', ort),
                      _formFieldDual('Störungs Nr. / Datum',
                          stoerungsnummer, _dateFormat.format(datum)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 95),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _buildMaterialTabelle(materialien, 3),
            pw.SizedBox(height: 12),
            // Umschreibung der Arbeit
            pw.Text('Umschreibung der Arbeit',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              constraints: const pw.BoxConstraints(minHeight: 80),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _yellowCell,
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
            _buildPositionRow('Eigener Auftrag', 1, pauschale ?? 0,
                pauschale ?? 0,
                waehrung: 'CHF'),
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
    final logo = await _loadLogo();
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
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. EE-REINIGUNG-RAPPORT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildEEReinigungPage({
    required String referenzNr,
    required String stoerungsnummer,
    required DateTime datum,
    required String kunde,
    String adresse = '',
    required String ort,
    required bool istBergkunde,
    required double preis,
    List<(String name, double menge)> materialien = const [],
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader(
                'Eröffnungen / Endreinigungen\nim Auftrag von Heineken',
                logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Eröffnung/Endrein.', 'Eröffnung'),
                      _formField('Kunde / Rest.', kunde),
                      _formField('Name', ''),
                      _formField('Vorname', ''),
                      _formField('Adresse', adresse),
                      _formField('PLZ / Ort', ort),
                      _formFieldDual('Störungs Nr. / Datum',
                          stoerungsnummer, _dateFormat.format(datum)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 95),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _buildMaterialTabelle(materialien, 3),
            pw.SizedBox(height: 16),
            _buildPositionRow('Anfahrtspauschale', 1, preis, preis),
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
    final logo = await _loadLogo();
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
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. MONTAGE-RAPPORT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildMontagePage({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    String adresse = '',
    required String ort,
    required String montageTyp,
    required String beschreibung,
    double? stundensatz,
    double? dauerStunden,
    double? kostenArbeit,
    List<(String name, double menge)> materialien = const [],
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader('Montageaufträge', logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Art der Montage', _montageTypLabel(montageTyp)),
                      _formField('Kunde / Rest.', kunde),
                      _formField('Name', ''),
                      _formField('Vorname', ''),
                      _formField('Adresse', adresse),
                      _formField('PLZ / Ort', ort),
                      _formFieldDual('Auftrags Nr. / Datum', '-',
                          _dateFormat.format(datum)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 95),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            // Anlass: Tages-Einträge statt Material-Tabelle
            montageTyp == 'anlass'
                ? _buildAnlassTabelle(materialien, 5)
                : _buildMaterialTabelle(materialien, 7),
            pw.SizedBox(height: 12),
            // Stunden-Position
            _buildPositionRow(
                'Anzahl Stunden',
                dauerStunden ?? 0,
                stundensatz ?? 80,
                kostenArbeit ?? 0),
            pw.SizedBox(height: 12),
            // Montagepauschale (nicht bei Anlass)
            if (montageTyp != 'anlass')
              _buildPositionRow(
                  'Montagepauschale\npro Montagetag', 0, 600, 0),
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
    final logo = await _loadLogo();
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
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. PIKETT-RAPPORT (nutzt Störung-Template)
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
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        final pauschalePro = pauschale ?? 80;
        final feiertagPro = feiertagZuschlag != null && anzahlFeiertage > 0
            ? feiertagZuschlag / anzahlFeiertage
            : 80.0;
        final pikettTotal = pauschalePro;
        final feiertagTotal =
            anzahlFeiertage > 0 ? anzahlFeiertage * feiertagPro : 0.0;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader('Störung', logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            // Pikett-Kundendaten (Vorname = "Pikett KW X")
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Kunde / Rest.', ''),
                      _formField('Name', ''),
                      _formField('Vorname', 'Pikett KW $kalenderwoche'),
                      _formField('Adresse', ''),
                      _formField('PLZ / Ort', ''),
                      _formField('Störungs Nr. / Datum', ''),
                      _formField('Seriennummer Kühler', ''),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Zeit der Störungsmeldung:',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      _borderedBox('', width: 80),
                      pw.SizedBox(height: 50),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            // Bereich + Material (leer)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                    width: 150,
                    child: _buildBereichCheckboxes(null)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _buildMaterialTabelle([], 3)),
              ],
            ),
            pw.SizedBox(height: 4),
            // Leere Störungspositionen
            _buildStoerungsPositionen(null, null),
            pw.SizedBox(height: 2),
            // Leere Anfahrt
            _buildAnfahrt(0, null),
            pw.SizedBox(height: 2),
            // Pikett-Positionen mit echten Werten
            _buildPikettPositionen(
              1,
              pikettTotal,
              anzahlFeiertage,
              feiertagTotal > 0 ? feiertagTotal : null,
            ),
            pw.Spacer(),
            _buildTotalZeile(
                pauschaleGesamt ?? (pikettTotal + feiertagTotal)),
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
    final logo = await _loadLogo();
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
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. ANFAHRTSPAUSCHALE-RAPPORT
  // ═══════════════════════════════════════════════════════════════

  static pw.Page buildAnfahrtspauschPage({
    required String referenzNr,
    required DateTime datum,
    required String kunde,
    String adresse = '',
    required String ort,
    Uint8List? logoBytes,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 30),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFormHeader('Anfahrtspauschale Bergrestaurant',
                logoBytes: logoBytes),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 310,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _formField('Art der Pauschale', '-'),
                      _formField('Kunde / Rest.', kunde),
                      _formField('Name', ''),
                      _formField('Vorname', ''),
                      _formField('Adresse', adresse),
                      _formField('PLZ / Ort', ort),
                      _formField('Datum', _dateFormat.format(datum)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 95),
                      pw.Row(children: [
                        pw.Text('Kontrolliert RSL',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 8),
                        _borderedBox('', width: 60),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _buildMaterialTabelle([], 3),
            pw.SizedBox(height: 16),
            _buildPositionRow('Anfahrtspauschale', 1, 180, 180),
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
    final logo = await _loadLogo();
    final pdf = pw.Document();
    pdf.addPage(buildAnfahrtspauschPage(
      referenzNr: referenzNr,
      datum: datum,
      kunde: kunde,
      ort: ort,
      logoBytes: logo,
    ));
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  /// Logo laden
  static Future<Uint8List?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/heineken_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Heineken-Logo Widget
  static pw.Widget _buildLogo(Uint8List? logoBytes) {
    if (logoBytes != null) {
      return pw.Image(pw.MemoryImage(logoBytes), width: 160);
    }
    return pw.Text('HEINEKEN',
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor(0, 0.51, 0),
        ));
  }

  /// Form-Header: Logo + SBS Projer GmbH + gelbe Titelleiste
  static pw.Widget _buildFormHeader(String titel,
      {Uint8List? logoBytes}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildLogo(logoBytes),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(_firmaName,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.5),
          ),
          child: pw.Center(
            child: pw.Text(titel,
                style: const pw.TextStyle(fontSize: 22),
                textAlign: pw.TextAlign.center),
          ),
        ),
      ],
    );
  }

  /// Gelbe Zelle mit Rand
  static pw.Widget _yellowBox(String text,
      {double? width,
      double height = 18,
      pw.TextStyle? style,
      pw.TextAlign textAlign = pw.TextAlign.left}) {
    return pw.Container(
      width: width,
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        color: _yellowCell,
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Text(text,
          style: style ?? const pw.TextStyle(fontSize: 10),
          textAlign: textAlign),
    );
  }

  /// Zelle mit Rand (ohne Farbe)
  static pw.Widget _borderedBox(String text,
      {double? width, double height = 18}) {
    return pw.Container(
      width: width,
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child:
          pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  /// Formular-Feld: Label links, gelbe Wert-Zelle rechts
  static pw.Widget _formField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 115,
              child: pw.Text(label,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(child: _yellowBox(value)),
        ],
      ),
    );
  }

  /// Formular-Feld mit zwei gelben Zellen (z.B. Nr + Datum)
  static pw.Widget _formFieldDual(
      String label, String val1, String val2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 115,
              child: pw.Text(label,
                  style: const pw.TextStyle(fontSize: 10))),
          _yellowBox(val1, width: 50),
          pw.SizedBox(width: 4),
          pw.Expanded(child: _yellowBox(val2)),
        ],
      ),
    );
  }

  /// Bereich-Checkboxen (B/D/K/H/O) mit gelben Zellen
  static pw.Widget _buildBereichCheckboxes(List<int>? bereiche) {
    final bereichDefs = [
      (2, 'B = Blade'),
      (3, 'D = David'),
      (1, 'K = Konventionell'),
      (4, 'H = Heigenie'),
      (5, 'O = Orion'),
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: bereichDefs.map((b) {
        final isSelected = bereiche?.contains(b.$1) ?? false;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(b.$2,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                width: 16,
                height: 16,
                decoration: pw.BoxDecoration(
                  color: _yellowCell,
                  border: pw.Border.all(width: 0.5),
                ),
                child: isSelected
                    ? pw.Center(
                        child: pw.Text('X',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold)))
                    : pw.SizedBox(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Material-Tabelle mit gelben Zellen (volle Breite)
  static pw.Widget _buildMaterialTabelle(
      List<(String name, double menge)> materialien, int maxRows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                height: 18,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Text('Art. Nr. verbrauchtes Mat.',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.Container(
              width: 60,
              height: 18,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text('Anzahl',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        // Datenzeilen
        ...List.generate(
          materialien.length < maxRows ? maxRows : materialien.length,
          (i) {
            final mat =
                i < materialien.length ? materialien[i] : null;
            return pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 16,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: _yellowCell,
                      border: pw.Border.all(width: 0.5),
                    ),
                    child: pw.Text(mat?.$1 ?? '-',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),
                pw.Container(
                  width: 60,
                  height: 16,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: _yellowCell,
                    border: pw.Border.all(width: 0.5),
                  ),
                  child: pw.Text(
                      mat != null
                          ? mat.$2.toStringAsFixed(0)
                          : '-',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Anlass: Tages-/Spesen-Tabelle (Freitext + Stunden statt Material + Anzahl)
  static pw.Widget _buildAnlassTabelle(
      List<(String name, double menge)> eintraege, int maxRows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                height: 18,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Text('Tag / Spesen',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.Container(
              width: 60,
              height: 18,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text('Stunden',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        // Datenzeilen
        ...List.generate(
          eintraege.length < maxRows ? maxRows : eintraege.length,
          (i) {
            final e = i < eintraege.length ? eintraege[i] : null;
            return pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 16,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: _yellowCell,
                      border: pw.Border.all(width: 0.5),
                    ),
                    child: pw.Text(e?.$1 ?? '-',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),
                pw.Container(
                  width: 60,
                  height: 16,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: _yellowCell,
                    border: pw.Border.all(width: 0.5),
                  ),
                  child: pw.Text(
                      e != null
                          ? e.$2.toStringAsFixed(2)
                          : '-',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Störungspositionen 1–6
  static pw.Widget _buildStoerungsPositionen(
      List<int>? bereiche, double? preisBasis) {
    final positionen = [
      ('Störung 1', 55.0),
      ('Störung 2', 55.0),
      ('Störung 3', 90.0),
      ('Störung 4', 45.0),
      ('Störung 5', 45.0),
      ('Störung 6', 0.0),
    ];

    return pw.Column(
      children: [
        // "Menge" Header
        pw.Row(children: [
          pw.SizedBox(width: 200),
          pw.SizedBox(
              width: 55,
              child: pw.Text('Menge',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center)),
        ]),
        ...positionen.asMap().entries.map((e) {
          final idx = e.key;
          final name = e.value.$1;
          final einzelpreis = e.value.$2;
          final menge =
              (bereiche != null && bereiche.contains(idx + 1)) ? 1 : 0;
          final total = menge * einzelpreis;

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(
                    width: 200,
                    child: pw.Text(name,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold))),
                _yellowBox(menge.toString(),
                    width: 55,
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(width: 10),
                pw.SizedBox(
                    width: 25,
                    child: pw.Text('SFr.',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                        idx == 5
                            ? ''
                            : einzelpreis.toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right)),
                if (idx == 5)
                  pw.Expanded(
                      child: pw.Text(
                          '  Reinigung gem.DBO-Handbuch',
                          style: const pw.TextStyle(fontSize: 8))),
                if (idx != 5) pw.Spacer(),
                pw.SizedBox(
                    width: 25,
                    child: pw.Text('SFr.',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Container(
                  width: 55,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(width: 0.5)),
                  ),
                  child: pw.Text(
                      total > 0
                          ? total.toStringAsFixed(2)
                          : '-',
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

  /// Anfahrt-Sektion
  static pw.Widget _buildAnfahrt(int km, double? preisAnfahrt) {
    final istLangstrecke = km > 80;
    final anfahrtMenge = preisAnfahrt != null && preisAnfahrt > 0
        ? (istLangstrecke ? km.toDouble() : 1.0)
        : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Kürzer als 80 Km
        pw.Row(children: [
          pw.SizedBox(
              width: 200,
              child: pw.Text('Fahrweg kürzer als 80 Km',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic))),
          pw.SizedBox(
              width: 55,
              child: pw.Text('Menge',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center)),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(
                  width: 200,
                  child: pw.Text('Anfahrt Pauschal',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold))),
              _yellowBox(
                  !istLangstrecke
                      ? anfahrtMenge.toInt().toString()
                      : '0',
                  width: 55,
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(
                  width: 50,
                  child: pw.Text('60.00',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right)),
              pw.Spacer(),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Container(
                width: 55,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text(
                    !istLangstrecke && preisAnfahrt != null && preisAnfahrt > 0
                        ? preisAnfahrt.toStringAsFixed(2)
                        : '-',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        // Länger als 80 Km
        pw.Row(children: [
          pw.SizedBox(
              width: 200,
              child: pw.Text('Fahrweg länger als 80 Km',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic))),
          pw.SizedBox(
              width: 55,
              child: pw.Text('Anzahl Km',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center)),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(
                  width: 200,
                  child: pw.Text('Anfahrt in Km (berechnet)',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold))),
              _yellowBox(
                  istLangstrecke ? km.toString() : '0',
                  width: 55,
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(
                  width: 50,
                  child: pw.Text('0.72',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right)),
              pw.Spacer(),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Container(
                width: 55,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text(
                    istLangstrecke && preisAnfahrt != null && preisAnfahrt > 0
                        ? preisAnfahrt.toStringAsFixed(2)
                        : '-',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
        // Fahrweg von-bis-nach
        pw.Row(children: [
          pw.SizedBox(
              width: 200,
              child: pw.Text('Fahrweg von-bis-nach',
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(child: _yellowBox('-')),
        ]),
      ],
    );
  }

  /// Pikett-Positionen (Bereitschaft + Feiertag)
  static pw.Widget _buildPikettPositionen(
      int mengePikett, double? preisPikett,
      int feiertage, double? preisFeiert) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(
                  width: 200,
                  child: pw.Text('Pikettbereitschaft KW ...',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold))),
              _yellowBox(mengePikett.toString(),
                  width: 55, textAlign: pw.TextAlign.center),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(
                  width: 50,
                  child: pw.Text('80.00',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 60,
                  child: pw.Text('(FR-SA)',
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center)),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Container(
                width: 55,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text(
                    mengePikett > 0 && preisPikett != null
                        ? preisPikett.toStringAsFixed(2)
                        : '-',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(
                  width: 200,
                  child: pw.Text('Pikett Feiertag',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold))),
              _yellowBox(feiertage.toString(),
                  width: 55, textAlign: pw.TextAlign.center),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(
                  width: 50,
                  child: pw.Text('80.00',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right)),
              pw.Spacer(),
              pw.SizedBox(
                  width: 25,
                  child: pw.Text('SFr.',
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Container(
                width: 55,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text(
                    feiertage > 0 && preisFeiert != null
                        ? preisFeiert.toStringAsFixed(2)
                        : '-',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Einzelne Position (für Eigenauftrag, Montage etc.)
  static pw.Widget _buildPositionRow(
      String label, double menge, double einzelpreis, double total,
      {String waehrung = 'SFr.', String? mengeLabel}) {
    final mengeStr = menge == menge.roundToDouble()
        ? menge.toInt().toString()
        : menge.toStringAsFixed(2);
    return pw.Column(
      children: [
        pw.Row(children: [
          pw.SizedBox(width: 200),
          pw.SizedBox(
              width: 55,
              child: pw.Text(mengeLabel ?? 'Menge',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center)),
        ]),
        pw.Row(
          children: [
            pw.SizedBox(
                width: 200,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold))),
            _yellowBox(mengeStr,
                width: 55, textAlign: pw.TextAlign.center),
            pw.SizedBox(width: 10),
            pw.SizedBox(
                width: 25,
                child: pw.Text(waehrung,
                    style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(
                width: 50,
                child: pw.Text(einzelpreis.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right)),
            pw.Spacer(),
            pw.SizedBox(
                width: 25,
                child: pw.Text('SFr.',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.Container(
              width: 55,
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
              child: pw.Text(
                  total > 0 ? total.toStringAsFixed(2) : '-',
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }

  /// Total-Zeile mit Doppel-Unterstrich
  static pw.Widget _buildTotalZeile(double total) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 20),
            pw.SizedBox(
                width: 25,
                child: pw.Text('SFr.',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(
              width: 60,
              child: pw.Text(
                  total == total.roundToDouble()
                      ? total.toStringAsFixed(2)
                      : total.toStringAsFixed(2),
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 85,
              child: pw.Column(children: [
                pw.Container(height: 1, color: _black),
                pw.SizedBox(height: 1),
                pw.Container(height: 1, color: _black),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  /// Montage-Typ Label
  static String _montageTypLabel(String typ) {
    switch (typ) {
      case 'neumontage':
        return 'Neumontage';
      case 'demontage':
        return 'Demontage';
      case 'abaenderung':
        return 'Abänderung';
      case 'heigenie_service':
        return 'HeiGenie Service';
      case 'anlass':
        return 'Anlass';
      case 'spesen':
        return 'Spesen';
      case 'aufwandsentschaedigung':
        return 'Aufwandsentsch.';
      // Legacy
      case 'neu_installation': case 'montage': return 'Neumontage';
      case 'umbau': case 'erweiterung': return 'Abänderung';
      case 'abbau': return 'Demontage';
      case 'anlass_mitarbeit': return 'Anlass';
      default:
        return typ;
    }
  }
}
