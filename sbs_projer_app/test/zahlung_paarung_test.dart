import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlung_paarung.dart';

/// Ein Zahlungseingang, reduziert auf das, was die Paarung braucht.
typedef Zahlung = ({DateTime datum, String key});

/// Zahlungseingang mit Betrag (für die betrags-bewusste Paarung).
typedef ZahlungMitBetrag = ({DateTime datum, double betrag, String key});

Map<String, Zahlung> paare(
  List<Zahlung> zahlungen,
  List<({String id, DateTime rechnungsdatum})> forderungen,
) =>
    paareNachDatum<Zahlung>(
      zahlungen: zahlungen,
      datumVon: (z) => z.datum,
      forderungen: forderungen,
    );

void main() {
  final juni = (datum: DateTime(2026, 6, 26), key: 'tx-juni');
  final maerz = (datum: DateTime(2026, 3, 25), key: 'tx-maerz');

  group('paareNachDatum (Regel Daniel 28.07.2026)', () {
    test('neueste Zahlung zur neuesten Forderung, dann absteigend', () {
      final paarung = paare([juni, maerz], [
        (id: 'alt', rechnungsdatum: DateTime(2026, 1, 20)),
        (id: 'neu', rechnungsdatum: DateTime(2026, 5, 12)),
      ]);
      expect(paarung['neu'], juni);
      expect(paarung['alt'], maerz);
    });

    test('Reihenfolge der Eingabe ist egal', () {
      final paarung = paare([maerz, juni], [
        (id: 'neu', rechnungsdatum: DateTime(2026, 5, 12)),
        (id: 'alt', rechnungsdatum: DateTime(2026, 1, 20)),
      ]);
      expect(paarung['neu'], juni);
      expect(paarung['alt'], maerz);
    });

    test('der camt-Schlüssel folgt der gepaarten Zahlung', () {
      final paarung = paare([juni, maerz], [
        (id: 'alt', rechnungsdatum: DateTime(2026, 1, 20)),
        (id: 'neu', rechnungsdatum: DateTime(2026, 5, 12)),
      ]);
      expect(paarung['neu']!.key, 'tx-juni');
      expect(paarung['alt']!.key, 'tx-maerz');
    });

    test('mehr Forderungen als Zahlungen: Rest bekommt die älteste Zahlung',
        () {
      final paarung = paare([juni], [
        (id: 'a', rechnungsdatum: DateTime(2026, 5, 12)),
        (id: 'b', rechnungsdatum: DateTime(2026, 3, 2)),
        (id: 'c', rechnungsdatum: DateTime(2026, 1, 20)),
      ]);
      expect(paarung.length, 3);
      expect(paarung.values.every((z) => z == juni), isTrue);
    });

    test('mehr Zahlungen als Forderungen: überzählige bleiben unbenutzt', () {
      final paarung = paare(
        [juni, (datum: DateTime(2026, 5, 1), key: 'tx-mai'), maerz],
        [(id: 'x', rechnungsdatum: DateTime(2026, 5, 12))],
      );
      expect(paarung, {'x': juni});
    });

    test('eine Zahlung, eine Forderung', () {
      expect(paare([juni], [(id: 'x', rechnungsdatum: DateTime(2026, 5, 12))]),
          {'x': juni});
    });

    test('leere Eingaben -> leere Paarung', () {
      expect(paare([], [(id: 'x', rechnungsdatum: DateTime(2026))]), isEmpty);
      expect(paare([juni], []), isEmpty);
    });

    test('gleiche Rechnungsdaten -> jede Forderung bekommt eine Zahlung', () {
      final paarung = paare([juni, maerz], [
        (id: 'a', rechnungsdatum: DateTime(2026, 5, 12)),
        (id: 'b', rechnungsdatum: DateTime(2026, 5, 12)),
      ]);
      expect(paarung.length, 2);
      expect(paarung.values.toSet(), {juni, maerz});
    });
  });

  group('paareMitBetrag (Sammelzahler-Fix 07.08.2026)', () {
    Map<String, ZahlungMitBetrag> paareB(
      List<ZahlungMitBetrag> zahlungen,
      List<({String id, DateTime rechnungsdatum, double betrag})> forderungen,
    ) =>
        paareMitBetrag<ZahlungMitBetrag>(
          zahlungen: zahlungen,
          datumVon: (z) => z.datum,
          betragVon: (z) => z.betrag,
          forderungen: forderungen,
        );

    test('gleicher Tag, verschiedene Beträge → Betrag entscheidet', () {
      // Weisse Arena: zwei Zahlungen vom 17.04. auf zwei Rechnungen vom 04.04.
      final z1 = (datum: DateTime(2026, 4, 17), betrag: 74.60, key: 'tx-74');
      final z2 = (datum: DateTime(2026, 4, 17), betrag: 132.95, key: 'tx-132');
      final paarung = paareB([z1, z2], [
        (id: 'r132', rechnungsdatum: DateTime(2026, 4, 4), betrag: 132.95),
        (id: 'r74', rechnungsdatum: DateTime(2026, 4, 4), betrag: 74.60),
      ]);
      expect(paarung['r74']!.key, 'tx-74');
      expect(paarung['r132']!.key, 'tx-132');
    });

    test('Betrag-exakt schlägt Datums-Nähe', () {
      final zNeu = (datum: DateTime(2026, 6, 1), betrag: 50.0, key: 'tx-neu');
      final zAlt = (datum: DateTime(2026, 3, 1), betrag: 80.0, key: 'tx-alt');
      final paarung = paareB([zNeu, zAlt], [
        // Neueste Forderung hat den Betrag der ÄLTEREN Zahlung.
        (id: 'f80', rechnungsdatum: DateTime(2026, 5, 20), betrag: 80.0),
        (id: 'f50', rechnungsdatum: DateTime(2026, 2, 10), betrag: 50.0),
      ]);
      expect(paarung['f80']!.key, 'tx-alt');
      expect(paarung['f50']!.key, 'tx-neu');
    });

    test('ohne Betrags-Treffer identisch zur Datums-Regel', () {
      final z1 = (datum: DateTime(2026, 6, 26), betrag: 99.0, key: 'tx-juni');
      final z2 = (datum: DateTime(2026, 3, 25), betrag: 88.0, key: 'tx-maerz');
      final paarung = paareB([z1, z2], [
        (id: 'alt', rechnungsdatum: DateTime(2026, 1, 20), betrag: 10.0),
        (id: 'neu', rechnungsdatum: DateTime(2026, 5, 12), betrag: 20.0),
      ]);
      expect(paarung['neu']!.key, 'tx-juni');
      expect(paarung['alt']!.key, 'tx-maerz');
    });

    test('Mischfall: ein Betrags-Paar, Rest nach Datum', () {
      final zA = (datum: DateTime(2026, 6, 1), betrag: 74.60, key: 'tx-a');
      final zB = (datum: DateTime(2026, 5, 1), betrag: 200.0, key: 'tx-b');
      final zC = (datum: DateTime(2026, 4, 1), betrag: 300.0, key: 'tx-c');
      final paarung = paareB([zA, zB, zC], [
        (id: 'f1', rechnungsdatum: DateTime(2026, 5, 15), betrag: 74.60),
        (id: 'f2', rechnungsdatum: DateTime(2026, 4, 15), betrag: 111.0),
        (id: 'f3', rechnungsdatum: DateTime(2026, 3, 15), betrag: 222.0),
      ]);
      expect(paarung['f1']!.key, 'tx-a'); // Betrag exakt
      expect(paarung['f2']!.key, 'tx-b'); // Rest: neueste zu neuester
      expect(paarung['f3']!.key, 'tx-c');
    });

    test('mehr Forderungen als Zahlungen: Rest bekommt die älteste Zahlung',
        () {
      final z = (datum: DateTime(2026, 6, 1), betrag: 74.60, key: 'tx-a');
      final paarung = paareB([z], [
        (id: 'f1', rechnungsdatum: DateTime(2026, 5, 15), betrag: 74.60),
        (id: 'f2', rechnungsdatum: DateTime(2026, 4, 15), betrag: 111.0),
      ]);
      expect(paarung['f1']!.key, 'tx-a');
      expect(paarung['f2']!.key, 'tx-a');
    });

    test('leere Eingaben -> leere Paarung', () {
      expect(paareB([], []), isEmpty);
    });
  });
}
