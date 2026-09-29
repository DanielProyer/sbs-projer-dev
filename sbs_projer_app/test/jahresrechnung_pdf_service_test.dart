import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/jahresrechnung_pdf_service.dart';

import 'hilfen/pdf_text.dart';

const konten = [
  KontoInfo(kontonummer: 1000, bezeichnung: 'Kasse', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1100, bezeichnung: 'Debitoren', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1109, bezeichnung: 'Delkredere', kategorie: 'Umlaufvermögen'),
  KontoInfo(
    kontonummer: 2208,
    bezeichnung: 'Steuerrückstellung',
    kategorie: 'Kurzfristiges Fremdkapital',
  ),
  KontoInfo(
    kontonummer: 2260,
    bezeichnung: 'Privatkonto',
    kategorie: 'Kurzfristiges Fremdkapital',
  ),
  KontoInfo(kontonummer: 2500, bezeichnung: 'Coronakredit', kategorie: 'Langfristiges Fremdkapital'),
  KontoInfo(kontonummer: 2800, bezeichnung: 'Stammkapital', kategorie: 'Eigenkapital'),
];

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final k = JahresrechnungKennzahlen(
    jahr: 2025,
    gewinn: 20890.22,
    gewinnvortrag: 35060.71,
    stammkapital: 20000,
    debitoren: 112587.66,
    delkredere: 5629.38,
    rueckstellung: 4000,
    bank: 12202.73,
    kasse: 6670.24,
    aufrechnungenAuto: 120,
    aufrechnungenManuell: 200,
    abschreibungen: const ["Jahrgang 2019: 29 Rechnungen, 2'235.90"],
    // Typografische Zeichen: seit pdfDokument() kein Kästchen mehr.
    ereignisse: 'Keine – ausser der Abschreibung (Entscheid 29.09.2026) …',
  );

  final bilanz = BilanzService.gruppiere(
    {1000: 6670.24, 1020: 12202.73, 1100: 112587.66, 1109: -5629.38, 2208: -4000, 2260: -45880.32, 2800: -20000},
    konten,
    gewinnvortrag: 35060.71,
    jahresergebnis: 20890.22,
  );
  // Vorjahr mit einem Posten, den es im Jahr nicht mehr gibt (2500), und
  // ohne Delkredere — beides muss zusammengeführt werden.
  final bilanzVj = BilanzService.gruppiere(
    {1000: 1122.69, 1020: 11829.71, 1100: 85871.15, 2260: -38762.84, 2500: -5000, 2800: -20000},
    konten,
    gewinnvortrag: 6783.20,
    jahresergebnis: 28277.51,
  );
  const er = ErfolgsrechnungDaten(
    nettoerloes: 197566.76,
    materialaufwand: 649.97,
    personalaufwand: 102494.22,
    uebrigerAufwand: 58935.41,
    abschreibungen: 0,
    finanzerfolg: 0,
    nebenerfolg: -10388.94,
    steuern: 4208,
  );
  const kontenJahr = ErKontenAufstellung([
    ErKlasse(3, [ErKonto(3000, 197566.76, bezeichnung: 'Ertrag Reinigung')]),
    ErKlasse(6, [
      ErKonto(6280, 120, bezeichnung: 'Verkehrsbussen'),
      ErKonto(6500, 58815.41, bezeichnung: 'Verwaltung'),
    ]),
  ]);
  const kontenVj = ErKontenAufstellung([
    ErKlasse(3, [ErKonto(3000, 180000, bezeichnung: 'Ertrag Reinigung')]),
  ]);

  Future<List<int>> bauen({bool mitVorjahr = true}) =>
      JahresrechnungPdfService.generate(
        k: k,
        bilanz: bilanz,
        bilanzVorjahr: mitVorjahr ? bilanzVj : null,
        er: er,
        konten: kontenJahr,
        kontenVorjahr: mitVorjahr ? kontenVj : null,
        geschaeftsfuehrer: 'Daniel Projer',
        erstelltAm: DateTime(2026, 9, 29),
      );

  /// Seitenzahl aus dem Seitenbaum (`/Type /Pages … /Count n`) — die
  /// Dictionaries schreibt das pdf-Paket unkomprimiert.
  int seiten(List<int> bytes) {
    final text = latin1.decode(bytes);
    final m = RegExp(r'/Type\s*/Pages[^>]*?/Count\s+(\d+)').firstMatch(text) ??
        RegExp(r'/Count\s+(\d+)[^>]*?/Type\s*/Pages').firstMatch(text);
    expect(m, isNotNull, reason: 'Seitenbaum nicht gefunden');
    return int.parse(m!.group(1)!);
  }

  test('vier Seiten: Bilanz, Erfolgsrechnung, Anhang, Steuerbeilage', () async {
    final bytes = await bauen();
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(seiten(bytes), 4);
    // Für eine Sichtprüfung von Hand: JAHRESRECHNUNG_PDF=pfad setzen.
    final ziel = Platform.environment['JAHRESRECHNUNG_PDF'];
    if (ziel != null) File(ziel).writeAsBytesSync(bytes);
  });

  test('ohne Vorjahr entsteht dieselbe Struktur', () async {
    final bytes = await bauen(mitVorjahr: false);
    expect(seiten(bytes), 4);
  });

  test('Text der Seiten: Vorjahresspalte, Anhang und Beilage', () async {
    final text = pdfSeitenText(await bauen());
    expect(text[0], contains('CHF 31.12.2025 31.12.2024'));
    expect(text[0], contains("1020 Bank 12'202.73 11'829.71"));
    // Posten nur im Vorjahr: im Jahr 0.00.
    expect(text[0], contains("2500 Coronakredit 0.00 5'000.00"));
    expect(text[0], contains('Aktiven = Passiven'));
    expect(text[3], contains("= Steuerbarer Reingewinn (Vorschlag) 21'210.22"));
    expect(text[3], contains('(v$kAppVersion)'));
  });

  test('K1: Folgeseite der ER mit Spaltenkopf, jede Seite mit Fusszeile', () async {
    // 40 Aufwandkonten: Die Erfolgsrechnung braucht zwei Seiten.
    final viele = ErKontenAufstellung([
      const ErKlasse(3, [ErKonto(3000, 197566.76, bezeichnung: 'Ertrag')]),
      ErKlasse(6, [
        for (var i = 0; i < 40; i++)
          ErKonto(6000 + i * 10, 100.0 + i, bezeichnung: 'Aufwand $i'),
      ]),
    ]);
    final bytes = await JahresrechnungPdfService.generate(
      k: k,
      bilanz: bilanz,
      bilanzVorjahr: bilanzVj,
      er: er,
      konten: viele,
      kontenVorjahr: kontenVj,
      erstelltAm: DateTime(2026, 9, 29),
    );
    final text = pdfSeitenText(bytes);
    expect(text.length, greaterThanOrEqualTo(5));
    final n = text.length;
    for (var i = 0; i < n; i++) {
      expect(
        text[i],
        contains('Jahresrechnung 2025 · Seite ${i + 1}/$n'),
        reason: 'Fusszeile Seite ${i + 1}',
      );
    }
    // Seite 3 = Fortsetzung der Erfolgsrechnung: ohne Kopf wären die
    // Beträge keiner Spalte zuzuordnen.
    expect(text[2], isNot(contains('Nettoerlös')));
    expect(text[2], contains('CHF 2025 2024'));
    expect(text[2], contains('Aufwand 39'));
  });

  group('Zusammenführung (vergleich)', () {
    test('Vorjahresspalte und Summen je Gruppe', () {
      final g = JahresrechnungPdfService.vergleich(bilanz.passiven, bilanzVj.passiven);
      expect(g.map((x) => x.titel).toList(), [
        'Kurzfristiges Fremdkapital',
        'Langfristiges Fremdkapital',
        'Eigenkapital',
      ]);
      final lang = g[1];
      expect(lang.posten.single.jahr, 0);
      expect(lang.posten.single.vorjahr, 5000);
      final ek = g[2];
      expect(ek.summeJahr, closeTo(75950.93, 0.001));
      expect(ek.summeVorjahr, closeTo(55060.71, 0.001));
    });

    test('K2: berechnete 2970/2980 und echtes Konto gleicher Nummer bleiben getrennt', () {
      const jahr = [
        BilanzGruppe('Eigenkapital', [
          BilanzPosten(2800, 'Stammkapital', 20000),
          BilanzPosten(2970, 'Gewinnvortrag (gebucht)', 100),
          BilanzPosten(2970, 'Gewinn-/Verlustvortrag', 35060.71),
          BilanzPosten(2980, 'Jahresergebnis', 20890.22),
        ]),
      ];
      const vorjahr = [
        BilanzGruppe('Eigenkapital', [
          BilanzPosten(2800, 'Stammkapital', 20000),
          BilanzPosten(2970, 'Gewinn-/Verlustvortrag', 6783.20),
        ]),
      ];
      final p = JahresrechnungPdfService.vergleich(jahr, vorjahr).single.posten;
      expect(p.length, 4);
      final berechnet = p.firstWhere((x) => x.bezeichnung == 'Gewinn-/Verlustvortrag');
      expect(berechnet.jahr, 35060.71);
      expect(berechnet.vorjahr, 6783.20);
      final gebucht = p.firstWhere((x) => x.bezeichnung == 'Gewinnvortrag (gebucht)');
      expect(gebucht.jahr, 100);
      expect(gebucht.vorjahr, 0);
    });

    test('ER-Konten beider Jahre je Klasse', () {
      final kl = JahresrechnungPdfService.klassenVergleich(kontenJahr, kontenVj);
      expect(kl.map((x) => x.klasse).toList(), [3, 6]);
      expect(kl[0].summeJahr, 197566.76);
      expect(kl[0].summeVorjahr, 180000);
      expect(kl[1].summeVorjahr, 0);
    });
  });

  group('Anhang', () {
    String text(JahresrechnungKennzahlen kz, String titel) =>
        JahresrechnungPdfService.anhangPunkte(
          k: kz,
          anlagevermoegen: 0,
          firma: 'SBS Projer GmbH',
          sitz: 'Domat/Ems',
        ).firstWhere((p) => p.$1 == titel).$2;

    test('K7: gebuchter Delkredere-Satz statt fest 5 %', () {
      final kz = k.mit(); // 5'629.38 auf 112'587.66 = 5.0 %
      expect(text(kz, 'Forderungen aus Lieferungen und Leistungen'), contains('von 5.0 %'));
      const tief = JahresrechnungKennzahlen(
        jahr: 2025,
        gewinn: 0,
        gewinnvortrag: 0,
        stammkapital: 20000,
        debitoren: 105351.96,
        delkredere: 5629.38,
        rueckstellung: 0,
        bank: 0,
        kasse: 0,
        aufrechnungenAuto: 0,
      );
      expect(text(tief, 'Forderungen aus Lieferungen und Leistungen'), contains('von 5.3 %'));
    });

    test('K8: «nach dem Stichtag beschlossen» nur bei Rückholung im Folgejahr', () {
      const basis = JahresrechnungKennzahlen(
        jahr: 2025,
        gewinn: 0,
        gewinnvortrag: 0,
        stammkapital: 20000,
        debitoren: 0,
        delkredere: 0,
        rueckstellung: 0,
        bank: 0,
        kasse: 0,
        aufrechnungenAuto: 0,
        abschreibungen: ["Jahrgang 2020: 76 Rechnungen, 7'216.30"],
      );
      expect(
        text(basis, 'Ereignisse nach dem Bilanzstichtag'),
        'Keine wesentlichen Ereignisse nach dem Bilanzstichtag.',
      );
      const danach = JahresrechnungKennzahlen(
        jahr: 2025,
        gewinn: 0,
        gewinnvortrag: 0,
        stammkapital: 20000,
        debitoren: 0,
        delkredere: 0,
        rueckstellung: 0,
        bank: 0,
        kasse: 0,
        aufrechnungenAuto: 0,
        abschreibungNachStichtag: true,
      );
      expect(
        text(danach, 'Ereignisse nach dem Bilanzstichtag'),
        contains('nach dem Bilanzstichtag beschlossen und per 31.12.2025 verbucht'),
      );
      // Freitext hat immer Vorrang.
      expect(
        text(danach.mit(ereignisse: 'Keine.'), 'Ereignisse nach dem Bilanzstichtag'),
        'Keine.',
      );
    });
  });
}
