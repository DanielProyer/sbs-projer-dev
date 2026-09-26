import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tagesplan_verschieben.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag _e(
  String id, {
  String name = 'Betrieb',
  String? betriebId,
  List<String> ruhetage = const [],
  TourEintragTyp typ = TourEintragTyp.reinigung,
}) => TourEintrag(
  typ: typ,
  id: id,
  betriebId: betriebId,
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

    test('alle erledigt → leer', () {
      final plan = [_e('a'), _e('s_1'), _e('hist_x')];
      expect(verschiebbareEintraege(plan, {'a', 's_1'}), isEmpty);
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

    test('abgemachte Termine bleiben hier — Einzahl und Mehrzahl', () {
      expect(
        verschiebenRueckfrageText(
          anzahl: 3,
          ziel: dienstag,
          schonDort: 0,
          ruhetag: const [],
          erledigt: 1,
          termine: const ['Löwen'],
        ),
        '3 Stopps auf Di 29.09. verschieben?\n'
        '1 erledigter Stopp bleibt hier.\n'
        '1 abgemachter Termin bleibt hier: Löwen',
      );
      expect(
        verschiebenRueckfrageText(
          anzahl: 3,
          ziel: dienstag,
          schonDort: 0,
          ruhetag: const [],
          erledigt: 0,
          termine: const ['Löwen', 'Rössli'],
        ),
        '3 Stopps auf Di 29.09. verschieben?\n'
        '2 abgemachte Termine bleiben hier: Löwen, Rössli',
      );
    });
  });

  // K1 (Review 26.09.2026): abgeschlossene Einsätze bleiben am Tag.
  group('abgeschlosseneEinsatzEintragIds', () {
    final plan = [
      _e('s_1', typ: TourEintragTyp.stoerung),
      _e('s_2', typ: TourEintragTyp.stoerung),
      _e('s_3', typ: TourEintragTyp.stoerung),
      _e('m_4', typ: TourEintragTyp.montage),
      _e('m_5', typ: TourEintragTyp.montage),
      _e('m_6', typ: TourEintragTyp.heigenie),
      _e('m_7', typ: TourEintragTyp.montage),
      _e('r_8'),
      _e('u_9', typ: TourEintragTyp.stoerung),
    ];
    const status = {
      's_1': 'offen',
      's_2': 'in_bearbeitung',
      's_3': 'erledigt',
      'm_4': 'geplant',
      'm_5': 'abgeschlossen',
      'm_6': 'abgeschlossen',
      // m_7: nicht geladen → gilt als offen
      'r_8': 'abgeschlossen', // Reinigung: kein Einsatz, zählt nicht
      'u_9': 'erledigt', // kein s_/m_-Stopp, zählt nicht
    };

    test('nur Störungen/Montagen/HeiGenie, deren Status nicht offen ist', () {
      expect(
        abgeschlosseneEinsatzEintragIds(plan, status),
        unorderedEquals(['s_3', 'm_5', 'm_6']),
      );
    });

    test('ohne Status-Daten ist nichts abgeschlossen', () {
      expect(abgeschlosseneEinsatzEintragIds(plan, const {}), isEmpty);
    });
  });

  // M4 (Review 26.09.2026): abgemachte Saison-Termine bleiben am Tag.
  group('terminEintragIds', () {
    final plantag = DateTime(2026, 9, 28);
    TerminDto termin(
      String betriebId, {
      String typ = 'eroeffnungsreinigung',
      DateTime? datum,
      String status = 'geplant',
    }) => TerminDto(
      id: 'tm-$betriebId',
      userId: 'u',
      betriebId: betriebId,
      datum: datum ?? DateTime(2026, 9, 28, 9, 30),
      typ: typ,
      titel: 'Termin',
      status: status,
    );

    test('Reinigung desselben Betriebs am Termin-Tag zählt', () {
      final plan = [
        _e('r_1', betriebId: 'b1', name: 'Löwen'),
        _e('r_2', betriebId: 'b2', name: 'Krone'),
      ];
      expect(terminEintragIds(plan, [termin('b1')], plantag), {'r_1'});
    });

    test('Endreinigung zählt, «sonstiges» nicht', () {
      final plan = [_e('r_1', betriebId: 'b1'), _e('r_2', betriebId: 'b2')];
      expect(
        terminEintragIds(plan, [
          termin('b1', typ: 'endreinigung'),
          termin('b2', typ: 'sonstiges'),
        ], plantag),
        {'r_1'},
      );
    });

    test('Termin an einem anderen Tag oder nicht mehr geplant zählt nicht', () {
      final plan = [_e('r_1', betriebId: 'b1'), _e('r_2', betriebId: 'b2')];
      expect(
        terminEintragIds(plan, [
          termin('b1', datum: DateTime(2026, 9, 29)),
          termin('b2', status: 'abgesagt'),
        ], plantag),
        isEmpty,
      );
    });

    test('t_-Einträge zählen immer, Störung am Termin-Betrieb nicht', () {
      final plan = [
        _e('t_tm-9', betriebId: 'b9'),
        _e('s_1', betriebId: 'b1', typ: TourEintragTyp.stoerung),
      ];
      expect(terminEintragIds(plan, [termin('b1')], plantag), {'t_tm-9'});
    });

    test('routeId und serverId desselben Betriebs über den Schlüssel', () {
      // Anlage trägt die routeId, der Termin die serverId.
      final plan = [_e('r_1', betriebId: 'route-7')];
      const lookup = {'route-7': 'route-7', 'srv-7': 'route-7'};
      expect(terminEintragIds(plan, [termin('srv-7')], plantag), isEmpty);
      expect(
        terminEintragIds(
          plan,
          [termin('srv-7')],
          plantag,
          betriebSchluessel: (id) => lookup[id] ?? id,
        ),
        {'r_1'},
      );
    });
  });

  group('tagesplanAufteilen', () {
    test('trennt Mitgehende, Erledigte (inkl. hist_) und Termine', () {
      final plan = [
        _e('a', name: 'Adler'),
        _e('hist_x', name: 'Hist'),
        _e('b', name: 'Bären'),
        _e('r_1', name: 'Löwen'),
        _e('t_2', name: 'Rössli'),
        _e('c', name: 'Krone'),
      ];
      final aufteilung = tagesplanAufteilen(
        plan,
        erledigtIds: {'b'},
        terminIds: {'r_1', 't_2'},
      );
      expect(aufteilung.mit.map((e) => e.id), ['a', 'c']);
      expect(aufteilung.erledigt, 2);
      expect(aufteilung.termine, ['Löwen', 'Rössli']);
    });

    test('erledigter Termin zählt als erledigt, nicht als Termin', () {
      final aufteilung = tagesplanAufteilen(
        [_e('r_1', name: 'Löwen')],
        erledigtIds: {'r_1'},
        terminIds: {'r_1'},
      );
      expect(aufteilung.mit, isEmpty);
      expect(aufteilung.erledigt, 1);
      expect(aufteilung.termine, isEmpty);
    });

    test('alles erledigt → nichts geht mit', () {
      final aufteilung = tagesplanAufteilen(
        [_e('a'), _e('b')],
        erledigtIds: {'a', 'b'},
        terminIds: const {},
      );
      expect(aufteilung.mit, isEmpty);
      expect(aufteilung.erledigt, 2);
    });
  });

  group('verschobenText', () {
    test('Mehrzahl und Einzahl', () {
      expect(verschobenText(5, dienstag), '5 Stopps auf Di 29.09. verschoben');
      expect(verschobenText(1, dienstag), '1 Stopp auf Di 29.09. verschoben');
    });
  });

  group('verschiebenFehlerText', () {
    test('nichts geschrieben → schlichter Fehler', () {
      expect(
        verschiebenFehlerText(
          fehler: 'keine Verbindung',
          ziel: dienstag,
          angehaengt: false,
          einsaetzeUmgeplant: 0,
        ),
        'Verschieben fehlgeschlagen: keine Verbindung',
      );
    });

    test('Einsätze schon umgeplant → sagt, wo sie stehen', () {
      expect(
        verschiebenFehlerText(
          fehler: 'keine Verbindung',
          ziel: dienstag,
          angehaengt: false,
          einsaetzeUmgeplant: 1,
        ),
        'Verschieben fehlgeschlagen: keine Verbindung — der Einsatz steht '
        'aber schon auf Di 29.09.',
      );
      expect(
        verschiebenFehlerText(
          fehler: 'x',
          ziel: dienstag,
          angehaengt: false,
          einsaetzeUmgeplant: 3,
        ),
        'Verschieben fehlgeschlagen: x — die 3 Einsätze stehen aber schon '
        'auf Di 29.09.',
      );
    });

    test('am Zieltag angehängt, hier nicht entfernt → Teilfehler', () {
      expect(
        verschiebenFehlerText(
          fehler: 'Tagesplan vom Mo 28.09. nicht gefunden',
          ziel: dienstag,
          angehaengt: true,
          einsaetzeUmgeplant: 2,
        ),
        'Am Zieltag angehängt, aber hier nicht entfernt — bitte Tag prüfen '
        '(Tagesplan vom Mo 28.09. nicht gefunden)',
      );
    });
  });

  test('TagesplanNichtGefunden nennt den Tag', () {
    expect(
      TagesplanNichtGefunden(DateTime(2026, 9, 28)).toString(),
      'Tagesplan vom Mo 28.09. nicht gefunden',
    );
  });

  test('Ruhetag-Hinweis für einen einzelnen Stopp', () {
    expect(
      ruhetagHinweisText('Rössli', dienstag),
      'Rössli hat am Di Ruhetag. Trotzdem verschieben?',
    );
  });
}
