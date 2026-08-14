import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/kuehler_monitoring.dart';

void main() {
  group('istAusserhalbSollbereich', () {
    test('Wert innerhalb des Bereichs ist nicht ausserhalb', () {
      expect(
        istAusserhalbSollbereich(temperatur: 4.0, sollMin: 2.0, sollMax: 6.0),
        isFalse,
      );
    });

    test('Wert unter sollMin ist ausserhalb', () {
      expect(
        istAusserhalbSollbereich(temperatur: 1.0, sollMin: 2.0, sollMax: 6.0),
        isTrue,
      );
    });

    test('Wert über sollMax ist ausserhalb', () {
      expect(
        istAusserhalbSollbereich(temperatur: 7.0, sollMin: 2.0, sollMax: 6.0),
        isTrue,
      );
    });

    test('Wert exakt auf sollMin gilt als innerhalb (Grenzfall)', () {
      expect(
        istAusserhalbSollbereich(temperatur: 2.0, sollMin: 2.0, sollMax: 6.0),
        isFalse,
      );
    });

    test('Wert exakt auf sollMax gilt als innerhalb (Grenzfall)', () {
      expect(
        istAusserhalbSollbereich(temperatur: 6.0, sollMin: 2.0, sollMax: 6.0),
        isFalse,
      );
    });

    test('Ohne jeglichen Sollbereich (beide null) nie ausserhalb', () {
      expect(
        istAusserhalbSollbereich(temperatur: 999.0, sollMin: null, sollMax: null),
        isFalse,
      );
    });

    test('Nur sollMin gesetzt: unten geprüft, oben unbegrenzt', () {
      expect(
        istAusserhalbSollbereich(temperatur: 1.0, sollMin: 2.0, sollMax: null),
        isTrue,
      );
      expect(
        istAusserhalbSollbereich(temperatur: 500.0, sollMin: 2.0, sollMax: null),
        isFalse,
      );
    });

    test('Nur sollMax gesetzt: oben geprüft, unten unbegrenzt', () {
      expect(
        istAusserhalbSollbereich(temperatur: -500.0, sollMin: null, sollMax: 6.0),
        isFalse,
      );
      expect(
        istAusserhalbSollbereich(temperatur: 7.0, sollMin: null, sollMax: 6.0),
        isTrue,
      );
    });
  });

  group('messungText', () {
    test('Gleicher Tag: nur Uhrzeit', () {
      final jetzt = DateTime(2026, 8, 14, 14, 30);
      final gemessenAm = DateTime(2026, 8, 14, 14, 5);
      expect(
        messungText(gemessenAm, 4.2, jetzt: jetzt),
        '4.2 °C 14:05',
      );
    });

    test('Anderer Tag: Datum + Uhrzeit', () {
      final jetzt = DateTime(2026, 8, 14, 9, 0);
      final gemessenAm = DateTime(2026, 8, 13, 22, 5);
      expect(
        messungText(gemessenAm, 3.0, jetzt: jetzt),
        '3.0 °C 13.08. 22:05',
      );
    });

    test('Eine Nachkommastelle, gerundet', () {
      final jetzt = DateTime(2026, 8, 14, 14, 30);
      final gemessenAm = DateTime(2026, 8, 14, 8, 0);
      expect(
        messungText(gemessenAm, 4.26, jetzt: jetzt),
        '4.3 °C 08:00',
      );
    });

    test('Zweistellige Minuten/Stunden werden mit führender Null aufgefüllt', () {
      final jetzt = DateTime(2026, 8, 14, 14, 30);
      final gemessenAm = DateTime(2026, 8, 14, 9, 5);
      expect(
        messungText(gemessenAm, -1.0, jetzt: jetzt),
        '-1.0 °C 09:05',
      );
    });
  });
}
