import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/mahnlauf_provider.dart';

/// Die reine Aufbereitung der Mahnlauf-Seite. Hier entscheidet sich, welche
/// Betriebe Daniel zum Mahnen angeboten werden — jeder Test ist eine Art,
/// wie eine bezahlte Rechnung trotzdem in die Liste rutschen könnte.
Rechnung _r({
  required String id,
  String betrieb = 'b1',
  String typ = 'kundenrechnung',
  required DateTime datum,
  String status = 'offen',
  DateTime? versendet,
  String? versandart = 'rechnung_mail',
  double brutto = 94.05,
  DateTime? erinnerung,
  DateTime? mahnung1,
  DateTime? mahnung2,
  DateTime? frist,
  DateTime? zahlungAm,
  double? zahlungBetrag,
}) =>
    Rechnung(
      id: id,
      userId: 'u',
      rechnungsnummer: 'NR-$id',
      rechnungstyp: typ,
      betriebId: betrieb,
      rechnungsdatum: datum,
      faelligkeitsdatum: datum.add(const Duration(days: 30)),
      betragBrutto: brutto,
      zahlungsstatus: status,
      versandart: versandart,
      versendetAm: versendet,
      erinnerungAm: erinnerung,
      mahnung1Am: mahnung1,
      mahnung2Am: mahnung2,
      mahnFristBis: frist,
      zahlungEingegangenAm: zahlungAm,
      zahlungBetrag: zahlungBetrag,
    );

