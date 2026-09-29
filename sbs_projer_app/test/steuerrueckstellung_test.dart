import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/steuerrueckstellung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/steuerrueckstellung_service.dart';

/// Steuerrückstellung im Jahresabschluss (Schritt D) — bis 29.09.2026 per
/// SQL gebucht (docs/buchhaltung/jahresabschluss-2025.md Abschnitt 9d),
/// seither in der App.

var _id = 0;

Buchung _b(
  int soll,
  int haben,
  double betrag,
  DateTime datum, {
  String? belegTyp,
  int? geschaeftsjahr,
  String? belegnummer,
  bool storniert = false,
  String? stornoVonId,
  int? mwstKonto,
  double mwst = 0,
  String? steuerart,
}) => Buchung(
  id: 'b${_id++}',
  userId: 'u',
  datum: datum,
  belegnummer: belegnummer,
  sollKonto: soll,
  habenKonto: haben,
  mwstKonto: mwstKonto,
  betragNetto: betrag - mwst,
  mwstBetrag: mwst,
  betragBrutto: betrag,
  beschreibung: 'Test',
  belegTyp: belegTyp,
  geschaeftsjahr: geschaeftsjahr ?? datum.year,
  istStorniert: storniert,
  stornoVonId: stornoVonId,
  steuerart: steuerart,
);

final _silvester2025 = DateTime(2025, 12, 31);

