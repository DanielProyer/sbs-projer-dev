import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_betrieb.dart';
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';

/// Aufgaben mit Betriebsbezug (Migration 212, Entscheid Daniel 27.09.2026).

Map<String, dynamic> _zeile(
  String id, {
  String typ = 'eigene',
  String? betrieb = 'b1',
  String? titel,
  String? faellig,
  String? erledigt,
}) => {
  'id': id,
  'typ': typ,
  'key': typ == 'eigene' ? null : 'x:$id',
  'titel': titel ?? 'Aufgabe $id',
  'faellig_am': faellig,
  'snooze_bis': null,
  'erledigt_am': erledigt,
  'betrieb_id': betrieb,
};

final _jetzt = DateTime.utc(2026, 9, 27, 10);

void main() {
  group('EigeneAufgabe', () {
    test('fromJson liest Betrieb, Datum und Erledigt', () {
      final a = EigeneAufgabe.fromJson(
        _zeile(
          'a',
          faellig: '2026-09-28',
          erledigt: '2026-09-27T08:00:00+00:00',
        ),
      );
      expect(a.id, 'a');
      expect(a.betriebId, 'b1');
      expect(a.faelligAm, DateTime(2026, 9, 28));
      expect(a.erledigt, isTrue);
    });

    test('fromJson: fehlende Spalte betrieb_id (vor Migration 212) → null', () {
      final a = EigeneAufgabe.fromJson({
        'id': 'a',
        'typ': 'eigene',
        'titel': 'Alt',
      });
      expect(a.betriebId, isNull);
      expect(a.faelligAm, isNull);
    });

    test('fromJson: leerer Titel wird «?», leerer Betrieb null', () {
      final a = EigeneAufgabe.fromJson(
        _zeile('a', titel: '  ', betrieb: ''),
      );
      expect(a.titel, '?');
      expect(a.betriebId, isNull);
    });

    test('toJson schreibt Kalendertag und Betrieb — null bleibt drin', () {
      expect(
        EigeneAufgabe(
          titel: 'Hahn mitnehmen',
          faelligAm: DateTime(2026, 10, 1, 23, 30),
          betriebId: 'b1',
        ).toJson(),
        {
          'titel': 'Hahn mitnehmen',
          'faellig_am': '2026-10-01',
          'betrieb_id': 'b1',
        },
      );
      // Beim Bearbeiten heisst null «Betrieb entfernt».
      final ohne = const EigeneAufgabe(titel: 'x').toJson();
      expect(ohne.containsKey('betrieb_id'), isTrue);
      expect(ohne['betrieb_id'], isNull);
      expect(ohne['faellig_am'], isNull);
    });
  });

  group('aufgabenFuerBetrieb', () {
    test('nur eigene Aufgaben dieses Betriebs', () {
      final liste = aufgabenFuerBetrieb([
        _zeile('a'),
        _zeile('fremd', betrieb: 'b2'),
        _zeile('ohne', betrieb: null),
        _zeile('marker', typ: 'marker'),
        _zeile('snooze', typ: 'snooze'),
        {..._zeile('keineId'), 'id': null},
      ], 'b1', _jetzt);
      expect(liste.map((a) => a.id), ['a']);
    });

    test('offene zuerst (nach Fälligkeit, ohne Datum zuletzt), dann '
        'erledigte der letzten 30 Tage, jüngste zuerst', () {
      final liste = aufgabenFuerBetrieb([
        _zeile('e-alt', erledigt: '2026-09-01T09:00:00+00:00'),
        _zeile('o-ohne', titel: 'Zapfhahn'),
        _zeile('e-neu', erledigt: '2026-09-26T09:00:00+00:00'),
        _zeile('o-spaet', faellig: '2026-10-05'),
        _zeile('o-frueh', faellig: '2026-09-20'),
        _zeile('o-ohne2', titel: 'anrufen'),
        _zeile('e-zu-alt', erledigt: '2026-08-20T09:00:00+00:00'),
      ], 'b1', _jetzt);
      expect(liste.map((a) => a.id), [
        'o-frueh',
        'o-spaet',
        'o-ohne2', // «anrufen» vor «Zapfhahn», Gross/Klein egal
        'o-ohne',
        'e-neu',
        'e-alt',
      ]);
    });

    test('keine Zeilen → leer', () {
      expect(aufgabenFuerBetrieb(const [], 'b1', _jetzt), isEmpty);
    });
  });

  group('Aufgabenliste mit Betrieb', () {
    List<AufgabenEintrag> baue(List<Map<String, dynamic>> zeilen) =>
        baueAufgabenListe(
          detektoren: const [],
          aufgabenZeilen: zeilen,
          anstehend: const [],
          saisonVorschlaege: const [],
          saisonTermine: const [],
          aenderungsVorschlaege: 0,
          heute: DateTime(2026, 9, 27),
          betriebAnzeige: (id) => id == 'b1' ? 'Rössli, Ilanz' : null,
        );

    test('Betrieb als Untertitel, «Dorthin» zur Betriebsseite', () {
      final a = baue([_zeile('a', titel: 'Hahn mitnehmen')]).single;
      expect(a.titel, 'Hahn mitnehmen');
      expect(a.untertitel, 'Rössli, Ilanz');
      expect(a.route, '/betriebe/b1');
      expect(a.betriebId, 'b1');
      expect(a.eigeneId, 'a');
    });

    test('ohne Betrieb: Freitext wie bisher — kein Untertitel, keine Route', () {
      final a = baue([_zeile('a', betrieb: null)]).single;
      expect(a.untertitel, isNull);
      expect(a.route, isNull);
      expect(a.betriebId, isNull);
    });

    test('unbekannter Betrieb (nicht geladen): Route ja, Untertitel nein', () {
      final a = baue([_zeile('a', betrieb: 'b9')]).single;
      expect(a.untertitel, isNull);
      expect(a.route, '/betriebe/b9');
    });
  });

  group('AufgabeZeile: eigene Aufgabe mit Betrieb', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
    });

    const eintrag = AufgabenEintrag(
      quelle: AufgabenQuelle.eigene,
      key: 'eigene:a',
      titel: 'Hahn mitnehmen',
      untertitel: 'Rössli, Ilanz',
      route: '/betriebe/b1',
      eigeneId: 'a',
      betriebId: 'b1',
    );

    Future<({List<String> taps})> zeige(
      WidgetTester tester, {
      bool mitBearbeiten = true,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AufgabeZeile(
                  eintrag: eintrag,
                  heute: DateTime(2026, 9, 27),
                  onDorthin: () => taps.add('dorthin'),
                  onSnooze: (_) {},
                  onErledigt: () => taps.add('erledigt'),
                  onEinplanen: () {},
                  onBestaetigen: () {},
                  onBearbeiten: mitBearbeiten
                      ? () => taps.add('bearbeiten')
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
      return (taps: taps);
    }

    testWidgets('Betrieb steht als Untertitel, 360 px ohne Überlauf', (
      tester,
    ) async {
      await zeige(tester);
      expect(find.text('Rössli, Ilanz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Zeile → Bearbeiten, Pfeil → Betriebsseite', (tester) async {
      final r = await zeige(tester);
      await tester.tap(find.text('Hahn mitnehmen'));
      await tester.tap(find.byTooltip('Dorthin'));
      await tester.tap(find.byTooltip('Erledigt'));
      expect(r.taps, ['bearbeiten', 'dorthin', 'erledigt']);
    });

    testWidgets('ohne Bearbeiten-Callback führt die Zeile «Dorthin»', (
      tester,
    ) async {
      final r = await zeige(tester, mitBearbeiten: false);
      await tester.tap(find.text('Hahn mitnehmen'));
      expect(r.taps, ['dorthin']);
    });
  });

  test('aufgabenFuerBetriebProvider liest die eine Tabellen-Abfrage', () async {
    final container = ProviderContainer(
      overrides: [
        aufgabenZeilenProvider.overrideWith(
          (ref) async => [
            _zeile('a'),
            _zeile('b', betrieb: 'b2'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final b1 = await container.read(aufgabenFuerBetriebProvider('b1').future);
    final b2 = await container.read(aufgabenFuerBetriebProvider('b2').future);
    expect(b1.map((a) => a.id), ['a']);
    expect(b2.map((a) => a.id), ['b']);
  });

  test('Migration 212: Spalte mit on delete set null und Index', () {
    final sql = File(
      '../Datenbank/migrations/212_aufgaben_betrieb.sql',
    ).readAsStringSync().toLowerCase();
    expect(
      sql,
      contains(
        'add column betrieb_id uuid references public.betriebe(id) '
        'on delete set null',
      ),
    );
    expect(sql, contains('(user_id, betrieb_id)'));
  });
}
