import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';

Buchung _b({
  required String id,
  required int soll,
  required int haben,
  required double betrag,
  String? belegId,
  bool storniert = false,
  String? stornoVon,
}) => Buchung(
  id: id,
  userId: 'u1',
  datum: DateTime(2026, 9, 16),
  sollKonto: soll,
  habenKonto: haben,
  betragNetto: betrag,
  betragBrutto: betrag,
  beschreibung: 'x',
  belegId: belegId,
  geschaeftsjahr: 2026,
  istStorniert: storniert,
  stornoVonId: stornoVon,
);

void main() {
  const rechnungen = {'r1': 'chesa', 'r2': 'chesa', 'r3': 'andere'};

  group('offenesGuthabenJeBetrieb', () {
    test('Haben 2030 baut Guthaben auf, Soll 2030 baut es ab', () {
      final m = offenesGuthabenJeBetrieb([
        _b(id: 'a', soll: 1020, haben: 2030, betrag: 30, belegId: 'r1'),
        _b(id: 'b', soll: 2030, haben: 1100, betrag: 10, belegId: 'r2'),
        _b(id: 'c', soll: 1020, haben: 2030, betrag: 5, belegId: 'r3'),
      ], rechnungen);
      expect(m['chesa'], closeTo(20, 1e-9));
      expect(m['andere'], closeTo(5, 1e-9));
    });

    test('stornierte Originale und Gegenbuchungen zählen nicht', () {
      final m = offenesGuthabenJeBetrieb([
        _b(id: 'a', soll: 1020, haben: 2030, betrag: 30, belegId: 'r1'),
        _b(
          id: 'b',
          soll: 1020,
          haben: 2030,
          betrag: 50,
          belegId: 'r1',
          storniert: true,
        ),
        _b(
          id: 'c',
          soll: 2030,
          haben: 1020,
          betrag: 50,
          belegId: 'r1',
          stornoVon: 'b',
        ),
      ], rechnungen);
      expect(m['chesa'], closeTo(30, 1e-9));
    });

    test('ohne beleg_id oder unbekannte Rechnung → Schlüssel leer', () {
      final m = offenesGuthabenJeBetrieb([
        _b(id: 'a', soll: 1020, haben: 2030, betrag: 30),
        _b(id: 'b', soll: 1020, haben: 2030, betrag: 7, belegId: 'unbekannt'),
      ], rechnungen);
      expect(m[''], closeTo(37, 1e-9));
      expect(m.containsKey('chesa'), isFalse);
    });

    test('Buchungen ohne 2030 werden ignoriert', () {
      final m = offenesGuthabenJeBetrieb([
        _b(id: 'a', soll: 1020, haben: 1100, betrag: 30, belegId: 'r1'),
      ], rechnungen);
      expect(m, isEmpty);
    });
  });

  group('guthabenAbzug', () {
    test('Guthaben kleiner als Brutto → ganzes Guthaben', () {
      expect(guthabenAbzug(guthaben: 30, brutto: 143.75), 30);
    });
    test('Guthaben grösser als Brutto → Brutto', () {
      expect(guthabenAbzug(guthaben: 200, brutto: 143.75), 143.75);
    });
    test('auf 5 Rappen gerundet', () {
      expect(guthabenAbzug(guthaben: 30.02, brutto: 143.75), 30.0);
      expect(guthabenAbzug(guthaben: 30.03, brutto: 143.75), 30.05);
    });
    test('nie negativ', () {
      expect(guthabenAbzug(guthaben: -5, brutto: 143.75), 0);
      expect(guthabenAbzug(guthaben: 30, brutto: 0), 0);
    });
  });
}
