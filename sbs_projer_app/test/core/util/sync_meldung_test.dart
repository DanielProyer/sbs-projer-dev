import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/sync_meldung.dart';

void main() {
  group('syncMeldung', () {
    test('nichts zu tun: freundliche Bestätigung, kein Fehler', () {
      final m = syncMeldung(pushed: 0, pulled: 0, fehler: []);

      expect(m.istFehler, isFalse);
      expect(m.text, contains('aktuell'));
    });

    test('erfolgreich: nennt gesendet und empfangen', () {
      final m = syncMeldung(pushed: 3, pulled: 5, fehler: []);

      expect(m.istFehler, isFalse);
      expect(m.text, contains('3'));
      expect(m.text, contains('5'));
    });

    test('Teilfehler: als Fehler markiert und beziffert', () {
      // Kern des Bugs: Vorher meldete die App hier «Synchronisierung
      // gestartet» und nie wieder etwas — der Nutzer hielt fehlende Daten
      // für übertragen.
      final m = syncMeldung(
        pushed: 2,
        pulled: 0,
        fehler: ['event_staende: 1 Satz/Sätze nicht übertragen (…)'],
      );

      expect(m.istFehler, isTrue);
      expect(m.text, contains('event_staende'));
    });

    test('mehrere Fehler: Anzahl steht in der Meldung', () {
      final m = syncMeldung(
        pushed: 0,
        pulled: 0,
        fehler: ['a: kaputt', 'b: kaputt', 'c: kaputt'],
      );

      expect(m.istFehler, isTrue);
      expect(m.text, contains('3'));
    });

    test('erfolgreicher Push zählt trotz Fehler mit', () {
      final m = syncMeldung(pushed: 7, pulled: 1, fehler: ['x: kaputt']);

      expect(m.istFehler, isTrue);
      expect(m.text, contains('7'));
    });
  });
}
