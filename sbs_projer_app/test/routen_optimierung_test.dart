import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/routen_optimierung.dart';

/// Testwelt «Linie»: vier Bloecke auf einer Strasse, je Abschnitt 10 Minuten.
///
///   Start(-1) — A(0) — B(1) — C(2) — D(3)
///
/// Die Matrix steht ausgeschrieben da, damit jede Erwartung im Test von Hand
/// nachrechenbar ist (und nicht dieselbe Formel prueft, die sie erzeugt hat).
const Map<String, int> _matrix = {
  'A>B': 10,
  'B>A': 10,
  'A>C': 20,
  'C>A': 20,
  'A>D': 30,
  'D>A': 30,
  'B>C': 10,
  'C>B': 10,
  'B>D': 20,
  'D>B': 20,
  'C>D': 10,
  'D>C': 10,
};

/// Anfahrt vom Startort (und Heimweg zurueck) — der Start liegt eine
/// Wegeinheit vor A.
const Map<String, int> _vomStart = {'A': 10, 'B': 20, 'C': 30, 'D': 40};

int _fahrzeit(String von, String nach) => _matrix['$von>$nach']!;
int _anfahrt(String id) => _vomStart[id]!;
int _heimweg(String id) => _vomStart[id]!;

/// Einbahn-Welt: gegen die Fahrtrichtung kostet es ein Vielfaches. Prueft,
/// dass die Optimierung auch bei asymmetrischer Matrix korrekt rechnet.
const Map<String, int> _einbahn = {
  'X>Y': 10,
  'Y>X': 100,
  'Y>Z': 10,
  'Z>Y': 100,
  'X>Z': 50,
  'Z>X': 50,
};

int _fahrzeitEinbahn(String von, String nach) => _einbahn['$von>$nach']!;

/// Grossfall: 12 Bloecke, wieder auf einer Linie (Position in Kilometern,
/// 3 Minuten je Kilometer), Startort bei Kilometer 0.
const Map<String, int> _km = {
  'B01': 12,
  'B02': 3,
  'B03': 27,
  'B04': 8,
  'B05': 19,
  'B06': 1,
  'B07': 31,
  'B08': 15,
  'B09': 6,
  'B10': 24,
  'B11': 10,
  'B12': 21,
};

int _fahrzeitGross(String von, String nach) =>
    (_km[von]! - _km[nach]!).abs() * 3;
int _anfahrtGross(String id) => _km[id]! * 3;

int _kosten(
  List<String> reihenfolge, {
  int Function(String, String) fahrzeit = _fahrzeit,
  int Function(String)? anfahrt,
  int Function(String)? heimweg,
}) => gesamtFahrzeit(
  reihenfolge: reihenfolge,
  fahrzeitZwischen: fahrzeit,
  anfahrtVomStart: anfahrt,
  heimwegZumStart: heimweg,
);

