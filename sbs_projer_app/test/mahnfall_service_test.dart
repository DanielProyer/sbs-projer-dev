import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/mahnfall_service.dart';

/// Reine Teile des `MahnfallService` (Mahnwesen Teil 2, Task 5): der Text der
/// Heineken-Mail und die Vorbelegung des Schuldners für die Betreibung.
void main() {
  Rechnung r(
    String id,
    String nr,
    DateTime datum,
    double betrag, {
    DateTime? erinnerung,
    DateTime? mahnung1,
    DateTime? mahnung2,
  }) =>
      Rechnung(
        id: id,
        userId: 'u',
        rechnungsnummer: nr,
        rechnungstyp: 'kundenrechnung',
        rechnungsdatum: datum,
        faelligkeitsdatum: datum.add(const Duration(days: 30)),
        betragBrutto: betrag,
        zahlungsstatus: 'mahnung_2',
        mahnungStufe: 3,
        erinnerungAm: erinnerung,
        mahnung1Am: mahnung1,
        mahnung2Am: mahnung2,
      );

  group('heinekenMailText', () {
    final rechnungen = [
      r('a', 'RE-2026-0101', DateTime.utc(2026, 3, 4), 250.25,
          erinnerung: DateTime.utc(2026, 5, 2),
          mahnung1: DateTime.utc(2026, 6, 3),
          mahnung2: DateTime.utc(2026, 7, 6)),
      r('b', 'RE-2026-0150', DateTime.utc(2026, 4, 1), 220,
          mahnung1: DateTime.utc(2026, 6, 3),
          mahnung2: DateTime.utc(2026, 7, 6)),
    ];
    final text = MahnfallService.heinekenMailText(
      betrieb: 'Hemingway, Chur',
      rechnungen: rechnungen,
    );

    test('nennt Betrieb mit Ort und bittet um Kontaktaufnahme', () {
      expect(text, startsWith('Hallo'));
      expect(text, contains('Hemingway, Chur'));
      expect(text, contains('Könnt ihr mit dem Betrieb Kontakt aufnehmen?'));
    });

    test('jede Rechnung mit Nummer, Datum und Betrag, dazu das Total', () {
      expect(text, contains('RE-2026-0101'));
      expect(text, contains('04.03.2026'));
      expect(text, contains('CHF 250.25'));
      expect(text, contains('RE-2026-0150'));
      expect(text, contains('01.04.2026'));
      expect(text, contains('CHF 220.00'));
      expect(text, contains('Total'));
      expect(text, contains('CHF 470.25'));
    });

    test('Mahnverlauf je Rechnung, fehlende Stufen weggelassen', () {
      expect(text, contains('Erinnerung 02.05.2026'));
      expect(text, contains('1. Mahnung 03.06.2026'));
      expect(text, contains('letzte Mahnung 06.07.2026'));
      // Rechnung b hatte keine Erinnerung: genau eine Erinnerung im Text.
      expect('Erinnerung '.allMatches(text).length, 1);
    });

    test('Beilage Kontoauszug, Gruss, kein Zins, keine Gebühren', () {
      expect(text, contains('Kontoauszug'));
      expect(text, contains('Daniel Projer'));
      expect(text, contains('SBS Projer GmbH'));
      expect(text.toLowerCase(), isNot(contains('zins')));
      expect(text.toLowerCase(), isNot(contains('gebühr')));
    });

    test('Tausender-Apostroph im Total', () {
      final t = MahnfallService.heinekenMailText(
        betrieb: 'X',
        rechnungen: [r('c', 'N1', DateTime.utc(2026, 1, 5), 1234.5)],
      );
      expect(t, contains("CHF 1'234.50"));
    });

    test('mit Kundenguthaben: offen ist «zu zahlen» (Review M4)', () {
      final t = MahnfallService.heinekenMailText(
        betrieb: 'X',
        rechnungen: [
          r('c', 'N1', DateTime.utc(2026, 1, 5), 143.75)
              .copyWith(guthabenVerrechnet: 30),
        ],
      );
      expect(t, contains('CHF 113.75'));
      expect(t, isNot(contains('143.75')));
    });
  });

  group('schuldnerVorbelegung', () {
    test('Rechnungsadresse mit Firma geht vor', () {
      final s = MahnfallService.schuldnerVorbelegung(
        betriebName: 'Hemingway',
        firma: 'Gastro Muster GmbH',
        strasse: 'Bahnhofstrasse',
        nr: '12',
        plz: '7000',
        ort: 'Chur',
      );
      expect(s.name, 'Gastro Muster GmbH');
      expect(s.adresse, 'Bahnhofstrasse 12, 7000 Chur');
    });

    test('ohne Firma der Betriebsname, fehlende Teile ausgelassen', () {
      final s = MahnfallService.schuldnerVorbelegung(
        betriebName: 'Hemingway',
        firma: '  ',
        strasse: 'Bahnhofstrasse',
        plz: '7000',
        ort: 'Chur',
      );
      expect(s.name, 'Hemingway');
      expect(s.adresse, 'Bahnhofstrasse, 7000 Chur');
    });

    test('gar keine Adresse → null', () {
      final s = MahnfallService.schuldnerVorbelegung(betriebName: 'Hemingway');
      expect(s.adresse, isNull);
    });
  });

  group('notizOhneUebernahme / notizMitUebernahme', () {
    test('Markierung anhängen und wieder entfernen', () {
      final mit = MahnfallService.notizMitUebernahme('Telefon mit Heineken');
      expect(mit, contains('[UEBERNAHME OFFEN]'));
      expect(mit, startsWith('Telefon mit Heineken'));
      expect(MahnfallService.notizOhneUebernahme(mit), 'Telefon mit Heineken');
    });

    test('leere Notiz', () {
      expect(MahnfallService.notizMitUebernahme(null), '[UEBERNAHME OFFEN]');
      expect(MahnfallService.notizOhneUebernahme('[UEBERNAHME OFFEN]'), isNull);
    });

    test('nicht doppelt anhängen', () {
      final einmal = MahnfallService.notizMitUebernahme(null);
      expect(MahnfallService.notizMitUebernahme(einmal), einmal);
    });
  });

  group('betreibungsFelderBereinigen', () {
    test('Datum als Tag, leere Texte als null, Zahlen/Bool unverändert', () {
      final m = MahnfallService.betreibungsFelderBereinigen({
        'zahlungsbefehl_am': DateTime.utc(2026, 10, 3),
        'betreibungsamt': '  ',
        'schuldner_name': ' Gastro Muster GmbH ',
        'rechtsvorschlag': false,
        'kosten_vorschuss': 60.0,
      });
      expect(m['zahlungsbefehl_am'], '2026-10-03');
      expect(m.containsKey('betreibungsamt'), isTrue);
      expect(m['betreibungsamt'], isNull);
      expect(m['schuldner_name'], 'Gastro Muster GmbH');
      expect(m['rechtsvorschlag'], false);
      expect(m['kosten_vorschuss'], 60.0);
    });

    test('notiz ist kein Betreibungsfeld (M-5, nur über notizSpeichern)', () {
      expect(
        () => MahnfallService.betreibungsFelderBereinigen({'notiz': 'x'}),
        throwsArgumentError,
      );
    });

    test('fremde Felder (z. B. status) werden abgelehnt', () {
      expect(
        () => MahnfallService.betreibungsFelderBereinigen({'status': 'erledigt'}),
        throwsArgumentError,
      );
    });
  });

  group('notizZusammenfuehren (notizSpeichern)', () {
    const m = MahnfallService.kUebernahmeOffen;

    test('ohne Markierung: Text getrimmt, leer → null', () {
      expect(MahnfallService.notizZusammenfuehren('alt', ' neu '), 'neu');
      expect(MahnfallService.notizZusammenfuehren('alt', '  '), isNull);
      expect(MahnfallService.notizZusammenfuehren(null, null), isNull);
    });

    test('Markierung der alten Notiz bleibt erhalten', () {
      expect(MahnfallService.notizZusammenfuehren('x\n$m', 'Telefon mit Heineken'),
          'Telefon mit Heineken\n$m');
      expect(MahnfallService.notizZusammenfuehren(m, ''), m,
          reason: 'leeres Textfeld darf die Übernahme-Aufgabe nicht löschen');
    });

    test('Markierung kann nicht über das Textfeld neu entstehen', () {
      expect(MahnfallService.notizZusammenfuehren(null, 'a $m'), 'a');
    });
  });
}
