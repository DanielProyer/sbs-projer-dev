import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

/// Eine Bewegung auf dem Kunden-Konto: Rechnung (Soll) oder Zahlung (Haben).
class _Bewegung {
  final DateTime datum;
  final String vorgang;
  final String beleg;
  final double soll; // Rechnung
  final double haben; // Zahlung/Abschreibung
  final String? status; // Kennzeichnung nur bei Rechnungszeilen
  _Bewegung({
    required this.datum,
    required this.vorgang,
    required this.beleg,
    this.soll = 0,
    this.haben = 0,
    this.status,
  });
}

/// Kontoauszug eines Betriebs: alle Rechnungen und Zahlungen chronologisch
/// mit laufendem Saldo — als professionelles A4-PDF (Briefkopf im Stil der
/// Rechnung). Gedacht als Grundlage für Mahn-Gespräche (Wunsch Daniel
/// 07.08.2026): Der Kunde sieht auf einen Blick, was fakturiert, was bezahlt
/// und was offen ist.
class KontoauszugPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFF4F4F4);
  static const _lineGrey = PdfColor.fromInt(0xFFCCCCCC);
  static const _rot = PdfColor.fromInt(0xFFB00020);
  static const _gruen = PdfColor.fromInt(0xFF1B5E20);

  static const _ibanFormatted = 'CH66 0077 4010 3765 5060 1';

  // Schweizer Schreibweise mit geradem Apostroph als Tausendertrennung
  // (einheitlich zu den übrigen Auswertungen; seit der eingebetteten
  // Unicode-Schrift wäre auch ’ möglich — siehe services/pdf/pdf_schrift.dart).
  static final _chf = NumberFormat('#,##0.00', 'en_US');
  static String _fmt(double v) => _chf.format(v).replaceAll(',', "'");

  static Future<Uint8List> generate({
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    BetriebRechnungsadresse? rechnungsadresse,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
  }) async {
    final pdf = await pdfDokument();
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Bewegungen aufbauen: je Rechnung eine Soll-Zeile; Zahlung bzw.
    // Abschreibung als Haben-Zeile am jeweiligen Datum.
    final bewegungen = <_Bewegung>[];
    double totalFakturiert = 0, totalZahlungen = 0, totalAbgeschrieben = 0;
    for (final r in rechnungen) {
      final nr = r.rechnungsnummer ?? '-';
      bewegungen.add(_Bewegung(
        datum: r.rechnungsdatum,
        vorgang: 'Rechnung',
        beleg: nr,
        soll: r.betragBrutto,
        status: _statusLabel(r),
      ));
      totalFakturiert += r.betragBrutto;
      if (r.zahlungsstatus == 'bezahlt') {
        final zBetrag = r.zahlungBetrag ?? r.betragBrutto;
        bewegungen.add(_Bewegung(
          datum: r.zahlungEingegangenAm ?? r.rechnungsdatum,
          vorgang: 'Zahlung',
          beleg: nr,
          haben: zBetrag,
        ));
        totalZahlungen += zBetrag;
      } else if (r.zahlungsstatus == 'abgeschrieben') {
        bewegungen.add(_Bewegung(
          datum: r.rechnungsdatum,
          vorgang: 'Abschreibung',
          beleg: nr,
          haben: r.betragBrutto,
        ));
        totalAbgeschrieben += r.betragBrutto;
      }
    }
    bewegungen.sort((a, b) {
      final d = a.datum.compareTo(b.datum);
      if (d != 0) return d;
      // Gleicher Tag: Rechnung vor Zahlung.
      return b.soll.compareTo(a.soll);
    });

    final offenerSaldo = totalFakturiert - totalZahlungen - totalAbgeschrieben;
    final offeneAnzahl = rechnungen
        .where((r) =>
            r.zahlungsstatus != 'bezahlt' && r.zahlungsstatus != 'abgeschrieben')
        .length;

    // Laufender Saldo je Zeile.
    final salden = <double>[];
    double lauf = 0;
    for (final b in bewegungen) {
      lauf += b.soll - b.haben;
      salden.add(lauf);
    }

    final heute = dateFormat.format(DateTime.now());
    final von = bewegungen.isEmpty
        ? heute
        : dateFormat.format(bewegungen.first.datum);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 48),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Kontoauszug ${betrieb.name} · Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        build: (ctx) => [
          _briefkopf(
            firmaName: firmaName,
            firmaStrasse: firmaStrasse,
            firmaPlzOrt: firmaPlzOrt,
            firmaMwst: firmaMwst,
          ),
          pw.SizedBox(height: 24),
          _adresseUndTitel(betrieb, rechnungsadresse, von, heute),
          pw.SizedBox(height: 18),
          _summenBlock(totalFakturiert, totalZahlungen, totalAbgeschrieben,
              offenerSaldo, offeneAnzahl),
          pw.SizedBox(height: 16),
          _tabelle(bewegungen, salden, dateFormat),
          pw.SizedBox(height: 18),
          _fusszeile(offenerSaldo),
        ],
      ),
    );

    return pdf.save();
  }

  static String? _statusLabel(Rechnung r) {
    switch (r.zahlungsstatus) {
      case 'bezahlt':
        return null; // Zahlung hat eigene Zeile
      case 'abgeschrieben':
        return null;
      case 'erinnert':
        return 'erinnert';
      case 'mahnung_1':
        return '1. Mahnung';
      case 'mahnung_2':
        return '2. Mahnung';
      default:
        return 'offen';
    }
  }

  static pw.Widget _briefkopf({
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
  }) {
    final name = firmaName ?? 'SBS Projer GmbH';
    final strasse = firmaStrasse ?? 'Via Rezia 8';
    final plzOrt = firmaPlzOrt ?? '7013 Domat/Ems';
    final mwst = (firmaMwst == null || firmaMwst.isEmpty)
        ? 'CHE-413.083.919 MWST'
        : firmaMwst;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(name,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkBlue)),
            pw.SizedBox(height: 4),
            pw.Text(strasse, style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text(plzOrt, style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.SizedBox(height: 4),
            pw.Text('Tel 076 566 58 06 | sbs.projer@gmail.com',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text(mwst, style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _darkBlue,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text('KONTOAUSZUG',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 1.5)),
        ),
      ],
    );
  }

  static pw.Widget _adresseUndTitel(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
    String von,
    String bis,
  ) {
    final zeilen = adressZeilen(
      betriebName: betrieb.name,
      betriebStrasse: betrieb.strasse,
      betriebNr: betrieb.nr,
      betriebPlz: betrieb.plz,
      betriebOrt: betrieb.ort,
      ra: ra,
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final z in zeilen)
              pw.Text(z, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
                'Objekt: ${betrieb.name}'
                    '${(betrieb.ort ?? '').isNotEmpty ? ', ${betrieb.ort}' : ''}',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
            // Bindestrich statt Gedankenstrich (–, U+2013): fehlt in der
            // eingebauten PDF-Schrift.
            pw.Text('Zeitraum: $von - $bis',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text('Erstellt am: $bis',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summenBlock(double fakturiert, double zahlungen,
      double abgeschrieben, double offen, int offeneAnzahl) {
    pw.Widget kachel(String label, String wert,
        {PdfColor farbe = _darkBlue, bool hebtHervor = false}) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: hebtHervor ? _darkBlue : _lightGrey,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 7.5,
                      color: hebtHervor ? PdfColors.grey300 : _grey,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 3),
              pw.Text(wert,
                  style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: hebtHervor ? PdfColors.white : farbe)),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        kachel('TOTAL FAKTURIERT', 'CHF ${_fmt(fakturiert)}'),
        kachel('TOTAL ZAHLUNGEN', 'CHF ${_fmt(zahlungen)}', farbe: _gruen),
        if (abgeschrieben > 0)
          kachel('ABSCHREIBUNGEN', 'CHF ${_fmt(abgeschrieben)}'),
        kachel(
          'OFFENER SALDO ($offeneAnzahl RG)',
          'CHF ${_fmt(offen)}',
          hebtHervor: true,
        ),
      ],
    );
  }

  static pw.Widget _tabelle(
    List<_Bewegung> bewegungen,
    List<double> salden,
    DateFormat dateFormat,
  ) {
    const headerStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColors.white,
    );
    const cellStyle = pw.TextStyle(fontSize: 8.5);
    const cellGrey = pw.TextStyle(fontSize: 8.5, color: _grey);

    pw.Widget zelle(String text,
        {pw.TextStyle style = cellStyle,
        pw.Alignment align = pw.Alignment.centerLeft}) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: style),
      );
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(58), // Datum
        1: const pw.FixedColumnWidth(72), // Vorgang
        2: const pw.FlexColumnWidth(), // Beleg
        3: const pw.FixedColumnWidth(58), // Status
        4: const pw.FixedColumnWidth(62), // Rechnung
        5: const pw.FixedColumnWidth(62), // Zahlung
        6: const pw.FixedColumnWidth(62), // Saldo
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _lineGrey, width: 0.4),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _darkBlue),
          children: [
            zelle('Datum', style: headerStyle),
            zelle('Vorgang', style: headerStyle),
            zelle('Beleg / Rechnung', style: headerStyle),
            zelle('Status', style: headerStyle),
            zelle('Rechnung CHF',
                style: headerStyle, align: pw.Alignment.centerRight),
            zelle('Zahlung CHF',
                style: headerStyle, align: pw.Alignment.centerRight),
            zelle('Saldo CHF',
                style: headerStyle, align: pw.Alignment.centerRight),
          ],
        ),
        for (var i = 0; i < bewegungen.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isOdd ? _lightGrey : PdfColors.white),
            children: [
              zelle(dateFormat.format(bewegungen[i].datum)),
              zelle(bewegungen[i].vorgang,
                  style: bewegungen[i].haben > 0 &&
                          bewegungen[i].vorgang == 'Zahlung'
                      ? const pw.TextStyle(fontSize: 8.5, color: _gruen)
                      : cellStyle),
              zelle(bewegungen[i].beleg, style: cellGrey),
              zelle(
                bewegungen[i].status ?? '',
                style: bewegungen[i].status == null ||
                        bewegungen[i].status == 'offen'
                    ? cellGrey
                    : const pw.TextStyle(fontSize: 8.5, color: _rot),
              ),
              zelle(bewegungen[i].soll > 0 ? _fmt(bewegungen[i].soll) : '',
                  align: pw.Alignment.centerRight),
              zelle(bewegungen[i].haben > 0 ? _fmt(bewegungen[i].haben) : '',
                  align: pw.Alignment.centerRight,
                  style: const pw.TextStyle(fontSize: 8.5, color: _gruen)),
              zelle(_fmt(salden[i]),
                  align: pw.Alignment.centerRight,
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: salden[i] > 0.005 ? _rot : _gruen)),
            ],
          ),
      ],
    );
  }

  static pw.Widget _fusszeile(double offen) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lineGrey, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            offen > 0.005
                ? 'Wir bitten um Überweisung des offenen Saldos von CHF ${_fmt(offen)} auf das untenstehende Konto. Bereits erfolgte Zahlungen sind in diesem Auszug berücksichtigt.'
                : 'Das Konto ist ausgeglichen - besten Dank.',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Zahlungsverbindung: Graubündner Kantonalbank · IBAN $_ibanFormatted · SBS Projer GmbH, Via Rezia 8, 7013 Domat/Ems',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    );
  }
}
