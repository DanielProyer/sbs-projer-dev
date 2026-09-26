import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';
import 'package:sbs_projer_app/services/pdf/qr_zahlteil.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

/// Eine Bewegung auf dem Kunden-Konto: Rechnung (Soll) oder Zahlung (Haben).
class _Bewegung {
  final DateTime datum;
  final String vorgang;
  final String beleg;
  final double soll; // Rechnung
  final double haben; // Zahlung/Abschreibung
  final String? status; // Kennzeichnung nur bei Rechnungszeilen

  /// Wie die Rechnung zum Kunden kam, z. B. «EZS am Tresen · 17.09.2026».
  /// Nur bei Rechnungszeilen gesetzt.
  final String? zustellung;

  _Bewegung({
    required this.datum,
    required this.vorgang,
    required this.beleg,
    this.soll = 0,
    this.haben = 0,
    this.status,
    this.zustellung,
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

  // Schweizer Schreibweise mit geradem Apostroph als Tausendertrennung
  // (einheitlich zu den übrigen Auswertungen; seit der eingebetteten
  // Unicode-Schrift wäre auch ’ möglich — siehe services/pdf/pdf_schrift.dart).
  static final _chf = NumberFormat('#,##0.00', 'en_US');
  static String _fmt(double v) => _chf.format(v).replaceAll(',', "'");

  /// Wie die Rechnung zum Kunden kam, für die Belegspalte:
  /// «EZS am Tresen · 17.09.2026», «Per E-Mail · 14.09.2026».
  ///
  /// WARUM im Auszug (Wunsch Daniel 21.09.2026): Am Tresen übergeben und per
  /// Mail versendet sind zwei verschiedene Gespräche. Steht es nicht auf dem
  /// Papier, muss man für jede Zeile in die App zurück.
  ///
  /// Ohne hinterlegtes Datum steht nur der Weg. Ein «kein Zustelldatum» wäre
  /// auf einem Kundendokument eine Behauptung über den Kunden, obwohl es eine
  /// Lücke in UNSERER Erfassung ist. Für Daniel ist die Lücke trotzdem
  /// sichtbar — am fehlenden Datum, und in der App orange hervorgehoben.
  static String? zustellungKurz(Rechnung r, DateFormat df) {
    final weg = switch (r.versandart) {
      'rechnung_tresen' => 'EZS am Tresen',
      'rechnung_mail' => 'Per E-Mail',
      'rechnung_post' => 'Per Post',
      'barzahlung' => 'Bar bezahlt',
      'jahresrechnung' => 'Jahresrechnung',
      'heineken' => 'Via Heineken',
      null || '' => null,
      _ => r.versandart,
    };
    if (weg == null) return null;
    // Tresen wird übergeben, Mail und Post versendet — je nach Weg zählt ein
    // anderes Datum. Liegen beide vor, gewinnt das spätere Ereignis.
    final datum = r.versandart == 'rechnung_tresen'
        ? (r.uebergebenAm ?? r.versendetAm)
        : (r.versendetAm ?? r.uebergebenAm);
    return datum == null ? weg : '$weg · ${df.format(datum)}';
  }

  /// Schneidet die Rechnungen auf ein Kalenderjahr zu (nach `rechnungsdatum`).
  /// null = alles. Eigene Funktion, damit die Auswahl prüfbar ist, ohne ein
  /// PDF zerlegen zu müssen — `test/kontoauszug_jahr_test.dart`.
  static List<Rechnung> fuerJahr(List<Rechnung> rechnungen, int? jahr) =>
      jahr == null
      ? rechnungen
      : rechnungen.where((r) => r.rechnungsdatum.year == jahr).toList();

  /// Bewegungen samt Summen (rein). Je Rechnung eine Soll-Zeile; Zahlung
  /// bzw. Abschreibung als Haben-Zeile am jeweiligen Datum; verrechnetes
  /// Kundenguthaben (v0.137.0) als eigene Haben-Zeile am Rechnungsdatum.
  static ({
    List<_Bewegung> bewegungen,
    double fakturiert,
    double zahlungen,
    double verrechnet,
    double abgeschrieben,
  }) _aufstellung(List<Rechnung> gefiltert, DateFormat dateFormat) {
    final bewegungen = <_Bewegung>[];
    double totalFakturiert = 0,
        totalZahlungen = 0,
        totalVerrechnet = 0,
        totalAbgeschrieben = 0;
    for (final r in gefiltert) {
      final nr = r.rechnungsnummer ?? '-';
      bewegungen.add(
        _Bewegung(
          datum: r.rechnungsdatum,
          vorgang: 'Rechnung',
          beleg: nr,
          soll: r.betragBrutto,
          status: _statusLabel(r),
          zustellung: zustellungKurz(r, dateFormat),
        ),
      );
      totalFakturiert += r.betragBrutto;
      if (r.guthabenVerrechnet > 0) {
        bewegungen.add(
          _Bewegung(
            datum: r.rechnungsdatum,
            vorgang: 'Verrechnung Guthaben',
            beleg: nr,
            haben: r.guthabenVerrechnet,
          ),
        );
        totalVerrechnet += r.guthabenVerrechnet;
      }
      if (r.zahlungsstatus == 'bezahlt') {
        final zBetrag = r.zahlungBetrag ?? r.zuZahlen;
        bewegungen.add(
          _Bewegung(
            datum: r.zahlungEingegangenAm ?? r.rechnungsdatum,
            vorgang: 'Zahlung',
            beleg: nr,
            haben: zBetrag,
          ),
        );
        totalZahlungen += zBetrag;
      } else if (r.zahlungsstatus == 'abgeschrieben') {
        bewegungen.add(
          _Bewegung(
            datum: r.rechnungsdatum,
            vorgang: 'Abschreibung',
            beleg: nr,
            haben: r.zuZahlen,
          ),
        );
        totalAbgeschrieben += r.zuZahlen;
      }
    }
    bewegungen.sort((a, b) {
      final d = a.datum.compareTo(b.datum);
      if (d != 0) return d;
      // Gleicher Tag: Rechnung vor Zahlung.
      return b.soll.compareTo(a.soll);
    });
    return (
      bewegungen: bewegungen,
      fakturiert: totalFakturiert,
      zahlungen: totalZahlungen,
      verrechnet: totalVerrechnet,
      abgeschrieben: totalAbgeschrieben,
    );
  }

  /// Rein, für Tests: die Zeilen des Auszugs (Vorgang, Soll, Haben) und der
  /// offene Saldo.
  static ({
    List<({String vorgang, double soll, double haben})> zeilen,
    double offen,
  }) auszugZeilen(List<Rechnung> rechnungen, {int? jahr}) {
    final a = _aufstellung(fuerJahr(rechnungen, jahr), DateFormat('dd.MM.yyyy'));
    return (
      zeilen: [
        for (final b in a.bewegungen)
          (vorgang: b.vorgang, soll: b.soll, haben: b.haben),
      ],
      offen: a.fakturiert - a.zahlungen - a.verrechnet - a.abgeschrieben,
    );
  }

  /// [jahr] grenzt den Auszug auf ein Kalenderjahr ein (nach `rechnungsdatum`).
  /// null = alles. Aufrufer: die Betriebsseite (eigenständiger Auszug) UND
  /// `MahnlaufService` (Beilage zur Mahn-Mail, mit `muster`/`mitZahlteil:
  /// false` — siehe dort).
  ///
  /// Gefiltert wird BEWUSST hier drin und nicht beim Aufrufer: Sonst könnten
  /// Inhalt und die Zeitraum-Angabe im Kopf auseinanderlaufen, und das Papier
  /// behauptete einen Zeitraum, den es nicht zeigt.
  ///
  /// [muster] und [mitZahlteil] werden unverändert an [seitenHinzufuegen]
  /// durchgereicht (Doku dort).
  static Future<Uint8List> generate({
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    BetriebRechnungsadresse? rechnungsadresse,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
    GeschaeftEinstellungen geschaeft = const GeschaeftEinstellungen(),
    int? jahr,
    bool muster = false,
    bool mitZahlteil = true,
  }) async {
    final pdf = await pdfDokument();
    await seitenHinzufuegen(
      pdf,
      betrieb: betrieb,
      rechnungen: rechnungen,
      rechnungsadresse: rechnungsadresse,
      firmaName: firmaName,
      firmaStrasse: firmaStrasse,
      firmaPlzOrt: firmaPlzOrt,
      firmaMwst: firmaMwst,
      geschaeft: geschaeft,
      jahr: jahr,
      muster: muster,
      mitZahlteil: mitZahlteil,
    );
    return pdf.save();
  }

  /// Hängt die Seiten des Kontoauszugs an [pdf] an — für das Druck-PDF des
  /// Mahnschreibens (v0.134.0), das Schreiben und Auszug in EINEM Dokument
  /// braucht. [generate] ruft das mit einem eigenen Dokument auf.
  ///
  /// [muster] überlagert jede Seite mit einem «MUSTER»-Wasserzeichen — für
  /// Kontoauszug-Seiten, die einem Mahnschreiben-MUSTER beiliegen.
  ///
  /// [mitZahlteil] steuert den Einzahlungsschein über den Gesamtsaldo
  /// (Default `true`, bisheriges Verhalten für den eigenständigen Auszug).
  /// Das Mahnschreiben (v0.134.0) übergibt `false`: Es hat bereits einen
  /// eigenen Zahlteil PRO RECHNUNG; ein zweiter, summierter Zahlteil über
  /// denselben Gesamtbetrag wäre eine zweite Zahlungsaufforderung — eine
  /// Doppelzahlung wäre möglich, und der camt-Abgleich fände eine Zahlung,
  /// die zu keiner Einzelrechnung passt (Review 23.09.2026).
  ///
  /// Rückgabe: Anzahl der tatsächlich gebauten Zahlteile (0 oder 1) — rein
  /// zu Prüfzwecken (`test/mahnschreiben_pdf_test.dart` zählt sie, um den
  /// fehlenden Sammel-Zahlteil im Mahn-PDF nachzuweisen).
  static Future<int> seitenHinzufuegen(
    pw.Document pdf, {
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    BetriebRechnungsadresse? rechnungsadresse,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
    GeschaeftEinstellungen geschaeft = const GeschaeftEinstellungen(),
    int? jahr,
    bool muster = false,
    bool mitZahlteil = true,
  }) async {
    final dateFormat = DateFormat('dd.MM.yyyy');

    final gefiltert = fuerJahr(rechnungen, jahr);

    // Bewegungen aufbauen (rein, siehe [_aufstellung]).
    final auf = _aufstellung(gefiltert, dateFormat);
    final bewegungen = auf.bewegungen;
    final totalFakturiert = auf.fakturiert;
    final totalZahlungen = auf.zahlungen;
    final totalVerrechnet = auf.verrechnet;
    final totalAbgeschrieben = auf.abgeschrieben;

    final offenerSaldo =
        totalFakturiert - totalZahlungen - totalVerrechnet - totalAbgeschrieben;
    // Über `gefiltert`, nicht über `rechnungen`: Sonst nennt die Kachel
    // «OFFENER SALDO (n RG)» beim Jahresauszug die Anzahl ALLER offenen
    // Rechnungen, während der Betrag daneben nur das Jahr umfasst — zwei
    // Zahlen, die nicht zusammengehören. Ohne Jahresangabe ist beides
    // identisch, das bisherige Verhalten ändert sich also nicht.
    final offeneAnzahl = gefiltert
        .where(
          (r) =>
              r.zahlungsstatus != 'bezahlt' &&
              r.zahlungsstatus != 'abgeschrieben',
        )
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
    // Beim Jahresauszug das ganze Kalenderjahr nennen, nicht die erste
    // Bewegung — sonst liest sich «Zeitraum: 14.03.2026 - 21.09.2026» wie eine
    // willkürliche Auswahl statt wie ein Jahresauszug.
    final zeitraum = jahr == null
        ? '$von - $heute'
        : '01.01.$jahr - 31.12.$jahr';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: musterPageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 48),
          muster: muster,
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Kontoauszug ${betrieb.name}${jahr == null ? '' : ' $jahr'} '
            '· Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        build: (ctx) => [
          _briefkopf(
            firmaName: firmaName,
            firmaStrasse: firmaStrasse,
            firmaPlzOrt: firmaPlzOrt,
            firmaMwst: firmaMwst,
            geschaeft: geschaeft,
          ),
          pw.SizedBox(height: 24),
          _adresseUndTitel(betrieb, rechnungsadresse, zeitraum, heute),
          pw.SizedBox(height: 18),
          _summenBlock(
            totalFakturiert,
            totalZahlungen,
            totalAbgeschrieben,
            offenerSaldo,
            offeneAnzahl,
            verrechnet: totalVerrechnet,
          ),
          pw.SizedBox(height: 16),
          _tabelle(bewegungen, salden, dateFormat),
          pw.SizedBox(height: 18),
          _fusszeile(offenerSaldo, jahr, geschaeft, mitZahlteil: mitZahlteil),
        ],
      ),
    );

    // Einzahlungsschein auf einer eigenen Seite. Der Zahlteil braucht die
    // unteren 105 mm einer randlosen A4-Seite; der Auszug selbst läuft über
    // beliebig viele Seiten mit Rand. Beides auf derselben Seite ginge nur mit
    // reserviertem Fussraum auf JEDER Seite — die eigene Seite ist die
    // normkonforme und im Alltag übliche Lösung (Perforation).
    // Auf 5 Rappen — ein Einzahlungsschein über 113.47 wäre nicht bezahlbar.
    final zahlbar = rundeAuf5Rappen(offenerSaldo);
    if (!mitZahlteil || zahlbar <= 0) {
      return 0;
    }

    pdf.addPage(
      pw.Page(
        pageTheme: musterPageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          muster: muster,
        ),
        build: (ctx) => pw.Column(
          children: [
            pw.Spacer(),
            QrZahlteil.bauen(
              zahlbar,
              qrEmpfaenger(
                betriebName: betrieb.name,
                betriebStrasse: betrieb.strasse,
                betriebNr: betrieb.nr,
                betriebPlz: betrieb.plz,
                betriebOrt: betrieb.ort,
                ra: rechnungsadresse,
              ),
              mitteilung:
                  'Kontoauszug${jahr == null ? '' : ' $jahr'} - '
                  '${betrieb.name}',
              referenz: einzelReferenz(gefiltert),
            ),
          ],
        ),
      ),
    );
    return 1;
  }


  /// Die Referenz für den Einzahlungsschein. Öffentlich, damit die Regel
  /// prüfbar ist — `test/kontoauszug_jahr_test.dart`.
  ///
  /// Entscheid Daniel (21.09.2026): **Nur wenn genau EINE Rechnung offen ist**,
  /// trägt der Schein deren Referenz — dann ordnet der camt-Abgleich die
  /// Zahlung automatisch zu, wie bei einer normalen Rechnung.
  ///
  /// Sind mehrere offen, bleibt der Schein bewusst ohne Referenz. Die Referenz
  /// einer einzelnen Rechnung zu nehmen wäre schlimmer als keine: Die Zahlung
  /// würde vollständig auf jene eine Rechnung gebucht, die übrigen blieben
  /// offen, und der Fehler fiele erst bei der nächsten Mahnung auf. Ohne
  /// Referenz ordnet man von Hand zu — sichtbar und richtig.
  static String? einzelReferenz(List<Rechnung> gefiltert) {
    final offen = gefiltert
        .where(
          (r) =>
              r.zahlungsstatus != 'bezahlt' &&
              r.zahlungsstatus != 'abgeschrieben',
        )
        .toList();
    if (offen.length != 1) return null;
    final ref = offen.single.qrReferenz;
    return (ref == null || ref.isEmpty) ? null : ref;
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
    required GeschaeftEinstellungen geschaeft,
  }) {
    final name = firmaName ?? geschaeft.firma;
    final strasse = firmaStrasse ?? geschaeft.adresseStrasse;
    final plzOrt = firmaPlzOrt ?? geschaeft.adressePlzOrt;
    final mwst = (firmaMwst == null || firmaMwst.isEmpty)
        ? geschaeft.mwstZeileOderFallback
        : firmaMwst;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _darkBlue,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              strasse,
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            pw.Text(
              plzOrt,
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Tel ${geschaeft.telefonOrFallback} | ${geschaeft.mailGeschaeftOderFallback}',
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            pw.Text(mwst, style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _darkBlue,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'KONTOAUSZUG',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _adresseUndTitel(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
    String zeitraum,
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
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            // Bindestrich statt Gedankenstrich (–, U+2013): fehlt in der
            // eingebauten PDF-Schrift.
            pw.Text(
              'Zeitraum: $zeitraum',
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            pw.Text(
              'Erstellt am: $bis',
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summenBlock(
    double fakturiert,
    double zahlungen,
    double abgeschrieben,
    double offen,
    int offeneAnzahl, {
    double verrechnet = 0,
  }) {
    pw.Widget kachel(
      String label,
      String wert, {
      PdfColor farbe = _darkBlue,
      bool hebtHervor = false,
    }) {
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
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: hebtHervor ? PdfColors.grey300 : _grey,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                wert,
                style: pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  color: hebtHervor ? PdfColors.white : farbe,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        kachel('TOTAL FAKTURIERT', 'CHF ${_fmt(fakturiert)}'),
        kachel('TOTAL ZAHLUNGEN', 'CHF ${_fmt(zahlungen)}', farbe: _gruen),
        if (verrechnet > 0)
          kachel('GUTHABEN VERRECHNET', 'CHF ${_fmt(verrechnet)}',
              farbe: _gruen),
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
    const headerStyle = pw.TextStyle(fontSize: 8, color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 8.5);
    const cellGrey = pw.TextStyle(fontSize: 8.5, color: _grey);

    pw.Widget zelle(
      String text, {
      pw.TextStyle style = cellStyle,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: style),
      );
    }

    /// Belegnummer und darunter der Zustellweg. Zweizeilig statt als eigene
    /// Spalte: Für eine achte Spalte reicht die A4-Breite nicht, ohne die
    /// Belegnummer umbrechen zu lassen.
    pw.Widget belegZelle(String beleg, String? zustellung) {
      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(beleg, style: cellGrey),
            if (zustellung != null)
              pw.Text(
                zustellung,
                style: const pw.TextStyle(fontSize: 7, color: _grey),
              ),
          ],
        ),
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
            zelle('Beleg / Zustellung', style: headerStyle),
            zelle('Status', style: headerStyle),
            zelle(
              'Rechnung CHF',
              style: headerStyle,
              align: pw.Alignment.centerRight,
            ),
            zelle(
              'Zahlung CHF',
              style: headerStyle,
              align: pw.Alignment.centerRight,
            ),
            zelle(
              'Saldo CHF',
              style: headerStyle,
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
        for (var i = 0; i < bewegungen.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _lightGrey : PdfColors.white,
            ),
            children: [
              zelle(dateFormat.format(bewegungen[i].datum)),
              zelle(
                bewegungen[i].vorgang,
                style:
                    bewegungen[i].haben > 0 &&
                        bewegungen[i].vorgang == 'Zahlung'
                    ? const pw.TextStyle(fontSize: 8.5, color: _gruen)
                    : cellStyle,
              ),
              belegZelle(bewegungen[i].beleg, bewegungen[i].zustellung),
              zelle(
                bewegungen[i].status ?? '',
                style:
                    bewegungen[i].status == null ||
                        bewegungen[i].status == 'offen'
                    ? cellGrey
                    : const pw.TextStyle(fontSize: 8.5, color: _rot),
              ),
              zelle(
                bewegungen[i].soll > 0 ? _fmt(bewegungen[i].soll) : '',
                align: pw.Alignment.centerRight,
              ),
              zelle(
                bewegungen[i].haben > 0 ? _fmt(bewegungen[i].haben) : '',
                align: pw.Alignment.centerRight,
                style: const pw.TextStyle(fontSize: 8.5, color: _gruen),
              ),
              zelle(
                _fmt(salden[i]),
                align: pw.Alignment.centerRight,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: salden[i] > 0.005 ? _rot : _gruen,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Zahlungssatz der Fusszeile — rein, ohne PDF-Widgets, damit er ohne
  /// Rendering geprüft werden kann.
  ///
  /// [mitZahlteil] steuert NUR diesen Satz, nicht den Zahlteil selbst (der
  /// wird schon in [seitenHinzufuegen] weggelassen): Ohne eigenen Zahlteil —
  /// als Beilage zum Mahnschreiben (Review 23.09.2026, Vorab-Punkt 2) — wäre
  /// «auf das untenstehende Konto» falsch, weil gar kein Einzahlungsschein
  /// mehr folgt. Bezahlt wird dann über die Zahlteile im Mahnschreiben.
  static String fusszeilenSatz(double offen, {bool mitZahlteil = true}) {
    if (offen <= 0.005) return 'Das Konto ist ausgeglichen - besten Dank.';
    if (!mitZahlteil) {
      return 'Bitte verwenden Sie für die Zahlung die Einzahlungsscheine im '
          'Mahnschreiben.';
    }
    return 'Wir bitten um Überweisung des offenen Saldos von CHF ${_fmt(offen)} '
        'auf das untenstehende Konto. Bereits erfolgte Zahlungen sind in '
        'diesem Auszug berücksichtigt.';
  }

  static pw.Widget _fusszeile(
    double offen,
    int? jahr,
    GeschaeftEinstellungen geschaeft, {
    bool mitZahlteil = true,
  }) {
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
            fusszeilenSatz(offen, mitZahlteil: mitZahlteil),
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          // WICHTIG beim Jahresauszug: Ohne diesen Satz liest der Kunde den
          // Saldo als seinen GESAMTEN Ausstand. Hat er ältere offene Posten,
          // wäre das Papier schlicht falsch — und eine Zahlung nach diesem
          // Betrag liesse die alten Rechnungen stillschweigend liegen.
          if (jahr != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Dieser Auszug umfasst ausschliesslich das Jahr $jahr. '
              'Allfällige Posten aus früheren Jahren sind nicht enthalten.',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _darkBlue,
              ),
            ),
          ],
          pw.SizedBox(height: 5),
          pw.Text(
            'Zahlungsverbindung: Graubündner Kantonalbank · IBAN ${GeschaeftEinstellungen.zahlungsIbanFormatiert} · '
            '${geschaeft.firma}, ${geschaeft.adresseStrasse}, ${geschaeft.adressePlzOrt}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }
}
