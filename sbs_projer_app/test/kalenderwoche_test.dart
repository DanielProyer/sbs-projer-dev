import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/kalenderwoche.dart';

/// ISO-Kalenderwoche UND ihr Jahr: Am Jahreswechsel gehört ein Datum oft zur
/// Woche des Nachbarjahres. Das Pikett-Formular nahm bis 26.09.2026
/// `datum.year` — aus KW 1/2026 (ab Mo 29.12.2025) wurde so KW 1/2025.
void main() {
  void pruefe(DateTime datum, int kw, int jahr) {
    final d = '${datum.day}.${datum.month}.${datum.year}';
    expect(kalenderwoche(datum), kw, reason: 'KW von $d');
    expect(isoWochenjahr(datum), jahr, reason: 'Wochenjahr von $d');
  }

  test('Ende Dezember kann schon zur KW 1 des Folgejahres gehören', () {
    pruefe(DateTime(2025, 12, 29), 1, 2026);
    pruefe(DateTime(2024, 12, 31), 1, 2025);
  });

  test('Anfang Januar kann noch zur letzten KW des Vorjahres gehören', () {
    pruefe(DateTime(2027, 1, 1), 53, 2026);
    pruefe(DateTime(2027, 1, 3), 53, 2026); // Sonntag derselben Woche
    pruefe(DateTime(2027, 1, 4), 1, 2027); // Montag danach
  });

  test('Sonntag 04.01.2026 liegt noch in KW 1/2026', () {
    pruefe(DateTime(2026, 1, 4), 1, 2026);
  });

  test('mitten im Jahr sind Wochenjahr und Kalenderjahr gleich', () {
    pruefe(DateTime(2026, 6, 15), 25, 2026);
    // Sommerzeit: lokale Uhrzeit spät am Abend darf nichts verschieben.
    pruefe(DateTime(2026, 9, 17, 23, 30), 38, 2026);
  });
}
