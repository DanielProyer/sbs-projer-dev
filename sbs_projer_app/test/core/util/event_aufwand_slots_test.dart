import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_aufwand_slots.dart';

void main() {
  DateTime t(int tag) => DateTime(2026, 7, tag);

  group('montageSlotsAusAufwand — Details im Slot-Text', () {
    test('Fall Lumnezia 22.07.: Kategorien und Notiz erscheinen', () {
      final slots = montageSlotsAusAufwand([
        (datum: t(22), stunden: 1, kategorie: 'anfahrt', notiz: null),
        (datum: t(22), stunden: 2, kategorie: 'inbetriebnahme',
            notiz: 'Augenschein'),
      ]);
      expect(slots, hasLength(1));
      expect(slots.first.text,
          'Mi 22.7. — Anfahrt 1h · Inbetriebnahme 2h (Augenschein)');
      expect(slots.first.stunden, 3);
    });

    test('mehrere Zeilen derselben Kategorie am Tag werden summiert, '
        'Notizen zusammengeführt', () {
      final slots = montageSlotsAusAufwand([
        (datum: t(23), stunden: 4, kategorie: 'pikett', notiz: '10–14'),
        (datum: t(23), stunden: 5, kategorie: 'pikett', notiz: '18–23'),
      ]);
      expect(slots.first.text, 'Do 23.7. — Pikett 9h (10–14, 18–23)');
      expect(slots.first.stunden, 9);
    });

    test('halbe Stunden ohne Nachkomma-Müll', () {
      final slots = montageSlotsAusAufwand([
        (datum: t(24), stunden: 2.5, kategorie: 'spesen', notiz: null),
      ]);
      expect(slots.first.text, 'Fr 24.7. — Spesen 2.5h');
    });

    test('unbekannte Kategorie erscheint roh statt zu verschwinden', () {
      final slots = montageSlotsAusAufwand([
        (datum: t(24), stunden: 1, kategorie: 'sonderfall', notiz: null),
      ]);
      expect(slots.first.text, contains('sonderfall 1h'));
    });

    test('Tage aufsteigend, Kategorien in fester Reihenfolge', () {
      final slots = montageSlotsAusAufwand([
        (datum: t(25), stunden: 16, kategorie: 'pikett', notiz: null),
        (datum: t(24), stunden: 16, kategorie: 'pikett', notiz: null),
        (datum: t(25), stunden: 1, kategorie: 'anfahrt', notiz: null),
        (datum: t(25), stunden: 2, kategorie: 'spesen', notiz: null),
      ]);
      expect(slots, hasLength(2));
      expect(slots[0].text, 'Fr 24.7. — Pikett 16h');
      expect(slots[1].text, 'Sa 25.7. — Anfahrt 1h · Pikett 16h · Spesen 2h');
      expect(slots[1].stunden, 19);
    });

    test('mehr als 5 Tage: 4 einzeln + Sammel-Slot mit Kategorie-Summen, '
        'Gesamtstunden bleiben erhalten', () {
      final zeilen = [
        for (var tag = 20; tag <= 26; tag++)
          (datum: t(tag), stunden: 8.0, kategorie: 'pikett', notiz: null),
        (datum: t(26), stunden: 2.0, kategorie: 'spesen', notiz: null),
      ];
      final slots = montageSlotsAusAufwand(zeilen);
      expect(slots, hasLength(5));
      expect(slots.last.text, 'Weitere Tage — Pikett 24h · Spesen 2h');
      expect(slots.last.stunden, 26);
      final total = slots.fold<double>(0, (s, e) => s + e.stunden);
      expect(total, 58); // 7×8 + 2
    });

    test('leer bleibt leer', () {
      expect(montageSlotsAusAufwand([]), isEmpty);
    });
  });
}
