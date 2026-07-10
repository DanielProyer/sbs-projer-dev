import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_kunde.dart';

void main() {
  group('istMeinKundeVorschlag', () {
    test('inaktiv -> false, auch mit Konventionell', () {
      expect(istMeinKundeVorschlag('inaktiv', ['Konventionell']), isFalse);
    });

    test('geschlossen -> false, auch mit Orion', () {
      expect(istMeinKundeVorschlag('geschlossen', ['Orion']), isFalse);
    });

    test('aktiv + Konventionell -> true', () {
      expect(istMeinKundeVorschlag('aktiv', ['Konventionell']), isTrue);
    });

    test('aktiv + Orion -> true', () {
      expect(istMeinKundeVorschlag('aktiv', ['David', 'Orion']), isTrue);
    });

    test('saisonpause + Konventionell -> true (weiterhin Kunde)', () {
      expect(istMeinKundeVorschlag('saisonpause', ['Konventionell']), isTrue);
    });

    test('aktiv + nur David/Higenie/Veranstaltungen -> false', () {
      expect(
          istMeinKundeVorschlag('aktiv', ['David', 'Higenie', 'Veranstaltungen']),
          isFalse);
    });

    test('aktiv + leere Zapfsysteme -> false', () {
      expect(istMeinKundeVorschlag('aktiv', const []), isFalse);
    });
  });
}
