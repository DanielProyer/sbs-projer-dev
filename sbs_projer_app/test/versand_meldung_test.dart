import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/versand_meldung.dart';

/// Was nach einem abgebrochenen Mailversand auf dem Handy steht.
///
/// Der Fall vom 17.09.2026 (Löwen Maienfeld, Rechnung 2026-09-1452): Die Mail
/// war raus, der Server hatte den Vermerk gesetzt, nur die Antwort kam nicht
/// mehr an. Die App meldete «MAIL-VERSAND FEHLGESCHLAGEN» und forderte zum
/// Nachholen auf — ein zweiter Versand an denselben Kunden.
void main() {
  final netzfehler = Exception(
    'ClientException: Failed to fetch, uri=https://pltbaqqwpnmdajwgnhpd'
    '.supabase.co/functions/v1/send-rechnung-mail',
  );

  group('versandStandAus', () {
    test('true = versendet, false = nicht, null = unklar', () {
      expect(versandStandAus(true), VersandStand.versendet);
      expect(versandStandAus(false), VersandStand.nichtVersendet);
      expect(versandStandAus(null), VersandStand.unklar);
    });
  });

  group('versandMeldung', () {
    test(
      'Vermerk steht: kein Fehler, und ausdruecklich nicht nochmal senden',
      () {
        final m = versandMeldung(VersandStand.versendet, netzfehler);
        expect(m.istFehler, isFalse);
        expect(m.text, contains('versendet'));
        expect(m.text, contains('Nicht erneut senden'));
      },
    );

    test('kein Vermerk: Fehler, mit Weg zum Nachholen', () {
      final m = versandMeldung(VersandStand.nichtVersendet, netzfehler);
      expect(m.istFehler, isTrue);
      expect(m.text, contains('NICHT versendet'));
      expect(m.text, contains('nachholen'));
    });

    test('Nachfrage kam nicht durch: pruefen, nicht nachholen', () {
      final m = versandMeldung(VersandStand.unklar, netzfehler);
      expect(m.istFehler, isFalse);
      expect(m.text, contains('unklar'));
      expect(m.text, contains('prüfen'));
      expect(
        m.text,
        isNot(contains('nachholen')),
        reason: 'bei unklarem Stand darf nichts zum Zweitversand auffordern',
      );
    });

    test('keine Meldung zeigt die URL aus der Ausnahme', () {
      for (final stand in VersandStand.values) {
        final t = versandMeldung(stand, netzfehler).text;
        expect(t, isNot(contains('supabase.co')));
        expect(t, isNot(contains('uri=')));
        expect(t, contains('keine Verbindung'));
      }
    });
  });

  group('kettenFehlerMeldung', () {
    test('fordert zum Pruefen auf, nie zum Nachholen', () {
      final t = kettenFehlerMeldung(netzfehler);
      expect(t, contains('keine Verbindung'));
      expect(t, contains('prüfen'));
      expect(t, isNot(contains('supabase.co')));
      expect(
        t,
        isNot(contains('nachholen')),
        reason:
            'unklar, ob die Rechnung schon steht — Nachholen kann eine '
            'zweite Rechnung erzeugen',
      );
    });
  });

  group('buchungFehlerMeldung', () {
    test('nennt die Rechnungsliste, nicht das Reinigungs-Detail', () {
      final t = buchungFehlerMeldung(netzfehler);
      expect(t, contains('keine Verbindung'));
      expect(t, contains('Rechnungsliste'));
      expect(t, contains('tippen zum Nachbuchen'));
      expect(
        t,
        isNot(contains('Reinigungs-Detail')),
        reason: 'dort gibt es kein Nachbuchen — der Fehler von v0.109.1',
      );
    });
  });

  group('heigenieFehlerMeldung', () {
    test('erfindet keinen Nachhol-Weg', () {
      final t = heigenieFehlerMeldung(netzfehler);
      expect(t, contains('NICHT gemailt'));
      expect(t, contains('keine Verbindung'));
      expect(t, contains('Beat'));
      for (final erfunden in ['Reinigungs-Detail', 'Rechnungs-Detail']) {
        expect(
          t,
          isNot(contains(erfunden)),
          reason: 'die HeiGenie-Mail laesst sich nirgends erneut senden',
        );
      }
    });
  });
}
