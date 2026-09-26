import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

/// Der Schweizer QR-Zahlteil (untere 105 mm einer A4-Seite).
///
/// WARUM diese Datei existiert (21.09.2026): Der Block lag wortgleich in
/// `rechnung_pdf_service.dart` und `mahnung_pdf_service.dart`. Mit dem
/// Kontoauszug kam ein dritter Bedarf dazu — statt ein drittes Mal zu kopieren,
/// steht er jetzt einmal hier. Die alte Kopie in `mahnung_pdf_service.dart`
/// ist mit dieser Datei entfallen (v0.134.0); das Mahnschreiben nutzt diesen
/// Zahlteil.
///
/// Die Firmendaten (Zahlungsempfänger) kommen seit Runde 4 (26.09.2026) aus
/// [GeschaeftEinstellungen] — vorher standen sie hier als zweite Kopie. Die
/// frühere Sorge «eine versehentlich leere oder falsche IBAN führt Geld auf
/// ein fremdes Konto» fängt [GeschaeftEinstellungen.ibanKompakt] ab: leer
/// oder mit falscher Prüfziffer gilt die feste [GeschaeftEinstellungen.kIban].
class QrKreditor {
  final String iban;
  final String ibanFormatiert;
  final String name;
  final String strasse;
  final String nr;
  final String plz;
  final String ort;
  final String land;

  const QrKreditor({
    required this.iban,
    required this.ibanFormatiert,
    required this.name,
    required this.strasse,
    required this.nr,
    required this.plz,
    required this.ort,
    this.land = 'CH',
  });

  factory QrKreditor.aus(GeschaeftEinstellungen g) {
    final (strasse, nr) = g.strasseUndNr;
    final (plz, ort) = g.plzUndOrt;
    return QrKreditor(
      iban: g.ibanKompakt,
      ibanFormatiert: g.ibanFormatiert,
      name: g.firma,
      strasse: strasse,
      nr: nr,
      plz: plz,
      ort: ort,
    );
  }
}

