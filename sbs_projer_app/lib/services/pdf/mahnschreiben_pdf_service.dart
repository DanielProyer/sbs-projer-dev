import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';
import 'package:sbs_projer_app/services/pdf/qr_zahlteil.dart';

/// Ein Rechnungsposten des Sammelschreibens: die Rechnung und die Mahnstufe,
/// in der SIE steht (bei einer Sammelmahnung können mehrere Rechnungen eines
/// Betriebs auf unterschiedlichen Stufen stehen).
typedef MahnPosten = ({Rechnung rechnung, MahnStufe stufe});

/// Sammel-Mahnschreiben (v0.134.0): ein Brief für alle offenen Rechnungen
/// eines Betriebs, mit einem eigenen QR-Zahlteil je Rechnung und optional dem
/// Kontoauszug als Beilage. Ersetzt `MahnungPdfService` (Task 6), das je
/// Rechnung ein eigenes Schreiben erzeugte — Daniel wollte EIN Papier pro
/// Kunde, nicht eines pro offener Rechnung (Spec Abschnitt 4).
class MahnschreibenPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _darkRed = PdfColor.fromInt(0xFF8B0000);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);
  static const _lineGrey = PdfColor.fromInt(0xFFCCCCCC);

  static final _df = DateFormat('dd.MM.yyyy');

  // Firmendaten für den Briefkopf — eine Wahrheit mit dem QR-Zahlteil, damit
  // Briefkopf und Einzahlungsschein nie auseinanderlaufen.
  static const _firmaName = QrZahlteil.firmaName;
  static const _firmaStrasse = QrZahlteil.firmaStrasse;
  static const _firmaNr = QrZahlteil.firmaNr;
  static const _firmaPlz = QrZahlteil.firmaPlz;
  static const _firmaOrt = QrZahlteil.firmaOrt;

  /// Ein Einzahlungsschein über 113.47 wäre in der Schweiz nicht bezahlbar —
  /// gleiche Rundung wie Rechnung und Kontoauszug (Review 23.09.2026, Minor 5:
  /// der QR-Betrag muss wie der Rechnungsbetrag runden, sonst zeigen Brief-
  /// tabelle und Zahlteil zwei leicht verschiedene Zahlen).
  static double _roundTo5Rappen(double value) => (value * 20).roundToDouble() / 20;

  /// Text des Schreibens. Rein, ohne PDF-Widgets, damit die Formulierung ohne
  /// Rendering geprüft werden kann (`test/mahnschreiben_pdf_test.dart`).
  ///
  /// [stufen] ist eine Stufe JE ENTHALTENER RECHNUNG (nicht dedupliziert) —
  /// daraus ergeben sich Einzahl/Mehrzahl UND ob alle Rechnungen dieselbe
  /// Stufe haben.
  ///
  /// WARUM die Fallunterscheidung «einheitlich vs. gemischt» (Review
  /// 23.09.2026, Punkt 3): Bei einer Sammelmahnung können Rechnungen eines
  /// Betriebs auf UNTERSCHIEDLICHEN Stufen stehen (eine gerade erst
  /// erinnert, eine andere schon in der letzten Mahnung). Betreibungsandrohung
  /// und Verzugszins dürfen sich dann NUR auf die Rechnungen beziehen, die
  /// TATSÄCHLICH auf der letzten Stufe stehen — sonst drohte der Brief allen
  /// Rechnungen mit Betreibung, obwohl die meisten frisch überfällig sind.
  /// Ebenso darf «trotz mehrfacher Erinnerung» nur stehen, wenn das für ALLE
  /// enthaltenen Rechnungen stimmt.
  ///
  /// [ersteErinnerungLetzte] = frühestes Erinnerungsdatum NUR der Rechnungen
  /// auf Stufe [MahnStufe.letzte] (nicht aller enthaltenen Rechnungen) — der
  /// Verzugszins-Satz bezieht sich ausschliesslich auf diese.
  static String mahnText(
    List<MahnStufe> stufen, {
    required DateTime frist,
    DateTime? ersteErinnerungLetzte,
  }) {
    if (stufen.isEmpty) {
      throw ArgumentError('mahnText: stufen darf nicht leer sein');
    }
    final fristStr = _df.format(frist);
    final anzahl = stufen.length;
    final hoechste = hoechsteStufe(stufen);
    final einheitlich = stufen.every((s) => s == hoechste);
    final enthaeltLetzte = stufen.contains(MahnStufe.letzte);

    const gegenstandslos =
        'Falls Sie die Zahlung inzwischen ausgelöst haben, betrachten Sie '
        'dieses Schreiben als gegenstandslos.';
    const zahlungsschwierigkeiten =
        'Bei Zahlungsschwierigkeiten melden Sie sich bitte — wir finden '
        'gerne eine Lösung.';
    final zinsTeil = ersteErinnerungLetzte == null
        ? 'dabei wird ein Verzugszins von 5 % geltend gemacht'
        : 'dabei wird ein Verzugszins von 5 % seit '
            '${_df.format(ersteErinnerungLetzte)} geltend gemacht';

    if (einheitlich) {
      switch (hoechste) {
        case MahnStufe.erinnerung:
          final rechnungWort =
              anzahl == 1 ? 'die folgende Rechnung' : 'die folgenden Rechnungen';
          final istSind = anzahl == 1 ? 'ist' : 'sind';
          final betragWort = anzahl == 1 ? 'den offenen Betrag' : 'die offenen Beträge';
          return 'Vermutlich $istSind Ihnen $rechnungWort entgangen. Wir '
              'bitten Sie freundlich, $betragWort bis zum $fristStr zu '
              'begleichen.\n\n$gegenstandslos';
        case MahnStufe.mahnung1:
          final betragWort = anzahl == 1
              ? 'der Betrag der folgenden Rechnung'
              : 'die Beträge der folgenden Rechnungen';
          final istSind = anzahl == 1 ? 'ist' : 'sind';
          final ihnSie = anzahl == 1 ? 'ihn' : 'sie';
          return 'Trotz unserer Zahlungserinnerung $istSind $betragWort '
              'weiterhin nicht bei uns eingegangen. Wir fordern Sie hiermit '
              'auf, $ihnSie bis spätestens $fristStr zu begleichen.\n\n'
              '$gegenstandslos';
        case MahnStufe.letzte:
          final betragWort = anzahl == 1
              ? 'der Betrag der folgenden Rechnung'
              : 'die Beträge der folgenden Rechnungen';
          final istSind = anzahl == 1 ? 'ist' : 'sind';
          final ihnSie = anzahl == 1 ? 'ihn' : 'sie';
          // Das Datum nur EINMAL nennen (Review 23.09.2026, Vorab-Punkt 3):
          // Zahlungsfrist und Betreibungsandrohung beziehen sich auf denselben
          // Termin, «bis dahin» verweist auf das oben genannte Datum zurück.
          return 'Trotz mehrfacher Erinnerung und Mahnung $istSind $betragWort '
              'bis heute nicht bei uns eingegangen. Wir fordern Sie hiermit '
              'letztmalig auf, $ihnSie bis spätestens $fristStr zu '
              'begleichen. Ohne Zahlungseingang bis dahin leiten wir ohne '
              'weitere Ankündigung die Betreibung ein; $zinsTeil.\n\n'
              '$zahlungsschwierigkeiten\n\n$gegenstandslos';
      }
    }

    // Gemischte Stufen: allgemeiner Hinweis auf die Tabelle, die die Stufe je
    // Rechnung ausweist — plus die Betreibungs-/Zins-Klausel NUR, wenn
    // mindestens eine Rechnung tatsächlich auf der letzten Stufe steht, und
    // nur bezogen auf GENAU DIESE.
    final buffer = StringBuffer(
      'Die folgenden Rechnungen sind unterschiedlich lange überfällig; die '
      'jeweilige Mahnstufe entnehmen Sie bitte der Tabelle. Wir bitten Sie, '
      'sämtliche offenen Beträge bis zum $fristStr zu begleichen.',
    );
    if (enthaeltLetzte) {
      buffer.write(
        '\n\nFür die in der Tabelle als ‹Letzte Mahnung› bezeichneten '
        'Rechnungen leiten wir ohne Zahlungseingang bis $fristStr ohne '
        'weitere Ankündigung die Betreibung ein; $zinsTeil.',
      );
    }
    if (hoechste == MahnStufe.letzte) {
      buffer.write('\n\n$zahlungsschwierigkeiten');
    }
    buffer.write('\n\n$gegenstandslos');
    return buffer.toString();
  }

  /// Baut das Sammel-Mahnschreiben eines Betriebs.
  ///
  /// [posten] eine Zeile je offener Rechnung mit ihrer eigenen Mahnstufe;
  /// der Titel des Briefs richtet sich nach der HÖCHSTEN Stufe darunter
  /// (`hoechsteStufe`) — eine Sammelmahnung ist nie milder als ihre
  /// schärfste enthaltene Rechnung.
  ///
  /// [kontoauszugRechnungen] hängt bei Angabe den Kontoauszug als Beilage an
  /// (Druck-PDF, siehe Abweichung «ohne Rechnungskopien» im Plan). Der
  /// Kontoauszug bekommt bewusst `mitZahlteil: false`: Ein zweiter,
  /// SUMMIERTER Zahlteil über den Gesamtsaldo neben den Zahlteilen je
  /// Rechnung wäre eine zweite Zahlungsaufforderung über denselben Betrag —
  /// Doppelzahlungsgefahr, und der camt-Abgleich sähe eine Zahlung, die zu
  /// keiner Einzelrechnung passt (Review 23.09.2026, Punkt 1).
  ///
  /// [muster] überlagert JEDE Seite (Schreiben, QR-Seiten, Kontoauszug) mit
  /// dem MUSTER-Wasserzeichen — für die Vorschau vor dem Versand.
  static Future<Uint8List> generate({
    required BetriebLocal betrieb,
    BetriebRechnungsadresse? rechnungsadresse,
    required List<MahnPosten> posten,
    required DateTime datum,
    required DateTime frist,
    required bool muster,
    List<Rechnung>? kontoauszugRechnungen,
    int? kontoauszugJahr,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
  }) async {
    final pdf = await pdfDokument();
    final stufen = posten.map((p) => p.stufe).toList();
    final stufe = hoechsteStufe(stufen);
    // Nur die Erinnerungsdaten der Rechnungen auf der LETZTEN Stufe zählen
    // für den Verzugszins-Satz — siehe Kommentar an `mahnText`.
    final ersteErinnerungLetzte = posten
        .where((p) => p.stufe == MahnStufe.letzte)
        .map((p) => p.rechnung.erinnerungAm)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (bisher, aktuell) =>
              bisher == null || aktuell.isBefore(bisher) ? aktuell : bisher,
        );
    final kundeAddr = qrEmpfaenger(
      betriebName: betrieb.name,
      betriebStrasse: betrieb.strasse,
      betriebNr: betrieb.nr,
      betriebPlz: betrieb.plz,
      betriebOrt: betrieb.ort,
      ra: rechnungsadresse,
    );
    final total = posten.fold<double>(
      0,
      (summe, p) => summe + p.rechnung.betragBrutto,
    );

    // ─── Seite 1: das Schreiben selbst ───
    pdf.addPage(
      pw.MultiPage(
        pageTheme: musterPageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 48),
          muster: muster,
        ),
        build: (context) => [
          _buildHeader(
            firmaName: firmaName,
            firmaStrasse: firmaStrasse,
            firmaPlzOrt: firmaPlzOrt,
            firmaMwst: firmaMwst,
          ),
          pw.SizedBox(height: 30),
          _buildKundenAdresse(betrieb, rechnungsadresse),
          pw.SizedBox(height: 18),
          // Ort vor dem Datum («Domat/Ems, 23.09.2026») — Review 23.09.2026,
          // Punkt 4: Geschäftsbriefe datieren mit Absenderort, nicht bloss
          // dem Datum allein.
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '$_firmaOrt, ${_df.format(datum)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            stufe.titel.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: stufe == MahnStufe.erinnerung ? _darkBlue : _darkRed,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            posten.length == 1
                ? 'Rechnung ${posten.single.rechnung.rechnungsnummer ?? ''}'
                : 'Offene Rechnungen',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            mahnText(stufen, frist: frist, ersteErinnerungLetzte: ersteErinnerungLetzte),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          _buildPostenTabelle(posten),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total CHF ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Zahlbar bis ${_df.format(frist)}.',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Freundliche Grüsse', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            _firmaName,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    // ─── QR-Seiten: je Rechnung eine EIGENE Seite, Zahlteil UNTEN ───
    //
    // WARUM ein Zahlteil pro Seite statt zwei (Review 23.09.2026, Punkt 5):
    // Die Swiss-QR-Bill-Norm sieht den Zahlteil am UNTEREN Rand einer A4-Seite
    // vor (Perforation). Zwei Zahlteile pro Seite — einer oben, einer unten —
    // verletzen das für den OBEREN. Eine eigene Seite je Rechnung, mit einem
    // Spacer VOR dem Zahlteil, hält jeden Zahlteil unten — auch bei einer
    // ungeraden Anzahl gibt es dadurch keinen Sonderfall mehr.
    for (final p in posten) {
      pdf.addPage(
        pw.Page(
          pageTheme: musterPageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            muster: muster,
          ),
          build: (context) => pw.Column(
            children: [
              pw.Spacer(),
              _buildQrBlock(p.rechnung, betrieb, kundeAddr),
            ],
          ),
        ),
      );
    }

    // ─── Kontoauszug als Beilage (optional) ───
    if (kontoauszugRechnungen != null) {
      await KontoauszugPdfService.seitenHinzufuegen(
        pdf,
        betrieb: betrieb,
        rechnungen: kontoauszugRechnungen,
        rechnungsadresse: rechnungsadresse,
        firmaName: firmaName,
        firmaStrasse: firmaStrasse,
        firmaPlzOrt: firmaPlzOrt,
        firmaMwst: firmaMwst,
        jahr: kontoauszugJahr,
        muster: muster,
        // Kein zweiter, summierter Zahlteil im Mahn-Druck-PDF — siehe
        // Doc-Kommentar an [generate].
        mitZahlteil: false,
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildQrBlock(
    Rechnung rechnung,
    BetriebLocal betrieb,
    QrEmpfaenger kundeAddr,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(50, 8, 50, 4),
          child: pw.Text(
            'Rechnung ${rechnung.rechnungsnummer ?? ''} vom '
            '${_df.format(rechnung.rechnungsdatum)}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        QrZahlteil.bauen(
          _roundTo5Rappen(rechnung.betragBrutto),
          kundeAddr,
          mitteilung: 'Rechnung ${rechnung.rechnungsnummer ?? ''}',
          referenz: rechnung.qrReferenz,
        ),
      ],
    );
  }

  // ─── HEADER ───

  static pw.Widget _buildHeader({
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
  }) {
    final displayName = firmaName ?? _firmaName;
    final displayStrasse = firmaStrasse ?? '$_firmaStrasse $_firmaNr';
    final displayPlzOrt = firmaPlzOrt ?? '$_firmaPlz $_firmaOrt';
    final mwstLeer = firmaMwst == null || firmaMwst.isEmpty;
    final displayMwst = mwstLeer ? 'CHE-413.083.919 MWST' : firmaMwst;

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
        pw.Text(displayStrasse, style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.Text(displayPlzOrt, style: const pw.TextStyle(fontSize: 9, color: _grey)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Tel 076 566 58 06 | sbs.projer@gmail.com',
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
        pw.Text(displayMwst, style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ],
    );
  }

  // ─── KUNDENADRESSE ───

  static pw.Widget _buildKundenAdresse(
    BetriebLocal betrieb,
    BetriebRechnungsadresse? ra,
  ) {
    final lines = adressZeilen(
      betriebName: betrieb.name,
      betriebStrasse: betrieb.strasse,
      betriebNr: betrieb.nr,
      betriebPlz: betrieb.plz,
      betriebOrt: betrieb.ort,
      ra: ra,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 10)))
          .toList(),
    );
  }

  // ─── POSTEN-TABELLE ───

  static pw.Widget _buildPostenTabelle(List<MahnPosten> posten) {
    const headerStyle = pw.TextStyle(fontSize: 8, color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 8.5);

    pw.Widget zelle(
      String text, {
      pw.TextStyle style = cellStyle,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text, style: style, maxLines: 1),
      );
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Rechnungsnr.
        1: const pw.FixedColumnWidth(62), // Rechnungsdatum
        2: const pw.FixedColumnWidth(62), // fällig seit
        3: const pw.FixedColumnWidth(62), // Betrag
        // Breit genug für «Letzte Mahnung», den längsten Stufentitel, ohne
        // Umbruch (Review 23.09.2026, Minor 5).
        4: const pw.FixedColumnWidth(92),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _lineGrey, width: 0.4),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _darkBlue),
          children: [
            zelle('Rechnungsnr.', style: headerStyle),
            zelle('Datum', style: headerStyle),
            zelle('Fällig seit', style: headerStyle),
            zelle('Betrag CHF', style: headerStyle, align: pw.Alignment.centerRight),
            zelle('Stufe', style: headerStyle),
          ],
        ),
        for (var i = 0; i < posten.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _lightGrey : PdfColors.white,
            ),
            children: [
              zelle(posten[i].rechnung.rechnungsnummer ?? ''),
              zelle(_df.format(posten[i].rechnung.rechnungsdatum)),
              zelle(_df.format(posten[i].rechnung.faelligkeitsdatum)),
              zelle(
                posten[i].rechnung.betragBrutto.toStringAsFixed(2),
                align: pw.Alignment.centerRight,
              ),
              zelle(posten[i].stufe.titel),
            ],
          ),
      ],
    );
  }
}
