import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';

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
}
