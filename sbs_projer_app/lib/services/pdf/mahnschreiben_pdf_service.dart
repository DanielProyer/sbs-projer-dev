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

  /// Text des Schreibens für eine Stufe. Rein, ohne PDF-Widgets, damit die
  /// Formulierung ohne Rendering geprüft werden kann (`test/mahnschreiben_pdf_test.dart`).
  ///
  /// [ersteErinnerung] = frühestes Erinnerungsdatum der enthaltenen
  /// Rechnungen. Nur die letzte Mahnung nennt es (Verzugszins-Satz) — die
  /// 1. Mahnung nennt bewusst kein Datum, weil bei einer Sammelmahnung
  /// mehrere Rechnungen mit unterschiedlichen Erinnerungsdaten enthalten sein
  /// können.
  static String mahnText(
    MahnStufe stufe, {
    required DateTime frist,
    DateTime? ersteErinnerung,
  }) {
    final fristStr = _df.format(frist);
    const gegenstandslos =
        'Falls Sie die Zahlung inzwischen ausgelöst haben, betrachten Sie '
        'dieses Schreiben als gegenstandslos.';

    switch (stufe) {
      case MahnStufe.erinnerung:
        return 'Bei der Überprüfung unserer Buchhaltung ist uns entgangen, '
            'dass die untenstehenden Beträge noch nicht bei uns eingegangen '
            'sind. Wir bitten Sie freundlich, die offenen Rechnungen bis zum '
            '$fristStr zu begleichen.\n\n$gegenstandslos';
      case MahnStufe.mahnung1:
        return 'Trotz unserer Zahlungserinnerung sind die untenstehenden '
            'Beträge weiterhin nicht bei uns eingegangen. Wir fordern Sie '
            'hiermit auf, die offenen Rechnungen bis spätestens $fristStr '
            'zu begleichen.\n\n$gegenstandslos';
      case MahnStufe.letzte:
        final zinsSatz = ersteErinnerung == null
            ? 'Wir behalten uns die Verrechnung eines Verzugszinses von 5 % '
                'vor.'
            : 'Wir behalten uns die Verrechnung eines Verzugszinses von 5 % '
                'seit ${_df.format(ersteErinnerung)} vor.';
        return 'Trotz mehrfacher Erinnerung und Mahnung sind die '
            'untenstehenden Beträge bis heute nicht bei uns eingegangen. Wir '
            'fordern Sie hiermit letztmalig auf, die offenen Rechnungen bis '
            'spätestens $fristStr zu begleichen. $zinsSatz Andernfalls '
            'sehen wir uns gezwungen, ohne weitere Ankündigung die '
            'Betreibung einzuleiten.\n\n$gegenstandslos';
    }
  }

  /// Baut das Sammel-Mahnschreiben eines Betriebs.
  ///
  /// [posten] eine Zeile je offener Rechnung mit ihrer eigenen Mahnstufe;
  /// der Titel des Briefs richtet sich nach der HÖCHSTEN Stufe darunter
  /// (`hoechsteStufe`) — eine Sammelmahnung ist nie milder als ihre
  /// schärfste enthaltene Rechnung.
  ///
  /// [kontoauszugRechnungen] hängt bei Angabe den Kontoauszug als Beilage an
  /// (Druck-PDF, siehe Abweichung «ohne Rechnungskopien» im Plan).
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
    final stufe = hoechsteStufe(posten.map((p) => p.stufe));
    final ersteErinnerung = posten
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
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                stufe.titel.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: stufe == MahnStufe.erinnerung ? _darkBlue : _darkRed,
                ),
              ),
              pw.Text(_df.format(datum), style: const pw.TextStyle(fontSize: 10)),
            ],
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
            mahnText(stufe, frist: frist, ersteErinnerung: ersteErinnerung),
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

    // ─── QR-Seiten: je Rechnung ein eigener Zahlteil, zwei pro A4-Seite ───
    for (var i = 0; i < posten.length; i += 2) {
      final oben = posten[i];
      final unten = i + 1 < posten.length ? posten[i + 1] : null;
      pdf.addPage(
        pw.Page(
          pageTheme: musterPageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            muster: muster,
          ),
          build: (context) => pw.Column(
            children: [
              _buildQrBlock(oben.rechnung, betrieb, kundeAddr),
              if (unten != null)
                _buildQrBlock(unten.rechnung, betrieb, kundeAddr)
              else
                pw.Spacer(),
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
          rechnung.betragBrutto,
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
        child: pw.Text(text, style: style),
      );
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Rechnungsnr.
        1: const pw.FixedColumnWidth(65), // Rechnungsdatum
        2: const pw.FixedColumnWidth(65), // fällig seit
        3: const pw.FixedColumnWidth(65), // Betrag
        4: const pw.FixedColumnWidth(75), // Stufe
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
