import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_betrieb.dart';
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';

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
