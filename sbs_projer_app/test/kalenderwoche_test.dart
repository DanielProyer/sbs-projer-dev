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

  // Tourenplan (Review 26.09.2026): «Nächste Woche» rechnete mit
  // `Duration(days: 7)`. Über die Zeitumstellung sind das 167 bzw. 169
  // Stunden — aus Mo 19.10.2026 wurde So 25.10. 23:00. Die Erwartungen hier
  // sind Mitternacht am richtigen Tag, in jeder Zeitzone.
  group('wochePlus / wochenStart über die Zeitumstellung', () {
    void istMitternacht(DateTime d, DateTime erwartet) {
      expect(d, erwartet);
      expect(d.hour, 0, reason: 'Stunde von $d');
      expect(d.minute, 0, reason: 'Minute von $d');
    }

    test('Sommerzeit-Ende: Mo 19.10.2026 → Mo 26.10.2026 und zurück', () {
      final naechste = wochePlus(DateTime(2026, 10, 19), 1);
      istMitternacht(naechste, DateTime(2026, 10, 26));
      expect(naechste.weekday, DateTime.monday);
      istMitternacht(wochePlus(naechste, -1), DateTime(2026, 10, 19));
    });

    test('Sommerzeit-Beginn: Mo 22.03.2027 → Mo 29.03.2027 und zurück', () {
      final naechste = wochePlus(DateTime(2027, 3, 22), 1);
      istMitternacht(naechste, DateTime(2027, 3, 29));
      expect(naechste.weekday, DateTime.monday);
      istMitternacht(wochePlus(naechste, -1), DateTime(2027, 3, 22));
    });

    test('mehrere Wochen und Monats-/Jahreswechsel', () {
      final faelle = <(DateTime, int, DateTime)>[
        (DateTime(2026, 9, 28), 2, DateTime(2026, 10, 12)),
        (DateTime(2026, 12, 28), 1, DateTime(2027, 1, 4)),
        (DateTime(2027, 1, 4), -1, DateTime(2026, 12, 28)),
      ];
      for (final (von, wochen, erwartet) in faelle) {
        istMitternacht(wochePlus(von, wochen), erwartet);
      }
    });

    test('wochenStart ist der Montag um Mitternacht', () {
      // Sonntag spät am Abend nach der Umstellung — mit 6 × 24 h zurück
      // kam hier ein Dienstag heraus.
      istMitternacht(
        wochenStart(DateTime(2026, 10, 25, 23, 30)),
        DateTime(2026, 10, 19),
      );
      istMitternacht(
        wochenStart(DateTime(2026, 10, 26)),
        DateTime(2026, 10, 26),
      );
      istMitternacht(
        wochenStart(DateTime(2027, 3, 28, 12)),
        DateTime(2027, 3, 22),
      );
      // Woche über den Jahreswechsel.
      istMitternacht(
        wochenStart(DateTime(2027, 1, 1)),
        DateTime(2026, 12, 28),
      );
    });

    test('Wochenstart plus sechs Tage bleibt in derselben Woche', () {
      final mo = wochenStart(DateTime(2026, 10, 21));
      for (var i = 0; i < 7; i++) {
        final tag = DateTime(mo.year, mo.month, mo.day + i);
        expect(tag.weekday, DateTime.monday + i);
        expect(wochenStart(tag), mo, reason: 'Tag $i');
      }
    });
  });
}
