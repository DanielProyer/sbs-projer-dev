import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/arbeitszeit_vorschlag_einsatz.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';

/// Minuten seit Mitternacht aus Stunde/Minute — liest sich wie die Uhrzeit.
int u(int h, [int m = 0]) => h * 60 + m;

Halt start(int abfahrt) => Halt(
  typ: HaltTyp.startort,
  id: 'domat_ems',
  name: 'Domat/Ems',
  abfahrtMin: abfahrt,
  quelle: 'arbeitsbeginn',
);

Halt feierabend(int ankunft) => Halt(
  typ: HaltTyp.startort,
  id: 'domat_ems',
  name: 'Domat/Ems',
  ankunftMin: ankunft,
  quelle: 'feierabend',
);

Halt betrieb(String id, int an, int ab, {String quelle = 'reinigung'}) => Halt(
  typ: HaltTyp.betrieb,
  id: id,
  name: id,
  ankunftMin: an,
  abfahrtMin: ab,
  quelle: quelle,
);

void main() {
  final tag = DateTime(2026, 9, 25);
  // «jetzt» an einem anderen Tag: kein offenes Ende, kein Jetzt-Rückfall.
  final spaeter = DateTime(2026, 9, 27, 20, 15);

  ({String von, String bis})? vorschlag(
    List<Halt> halte, {
    String? betriebId = 'b_stoerung',
    int dauer = 60,
    DateTime? jetzt,
  }) => arbeitszeitVorschlag(
    datum: tag,
    betriebId: betriebId,
    halteDesTages: halte,
    geplanteDauerMin: dauer,
    jetzt: jetzt ?? spaeter,
  );

  group('Betrieb des Einsatzes liegt in der Kette', () {
    test('Zeitfenster (etwa eine Reinigung dort) → genau diese Zeiten', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(9)),
        betrieb('b_stoerung', u(9, 22), u(10, 47)),
        feierabend(u(17)),
      ]);
      // Erfasste Zeiten bleiben unverändert — keine Rundung.
      expect(v, (von: '09:22', bis: '10:47'));
    });

    test('nur ein Stempel dort → Stempel minus Dauer bis Stempel', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b_stoerung', u(10, 32), u(10, 32), quelle: 'wegpunkt'),
        feierabend(u(17)),
      ], dauer: 45);
      expect(v, (von: '09:47', bis: '10:32'));
    });

    test('Stempel-Rückrechnung beginnt nicht vor dem Arbeitsbeginn', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b_stoerung', u(8), u(8), quelle: 'wegpunkt'),
        feierabend(u(17)),
      ]);
      expect(v, (von: '07:30', bis: '08:00'));
    });

    test('ein Zeitfenster geht einem Stempel am selben Betrieb vor', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b_stoerung', u(8), u(8), quelle: 'wegpunkt'),
        betrieb('b2', u(9), u(10)),
        betrieb('b_stoerung', u(14), u(15, 10)),
        feierabend(u(17)),
      ]);
      expect(v, (von: '14:00', bis: '15:10'));
    });

    test(
      'Arbeitsbeginn «unterwegs» am Betrieb zählt nicht als Einsatz-Halt',
      () {
        // _unterwegsHalt trägt die Betriebs-Id, bleibt aber Typ startort und
        // hat nur eine Abfahrt — das ist kein Einsatz dort.
        final v = vorschlag([
          const Halt(
            typ: HaltTyp.startort,
            id: 'b_stoerung',
            name: 'b_stoerung',
            abfahrtMin: 450,
            quelle: 'arbeitsbeginn',
          ),
          betrieb('b1', u(9), u(10)),
          feierabend(u(17)),
        ]);
        // Grösste Lücke 10:00–17:00 → Mitte 13:30 ± 30.
        expect(v, (von: '13:00', bis: '14:00'));
      },
    );
  });

  group('sonst die grösste Lücke der Kette', () {
    test('Mitte der Lücke ± halbe Dauer', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(9)), // Lücke davor 30 min
        betrieb('b2', u(10, 30), u(11, 30)), // Lücke davor 90 min
        feierabend(u(17)), // Lücke davor 330 min
      ]);
      // 11:30–17:00, Mitte 14:15.
      expect(v, (von: '13:45', bis: '14:45'));
    });

    test('auf 5 Minuten gerundet, innerhalb der Lücke', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(9, 3)),
        betrieb('b2', u(9, 58), u(16, 40)),
        feierabend(u(17)),
      ], dauer: 30);
      // 09:03–09:58 (55 min), Mitte 09:30:30 → 09:15–09:45.
      expect(v, (von: '09:15', bis: '09:45'));
    });

    test('Dauer länger als die Lücke → die Lücke, nie darüber hinaus', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(9)), // Lücke davor 30
        betrieb('b2', u(9, 40), u(16, 50)), // Lücke davor 40
        feierabend(u(17)), // Lücke davor 10
      ], dauer: 90);
      // Ein Vorschlag, der die Reinigungen überlappt, erzeugte in «Fahrten
      // aus der Kette» Ankunft vor Abfahrt.
      expect(v, (von: '09:00', bis: '09:40'));
    });

    test('Lücke unter dem 5-Minuten-Raster → die Lücke selbst', () {
      final v = vorschlag([
        betrieb('b1', u(8), u(9, 1)),
        betrieb('b2', u(9, 4), u(10)),
      ]);
      expect(v, (von: '09:01', bis: '09:04'));
    });

    test('bei gleich grossen Lücken die spätere', () {
      final v = vorschlag([
        betrieb('b1', u(8), u(9)),
        betrieb('b2', u(10), u(11)),
        betrieb('b3', u(12), u(13)),
      ]);
      // 09:00–10:00 und 11:00–12:00 gleich lang.
      expect(v, (von: '11:00', bis: '12:00'));
    });

    test('überlappende Halte (Erfassungsfehler) ergeben keine Lücke', () {
      final v = vorschlag([
        betrieb('b1', u(8), u(9, 30)),
        betrieb('b2', u(9), u(10)),
      ]);
      expect(v, isNull);
    });
  });

  group('heute: offenes Ende bis jetzt', () {
    final heute = DateTime(2026, 9, 25, 10, 3);

    test('Abschluss gleich nach der Arbeit → jetzt minus Dauer, nicht vor '
        'der letzten Abfahrt', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(9, 30)), // Lücke davor 30
      ], jetzt: heute); // offen 09:30–10:03 = 33
      expect(v, (von: '09:30', bis: '10:00'));
    });

    test('offenes Ende mit Platz für die ganze Dauer', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(7, 45), u(8, 10)),
      ], jetzt: heute);
      // offen 08:10–10:03 → bis 10:00, von 09:00.
      expect(v, (von: '09:00', bis: '10:00'));
    });

    test('frühere, grössere Lücke schlägt das kurze offene Ende', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(9), u(9, 55)), // Lücke davor 90
      ], jetzt: heute); // offen 8 min
      // 07:30–09:00, Mitte 08:15.
      expect(v, (von: '07:45', bis: '08:45'));
    });

    test('mit Feierabend gibt es kein offenes Ende', () {
      final v = vorschlag([
        start(u(7, 30)),
        betrieb('b1', u(8), u(8, 30)),
        feierabend(u(9, 30)),
      ], jetzt: DateTime(2026, 9, 25, 20));
      // 08:30–09:30 (60) statt bis 20:00.
      expect(v, (von: '08:30', bis: '09:30'));
    });

    test('vergangener Tag ohne Feierabend: kein offenes Ende', () {
      final v = vorschlag([start(u(7, 30)), betrieb('b1', u(8), u(9))]);
      // Nur 07:30–08:00; «jetzt» liegt an einem anderen Tag.
      expect(v, (von: '07:30', bis: '08:00'));
    });
  });

  group('ohne Halte oder Lücke', () {
    test('heute → jetzt minus Dauer bis jetzt, auf 5 Minuten', () {
      final v = vorschlag(
        const [],
        dauer: 45,
        jetzt: DateTime(2026, 9, 25, 14, 22),
      );
      expect(v, (von: '13:35', bis: '14:20'));
    });

    test('heute, nur Arbeitsbeginn nach «jetzt» → Jetzt-Rückfall', () {
      final v = vorschlag([start(u(15))], jetzt: DateTime(2026, 9, 25, 14, 22));
      expect(v, (von: '13:20', bis: '14:20'));
    });

    test('anderer Tag ohne Halte → kein Vorschlag', () {
      expect(vorschlag(const []), isNull);
    });

    test('anderer Tag mit nur einem Halt → kein Vorschlag', () {
      expect(vorschlag([betrieb('b1', u(8), u(9))]), isNull);
    });

    test('kurz nach Mitternacht → kein negatives Fenster', () {
      final v = vorschlag(const [], jetzt: DateTime(2026, 9, 25, 0, 3));
      expect(v, isNull);
    });
  });

  test('Einsatz ohne Betrieb: nur die Lücken-Regel', () {
    final v = vorschlag([
      start(u(7, 30)),
      betrieb('b1', u(8), u(9)),
      feierabend(u(11)),
    ], betriebId: null);
    expect(v, (von: '09:30', bis: '10:30'));
  });

  test('ohne geplante Dauer gilt die Standarddauer (60 min)', () {
    final v = vorschlag([
      start(u(7, 30)),
      betrieb('b1', u(8), u(9)),
      feierabend(u(17)),
    ], dauer: 0);
    // 09:00–17:00, Mitte 13:00.
    expect(v, (von: '12:30', bis: '13:30'));
  });
}
