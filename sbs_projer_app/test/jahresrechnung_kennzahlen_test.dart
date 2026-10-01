import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';

AbschreibungLauf lauf({
  int geschaeftsjahr = 2025,
  List<int> jahrgaenge = const [2020],
  int anzahl = 76,
  double brutto = 7216.30,
  String status = 'gebucht',
  int? mwstJahr,
}) => AbschreibungLauf(
  id: 'l$jahrgaenge',
  geschaeftsjahr: geschaeftsjahr,
  jahrgaenge: jahrgaenge,
  buchungsdatum: DateTime(geschaeftsjahr, 12, 31),
  mwstJahr: mwstJahr ?? geschaeftsjahr,
  mwstQuartal: 4,
  anzahl: anzahl,
  netto: brutto,
  mwst: 0,
  brutto: brutto,
  status: status,
  ruecknahmeMoeglich: true,
);

/// Rechenbeispiel aus `docs/buchhaltung/jahresabschluss-2025.md` §6
/// (Fassung 1 vom 02.09.2026): Gewinn 20'890.22, Vortrag 35'060.71,
/// EK 75'950.93. Die Saldi sind klein gehalten, treffen aber genau diese
/// Summen (Saldo = Soll − Haben, Ertrag also negativ).
final vorjahr = <int, double>{
  1020: 11829.71,
  2800: -20000,
  3000: -100000,
  5000: 64939.29, // − (−100'000 + 64'939.29) = 35'060.71 Gewinn kumuliert
};

final jahr2025 = <int, double>{
  1000: 6670.24,
  1020: 12202.73,
  1100: 112587.66,
  1109: -5629.38,
  2208: -4000,
  2800: -20000,
  3000: -300000,
  5000: 243929.07,
  6280: 120,
  // kumuliert: −(−300'000 + 243'929.07 + 120) = 55'950.93
};

