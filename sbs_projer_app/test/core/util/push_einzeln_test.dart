import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/push_einzeln.dart';

/// Testdatensatz mit Namen — steht für ein beliebiges *Local-Modell.
class _Satz {
  final String name;
  String? serverId;
  bool synced = false;
  _Satz(this.name);
}

void main() {
  group('pushEinzeln', () {
    test('alle erfolgreich: keine Fehler, alle übertragen', () async {
      final saetze = [_Satz('a'), _Satz('b')];

      final r = await pushEinzeln<_Satz>(
        items: saetze,
        push: (s) async => 'server-${s.name}',
        beiErfolg: (s, id) {
          s.serverId = id;
          s.synced = true;
        },
        bezeichnung: (s) => s.name,
      );

      expect(r.fehler, isEmpty);
      expect(r.erfolgreich, hasLength(2));
      expect(saetze[0].serverId, 'server-a');
      expect(saetze[1].synced, isTrue);
    });

    test('ein Teilfehler wird GEMELDET, nicht verschluckt', () async {
      // Der eigentliche Bug: vorher landete so ein Fehler nur in debugPrint,
      // der Sync meldete «erfolgreich» und der Satz fehlte still auf dem Server.
      final saetze = [_Satz('gut'), _Satz('kaputt'), _Satz('auch gut')];

      final r = await pushEinzeln<_Satz>(
        items: saetze,
        push: (s) async {
          if (s.name == 'kaputt') throw Exception('FK verletzt');
          return 'server-${s.name}';
        },
        beiErfolg: (s, id) => s.serverId = id,
        bezeichnung: (s) => s.name,
      );

      expect(r.fehler, hasLength(1));
      expect(r.fehler.single, contains('kaputt'));
      expect(r.fehler.single, contains('FK verletzt'));
    });

    test('ein Teilfehler stoppt die übrigen Sätze nicht', () async {
      final saetze = [_Satz('gut'), _Satz('kaputt'), _Satz('auch gut')];

      final r = await pushEinzeln<_Satz>(
        items: saetze,
        push: (s) async {
          if (s.name == 'kaputt') throw Exception('FK verletzt');
          return 'server-${s.name}';
        },
        beiErfolg: (s, id) => s.serverId = id,
        bezeichnung: (s) => s.name,
      );

      expect(r.erfolgreich, hasLength(2));
      expect(saetze[2].serverId, 'server-auch gut');
      // Der gescheiterte Satz bleibt unmarkiert und wird beim nächsten
      // Lauf erneut versucht.
      expect(saetze[1].serverId, isNull);
    });

    test('alle scheitern: nichts übertragen, jeder Fehler benannt', () async {
      final saetze = [_Satz('x'), _Satz('y')];

      final r = await pushEinzeln<_Satz>(
        items: saetze,
        push: (s) async => throw Exception('offline'),
        beiErfolg: (s, id) => s.serverId = id,
        bezeichnung: (s) => s.name,
      );

      expect(r.erfolgreich, isEmpty);
      expect(r.fehler, hasLength(2));
      expect(r.fehler[0], contains('x'));
      expect(r.fehler[1], contains('y'));
    });

    test('leere Liste: kein Fehler, kein Erfolg', () async {
      final r = await pushEinzeln<_Satz>(
        items: <_Satz>[],
        push: (s) async => 'nie',
        beiErfolg: (s, id) {},
        bezeichnung: (s) => s.name,
      );

      expect(r.erfolgreich, isEmpty);
      expect(r.fehler, isEmpty);
    });
  });

  group('pushFehlerMeldung', () {
    test('fasst Teilfehler je Tabelle zu einer Zeile zusammen', () {
      final meldung = pushFehlerMeldung('event_staende', [
        'Stand A: FK verletzt',
        'Stand B: FK verletzt',
      ]);

      expect(meldung, contains('event_staende'));
      expect(meldung, contains('2'));
    });

    test('ohne Fehler kommt keine Meldung', () {
      expect(pushFehlerMeldung('event_staende', []), isNull);
    });
  });
}
