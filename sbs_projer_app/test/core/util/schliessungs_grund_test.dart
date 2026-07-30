import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..status = 'aktiv';

// 03.08.2026 ist ein Montag.
final _montag = DateTime(2026, 8, 3);
final _dienstag = DateTime(2026, 8, 4);

void main() {
  group('schliessungsGrund (Warnung im Tagesplan, 31.07.2026)', () {
    test('offener Betrieb: kein Grund', () {
      expect(schliessungsGrund(_betrieb(), _montag), isNull);
    });

    test('Ruhetag wird benannt', () {
      final b = _betrieb()..ruhetage = ['Mo'];
      expect(schliessungsGrund(b, _montag), 'Ruhetag');
      expect(schliessungsGrund(b, _dienstag), isNull);
    });

    test('Ruhetag auch in Langform erkannt', () {
      final b = _betrieb()..ruhetage = ['Montag'];
      expect(schliessungsGrund(b, _montag), 'Ruhetag');
    });

    test('Betriebsferien nennen das Enddatum', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 27)
        ..ferienEnde = DateTime(2026, 8, 16);
      expect(schliessungsGrund(b, _montag), 'Betriebsferien bis 16.08.');
    });

    test('Ferien aus Slot 5 werden ebenso gefunden', () {
      final b = _betrieb()
        ..ferien5Start = DateTime(2026, 8, 1)
        ..ferien5Ende = DateTime(2026, 8, 5);
      expect(schliessungsGrund(b, _montag), 'Betriebsferien bis 05.08.');
    });

    test('Zwischensaison: Saisonbetrieb ausserhalb seiner Fenster', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..winterSaisonAktiv = true
        ..winterStartDatum = DateTime(2026, 12, 1)
        ..winterEndeDatum = DateTime(2027, 4, 1);
      expect(schliessungsGrund(b, _montag), 'Zwischensaison');
    });

    test('laufende Saison ist kein Grund', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 6, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(schliessungsGrund(b, _montag), isNull);
    });

    test('inaktiver/geschlossener Betrieb', () {
      expect(
        schliessungsGrund(_betrieb()..status = 'inaktiv', _montag),
        'Betrieb inaktiv',
      );
      expect(
        schliessungsGrund(_betrieb()..status = 'geschlossen', _montag),
        'Betrieb geschlossen',
      );
    });

    test('Ferien schlagen Ruhetag (der dringendere Grund zuerst)', () {
      final b = _betrieb()
        ..ruhetage = ['Mo']
        ..ferienStart = DateTime(2026, 8, 1)
        ..ferienEnde = DateTime(2026, 8, 20);
      expect(schliessungsGrund(b, _montag), 'Betriebsferien bis 20.08.');
    });

    test('deckungsgleich mit istOffenerTag', () {
      final faelle = [
        _betrieb(),
        _betrieb()..ruhetage = ['Mo'],
        _betrieb()..status = 'inaktiv',
        _betrieb()
          ..ferienStart = DateTime(2026, 8, 1)
          ..ferienEnde = DateTime(2026, 8, 9),
        _betrieb()
          ..istSaisonbetrieb = true
          ..winterSaisonAktiv = true
          ..winterStartDatum = DateTime(2026, 12, 1)
          ..winterEndeDatum = DateTime(2027, 4, 1),
      ];
      for (final b in faelle) {
        expect(
          schliessungsGrund(b, _montag) == null,
          istOffenerTag(b, _montag),
          reason: 'Grund und istOffenerTag müssen dasselbe sagen',
        );
      }
    });
  });
}
