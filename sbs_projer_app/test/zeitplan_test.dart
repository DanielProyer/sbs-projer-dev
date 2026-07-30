import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';

PlanBlock b(String id, int dauer, {String? anker}) =>
    PlanBlock(id: id, dauerMinuten: dauer, ankerZeit: anker);

PlanBlock ist(String id, int dauer, {required int von, required int bis}) =>
    PlanBlock(id: id, dauerMinuten: dauer, istStartMin: von, istEndMin: bis);

void main() {
  group('berechneZeitplanMitIst (Live-Tagesplan, 30.07.2026)', () {
    test('erledigt mit Ist-Zeiten, frei bis jetzt, Rest ab jetzt', () {
      // Beginn 06:00, Besuch a wirklich 06:40-07:10, jetzt 07:30.
      final s = berechneZeitplanMitIst(
        bloecke: [ist('a', 30, von: 400, bis: 430), b('c', 60)],
        jetztMin: 450,
        arbeitsbeginn: '06:00',
        anfahrtMinuten: 20,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 10,
      );
      expect(s.map((x) => x.art).toList(), [
        SegmentArt.anfahrt, // gemessen 06:00-06:40
        SegmentArt.besuch, // ist 06:40-07:10
        SegmentArt.frei, // 07:10-07:30
        SegmentArt.fahrt, // geplant ab 07:30
        SegmentArt.besuch,
      ]);
      expect(s[0].ist, isTrue);
      expect(s[0].startMin, 360);
      expect(s[0].endMin, 400);
      expect(s[1].ist, isTrue);
      expect(s[2].startMin, 430);
      expect(s[2].endMin, 450);
      expect(s[3].ist, isFalse);
      expect(s[3].startMin, 450); // Rest startet bei jetzt
      expect(s[4].startMin, 460);
    });

    test('Vergangener Tag (jetztMin 0): kein frei, Achse ab erstem Ist', () {
      // Nutzung fuer vergangene Tage (31.07.2026): arbeitsbeginn = erster
      // Ist-Start (kein erfasster Beginn), jetztMin 0 -> kein frei-Segment,
      // offene Eintraege folgen direkt auf das letzte gemessene Ereignis.
      final s = berechneZeitplanMitIst(
        bloecke: [
          ist('a', 30, von: 400, bis: 430),
          ist('b', 45, von: 445, bis: 490),
          b('offen', 60),
        ],
        jetztMin: 0,
        arbeitsbeginn: '06:40', // = erster Ist-Start 400
        anfahrtMinuten: 20,
        heimwegMinuten: 15,
        fahrzeitZwischen: (v, n) => 10,
      );
      expect(s.map((x) => x.art).toList(), [
        SegmentArt.besuch, // ist a 06:40-07:10 — KEINE Fake-Anfahrt davor
        SegmentArt.fahrt, // gemessen 07:10-07:25
        SegmentArt.besuch, // ist b 07:25-08:10
        SegmentArt.fahrt, // geplant ab letztem Ist-Ende
        SegmentArt.besuch, // offen
        SegmentArt.heimweg,
      ]);
      expect(s.any((x) => x.art == SegmentArt.frei), isFalse);
      expect(s[0].startMin, 400);
      expect(s[3].ist, isFalse);
      expect(s[3].startMin, 490); // direkt nach Ist-Ende, nicht ab jetzt
      expect(s[4].startMin, 500);
    });

    test('Ist-Reihenfolge schlaegt Planreihenfolge', () {
      final s = berechneZeitplanMitIst(
        bloecke: [
          ist('spaet', 30, von: 500, bis: 530),
          ist('frueh', 30, von: 400, bis: 430),
        ],
        jetztMin: 531,
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      final besuche = s
          .where((x) => x.art == SegmentArt.besuch)
          .map((x) => x.blockId);
      expect(besuche.toList(), ['frueh', 'spaet']);
      // Gemessene Uebergangszeit 430-500 als Ist-Fahrt.
      final fahrt = s.firstWhere((x) => x.art == SegmentArt.fahrt);
      expect(fahrt.ist, isTrue);
      expect(fahrt.minuten, 70);
    });

    test('ohne Ist rutscht der Plan mit der Uhr', () {
      final s = berechneZeitplanMitIst(
        bloecke: [b('a', 30)],
        jetztMin: 9 * 60, // 09:00, Beginn waere 06:00
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.single.startMin, 9 * 60);
    });

    test('jetzt vor Arbeitsbeginn: Plan startet am Arbeitsbeginn', () {
      final s = berechneZeitplanMitIst(
        bloecke: [b('a', 30)],
        jetztMin: 5 * 60, // 05:00
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.single.startMin, 6 * 60);
    });

    test('kein frei-Segment unter 3 Minuten', () {
      final s = berechneZeitplanMitIst(
        bloecke: [ist('a', 30, von: 400, bis: 430)],
        jetztMin: 432,
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.any((x) => x.art == SegmentArt.frei), isFalse);
    });

    test('Anker im Rest erzeugt Wartezeit ab jetzt', () {
      final s = berechneZeitplanMitIst(
        bloecke: [
          ist('a', 30, von: 400, bis: 430),
          b('c', 30, anker: '09:00'),
        ],
        jetztMin: 450,
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 10,
      );
      final warte = s.firstWhere((x) => x.art == SegmentArt.wartezeit);
      expect(warte.startMin, 460); // nach Fahrt ab jetzt (450+10)
      expect(warte.endMin, 9 * 60);
    });

    test('alles erledigt: frei + Heimweg', () {
      final s = berechneZeitplanMitIst(
        bloecke: [ist('a', 30, von: 400, bis: 430)],
        jetztMin: 460,
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: 20,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.map((x) => x.art).toList(), [
        SegmentArt.besuch,
        SegmentArt.frei,
        SegmentArt.heimweg,
      ]);
      expect(s.last.startMin, 460);
    });

    test('leerer Plan bleibt leer', () {
      expect(
        berechneZeitplanMitIst(
          bloecke: [],
          jetztMin: 500,
          arbeitsbeginn: '06:00',
          anfahrtMinuten: 10,
          heimwegMinuten: 10,
          fahrzeitZwischen: (v, n) => 0,
        ),
        isEmpty,
      );
    });
  });

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
    test(
      '0-Minuten-Fahrt zwischen zwei Besuchen erzeugt kein Fahrt-Segment',
      () {
        final s = berechneZeitplan(
          bloecke: [b('a', 30), b('c', 30)],
          arbeitsbeginn: '06:00',
          anfahrtMinuten: null,
          heimwegMinuten: null,
          fahrzeitZwischen: (v, n) => 0,
        );
        expect(s.any((x) => x.art == SegmentArt.fahrt), isFalse);
        expect(s.map((x) => x.art).toList(), [
          SegmentArt.besuch,
          SegmentArt.besuch,
        ]);
      },
    );
    test('korrupter Anker (kein HH:mm) wird ignoriert — keine Wartezeit', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30, anker: 'abc')],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.any((x) => x.art == SegmentArt.wartezeit), isFalse);
      expect(s.first.art, SegmentArt.besuch);
      expect(s.first.startMin, 6 * 60);
    });
    test('kaputter arbeitsbeginn faellt auf 06:00 zurueck', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30)],
        arbeitsbeginn: 'kaputt',
        anfahrtMinuten: null,
        heimwegMinuten: null,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.first.startMin, kZeitleisteStartMin);
      expect(s.first.startMin, 6 * 60);
    });
  });
}
