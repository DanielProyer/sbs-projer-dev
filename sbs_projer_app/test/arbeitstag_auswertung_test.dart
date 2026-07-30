import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart';

Arbeitstagsdaten tag(
  int day, {
  String? beginn,
  String? ende,
  int? kmStart,
  int? kmEnde,
  int besuche = 0,
}) => (
  datum: DateTime(2026, 7, day),
  beginn: beginn,
  ende: ende,
  kmStart: kmStart,
  kmEnde: kmEnde,
  besuche: besuche,
);

void main() {
  group('tagesKm', () {
    test('Differenz der beiden Zählerstände', () {
      expect(tagesKm(kmStart: 77912, kmEnde: 78290), 378);
    });
    test('gleicher Stand = 0 km (gültiger Tag ohne Fahrt)', () {
      expect(tagesKm(kmStart: 1000, kmEnde: 1000), 0);
    });
    test('unvollständig → null', () {
      expect(tagesKm(kmStart: 1000, kmEnde: null), isNull);
      expect(tagesKm(kmStart: null, kmEnde: 1000), isNull);
      expect(tagesKm(), isNull);
    });
    test('Abendstand kleiner als Morgenstand → null (Tippfehler)', () {
      expect(tagesKm(kmStart: 1000, kmEnde: 900), isNull);
    });
  });

  group('arbeitsMinuten', () {
    test('normaler Tag', () {
      expect(arbeitsMinuten(beginn: '05:20', ende: '18:23'), 783);
    });
    test('Beginn = Ende → 0', () {
      expect(arbeitsMinuten(beginn: '08:00', ende: '08:00'), 0);
    });
    test('unvollständig → null', () {
      expect(arbeitsMinuten(beginn: '05:20'), isNull);
      expect(arbeitsMinuten(ende: '18:23'), isNull);
      expect(arbeitsMinuten(), isNull);
    });
    test('über Mitternacht wird nicht gerechnet → null', () {
      expect(arbeitsMinuten(beginn: '22:00', ende: '02:00'), isNull);
    });
    test('kaputter Wert → null statt Absturz', () {
      expect(arbeitsMinuten(beginn: 'x', ende: '18:00'), isNull);
      expect(arbeitsMinuten(beginn: '25:00', ende: '26:00'), isNull);
    });
  });

  group('hatErfassung', () {
    test('leerer Tag zählt nicht', () {
      expect(hatErfassung(tag(1)), isFalse);
    });
    test('halbe Erfassung zählt (nur Feierabend)', () {
      expect(hatErfassung(tag(1, ende: '18:00')), isTrue);
    });
    test('nur Besuche zählen auch', () {
      expect(hatErfassung(tag(1, besuche: 3)), isTrue);
    });
  });

  group('berechneKennzahlen', () {
    test('vollständige Tage: Summen und Schnitte', () {
      final k = berechneKennzahlen([
        tag(
          1,
          beginn: '06:00',
          ende: '18:00',
          kmStart: 100,
          kmEnde: 300,
          besuche: 4,
        ),
        tag(
          2,
          beginn: '07:00',
          ende: '17:00',
          kmStart: 300,
          kmEnde: 400,
          besuche: 6,
        ),
      ]);
      expect(k.anzahlTage, 2);
      expect(k.totalKm, 300);
      expect(k.schnittKm, 150);
      expect(k.totalMinuten, 720 + 600);
      expect(k.schnittMinuten, 660);
      expect(k.anzahlBesuche, 10);
      expect(k.schnittBesuche, 5);
      expect(k.kmJeBesuch, 30);
      expect(k.minutenJeBesuch, 132);
    });

    test('nur-km-Tag verwässert die Zeitstatistik nicht', () {
      final k = berechneKennzahlen([
        tag(1, beginn: '06:00', ende: '18:00', besuche: 2),
        tag(2, kmStart: 100, kmEnde: 200, besuche: 3),
      ]);
      expect(k.anzahlTage, 2);
      expect(k.tageMitZeit, 1);
      expect(k.schnittMinuten, 720); // nicht 360
      expect(k.tageMitKm, 1);
      expect(k.schnittKm, 100);
      // Verhältnisse jeweils nur über die vollständigen Tage
      expect(k.minutenJeBesuch, 360); // 720 / 2 Besuche des Zeit-Tages
      expect(k.kmJeBesuch, closeTo(33.33, 0.01)); // 100 / 3 Besuche
    });

    test('leere Tage fallen raus, Nenner bleibt sauber', () {
      final k = berechneKennzahlen([
        tag(1),
        tag(2, beginn: '08:00', ende: '12:00', besuche: 1),
      ]);
      expect(k.anzahlTage, 1);
      expect(k.schnittBesuche, 1);
    });

    test('ohne Grundlage null statt 0', () {
      final k = berechneKennzahlen([]);
      expect(k.anzahlTage, 0);
      expect(k.schnittKm, isNull);
      expect(k.schnittMinuten, isNull);
      expect(k.schnittBesuche, isNull);
      expect(k.kmJeBesuch, isNull);
      expect(k.minutenJeBesuch, isNull);
    });

    test('km-Tag ohne Besuche bläht «km je Besuch» nicht auf', () {
      final k = berechneKennzahlen([
        tag(1, kmStart: 0, kmEnde: 100, besuche: 5),
        tag(2, kmStart: 100, kmEnde: 400), // Fahrtag ohne Besuch
      ]);
      expect(k.totalKm, 400);
      expect(k.kmJeBesuch, 80); // 400 / 5, kein Teilen durch 0
    });

    test('Tippfehler beim km-Stand fliegt aus der km-Statistik', () {
      final k = berechneKennzahlen([
        tag(1, kmStart: 500, kmEnde: 100, besuche: 2),
        tag(2, kmStart: 500, kmEnde: 600, besuche: 2),
      ]);
      expect(k.anzahlTage, 2);
      expect(k.tageMitKm, 1);
      expect(k.totalKm, 100);
    });
  });

  group('besucheJeTag', () {
    test('mehrere Anlagen desselben Betriebs = ein Besuch', () {
      final map = besucheJeTag([
        (datum: DateTime(2026, 7, 1, 8), betriebId: 'a'),
        (datum: DateTime(2026, 7, 1, 9), betriebId: 'a'),
        (datum: DateTime(2026, 7, 1, 14), betriebId: 'b'),
        (datum: DateTime(2026, 7, 2, 8), betriebId: 'a'),
      ]);
      expect(map[DateTime(2026, 7, 1)], 2);
      expect(map[DateTime(2026, 7, 2)], 1);
    });
    test('Uhrzeit stört die Tages-Zuordnung nicht', () {
      final map = besucheJeTag([
        (datum: DateTime(2026, 7, 1, 23, 59), betriebId: 'a'),
      ]);
      expect(map.keys.single, DateTime(2026, 7, 1));
    });
  });

  group('Anzeige-Helfer', () {
    test('dauerText', () {
      expect(dauerText(783), '13h 03');
      expect(dauerText(60), '1h 00');
      expect(dauerText(0), '0h 00');
    });
    test('schnittText mit Komma, null als Strich', () {
      expect(schnittText(12.34), '12,3');
      expect(schnittText(null), '–');
      expect(schnittText(150, nachkomma: 0), '150');
    });
  });
}
