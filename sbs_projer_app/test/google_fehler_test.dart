import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_fehler.dart';

void main() {
  // Wortlaut aus dem Feld (29.07.2026, Kontakte-Sync).
  const echterFehler =
      'FunctionException(status: 500, details: {error: People API 403: '
      'People API has not been used in project 1040401919292 before or it is '
      'disabled. Enable it by visiting '
      'https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=1040401919292 '
      'then retry. If you enabled this API recently, wait a few minutes for '
      'the action to propagate to our systems and retry.}, reasonPhrase: )';

  group('googleFehler — API nicht freigeschaltet', () {
    final f = googleFehler(echterFehler);

    test('wird als Freischaltungsproblem erkannt', () {
      expect(f.art, GoogleFehlerArt.apiNichtAktiviert);
    });

    test('nennt den Dienst beim Namen statt der Rohmeldung', () {
      expect(f.text, contains('Google Kontakte'));
      expect(f.text, isNot(contains('FunctionException')));
      expect(f.text, isNot(contains('propagate')));
    });

    test('reicht die Freischaltseite von Google durch', () {
      expect(f.link, startsWith('https://console.developers.google.com/'));
      expect(f.link, contains('people.googleapis.com'));
      // Kein Klammer-Müll aus der umgebenden Meldung.
      expect(f.link, isNot(contains('}')));
      expect(f.link, isNot(contains(' ')));
    });

    test('ist meldenswert', () {
      expect(f.istMeldenswert, isTrue);
    });

    test('erkennt auch den Kalender-Dienst', () {
      final k = googleFehler(
          'Calendar API has not been used in project 123 before or it is '
          'disabled.');
      expect(k.art, GoogleFehlerArt.apiNichtAktiviert);
      expect(k.text, contains('Google Kalender'));
    });
  });

  group('googleFehler — weitere Fälle', () {
    test('fehlende Freigabe', () {
      final f = googleFehler(
          'Request had insufficient authentication scopes. (403)');
      expect(f.art, GoogleFehlerArt.keineBerechtigung);
      expect(f.text, contains('neu verbinden'));
    });

    test('abgelaufene Verbindung', () {
      final f = googleFehler('invalid_grant: Token has been expired');
      expect(f.art, GoogleFehlerArt.verbindungAbgelaufen);
      expect(f.istMeldenswert, isTrue);
    });

    test('kein Konto verbunden wird nicht gemeldet', () {
      final f = googleFehler('skipped: not_connected');
      expect(f.art, GoogleFehlerArt.nichtVerbunden);
      expect(f.istMeldenswert, isFalse);
    });

    test('Unbekanntes behält den Originaltext', () {
      final f = googleFehler('Exception: irgendwas ganz anderes');
      expect(f.art, GoogleFehlerArt.unbekannt);
      expect(f.text, contains('irgendwas ganz anderes'));
      expect(f.link, isNull);
    });

    test('ohne Link im Text bleibt der Link leer', () {
      final f = googleFehler(
          'People API has not been used in project 999 before or it is disabled.');
      expect(f.art, GoogleFehlerArt.apiNichtAktiviert);
      expect(f.link, isNull);
    });
  });
}
