import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tages_sync.dart';

void main() {
  group('brauchtTagesSync', () {
    test('null (noch nie synchronisiert) → fällig', () {
      expect(brauchtTagesSync(null, DateTime(2026, 7, 14, 10)), isTrue);
    });

    test('gleicher Kalendertag, andere Uhrzeit → nicht fällig', () {
      expect(
        brauchtTagesSync(DateTime(2026, 7, 14, 8, 5), DateTime(2026, 7, 14, 23, 59)),
        isFalse,
      );
    });

    test('Vortag → fällig', () {
      expect(
        brauchtTagesSync(DateTime(2026, 7, 13, 23, 50), DateTime(2026, 7, 14, 0, 1)),
        isTrue,
      );
    });

    test('Monatswechsel → fällig', () {
      expect(
        brauchtTagesSync(DateTime(2026, 6, 30, 12), DateTime(2026, 7, 1, 9)),
        isTrue,
      );
    });

    test('Jahreswechsel → fällig', () {
      expect(
        brauchtTagesSync(DateTime(2025, 12, 31, 23), DateTime(2026, 1, 1, 1)),
        isTrue,
      );
    });

    test('exakt gleicher Zeitpunkt → nicht fällig', () {
      final t = DateTime(2026, 7, 14, 10, 30);
      expect(brauchtTagesSync(t, t), isFalse);
    });
  });
}