void main() {
  group('rueckstellungVorschlag', () {
    test('Beispiel 2025: Gewinn vor Rückstellung 18\'035.70, Aufrechnungen '
        '320 → 2\'800', () {
      // R = 0.182 · 18'355.70 / 1.182 = 2'826.4 → auf 100: 2'800
      // (docs/buchhaltung/jahresabschluss-2025.md Abschnitt 9d).
      expect(
        rueckstellungVorschlag(
          gewinnVorRueckstellung: 18035.70,
          aufrechnungen: 320,
        ),
        2800,
      );
    });

    test('Verlustjahr → 0, nie negativ', () {
      expect(
        rueckstellungVorschlag(
          gewinnVorRueckstellung: -5000,
          aufrechnungen: 320,
        ),
        0,
      );
      expect(
        rueckstellungVorschlag(gewinnVorRueckstellung: 0, aufrechnungen: 0),
        0,
      );
    });

    test('rundet kaufmännisch auf 100', () {
      // Satz 25 % → R = 0.25 · B / 1.25 = 0.2 · B
      expect(
        rueckstellungVorschlag(
          gewinnVorRueckstellung: 6240,
          aufrechnungen: 0,
          satz: 0.25,
        ),
        1200, // 1'248
      );
      expect(
        rueckstellungVorschlag(
          gewinnVorRueckstellung: 6260,
          aufrechnungen: 0,
          satz: 0.25,
        ),
        1300, // 1'252
      );
    });

    test('löst R = s · (G + A − R): Rückstellung auf den Gewinn NACH '
        'Rückstellung', () {
      const g = 50000.0, a = 500.0, s = kSteuersatzEffektiv;
      final r = rueckstellungVorschlag(
        gewinnVorRueckstellung: g,
        aufrechnungen: a,
      );
      // Bis auf die Rundung auf 100 erfüllt der Vorschlag die Gleichung.
      expect((r - s * (g + a - r)).abs(), lessThan(100));
      // 18.2 % auf den Gewinn VOR Rückstellung wäre deutlich zu hoch.
      expect(r, lessThan(s * (g + a) - 1000));
    });

    test('Satz-Konstante: kalibriert an der Veranlagung 2024', () {
      expect(kSteuersatzEffektiv, 0.182);
    });
  });

  test('steuerbarerGewinn = Gewinn nach Rückstellung + Aufrechnungen', () {
    // 2025 nach D2: Gewinn 15'235.70 + Bussen 320 = 15'555.70 (Abschnitt 9d).
    expect(
      steuerbarerGewinn(gewinnNachRueckstellung: 15235.70, aufrechnungen: 320),
      15555.70,
    );
  });

  group('istRueckstellungsbuchung / rueckstellungGebucht', () {
    final jaD = _b(
      8900,
      2208,
      4000,
      _silvester2025,
      belegTyp: 'abschluss',
      belegnummer: 'JA2025_D',
    );

    test('JA2025_D zählt für 2025', () {
      expect(istRueckstellungsbuchung(jaD, 2025), isTrue);
      expect(rueckstellungGebucht([jaD], 2025), 4000);
    });

    test('Umbuchung der Steuerzahlung (JA2025_D_U1, April 2026) zählt für '
        '2026 NICHT', () {
      final u1 = _b(
        2208,
        8900,
        2405.50,
        DateTime(2026, 4, 15),
        belegTyp: 'abschluss',
        belegnummer: 'JA2025_D_U1',
      );
      expect(istRueckstellungsbuchung(u1, 2026), isFalse);
      expect(rueckstellungGebucht([jaD, u1], 2026), 0);
      expect(rueckstellungGebucht([jaD, u1], 2025), 4000);
    });

    test('Zahlung gegen 2208 und Steueraufwand ohne 2208 zählen nicht', () {
      final zahlung = _b(
        2208,
        1020,
        2748,
        _silvester2025,
        belegTyp: 'abschluss',
      );
      final steuer = _b(8900, 1020, 1088, _silvester2025);
      expect(rueckstellungGebucht([jaD, zahlung, steuer], 2025), 4000);
    });

    test('Nachführung 2208 an 8900 per 31.12. senkt die Rückstellung', () {
      final d2 = _b(
        2208,
        8900,
        1200,
        _silvester2025,
        belegTyp: 'abschluss',
        belegnummer: 'JA2025_D2',
      );
      expect(rueckstellungGebucht([jaD, d2], 2025), 2800);
    });

    test('aus dem Buchungsformular (ohne beleg_typ) zählt — Datum, '
        'Geschäftsjahr und Kontenpaar grenzen schon ab', () {
      final ohneTyp = _b(8900, 2208, 100, _silvester2025);
      expect(istRueckstellungsbuchung(ohneTyp, 2025), isTrue);
      expect(rueckstellungGebucht([jaD, ohneTyp], 2025), 4100);
      // Umbuchung einer Steuerzahlung von Hand im Jahr: kein 31.12.
      final umbuchung = _b(2208, 8900, 2748, DateTime(2025, 5, 5));
      expect(istRueckstellungsbuchung(umbuchung, 2025), isFalse);
    });

    test('anderes Geschäftsjahr oder storniert → zählt nicht', () {
      final falschesJahr = _b(
        8900,
        2208,
        100,
        _silvester2025,
        belegTyp: 'abschluss',
        geschaeftsjahr: 2026,
      );
      final storniert = _b(
        8900,
        2208,
        100,
        _silvester2025,
        belegTyp: 'abschluss',
        storniert: true,
      );
      final gegen = _b(
        2208,
        8900,
        100,
        _silvester2025,
        belegTyp: 'abschluss',
        stornoVonId: storniert.id,
      );
      expect(rueckstellungGebucht([falschesJahr, storniert, gegen], 2025), 0);
    });
  });

  group('bussenAuf8900', () {
    test('Steuerbusse auf 8900 (steuerart «busse») zählt, Steuern nicht', () {
      final journal = [
        // 2025: «Busse Kanton» 200.00 auf 8900 (produktiv so gebucht).
        _b(8900, 1020, 200, DateTime(2025, 3, 20), steuerart: 'busse'),
        _b(8900, 1020, 1088, DateTime(2025, 5, 14), steuerart: 'bund'),
        // MWST-Busse auf 2202 ist kein 8900-Aufwand.
        _b(2202, 1020, 1110, DateTime(2025, 10, 7), steuerart: 'busse'),
        // Anderes Jahr, storniert → nicht.
        _b(8900, 1020, 400, DateTime(2024, 3, 17), steuerart: 'busse'),
        _b(
          8900,
          1020,
          50,
          DateTime(2025, 6, 1),
          steuerart: 'busse',
          storniert: true,
        ),
      ];
      expect(bussenAuf8900(journal, 2025), 200);
      expect(bussenAuf8900(journal, 2024), 400);
    });
  });

  group('Lage mit Bussen wie 2025', () {
    // Verkehrsbusse 120.00 mit Vorsteuer 8.99 gebucht (1171) → Aufwand 6280
    // nur 111.01; «Busse Kanton» 200.00 auf 8900 → Aufrechnung 311.01
    // (so auch die Steuerbeilage 2025).
    final journal = [
      _b(1100, 3400, 30000, DateTime(2025, 3, 1)),
      _b(6280, 1020, 120, DateTime(2025, 7, 31), mwstKonto: 1171, mwst: 8.99),
      _b(8900, 1020, 200, DateTime(2025, 3, 20), steuerart: 'busse'),
      _b(8900, 2208, 4000, _silvester2025, belegTyp: 'abschluss'),
    ];

    test('Aufrechnung = 6280 netto + Steuerbusse 8900', () {
      final l = SteuerrueckstellungService.lage(journal, 2025);
      expect(l.aufrechnungenAuto, 311.01);
      // 30'000 − 111.01 − 200 − 4'000 + 4'000
      expect(l.gewinnVorRueckstellung, 29688.99);
      expect(l.gebucht, 4000);
    });
  });

  group('Lage aus dem Journal', () {
    // 2024: Ertrag 10'000 (darf nicht ins Jahr 2025 fallen).
    // 2025: Ertrag 30'000, Aufwand 5'000, Verkehrsbusse 120, Steuerbusse
    // 200, Rückstellung 4'000 → Gewinn nach Rückstellung 20'680.
    final journal = [
      _b(1100, 3400, 10000, DateTime(2024, 6, 1)),
      _b(1100, 3400, 30000, DateTime(2025, 3, 1)),
      _b(6000, 1020, 5000, DateTime(2025, 4, 1)),
      _b(6280, 1020, 120, DateTime(2025, 7, 31)),
      _b(6281, 1020, 200, DateTime(2025, 3, 20)),
      _b(8900, 2208, 4000, _silvester2025, belegTyp: 'abschluss'),
      // 2026: darf nicht zählen.
      _b(6280, 1020, 20, DateTime(2026, 1, 28)),
      _b(2208, 8900, 2405.50, DateTime(2026, 4, 15), belegTyp: 'abschluss'),
    ];

    test('Gewinn VOR Rückstellung, Bussen 6280+6281, gebucht', () {
      final l = SteuerrueckstellungService.lage(journal, 2025);
      expect(l.gebucht, 4000);
      expect(l.gewinnVorRueckstellung, 24680); // 20'680 + 4'000
      expect(l.aufrechnungenAuto, 320);
    });

    test('Vorschlag hängt nicht von der schon gebuchten Rückstellung ab', () {
      final ohne = journal.where((b) => b.sollKonto != 8900).toList();
      final mit = SteuerrueckstellungService.lage(journal, 2025);
      final vorher = SteuerrueckstellungService.lage(ohne, 2025);
      expect(vorher.gebucht, 0);
      expect(vorher.gewinnVorRueckstellung, mit.gewinnVorRueckstellung);
    });
  });

  group('Buchung', () {
    test('rueckstellungBuchung: Auf- und Abbau, nichts bei gleichem Stand', () {
      expect(rueckstellungBuchung(ziel: 2800, gebucht: 4000), (
        betrag: 1200.0,
        aufbau: false,
      ));
      expect(rueckstellungBuchung(ziel: 4000, gebucht: 0), (
        betrag: 4000.0,
        aufbau: true,
      ));
      expect(rueckstellungBuchung(ziel: 2800, gebucht: 2800).betrag, 0);
    });

    test(
      'buchungszeile: 2208 an 8900 per 31.12., JA-Belegnummer, abschluss',
      () {
        final z = SteuerrueckstellungService.buchungszeile(
          jahr: 2025,
          ziel: 2800,
          gebucht: 4000,
          begruendung: 'Vorschlag 2\'800',
          belegnummer: 'JA2025_D2',
        )!;
        expect(z['datum'], '2025-12-31');
        expect(z['belegnummer'], 'JA2025_D2');
        expect(z['soll_konto'], 2208);
        expect(z['haben_konto'], 8900);
        expect(z['betrag_brutto'], 1200);
        expect(z['betrag_netto'], 1200);
        expect(z['mwst_betrag'], 0);
        expect(z['beleg_typ'], 'abschluss');
        expect(z['zahlungsweg'], 'intern');
        expect(z['geschaeftsjahr'], 2025);
        expect(
          z['notizen'],
          'Jahresabschluss 2025 Schritt D (App): Vorschlag 2\'800',
        );
        // Die gebuchte Zeile erkennt die Lage wieder als Rückstellung.
        final gebucht = _b(
          z['soll_konto'] as int,
          z['haben_konto'] as int,
          z['betrag_brutto'] as double,
          _silvester2025,
          belegTyp: z['beleg_typ'] as String,
          geschaeftsjahr: z['geschaeftsjahr'] as int,
        );
        expect(istRueckstellungsbuchung(gebucht, 2025), isTrue);
      },
    );

    test('Verlustjahr: Abbau auf 0 löst die ganze Rückstellung auf', () {
      expect(
        rueckstellungVorschlag(
          gewinnVorRueckstellung: -5000,
          aufrechnungen: 311.01,
        ),
        0,
      );
      final z = SteuerrueckstellungService.buchungszeile(
        jahr: 2025,
        ziel: 0,
        gebucht: 4000,
        begruendung: 'Verlustjahr',
        belegnummer: 'JA2025_D2',
      )!;
      expect(z['soll_konto'], 2208);
      expect(z['haben_konto'], 8900);
      expect(z['betrag_brutto'], 4000);
    });

    test('buchungszeile: Aufbau 8900 an 2208; null ohne Differenz', () {
      final z = SteuerrueckstellungService.buchungszeile(
        jahr: 2026,
        ziel: 3100,
        gebucht: 0,
        begruendung: 'x',
        belegnummer: 'JA2026_D',
      )!;
      expect(z['soll_konto'], 8900);
      expect(z['haben_konto'], 2208);
      expect(z['datum'], '2026-12-31');
      expect(
        SteuerrueckstellungService.buchungszeile(
          jahr: 2026,
          ziel: 3100,
          gebucht: 3100,
          begruendung: 'x',
          belegnummer: 'JA2026_D2',
        ),
        isNull,
      );
    });
  });
}
