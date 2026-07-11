import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..status = 'aktiv';

void main() {
  group('istOffenerTag', () {
    test('aktiv, kein Ruhetag, keine Ferien, kein Saisonbetrieb → true', () {
      expect(istOffenerTag(_betrieb(), DateTime(2026, 7, 10)), isTrue);
    });
    test('Ruhetag → false', () {
      final b = _betrieb()..ruhetage = ['Samstag'];
      expect(istOffenerTag(b, DateTime(2026, 7, 11)), isFalse);
    });
    test('in Ferien → false', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 6)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
    test('Saisonbetrieb ausserhalb Saison → false', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 11, 1)), isFalse);
    });
    test('Saisonbetrieb innerhalb Saison → true', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isTrue);
    });
    test('status != aktiv → false', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
  });

  group('naechsterOffenerTag', () {
    test('überspringt Ruhetage vorwärts', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11)),
          DateTime(2026, 7, 13));
    });
    test('überspringt Ferien vorwärts', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 13)
        ..ferienEnde = DateTime(2026, 7, 17);
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 13)),
          DateTime(2026, 7, 18));
    });
    test('rückwärts findet letzten offenen Tag', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11), rueckwaerts: true),
          DateTime(2026, 7, 10));
    });
    test('nie offen → null nach 60 Tagen', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 10)), isNull);
    });
  });

  group('qualifizierteSchliessung', () {
    test('Saisonende → erster geschlossener Tag = Ende+1, istSaisonende', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      final s = qualifizierteSchliessung(b, DateTime(2026, 9, 1));
      expect(s, isNotNull);
      expect(s!.datum, DateTime(2026, 10, 1));
      expect(s.istSaisonende, isTrue);
    });
    test('lange Ferien (≥21 Tage) → Start; kurze werden ignoriert', () {
      final lang = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21);
      final s = qualifizierteSchliessung(lang, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);

      final kurz = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(qualifizierteSchliessung(kurz, DateTime(2026, 6, 1)), isNull);
    });
    test('nächste Schliessung gewinnt (Ferien vor Saisonende)', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21);
      final s = qualifizierteSchliessung(b, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);
    });
  });

  group('oeffnungNach', () {
    test('Saisonstart nach ab', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 5, 1));
    });
    test('Ferienende+1, nimmt die frühere Öffnung', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 10);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 2, 11));
    });
  });
}
