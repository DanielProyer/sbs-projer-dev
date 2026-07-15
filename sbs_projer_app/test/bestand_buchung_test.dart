import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/bestand_buchung.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

MaterialBestellposition _pos({
  required String id,
  String? lagerId,
  String? kategorieName,
  double menge = 1,
  int sortierung = 0,
  String name = 'Artikel',
}) =>
    MaterialBestellposition(
      id: id,
      bestellungId: 'b1',
      lagerId: lagerId,
      name: name,
      menge: menge,
      kategorieName: kategorieName,
      sortierung: sortierung,
    );

void main() {
  group('istBuchbar', () {
    test('mit lagerId → true', () {
      expect(istBuchbar(_pos(id: 'p1', lagerId: 'l1')), isTrue);
    });

    test('ohne lagerId (Freitext) → false', () {
      expect(istBuchbar(_pos(id: 'p1')), isFalse);
    });

    test('leere lagerId → false', () {
      expect(istBuchbar(_pos(id: 'p1', lagerId: '')), isFalse);
    });
  });

  group('abholPayload', () {
    test('buchbare Position mit Menge > 0 → im Payload', () {
      final payload = abholPayload(
        positionen: [_pos(id: 'p1', lagerId: 'l1')],
        mengen: {'p1': 3},
      );
      expect(payload, {'p1': 3.0});
    });

    test('Position ohne lagerId → nicht im Payload', () {
      final payload = abholPayload(
        positionen: [_pos(id: 'p1')],
        mengen: {'p1': 3},
      );
      expect(payload, isEmpty);
    });

    test('Menge fehlt / 0 / negativ → nicht im Payload', () {
      final positionen = [
        _pos(id: 'p1', lagerId: 'l1'),
        _pos(id: 'p2', lagerId: 'l2'),
        _pos(id: 'p3', lagerId: 'l3'),
      ];
      final payload = abholPayload(
        positionen: positionen,
        mengen: {'p2': 0, 'p3': -5},
      );
      expect(payload, isEmpty);
    });

    test('mehrere Positionen auf dasselbe Lager bleiben getrennt (Positions-Bezug)', () {
      final payload = abholPayload(
        positionen: [
          _pos(id: 'p1', lagerId: 'l1'),
          _pos(id: 'p2', lagerId: 'l1'),
        ],
        mengen: {'p1': 2, 'p2': 3},
      );
      expect(payload, {'p1': 2.0, 'p2': 3.0});
    });

    test('leere Eingabe → leere Map', () {
      expect(abholPayload(positionen: [], mengen: {}), isEmpty);
    });
  });

  group('positionenNachKategorie', () {
    test('gruppiert nach Kategorie, Reihenfolge des ersten Auftretens', () {
      final gruppen = positionenNachKategorie([
        _pos(id: 'p1', kategorieName: 'Reinigungsmaterial'),
        _pos(id: 'p2', kategorieName: 'Verbrauchsmaterial'),
        _pos(id: 'p3', kategorieName: 'Reinigungsmaterial'),
      ]);
      expect(gruppen.map((g) => g.name).toList(),
          ['Reinigungsmaterial', 'Verbrauchsmaterial']);
      expect(gruppen.first.positionen.map((p) => p.id).toList(), ['p1', 'p3']);
    });

    test('Positionen ohne Kategorie landen in „Übrige" ganz am Schluss', () {
      final gruppen = positionenNachKategorie([
        _pos(id: 'p1'),
        _pos(id: 'p2', kategorieName: 'Reinigungsmaterial'),
      ]);
      expect(gruppen.map((g) => g.name).toList(), ['Reinigungsmaterial', 'Übrige']);
      expect(gruppen.last.positionen.single.id, 'p1');
    });

    test('leere Liste → leer', () {
      expect(positionenNachKategorie([]), isEmpty);
    });
  });
}
