import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

/// Erzeugt den Lohnausweis im **amtlichen Layout** (Form. 11 dfi,
/// 605.040.18N — Eidgenössische Steuerverwaltung / Schweizerische
/// Steuerkonferenz), also in derselben Aufmachung wie die von Hand
/// ausgefüllten Ausweise 2019–2024: dreisprachige Ziffern 1–15, Kopffelder
/// A–H, Bestätigungsblock I.
///
/// Das amtliche PDF selbst lässt sich nicht befüllen (das `pdf`-Paket kann
/// keine bestehenden Dokumente laden), deshalb ist das Formular hier
/// nachgebaut. Inhalt und Reihenfolge folgen dem Original; Beträge stehen
/// gemäss Vorgabe in **ganzen Franken**.
class LohnausweisPdfService {
  static const _grau = PdfColor.fromInt(0xFF555555);
  static const _feld = PdfColor.fromInt(0xFFEFE9F4); // Eingabefelder (lila)
  static const _linie = PdfColor.fromInt(0xFF9E9E9E);

  // Spaltenmasse des Formulars (A4 hochkant, Ränder 28pt).
  static const double _wertBreite = 92;
  static const double _zeichenBreite = 12;
  static const double _nrBreite = 16;

  static String _ganz(double v) =>
      NumberFormat('#,##0', 'en_US').format(v.round()).replaceAll(',', '’');

