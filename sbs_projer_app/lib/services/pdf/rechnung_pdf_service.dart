import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';
import 'package:sbs_projer_app/services/pdf/qr_zahlteil.dart';
import 'package:sbs_projer_app/core/util/mwst_satz.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

/// Eine Zeile im Summenblock der Rechnung (rein, testbar).
class SummenZeile {
  final String label;
  final double betrag;
  final bool fett;

  /// Trennlinie über der Zeile.
  final bool linieDavor;

  const SummenZeile(
    this.label,
    this.betrag, {
    this.fett = false,
    this.linieDavor = false,
  });
}

class RechnungPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);
  static const _lineGrey = PdfColor.fromInt(0xFFCCCCCC);

  /// Generiert eine professionelle A4-Kundenrechnung mit QR-Zahlteil.
  /// [mitteilung] überschreibt den Standard-Buchungstext im QR-Zahlteil (Ustrd).
  /// [firmaName], [firmaStrasse], [firmaPlzOrt], [firmaMwst] überschreiben nur
  /// den Briefkopf (Letterhead). Alles andere (Telefon, Mail, MWST-Nr., IBAN
  /// und Empfänger im QR-Zahlteil) kommt aus [geschaeft] — eine Quelle für
  /// Briefkopf und Einzahlungsschein; ohne DB-Zeile die Rückfall-Konstanten.
  static Future<Uint8List> generate({
    required Rechnung rechnung,
    required List<RechnungsPosition> positionen,
    required BetriebLocal betrieb,
    BetriebRechnungsadresse? rechnungsadresse,
    String? mitteilung,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
    GeschaeftEinstellungen geschaeft = const GeschaeftEinstellungen(),
  }) async {
    final pdf = await pdfDokument();
    final dateFormat = DateFormat('dd.MM.yyyy');
    final zahlBetrag = qrBetrag(rechnung);

    // Positionen aufsteigend nach Position sortieren
    positionen = List.of(positionen)
      ..sort((a, b) => a.position.compareTo(b.position));

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
                    _buildHeader(
                      firmaName: firmaName,
                      firmaStrasse: firmaStrasse,
                      firmaPlzOrt: firmaPlzOrt,
                      firmaMwst: firmaMwst,
                      geschaeft: geschaeft,
                    ),
                    pw.SizedBox(height: 30),
                    _buildKundenAdresse(betrieb, rechnungsadresse),
                    pw.SizedBox(height: 30),
                    _buildRechnungsInfo(rechnung, betrieb, dateFormat),
                    pw.SizedBox(height: 20),
                    _buildPositionenTabelle(positionen),
                    pw.SizedBox(height: 16),
                    _buildSummen(rechnung),
                    pw.SizedBox(height: 20),
                    if (mitZahlteil(rechnung)) _buildZahlungsInfo(),
                  ],
                ),
              ),

              pw.Spacer(),

              if (guthabenHinweis(rechnung) != null)
                pw.Padding(
                  padding: pw.EdgeInsets.fromLTRB(
                      50, 0, 50, mitZahlteil(rechnung) ? 8 : 40),
                  child: pw.Text(
                    guthabenHinweis(rechnung)!,
                    style: mitZahlteil(rechnung)
                        ? const pw.TextStyle(fontSize: 9, color: _grey)
                        : pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              // === QR-ZAHLTEIL (untere 105mm) — entfällt, wenn das
              // Guthaben alles deckt (Review I2) ===
              if (mitZahlteil(rechnung))
                QrZahlteil.bauen(
                zahlBetrag,
                kundeAddr,
                geschaeft: geschaeft,
                mitteilung:
                    mitteilung ??
                    '${betrieb.ort ?? ''} - ${betrieb.name} - ${dateFormat.format(rechnung.rechnungsdatum)}',
                referenz: rechnung.qrReferenz,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── HEADER ───

  static pw.Widget _buildHeader({
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
    required GeschaeftEinstellungen geschaeft,
  }) {
    final displayName = firmaName ?? geschaeft.firma;
    final displayStrasse = firmaStrasse ?? geschaeft.adresseStrasse;
    final displayPlzOrt = firmaPlzOrt ?? geschaeft.adressePlzOrt;
    final mwstLeer = firmaMwst == null || firmaMwst.isEmpty;
    final displayMwst = mwstLeer ? geschaeft.mwstZeileOderFallback : firmaMwst;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          displayName,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _darkBlue,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          displayStrasse,
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
        pw.Text(
          displayPlzOrt,
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Tel ${geschaeft.telefonOrFallback} | ${geschaeft.mailGeschaeftOderFallback}',
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
        pw.Text(
          displayMwst,
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
      ],
    );
  }

  // ─── KUNDENADRESSE ───

  static pw.Widget _buildKundenAdresse(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
  ) {
    final lines = _adressZeilen(betrieb, ra);
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
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _infoValue(String text) {
    return pw.Text(text, style: const pw.TextStyle(fontSize: 9));
  }

  // ─── POSITIONSTABELLE ───

  static pw.Widget _buildPositionenTabelle(List<RechnungsPosition> positionen) {
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
                child: pw.Text(
                  'Pos',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  'Beschreibung',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 80,
                child: pw.Text(
                  'Betrag CHF',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        // Zeilen
        ...List.generate(positionen.length, (i) {
          final p = positionen[i];
          final isEven = i % 2 == 0;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _lightGrey,
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 35,
                  child: pw.Text(
                    '${p.position}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    p.beschreibung,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(
                    _chf(p.betragNetto),
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── SUMMEN ───

  /// Betrag auf dem QR-Zahlteil: was der Kunde zahlt (nach Verrechnung
  /// eines Kundenguthabens), auf 5 Rappen.
  static double qrBetrag(Rechnung rechnung) =>
      rundeAuf5Rappen(rechnung.zuZahlen);

  /// Zahlteil nur, wenn etwas zu zahlen ist — deckt das Guthaben alles,
  /// wäre ein Einzahlungsschein über 0.00 verwirrend (Review I2).
  static bool mitZahlteil(Rechnung rechnung) =>
      !(rechnung.guthabenVerrechnet > 0 && qrBetrag(rechnung) < 0.005);

  /// Satz über dem Zahlteil bei verrechnetem Guthaben, sonst null.
  static String? guthabenHinweis(Rechnung rechnung) {
    if (rechnung.guthabenVerrechnet <= 0) return null;
    return mitZahlteil(rechnung)
        ? 'Ihr Guthaben aus der Überzahlung wurde verrechnet.'
        : 'Vollständig mit Ihrem Guthaben verrechnet — nichts zu zahlen.';
  }

  /// Zeilen des Summenblocks. Bei verrechnetem Guthaben folgen auf «Total»
  /// der Abzug und fett «Zu zahlen» — Betrag, Ertrag und MWST der Rechnung
  /// bleiben unverändert.
  static List<SummenZeile> summenZeilen(Rechnung rechnung) {
    final satz =
        mwstProzentAusBetraegen(rechnung.betragNetto, rechnung.mwstBetrag);
    final zeilen = <SummenZeile>[
      SummenZeile('Netto', rechnung.betragNetto),
      SummenZeile('MwSt $satz%', rechnung.mwstBetrag),
      SummenZeile(
        'Total CHF',
        rundeAuf5Rappen(rechnung.betragBrutto),
        fett: true,
        linieDavor: true,
      ),
    ];
    if (rechnung.guthabenVerrechnet > 0) {
      zeilen.add(
        SummenZeile('abzüglich Kundenguthaben', -rechnung.guthabenVerrechnet),
      );
      zeilen.add(
        SummenZeile(
          'Zu zahlen CHF',
          qrBetrag(rechnung),
          fett: true,
          linieDavor: true,
        ),
      );
    }
    return zeilen;
  }

  static pw.Widget _buildSummen(Rechnung rechnung) {
    final kinder = <pw.Widget>[];
    for (final z in summenZeilen(rechnung)) {
      if (kinder.isNotEmpty) {
        if (z.linieDavor) {
          kinder.add(pw.SizedBox(height: 4));
          kinder.add(pw.Container(height: 1, color: _lineGrey));
          kinder.add(pw.SizedBox(height: 4));
        } else {
          kinder.add(pw.SizedBox(height: 3));
        }
      }
      if (z.fett) {
        final stil = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
        kinder.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(z.label, style: stil),
              pw.Text(_chf(z.betrag), style: stil),
            ],
          ),
        );
      } else {
        kinder.add(_summenRow(z.label, _chf(z.betrag)));
      }
    }
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(width: 200, child: pw.Column(children: kinder)),
    );
  }

  static pw.Widget _summenRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // ─── ZAHLUNGSINFO ───

  static pw.Widget _buildZahlungsInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Zahlbar innert 30 Tagen netto',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Vielen Dank für Ihren Auftrag!',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _darkBlue,
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ───

  static String _chf(double value) {
    return value.toStringAsFixed(2);
  }


  // Adressaufbau: siehe core/util/rechnungsadresse_zeilen.dart (eine Wahrheit
  // für Rechnung, Mahnung und Kontoauszug, per Test abgesichert).

  static List<String> _adressZeilen(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
  ) => adressZeilen(
    betriebName: betrieb.name,
    betriebStrasse: betrieb.strasse,
    betriebNr: betrieb.nr,
    betriebPlz: betrieb.plz,
    betriebOrt: betrieb.ort,
    ra: ra,
  );

  static QrEmpfaenger _getKundenAdressDaten(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
  ) => qrEmpfaenger(
    betriebName: betrieb.name,
    betriebStrasse: betrieb.strasse,
    betriebNr: betrieb.nr,
    betriebPlz: betrieb.plz,
    betriebOrt: betrieb.ort,
    ra: ra,
  );
}
