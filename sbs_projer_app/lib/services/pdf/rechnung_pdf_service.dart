import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

class RechnungPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);
  static const _lineGrey = PdfColor.fromInt(0xFFCCCCCC);

  // Firmendaten
  static const _iban = 'CH6600774010376550601';
  static const _ibanFormatted = 'CH66 0077 4010 3765 5060 1';
  static const _firmaName = 'SBS Projer GmbH';
  static const _firmaStrasse = 'Via Rezia';
  static const _firmaNr = '8';
  static const _firmaPlz = '7013';
  static const _firmaOrt = 'Domat/Ems';
  static const _firmaLand = 'CH';

  /// Generiert eine professionelle A4-Kundenrechnung mit QR-Zahlteil.
  static Future<Uint8List> generate({
    required Rechnung rechnung,
    required List<RechnungsPosition> positionen,
    required BetriebLocal betrieb,
    BetriebRechnungsadresse? rechnungsadresse,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy');
    final brutto = _roundTo5Rappen(rechnung.betragBrutto);

    // Kundenadresse für QR-Bill
    final kundeAddr = _getKundenAdressDaten(betrieb, rechnungsadresse);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // === RECHNUNGSINHALT (oberer Teil) ===
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(50, 40, 50, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    pw.SizedBox(height: 30),
                    _buildKundenAdresse(betrieb, rechnungsadresse),
                    pw.SizedBox(height: 30),
                    _buildRechnungsInfo(rechnung, betrieb, dateFormat),
                    pw.SizedBox(height: 20),
                    _buildPositionenTabelle(positionen),
                    pw.SizedBox(height: 16),
                    _buildSummen(rechnung),
                    pw.SizedBox(height: 20),
                    _buildZahlungsInfo(),
                  ],
                ),
              ),

              pw.Spacer(),

              // === QR-ZAHLTEIL (untere 105mm) ===
              _buildQrZahlteil(brutto, kundeAddr),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── HEADER ───

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _firmaName,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _darkBlue,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('$_firmaStrasse $_firmaNr',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text('$_firmaPlz $_firmaOrt',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.SizedBox(height: 4),
        pw.Text('Tel 076 566 58 06',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text('CHE-413.083.919 MWST',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ],
    );
  }

  // ─── KUNDENADRESSE ───

  static pw.Widget _buildKundenAdresse(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
  ) {
    final lines = _getKundenAdressZeilen(betrieb, ra);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 10)))
          .toList(),
    );
  }

  // ─── RECHNUNGSINFO ───

  static pw.Widget _buildRechnungsInfo(
    Rechnung rechnung,
    BetriebLocal betrieb,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RECHNUNG',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _darkBlue,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoLabel('Rechnungs-Nr.:'),
                  pw.SizedBox(height: 4),
                  _infoLabel('Datum:'),
                  pw.SizedBox(height: 4),
                  _infoLabel('Fällig bis:'),
                  pw.SizedBox(height: 4),
                  _infoLabel('Kunden-Nr.:'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoValue(rechnung.rechnungsnummer ?? ''),
                pw.SizedBox(height: 4),
                _infoValue(dateFormat.format(rechnung.rechnungsdatum)),
                pw.SizedBox(height: 4),
                _infoValue(dateFormat.format(rechnung.faelligkeitsdatum)),
                pw.SizedBox(height: 4),
                _infoValue(betrieb.betriebNr ?? ''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoLabel(String text) {
    return pw.Text(text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));
  }

  static pw.Widget _infoValue(String text) {
    return pw.Text(text, style: const pw.TextStyle(fontSize: 9));
  }

  // ─── POSITIONSTABELLE ───

  static pw.Widget _buildPositionenTabelle(
      List<RechnungsPosition> positionen) {
    return pw.Column(
      children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: const pw.BoxDecoration(color: _darkBlue),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 35,
                child: pw.Text('Pos',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              pw.Expanded(
                child: pw.Text('Beschreibung',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              pw.SizedBox(
                width: 80,
                child: pw.Text('Betrag CHF',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
        // Zeilen
        ...List.generate(positionen.length, (i) {
          final p = positionen[i];
          final isEven = i % 2 == 0;
          return pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _lightGrey,
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 35,
                  child: pw.Text('${p.position}',
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Expanded(
                  child: pw.Text(p.beschreibung,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(_chf(p.betragNetto),
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

  // ─── SUMMEN ───

  static pw.Widget _buildSummen(Rechnung rechnung) {
    final brutto = _roundTo5Rappen(rechnung.betragBrutto);
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Column(
          children: [
            _summenRow('Netto', _chf(rechnung.betragNetto)),
            pw.SizedBox(height: 3),
            _summenRow('MwSt 8.1%', _chf(rechnung.mwstBetrag)),
            pw.SizedBox(height: 4),
            pw.Container(height: 1, color: _lineGrey),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total CHF',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(_chf(brutto),
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summenRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // ─── ZAHLUNGSINFO ───

  static pw.Widget _buildZahlungsInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Zahlbar innert 30 Tagen netto',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 6),
        pw.Text('Vielen Dank für Ihren Auftrag!',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _darkBlue)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ═══ QR-ZAHLTEIL (Swiss QR-bill, untere 105mm der A4-Seite) ═══
  // ═══════════════════════════════════════════════════════════════

  static pw.Widget _buildQrZahlteil(
      double betrag, _KundeAdresse kunde) {
    const mm = PdfPageFormat.mm;
    final betragStr = betrag.toStringAsFixed(2);

    // QR-Code Daten (Swiss Payment Standards v2.3)
    final qrData = _buildQrData(betrag, kunde);

    return pw.Container(
      height: 105 * mm,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ─── EMPFANGSSCHEIN (links, 62mm) ───
          pw.Container(
            width: 62 * mm,
            padding: const pw.EdgeInsets.fromLTRB(
                5 * mm, 5 * mm, 5 * mm, 5 * mm),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  right: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Empfangsschein',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _qrSectionTitle('Konto / Zahlbar an'),
                _qrText(_ibanFormatted),
                _qrText(_firmaName),
                _qrText('$_firmaStrasse $_firmaNr'),
                _qrText('$_firmaPlz $_firmaOrt'),
                pw.SizedBox(height: 6),
                if (kunde.name.isNotEmpty) ...[
                  _qrSectionTitle('Zahlbar durch'),
                  _qrText(kunde.name),
                  if (kunde.strasse.isNotEmpty) _qrText(kunde.strasse),
                  if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  pw.SizedBox(height: 6),
                ],
                pw.Row(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _qrSectionTitle('Währung'),
                        _qrText('CHF'),
                      ],
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _qrSectionTitle('Betrag'),
                        _qrText(betragStr),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Annahmestelle',
                      style: pw.TextStyle(
                          fontSize: 6, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ─── ZAHLTEIL (rechts, 148mm) ───
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(
                  5 * mm, 5 * mm, 5 * mm, 5 * mm),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Zahlteil',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // QR-Code (46×46mm)
                      pw.Container(
                        width: 46 * mm,
                        height: 46 * mm,
                        child: pw.BarcodeWidget(
                          barcode: Barcode.qrCode(
                            errorCorrectLevel:
                                BarcodeQRCorrectionLevel.medium,
                          ),
                          data: qrData,
                          width: 46 * mm,
                          height: 46 * mm,
                        ),
                      ),
                      pw.SizedBox(width: 5 * mm),
                      // Betrag rechts vom QR
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.start,
                                children: [
                                  _qrSectionTitle('Währung'),
                                  pw.Text('CHF',
                                      style:
                                          const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                              pw.SizedBox(width: 10),
                              pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.start,
                                children: [
                                  _qrSectionTitle('Betrag'),
                                  pw.Text(betragStr,
                                      style:
                                          const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  _qrSectionTitle('Konto / Zahlbar an'),
                  _qrText(_ibanFormatted),
                  _qrText(_firmaName),
                  _qrText('$_firmaStrasse $_firmaNr'),
                  _qrText('$_firmaPlz $_firmaOrt'),
                  pw.SizedBox(height: 6),
                  if (kunde.name.isNotEmpty) ...[
                    _qrSectionTitle('Zahlbar durch'),
                    _qrText(kunde.name),
                    if (kunde.strasse.isNotEmpty) _qrText(kunde.strasse),
                    if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrSectionTitle(String text) {
    return pw.Text(text,
        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold));
  }

  static pw.Widget _qrText(String text) {
    return pw.Text(text, style: const pw.TextStyle(fontSize: 8));
  }

  /// Baut den QR-Code Datenstring gemäss Swiss Payment Standards.
  static String _buildQrData(double betrag, _KundeAdresse kunde) {
    final lines = <String>[
      'SPC', // QR Type
      '0200', // Version
      '1', // Coding Type (UTF-8)
      _iban, // IBAN
      'S', // Creditor Address Type (S=structured)
      _firmaName, // Creditor Name
      _firmaStrasse, // Creditor Street
      _firmaNr, // Creditor Building Number
      _firmaPlz, // Creditor Postal Code
      _firmaOrt, // Creditor City
      _firmaLand, // Creditor Country
      '', // Ultimate Creditor Address Type
      '', // Ultimate Creditor Name
      '', // Ultimate Creditor Street
      '', // Ultimate Creditor Building Number
      '', // Ultimate Creditor Postal Code
      '', // Ultimate Creditor City
      '', // Ultimate Creditor Country
      betrag.toStringAsFixed(2), // Amount
      'CHF', // Currency
      // Debtor (Zahlbar durch)
      kunde.name.isNotEmpty ? 'S' : '', // Debtor Address Type
      kunde.name, // Debtor Name
      kunde.strasseOnly, // Debtor Street
      kunde.nrOnly, // Debtor Building Number
      kunde.plzOnly, // Debtor Postal Code
      kunde.ortOnly, // Debtor City
      kunde.name.isNotEmpty ? _firmaLand : '', // Debtor Country
      'NON', // Reference Type
      '', // Reference
      '', // Additional Information
      'EPD', // Trailer
    ];
    return lines.join('\n');
  }

  // ─── HELPERS ───

  static String _chf(double value) {
    return value.toStringAsFixed(2);
  }

  static double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  static List<String> _getKundenAdressZeilen(
      BetriebLocal betrieb, BetriebRechnungsadresse? ra) {
    final lines = <String>[];
    if (ra != null) {
      if (ra.firma != null && ra.firma!.isNotEmpty) lines.add(ra.firma!);
      final name = [ra.vorname, ra.nachname]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (name.isNotEmpty) lines.add(name);
      final strasse = [ra.strasse, ra.nr]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (strasse.isNotEmpty) lines.add(strasse);
      final plzOrt =
          [ra.plz, ra.ort].where((s) => s != null && s.isNotEmpty).join(' ');
      if (plzOrt.isNotEmpty) lines.add(plzOrt);
    } else {
      lines.add(betrieb.name);
      final strasse = [betrieb.strasse, betrieb.nr]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (strasse.isNotEmpty) lines.add(strasse);
      final plzOrt = [betrieb.plz, betrieb.ort]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (plzOrt.isNotEmpty) lines.add(plzOrt);
    }
    return lines;
  }

  static _KundeAdresse _getKundenAdressDaten(
      BetriebLocal betrieb, BetriebRechnungsadresse? ra) {
    if (ra != null) {
      final name = [ra.firma, ra.vorname, ra.nachname]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ')
          .trim();
      return _KundeAdresse(
        name: name.isNotEmpty ? name : (ra.nachname ?? ''),
        strasseOnly: ra.strasse ?? '',
        nrOnly: ra.nr ?? '',
        plzOnly: ra.plz ?? '',
        ortOnly: ra.ort ?? '',
      );
    }
    return _KundeAdresse(
      name: betrieb.name,
      strasseOnly: betrieb.strasse ?? '',
      nrOnly: betrieb.nr ?? '',
      plzOnly: betrieb.plz ?? '',
      ortOnly: betrieb.ort ?? '',
    );
  }
}

class _KundeAdresse {
  final String name;
  final String strasseOnly;
  final String nrOnly;
  final String plzOnly;
  final String ortOnly;

  _KundeAdresse({
    required this.name,
    required this.strasseOnly,
    required this.nrOnly,
    required this.plzOnly,
    required this.ortOnly,
  });

  String get strasse {
    final s = [strasseOnly, nrOnly]
        .where((s) => s.isNotEmpty)
        .join(' ');
    return s;
  }

  String get plzOrt {
    final s = [plzOnly, ortOnly]
        .where((s) => s.isNotEmpty)
        .join(' ');
    return s;
  }
}