class QrZahlteil {
  static pw.Widget bauen(
    double betrag,
    QrEmpfaenger kunde, {
    required GeschaeftEinstellungen geschaeft,
    String? mitteilung,
    String? referenz,
  }) {
    const mm = PdfPageFormat.mm;
    final betragStr = betrag.toStringAsFixed(2);
    final kreditor = QrKreditor.aus(geschaeft);

    // QR-Code Daten (Swiss Payment Standards v2.3)
    final qrData = qrDaten(
      betrag,
      kunde,
      kreditor,
      mitteilung: mitteilung,
      referenz: referenz,
    );

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
              5 * mm,
              5 * mm,
              5 * mm,
              5 * mm,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                right: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Empfangsschein',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                _sectionTitle('Konto / Zahlbar an'),
                _qrText(kreditor.ibanFormatiert),
                _qrText(kreditor.name),
                _qrText('${kreditor.strasse} ${kreditor.nr}'),
                _qrText('${kreditor.plz} ${kreditor.ort}'),
                pw.SizedBox(height: 6),
                if (kunde.name.isNotEmpty) ...[
                  _sectionTitle('Zahlbar durch'),
                  _qrText(kunde.name),
                  if (kunde.strasseZeile.isNotEmpty)
                    _qrText(kunde.strasseZeile),
                  if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  pw.SizedBox(height: 6),
                ],
                pw.Row(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [_sectionTitle('Währung'), _qrText('CHF')],
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [_sectionTitle('Betrag'), _qrText(betragStr)],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Annahmestelle',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── ZAHLTEIL (rechts, 148mm) ───
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(
                5 * mm,
                5 * mm,
                5 * mm,
                5 * mm,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Zahlteil',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // QR-Code (46×46mm) mit zwingendem Schweizerkreuz (7mm) in der Mitte
                      pw.Container(
                        width: 46 * mm,
                        height: 46 * mm,
                        child: pw.Stack(
                          alignment: pw.Alignment.center,
                          children: [
                            pw.BarcodeWidget(
                              barcode: Barcode.qrCode(
                                errorCorrectLevel:
                                    BarcodeQRCorrectionLevel.medium,
                              ),
                              data: qrData,
                              width: 46 * mm,
                              height: 46 * mm,
                            ),
                            _swissQrCross(),
                          ],
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
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle('Währung'),
                                  pw.Text(
                                    'CHF',
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                              pw.SizedBox(width: 10),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle('Betrag'),
                                  pw.Text(
                                    betragStr,
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  _sectionTitle('Konto / Zahlbar an'),
                  _qrText(kreditor.ibanFormatiert),
                  _qrText(kreditor.name),
                  _qrText('${kreditor.strasse} ${kreditor.nr}'),
                  _qrText('${kreditor.plz} ${kreditor.ort}'),
                  pw.SizedBox(height: 6),
                  if (referenz != null && referenz.isNotEmpty) ...[
                    _sectionTitle('Referenz'),
                    _qrText(_scorAnzeige(referenz)),
                    pw.SizedBox(height: 6),
                  ],
                  if (kunde.name.isNotEmpty) ...[
                    _sectionTitle('Zahlbar durch'),
                    _qrText(kunde.name),
                    if (kunde.strasseZeile.isNotEmpty)
                      _qrText(kunde.strasseZeile),
                    if (kunde.plzOrt.isNotEmpty) _qrText(kunde.plzOrt),
                  ],
                  if (mitteilung != null && mitteilung.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    _sectionTitle('Zusätzliche Informationen'),
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

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _qrText(String text) {
    return pw.Text(text, style: const pw.TextStyle(fontSize: 8));
  }

  /// Zwingendes Schweizerkreuz (7×7mm) in der Mitte des QR-Codes (Swiss QR-Bill).
  /// Weisses Kreuz auf schwarzem Feld mit dünnem weissem Rahmen zur Abgrenzung.
  static pw.Widget _swissQrCross() {
    const mm = PdfPageFormat.mm;
    const white = PdfColor.fromInt(0xFFFFFFFF);
    const black = PdfColor.fromInt(0xFF000000);
    return pw.Container(
      width: 7 * mm,
      height: 7 * mm,
      color: white,
      child: pw.Padding(
        padding: pw.EdgeInsets.all(0.4 * mm),
        child: pw.Container(
          color: black,
          child: pw.Stack(
            alignment: pw.Alignment.center,
            children: [
              pw.Container(width: 1.3 * mm, height: 4.0 * mm, color: white),
              pw.Container(width: 4.0 * mm, height: 1.3 * mm, color: white),
            ],
          ),
        ),
      ),
    );
  }

  /// SCOR-Referenz in 4er-Gruppen für die Anzeige: RF18 5390 0754 7034.
  static String _scorAnzeige(String ref) {
    final r = ref.replaceAll(' ', '');
    final sb = StringBuffer();
    for (var i = 0; i < r.length; i += 4) {
      if (i > 0) sb.write(' ');
      sb.write(r.substring(i, i + 4 > r.length ? r.length : i + 4));
    }
    return sb.toString();
  }

  /// Baut den QR-Code Datenstring gemäss Swiss Payment Standards.
  static String qrDaten(
    double betrag,
    QrEmpfaenger kunde,
    QrKreditor kreditor, {
    String? mitteilung,
    String? referenz,
  }) {
    // Nutzt die gemeinsame reine Funktion (byte-identisch zur bisherigen Ausgabe).
    return swissQrPayload(
      iban: kreditor.iban,
      creditorName: kreditor.name,
      creditorStreet: kreditor.strasse,
      creditorNr: kreditor.nr,
      creditorPlz: kreditor.plz,
      creditorOrt: kreditor.ort,
      creditorLand: kreditor.land,
      betrag: betrag,
      debtorName: kunde.name,
      debtorStreet: kunde.strasse,
      debtorNr: kunde.nr,
      debtorPlz: kunde.plz,
      debtorOrt: kunde.ort,
      referenz: referenz,
      mitteilung: mitteilung,
    );
  }
}
