import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Geladener Betrieb ohne Ferien — seit 27.09.2026 ist `ferienPerioden`
/// die einzige Quelle, `null` hiesse «nicht geladen».
BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..ferienPerioden = const [];

void main() {
  group('ferienSlots', () {
    test('geladen ohne Ferien: keine Slots', () {
      expect(ferienSlots(_betrieb()), isEmpty);
    });

    test('liefert alle Perioden in Reihenfolge', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 1, 1), bis: DateTime(2026, 1, 10)),
          (von: DateTime(2026, 4, 1), bis: DateTime(2026, 4, 5)),
          (von: DateTime(2026, 5, 20), bis: DateTime(2026, 5, 31)),
        ];
      final slots = ferienSlots(b);
      expect(slots.length, 3);
      expect(slots[0].start, DateTime(2026, 1, 1));
      expect(slots[1].start, DateTime(2026, 4, 1));
      expect(slots[2].ende, DateTime(2026, 5, 31));
    });
  });

  group('ferienStarts / ferienEnden', () {
    test('liefern Werte aus ferienPerioden', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
          (von: DateTime(2026, 11, 1), bis: DateTime(2026, 11, 5)),
        ];
      expect(ferienStarts(b), [DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
      expect(ferienEnden(b), [DateTime(2026, 10, 10), DateTime(2026, 11, 5)]);
    });
  });

  group('istInFerien', () {
    test('findet die Periode', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 10, 5)), isTrue);
    });

    test('Randtage inklusive', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 10, 1)), isTrue);
      expect(istInFerien(b, DateTime(2026, 10, 10)), isTrue);
    });

    test('Tag ausserhalb ergibt false', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 9, 30)), isFalse);
      expect(istInFerien(b, DateTime(2026, 10, 11)), isFalse);
    });

    test('mehrere Perioden werden alle geprueft', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 1, 1), bis: DateTime(2026, 1, 5)),
          (von: DateTime(2026, 6, 1), bis: DateTime(2026, 6, 5)),
          (von: DateTime(2026, 12, 20), bis: DateTime(2026, 12, 31)),
        ];
      expect(istInFerien(b, DateTime(2026, 1, 3)), isTrue);
      expect(istInFerien(b, DateTime(2026, 6, 3)), isTrue);
      expect(istInFerien(b, DateTime(2026, 12, 25)), isTrue);
      expect(istInFerien(b, DateTime(2026, 7, 1)), isFalse);
    });
  });

  // 27.09.2026: Die Tabelle ist vollstaendig, die Altspalten sind
  // eingefroren und werden entfernt. Der Rueckfall ist abgeschaltet — aber
  // laut, damit ein vergessener Ladepfad sofort auffaellt.
  group('Altspalten ohne Wirkung / Rueckfall abgeschaltet', () {
    test('geladene Perioden: Altspalten werden ignoriert', () {
      // Der Zombie-Fall: Daniel loescht eine falsch erfasste Periode — sie
      // darf nicht ueber den Altbestand zurueckkommen.
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 10)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(istInFerien(b, DateTime(2026, 7, 15)), isFalse);
      expect(ferienStarts(b), isEmpty);
    });

    test('nicht geladen: kein Rueckfall, assert meldet den Fehler, '
        'Zaehler zaehlt', () {
      final b = BetriebLocal()
        ..userId = 'test'
        ..name = 'Ohne Perioden'
        ..ferienStart = DateTime(2026, 7, 10)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(b.ferienPerioden, isNull);
      final vorher = ferienRueckfallZaehler;
      // Im Debug-Modus (Tests) bricht das assert ab; im Release liefert
      // ferienSlots [] — die Altspalten werden in keinem Fall gelesen.
      expect(() => ferienSlots(b), throwsA(isA<AssertionError>()));
      expect(() => istInFerien(b, DateTime(2026, 7, 15)),
          throwsA(isA<AssertionError>()));
      expect(ferienRueckfallZaehler, vorher + 2);
    });

    test('keineBetriebsferien: auch ungeladen kein Fehlalarm', () {
      final b = BetriebLocal()
        ..userId = 'test'
        ..name = 'Keine Ferien'
        ..keineBetriebsferien = true;
      expect(wirksameFerienSlots(b), isEmpty);
      expect(istInFerien(b, DateTime(2026, 7, 15)), isFalse);
    });
  });

  group('mitFerienPerioden', () {
    final FerienPeriodenMap map = {
      'b1': [(von: DateTime(2026, 7, 1), bis: DateTime(2026, 7, 14))],
    };

    test('haengt die Perioden des Betriebs an', () {
      final b = mitFerienPerioden(_betrieb()..serverId = 'b1', map);
      expect(istInFerien(b, DateTime(2026, 7, 5)), isTrue);
    });

    test('Betrieb ohne Eintrag: leere Liste statt null', () {
      final b = BetriebLocal()
        ..name = 'X'
        ..serverId = 'b2';
      mitFerienPerioden(b, map);
      expect(b.ferienPerioden, isNotNull);
      expect(b.ferienPerioden, isEmpty);
    });

    test('Betrieb ohne serverId: leere Liste statt null', () {
      final b = BetriebLocal()..name = 'Neu';
      mitFerienPerioden(b, map);
      expect(b.ferienPerioden, isEmpty);
    });
  });

  group('betriebeMitFerien', () {
    BetriebLocal roh(String id) => BetriebLocal()
      ..name = id
      ..serverId = id;

    test('jede Liste kommt mit Ferien — auch weitere Sendungen', () async {
      final quelle = StreamController<List<BetriebLocal>>();
      final ferien = Completer<FerienPeriodenMap>();
      final listen = <List<BetriebLocal>>[];
      final abo = betriebeMitFerien(quelle.stream, ferien.future)
          .listen(listen.add);
      addTearDown(abo.cancel);

      quelle.add([roh('b1'), roh('b2')]);
      await pumpEventQueue();
      expect(listen, isEmpty, reason: 'ohne Ferien keine Betriebe');

      ferien.complete({
        'b1': [(von: DateTime(2026, 7, 1), bis: DateTime(2026, 7, 14))],
      });
      await pumpEventQueue();
      expect(listen.length, 1);
      expect(listen[0].every((b) => b.ferienPerioden != null), isTrue);
      expect(istInFerien(listen[0][0], DateTime(2026, 7, 5)), isTrue);
      expect(listen[0][1].ferienPerioden, isEmpty);

      // Nativ sendet der Isar-Strom bei jeder Aenderung neu.
      quelle.add([roh('b1')]);
      await pumpEventQueue();
      expect(listen.length, 2);
      expect(istInFerien(listen[1][0], DateTime(2026, 7, 5)), isTrue);
      await quelle.close();
    });

    test('Ferien-Ladefehler: Betriebe kommen trotzdem, Ferien «unbekannt»',
        () async {
      // Entscheid 27.09.2026: Betriebe sind der Kern der App und bleiben
      // sichtbar; laut wird es ueber ferienSlots und die Aufgabe
      // «Ferien nicht geladen» (test/ferien_ladefehler_test.dart).
      final strom = betriebeMitFerien(
        Stream.value([roh('b1')..ferienPerioden = const []]),
        Future<FerienPeriodenMap>.error(StateError('offline')),
      );
      final listen = await strom.toList();
      expect(listen, hasLength(1));
      expect(listen[0].single.name, 'b1');
      // null = unbekannt — NICHT die leere Liste («keine Ferien»).
      expect(listen[0].single.ferienPerioden, isNull);
    });
  });

  // Review R7 (26.09.2026): Der Schalter «Keine Betriebsferien» blendet die
  // Perioden nur aus — alle auswertenden Leser muessen ihn beachten.
  group('wirksameFerienSlots / keineBetriebsferien', () {
    BetriebLocal mitFerien() => _betrieb()
      ..ferienPerioden = [
        (von: DateTime(2026, 10, 11), bis: DateTime(2026, 11, 4)),
      ];

    test('ohne Schalter: Perioden gelten', () {
      final b = mitFerien();
      expect(wirksameFerienSlots(b).length, 1);
      expect(istInFerien(b, DateTime(2026, 10, 20)), isTrue);
      expect(ferienStarts(b), [DateTime(2026, 10, 11)]);
    });

    test('mit Schalter: nichts gilt, Rohbestand bleibt', () {
      final b = mitFerien()..keineBetriebsferien = true;
      expect(wirksameFerienSlots(b), isEmpty);
      expect(istInFerien(b, DateTime(2026, 10, 20)), isFalse);
      expect(ferienStarts(b), isEmpty);
      expect(ferienEnden(b), isEmpty);
      expect(ferienSlots(b).length, 1);
    });
  });
}
