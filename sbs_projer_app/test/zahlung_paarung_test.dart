import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlung_paarung.dart';

/// Ein Zahlungseingang, reduziert auf das, was die Paarung braucht.
typedef Zahlung = ({DateTime datum, String key});

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
}