void main() {
  group('kennzahlenAus', () {
    final k = kennzahlenAus(
      jahr: 2025,
      saldiJahr: jahr2025,
      saldiVorjahr: vorjahr,
      laeufe: [
        lauf(jahrgaenge: [2019], anzahl: 29, brutto: 2235.90),
        lauf(),
      ],
      aufrechnungenManuell: 200, // Busse Kanton, 2025 noch auf 8900
    );

    test('Gewinn, Vortrag und Eigenkapital wie im Abschluss 2025', () {
      expect(k.gewinnvortrag, 35060.71);
      expect(k.gewinn, 20890.22);
      expect(k.stammkapital, 20000);
      expect(k.eigenkapital, 75950.93);
    });

    test('Bilanzposten mit dem richtigen Vorzeichen', () {
      expect(k.debitoren, 112587.66);
      expect(k.delkredere, 5629.38); // Haben-Saldo → positiv
      expect(k.rueckstellung, 4000);
      expect(k.bank, 12202.73);
      expect(k.kasse, 6670.24);
    });

    test('Aufrechnungen: 6280 automatisch, der Rest manuell', () {
      expect(k.aufrechnungenAuto, 120);
      expect(k.aufrechnungenManuell, 200);
      expect(k.aufrechnungen, 320);
      expect(k.steuerbarerGewinn, 21210.22);
    });

    test('Abschreibungszeilen je gebuchtem Lauf, nach Jahrgang sortiert', () {
      expect(k.abschreibungen, [
        "Jahrgang 2019: 29 Rechnungen, 2'235.90",
        "Jahrgang 2020: 76 Rechnungen, 7'216.30",
      ]);
    });
  });

  test('Verlustjahr: Gewinn negativ, EK sinkt', () {
    final k = kennzahlenAus(
      jahr: 2025,
      saldiJahr: {...vorjahr, 3000: -100000, 5000: 69939.29},
      saldiVorjahr: vorjahr,
      laeufe: const [],
    );
    expect(k.gewinn, -5000);
    expect(k.eigenkapital, 50060.71);
    expect(k.abschreibungen, isEmpty);
  });

  test('6280 zählt nur die Bewegung des Jahrs, 6281 zählt mit', () {
    final k = kennzahlenAus(
      jahr: 2026,
      saldiJahr: {6280: 500, 6281: 150},
      saldiVorjahr: {6280: 380},
      laeufe: const [],
    );
    expect(k.aufrechnungenAuto, 270);
  });

  test('Steuerbussen auf 8900 zählen zur automatischen Aufrechnung', () {
    // Wie die Rückstellungs-Regel (B, 29.09.2026): 2025 steht die «Busse
    // Kanton» 200.00 auf 8900 — sie ist nicht abzugsfähig wie 6280/6281.
    final k = kennzahlenAus(
      jahr: 2025,
      saldiJahr: {6280: 111.01},
      saldiVorjahr: const {},
      bussen8900: 200,
      laeufe: const [],
    );
    expect(k.aufrechnungenAuto, 311.01);
  });

  group('Abschreibung nach dem Bilanzstichtag', () {
    test('Rückholung im Folgejahr = nach dem Stichtag beschlossen', () {
      final k = kennzahlenAus(
        jahr: 2025,
        saldiJahr: const {},
        saldiVorjahr: const {},
        laeufe: [lauf(mwstJahr: 2026)],
      );
      expect(k.abschreibungNachStichtag, isTrue);
    });

    test('Rückholung im selben Jahr, fremde oder zurückgenommene Läufe: nein', () {
      final k = kennzahlenAus(
        jahr: 2025,
        saldiJahr: const {},
        saldiVorjahr: const {},
        laeufe: [
          lauf(),
          lauf(geschaeftsjahr: 2026, mwstJahr: 2027),
          lauf(mwstJahr: 2026, status: 'zurueckgenommen'),
        ],
      );
      expect(k.abschreibungNachStichtag, isFalse);
    });
  });

  test('Delkredere-Satz aus den Beträgen, eine Nachkommastelle', () {
    final k = kennzahlenAus(
      jahr: 2025,
      saldiJahr: {1100: 105351.96, 1109: -5629.38},
      saldiVorjahr: const {},
      laeufe: const [],
    );
    // 5'629.38 auf 105'351.96 = 5.34 % — nicht fest «5 %».
    expect(k.delkredereSatzText, '5.3 %');
    final ohne = kennzahlenAus(
      jahr: 2025,
      saldiJahr: const {},
      saldiVorjahr: const {},
      laeufe: const [],
    );
    expect(ohne.delkredereSatzText, '0.0 %');
  });

  test('zurückgenommene und fremde Läufe zählen nicht', () {
    final zeilen = abschreibungsZeilen(2025, [
      lauf(status: 'zurueckgenommen'),
      lauf(geschaeftsjahr: 2026, jahrgaenge: [2021]),
      lauf(jahrgaenge: [2019, 2020], anzahl: 105, brutto: 9452.20),
    ]);
    expect(zeilen, ["Jahrgänge 2019, 2020: 105 Rechnungen, 9'452.20"]);
  });

  test('mit() übernimmt Dialog-Eingaben, leere Ereignisse bleiben null', () {
    final k = kennzahlenAus(
      jahr: 2025,
      saldiJahr: jahr2025,
      saldiVorjahr: vorjahr,
      laeufe: const [],
      ereignisse: '   ',
    );
    expect(k.ereignisse, isNull);
    final m = k.mit(aufrechnungenManuell: 80, ereignisse: 'Keine.');
    expect(m.aufrechnungen, 200);
    expect(m.ereignisse, 'Keine.');
    expect(m.gewinn, k.gewinn);
  });

  group('Ausserordentlicher Ertrag 8000 (Art. 959c Abs. 2 Ziff. 12 OR)', () {
    Buchung b(
      String nr,
      int soll,
      int haben,
      double betrag,
      String text, {
      int jahr = 2025,
      double mwst = 0,
      int? mwstKonto,
      bool storniert = false,
    }) => Buchung(
      id: '$nr $text',
      userId: 'u',
      datum: DateTime(jahr, 12, 31),
      belegnummer: nr,
      sollKonto: soll,
      habenKonto: haben,
      mwstKonto: mwstKonto,
      betragNetto: betrag - mwst,
      mwstBetrag: mwst,
      betragBrutto: betrag,
      beschreibung: text,
      geschaeftsjahr: jahr,
      istStorniert: storniert,
    );

    test('je Beleg eine Zeile: Vorzeichen, gemeinsamer Anfang, Fremdjahr und Storno nicht', () {
      final zeilen = aoErtragZeilenAus([
        b('JA2025_F1', 1100, 8000, 85.10, 'Nachtrag Forderung 011_2023_03_09_0224_00008510 BARacca (März-2023-Lücke, bezahlt 31.05.2023)'),
        b('JA2025_B4', 2200, 8000, 2079.39, 'Auflösung MwSt-Altsaldo 2019–2024 (Journal-USt über ESTV-Saldi)'),
        b('JA2025_F1', 1100, 8000, 67.85, 'Nachtrag Forderung 011_2023_03_14_0002_00006785 Fravi (März-2023-Lücke, bezahlt 24.03.2023)'),
        b('JA2025_F3', 8000, 1100, 161.55, "Korrektur Heineken-Forderung 08/2019: Excel 4'366.16, Rechnung und Zahlung 4'204.61"),
        // MWST am Entscheidtag im Folgejahr: zählt 2025 nicht.
        b('JA2025_F_MWST', 8000, 2200, 218.50, 'MWST 7.7 % auf nachgebuchten Ertrag', jahr: 2026, mwst: 218.50, mwstKonto: 2200),
        b('X', 1020, 8000, 50, 'Fremdjahr', jahr: 2024),
        b('S', 1020, 8000, 999, 'Storniert', storniert: true),
        b('N', 1020, 3400, 999, 'Anderes Konto'),
      ], 2025);
      expect(zeilen, [
        "Auflösung MwSt-Altsaldo 2019–2024: 2'079.39",
        'Nachtrag Forderung (2 Buchungen): 152.95',
        'Korrektur Heineken-Forderung 08/2019: -161.55',
      ]);
    });

    test('MWST-Aufteilung: Soll 8000 mit mwst_konto 2200 zählt brutto als Aufwand', () {
      expect(
        aoErtragZeilenAus([
          b('JA2025_F_MWST', 8000, 2200, 218.50, 'MWST 7.7 % auf nachgebuchten Ertrag', jahr: 2026, mwst: 218.50, mwstKonto: 2200),
        ], 2026),
        ['MWST 7.7 % auf nachgebuchten Ertrag: -218.50'],
      );
    });

    test('kennzahlenAus: Bewegung des Jahrs auf 8000, positiv = Ertrag, Zeilen aus dem Journal', () {
      final k = kennzahlenAus(
        jahr: 2025,
        saldiJahr: {...jahr2025, 8000: -6367.89},
        saldiVorjahr: {...vorjahr, 8000: -1000},
        laeufe: const [],
        journal: [b('JA2025_B5', 2000, 8000, 96.95, 'Auflösung Kreditoren-Altrest 96.95 (ohne Beleg)')],
      );
      expect(k.aoErtrag, closeTo(5367.89, 0.001));
      expect(k.aoErtragZeilen, ['Auflösung Kreditoren-Altrest 96.95: 96.95']);
      expect(k.mit(ereignisse: 'x').aoErtragZeilen, k.aoErtragZeilen);
      final ohne = kennzahlenAus(jahr: 2025, saldiJahr: jahr2025, saldiVorjahr: vorjahr, laeufe: const []);
      expect(ohne.aoErtrag, 0);
      expect(ohne.aoErtragZeilen, isEmpty);
    });
  });
}
