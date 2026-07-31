import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_dauer.dart';

void main() {
  group('einsatzDauerVorgabe — Störungen', () {
    test('ohne Angaben die Standarddauer', () {
      expect(einsatzDauerVorgabe(art: 'stoerung'), 60);
    });

    test('ein einzelner Bereich ist kürzer als der Standard', () {
      // Ein Zapfhahn allein ist selten eine Stunde Arbeit.
      final d = einsatzDauerVorgabe(art: 'stoerung', stoerungBereiche: [1]);
      expect(d, lessThan(60));
      expect(d, greaterThanOrEqualTo(20));
    });

    test('mehr Bereiche bedeuten mehr Zeit', () {
      final einer = einsatzDauerVorgabe(art: 'stoerung', stoerungBereiche: [1]);
      final drei = einsatzDauerVorgabe(
        art: 'stoerung',
        stoerungBereiche: [1, 2, 3],
      );
      expect(drei, greaterThan(einer));
    });

    test('viele Bereiche werden gedeckelt, nicht endlos addiert', () {
      final alle = einsatzDauerVorgabe(
        art: 'stoerung',
        stoerungBereiche: [1, 2, 3, 4, 5],
      );
      expect(alle, lessThanOrEqualTo(180));
    });

    test('leere Bereichsliste zählt wie keine Angabe', () {
      expect(einsatzDauerVorgabe(art: 'stoerung', stoerungBereiche: []), 60);
    });
  });

  group('einsatzDauerVorgabe — Montagen', () {
    test('Neumontage dauert länger als der Standard', () {
      expect(
        einsatzDauerVorgabe(art: 'montage', montageTyp: 'neumontage'),
        greaterThan(60),
      );
    });

    test('Demontage ist kürzer als eine Neumontage', () {
      final neu = einsatzDauerVorgabe(art: 'montage', montageTyp: 'neumontage');
      final ab = einsatzDauerVorgabe(art: 'montage', montageTyp: 'demontage');
      expect(ab, lessThan(neu));
    });

    test('unbekannter Montage-Typ fällt auf den Standard zurück', () {
      expect(einsatzDauerVorgabe(art: 'montage', montageTyp: 'irgendwas'), 60);
    });

    test('Spesen und Aufwandsentschädigung brauchen keine Zeit vor Ort', () {
      // Das sind reine Abrechnungsposten, kein Einsatz beim Kunden.
      expect(einsatzDauerVorgabe(art: 'montage', montageTyp: 'spesen'), 0);
      expect(
        einsatzDauerVorgabe(
          art: 'montage',
          montageTyp: 'aufwandsentschaedigung',
        ),
        0,
      );
    });
  });

  group('einsatzDauerVorgabe — Sonstiges', () {
    test('unbekannte Art ergibt den Standard', () {
      expect(einsatzDauerVorgabe(art: 'unbekannt'), 60);
    });

    test('Vorgabe ist immer ein Vielfaches von 5 Minuten', () {
      // Der Tagesplan arbeitet in 5-Minuten-Schritten.
      for (final bereiche in [
        [1],
        [1, 2],
        [1, 2, 3],
        [1, 2, 3, 4],
        [1, 2, 3, 4, 5],
      ]) {
        final d = einsatzDauerVorgabe(
          art: 'stoerung',
          stoerungBereiche: bereiche,
        );
        expect(d % 5, 0, reason: 'Bereiche $bereiche ergaben $d');
      }
    });
  });
}
