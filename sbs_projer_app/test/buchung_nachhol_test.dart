import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';

/// Die Entscheidung «braucht diese abgeschlossene Reinigung eine
/// Ertragsbuchung?» steht seit 04.09.2026 als reine Funktion neben dem
/// Buchungs-Service — damit die Nachhol-Suche exakt dieselbe Bedingung nutzt
/// wie das Buchen selbst. Vorher hätte man sie duplizieren müssen, und die
/// Kopie wäre beim ersten Regelwechsel auseinandergelaufen.
void main() {
  group('brauchtErtragsbuchung', () {
    test('Barzahlung und alle Rechnungsarten brauchen eine Buchung', () {
      for (final art in [
        'barzahlung',
        'rechnung_tresen',
        'rechnung_mail',
        'rechnung_post',
        'jahresrechnung',
      ]) {
        expect(
          brauchtErtragsbuchung(art: art, netto: 69),
          isTrue,
          reason: '$art muss gebucht werden',
        );
      }
    });

    test('Heineken läuft über die Monatsrechnung — keine Einzelbuchung', () {
      expect(brauchtErtragsbuchung(art: 'heineken', netto: 69), isFalse);
    });

    test('Kulanz und Heineken-Monteur werden nie gebucht', () {
      expect(
        brauchtErtragsbuchung(art: 'barzahlung', netto: 69, istKulanz: true),
        isFalse,
      );
      expect(
        brauchtErtragsbuchung(
          art: 'rechnung_tresen',
          netto: 69,
          istHeinekenMonteur: true,
        ),
        isFalse,
      );
    });

    test('Netto 0 oder negativ ergibt keine Buchung', () {
      expect(brauchtErtragsbuchung(art: 'barzahlung', netto: 0), isFalse);
      expect(brauchtErtragsbuchung(art: 'barzahlung', netto: -5), isFalse);
    });

    test('Unbekannte Art wird nicht gebucht', () {
      expect(brauchtErtragsbuchung(art: 'gutschein', netto: 69), isFalse);
    });

    test('deckt sich mit der alten Guard-Kette in allen Kombinationen', () {
      // Vor dem 04.09.2026 standen die Guards inline in createFromReinigung:
      //   (istBar || rechnungsTypen.contains(rs)) && !kulanz && !monteur
      //   && netto > 0
      // Diese Schleife hält fest, dass die herausgezogene Funktion exakt
      // dasselbe entscheidet — sonst würde ein Regelwechsel unbemerkt nur
      // eine der beiden Seiten treffen.
      for (final art in [
        ...zahlungsarten,
        'gutschein',
        '',
      ]) {
        for (final kulanz in [false, true]) {
          for (final monteur in [false, true]) {
            for (final netto in [-1.0, 0.0, 0.01, 69.0]) {
              final alt =
                  (art == 'barzahlung' ||
                      reinigungRechnungsTypen.contains(art)) &&
                  !kulanz &&
                  !monteur &&
                  netto > 0;
              expect(
                brauchtErtragsbuchung(
                  art: art,
                  netto: netto,
                  istKulanz: kulanz,
                  istHeinekenMonteur: monteur,
                ),
                alt,
                reason: 'art=$art kulanz=$kulanz monteur=$monteur netto=$netto',
              );
            }
          }
        }
      }
    });
  });
}
