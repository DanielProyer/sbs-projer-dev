import 'package:flutter_test/flutter_test.dart';
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
  });
}