  static Future<Uint8List> generate(
    LohnEinstellungen einst,
    Map<String, double> totale,
    int jahr,
  ) async {
    final pdf = await pdfDokument();
    final df = DateFormat('dd.MM.yyyy');

    final brutto = totale['brutto'] ?? 0;
    final ahvAn = totale['ahv_an'] ?? 0;
    final alvAn = totale['alv_an'] ?? 0;
    final nbuAn = totale['nbu_an'] ?? 0;
    final bvgAn = totale['bvg_an'] ?? 0;
    final ktgAn = totale['ktg_an'] ?? 0;

    // Ziffer 9 umfasst AHV/IV/EO, ALV und NBUV — KTG gehört nicht dazu.
    final ziffer9 = ahvAn + alvAn + nbuAn;
    // Ziffer 11 muss rechnerisch 8 − 9 − 10 ergeben (Formularlogik).
    final ziffer11 = brutto - ziffer9 - bvgAn;

    final name = [einst.arbeitnehmerName, einst.arbeitnehmerVorname]
        .where((e) => (e ?? '').isNotEmpty)
        .join(' ');

    final bemerkung = StringBuffer(
        'Nettolohnvereinbarung: Bruttolohn aufgerechnet gemäss Anleitung zur '
        'Lohndeklaration (Nettolohn ÷ (100 − 6.4) × 100).');
    if (ktgAn > 0) {
      bemerkung.write(
          ' KTG-Beitrag Arbeitnehmer ${_ganz(ktgAn)} ist im Bruttolohn enthalten.');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Kopf A / B ──────────────────────────────────────────────
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('A'),
              _kaestchen(gekreuzt: true),
              pw.SizedBox(width: 6),
              pw.Text(
                  'Lohnausweis – Certificat de salaire – Certificato di salario',
                  style:
                      pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('B'),
              _kaestchen(),
              pw.SizedBox(width: 6),
              pw.Text(
                  'Rentenbescheinigung – Attestation de rentes – Attestazione delle rendite',
                  style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.SizedBox(height: 8),

            // ── C / F ───────────────────────────────────────────────────
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('C'),
              _wertFeld(einst.arbeitnehmerAhvNr ?? '', breite: 110),
              pw.SizedBox(width: 10),
              _wertFeld(
                  einst.arbeitnehmerGeburtsdatum == null
                      ? ''
                      : df.format(einst.arbeitnehmerGeburtsdatum!),
                  breite: 96),
              pw.SizedBox(width: 14),
              _kennzeichen('F'),
              _kaestchen(),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: _dreisprachig(
                  'Unentgeltliche Beförderung zwischen Wohn- und Arbeitsort',
                  'Transport gratuit entre le domicile et le lieu de travail',
                  'Trasporto gratuito dal domicilio al luogo di lavoro',
                ),
              ),
            ]),
            pw.Row(children: [
              pw.SizedBox(width: _nrBreite),
              pw.SizedBox(
                  width: 110,
                  child: pw.Text('AHV-Nr. – No AVS – N.AVS',
                      style: const pw.TextStyle(fontSize: 5.5, color: _grau))),
              pw.SizedBox(width: 10),
              pw.SizedBox(
                  width: 96,
                  child: pw.Text(
                      'Geburtsdatum – Date de naissance – Data di nascita',
                      style: const pw.TextStyle(fontSize: 5.5, color: _grau))),
            ]),
            pw.SizedBox(height: 6),

            // ── D / E / G ───────────────────────────────────────────────
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('D'),
              _wertFeld('$jahr', breite: 52),
              pw.SizedBox(width: 10),
              _kennzeichen('E'),
              _wertFeld('01.01.$jahr', breite: 62),
              pw.SizedBox(width: 8),
              _wertFeld('31.12.$jahr', breite: 62),
              pw.SizedBox(width: 14),
              _kennzeichen('G'),
              _kaestchen(),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: _dreisprachig(
                  'Kantinenverpflegung / Lunch-Checks',
                  'Repas à la cantine / chèques-repas',
                  'Pasti alla mensa / buoni pasto',
                ),
              ),
            ]),
            pw.Row(children: [
              pw.SizedBox(width: _nrBreite),
              pw.SizedBox(
                  width: 52,
                  child: pw.Text('Jahr – Année – Anno',
                      style: const pw.TextStyle(fontSize: 5.5, color: _grau))),
              pw.SizedBox(width: 10 + _nrBreite),
              pw.SizedBox(
                  width: 62,
                  child: pw.Text('von – du – dal',
                      style: const pw.TextStyle(fontSize: 5.5, color: _grau))),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                  width: 62,
                  child: pw.Text('bis – au – al',
                      style: const pw.TextStyle(fontSize: 5.5, color: _grau))),
            ]),
            pw.SizedBox(height: 8),

            // ── H Adressfeld ────────────────────────────────────────────
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('H'),
              pw.Expanded(
                child: pw.Container(
                  height: 74,
                  padding: const pw.EdgeInsets.fromLTRB(90, 10, 8, 6),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _linie, width: 0.4)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                      if ((einst.arbeitnehmerAdresse ?? '').isNotEmpty)
                        pw.Text(einst.arbeitnehmerAdresse!,
                            style: const pw.TextStyle(fontSize: 10)),
                      if ((einst.arbeitnehmerPlzOrt ?? '').isNotEmpty)
                        pw.Text(einst.arbeitnehmerPlzOrt!,
                            style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ]),
            pw.SizedBox(height: 6),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              _dreisprachig('Nur ganze Frankenbeträge', 'Que des montants entiers',
                  'Unicamente importi interi',
                  rechts: true),
            ]),
            pw.SizedBox(height: 4),

            // ── Ziffern 1–15 ────────────────────────────────────────────
            _zeile('1.',
                d: 'Lohn soweit nicht unter Ziffer 2–7 aufzuführen / Rente',
                f: 'Salaire qui ne concerne pas les chiffres 2 à 7 ci-dessous / Rente',
                i: 'Salario se non da indicare sotto cifre da 2 a 7 più sotto / Rendita',
                wert: _ganz(brutto)),
            _zeile('2.',
                d: 'Gehaltsnebenleistungen — 2.1 Verpflegung, Unterkunft · 2.2 Privatanteil Geschäftsfahrzeug · 2.3 Andere',
                f: 'Prestations salariales accessoires',
                i: 'Prestazioni accessorie al salario',
                zeichen: '+'),
            _zeile('3.',
                d: 'Unregelmässige Leistungen – Prestations non périodiques – Prestazioni aperiodiche',
                zeichen: '+'),
            _zeile('4.',
                d: 'Kapitalleistungen – Prestations en capital – Prestazioni in capitale',
                zeichen: '+'),
            _zeile('5.',
                d: 'Beteiligungsrechte gemäss Beiblatt – Droits de participation selon annexe – Diritti di partecipazione',
                zeichen: '+'),
            _zeile('6.',
                d: 'Verwaltungsratsentschädigungen – Indemnités des membres de l’administration – Indennità dei membri',
                zeichen: '+'),
            _zeile('7.',
                d: 'Andere Leistungen – Autres prestations – Altre prestazioni',
                zeichen: '+'),
            _zeile('8.',
                d: 'Bruttolohn total / Rente – Salaire brut total / Rente – Salario lordo totale / Rendita',
                zeichen: '=',
                wert: _ganz(brutto),
                fett: true),
            _zeile('9.',
                d: 'Beiträge AHV/IV/EO/ALV/NBUV – Cotisations AVS/AI/APG/AC/AANP – Contributi AVS/AI/IPG/AD/AINP',
                zeichen: '–',
                wert: _ganz(ziffer9)),
            _zeile('10.',
                d: 'Berufliche Vorsorge 2. Säule — 10.1 Ordentliche Beiträge – Cotisations ordinaires – Contributi ordinari',
                f: 'Prévoyance professionnelle 2e pilier — 10.2 Beiträge für den Einkauf – Cotisations pour le rachat',
                zeichen: '–',
                wert: _ganz(bvgAn)),
            _zeile('11.',
                d: 'Nettolohn / Rente – Salaire net / Rente – Salario netto / Rendita',
                f: 'In die Steuererklärung übertragen – A reporter sur la déclaration d’impôt – Da riportare nella dichiarazione',
                zeichen: '=',
                wert: _ganz(ziffer11),
                fett: true),
            _zeile('12.',
                d: 'Quellensteuerabzug – Retenue de l’impôt à la source – Ritenuta d’imposta alla fonte'),
            _zeile('13.',
                d: 'Spesenvergütungen (13.1 Effektive · 13.2 Pauschal · 13.3 Weiterbildung) – Allocations pour frais',
                f: 'Nicht im Bruttolohn (gemäss Ziffer 8) enthalten – Non comprises dans le salaire brut (au chiffre 8)'),
            _zeile('14.',
                d: 'Weitere Gehaltsnebenleistungen – Autres prestations salariales accessoires – Altre prestazioni'),

            // Ziffer 15: Bemerkungen mit Text
            pw.SizedBox(height: 2),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(
                  width: _nrBreite,
                  child: pw.Text('15.',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(
                width: 78,
                child: _dreisprachig(
                    'Bemerkungen', 'Observations', 'Osservazioni'),
              ),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  color: _feld,
                  child: pw.Text(bemerkung.toString(),
                      style: const pw.TextStyle(fontSize: 7.5)),
                ),
              ),
            ]),

            pw.Spacer(),

            // ── I Bestätigung ───────────────────────────────────────────
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kennzeichen('I'),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ort und Datum – Lieu et date – Luogo e data',
                        style: const pw.TextStyle(fontSize: 6, color: _grau)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        '${einst.arbeitgeberPlzOrt?.replaceAll(RegExp(r'^\d+\s*'), '') ?? 'Domat/Ems'}, '
                        '${df.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Die Richtigkeit und Vollständigkeit bestätigt',
                        style: const pw.TextStyle(fontSize: 6, color: _grau)),
                    pw.Text(
                        'inkl. genauer Anschrift und Telefonnummer des Arbeitgebers',
                        style: const pw.TextStyle(fontSize: 5.5, color: _grau)),
                    pw.Text('Certifié exact et complet',
                        style: const pw.TextStyle(fontSize: 5.5, color: _grau)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final z in [
                      einst.arbeitgeberName ?? 'SBS Projer GmbH',
                      einst.arbeitgeberAdresse ?? '',
                      einst.arbeitgeberPlzOrt ?? '',
                    ].where((e) => e.isNotEmpty))
                      pw.Text(z, style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 14),
                    pw.Container(
                        width: 130,
                        decoration: const pw.BoxDecoration(
                            border:
                                pw.Border(bottom: pw.BorderSide(width: 0.4)))),
                    pw.Text('Unterschrift Arbeitgeber',
                        style: const pw.TextStyle(fontSize: 5.5, color: _grau)),
                  ],
                ),
              ),
            ]),
            pw.SizedBox(height: 6),
            pw.Text('Form. 11 dfi  605.040.18N',
                style: const pw.TextStyle(fontSize: 6, color: _grau)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ── Bausteine ─────────────────────────────────────────────────────────

  static pw.Widget _kennzeichen(String buchstabe) => pw.SizedBox(
        width: _nrBreite,
        child: pw.Text(buchstabe,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _kaestchen({bool gekreuzt = false}) => pw.Container(
        width: 11,
        height: 11,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
            color: _feld, border: pw.Border.all(color: _linie, width: 0.4)),
        child: gekreuzt
            ? pw.Text('X',
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
            : null,
      );

  static pw.Widget _wertFeld(String text, {required double breite}) =>
      pw.Container(
        width: breite,
        height: 13,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        alignment: pw.Alignment.centerLeft,
        color: _feld,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  static pw.Widget _dreisprachig(String d, String f, String i,
          {bool rechts = false}) =>
      pw.Column(
        crossAxisAlignment:
            rechts ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(d, style: const pw.TextStyle(fontSize: 6, color: _grau)),
          pw.Text(f, style: const pw.TextStyle(fontSize: 6, color: _grau)),
          pw.Text(i, style: const pw.TextStyle(fontSize: 6, color: _grau)),
        ],
      );

  /// Eine Formularzeile: Ziffer · Bezeichnung (1–3 Sprachzeilen) · Zeichen ·
  /// Betragsfeld. Ohne [wert] bleibt das Feld leer (wie im Papierformular).
  static pw.Widget _zeile(
    String nr, {
    required String d,
    String? f,
    String? i,
    String zeichen = '',
    String? wert,
    bool fett = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: _nrBreite,
                child: pw.Text(nr,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight:
                            fett ? pw.FontWeight.bold : pw.FontWeight.normal))),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(d,
                      style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: fett
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal)),
                  if (f != null)
                    pw.Text(f,
                        style: const pw.TextStyle(fontSize: 6, color: _grau)),
                  if (i != null)
                    pw.Text(i,
                        style: const pw.TextStyle(fontSize: 6, color: _grau)),
                ],
              ),
            ),
            pw.SizedBox(
                width: _zeichenBreite,
                child: pw.Text(zeichen,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center)),
            pw.Container(
              width: _wertBreite,
              height: 13,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              alignment: pw.Alignment.centerRight,
              color: _feld,
              child: pw.Text(wert ?? '',
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          fett ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ],
        ),
      );
}
