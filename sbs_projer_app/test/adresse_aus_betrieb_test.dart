import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/adresse_aus_betrieb.dart';

/// Der Knopf «Aus Betriebsdaten übernehmen» im Rechnungsadress-Formular.
///
/// Von 229 aktiven eigenen Kunden hatten am 17.09.2026 nur 74 eine
/// Rechnungsadresse — bei 37 davon eine reine Abschrift der Betriebsdaten.
BetriebsAdresse a({
  String strasse = '',
  String nr = '',
  String plz = '',
  String ort = '',
  String email = '',
}) => (strasse: strasse, nr: nr, plz: plz, ort: ort, email: email);

void main() {
  final loewen = a(
    strasse: 'Bahnhofstrasse',
    nr: '12',
    plz: '7304',
    ort: 'Maienfeld',
    email: 'info@loewen-maienfeld.ch',
  );

  group('uebernehmen', () {
    test('leeres Formular wird vollstaendig gefuellt', () {
      final u = uebernehmen(formular: a(), betrieb: loewen);
      expect(u.werte, loewen);
      expect(u.geaendert.length, 5);
      expect(u.ueberschrieben, isEmpty);
    });

    test('ein leeres Betriebsfeld ueberschreibt NIE', () {
      final u = uebernehmen(
        formular: a(strasse: 'Dorfplatz', nr: '3', plz: '7000', ort: 'Chur'),
        betrieb: a(ort: 'Chur', email: 'x@y.ch'), // Strasse/Nr/PLZ fehlen
      );
      expect(u.werte.strasse, 'Dorfplatz', reason: 'darf nicht geleert werden');
      expect(u.werte.nr, '3');
      expect(u.werte.plz, '7000');
      expect(u.werte.email, 'x@y.ch');
      expect(u.geaendert.map((f) => f.name), ['E-Mail']);
    });

    test('gleicher Wert zaehlt nicht als Aenderung', () {
      final u = uebernehmen(formular: loewen, betrieb: loewen);
      expect(u.geaendert, isEmpty);
      expect(u.werte, loewen);
    });

    test('Leerzeichen zaehlen nicht als Unterschied', () {
      final u = uebernehmen(
        formular: a(ort: '  Maienfeld  '),
        betrieb: a(ort: 'Maienfeld'),
      );
      expect(u.geaendert, isEmpty);
    });

    test('abweichende Werte werden als ueberschrieben gemeldet', () {
      final u = uebernehmen(
        formular: a(strasse: 'Postfach-Weg', ort: 'Maienfeld'),
        betrieb: loewen,
      );
      expect(u.werte.strasse, 'Bahnhofstrasse');
      expect(u.ueberschrieben.map((f) => f.name), ['Strasse']);
      expect(u.ueberschrieben.single.alt, 'Postfach-Weg');
      expect(
        u.geaendert.map((f) => f.name),
        containsAll(['Strasse', 'Nr.', 'PLZ', 'E-Mail']),
      );
      expect(u.geaendert.map((f) => f.name), isNot(contains('Ort')));
    });
  });

  group('uebernahmeMeldung', () {
    test('Betrieb ohne Adresse: sagt es, statt stumm zu bleiben', () {
      final u = uebernehmen(formular: a(), betrieb: a());
      expect(
        uebernahmeMeldung(u, betriebHatDaten: false),
        contains('keine Adresse hinterlegt'),
      );
    });

    test('nichts zu tun: sagt es auch', () {
      final u = uebernehmen(formular: loewen, betrieb: loewen);
      final m = uebernahmeMeldung(u, betriebHatDaten: true);
      expect(m, contains('schon so wie beim Betrieb'));
    });

    test('reines Fuellen nennt die Felder, ohne Warnung', () {
      final u = uebernehmen(formular: a(), betrieb: loewen);
      final m = uebernahmeMeldung(u, betriebHatDaten: true);
      expect(m, contains('Strasse'));
      expect(m, contains('E-Mail'));
      expect(m, isNot(contains('Überschrieben')));
    });

    test('Ueberschreiben wird benannt und als verwerfbar erklaert', () {
      final u = uebernehmen(formular: a(ort: 'Chur'), betrieb: loewen);
      final m = uebernahmeMeldung(u, betriebHatDaten: true);
      expect(m, contains('Überschrieben wurde Ort'));
      expect(m, contains('noch nicht gespeichert'));
    });
  });
}
