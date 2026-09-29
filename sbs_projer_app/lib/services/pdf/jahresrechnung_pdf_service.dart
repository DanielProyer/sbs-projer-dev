// lib/services/pdf/jahresrechnung_pdf_service.dart
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

/// Die Jahresrechnung als EIN Dokument für das Steuer-Dossier: Bilanz und
/// Erfolgsrechnung mit Vorjahr, Anhang (Art. 959c OR) und Steuerbeilage.
///
/// WARUM ein eigener Service: Bis zum Abschluss 2025 entstand die
/// Jahresrechnung aus drei Teilen — App-PDF Bilanz, App-PDF Erfolgsrechnung
/// (beide ohne Vorjahr) und dem Python-Skript
/// `Datenbank/wartung/jahresrechnung_beilage.py` mit von Hand eingetippten
/// Zahlen. Die Texte von Anhang und Beilage sind aus dem Skript übernommen,
/// die Zahlen kommen aus [JahresrechnungKennzahlen], also aus denselben Saldi
/// wie die Bilanz.
class JahresrechnungPdfService {
  static Future<Uint8List> generate({
    required JahresrechnungKennzahlen k,
    required BilanzDaten bilanz,
    BilanzDaten? bilanzVorjahr,
    required ErfolgsrechnungDaten er,
    ErfolgsrechnungDaten? erVorjahr,
    required ErKontenAufstellung konten,
    ErKontenAufstellung? kontenVorjahr,
    String? firmaName,
    String? firmaStrasse,
    String? firmaOrt,
    String? mwstZeile,
    String? geschaeftsfuehrer,
    required DateTime erstelltAm,
  }) async {
    final pdf = await pdfDokument();
    final df = DateFormat('dd.MM.yyyy');
    final jahr = k.jahr;
    final firma = firmaName ?? BerichtPdfCommon.firma;
    final plzOrt = firmaOrt ?? BerichtPdfCommon.ort;
    // «7013 Domat/Ems» → «Domat/Ems» für Sitz und Ort/Datum.
    final sitz = plzOrt.replaceFirst(RegExp(r'^\d{4,5}\s+'), '').trim();
    final erstellt = df.format(erstelltAm);
    final unterzeichner =
        (geschaeftsfuehrer == null || geschaeftsfuehrer.trim().isEmpty)
        ? 'Daniel Projer'
        : geschaeftsfuehrer.trim();

    pw.Widget kopf(String titel, String periode) => BerichtPdfCommon.kopf(
      titel,
      periode,
      firmaName: firmaName,
      firmaStrasse: firmaStrasse,
      firmaOrt: firmaOrt,
      mwstZeile: mwstZeile,
    );

    // ── Seite 1: Bilanz mit Vorjahr ──────────────────────────────────────
    final mitBilanzVj = bilanzVorjahr != null;
    final aktiven = _vergleich(bilanz.aktiven, bilanzVorjahr?.aktiven);
    final passiven = _vergleich(bilanz.passiven, bilanzVorjahr?.passiven);
    final diffJ = bilanz.differenz;
    final diffV = bilanzVorjahr?.differenz ?? 0;

    List<pw.Widget> seite(
      String titel,
      List<_Gruppe> gruppen,
      double total,
      double? totalVj,
    ) => [
      pw.SizedBox(height: 10),
      pw.Text(
        titel,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      for (final g in gruppen) ...[
        _zeile(g.titel, null, null, mitVorjahr: mitBilanzVj, bold: true),
        for (final p in g.posten)
          _zeile(
            '${p.nr}  ${p.bezeichnung}',
            p.jahr,
            p.vorjahr,
            mitVorjahr: mitBilanzVj,
            indent: 6,
          ),
        _zeile(
          'Total ${g.titel}',
          g.summeJahr,
          g.summeVorjahr,
          mitVorjahr: mitBilanzVj,
          bold: true,
          linieOben: true,
        ),
        pw.SizedBox(height: 4),
      ],
      _zeile(
        'Total $titel',
        total,
        totalVj,
        mitVorjahr: mitBilanzVj,
        bold: true,
        linieOben: true,
        fontSize: 10,
      ),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          kopf('Bilanz', 'per 31.12.$jahr'),
          pw.SizedBox(height: 8),
          _spaltenKopf('31.12.$jahr', mitBilanzVj ? '31.12.${jahr - 1}' : null),
          ...seite(
            'Aktiven',
            aktiven,
            bilanz.totalAktiven,
            bilanzVorjahr?.totalAktiven,
          ),
          pw.SizedBox(height: 8),
          ...seite(
            'Passiven',
            passiven,
            bilanz.totalPassiven,
            bilanzVorjahr?.totalPassiven,
          ),
          pw.SizedBox(height: 8),
          // Eine Differenz darf nie still verschwinden — sie steht fett da,
          // statt der Bestätigung «Aktiven = Passiven».
          if (diffJ.abs() >= 0.005 || diffV.abs() >= 0.005)
            _zeile(
              'Differenz Aktiven − Passiven',
              diffJ,
              bilanzVorjahr?.differenz,
              mitVorjahr: mitBilanzVj,
              bold: true,
            )
          else
            pw.Text(
              'Aktiven = Passiven',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );

    // ── Seite 2: Erfolgsrechnung mit Vorjahr ─────────────────────────────
    // Ohne Stufen des Vorjahrs entstehen sie aus dessen Konten-Aufstellung —
    // dieselben Kontobereiche wie `ErfolgsrechnungService.berechne`.
    final ev =
        erVorjahr ?? (kontenVorjahr == null ? null : _erAus(kontenVorjahr));
    final mitErVj = ev != null;
    pw.Widget stufe(
      String l,
      double j,
      double? v, {
      bool zwischen = false,
    }) => _zeile(
      l,
      j,
      v,
      mitVorjahr: mitErVj,
      bold: zwischen,
      linieOben: zwischen,
      fontSize: 10,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          kopf('Erfolgsrechnung', '01.01.–31.12.$jahr'),
          pw.SizedBox(height: 8),
          _spaltenKopf('$jahr', mitErVj ? '${jahr - 1}' : null),
          pw.SizedBox(height: 4),
          stufe('Nettoerlös (3)', er.nettoerloes, ev?.nettoerloes),
          stufe('− Materialaufwand (4)', -er.materialaufwand, _neg(ev?.materialaufwand)),
          stufe('Bruttoergebnis 1', er.bruttoergebnis1, ev?.bruttoergebnis1, zwischen: true),
          stufe('− Personalaufwand (5)', -er.personalaufwand, _neg(ev?.personalaufwand)),
          stufe('Bruttoergebnis 2', er.bruttoergebnis2, ev?.bruttoergebnis2, zwischen: true),
          stufe('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand, _neg(ev?.uebrigerAufwand)),
          stufe('EBITDA', er.ebitda, ev?.ebitda, zwischen: true),
          stufe('− Abschreibungen (6800)', -er.abschreibungen, _neg(ev?.abschreibungen)),
          stufe('EBIT', er.ebit, ev?.ebit, zwischen: true),
          stufe('+/− Finanzerfolg (6900)', er.finanzerfolg, ev?.finanzerfolg),
          stufe('EBT (vor Steuern)', er.ebt, ev?.ebt, zwischen: true),
          stufe('+/− Betriebsfremd / a.o. (7 / 8000–8899)', er.nebenerfolg, ev?.nebenerfolg),
          stufe('− Direkte Steuern (8900)', -er.steuern, _neg(ev?.steuern)),
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEFF3F7),
              border: pw.Border(
                top: pw.BorderSide(width: 1.2, color: BerichtPdfCommon.dunkel),
                bottom: pw.BorderSide(width: 1.2, color: BerichtPdfCommon.dunkel),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: _zeile(
              er.jahresergebnis < 0 ? 'Jahresverlust' : 'Jahresgewinn',
              er.jahresergebnis,
              ev?.jahresergebnis,
              mitVorjahr: mitErVj,
              bold: true,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Konten',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          for (final kl in _klassenVergleich(konten, kontenVorjahr)) ...[
            pw.SizedBox(height: 6),
            _zeile(
              'Klasse ${kl.klasse} – ${kontenklasseBeschreibung[kl.klasse] ?? ''}',
              kl.summeJahr,
              kl.summeVorjahr,
              mitVorjahr: mitErVj,
              bold: true,
            ),
            for (final kt in kl.konten)
              _zeile(
                '${kt.nr}  ${kt.bezeichnung}',
                kt.jahr,
                kt.vorjahr,
                mitVorjahr: mitErVj,
                indent: 8,
              ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            'Ertragsklassen (3, 7) positiv = Ertrag, übrige Klassen positiv = '
            'Aufwand.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    // ── Seite 3: Anhang OR 959c ──────────────────────────────────────────
    final anlage = _anlagevermoegen(bilanz);
    final abschreibungen = k.abschreibungen.isEmpty
        ? 'im Abschluss des Verjährungsjahres abgeschrieben; $jahr keine.'
        : 'im Abschluss des Verjährungsjahres abgeschrieben: '
              '${k.abschreibungen.join('; ')}.';
    final ereignisse =
        k.ereignisse ??
        (k.abschreibungen.isEmpty
            ? 'Keine wesentlichen Ereignisse nach dem Bilanzstichtag.'
            : 'Die Abschreibung der verjährten Jahrgänge wurde nach dem '
                  'Bilanzstichtag beschlossen und per 31.12.$jahr verbucht; '
                  'die Mehrwertsteuer-Rückholung erfolgt in der Periode des '
                  'Entscheids.');
    final punkte = <(String, String)>[
      (
        'Firma, Rechtsform, Sitz',
        '$firma, Gesellschaft mit beschränkter Haftung, $sitz GR. '
            'Zapfanlagen-Service (Reinigung, Störungsbehebung, Montage) als '
            'Heineken-Franchisenehmerin.',
      ),
      (
        'Rechnungslegung',
        'Nach den Vorschriften des Schweizer Obligationenrechts '
            '(Art. 957 ff. OR). Die Jahresrechnung wird in Schweizer Franken '
            'geführt.',
      ),
      (
        'Vollzeitstellen',
        'Im Jahresdurchschnitt nicht mehr als 10 Vollzeitstellen '
            '(eine Person).',
      ),
      (
        'Forderungen aus Lieferungen und Leistungen',
        'Nominalwert CHF ${chf(k.debitoren)} abzüglich pauschale '
            'Wertberichtigung (Delkredere) von 5 %, CHF ${chf(k.delkredere)}. '
            'Verjährte Forderungen (Art. 128 Ziff. 3 OR) werden jahrgangsweise '
            '$abschreibungen',
      ),
      (
        'Rückstellungen',
        'Rückstellung für Gewinn- und Kapitalsteuern $jahr: '
            'CHF ${chf(k.rueckstellung)}.',
      ),
      (
        'Flüssige Mittel',
        'Bank CHF ${chf(k.bank)} (Kontoauszug per 31.12.$jahr), '
            'Kasse CHF ${chf(k.kasse)}.',
      ),
      (
        'Anlagevermögen, Beteiligungen',
        anlage.abs() < 0.005
            ? 'Kein Anlagevermögen, keine Beteiligungen, keine Liegenschaften.'
            : 'Anlagevermögen gemäss Bilanz CHF ${chf(anlage)}; keine '
                  'Beteiligungen, keine Liegenschaften.',
      ),
      (
        'Eventualverbindlichkeiten, Leasing',
        'Keine Bürgschaften, keine Garantieverpflichtungen, keine '
            'Leasingverbindlichkeiten.',
      ),
      ('Ereignisse nach dem Bilanzstichtag', ereignisse),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          kopf('Anhang', 'zur Jahresrechnung $jahr (Art. 959c OR)'),
          pw.SizedBox(height: 8),
          for (final (titel, text) in punkte)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 150,
                    child: pw.Text(
                      titel,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      text,
                      style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 18),
          pw.Text('$sitz, $erstellt', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 32),
          pw.Text(
            '______________________________',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '$unterzeichner, Geschäftsführer',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    // ── Seite 4: Steuerbeilage ───────────────────────────────────────────
    pw.Widget wert(String label, String betrag, {bool summe = false}) =>
        pw.Container(
          decoration: summe
              ? const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 0.6)),
                )
              : null,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: summe ? pw.FontWeight.bold : null,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 110,
                child: pw.Text(
                  betrag,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: summe ? pw.FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
        );
    const klein = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          kopf('Beilage zur Steuererklärung $jahr', 'Kennzahlen'),
          pw.SizedBox(height: 10),
          wert('Reingewinn laut Erfolgsrechnung $jahr', chf(k.gewinn)),
          wert(
            '+ Aufrechnung: nicht abzugsfähige Bussen (Konten 6280/6281)',
            chf(k.aufrechnungenAuto),
          ),
          if (k.aufrechnungenManuell.abs() >= 0.005)
            wert('+ Weitere Aufrechnungen', chf(k.aufrechnungenManuell)),
          wert(
            '= Steuerbarer Reingewinn (Vorschlag)',
            chf(k.steuerbarerGewinn),
            summe: true,
          ),
          pw.SizedBox(height: 12),
          wert('Stammkapital', chf(k.stammkapital)),
          wert('Gewinnvortrag 01.01.$jahr', chf(k.gewinnvortrag)),
          wert(
            '${k.gewinn < 0 ? 'Jahresverlust' : 'Jahresgewinn'} $jahr',
            chf(k.gewinn),
          ),
          wert(
            '= Eigenkapital 31.12.$jahr (steuerbares Kapital)',
            chf(k.eigenkapital),
            summe: true,
          ),
          pw.SizedBox(height: 12),
          wert(
            'Rückstellung direkte Steuern (Konto 2208)',
            chf(k.rueckstellung),
          ),
          wert('Delkredere (Konto 1109)', chf(k.delkredere)),
          wert(
            'Beteiligungen / Liegenschaften / Anlagevermögen',
            anlage.abs() < 0.005 ? 'keine' : 'Anlagevermögen ${chf(anlage)}',
          ),
          wert('Verrechnungssteuer-Ansprüche', 'keine'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Beilagen: Bilanz und Erfolgsrechnung per 31.12.$jahr mit Vorjahr '
            'und Anhang (dieses Dokument), Lohnausweis, '
            'Bank-Zins-/Kapitalausweis, Beschluss der '
            'Gesellschafterversammlung.',
            style: klein,
          ),
          pw.SizedBox(height: 4),
          // Die App-Version gehört auf jede Ausgabe: Nur so lässt sich
          // später sagen, mit welchem Rechenstand die Zahlen entstanden.
          pw.Text(
            'Erstellt $erstellt aus der Buchhaltung der SBS-Projer-App '
            '(v$kAppVersion).',
            style: klein,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Eine Betragszeile mit Spalte Jahr und optional Vorjahr.
  static pw.Widget _zeile(
    String label,
    double? jahr,
    double? vorjahr, {
    required bool mitVorjahr,
    bool bold = false,
    bool linieOben = false,
    double indent = 0,
    double fontSize = 9,
  }) {
    final stil = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Container(
      decoration: linieOben
          ? const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.5)),
            )
          : null,
      padding: pw.EdgeInsets.symmetric(vertical: fontSize * 0.25),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: indent),
              child: pw.Text(label, style: stil),
            ),
          ),
          pw.SizedBox(
            width: _spalte,
            child: pw.Text(
              jahr == null ? '' : chf(jahr),
              textAlign: pw.TextAlign.right,
              style: stil,
            ),
          ),
          if (mitVorjahr)
            pw.SizedBox(
              width: _spalte,
              child: pw.Text(
                // Nur Gruppentitel haben weder Jahr noch Vorjahr. Fehlt
                // ein Posten im Vorjahr, zeigt die Zeile 0.00.
                jahr == null && vorjahr == null ? '' : chf(vorjahr ?? 0),
                textAlign: pw.TextAlign.right,
                style: stil.copyWith(color: PdfColors.grey700),
              ),
            ),
        ],
      ),
    );
  }

