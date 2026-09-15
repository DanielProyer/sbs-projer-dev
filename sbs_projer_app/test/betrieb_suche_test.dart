import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_suche.dart';

/// A9: Eine Suchregel für alle Betriebs-Auswahlfelder. Vorher suchten
/// Eigenauftrag und Eröffnungsreinigung nur im Namen — «Chur» fand dort
/// nichts, obwohl es in Störung und Reinigung funktionierte.
void main() {
  bool calanda(String suche) => betriebPasst(
        name: 'Calanda',
        ort: 'Chur',
        betriebNr: '4711',
        suche: suche,
      );

  group('betriebPasst', () {
    test('findet über den Namen', () {
      expect(calanda('Calanda'), isTrue);
      expect(calanda('cal'), isTrue);
    });

    test('findet über den Ort — der eigentliche Grund für A9', () {
      expect(calanda('Chur'), isTrue);
      expect(calanda('chu'), isTrue);
    });

    test('findet über die Betriebsnummer', () {
      expect(calanda('4711'), isTrue);
      expect(calanda('47'), isTrue);
    });

    test('Gross- und Kleinschreibung spielt keine Rolle', () {
      expect(calanda('CALANDA'), isTrue);
      expect(calanda('cHuR'), isTrue);
    });

    test('leere Eingabe passt immer', () {
      expect(calanda(''), isTrue);
      expect(calanda('   '), isTrue);
    });

    test('Leerzeichen um die Eingabe stören nicht', () {
      expect(calanda('  Chur '), isTrue);
    });

    test('was nicht passt, passt nicht', () {
      expect(calanda('Davos'), isFalse);
      expect(calanda('Rössli'), isFalse);
      expect(calanda('9999'), isFalse);
    });

    test('fehlender Ort und fehlende Nummer werfen nicht', () {
      expect(
        betriebPasst(name: 'Rössli', ort: null, betriebNr: null, suche: 'chur'),
        isFalse,
      );
      expect(
        betriebPasst(name: 'Rössli', ort: null, betriebNr: null, suche: 'röss'),
        isTrue,
      );
    });
  });
}
