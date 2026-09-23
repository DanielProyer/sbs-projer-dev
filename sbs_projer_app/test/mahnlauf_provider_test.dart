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
    'b1': (name: 'Rössli', ort: 'Chur', aliase: <String>[]),
    'b2': (name: 'Sonne', ort: 'Davos', aliase: <String>['Sonnenwirt AG']),
  };

  // Rechnung vom 01.06., fällig 01.07., zugestellt → Erinnerung längst fällig.
  Rechnung faellig(String id, {String betrieb = 'b1', double brutto = 94.05}) =>
      _r(id: id, betrieb: betrieb, datum: d(2026, 6, 1), versendet: d(2026, 6, 1), brutto: brutto);

  MahnlaufDaten bau(
    List<Rechnung> rechnungen, {
    List<MahnlaufGutschrift> gutschriften = const [],
    DateTime? letzterAuszug,
    bool ohneAuszug = false,
    String? luecke,
    Set<String> mitGebuchterZahlung = const {},
  }) =>
      baueMahnlauf(
        rechnungen: rechnungen,
        betriebe: betriebe,
        gutschriften: gutschriften,
        letzterAuszug: ohneAuszug ? null : (letzterAuszug ?? auszug),
        auszugLuecke: luecke,
        mitGebuchterZahlung: mitGebuchterZahlung,
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
    final l = bau([faellig('r1')], luecke: 'Lücke: 01.08.–03.08.');
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
