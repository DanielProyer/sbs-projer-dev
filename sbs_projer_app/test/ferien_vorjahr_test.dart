import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/ferien_vorjahr.dart';

void main() {
  List<({DateTime von, DateTime bis})> p(String von, String bis) => [
    (von: DateTime.parse(von), bis: DateTime.parse(bis)),
  ];

  group('vorjahresFerienHinweis', () {
    test('Tag liegt im Fenster des Vorjahres', () {
      final h = vorjahresFerienHinweis(
        perioden: p('2025-07-20', '2025-08-10'),
        tag: DateTime(2026, 7, 31),
        hatAussageFuerJahr: false,
      );
      expect(h, isNotNull);
      expect(h!.von, DateTime(2025, 7, 20));
      expect(h.bis, DateTime(2025, 8, 10));
    });

    test('Toleranz von 5 Tagen gilt einschliesslich', () {
      final perioden = p('2025-07-20', '2025-08-10');
      // genau 5 Tage nach dem Fensterende -> noch ein Hinweis
      expect(
        vorjahresFerienHinweis(
          perioden: perioden,
          tag: DateTime(2026, 8, 15),
          hatAussageFuerJahr: false,
        ),
        isNotNull,
      );
      // 6 Tage danach -> kein Hinweis mehr
      expect(
        vorjahresFerienHinweis(
          perioden: perioden,
          tag: DateTime(2026, 8, 16),
          hatAussageFuerJahr: false,
        ),
        isNull,
      );
      // genau 5 Tage VOR dem Fensterbeginn -> Hinweis
      expect(
        vorjahresFerienHinweis(
          perioden: perioden,
          tag: DateTime(2026, 7, 15),
          hatAussageFuerJahr: false,
        ),
        isNotNull,
      );
    });

    test('Uhrzeit im Tag verschiebt die Grenze nicht', () {
      // Der Vergleich laeuft auf Tagesebene: der 15.08. bleibt drin, auch
      // wenn der uebergebene Zeitpunkt kurz vor Mitternacht liegt.
      expect(
        vorjahresFerienHinweis(
          perioden: p('2025-07-20', '2025-08-10'),
          tag: DateTime(2026, 8, 15, 23, 59),
          hatAussageFuerJahr: false,
        ),
        isNotNull,
      );
    });

    test('kein Hinweis, wenn fuer dieses Jahr eine Aussage vorliegt', () {
      expect(
        vorjahresFerienHinweis(
          perioden: p('2025-07-20', '2025-08-10'),
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: true,
        ),
        isNull,
      );
    });

    test('zwei Jahre zurueck zaehlt auch', () {
      expect(
        vorjahresFerienHinweis(
          perioden: p('2024-07-20', '2024-08-10'),
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: false,
        ),
        isNotNull,
      );
    });

    test('drei Jahre zurueck ist zu alt', () {
      expect(
        vorjahresFerienHinweis(
          perioden: p('2023-07-20', '2023-08-10'),
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: false,
        ),
        isNull,
      );
    });

    test('Perioden des laufenden Jahres loesen keinen Hinweis aus', () {
      // Dort greift die echte Ferienwarnung — kein Vorjahres-Band daneben.
      expect(
        vorjahresFerienHinweis(
          perioden: p('2026-07-20', '2026-08-10'),
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: false,
        ),
        isNull,
      );
    });

    test('zukuenftige Perioden loesen keinen Hinweis aus', () {
      expect(
        vorjahresFerienHinweis(
          perioden: p('2027-07-20', '2027-08-10'),
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: false,
        ),
        isNull,
      );
    });

    test('leere Liste ergibt keinen Hinweis', () {
      expect(
        vorjahresFerienHinweis(
          perioden: const [],
          tag: DateTime(2026, 7, 31),
          hatAussageFuerJahr: false,
        ),
        isNull,
      );
    });

    test('bei mehreren passenden Perioden gewinnt die juengste', () {
      final h = vorjahresFerienHinweis(
        perioden: [
          (von: DateTime(2024, 7, 22), bis: DateTime(2024, 8, 12)),
          (von: DateTime(2025, 7, 20), bis: DateTime(2025, 8, 10)),
        ],
        tag: DateTime(2026, 7, 31),
        hatAussageFuerJahr: false,
      );
      expect(h!.von.year, 2025);
    });

    test('Fenster ueber den Jahreswechsel wird erkannt', () {
      // Wintersperre 27.12.2024–06.01.2025, geprueft am 02.01.2026.
      final h = vorjahresFerienHinweis(
        perioden: [(von: DateTime(2024, 12, 27), bis: DateTime(2025, 1, 6))],
        tag: DateTime(2026, 1, 2),
        hatAussageFuerJahr: false,
      );
      expect(h, isNotNull);
    });
  });
}
