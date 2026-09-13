import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/kachel_zaehler_providers.dart';

void main() {
  group('kommenderSonntag', () {
    test('Samstag → der morgige Sonntag', () {
      expect(kommenderSonntag(DateTime(2026, 9, 12)), DateTime(2026, 9, 13));
    });

    test('Sonntag → derselbe Tag, nicht eine Woche weiter', () {
      expect(kommenderSonntag(DateTime(2026, 9, 13)), DateTime(2026, 9, 13));
    });

    test('Montag → der Sonntag am Ende derselben Woche', () {
      expect(kommenderSonntag(DateTime(2026, 9, 14)), DateTime(2026, 9, 20));
    });

    test('schneidet die Uhrzeit ab', () {
      expect(kommenderSonntag(DateTime(2026, 9, 14, 17, 42)), DateTime(2026, 9, 20));
    });
  });
}
