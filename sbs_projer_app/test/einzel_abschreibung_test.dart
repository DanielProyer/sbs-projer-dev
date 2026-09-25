import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Einzelne Abschreibung über das Mahnwesen.
///
/// WARUM die Tests: Bis zum 20.09.2026 buchte `MahnwesenService.abschreiben`
/// auf das **Rechnungsdatum**. Bei Dischma 2026-05-0579 (Rechnung 08.05.,
/// Entscheid 20.09.) wäre die MWST-Rückholung damit in Q2/2026 gefallen —
/// ein längst eingereichtes Quartal, korrigierbar nur über eine
/// Korrekturabrechnung. Richtig ist der Tag des Entscheids (Art. 41 Abs. 2
/// MWSTG). Der Fall wurde damals von Hand gebucht; diese Tests halten fest,
/// dass der Code es jetzt selbst richtig macht.
Rechnung _rg({
  double netto = 69.00,
  double mwst = 5.60,
  double? brutto,
  DateTime? datum,
  String? nummer = '2026-05-0579',
}) => Rechnung(
  id: 'abcdef1234567890',
  userId: 'u',
  rechnungsnummer: nummer,
  rechnungstyp: 'kundenrechnung',
  betriebId: 'b',
  rechnungsdatum: datum ?? DateTime(2026, 5, 8),
  faelligkeitsdatum: (datum ?? DateTime(2026, 5, 8)).add(
    const Duration(days: 30),
  ),
  betragNetto: netto,
  mwstBetrag: mwst,
  betragBrutto: brutto ?? netto + mwst,
);

void main() {
  final heute = DateTime(2026, 9, 20, 14, 35);

  test('bucht auf den Entscheidtag, nicht auf das Rechnungsdatum', () {
    final a = einzelAbschreibung(_rg(), heute: heute);
    expect(a.datum, DateTime(2026, 9, 20), reason: 'Q3, nicht Q2');
    expect(a.datum.hour, 0, reason: 'ohne Uhrzeit');
  });

  test('Dischma-Fall: 69.00 Aufwand + 5.60 MWST, zusammen 74.60', () {
    final a = einzelAbschreibung(_rg(), heute: heute);
    expect(a.brutto, 74.60);
    expect(a.netto, 69.00);
    expect(a.mwst, 5.60);
    expect(a.netto + a.mwst, closeTo(a.brutto, 0.001));
  });

  test(
    'die Buchung stellt den Debitor immer glatt — auch bei krummem Betrag',
    () {
      // Frueher wurde das Brutto auf 5 Rappen nachgerundet; auf 1100 steht aber
      // der ungerundete Betrag, die Differenz waere stehen geblieben.
      final a = einzelAbschreibung(_rg(netto: 69.03, mwst: 5.60), heute: heute);
      expect(a.brutto, 74.63);
      expect(a.netto + a.mwst, closeTo(74.63, 0.001));
    },
  );

  test(
    'Netto folgt aus brutto minus MWST, auch wenn betrag_netto abweicht',
    () {
      // Altrechnung, deren drei Felder nicht zusammenpassen: massgebend ist,
      // was auf 1100 liegt (brutto).
      final a = einzelAbschreibung(
        _rg(netto: 60.00, mwst: 5.60, brutto: 74.60),
        heute: heute,
      );
      expect(a.brutto, 74.60);
      expect(a.netto, 69.00);
      expect(a.netto + a.mwst, closeTo(a.brutto, 0.001));
    },
  );

  test(
    'unsinnige MWST wird nicht gebucht, statt ein negatives Netto zu erzeugen',
    () {
      for (final unsinn in [-1.0, 0.0, 100.0]) {
        final a = einzelAbschreibung(
          _rg(mwst: unsinn, brutto: 74.60),
          heute: heute,
        );
        expect(a.mwst, 0.0, reason: 'MWST $unsinn');
        expect(a.netto, 74.60);
      }
    },
  );

  test('Beschreibung nennt Nummer und Rechnungsdatum', () {
    final a = einzelAbschreibung(_rg(), heute: heute);
    expect(a.beschreibung, contains('2026-05-0579'));
    expect(a.beschreibung, contains('08.05.2026'));
  });

  test('ohne Rechnungsnummer greift der Anfang der Id', () {
    final a = einzelAbschreibung(_rg(nummer: null), heute: heute);
    expect(a.beschreibung, contains('abcdef12'));
  });

  group('mit Kundenguthaben (Review I3)', () {
    Rechnung mitGuthaben() => Rechnung(
          id: 'abcdef1234567890',
          userId: 'u',
          rechnungsnummer: '2026-11-0001',
          rechnungstyp: 'kundenrechnung',
          betriebId: 'b',
          rechnungsdatum: DateTime(2026, 11, 20),
          faelligkeitsdatum: DateTime(2026, 12, 20),
          betragNetto: 132.95,
          mwstBetrag: 10.80,
          betragBrutto: 143.75,
          guthabenVerrechnet: 30,
        );

    test('abgeschrieben wird nur «zu zahlen», MWST anteilig', () {
      final a = einzelAbschreibung(mitGuthaben(), heute: heute);
      expect(a.brutto, 113.75);
      // 10.80 × 113.75 / 143.75 = 8.546… → 8.55
      expect(a.mwst, 8.55);
      expect(a.netto, 105.20);
      expect(a.guthaben, 30);
    });

    test('ohne Guthaben unverändert, guthaben 0', () {
      final a = einzelAbschreibung(_rg(), heute: heute);
      expect(a.guthaben, 0);
      expect(a.brutto, 74.60);
    });

    test('ganz durch Guthaben gedeckt: nichts abzuschreiben', () {
      final r = Rechnung(
        id: 'abcdef1234567890',
        userId: 'u',
        rechnungstyp: 'kundenrechnung',
        rechnungsdatum: DateTime(2026, 11, 20),
        faelligkeitsdatum: DateTime(2026, 12, 20),
        betragNetto: 18.50,
        mwstBetrag: 1.50,
        betragBrutto: 20,
        guthabenVerrechnet: 20,
      );
      final a = einzelAbschreibung(r, heute: heute);
      expect(a.brutto, 0);
      expect(a.mwst, 0);
      expect(a.netto, 0);
      expect(a.guthaben, 20);
    });
  });
}
