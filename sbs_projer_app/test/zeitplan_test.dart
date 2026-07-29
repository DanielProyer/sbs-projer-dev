import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';

PlanBlock b(String id, int dauer, {String? anker}) =>
    PlanBlock(id: id, dauerMinuten: dauer, ankerZeit: anker);

void main() {
  group('berechneZeitplan (Spec 2026-07-29)', () {
    test('Kette: Anfahrt, Besuche, Fahrten, Heimweg', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30), b('c', 60)],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: 20,
        heimwegMinuten: 25,
        fahrzeitZwischen: (von, nach) => 10,
      );
      expect(s.map((x) => x.art).toList(), [
        SegmentArt.anfahrt,
        SegmentArt.besuch,
        SegmentArt.fahrt,
        SegmentArt.besuch,
        SegmentArt.heimweg,
      ]);
      expect(s[0].startMin, 6 * 60); // 06:00 Anfahrt
      expect(s[1].startMin, 6 * 60 + 20); // 06:20 Besuch a
      expect(s[3].startMin, 6 * 60 + 60); // 07:00 Besuch c (06:50 + 10 Fahrt)
      expect(s[4].endMin, 6 * 60 + 120 + 25); // Heimweg-Ende 08:25
    });
    test('Anker erzeugt Wartezeit', () {
      final s = berechneZeitplan(
        bloecke: [
          b('a', 30),
          b('c', 30, anker: '08:00'),
        ],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: 0,
        heimwegMinuten: 0,
        fahrzeitZwischen: (v, n) => 10,
      );
      final warte = s.firstWhere((x) => x.art == SegmentArt.wartezeit);
      expect(warte.startMin, 6 * 60 + 40); // nach Fahrt 06:40
      expect(warte.endMin, 8 * 60); // bis Anker
      expect(s.last.startMin, 8 * 60); // Besuch c ab 08:00
    });
    test('Anker in der Vergangenheit: keine Wartezeit', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 120, anker: '06:30')],
        arbeitsbeginn: '07:00',
        anfahrtMinuten: 0,
        heimwegMinuten: 0,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.any((x) => x.art == SegmentArt.wartezeit), isFalse);
    });
    test('leer: nur nichts', () {
      expect(
        berechneZeitplan(
          bloecke: [],
          arbeitsbeginn: '06:00',
          anfahrtMinuten: 0,
          heimwegMinuten: 0,
          fahrzeitZwischen: (v, n) => 0,
        ),
        isEmpty,
      );
    });
    test('ohne Anfahrt (kein Startort): beginnt mit Besuch', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30)],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.first.art, SegmentArt.besuch);
      expect(s.first.startMin, 6 * 60);
    });
  });
}
