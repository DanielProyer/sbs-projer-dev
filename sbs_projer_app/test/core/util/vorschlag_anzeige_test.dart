import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/vorschlag_anzeige.dart';

void main() {
  group('vorschlagWertAnzeige — ruhetage', () {
    test('Liste mit Werten -> kommagetrennt', () {
      expect(vorschlagWertAnzeige('ruhetage', ['Mo', 'Di']), 'Mo, Di');
    });

    test('leere Liste -> "kein Ruhetag"', () {
      expect(vorschlagWertAnzeige('ruhetage', []), 'kein Ruhetag');
    });

    test('fehlender Wert -> "keine Angabe"', () {
      expect(vorschlagWertAnzeige('ruhetage', null), 'keine Angabe');
    });
  });

  group('vorschlagWertAnzeige — oeffnungszeiten', () {
    test('mehrere Tage mit Slots', () {
      final wert = {
        'Mo': [
          {'von': '08:00', 'bis': '12:00'},
          {'von': '13:00', 'bis': '18:00'},
        ],
        'Di': [
          {'von': '08:00', 'bis': '18:00'},
        ],
      };
      expect(
        vorschlagWertAnzeige('oeffnungszeiten', wert),
        'Mo 08:00–12:00, 13:00–18:00 · Di 08:00–18:00',
      );
    });

    test('alle Tage leer -> "keine Angabe"', () {
      final wert = {'Mo': <Map>[], 'Di': <Map>[]};
      expect(vorschlagWertAnzeige('oeffnungszeiten', wert), 'keine Angabe');
    });

    test('fehlender Wert -> "keine Angabe"', () {
      expect(vorschlagWertAnzeige('oeffnungszeiten', null), 'keine Angabe');
    });
  });

  group('vorschlagWertAnzeige — ferien', () {
    test('eine Periode im selben Jahr', () {
      final wert = [
        {'von': '2026-08-01', 'bis': '2026-08-16'},
      ];
      expect(vorschlagWertAnzeige('ferien', wert), '01.08.–16.08.2026');
    });

    test('Periode über den Jahreswechsel -> beide mit Jahr', () {
      final wert = [
        {'von': '2026-12-24', 'bis': '2027-01-02'},
      ];
      expect(vorschlagWertAnzeige('ferien', wert), '24.12.2026–02.01.2027');
    });

    test('mehrere Perioden -> mit Semikolon getrennt', () {
      final wert = [
        {'von': '2026-08-01', 'bis': '2026-08-16'},
        {'von': '2026-12-24', 'bis': '2027-01-02'},
      ];
      expect(
        vorschlagWertAnzeige('ferien', wert),
        '01.08.–16.08.2026; 24.12.2026–02.01.2027',
      );
    });

    test('leere Liste -> "keine Angabe"', () {
      expect(vorschlagWertAnzeige('ferien', []), 'keine Angabe');
    });
  });

  group('vorschlagWertAnzeige — saison', () {
    test('nur Sommerfenster', () {
      final wert = {
        'sommer_start_datum': '2026-06-15',
        'sommer_ende_datum': '2026-10-20',
      };
      expect(vorschlagWertAnzeige('saison', wert), '15.06.–20.10.');
    });

    test('nur Winterfenster (über Jahreswechsel, ohne Jahr)', () {
      final wert = {
        'winter_start_datum': '2026-12-01',
        'winter_ende_datum': '2027-04-01',
      };
      expect(vorschlagWertAnzeige('saison', wert), '01.12.–01.04.');
    });

    test('Sommer und Winter zugleich -> beide mit Label', () {
      final wert = {
        'sommer_start_datum': '2026-06-15',
        'sommer_ende_datum': '2026-10-20',
        'winter_start_datum': '2026-12-01',
        'winter_ende_datum': '2027-04-01',
      };
      expect(
        vorschlagWertAnzeige('saison', wert),
        'Sommer 15.06.–20.10. / Winter 01.12.–01.04.',
      );
    });

    test('leere Map -> "keine Angabe"', () {
      expect(vorschlagWertAnzeige('saison', {}), 'keine Angabe');
    });
  });

  group('vorschlagWertAnzeige — status', () {
    test('vorübergehend geschlossen', () {
      expect(
        vorschlagWertAnzeige('status', {'status': 'CLOSED_TEMPORARILY'}),
        'bei Google vorübergehend geschlossen',
      );
    });

    test('unbekannter Status-Code -> Rohwert', () {
      expect(
        vorschlagWertAnzeige('status', {'status': 'IRGENDWAS'}),
        'IRGENDWAS',
      );
    });

    test('fehlender Wert -> "keine Angabe"', () {
      expect(vorschlagWertAnzeige('status', null), 'keine Angabe');
    });
  });

  group('vorschlagFeldLabel / vorschlagQuelleLabel', () {
    test('Feld-Labels', () {
      expect(vorschlagFeldLabel('oeffnungszeiten'), 'Öffnungszeiten');
      expect(vorschlagFeldLabel('saison'), 'Saison');
    });

    test('Quelle-Labels inkl. Kombination', () {
      expect(vorschlagQuelleLabel('google'), 'Google');
      expect(vorschlagQuelleLabel('website'), 'Website');
      expect(vorschlagQuelleLabel('google_website'), 'Google + Website');
    });
  });
}
