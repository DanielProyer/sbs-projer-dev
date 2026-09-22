import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

void main() {
  group('navPfad und navLabel', () {
    test('fuenf Ziele mit Pfad und Beschriftung', () {
      expect(NavZiel.values, [
        NavZiel.heute,
        NavZiel.einsaetze,
        NavZiel.betriebe,
        NavZiel.tour,
        NavZiel.mehr,
      ]);
      expect(navPfad(NavZiel.heute), '/');
      expect(navPfad(NavZiel.einsaetze), '/einsaetze');
      expect(navPfad(NavZiel.betriebe), '/betriebe');
      expect(navPfad(NavZiel.tour), '/touren');
      expect(navPfad(NavZiel.mehr), '/mehr');
      expect(navLabel(NavZiel.heute), 'Heute');
      expect(navLabel(NavZiel.einsaetze), 'Einsätze');
      expect(navLabel(NavZiel.betriebe), 'Betriebe');
      expect(navLabel(NavZiel.tour), 'Tour');
      expect(navLabel(NavZiel.mehr), 'Mehr');
    });
  });

  group('aktivesZiel', () {
    test('die vier Ziele selbst', () {
      expect(aktivesZiel('/'), NavZiel.heute);
      expect(aktivesZiel('/einsaetze'), NavZiel.einsaetze);
      expect(aktivesZiel('/betriebe'), NavZiel.betriebe);
      expect(aktivesZiel('/touren'), NavZiel.tour);
    });

    test('Unterseiten zaehlen zum Ziel', () {
      expect(aktivesZiel('/betriebe/abc-123'), NavZiel.betriebe);
      expect(
        aktivesZiel('/betriebe/abc-123/rechnungsadresse'),
        NavZiel.betriebe,
      );
      expect(
        aktivesZiel('/einsaetze?typ=stoerung'.split('?').first),
        NavZiel.einsaetze,
      );
    });

    test('Detailseiten der Einsatztypen zeigen auf Einsaetze', () {
      for (final p in [
        '/reinigungen/abc',
        '/stoerungen/abc',
        '/montagen/abc',
        '/eigenauftraege/abc',
        '/eroeffnungsreinigungen/abc',
        '/pikett/abc',
      ]) {
        expect(aktivesZiel(p), NavZiel.einsaetze, reason: p);
      }
    });

    test('alles uebrige leuchtet «Mehr»', () {
      for (final p in [
        '/mehr',
        '/buchhaltung',
        '/buchhaltung/mwst',
        '/rechnungen/abc',
        '/heineken',
        '/aufgaben',
        '/stammdaten',
        '/einstellungen',
      ]) {
        expect(aktivesZiel(p), NavZiel.mehr, reason: p);
      }
      expect(zeigtNavigation('/buchhaltung'), isTrue);
    });

    test('Personen gehoeren zu den Betrieben', () {
      expect(aktivesZiel('/kontakte'), NavZiel.betriebe);
      expect(aktivesZiel('/kontakte/abc/bearbeiten'), NavZiel.betriebe);
    });

    test('ein Praefix darf keinen anderen Namen kapern', () {
      // '/betriebe-alt' faengt mit '/betriebe' an, ist aber etwas anderes.
      expect(aktivesZiel('/betriebe-alt'), NavZiel.mehr);
    });
  });

  group('zeigtNavigation', () {
    test('die vier Ziele und normale Seiten zeigen sie', () {
      for (final p in [
        '/',
        '/einsaetze',
        '/betriebe',
        '/touren',
        '/aufgaben',
        '/buchhaltung',
        '/betriebe/abc',
        '/reinigungen/abc',
        '/dokumente',
      ]) {
        expect(zeigtNavigation(p), isTrue, reason: p);
      }
    });

    test('Formulare nicht — Endung neu und bearbeiten', () {
      for (final p in [
        '/reinigungen/neu',
        '/stoerungen/neu',
        '/betriebe/neu',
        '/betriebe/abc/bearbeiten',
        '/anlagen/abc/bierleitungen/neu',
        '/buchhaltung/buchungen/neu',
      ]) {
        expect(zeigtNavigation(p), isFalse, reason: p);
      }
    });

    test('Formulare ohne solche Endung', () {
      for (final p in [
        '/login',
        '/spesen',
        '/betriebe/abc-123/rechnungsadresse',
        '/einstellungen/preise/abc-123',
        '/buchhaltung/camt-import',
        '/buchhaltung/eingangsrechnungen/upload',
        '/materialien/bestellen',
        '/events/abc/lageplan',
      ]) {
        expect(zeigtNavigation(p), isFalse, reason: p);
      }
    });

    test('aehnliche Pfade bleiben verschont', () {
      // Die Liste darf nicht ueber das Ziel hinausschiessen.
      expect(zeigtNavigation('/materialien'), isTrue);
      expect(zeigtNavigation('/materialien/bestellungen'), isTrue);
      expect(zeigtNavigation('/einstellungen'), isTrue);
      expect(zeigtNavigation('/buchhaltung/eingangsrechnungen'), isTrue);
      expect(zeigtNavigation('/events/abc'), isTrue);
    });

    test('abschliessender Schraegstrich aendert nichts', () {
      expect(zeigtNavigation('/reinigungen/neu/'), isFalse);
      expect(zeigtNavigation('/betriebe/'), isTrue);
      expect(zeigtNavigation('/'), isTrue);
    });
  });
}