void main() {
  final d = DateTime.utc;
  // Auszug bis 22.09., heute 23.09. → Bank frei, Stichtag 22.09.
  final heute = d(2026, 9, 23);
  final auszug = d(2026, 9, 22);
  const betriebe = {
    'b1': (name: 'Rössli', ort: 'Chur', aliase: <String>[], raMail: 'ra@roessli.ch', betriebMail: null),
    'b2': (name: 'Sonne', ort: 'Davos', aliase: <String>['Sonnenwirt AG'], raMail: null, betriebMail: null),
  };

  // Rechnung vom 01.06., fällig 01.07., zugestellt → Erinnerung längst fällig.
  Rechnung faellig(String id, {String betrieb = 'b1', double brutto = 94.05}) =>
      _r(id: id, betrieb: betrieb, datum: d(2026, 6, 1), versendet: d(2026, 6, 1), brutto: brutto);

  MahnlaufDaten bau(
    List<Rechnung> rechnungen, {
    List<MahnlaufGutschrift> gutschriften = const [],
    DateTime? letzterAuszug,
    bool ohneAuszug = false,
    AuszugKettenBefund kette = (status: AuszugKette.ok, text: null),
    Set<String> mitGebuchterZahlung = const {},
    Set<String> faelleRechnungIds = const {},
  }) =>
      baueMahnlauf(
        rechnungen: rechnungen,
        betriebe: betriebe,
        gutschriften: gutschriften,
        letzterAuszug: ohneAuszug ? null : (letzterAuszug ?? auszug),
        auszugKette: kette,
        mitGebuchterZahlung: mitGebuchterZahlung,
        faelleRechnungIds: faelleRechnungIds,
        heute: heute,
      );

  test('zwei fällige Rechnungen eines Betriebs = eine Karte', () {
    final m = bau([faellig('r1'), faellig('r2'), faellig('r3', betrieb: 'b2')]);
    expect(m.bankGesperrt, isFalse);
    expect(m.betriebe, hasLength(2));
    final b1 = m.betriebe.firstWhere((b) => b.betriebId == 'b1');
    expect(b1.faellig.map((p) => p.rechnung.id), unorderedEquals(['r1', 'r2']));
    expect(b1.anzeige, 'Rössli, Chur');
    expect(b1.summeFaellig, closeTo(188.10, 0.001));
    expect(b1.hoechste, MahnStufe.erinnerung);
    expect(b1.gesperrt, isFalse);
  });

  test('passende offene Gutschrift sperrt den Betrieb — mit sichtbarem Grund', () {
    final m = bau(
      [faellig('r1')],
      gutschriften: [(partei: 'Rössli Chur GmbH', betrag: 500.0, datum: d(2026, 9, 20))],
    );
    final b = m.betriebe.single;
    expect(b.gesperrt, isTrue);
    expect(b.sperrgrund, contains('Zahlung ungeklärt'));
    expect(b.sperrgrund, contains('Rössli Chur GmbH'));
    expect(b.sperrgrund, contains('500.00'));
    expect(b.sperrgrund, contains('20.09.2026'));
  });

  test('Rückfall bei mehr als 12 offenen Beträgen: eigener Text', () {
    final m = bau(
      [for (var i = 0; i < 13; i++) faellig('r$i')],
      gutschriften: [(partei: 'Unbekannt', betrag: 1.23, datum: d(2026, 9, 20))],
    );
    expect(m.betriebe.single.sperrgrund, contains('viele offene Rechnungen'));
  });

  test('Bank gesperrt (Auszug zu alt) → nichts fällig, In Frist/Erst zustellen trotzdem', () {
    final gemahnt = _r(
      id: 'g1',
      datum: d(2026, 6, 1),
      versendet: d(2026, 6, 1),
      status: 'erinnert',
      erinnerung: d(2026, 9, 15),
      frist: d(2026, 9, 25),
    );
    final nichtZugestellt = _r(id: 'n1', datum: d(2026, 6, 1), versandart: 'rechnung_post');
    final m = bau(
      [faellig('r1'), gemahnt, nichtZugestellt],
      letzterAuszug: d(2026, 9, 10),
    );
    expect(m.bankGesperrt, isTrue);
    expect(m.betriebe, isEmpty);
    // Für die Glocke: Es WÄRE ein Betrieb fällig — zuerst Auszug einlesen.
    expect(m.betriebeHinterBanksperre, 1);
    expect(m.inFrist.map((r) => r.id), ['g1']);
    expect(m.erstZustellen.map((r) => r.id), ['n1']);
  });

  test('kein Auszug oder Lücke in der Kette → Bank gesperrt mit Grund', () {
    expect(bau([faellig('r1')], ohneAuszug: true).bankGesperrt, isTrue);
    final l = bau(
      [faellig('r1')],
      kette: (status: AuszugKette.luecke, text: 'Lücke: 01.08.–03.08.'),
    );
    expect(l.bankGesperrt, isTrue);
    expect(l.betriebe, isEmpty);
    expect(l.bankSperrgrund, contains('Lücke zwischen den Bankauszügen'));
  });

  test('Altlast und Heineken erscheinen nirgends', () {
    final alt = _r(id: 'a1', datum: d(2025, 11, 1), versendet: d(2025, 11, 1));
    final hk = _r(id: 'h1', typ: 'heineken_monat', datum: d(2026, 6, 1), versendet: d(2026, 6, 1));
    final m = bau([alt, hk]);
    expect(m.betriebe, isEmpty);
    expect(m.inFrist, isEmpty);
    expect(m.erstZustellen, isEmpty);
    expect(m.zahlungGebucht, isEmpty);
  });

  test('nicht zugestellte Rechnung landet in «erst zustellen», nie in fällig', () {
    final n = _r(id: 'n1', datum: d(2026, 6, 1), versandart: 'rechnung_post');
    final m = bau([n]);
    expect(m.betriebe, isEmpty);
    expect(m.erstZustellen.map((r) => r.id), ['n1']);
  });

  test('gebuchter Zahlungseingang → nie fällig, eigene Liste «Status prüfen»', () {
    final m = bau([faellig('r1'), faellig('r2')], mitGebuchterZahlung: {'r1'});
    final b = m.betriebe.single;
    expect(b.faellig.map((p) => p.rechnung.id), ['r2']);
    expect(m.zahlungGebucht.map((r) => r.id), ['r1']);
    // Auch der Kontoauszug-Entscheid zählt sie nicht als offen.
    expect(b.offeneImMahnbereich.map((r) => r.id), ['r2']);
  });

  test('nur gebucht bezahlte Rechnung → keine Karte', () {
    final m = bau([faellig('r1')], mitGebuchterZahlung: {'r1'});
    expect(m.betriebe, isEmpty);
    expect(m.zahlungGebucht, hasLength(1));
  });

  test('Sortierung: höchste Stufe zuerst, dann ältestes Rechnungsdatum', () {
    final erinnert = _r(
      id: 'e1',
      betrieb: 'b2',
      datum: d(2026, 5, 1),
      versendet: d(2026, 5, 1),
      status: 'erinnert',
      erinnerung: d(2026, 8, 1),
      frist: d(2026, 8, 11),
    );
    final aelter = _r(id: 'o1', datum: d(2026, 4, 1), versendet: d(2026, 4, 1));
    final m = bau([aelter, erinnert]);
    expect(m.betriebe.map((b) => b.betriebId), ['b2', 'b1']);
    expect(m.betriebe.first.hoechste, MahnStufe.mahnung1);
  });

  test('Jahresrechnungen des Betriebs inkl. bezahlter, letzte Zahlung', () {
    final bezahlt = _r(
      id: 'p1',
      datum: d(2026, 2, 1),
      status: 'bezahlt',
      zahlungAm: d(2026, 3, 5),
      zahlungBetrag: 120,
    );
    final vorjahr = _r(id: 'v1', datum: d(2025, 12, 1), status: 'bezahlt', zahlungAm: d(2026, 1, 2));
    final m = bau([faellig('r1'), bezahlt, vorjahr]);
    final b = m.betriebe.single;
    expect(b.rechnungenDesJahres.map((r) => r.id), unorderedEquals(['r1', 'p1']));
    expect(b.letzteZahlung?.datum, d(2026, 3, 5));
    expect(b.letzteZahlung?.betrag, 120);
  });

  test('Kanal auf der Karte: Mail bzw. Druck ohne Adresse', () {
    final m = bau([faellig('r1'), faellig('r2', betrieb: 'b2')]);
    final b1 = m.betriebe.firstWhere((b) => b.betriebId == 'b1');
    final b2 = m.betriebe.firstWhere((b) => b.betriebId == 'b2');
    expect(b1.kanal.kanal, 'mail');
    expect(b1.kanal.mail, 'ra@roessli.ch');
    expect(b2.kanal.kanal, 'druck');
  });

  test('fehlender Saldo in der Kette: Hinweis, aber keine Sperre', () {
    final m = bau(
      [faellig('r1')],
      kette: (status: AuszugKette.ungeprueft, text: 'Saldo fehlt'),
    );
    expect(m.bankGesperrt, isFalse);
    expect(m.auszugHinweis, 'Saldo fehlt');
    expect(m.betriebe, hasLength(1));
  });

  group('pruefeVorErstellen (frische Daten vor dem zweiten Klick)', () {
    final vorschau = bau([faellig('r1'), faellig('r2')]);
    final gewaehlt = vorschau.betriebe.single.faellig;

    test('unverändert: frische Karte und Posten', () {
      final p = pruefeVorErstellen(
        frisch: bau([faellig('r1'), faellig('r2')]),
        betriebId: 'b1',
        gewaehlt: gewaehlt,
      );
      expect(p.fehler, isNull);
      expect(p.posten.map((x) => x.rechnung.id), ['r1', 'r2']);
      expect(p.karte!.offeneImMahnbereich, hasLength(2));
    });

    test('inzwischen Zahlung gebucht: Abbruch', () {
      final p = pruefeVorErstellen(
        frisch: bau([faellig('r1'), faellig('r2')], mitGebuchterZahlung: {'r2'}),
        betriebId: 'b1',
        gewaehlt: gewaehlt,
      );
      expect(p.fehler, startsWith('Daten haben sich geändert — bitte neu prüfen'));
      expect(p.posten, isEmpty);
    });

    test('inzwischen ungeklärte Gutschrift: Abbruch', () {
      final p = pruefeVorErstellen(
        frisch: bau(
          [faellig('r1'), faellig('r2')],
          gutschriften: [(partei: 'Rössli', betrag: 1.0, datum: d(2026, 9, 22))],
        ),
        betriebId: 'b1',
        gewaehlt: gewaehlt,
      );
      expect(p.fehler, isNotNull);
    });

    test('Bank inzwischen gesperrt: Abbruch', () {
      final p = pruefeVorErstellen(
        frisch: bau([faellig('r1'), faellig('r2')], ohneAuszug: true),
        betriebId: 'b1',
        gewaehlt: gewaehlt,
      );
      expect(p.fehler, isNotNull);
    });

    test('andere Stufe als in der Vorschau: Abbruch', () {
      final erinnert = _r(
        id: 'r1',
        datum: d(2026, 6, 1),
        versendet: d(2026, 6, 1),
        status: 'erinnert',
        erinnerung: d(2026, 8, 1),
        frist: d(2026, 8, 11),
      );
      final p = pruefeVorErstellen(
        frisch: bau([erinnert, faellig('r2')]),
        betriebId: 'b1',
        gewaehlt: gewaehlt,
      );
      expect(p.fehler, contains('NR-r1'));
    });
  });

  group('Einzelmahnung', () {
    test('nur der Betrieb der Rechnung, Sicherungen bleiben', () {
      final m = bau(
        [faellig('r1'), faellig('r2'), faellig('r3', betrieb: 'b2')],
        gutschriften: [(partei: 'Sonnenwirt AG', betrag: 5.0, datum: d(2026, 9, 21))],
      );
      final e = fuerEinzelmahnung(m, 'r3');
      expect(e.betriebe.map((b) => b.betriebId), ['b2']);
      expect(e.betriebe.single.gesperrt, isTrue, reason: 'Alias-Treffer sperrt');
      final e1 = fuerEinzelmahnung(m, 'r1');
      expect(e1.betriebe.single.betriebId, 'b1');
    });

    test('Rechnung nicht fällig → keine Karte', () {
      final jung = _r(id: 'j1', datum: d(2026, 9, 1), versendet: d(2026, 9, 1));
      final e = fuerEinzelmahnung(bau([jung, faellig('r2', betrieb: 'b2')]), 'j1');
      expect(e.betriebe, isEmpty);
    });
  });

  group('Eskalation und Mahnfälle (Teil 2)', () {
    // Letzte Mahnung am 01.09., Frist 11.09. → +5 = 16.09. ≤ Stichtag 22.09. − 3.
    Rechnung letzte(String id, {String betrieb = 'b1', DateTime? frist}) => _r(
          id: id,
          betrieb: betrieb,
          datum: d(2026, 6, 1),
          versendet: d(2026, 6, 1),
          status: 'mahnung_2',
          mahnung2: d(2026, 9, 1),
          frist: frist ?? d(2026, 9, 11),
        );

    test('mahnung_2 mit abgelaufener Frist+5 → eskalation, nicht in Frist', () {
      final m = bau([letzte('m2')]);
      expect(m.eskalation, hasLength(1));
      expect(m.eskalation.single.betriebId, 'b1');
      expect(m.eskalation.single.faellig.map((p) => p.rechnung.id), ['m2']);
      expect(m.eskalation.single.gesperrt, isFalse);
      expect(m.inFrist, isEmpty);
      expect(m.betriebe, isEmpty);
    });

    group('pruefeVorEskalation (I-4)', () {
      test('unverändert: frische Karte', () {
        final p = pruefeVorEskalation(
            frisch: bau([letzte('m2'), letzte('m3')]), betriebId: 'b1', rechnungIds: ['m2', 'm3']);
        expect(p.fehler, isNull);
        expect(p.karte!.faellig.map((x) => x.rechnung.id), unorderedEquals(['m2', 'm3']));
      });

      test('inzwischen Zahlung gebucht: Abbruch mit Rechnungsnummer', () {
        final p = pruefeVorEskalation(
          frisch: bau([letzte('m2'), letzte('m3')], mitGebuchterZahlung: {'m3'}),
          betriebId: 'b1',
          rechnungIds: ['m2', 'm3'],
        );
        expect(p.fehler, contains('NR-m3'));
        expect(p.karte, isNull);
      });

      test('inzwischen in einem Fall: Abbruch', () {
        final p = pruefeVorEskalation(
          frisch: bau([letzte('m2')], faelleRechnungIds: {'m2'}),
          betriebId: 'b1',
          rechnungIds: ['m2'],
        );
        expect(p.fehler, isNotNull);
      });

      test('Bank gesperrt / Gutschrift ungeklärt: Abbruch', () {
        expect(
          pruefeVorEskalation(
            frisch: bau([letzte('m2')], ohneAuszug: true),
            betriebId: 'b1',
            rechnungIds: ['m2'],
          ).fehler,
          contains('Bankauszug'),
        );
        expect(
          pruefeVorEskalation(
            frisch: bau([letzte('m2')],
                gutschriften: [(partei: 'Rössli', betrag: 94.05, datum: d(2026, 9, 20))]),
            betriebId: 'b1',
            rechnungIds: ['m2'],
          ).fehler,
          contains('Zahlung ungeklärt'),
        );
      });

      test('keine Rechnung gewählt: Abbruch', () {
        expect(
          pruefeVorEskalation(frisch: bau([letzte('m2')]), betriebId: 'b1', rechnungIds: const [])
              .fehler,
          isNotNull,
        );
      });
    });

    test('mahnung_2 mit laufender Frist bleibt in Frist', () {
      final m = bau([letzte('m2', frist: d(2026, 9, 20))]);
      expect(m.eskalation, isEmpty);
      expect(m.inFrist.map((r) => r.id), ['m2']);
    });

    test('Rechnung eines offenen Falls → nur in imFall', () {
      final m = bau([letzte('m2')], faelleRechnungIds: {'m2'});
      expect(m.eskalation, isEmpty);
      expect(m.betriebe, isEmpty);
      expect(m.inFrist, isEmpty);
      expect(m.erstZustellen, isEmpty);
      expect(m.imFall.map((r) => r.id), ['m2']);
    });

    test('ein Fall friert auch mahnung_1-Rechnungen ein', () {
      final m1 = _r(
        id: 'm1',
        datum: d(2026, 5, 1),
        versendet: d(2026, 5, 1),
        status: 'mahnung_1',
        mahnung1: d(2026, 8, 1),
        frist: d(2026, 8, 11),
      );
      // Ohne Fall wäre sie als letzte Mahnung fällig.
      expect(bau([m1]).betriebe, hasLength(1));
      final m = bau([m1, faellig('r1')], faelleRechnungIds: {'m1'});
      expect(m.imFall.map((r) => r.id), ['m1']);
      expect(m.betriebe.single.faellig.map((p) => p.rechnung.id), ['r1']);
      expect(m.inFrist, isEmpty);
    });

    test('Bank-Sperre gilt auch für die Eskalation', () {
      final m = bau([letzte('m2')], letzterAuszug: d(2026, 9, 10));
      expect(m.bankGesperrt, isTrue);
      expect(m.eskalation, isEmpty);
      expect(m.betriebe, isEmpty);
    });

    test('Gutschrift-Sperre gilt auch für die Eskalation', () {
      final m = bau(
        [letzte('m2')],
        gutschriften: [(partei: 'Rössli', betrag: 94.05, datum: d(2026, 9, 20))],
      );
      expect(m.eskalation.single.gesperrt, isTrue);
      expect(m.eskalation.single.sperrgrund, contains('Zahlung ungeklärt'));
    });

    test('gebuchte Zahlung → keine Eskalation', () {
      final m = bau([letzte('m2')], mitGebuchterZahlung: {'m2'});
      expect(m.eskalation, isEmpty);
      expect(m.zahlungGebucht.map((r) => r.id), ['m2']);
    });

    test('Einzelmahnung: Fall-Rechnung bekommt keine Karte', () {
      final m = bau([faellig('r1'), faellig('r2')], faelleRechnungIds: {'r1'});
      final e = fuerEinzelmahnung(m, 'r1');
      expect(e.betriebe, isEmpty);
      expect(e.eskalation, isEmpty);
      expect(e.imFall.map((r) => r.id), ['r1']);
    });

    test('pruefeVorErstellen: Rechnung inzwischen in einem Fall → Abbruch', () {
      final vorschau = bau([faellig('r1'), faellig('r2')]);
      final p = pruefeVorErstellen(
        frisch: bau([faellig('r1'), faellig('r2')], faelleRechnungIds: {'r2'}),
        betriebId: 'b1',
        gewaehlt: vorschau.betriebe.single.faellig,
      );
      expect(p.fehler, contains('Mahnfall'));
      expect(p.posten, isEmpty);
    });
  });

  group('rechnungenMitGebuchterZahlung', () {
    Buchung b(String id, {int soll = 1020, int haben = 1100, String? beleg, bool storniert = false, String? stornoVon}) =>
        Buchung(
          id: id,
          userId: 'u',
          datum: d(2026, 9, 1),
          sollKonto: soll,
          habenKonto: haben,
          betragNetto: 94.05,
          betragBrutto: 94.05,
          beschreibung: 'Zahlung',
          belegId: beleg,
          geschaeftsjahr: 2026,
          istStorniert: storniert,
          stornoVonId: stornoVon,
        );

    test('Haben 1100 mit beleg_id = Rechnung zählt — auch Teilzahlungen', () {
      expect(rechnungenMitGebuchterZahlung([b('1', beleg: 'r1')]), {'r1'});
    });
    test('Ertragsbuchung (Soll 1100) und Stornos zählen nicht', () {
      expect(
        rechnungenMitGebuchterZahlung([
          b('1', soll: 1100, haben: 3200, beleg: 'r1'),
          b('2', beleg: 'r2', storniert: true),
          b('3', beleg: 'r3', stornoVon: 'x'),
          b('4'),
        ]),
        isEmpty,
      );
    });
  });
}
