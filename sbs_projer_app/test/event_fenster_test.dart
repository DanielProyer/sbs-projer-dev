import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_fenster.dart';

void main() {
  final von = DateTime(2026, 10, 10);
  final bis = DateTime(2026, 10, 12);

  test('8 Tage vorher: nein', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 2)), isFalse);
  });
  test('7 Tage vorher: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 3)), isTrue);
  });
  test('waehrend des Events: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 11, 23, 30)), isTrue);
  });
  test('letzter Tag: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 12, 22)), isTrue);
  });
  test('Tag danach: nein', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 13)), isFalse);
  });
  test('ohne Start: nein', () {
    expect(eventImFenster(null, bis, DateTime(2026, 10, 11)), isFalse);
  });
  test('ohne Ende gilt der Starttag als Ende', () {
    expect(eventImFenster(von, null, DateTime(2026, 10, 10)), isTrue);
    expect(eventImFenster(von, null, DateTime(2026, 10, 11)), isFalse);
  });
  test('ueber die Zeitumstellung (25.10.2026) zaehlt der Kalendertag', () {
    final v = DateTime(2026, 11, 1);
    expect(eventImFenster(v, v, DateTime(2026, 10, 25, 1)), isTrue);
    expect(eventImFenster(v, v, DateTime(2026, 10, 24, 23)), isFalse);
  });
}
