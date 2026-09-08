import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

void main() {
  test('Storage-Pfad: user/bereich/jahr/id_dateiname', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'steuern',
          jahr: 2025,
          dokumentId: 'd1',
          dateiname: 'Rg 1.pdf'),
      'u1/steuern/2025/d1_Rg_1.pdf',
    );
  });

  test('Storage-Pfad ohne Jahr nutzt ohne-jahr', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'bank',
          jahr: null,
          dokumentId: 'd2',
          dateiname: 'a.pdf'),
      'u1/bank/ohne-jahr/d2_a.pdf',
    );
  });

  test('Storage-Pfad ersetzt Umlaute und Leerzeichen', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'steuern',
          jahr: 2024,
          dokumentId: 'd3',
          dateiname: 'Veranlagung Zürich.pdf'),
      'u1/steuern/2024/d3_Veranlagung_Z_rich.pdf',
    );
  });

  test('Typ-Vorschläge je Bereich: steuern enthält veranlagung, sonstiges immer dabei', () {
    expect(dokumentTypen('steuern'), contains('veranlagung'));
    expect(dokumentTypen('versicherungen'), contains('sonstiges'));
    expect(dokumentTypLabel('rechnung_definitiv'), 'Rechnung definitiv');
  });

  test('Unbekannter Bereich/Typ fällt sauber zurück', () {
    expect(dokumentTypen('unbekannt'), ['sonstiges']);
    expect(dokumentTypLabel('xyz'), 'xyz');
  });

  test('Pflicht-Typen: abgeschlossenes Jahr 6, laufendes Jahr 3', () {
    expect(pflichtTypen(jahr: 2024, heute: DateTime(2026, 9, 2)).length, 6);
    expect(pflichtTypen(jahr: 2026, heute: DateTime(2026, 9, 2)),
        ['jahresrechnung', 'lohnausweis', 'zinsausweis']);
  });

  test('Pflicht-Typ-Label: mit und ohne Steuerart-Suffix', () {
    expect(pflichtTypLabel('veranlagung:kanton'), 'Veranlagungsverfügung Kanton/Gemeinde');
    expect(pflichtTypLabel('jahresrechnung'), 'Jahresrechnung');
  });

  group('Kategorien je Bereich', () {
    test('Steuern behalten ihre Steuerarten', () {
      final k = dokumentKategorien('steuern');
      expect(k, isNotNull);
      expect(k!.keys, containsAll(['bund', 'kanton', 'mwst', 'busse']));
    });

    test('Vertraege kennen Gruendung und Franchise', () {
      final k = dokumentKategorien('vertraege');
      expect(k, isNotNull);
      expect(k!['gruendung'], 'Gründung');
      expect(k.keys, containsAll(['gruendung', 'franchise', 'fahrzeug']));
    });

    test('Bereiche ohne feste Liste liefern null (Freitext im Dialog)', () {
      expect(dokumentKategorien('bank'), isNull);
      expect(dokumentKategorien('sonstiges'), isNull);
      expect(dokumentKategorien('behoerden'), isNull);
    });
  });

  test('Dokumenttypen der Vertraege decken die Gruendungsakte ab', () {
    final t = dokumentTypen('vertraege');
    expect(t, containsAll(['vertrag', 'statuten', 'urkunde', 'protokoll']));
    for (final typ in t) {
      expect(dokumentTypLabel(typ), isNot(typ));
    }
  });

  group('Pensionskasse als eigener Bereich', () {
    test('steht im Bereichs-Dropdown', () {
      expect(dokumentBereiche['pensionskasse'], 'Pensionskasse');
    });

    test('bringt die Typen mit, die im Ordner 06_PK liegen', () {
      final t = dokumentTypen('pensionskasse');
      expect(t, containsAll(
          ['police', 'rechnung_definitiv', 'mahnung', 'kontoauszug', 'freizuegigkeit']));
    });

    test('braucht selbst keine Kategorienliste (Freitext genuegt)', () {
      expect(dokumentKategorien('pensionskasse'), isNull);
    });

    test('Storage-Pfad nutzt den neuen Bereich', () {
      expect(
        dokumentStoragePfad(
            userId: 'u1',
            bereich: 'pensionskasse',
            jahr: 2026,
            dokumentId: 'd1',
            dateiname: 'Ausweis.pdf'),
        'u1/pensionskasse/2026/d1_Ausweis.pdf',
      );
    });
  });

  group('Sozialversicherungen als eigene Bereiche', () {
    // Entscheid Daniel 08.09.2026: Jede Stelle mit eigenem Belegkreis bekommt
    // eine eigene Ebene. Als Sammeltopf hiess «Versicherungen», dass man vier
    // Absender durchsehen musste, um eine SUVA-Verfuegung zu finden.
    test('alle vier stehen im Bereichs-Dropdown', () {
      expect(dokumentBereiche['ahv'], 'AHV/SVA');
      expect(dokumentBereiche['unfall'], 'Unfall/SUVA');
      expect(dokumentBereiche['krankentaggeld'], 'Krankentaggeld');
      expect(dokumentBereiche['haftpflicht'], 'Haftpflicht');
    });

    test('AHV deckt ab, was die SVA schickt', () {
      // Bestand 04_SVA: 23 Rechnungen, 8 Mahnungen, 6 Verfuegungen, 6 Briefe,
      // 1 Anschlussvertrag. Akonto- und Schlussrechnung sind verschiedene
      // Typen, die Bussen kommen als eigene Verfuegung.
      expect(
        dokumentTypen('ahv'),
        containsAll([
          'rechnung_provisorisch',
          'rechnung_definitiv',
          'mahnung',
          'verfuegung',
          'bussverfuegung',
          'kontoauszug',
          'vertrag',
          'brief',
        ]),
      );
    });

    test('Unfall deckt ab, was die SUVA schickt', () {
      expect(
        dokumentTypen('unfall'),
        containsAll([
          'police',
          'rechnung_provisorisch',
          'rechnung_definitiv',
          'verfuegung',
          'vertrag',
          'brief',
        ]),
      );
    });

    test('Krankentaggeld und Haftpflicht kennen Police und Rechnung', () {
      for (final bereich in ['krankentaggeld', 'haftpflicht']) {
        expect(dokumentTypen(bereich),
            containsAll(['police', 'rechnung_definitiv', 'mahnung', 'vertrag', 'brief']),
            reason: 'Bereich $bereich');
      }
    });

    test('keiner der vier braucht eine Kategorienliste', () {
      for (final bereich in ['ahv', 'unfall', 'krankentaggeld', 'haftpflicht']) {
        expect(dokumentKategorien(bereich), isNull, reason: 'Bereich $bereich');
      }
    });

    test('Versicherungen bleibt als Sammelbereich, aber ohne Unterkategorien', () {
      // Fuer Sach-, Rechtsschutz- oder Fahrzeugversicherung, die spaeter
      // dazukommt. Die vier bekannten Stellen stehen nicht mehr darunter.
      expect(dokumentBereiche['versicherungen'], 'Versicherungen (übrige)');
      expect(dokumentKategorien('versicherungen'), isNull);
    });

    test('Storage-Pfade nutzen die neuen Bereiche', () {
      expect(
        dokumentStoragePfad(
            userId: 'u1',
            bereich: 'unfall',
            jahr: 2025,
            dokumentId: 'd9',
            dateiname: 'Praemienverfuegung.pdf'),
        'u1/unfall/2025/d9_Praemienverfuegung.pdf',
      );
    });
  });

  group('Wächter über die Bereichs-Konfiguration', () {
    test('jeder Bereich bringt eigene Typen mit', () {
      // Ohne Eintrag in _typenJeBereich faellt ein Bereich still auf
      // ['sonstiges'] zurueck — im UI sieht man dann ein Dropdown mit einem
      // einzigen Eintrag und merkt es erst beim Hochladen.
      for (final bereich in dokumentBereiche.keys) {
        expect(dokumentTypen(bereich), isNot(['sonstiges']),
            reason: 'Bereich $bereich hat keine eigene Typenliste');
      }
    });

    test('jeder angebotene Typ hat ein Label', () {
      for (final bereich in dokumentBereiche.keys) {
        for (final typ in dokumentTypen(bereich)) {
          expect(dokumentTypLabel(typ), isNot(typ),
              reason: 'Typ $typ (Bereich $bereich) ohne Label faellt im UI als Code auf');
        }
      }
    });

    test('jede Kategorienliste gehoert zu einem existierenden Bereich', () {
      for (final bereich in ['steuern', 'vertraege']) {
        expect(dokumentBereiche.containsKey(bereich), isTrue);
        expect(dokumentKategorien(bereich), isNotNull);
      }
    });
  });
}
