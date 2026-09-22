import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/suche.dart';

SuchBetrieb _b(String id, String name, {String? ort, String? nr, String status = 'aktiv'}) =>
    (id: id, name: name, ort: ort, betriebNr: nr, status: status);

SuchPerson _p(String id, String vorname, {String? nachname, String? telefon, String? betrieb}) =>
    (id: id, vorname: vorname, nachname: nachname, telefon: telefon, betriebName: betrieb);

SuchRechnung _r(String id, String? nummer, {String? betrieb, DateTime? datum, double brutto = 100, String status = 'offen'}) =>
    (id: id, nummer: nummer, betriebName: betrieb, datum: datum ?? DateTime(2026, 9, 1), brutto: brutto, zahlungsstatus: status);

SuchBereich _bereich(String titel, String ziel, {String gruppe = 'Büro', List<String> stichwoerter = const []}) =>
    (titel: titel, untertitel: null, gruppe: gruppe, ziel: ziel, stichwoerter: stichwoerter);

void main() {
  group('normalisiere', () {
    test('klein, Umlaute, ß, Akzente, Leerzeichen', () {
      expect(normalisiere('  Rössli   Cham '), 'rossli cham');
      expect(normalisiere('Straße'), 'strasse');
      expect(normalisiere('Café Über'), 'cafe uber');
    });

    test('romanische/Tessiner Akzente', () {
      expect(normalisiere('Mòta'), 'mota');
    });
  });

  group('suche', () {
    final eingabe = SuchEingabe(
      betriebe: [
        _b('b1', 'Chleina Pub', ort: 'Cham', nr: '0137'),
        _b('b2', 'Pub am See', ort: 'Zug', status: 'geschlossen'),
        _b('b3', 'Rössli', ort: 'Cham'),
        _b('b4', 'Alter Pub', ort: 'Chur'),
      ],
      personen: [
        _p('k1', 'Donato', nachname: 'Toscano', telefon: '+41 79 108 41 08', betrieb: '4eri Bar'),
        _p('k2', 'Priska', nachname: 'Raguth', telefon: '079 700 71 29'),
      ],
      rechnungen: [
        _r('r1', '2026-09-1449', betrieb: 'Heineken', datum: DateTime(2026, 9, 5)),
        _r('r2', '2026-08-1449', betrieb: 'Alp Nova', datum: DateTime(2026, 8, 5)),
        _r('r3', '2026-09-1500', betrieb: 'Chleina Pub', datum: DateTime(2026, 9, 10)),
      ],
      bereiche: [
        _bereich('MwSt-Abrechnung', '/buchhaltung/mwst', stichwoerter: ['mwst', 'mehrwertsteuer']),
        _bereich('Stammdaten', '/stammdaten', gruppe: 'Einrichtung', stichwoerter: ['preise']),
      ],
    );

    List<String> titel(SuchErgebnis e, SuchGruppe g) =>
        e.gruppen.firstWhere((x) => x.gruppe == g).treffer.map((t) => t.titel).toList();

    test('unter 2 Zeichen: nichts', () {
      expect(suche(eingabe, 'p').gruppen, isEmpty);
      expect(suche(eingabe, '  ').gruppen, isEmpty);
    });

    test('mehrere Woerter muessen alle vorkommen', () {
      final e = suche(eingabe, 'pub cham');
      expect(titel(e, SuchGruppe.betriebe), ['Chleina Pub']);
    });

    test('Anfang vor Mitte, operativ vor geschlossen', () {
      final e = suche(eingabe, 'pub');
      // «Pub am See» beginnt mit «pub», ist aber geschlossen.
      // Rang zuerst (Anfang), dann operativ: Pub am See (Anfang) vor den
      // anderen (Mitte); unter den Mitte-Treffern alphabetisch.
      expect(titel(e, SuchGruppe.betriebe), ['Pub am See', 'Alter Pub', 'Chleina Pub']);
    });

    test('Umlaute in der Eingabe egal', () {
      expect(titel(suche(eingabe, 'rossli'), SuchGruppe.betriebe), ['Rössli']);
      expect(titel(suche(eingabe, 'rössli'), SuchGruppe.betriebe), ['Rössli']);
    });

    test('Rechnungsnummer als Teilstueck, neueste zuerst', () {
      final e = suche(eingabe, '1449');
      expect(titel(e, SuchGruppe.rechnungen), ['2026-09-1449', '2026-08-1449']);
    });

    test('nur Ziffern: Rechnungen vor Betrieben vor Personen', () {
      final e = suche(eingabe, '0137');
      expect(e.gruppen.first.gruppe, SuchGruppe.betriebe); // nur Betrieb trifft
      final z = suche(eingabe, '1500');
      expect(z.gruppen.first.gruppe, SuchGruppe.rechnungen);
      final gemischt = suche(eingabe, '07');
      final reihenfolge = gemischt.gruppen.map((g) => g.gruppe).toList();
      expect(reihenfolge.indexOf(SuchGruppe.personen), greaterThan(-1));
      if (reihenfolge.contains(SuchGruppe.rechnungen)) {
        expect(reihenfolge.indexOf(SuchGruppe.rechnungen),
            lessThan(reihenfolge.indexOf(SuchGruppe.personen)));
      }
    });

    test('Telefon ohne Leerzeichen und in 079-Schreibweise', () {
      expect(titel(suche(eingabe, '0791084108'), SuchGruppe.personen), ['Donato Toscano']);
      expect(titel(suche(eingabe, '079 108'), SuchGruppe.personen), ['Donato Toscano']);
      expect(titel(suche(eingabe, '0797007129'), SuchGruppe.personen), ['Priska Raguth']);
    });

    test('Telefon: alle drei Formen, egal wie gespeichert', () {
      // Donato ist als «+41 79 108 41 08» gespeichert.
      expect(titel(suche(eingabe, '+41 79 108'), SuchGruppe.personen), ['Donato Toscano']);
      expect(titel(suche(eingabe, '0041791084108'), SuchGruppe.personen), ['Donato Toscano']);
      expect(titel(suche(eingabe, '41791084108'), SuchGruppe.personen), ['Donato Toscano']);
      expect(titel(suche(eingabe, '0791084108'), SuchGruppe.personen), ['Donato Toscano']);
      // Priska ist als «079 700 71 29» gespeichert.
      expect(titel(suche(eingabe, '41797007129'), SuchGruppe.personen), ['Priska Raguth']);
      expect(titel(suche(eingabe, '+41 79 700'), SuchGruppe.personen), ['Priska Raguth']);
    });

    test('Person ueber den Betriebsnamen', () {
      expect(titel(suche(eingabe, '4eri'), SuchGruppe.personen), ['Donato Toscano']);
    });

    test('Bereiche ueber Stichwort', () {
      expect(titel(suche(eingabe, 'mwst'), SuchGruppe.bereiche), ['MwSt-Abrechnung']);
      expect(titel(suche(eingabe, 'preise'), SuchGruppe.bereiche), ['Stammdaten']);
    });

    test('Routen je Gruppe', () {
      final e = suche(eingabe, 'toscano');
      final t = e.gruppen.single.treffer.single;
      expect(t.route, '/kontakte/k1/bearbeiten');
      expect(t.telefon, '+41 79 108 41 08');
      expect(suche(eingabe, 'rossli').gruppen.single.treffer.single.route, '/betriebe/b3');
      expect(suche(eingabe, '1500').gruppen.single.treffer.single.route, '/rechnungen/r3');
    });

    test('leere Gruppen fehlen', () {
      final e = suche(eingabe, 'toscano');
      expect(e.gruppen.map((g) => g.gruppe), [SuchGruppe.personen]);
    });

    test('gleiches Rechnungsdatum: Rechnungsnummer absteigend als zweiter Schluessel', () {
      final e = SuchEingabe(
        betriebe: const [],
        personen: const [],
        rechnungen: [
          _r('x1', '2026-09-1000', datum: DateTime(2026, 9, 5)),
          _r('x2', '2026-09-2000', datum: DateTime(2026, 9, 5)),
        ],
        bereiche: const [],
      );
      expect(titel(suche(e, '2026-09'), SuchGruppe.rechnungen),
          ['2026-09-2000', '2026-09-1000']);
    });

    test('Rechnungstreffer: Betrag mit Apostroph, Status lesbar', () {
      final e = SuchEingabe(
        betriebe: const [],
        personen: const [],
        rechnungen: [
          _r('rx', '2026-09-9999', betrieb: 'X', brutto: 13966.09, status: 'mahnung_1'),
        ],
        bereiche: const [],
      );
      final t = suche(e, '9999').gruppen.single.treffer.single;
      expect(t.untertitel, contains("13'966.09"));
      expect(t.untertitel, contains('1. Mahnung'));
    });

    test('Deckel 5 mit Gesamtzahl; Bereiche ohne Deckel', () {
      final viele = SuchEingabe(
        betriebe: [for (var i = 0; i < 8; i++) _b('b$i', 'Bar $i')],
        personen: const [],
        rechnungen: const [],
        bereiche: [for (var i = 0; i < 7; i++) _bereich('Bar-Seite $i', '/x$i')],
      );
      final e = suche(viele, 'bar');
      final b = e.gruppen.firstWhere((g) => g.gruppe == SuchGruppe.betriebe);
      expect(b.treffer.length, 5);
      expect(b.gesamt, 8);
      final be = e.gruppen.firstWhere((g) => g.gruppe == SuchGruppe.bereiche);
      expect(be.treffer.length, 7);
    });
  });

  group('markiere', () {
    test('Suchwoerter fett, Gross/Klein egal, Reihenfolge erhalten', () {
      expect(markiere('Chleina Pub', 'pub'), [('Chleina ', false), ('Pub', true)]);
      expect(markiere('Chleina Pub', 'pub ch'),
          [('Ch', true), ('leina ', false), ('Pub', true)]);
      expect(markiere('Rössli', 'xyz'), [('Rössli', false)]);
    });

    test('tuerkisches İ stuerzt nicht ab (JS: toLowerCase() macht 2 Zeichen)', () {
      expect(markiere('İnci Arslan', 'arslan'),
          [('İnci ', false), ('Arslan', true)]);
    });
  });
}
