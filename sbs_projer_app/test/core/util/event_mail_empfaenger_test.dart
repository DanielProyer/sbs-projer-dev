import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_mail_empfaenger.dart';

void main() {
  group('abschlussEmpfaenger', () {
    test('filtert auf event_heineken + rsl, Eventverantwortlicher zuerst', () {
      final v = abschlussEmpfaenger([
        (name: 'Ralf RSL', rolle: 'rsl', email: 'ralf@heineken.ch'),
        (name: 'Otto OK', rolle: 'ok', email: 'otto@x.ch'),
        (name: 'Eva Event', rolle: 'event_heineken', email: 'eva@heineken.ch'),
      ]);
      expect(v.map((e) => e.name).toList(), ['Eva Event', 'Ralf RSL']);
      expect(v.first.rolle, 'event_heineken');
    });

    test('Eintrag ohne E-Mail bleibt gelistet (email null/leer)', () {
      final v = abschlussEmpfaenger([
        (name: 'Eva Event', rolle: 'event_heineken', email: null),
        (name: 'Ralf RSL', rolle: 'rsl', email: ''),
      ]);
      expect(v.length, 2);
      expect(v[0].email, isNull);
      expect(v[1].email, '');
    });

    test('andere Rollen werden ignoriert', () {
      final v = abschlussEmpfaenger([
        (name: 'Bau Beat', rolle: 'bau', email: 'beat@x.ch'),
      ]);
      expect(v, isEmpty);
    });
  });

  group('abschlussBetreff / abschlussDateiname', () {
    test('Betreff enthält Name und Jahr', () {
      expect(abschlussBetreff('Openair Val Lumnezia', 2026),
          'Abschlussbericht Openair Val Lumnezia 2026');
    });
    test('Dateiname bereinigt Sonderzeichen/Leerzeichen', () {
      expect(abschlussDateiname('Openair Val Lumnezia', 2026),
          'Abschlussbericht_Openair_Val_Lumnezia_2026.pdf');
      expect(abschlussDateiname('Chant du Gros / 2024', 2026),
          'Abschlussbericht_Chant_du_Gros__2024_2026.pdf');
    });
  });
}
