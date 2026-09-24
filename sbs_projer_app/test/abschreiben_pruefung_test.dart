import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';

/// Review Mahnwesen Teil 2, I-1/I-2: Was vor dem Abschreiben im Journal
/// steht, entscheidet — gebuchte Zahlung sperrt, gebuchte Abschreibung
/// verhindert eine zweite Buchung.
void main() {
  Buchung b({
    int soll = 1020,
    int haben = 1100,
    String? typ,
    bool storniert = false,
    String? stornoVon,
  }) =>
      Buchung(
        id: 'x',
        userId: 'u',
        datum: DateTime.utc(2026, 9, 1),
        sollKonto: soll,
        habenKonto: haben,
        betragNetto: 100,
        betragBrutto: 100,
        beschreibung: 't',
        belegTyp: typ,
        belegId: 'r1',
        geschaeftsjahr: 2026,
        istStorniert: storniert,
        stornoVonId: stornoVon,
      );

  group('abschreibungSchonGebucht', () {
    test('keine Buchung → buchen', () {
      expect(abschreibungSchonGebucht(const []), isFalse);
    });
    test('Ertragsbuchung allein → buchen', () {
      expect(abschreibungSchonGebucht([b(soll: 1100, haben: 3000, typ: 'rechnung')]), isFalse);
    });
    test('Abschreibung steht → nur Status nachziehen', () {
      expect(abschreibungSchonGebucht([b(soll: 3805, typ: 'abschreibung')]), isTrue);
    });
    test('stornierte Abschreibung zählt nicht (Rechnung reaktiviert)', () {
      expect(
        abschreibungSchonGebucht([
          b(soll: 3805, typ: 'abschreibung', storniert: true),
          b(soll: 1100, haben: 3805, typ: 'abschreibung', stornoVon: 'x'),
        ]),
        isFalse,
      );
    });
  });

  group('zahlungGebucht', () {
    test('Zahlungseingang Haben 1100 → gesperrt', () {
      expect(zahlungGebucht([b(typ: 'zahlung')]), isTrue);
    });
    test('Abschreibung ist keine Zahlung', () {
      expect(zahlungGebucht([b(soll: 3805, typ: 'abschreibung')]), isFalse);
    });
    test('stornierte Zahlung zählt nicht; Ertragsbuchung auch nicht', () {
      expect(
        zahlungGebucht([
          b(typ: 'zahlung', storniert: true),
          b(soll: 1100, haben: 3000, typ: 'rechnung'),
        ]),
        isFalse,
      );
    });
  });
}
