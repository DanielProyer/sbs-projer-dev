import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/termin_abgleich.dart';

void main() {
  group('terminDecktVorschlagAb', () {
    const betriebA = 'betrieb-a';
    const betriebB = 'betrieb-b';

    test('Treffer: gleicher Betrieb, gleicher Typ, gleiches Datum', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'eroeffnungsreinigung',
        vorschlagDatum: DateTime(2026, 4, 15),
        bestehendeTermine: [
          TerminVergleich(
            betriebId: betriebA,
            typ: 'eroeffnungsreinigung',
            datum: DateTime(2026, 4, 15),
          ),
        ],
      );
      expect(gedeckt, isTrue);
    });

    test('knapp innerhalb: 7 Tage Abweichung zählt noch als gedeckt', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'endreinigung',
        vorschlagDatum: DateTime(2026, 10, 20),
        bestehendeTermine: [
          TerminVergleich(
            betriebId: betriebA,
            typ: 'endreinigung',
            datum: DateTime(2026, 10, 13),
          ),
        ],
      );
      expect(gedeckt, isTrue);
    });

    test('knapp ausserhalb: 8 Tage Abweichung zählt nicht mehr', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'endreinigung',
        vorschlagDatum: DateTime(2026, 10, 20),
        bestehendeTermine: [
          TerminVergleich(
            betriebId: betriebA,
            typ: 'endreinigung',
            datum: DateTime(2026, 10, 12),
          ),
        ],
      );
      expect(gedeckt, isFalse);
    });

    test('anderer Typ deckt den Vorschlag nicht ab', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'eroeffnungsreinigung',
        vorschlagDatum: DateTime(2026, 4, 15),
        bestehendeTermine: [
          TerminVergleich(
            betriebId: betriebA,
            typ: 'endreinigung',
            datum: DateTime(2026, 4, 15),
          ),
        ],
      );
      expect(gedeckt, isFalse);
    });

    test('anderer Betrieb deckt den Vorschlag nicht ab', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'eroeffnungsreinigung',
        vorschlagDatum: DateTime(2026, 4, 15),
        bestehendeTermine: [
          TerminVergleich(
            betriebId: betriebB,
            typ: 'eroeffnungsreinigung',
            datum: DateTime(2026, 4, 15),
          ),
        ],
      );
      expect(gedeckt, isFalse);
    });

    test('keine bestehenden Termine -> nie gedeckt', () {
      final gedeckt = terminDecktVorschlagAb(
        vorschlagBetriebId: betriebA,
        vorschlagTyp: 'eroeffnungsreinigung',
        vorschlagDatum: DateTime(2026, 4, 15),
        bestehendeTermine: const [],
      );
      expect(gedeckt, isFalse);
    });

    test(
      'Datum vor dem bestehenden Termin (Vorlauf) wird ebenfalls erkannt',
      () {
        final gedeckt = terminDecktVorschlagAb(
          vorschlagBetriebId: betriebA,
          vorschlagTyp: 'endreinigung',
          vorschlagDatum: DateTime(2026, 10, 13),
          bestehendeTermine: [
            TerminVergleich(
              betriebId: betriebA,
              typ: 'endreinigung',
              datum: DateTime(2026, 10, 20),
            ),
          ],
        );
        expect(gedeckt, isTrue);
      },
    );
  });
}
