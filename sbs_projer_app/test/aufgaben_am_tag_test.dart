import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_am_tag.dart';
import 'package:sbs_projer_app/presentation/widgets/touren/aufgaben_tag_sektion.dart';

/// Aufgaben im Tourenplan (27.09.2026): eigene Aufgaben mit
/// Fälligkeitsdatum erscheinen am gewählten Tag unter den Saison-Terminen.

Map<String, dynamic> _zeile(
  String id, {
  String typ = 'eigene',
  String? titel,
  String? faellig = '2026-09-28',
  String? erledigt,
}) => {
  'id': id,
  'typ': typ,
  'key': typ == 'eigene' ? null : 'x:$id',
  'titel': titel ?? 'Aufgabe $id',
  'faellig_am': faellig,
  'snooze_bis': null,
  'erledigt_am': erledigt,
};

final _tag = DateTime(2026, 9, 28);

void main() {
  group('aufgabenAmTag', () {
    test('nur eigene Aufgaben mit Fälligkeit genau am Kalendertag', () {
      final liste = aufgabenAmTag([
        _zeile('a'),
        _zeile('vortag', faellig: '2026-09-27'),
        _zeile('folgetag', faellig: '2026-09-29'),
        _zeile('vorjahr', faellig: '2025-09-28'),
        _zeile('ohne', faellig: null),
        _zeile('kaputt', faellig: 'morgen'),
        _zeile('marker', typ: 'marker'),
        _zeile('snooze', typ: 'snooze'),
      ], _tag);
      expect(liste.map((a) => a.id), ['a']);
    });

    test('Uhrzeit am gewählten Tag spielt keine Rolle', () {
      final liste = aufgabenAmTag([_zeile('a')], DateTime(2026, 9, 28, 23, 59));
      expect(liste, hasLength(1));
    });

    test('erledigte bleiben sichtbar — mit Haken, nach den offenen', () {
      final liste = aufgabenAmTag([
        _zeile('e', titel: 'Abgabe', erledigt: '2026-09-28T09:00:00+00:00'),
        _zeile('o2', titel: 'zapfhahn bestellen'),
        _zeile('o1', titel: 'Bank anrufen'),
      ], _tag);
      expect(liste.map((a) => a.titel), [
        'Bank anrufen',
        'zapfhahn bestellen',
        'Abgabe',
      ]);
      expect(liste.map((a) => a.erledigt), [false, false, true]);
    });

    test('leerer oder fehlender Titel wird «?», Zeile ohne Id fällt weg', () {
      final liste = aufgabenAmTag([
        _zeile('a', titel: '   '),
        {..._zeile('b'), 'id': null},
      ], _tag);
      expect(liste, hasLength(1));
      expect(liste.single.titel, '?');
    });

    test('keine Zeilen → leer', () {
      expect(aufgabenAmTag(const [], _tag), isEmpty);
    });
  });

  group('AufgabenTagSektion', () {
    Future<List<int>> zeige(
      WidgetTester tester,
      List<AufgabeAmTag> aufgaben,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AufgabenTagSektion(
              aufgaben: aufgaben,
              onTap: () => taps.add(1),
            ),
          ),
        ),
      );
      return taps;
    }

    const offen = (
      id: 'o',
      titel: 'Bank anrufen',
      erledigt: false,
      betrieb: null,
    );
    const erledigt = (id: 'e', titel: 'Abgabe', erledigt: true, betrieb: null);

    testWidgets('leer → nichts', (tester) async {
      await zeige(tester, const []);
      expect(find.textContaining('Aufgaben'), findsNothing);
    });

    testWidgets('startet zugeklappt, Titel mit Anzahl', (tester) async {
      await zeige(tester, const [offen, erledigt]);
      expect(find.text('Aufgaben (2)'), findsOneWidget);
      expect(find.text('Bank anrufen'), findsNothing);
    });

    testWidgets('aufgeklappt: Titel und Erledigt-Haken als Anzeige', (
      tester,
    ) async {
      await zeige(tester, const [offen, erledigt]);
      await tester.tap(find.text('Aufgaben (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Bank anrufen'), findsOneWidget);
      expect(find.text('Abgabe'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('Tipp auf eine Aufgabe führt zu den Aufgaben', (tester) async {
      final taps = await zeige(tester, const [offen]);
      await tester.tap(find.text('Aufgaben (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank anrufen'));
      expect(taps, hasLength(1));
    });
  });

  test('Tourenplan: Sektion unter den Saison-Terminen, Tipp → /aufgaben, '
      'keine Schreiblogik', () {
    final screen = File(
      'lib/presentation/screens/touren/tourenplanung_screen.dart',
    ).readAsStringSync();
    final saison = screen.indexOf('SaisonTermineSektion(');
    final aufgaben = screen.indexOf('AufgabenTagSektion(');
    expect(saison, greaterThanOrEqualTo(0));
    expect(aufgaben, greaterThan(saison), reason: 'unter den Saison-Terminen');
    final aufruf = screen.substring(
      aufgaben,
      screen.indexOf('Expanded(', aufgaben),
    );
    expect(aufruf, contains("context.push('/aufgaben')"));
    expect(screen, contains('aufgabenAmTag('));
    expect(screen, isNot(contains('AufgabenRepository')));
  });
}