  static const _spalte = 80.0;

  static pw.Widget _spaltenKopf(String jahr, String? vorjahr) {
    final stil = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text('CHF', style: stil)),
          pw.SizedBox(
            width: _spalte,
            child: pw.Text(jahr, textAlign: pw.TextAlign.right, style: stil),
          ),
          if (vorjahr != null)
            pw.SizedBox(
              width: _spalte,
              child: pw.Text(
                vorjahr,
                textAlign: pw.TextAlign.right,
                style: stil.copyWith(color: PdfColors.grey700),
              ),
            ),
        ],
      ),
    );
  }

  static double? _neg(double? v) => v == null ? null : -v;

  /// Stufengliederung aus der Konten-Aufstellung. Die Aufstellung führt
  /// Ertragsklassen (3, 7) positiv als Ertrag, alle übrigen positiv als
  /// Aufwand.
  static ErfolgsrechnungDaten _erAus(ErKontenAufstellung a) {
    double summe(int von, int bis) {
      var s = 0.0;
      for (final kl in a.klassen) {
        for (final k in kl.konten) {
          if (k.nr >= von && k.nr <= bis) s += k.summe;
        }
      }
      return s;
    }

    return ErfolgsrechnungDaten(
      nettoerloes: summe(3000, 3999),
      materialaufwand: summe(4000, 4999),
      personalaufwand: summe(5000, 5999),
      uebrigerAufwand: summe(6000, 6799),
      abschreibungen: summe(6800, 6899),
      finanzerfolg: -summe(6900, 6999),
      nebenerfolg: summe(7000, 7999) - summe(8000, 8899),
      steuern: summe(8900, 8999),
    );
  }

  static double _anlagevermoegen(BilanzDaten b) => b.aktiven
      .where((g) => g.titel == 'Anlagevermögen')
      .fold(0.0, (s, g) => s + g.summe);

  /// Reihenfolge der Bilanzgruppen wie in `BilanzService` (dort privat).
  static const _gruppenFolge = [
    'Umlaufvermögen',
    'Anlagevermögen',
    'Kurzfristiges Fremdkapital',
    'Langfristiges Fremdkapital',
    'Eigenkapital',
  ];

  /// Gruppen beider Jahre nach Titel zusammengeführt, Posten nach
  /// Kontonummer. Eine Gruppe, die nur im Vorjahr vorkommt (Coronakredit
  /// 2024 getilgt), steht an ihrem gewohnten Platz, nicht hinten.
  static List<_Gruppe> _vergleich(
    List<BilanzGruppe> jahr,
    List<BilanzGruppe>? vorjahr,
  ) {
    int rang(String t) {
      final i = _gruppenFolge.indexOf(t);
      return i < 0 ? _gruppenFolge.length : i;
    }

    final titel = <String>{
      ...jahr.map((g) => g.titel),
      ...?vorjahr?.map((g) => g.titel),
    }.toList();
    // Dart sortiert nicht stabil — unbekannte Titel behalten ihre Folge
    // über den Index als zweiten Schlüssel.
    final ursprung = [...titel];
    titel.sort((a, b) {
      final r = rang(a).compareTo(rang(b));
      return r != 0 ? r : ursprung.indexOf(a).compareTo(ursprung.indexOf(b));
    });
    return [
      for (final t in titel)
        _Gruppe(t, _posten(
          jahr.where((g) => g.titel == t).expand((g) => g.posten),
          (vorjahr ?? const []).where((g) => g.titel == t).expand((g) => g.posten),
        )),
    ];
  }

  static List<_Posten> _posten(
    Iterable<BilanzPosten> jahr,
    Iterable<BilanzPosten> vorjahr,
  ) {
    final zeilen = <int, _Posten>{};
    for (final p in jahr) {
      zeilen[p.kontonummer] = _Posten(p.kontonummer, p.bezeichnung, p.summe, 0);
    }
    for (final p in vorjahr) {
      final da = zeilen[p.kontonummer];
      zeilen[p.kontonummer] = da == null
          ? _Posten(p.kontonummer, p.bezeichnung, 0, p.summe)
          : _Posten(da.nr, da.bezeichnung, da.jahr, p.summe);
    }
    return zeilen.values.toList()..sort((a, b) => a.nr.compareTo(b.nr));
  }

  static BilanzPosten _alsPosten(ErKonto k) =>
      BilanzPosten(k.nr, k.bezeichnung ?? '—', k.summe);

  static List<_Klasse> _klassenVergleich(
    ErKontenAufstellung jahr,
    ErKontenAufstellung? vorjahr,
  ) {
    final klassen = <int>{
      ...jahr.klassen.map((k) => k.klasse),
      ...?vorjahr?.klassen.map((k) => k.klasse),
    }.toList()..sort();
    List<ErKonto> konten(ErKontenAufstellung? a, int kl) => [
      for (final k in a?.klassen ?? const <ErKlasse>[])
        if (k.klasse == kl) ...k.konten,
    ];
    return [
      for (final kl in klassen)
        _Klasse(
          kl,
          _posten(
            konten(jahr, kl).map(_alsPosten),
            konten(vorjahr, kl).map(_alsPosten),
          ),
        ),
    ];
  }
}

class _Posten {
  final int nr;
  final String bezeichnung;
  final double jahr, vorjahr;
  const _Posten(this.nr, this.bezeichnung, this.jahr, this.vorjahr);
}

class _Gruppe {
  final String titel;
  final List<_Posten> posten;
  const _Gruppe(this.titel, this.posten);
  double get summeJahr => posten.fold(0.0, (s, p) => s + p.jahr);
  double get summeVorjahr => posten.fold(0.0, (s, p) => s + p.vorjahr);
}

class _Klasse {
  final int klasse;
  final List<_Posten> konten;
  const _Klasse(this.klasse, this.konten);
  double get summeJahr => konten.fold(0.0, (s, p) => s + p.jahr);
  double get summeVorjahr => konten.fold(0.0, (s, p) => s + p.vorjahr);
}
