import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tagesplan_verschieben.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag _e(
  String id, {
  String name = 'Betrieb',
  List<String> ruhetage = const [],
  TourEintragTyp typ = TourEintragTyp.reinigung,
}) => TourEintrag(
  typ: typ,
  id: id,
  betriebName: name,
  beschreibung: '',
  ruhetage: ruhetage,
);

void main() {
  // Di 29.09.2026
  final dienstag = DateTime(2026, 9, 29);

  group('kurzTag', () {
    test('Wochentag-Kürzel und zweistelliger Monat', () {
      expect(kurzTag(dienstag), 'Di 29.09.');
      expect(kurzTag(DateTime(2026, 10, 4)), 'So 4.10.');
      expect(kurzTag(DateTime(2026, 9, 28)), 'Mo 28.09.');
    });
  });

  group('verschiebbareEintraege', () {
    test('lässt erledigte und hist_-Einträge weg, Reihenfolge bleibt', () {
      final plan = [_e('a'), _e('hist_x'), _e('s_1'), _e('b'), _e('m_2')];
      final ergebnis = verschiebbareEintraege(plan, {'b', 'm_2'});
      expect(ergebnis.map((e) => e.id), ['a', 's_1']);
    });

    test('leerer Plan → leer', () {
      expect(verschiebbareEintraege(const [], const {}), isEmpty);
    });
  });

  group('planNachAnhaengen', () {
    test('bestehende zuerst, neue ans Ende', () {
      final ergebnis = planNachAnhaengen([_e('x'), _e('y')], [_e('a'), _e('b')]);
      expect(ergebnis.map((e) => e.id), ['x', 'y', 'a', 'b']);
    });

    test('doppelte id: der bestehende Eintrag gewinnt', () {
      final ziel = [_e('x', name: 'Ziel')];
      final ergebnis = planNachAnhaengen(ziel, [_e('x', name: 'Neu'), _e('a')]);
      expect(ergebnis.map((e) => e.id), ['x', 'a']);
      expect(ergebnis.first.betriebName, 'Ziel');
    });

    test('Doppel innerhalb der neuen Liste nur einmal', () {
      final ergebnis = planNachAnhaengen(const [], [_e('a'), _e('a')]);
      expect(ergebnis.map((e) => e.id), ['a']);
    });
  });

  group('ruhetagBetriebe', () {
    test('nur Betriebe mit Ruhetag am Zieltag, ohne Doppel, Planfolge', () {
      final eintraege = [
        _e('1', name: 'Rössli', ruhetage: ['Di']),
        _e('2', name: 'Krone', ruhetage: ['Mo']),
        _e('3', name: 'Pöstli', ruhetage: ['Dienstag']),
        _e('4', name: 'Rössli', ruhetage: ['Di']),
      ];
      expect(ruhetagBetriebe(eintraege, dienstag), ['Rössli', 'Pöstli']);
    });
  });

  group('verschiebenRueckfrageText', () {
    test('nur die Grundfrage', () {
      expect(
        verschiebenRueckfrageText(
          anzahl: 5,
          ziel: dienstag,
          schonDort: 0,
          ruhetag: const [],
          erledigt: 0,
        ),
        '5 Stopps auf Di 29.09. verschieben?',
      );
    });

    test('alle Zusatzzeilen', () {
      expect(
        verschiebenRueckfrageText(
          anzahl: 1,
          ziel: dienstag,
          schonDort: 3,
          ruhetag: const ['Rössli', 'Pöstli'],
          erledigt: 2,
        ),
        '1 Stopp auf Di 29.09. verschieben?\n'
        'Dort stehen schon 3 Stopps.\n'
        'Ruhetag am Zieltag: Rössli, Pöstli\n'
        '2 erledigte Stopps bleiben hier.',
      );
    });

    test('Einzahl in den Zusatzzeilen', () {
      expect(
        verschiebenRueckfrageText(
          anzahl: 2,
          ziel: dienstag,
          schonDort: 1,
          ruhetag: const [],
          erledigt: 1,
        ),
        '2 Stopps auf Di 29.09. verschieben?\n'
        'Dort steht schon 1 Stopp.\n'
        '1 erledigter Stopp bleibt hier.',
      );
    });
  });

  group('verschobenText', () {
    test('Mehrzahl und Einzahl', () {
      expect(verschobenText(5, dienstag), '5 Stopps auf Di 29.09. verschoben');
      expect(verschobenText(1, dienstag), '1 Stopp auf Di 29.09. verschoben');
    });
  });
}
