import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

class MahnungPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _darkRed = PdfColor.fromInt(0xFF8B0000);

  static const _iban = 'CH6600774010376550601';
  static const _ibanFormatted = 'CH66 0077 4010 3765 5060 1';
  static const _firmaName = 'SBS Projer GmbH';
  static const _firmaStrasse = 'Via Rezia';
  static const _firmaNr = '8';
  static const _firmaPlz = '7013';
  static const _firmaOrt = 'Domat/Ems';
  static const _firmaLand = 'CH';

  static Future<Uint8List> generate({
    required Rechnung rechnung,
    required BetriebLocal betrieb,
    BetriebRechnungsadresse? rechnungsadresse,
    required int mahnStufe,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');
    final brutto = _roundTo5Rappen(rechnung.betragBrutto);
    final titel = _titel(mahnStufe);
    final frist = DateTime.now().add(Duration(days: mahnStufe < 2 ? 20 : 30));
    final kundeAddr = _getKundenAdressDaten(betrieb, rechnungsadresse);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(50, 40, 50, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    pw.SizedBox(height: 30),
                    _buildKundenAdresse(betrieb, rechnungsadresse),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      titel,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: mahnStufe == 0 ? _darkBlue : _darkRed,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 140,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _label('Bezug Rechnung:'),
                              pw.SizedBox(height: 4),
                              _label('Rechnungsdatum:'),
                              pw.SizedBox(height: 4),
                              _label('Fällig seit:'),
                              pw.SizedBox(height: 4),
                              _label('Offener Betrag:'),
                              pw.SizedBox(height: 4),
                              _label('Neue Zahlungsfrist:'),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _value(rechnung.rechnungsnummer ?? ''),
                            pw.SizedBox(height: 4),
                            _value(df.format(rechnung.rechnungsdatum)),
                            pw.SizedBox(height: 4),
                            _value(df.format(rechnung.faelligkeitsdatum)),
                            pw.SizedBox(height: 4),
                            _value('CHF ${brutto.toStringAsFixed(2)}'),
                            pw.SizedBox(height: 4),
                            _value(df.format(frist)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 24),
                    ..._buildText(mahnStufe, rechnung, df),
                    pw.SizedBox(height: 24),
                    pw.Text(
                      'Freundliche Grüsse',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _firmaName,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              _buildQrZahlteil(brutto, kundeAddr,
                  mitteilung:
                      '$titel - ${rechnung.rechnungsnummer ?? ""}'),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _titel(int stufe) {
    switch (stufe) {
      case 0:
        return 'ZAHLUNGSERINNERUNG';
      case 1:
        return '1. MAHNUNG';
      case 2:
        return '2. MAHNUNG';
      default:
        return 'MAHNUNG';
    }
  }

  static List<pw.Widget> _buildText(
      int stufe, Rechnung rechnung, DateFormat df) {
    switch (stufe) {
      case 0:
        return [
          pw.Text(
            'Sehr geehrte Damen und Herren',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Bei der Überprüfung unserer Buchhaltung haben wir festgestellt, '
            'dass die oben genannte Rechnung noch nicht beglichen wurde. '
            'Möglicherweise haben Sie die Zahlung bereits veranlasst — '
            'in diesem Fall betrachten Sie dieses Schreiben bitte als gegenstandslos.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Wir bitten Sie, den offenen Betrag bis zum angegebenen Datum zu überweisen.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ];
      case 1:
        return [
          pw.Text(
            'Sehr geehrte Damen und Herren',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Trotz unserer Zahlungserinnerung ist der oben genannte Betrag '
            'bisher nicht auf unserem Konto eingegangen. '
            'Wir fordern Sie hiermit auf, die ausstehende Zahlung '
            'bis zum angegebenen Datum vorzunehmen.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Sollte die Zahlung bereits erfolgt sein, bitten wir um '
            'eine kurze Rückmeldung.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ];
      default:
        return [
          pw.Text(
            'Sehr geehrte Damen und Herren',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Wir haben Sie bereits mehrfach an die ausstehende Zahlung '
            'erinnert. Leider ist der Betrag bis heute nicht eingegangen.',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Wir fordern Sie letztmalig auf, den offenen Betrag '
            'bis zum angegebenen Datum zu begleichen. '
            'Andernfalls behalten wir uns weitere Schritte vor.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ];
    }
  }

  // ─── HEADER ───

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_firmaName,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _darkBlue)),
        pw.SizedBox(height: 4),
        pw.Text('$_firmaStrasse $_firmaNr',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text('$_firmaPlz $_firmaOrt',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.SizedBox(height: 4),
        pw.Text('Tel 076 566 58 06 | sbs.projer@gmail.com',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text('CHE-413.083.919 MWST',
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ],
    );
  }

  // ─── KUNDENADRESSE ───

  static pw.Widget _buildKundenAdresse(
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
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 10)))
          .toList(),
    );
  }

  static pw.Widget _label(String text) =>
      pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));

  static pw.Widget _value(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 9));

  // ─── QR-ZAHLTEIL ───

  static pw.Widget _buildQrZahlteil(
      double betrag, _KundeAdresse kunde, {String? mitteilung}) {
    const mm = PdfPageFormat.mm;
    final betragStr = betrag.toStringAsFixed(2);

    final qrData = _buildQrData(betrag, kunde, mitteilung: mitteilung);

    return pw.Container(
      height: 105 * mm,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 62 * mm,
            padding:
                const pw.EdgeInsets.fromLTRB(5 * mm, 5 * mm, 5 * mm, 5 * mm),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  right: pw.BorderSide(
                      width: 0.5, style: pw.BorderStyle.dashed)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Empfangsschein',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _qrTitle('Konto / Zahlbar an'),
                _qrText(_ibanFormatted),
                _qrText(_firmaName),
                _qrText('$_firmaStrasse $_firmaNr'),
                _qrText('$_firmaPlz $_firmaOrt'),
                pw.SizedBox(height: 6),
                if (kunde.name.isNotEmpty) ...[
                  _qrTitle('Zahlbar durch'),
                  _qrText(kunde.name),
                  if (kunde.strasse.isNotEmpty) _qrText(kunde.strasse),
                  if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  pw.SizedBox(height: 6),
                ],
                pw.Row(children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [_qrTitle('Währung'), _qrText('CHF')]),
                  pw.SizedBox(width: 8),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [_qrTitle('Betrag'), _qrText(betragStr)]),
                ]),
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
          pw.Expanded(
            child: pw.Padding(
              padding:
                  const pw.EdgeInsets.fromLTRB(5 * mm, 5 * mm, 5 * mm, 5 * mm),
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
                      pw.Container(
                        width: 46 * mm,
                        height: 46 * mm,
                        child: pw.BarcodeWidget(
                          barcode: Barcode.qrCode(
                              errorCorrectLevel:
                                  BarcodeQRCorrectionLevel.medium),
                          data: qrData,
                          width: 46 * mm,
                          height: 46 * mm,
                        ),
                      ),
                      pw.SizedBox(width: 5 * mm),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(children: [
                            pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.start,
                                children: [
                                  _qrTitle('Währung'),
                                  pw.Text('CHF',
                                      style: const pw.TextStyle(fontSize: 8)),
                                ]),
                            pw.SizedBox(width: 10),
                            pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.start,
                                children: [
                                  _qrTitle('Betrag'),
                                  pw.Text(betragStr,
                                      style: const pw.TextStyle(fontSize: 8)),
                                ]),
                          ]),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  _qrTitle('Konto / Zahlbar an'),
                  _qrText(_ibanFormatted),
                  _qrText(_firmaName),
                  _qrText('$_firmaStrasse $_firmaNr'),
                  _qrText('$_firmaPlz $_firmaOrt'),
                  pw.SizedBox(height: 6),
                  if (kunde.name.isNotEmpty) ...[
                    _qrTitle('Zahlbar durch'),
                    _qrText(kunde.name),
                    if (kunde.strasse.isNotEmpty) _qrText(kunde.strasse),
                    if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  ],
                  if (mitteilung != null && mitteilung.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    _qrTitle('Zusätzliche Informationen'),
                    _qrText(mitteilung),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrTitle(String text) => pw.Text(text,
      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold));

  static pw.Widget _qrText(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 8));

  static String _buildQrData(double betrag, _KundeAdresse kunde,
      {String? mitteilung}) {
    final info = mitteilung != null && mitteilung.isNotEmpty
        ? (mitteilung.length > 140 ? mitteilung.substring(0, 140) : mitteilung)
        : '';
    final lines = <String>[
      'SPC', '0200', '1',
      _iban, 'S', _firmaName, _firmaStrasse, _firmaNr, _firmaPlz, _firmaOrt,
      _firmaLand,
      '', '', '', '', '', '', '',
      betrag.toStringAsFixed(2), 'CHF',
      kunde.name.isNotEmpty ? 'S' : '', kunde.name,
      kunde.strasseOnly, kunde.nrOnly, kunde.plzOnly, kunde.ortOnly,
      kunde.name.isNotEmpty ? _firmaLand : '',
      'NON', '', info, 'EPD',
    ];
    return lines.join('\n');
  }

  static double _roundTo5Rappen(double value) =>
      (value * 20).roundToDouble() / 20;

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
  final String name, strasseOnly, nrOnly, plzOnly, ortOnly;

  _KundeAdresse({
    required this.name,
    required this.strasseOnly,
    required this.nrOnly,
    required this.plzOnly,
    required this.ortOnly,
  });

  String get strasse =>
      [strasseOnly, nrOnly].where((s) => s.isNotEmpty).join(' ');
  String get plzOrt =>
      [plzOnly, ortOnly].where((s) => s.isNotEmpty).join(' ');
}