void main() {
  group('gesamtFahrzeit', () {
    test('leere Reihenfolge kostet nichts', () {
      expect(
        gesamtFahrzeit(reihenfolge: const [], fahrzeitZwischen: _fahrzeit),
        0,
      );
    });

    test('ohne Startort zaehlen nur die Fahrten zwischen den Besuchen', () {
      // A->B 10 + B->C 10 + C->D 10
      expect(
        gesamtFahrzeit(
          reihenfolge: const ['A', 'B', 'C', 'D'],
          fahrzeitZwischen: _fahrzeit,
        ),
        30,
      );
    });

    test('mit Anfahrt und Heimweg zaehlt die ganze Schlaufe', () {
      // Anfahrt B 20 + B->C 10 + Heimweg C 30
      expect(
        gesamtFahrzeit(
          reihenfolge: const ['B', 'C'],
          fahrzeitZwischen: _fahrzeit,
          anfahrtVomStart: _anfahrt,
          heimwegZumStart: _heimweg,
        ),
        60,
      );
    });

    test('einzelner Block: nur Anfahrt und Heimweg', () {
      expect(
        gesamtFahrzeit(
          reihenfolge: const ['C'],
          fahrzeitZwischen: _fahrzeit,
          anfahrtVomStart: _anfahrt,
          heimwegZumStart: _heimweg,
        ),
        60,
      );
    });
  });

  group('optimiereReihenfolge — Randfaelle', () {
    test('leere Liste bleibt leer', () {
      expect(
        optimiereReihenfolge(blockIds: const [], fahrzeitZwischen: _fahrzeit),
        isEmpty,
      );
    });

    test('ein Block bleibt unveraendert', () {
      expect(
        optimiereReihenfolge(
          blockIds: const ['C'],
          fahrzeitZwischen: _fahrzeit,
          anfahrtVomStart: _anfahrt,
          heimwegZumStart: _heimweg,
        ),
        ['C'],
      );
    });

    test('zwei Bloecke ohne Startort: gleichwertig, Eingabe bleibt stehen', () {
      // B->A und A->B kosten beide 10 — ohne Gewinn wird nicht umsortiert.
      expect(
        optimiereReihenfolge(
          blockIds: const ['B', 'A'],
          fahrzeitZwischen: _fahrzeit,
        ),
        ['B', 'A'],
      );
    });

    test(
      'zwei Bloecke mit Startort: die teurere Anfahrt wandert nach hinten',
      () {
        expect(
          optimiereReihenfolge(
            blockIds: const ['D', 'A'],
            fahrzeitZwischen: _fahrzeit,
            anfahrtVomStart: _anfahrt,
          ),
          ['A', 'D'],
        );
      },
    );

    test('die uebergebene Liste wird nicht veraendert', () {
      final eingabe = ['A', 'C', 'B', 'D'];
      optimiereReihenfolge(
        blockIds: eingabe,
        fahrzeitZwischen: _fahrzeit,
        anfahrtVomStart: _anfahrt,
        heimwegZumStart: _heimweg,
      );
      expect(eingabe, ['A', 'C', 'B', 'D']);
    });
  });

  group('optimiereReihenfolge — Optimierung', () {
    test('schlechte Reihenfolge wird messbar besser', () {
      const eingabe = ['A', 'C', 'B', 'D'];
      final ergebnis = optimiereReihenfolge(
        blockIds: eingabe,
        fahrzeitZwischen: _fahrzeit,
        anfahrtVomStart: _anfahrt,
        heimwegZumStart: _heimweg,
      );

      expect(ergebnis, ['A', 'B', 'C', 'D']);
      // 10+20+10+20+40 = 100 vorher, 10+10+10+10+40 = 80 nachher.
      expect(_kosten(eingabe, anfahrt: _anfahrt, heimweg: _heimweg), 100);
      expect(_kosten(ergebnis, anfahrt: _anfahrt, heimweg: _heimweg), 80);
    });

    test('ohne Startort bleibt der erste Block der Anker', () {
      final ergebnis = optimiereReihenfolge(
        blockIds: const ['A', 'C', 'B', 'D'],
        fahrzeitZwischen: _fahrzeit,
      );

      expect(ergebnis, ['A', 'B', 'C', 'D']);
      expect(_kosten(ergebnis), 30);
    });

    test('asymmetrische Matrix: Fahrtrichtung wird beruecksichtigt', () {
      const eingabe = ['Z', 'Y', 'X'];
      final ergebnis = optimiereReihenfolge(
        blockIds: eingabe,
        fahrzeitZwischen: _fahrzeitEinbahn,
      );

      expect(ergebnis, ['X', 'Y', 'Z']);
      expect(_kosten(eingabe, fahrzeit: _fahrzeitEinbahn), 200);
      expect(_kosten(ergebnis, fahrzeit: _fahrzeitEinbahn), 20);
    });
  });

  group('optimiereReihenfolge — fixierte Bloecke', () {
    test('ein fixierter Block behaelt seinen Index', () {
      const eingabe = ['A', 'C', 'B', 'D'];
      final ergebnis = optimiereReihenfolge(
        blockIds: eingabe,
        fahrzeitZwischen: _fahrzeit,
        anfahrtVomStart: _anfahrt,
        heimwegZumStart: _heimweg,
        fixiert: const {'C'},
      );

      expect(ergebnis[1], 'C', reason: 'Termin-Anker darf nicht wandern');
      expect(ergebnis.toSet(), eingabe.toSet());
      // Bestmoeglich mit C auf Index 1: A, C, D, B = 10+20+10+20+20 = 80.
      expect(_kosten(ergebnis, anfahrt: _anfahrt, heimweg: _heimweg), 80);
    });

    test('mehrere fixierte Bloecke behalten ihre Indizes', () {
      const eingabe = ['D', 'B', 'A', 'C'];
      final ergebnis = optimiereReihenfolge(
        blockIds: eingabe,
        fahrzeitZwischen: _fahrzeit,
        anfahrtVomStart: _anfahrt,
        heimwegZumStart: _heimweg,
        fixiert: const {'B', 'C'},
      );

      expect(ergebnis[1], 'B');
      expect(ergebnis[3], 'C');
      expect(ergebnis.toSet(), eingabe.toSet());
      expect(
        _kosten(ergebnis, anfahrt: _anfahrt, heimweg: _heimweg),
        lessThanOrEqualTo(
          _kosten(eingabe, anfahrt: _anfahrt, heimweg: _heimweg),
        ),
      );
    });

    test('sind alle Bloecke fixiert, bleibt die Reihenfolge unveraendert', () {
      const eingabe = ['D', 'B', 'A', 'C'];
      expect(
        optimiereReihenfolge(
          blockIds: eingabe,
          fahrzeitZwischen: _fahrzeit,
          anfahrtVomStart: _anfahrt,
          heimwegZumStart: _heimweg,
          fixiert: const {'A', 'B', 'C', 'D'},
        ),
        eingabe,
      );
    });
  });

  group('optimiereReihenfolge — Grossfall und Determinismus', () {
    const gross = [
      'B07',
      'B02',
      'B10',
      'B04',
      'B12',
      'B06',
      'B01',
      'B09',
      'B03',
      'B11',
      'B05',
      'B08',
    ];

    test('12 Bloecke: laeuft durch und wird nicht schlechter', () {
      final ergebnis = optimiereReihenfolge(
        blockIds: gross,
        fahrzeitZwischen: _fahrzeitGross,
        anfahrtVomStart: _anfahrtGross,
        heimwegZumStart: _anfahrtGross,
      );

      expect(ergebnis, hasLength(12));
      expect(ergebnis.toSet(), gross.toSet());

      final vorher = _kosten(
        gross,
        fahrzeit: _fahrzeitGross,
        anfahrt: _anfahrtGross,
        heimweg: _anfahrtGross,
      );
      final nachher = _kosten(
        ergebnis,
        fahrzeit: _fahrzeitGross,
        anfahrt: _anfahrtGross,
        heimweg: _anfahrtGross,
      );
      expect(nachher, lessThanOrEqualTo(vorher));
      // Auf der Linie ist die Schlaufe «hin und zurueck» optimal:
      // 2 x 31 km x 3 min = 186 min.
      expect(nachher, 186);
    });

    test('zweimal aufgerufen liefert dasselbe Ergebnis', () {
      List<String> lauf() => optimiereReihenfolge(
        blockIds: gross,
        fahrzeitZwischen: _fahrzeitGross,
        anfahrtVomStart: _anfahrtGross,
        heimwegZumStart: _anfahrtGross,
        fixiert: const {'B10'},
      );

      expect(lauf(), lauf());
    });

    test('Determinismus auch ohne Startort und ohne Fixierung', () {
      List<String> lauf() => optimiereReihenfolge(
        blockIds: gross,
        fahrzeitZwischen: _fahrzeitGross,
      );

      final a = lauf();
      expect(lauf(), a);
      expect(a.toSet(), gross.toSet());
    });
  });
}
