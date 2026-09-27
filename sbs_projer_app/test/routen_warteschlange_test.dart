import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/routen_warteschlange.dart';

/// Globale, serielle Warteschlange für `fahrzeit-route` (OSRM-Demo-Server:
/// höchstens eine Anfrage pro Sekunde). Uhr und Warten sind eingespritzt,
/// damit der Test nicht wirklich wartet.
void main() {
  late DateTime uhr;
  late List<Duration> gewartet;
  late RoutenWarteschlange schlange;

  /// Simulierte Antwortzeit einer Anfrage.
  const antwortzeit = Duration(milliseconds: 300);

  setUp(() {
    uhr = DateTime(2026, 9, 27, 8);
    gewartet = [];
    schlange = RoutenWarteschlange(
      warten: (d) async {
        gewartet.add(d);
        uhr = uhr.add(d);
      },
      jetzt: () => uhr,
    );
  });

  test('Abstand mindestens 1,1 s', () {
    expect(
      kRoutenAbstand,
      greaterThanOrEqualTo(const Duration(milliseconds: 1100)),
    );
  });

  // Nie zwei Anfragen gleichzeitig; ein zweiter Lauf stellt sich hinten an.
  test('seriell, Läufe nacheinander', () async {
    var laufend = 0, hoechstens = 0;
    final reihenfolge = <String>[];
    Future<String> anfrage(String name) async {
      laufend++;
      hoechstens = math.max(hoechstens, laufend);
      reihenfolge.add(name);
      await Future<void>.delayed(Duration.zero);
      uhr = uhr.add(antwortzeit);
      laufend--;
      return name;
    }

    final lauf1 = [
      for (final n in ['a1', 'a2', 'a3']) schlange.einreihen(() => anfrage(n)),
    ];
    final lauf2 = [
      for (final n in ['b1', 'b2']) schlange.einreihen(() => anfrage(n)),
    ];
    expect(await Future.wait([...lauf1, ...lauf2]), [
      'a1',
      'a2',
      'a3',
      'b1',
      'b2',
    ]);
    expect(hoechstens, 1);
    expect(reihenfolge, ['a1', 'a2', 'a3', 'b1', 'b2']);
  });

  test('zwischen zwei Anfragen mindestens kRoutenAbstand Pause', () async {
    final starts = <DateTime>[], enden = <DateTime>[];
    Future<void> anfrage() async {
      starts.add(uhr);
      uhr = uhr.add(antwortzeit);
      enden.add(uhr);
    }

    await Future.wait([
      for (var i = 0; i < 4; i++) schlange.einreihen(anfrage),
    ]);
    expect(starts, hasLength(4));
    for (var i = 1; i < starts.length; i++) {
      expect(
        starts[i].difference(enden[i - 1]),
        greaterThanOrEqualTo(kRoutenAbstand),
      );
    }
    // Die erste Anfrage wartet nicht.
    expect(gewartet, hasLength(3));
  });

  test('nach einer langen Pause keine zusätzliche Wartezeit', () async {
    await schlange.einreihen(() async => uhr = uhr.add(antwortzeit));
    uhr = uhr.add(const Duration(seconds: 5));
    await schlange.einreihen(() async => 1);
    expect(gewartet, isEmpty);
  });

  test('ein Fehler hält die Schlange nicht an', () async {
    final kaputt = schlange.einreihen<int>(
      () async => throw StateError('kaputt'),
    );
    final danach = schlange.einreihen(() async => 42);
    await expectLater(kaputt, throwsStateError);
    expect(await danach, 42);
  });
}
