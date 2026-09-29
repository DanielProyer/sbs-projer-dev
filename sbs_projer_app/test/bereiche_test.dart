import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

void main() {
  group('bereichFuerPfad', () {
    test('Rechnungen', () {
      for (final p in [
        '/rechnungen',
        '/rechnungen/abc',
        '/rechnungen/pro-betrieb',
        '/heineken',
        '/heineken/abc',
        '/jahresrechnung',
        '/bergkundenpauschalen',
        '/buchhaltung/mahnwesen',
        '/buchhaltung/debitoren',
      ]) {
        expect(bereichFuerPfad(p), 'rechnungen', reason: p);
      }
    });

    test('Bank und Zahlungen', () {
      for (final p in [
        '/bank',
        '/buchhaltung/camt-import',
        '/buchhaltung/camt-pruefliste',
        '/buchhaltung/eingangsrechnungen',
        '/buchhaltung/eingangsrechnungen/abc',
      ]) {
        expect(bereichFuerPfad(p), 'bank', reason: p);
      }
    });

    test('Abschluesse und Steuern', () {
      for (final p in [
        '/abschluesse',
        '/buchhaltung/mwst',
        '/buchhaltung/monatsabschluss',
        '/buchhaltung/audit',
        '/buchhaltung/jahresabschluss',
        '/buchhaltung/jahresabschluss?jahr=2025',
        '/buchhaltung/abschreibung',
        '/buchhaltung/steuern',
        '/buchhaltung/steuern/2025',
      ]) {
        expect(bereichFuerPfad(p), 'abschluesse', reason: p);
      }
    });

    test('Lohn vor Buchhaltung, Rest der Buchhaltung bleibt Buchhaltung', () {
      expect(bereichFuerPfad('/buchhaltung/lohn'), 'lohn');
      expect(bereichFuerPfad('/buchhaltung/lohn/einstellungen'), 'lohn');
      expect(bereichFuerPfad('/buchhaltung'), 'buchhaltung');
      expect(bereichFuerPfad('/buchhaltung/konten'), 'buchhaltung');
      expect(bereichFuerPfad('/buchhaltung/buchungen/abc'), 'buchhaltung');
    });

    test('Dokumente; ausserhalb des Bueros nichts', () {
      expect(bereichFuerPfad('/dokumente'), 'dokumente');
      expect(bereichFuerPfad('/touren'), isNull);
      expect(bereichFuerPfad('/betriebe/abc'), isNull);
      expect(bereichFuerPfad('/'), isNull);
      // Kein Namens-Kapern: /heinekenfest ist nicht /heineken.
      expect(bereichFuerPfad('/heinekenfest'), isNull);
    });

    test('Query-String und Fragment werden vor dem Vergleich abgeschnitten', () {
      expect(bereichFuerPfad('/buchhaltung/abschreibung?jahr=2025'), 'abschluesse');
      expect(bereichFuerPfad('/rechnungen?x=1'), 'rechnungen');
      expect(bereichFuerPfad('/rechnungen#x'), 'rechnungen');
    });
  });

  group('zaehleJeBereich', () {
    test('zaehlt Routen je Buero-Bereich, ignoriert null und Fremdes', () {
      final n = zaehleJeBereich([
        '/heineken',
        '/rechnungen',
        '/buchhaltung/mwst',
        '/buchhaltung/camt-pruefliste',
        '/touren',
        null,
      ]);
      expect(n, {'rechnungen': 2, 'abschluesse': 1, 'bank': 1});
    });
  });

  group('Bereichs-Liste', () {
    test('Mehr hat die drei Gruppen in der richtigen Reihenfolge', () {
      expect(kBereichMehr.gruppen.map((g) => g.titel).toList(), [
        'Unterwegs',
        'Büro',
        'Einrichtung',
      ]);
      expect(
        kBereichMehr.gruppen.first.eintraege.map((e) => e.titel).toList(),
        ['Einsätze', 'Spesen', 'Aufgaben', 'Events', 'Google-Termine'],
      );
      expect(kBereichMehr.gruppen.first.eintraege.first.ziel, '/einsaetze');
      expect(
        kBereichMehr.gruppen[1].eintraege.map((e) => e.ziel).toList(),
        [
          '/rechnungen',
          '/bank',
          '/buchhaltung',
          '/buchhaltung/lohn',
          '/abschluesse',
          '/dokumente',
        ],
      );
      expect(
        kBereichMehr.gruppen[2].eintraege.map((e) => e.ziel).toList(),
        ['/auswertungen', '/stammdaten', '/einstellungen'],
      );
    });

    test('Mehr fuehrt kein Ziel der Leiste ein zweites Mal (27.09.2026)', () {
      // Material zog in die Leiste und verliess dafür «Unterwegs». Ein Ziel
      // mit zwei Einstiegen auf demselben Bildschirm ist Ballast — und der
      // Zähler einer der beiden Stellen stimmt früher oder später nicht.
      final leiste = {for (final z in NavZiel.values) navPfad(z)};
      for (final e in kBereichMehr.alleEintraege) {
        expect(leiste.contains(e.ziel), isFalse, reason: e.ziel);
      }
    });

    test('jeder Eintrag auf Mehr hat einen Untertitel', () {
      // Einheitliche Zeilen: Titel und Untertitel, keine halb leeren.
      for (final e in kBereichMehr.alleEintraege) {
        expect(e.untertitel, isNotNull, reason: e.titel);
        expect(e.untertitel!.trim(), isNotEmpty, reason: e.titel);
      }
    });

    test('kein Ziel steht in zwei Bereichsseiten ausser Mehr', () {
      // Mehr verweist absichtlich auf die Bereichsseiten; innerhalb der
      // Bereichsseiten gehoert jedes Ziel an genau einen Ort (vorher B3-
      // Waechter der Buchhaltungs-Gruppen).
      final gesehen = <String, String>{};
      for (final b in kAlleBereiche.where((b) => b.id != 'mehr')) {
        for (final e in b.alleEintraege) {
          expect(
            gesehen.containsKey(e.ziel),
            isFalse,
            reason: '${e.ziel} in ${gesehen[e.ziel]} und ${b.id}',
          );
          gesehen[e.ziel] = b.id;
        }
      }
    });

    test('Bereichs-IDs sind eindeutig', () {
      final ids = kAlleBereiche.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('Stichwoerter sind klein und ohne Umlaute (werden so verglichen)', () {
      for (final b in kAlleBereiche) {
        for (final e in b.alleEintraege) {
          for (final s in e.stichwoerter) {
            expect(s, s.toLowerCase(), reason: '${e.titel}: $s');
            expect(RegExp('[äöüß]').hasMatch(s), isFalse, reason: '${e.titel}: $s');
          }
        }
      }
    });
  });

  test('Suche findet die Pikett-Dienste ueber «pikett» (23.09.2026)', () {
    final pikett = kSuchZusatzZiele.where((e) => e.ziel == '/einsaetze?typ=pikett');
    expect(pikett, hasLength(1));
    expect(pikett.single.stichwoerter, contains('pikett'));
  });

  test('Suche findet Bergkundenpauschalen und Anlagen als Zusatzziel (T11)', () {
    final berg =
        kSuchZusatzZiele.where((e) => e.ziel == '/bergkundenpauschalen');
    expect(berg, hasLength(1));
    expect(berg.single.stichwoerter, contains('bergkunde'));

    final anlagen = kSuchZusatzZiele.where((e) => e.ziel == '/anlagen');
    expect(anlagen, hasLength(1));
    expect(anlagen.single.stichwoerter, contains('zapfanlage'));
  });
}
