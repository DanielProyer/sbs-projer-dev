import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';

class ReinigungPdfService {
  static const _heinGreen = PdfColor.fromInt(0xFF008200);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFCCCCCC);

  /// Generiert das Heineken-Reinigungsprotokoll als PDF (FOR 1220/Vers.04)
  static Future<Uint8List> generate(ReinigungLocal reinigung) async {
    final betrieb =
        await BetriebRepository.getByServerId(reinigung.betriebId);
    final anlage =
        await AnlageRepository.getByServerId(reinigung.anlageId);

    // Logo laden (SVG)
    String? logoSvg;
    try {
      logoSvg = await rootBundle.loadString('assets/images/heineken_Logo.svg');
    } catch (_) {
      // Fallback: Text-Header
    }

    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // === HEADER ===
              _buildHeader(logoSvg),
              pw.SizedBox(height: 6),

              // === FIRMENDATEN + KUNDENDATEN ===
              _buildInfoSection(reinigung, betrieb, anlage, dateFormat),
              pw.SizedBox(height: 10),

              // === CHECKLISTE ===
              _buildCheckliste(reinigung),
              pw.SizedBox(height: 10),

              // === ARTIKELTABELLE ===
              _buildArtikeltabelle(reinigung),
              pw.SizedBox(height: 8),

              // === ZAHLUNGSINFO + UNTERSCHRIFTEN ===
              _buildFooterSection(reinigung, betrieb, dateFormat),

              pw.Spacer(),

              // === FOOTER ===
              _buildDocFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── HEADER ───

  static pw.Widget _buildHeader(String? logoSvg) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Heineken Logo (links)
        pw.Expanded(
          flex: 3,
          child: logoSvg != null
              ? pw.SvgImage(svg: logoSvg, height: 40)
              : pw.Text(
                  'HEINEKEN',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: _heinGreen,
                  ),
                ),
        ),
        // Swiss Beverage Services (rechts)
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            'Swiss Beverage Services',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ─── INFO SECTION (Firma links, Kunde rechts) ───

  static pw.Widget _buildInfoSection(
    ReinigungLocal r,
    BetriebLocal? betrieb,
    AnlageLocal? anlage,
    DateFormat dateFormat,
  ) {
    final isHeigenie = r.serviceTyp == 'heigenie';
    final kundenNr = betrieb?.betriebNr ?? '';
    final absatzstelle = anlage?.bezeichnung ?? anlage?.typAnlage ?? '';
    final kontakt = r.unterschriftKundeName ?? '';
    final plzOrt = betrieb != null
        ? [betrieb.plz, betrieb.ort].where((s) => s != null && s.isNotEmpty).join(' ')
        : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reinigungsprotokoll Quittung/Faktura',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _heinGreen,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Linke Spalte: Firmendaten
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SBS Projer GmbH',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('7013 Domat / Ems',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text('Telefon: 076 566 58 06',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text('CHE-413.083.919 MWST',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text('Ansatz MWST: 8.1%',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            // Rechte Spalte: Kundendaten
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Heigenie / Traditional
                  pw.Row(children: [
                    _radioCircle(isHeigenie),
                    pw.SizedBox(width: 3),
                    pw.Text('Heigenie', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(width: 12),
                    _radioCircle(!isHeigenie),
                    pw.SizedBox(width: 3),
                    pw.Text('Traditional',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.SizedBox(height: 6),
                  _labeledField('Kunden-Nr.:', kundenNr),
                  pw.SizedBox(height: 4),
                  _labeledField('Absatzstelle:', absatzstelle),
                  pw.SizedBox(height: 4),
                  _labeledField('Name / Vorname:', kontakt),
                  pw.SizedBox(height: 4),
                  _labeledField('PLZ / Ortschaft:', plzOrt),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _radioCircle(bool filled) {
    if (filled) {
      return pw.Container(
        width: 8,
        height: 8,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(width: 0.5),
          color: PdfColors.black,
        ),
      );
    }
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(width: 0.5),
      ),
    );
  }

  static pw.Widget _labeledField(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 0.5, color: _lightGrey),
              ),
            ),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ),
      ],
    );
  }

  // ─── CHECKLISTE ───

  static pw.Widget _buildCheckliste(ReinigungLocal r) {
    final items = [
      ('Durchlaufkühler', r.hatDurchlaufkuehler),
      ('Buffetanstich', r.hatBuffetanstich),
      ('Kühlkeller', r.hatKuehlkeller),
      ('Fasskühler', r.hatFasskuehler),
      ('Begleitkühlung kontrolliert', r.begleitkuehlungKontrolliert),
      ('Installation allg. kontrolliert', r.installationAllgemeinKontrolliert),
      ('Aligal Anschlüsse kontrolliert', r.aligalAnschluesseKontrolliert),
      ('Durchlaufkühler ausgeblasen', r.durchlaufkuehlerAusgeblasen),
      ('Wasserstand kontrolliert', r.wasserstandKontrolliert),
      ('Wasser im Durchlaufkühler gewechselt', r.wasserGewechselt),
      ('Leitung mit Wasser vorgespült', r.leitungWasserVorgespuelt),
      ('Leitungsreinigung mit Reinigungsmittel',
          r.leitungsreinigungReinigungsmittel),
      ('Förderdruck kontrolliert', r.foerderdruckKontrolliert),
      ('Zapfhahn zerlegt und gereinigt', r.zapfhahnZerlegtGereinigt),
      ('Zapfkopf zerlegt, gereinigt', r.zapfkopfZerlegtGereinigt),
      ('Servicekarte ausgefüllt', r.servicekarteAusgefuellt),
    ];

    // Beanstandungen aus JSON
    Map<String, String> notizen = {};
    if (r.checklisteNotizenJson != null) {
      try {
        notizen = Map<String, String>.from(
            jsonDecode(r.checklisteNotizenJson!));
      } catch (_) {}
    }

    // Keys für Notizen-Lookup (gleiche Reihenfolge wie items)
    final notizenKeys = [
      'hat_durchlaufkuehler',
      'hat_buffetanstich',
      'hat_kuehlkeller',
      'hat_fasskuehler',
      'begleitkuehlung_kontrolliert',
      'installation_allgemein_kontrolliert',
      'aligal_anschluesse_kontrolliert',
      'durchlaufkuehler_ausgeblasen',
      'wasserstand_kontrolliert',
      'wasser_gewechselt',
      'leitung_wasser_vorgespuelt',
      'leitungsreinigung_reinigungsmittel',
      'foerderdruck_kontrolliert',
      'zapfhahn_zerlegt_gereinigt',
      'zapfkopf_zerlegt_gereinigt',
      'servicekarte_ausgefuellt',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(children: [
          pw.Expanded(
            flex: 6,
            child: pw.Text('Ausgeführte Arbeiten',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(
            width: 30,
            child: pw.Text('Ja',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(
            width: 30,
            child: pw.Text('Nein',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text('Beanstandung:',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ]),
        pw.SizedBox(height: 2),
        // Zeilen
        ...List.generate(items.length, (i) {
          final beanstandung = notizen[notizenKeys[i]] ?? '';
          return _checklistRow(items[i].$1, items[i].$2, beanstandung);
        }),
        // Leerzeile (17. Zeile)
        _checklistRow('', false, ''),
      ],
    );
  }

  static pw.Widget _checklistRow(
      String label, bool checked, String beanstandung) {
    return pw.Container(
      height: 16,
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.SizedBox(
            width: 30,
            child: pw.Center(
              child: checked
                  ? pw.Text('\u2713',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold))
                  : pw.Text('O', style: const pw.TextStyle(fontSize: 8)),
            ),
          ),
          pw.SizedBox(
            width: 30,
            child: pw.Center(
              child: pw.Text('O', style: const pw.TextStyle(fontSize: 8)),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.3, color: _lightGrey),
                ),
              ),
              child: pw.Text(beanstandung,
                  style: const pw.TextStyle(fontSize: 7)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ARTIKELTABELLE ───

  static pw.Widget _buildArtikeltabelle(ReinigungLocal r) {
    final rows = <_ArtikelRow>[
      _ArtikelRow(
        '38457',
        'Reinigung Bier',
        r.serviceTyp == 'reinigung_bier' ? '1' : '',
        r.serviceTyp == 'reinigung_bier' ? _chf(r.preisGrundtarif) : '',
      ),
      _ArtikelRow(
        '28001',
        'Grundtarif Reinigung Orion Bier',
        r.serviceTyp == 'reinigung_orion' ? '1' : '',
        r.serviceTyp == 'reinigung_orion' ? _chf(r.preisGrundtarif) : '',
      ),
      _ArtikelRow(
        '6000',
        'Service Offenausschank Heigenie',
        r.serviceTyp == 'heigenie' ? '1' : '',
        r.serviceTyp == 'heigenie' ? 'Gem.Leihvertrag' : '',
      ),
      _ArtikelRow(
        '28001',
        'Grundtarif Reinigung fremd',
        r.serviceTyp == 'reinigung_fremd' ? '1' : '',
        r.serviceTyp == 'reinigung_fremd' ? _chf(r.preisGrundtarif) : '',
      ),
      _ArtikelRow(
        '28001',
        'Zusätzlicher Hahnen Orion',
        r.anzahlHaehneOrion > 0 ? '${r.anzahlHaehneOrion}' : '',
        r.anzahlHaehneOrion > 0 ? _chf(r.anzahlHaehneOrion * 18.0) : '',
      ),
      _ArtikelRow(
        '28001',
        'Zusätzlicher Hahnen fremd',
        r.anzahlHaehneFremd > 0 ? '${r.anzahlHaehneFremd}' : '',
        r.anzahlHaehneFremd > 0 ? _chf(r.anzahlHaehneFremd * 23.0) : '',
      ),
      _ArtikelRow(
        '28001',
        'Grundtarif Wein',
        r.serviceTyp == 'wein' ? '1' : '',
        r.serviceTyp == 'wein' ? _chf(r.preisGrundtarif) : '',
      ),
      _ArtikelRow(
        '28001',
        'Zusätzlicher Hahn Wein',
        r.anzahlHaehneWein > 0 ? '${r.anzahlHaehneWein}' : '',
        r.anzahlHaehneWein > 0 ? _chf(r.anzahlHaehneWein * 23.0) : '',
      ),
      _ArtikelRow(
        '28001',
        'Zusätzlicher Hahn zweite Anlage anderer Standort',
        r.anzahlHaehneAndererStandort > 0
            ? '${r.anzahlHaehneAndererStandort}'
            : '',
        r.anzahlHaehneAndererStandort > 0
            ? _chf(r.anzahlHaehneAndererStandort * 30.0)
            : '',
      ),
      _ArtikelRow(
        '28001',
        'Weitere zusätzliche Leitungen',
        r.anzahlHaehneEigen > 0 ? '${r.anzahlHaehneEigen}' : '',
        r.anzahlHaehneEigen > 0 ? _chf(r.anzahlHaehneEigen * 18.0) : '',
      ),
    ];

    return pw.Column(
      children: [
        // Header
        pw.Row(children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text('Art. Nr.',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text('Artikelbezeichnung',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(
            width: 50,
            child: pw.Text('Menge',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text('Preis',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right),
          ),
        ]),
        pw.SizedBox(height: 2),
        // Zeilen
        ...rows.map((row) => pw.Container(
              height: 14,
              child: pw.Row(children: [
                pw.SizedBox(
                  width: 45,
                  child: pw.Text(row.artNr,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Expanded(
                  child: pw.Text(row.bezeichnung,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(
                  width: 50,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom:
                              pw.BorderSide(width: 0.3, color: _lightGrey)),
                    ),
                    child: pw.Text(row.menge,
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center),
                  ),
                ),
                pw.SizedBox(
                  width: 70,
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom:
                              pw.BorderSide(width: 0.3, color: _lightGrey)),
                    ),
                    child: pw.Text(row.preis,
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                ),
              ]),
            )),
        // Leerzeile
        pw.Container(
          height: 14,
          child: pw.Row(children: [
            pw.SizedBox(
              width: 45,
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 0.3, color: _lightGrey)),
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 0.3, color: _lightGrey)),
                ),
              ),
            ),
            pw.SizedBox(
              width: 50,
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 0.3, color: _lightGrey)),
                ),
              ),
            ),
            pw.SizedBox(
              width: 70,
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(width: 0.3, color: _lightGrey)),
                ),
              ),
            ),
          ]),
        ),
        // Total
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total (inkl. ${r.mwstSatz?.toStringAsFixed(1) ?? '8.1'}% Mwst.)',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 70,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5, color: _lightGrey)),
              ),
              child: pw.Text(
                r.preisBrutto != null
                    ? _chf(_roundTo5Rappen(r.preisBrutto!))
                    : '',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── FOOTER SECTION (Zahlung + Unterschriften) ───

  static pw.Widget _buildFooterSection(
    ReinigungLocal r,
    BetriebLocal? betrieb,
    DateFormat dateFormat,
  ) {
    final isBarzahlung = betrieb?.rechnungsstellung == 'barzahlung';
    final datumStr = dateFormat.format(r.datum);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Linke Spalte: Zahlungsinfo
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('Auf Rechnung: ',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(isBarzahlung ? 'O' : '\u2713',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text('Zahlbar innert 30 Tagen netto',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Row(children: [
                pw.Text('Datum:', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: 100,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom:
                            pw.BorderSide(width: 0.3, color: _lightGrey)),
                  ),
                  child: pw.Text(!isBarzahlung ? datumStr : '',
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('Auf Barzahlung: ',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(isBarzahlung ? '\u2713' : 'O',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text('Betrag dankend erhalten',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Row(children: [
                pw.Text('Datum:', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: 100,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom:
                            pw.BorderSide(width: 0.3, color: _lightGrey)),
                  ),
                  child: pw.Text(isBarzahlung ? datumStr : '',
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ]),
            ],
          ),
        ),
        // Rechte Spalte: Unterschriften
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 4),
              // Unterschrift Kunde
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Unterschrift Kunde: ',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Expanded(
                    child: r.unterschriftKunde != null
                        ? pw.Container(
                            height: 30,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(
                                      width: 0.3, color: _lightGrey)),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(
                                  base64Decode(r.unterschriftKunde!)),
                              fit: pw.BoxFit.contain,
                              height: 28,
                            ),
                          )
                        : pw.Container(
                            height: 30,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(
                                      width: 0.3, color: _lightGrey)),
                            ),
                          ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              // Unterschrift Servicemonteur
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Unterschrift Servicemonteur: ',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Expanded(
                    child: r.unterschriftTechniker != null
                        ? pw.Container(
                            height: 30,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(
                                      width: 0.3, color: _lightGrey)),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(
                                  base64Decode(r.unterschriftTechniker!)),
                              fit: pw.BoxFit.contain,
                              height: 28,
                            ),
                          )
                        : pw.Container(
                            height: 30,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(
                                      width: 0.3, color: _lightGrey)),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DOCUMENT FOOTER ───

  static pw.Widget _buildDocFooter() {
    final now = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return pw.Row(
      children: [
        pw.Text('FOR 1220/Vers.04',
            style: pw.TextStyle(fontSize: 7, color: _grey)),
        pw.Spacer(),
        pw.Text('1/1', style: pw.TextStyle(fontSize: 7, color: _grey)),
        pw.Spacer(),
        pw.Text(now, style: pw.TextStyle(fontSize: 7, color: _grey)),
      ],
    );
  }

  // ─── HELPERS ───

  static String _chf(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(2);
  }

  static double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }
}

class _ArtikelRow {
  final String artNr;
  final String bezeichnung;
  final String menge;
  final String preis;

  _ArtikelRow(this.artNr, this.bezeichnung, this.menge, this.preis);
}
