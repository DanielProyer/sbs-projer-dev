import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _r({
  String id = 'r1',
  String typ = 'kundenrechnung',
  required DateTime datum,
  DateTime? faellig,
  String status = 'offen',
  String? versandart = 'rechnung_mail',
  DateTime? versendet,
  DateTime? uebergeben,
  DateTime? erinnerung,
  DateTime? mahnung1,
  DateTime? mahnung2,
  DateTime? frist,
  double brutto = 94.05,
  DateTime? zahlungEingegangen,
  double? zahlungBetrag,
}) =>
    Rechnung.fromJson({
      'id': id,
      'user_id': 'u',
      'rechnungsnummer': 'NR-$id',
      'rechnungstyp': typ,
      'betrieb_id': 'b1',
      'rechnungsdatum': datum.toIso8601String().split('T').first,
      'faelligkeitsdatum': (faellig ?? datum.add(const Duration(days: 30)))
          .toIso8601String()
          .split('T')
          .first,
      'betrag_netto': brutto / 1.081,
      'mwst_betrag': brutto - brutto / 1.081,
      'betrag_brutto': brutto,
      'zahlungsstatus': status,
      'versandart': versandart,
      'versendet_am': versendet?.toIso8601String().split('T').first,
      'uebergeben_am': uebergeben?.toIso8601String().split('T').first,
      'erinnerung_am': erinnerung?.toIso8601String().split('T').first,
      'mahnung_1_am': mahnung1?.toIso8601String().split('T').first,
      'mahnung_2_am': mahnung2?.toIso8601String().split('T').first,
      'mahn_frist_bis': frist?.toIso8601String().split('T').first,
      'mahnung_stufe': 0,
      'zahlung_eingegangen_am':
          zahlungEingegangen?.toIso8601String().split('T').first,
      'zahlung_betrag': zahlungBetrag,
    });

void main() {
  final d = DateTime.utc;

  group('imMahnbereich / zugestellt', () {
    test('Altlast vor 2026 nie', () {
      expect(imMahnbereich(_r(datum: d(2025, 12, 31), versendet: d(2026, 1, 1))), isFalse);
      expect(imMahnbereich(_r(datum: d(2026, 1, 1), versendet: d(2026, 1, 1))), isTrue);
    });
    test('Heineken-Monatsrechnung, bezahlt, abgeschrieben nie', () {
      expect(imMahnbereich(_r(typ: 'heineken_monat', datum: d(2026, 5, 1))), isFalse);
      expect(imMahnbereich(_r(status: 'bezahlt', datum: d(2026, 5, 1))), isFalse);
      expect(imMahnbereich(_r(status: 'abgeschrieben', datum: d(2026, 5, 1))), isFalse);
    });
    test('Jahresrechnung zaehlt', () {
      expect(imMahnbereich(_r(typ: 'jahresrechnung', datum: d(2026, 5, 1))), isTrue);
    });
    test('vermerkte Zahlung (noch nicht auf bezahlt gesetzt) nie (I-3)', () {
      expect(
        imMahnbereich(_r(datum: d(2026, 5, 1), zahlungBetrag: 50)),
        isFalse,
      );
      expect(
        imMahnbereich(_r(datum: d(2026, 5, 1), zahlungEingegangen: d(2026, 5, 10))),
        isFalse,
      );
    });
    test('zugestellt: Mail, Uebergabe oder Versandart Tresen (Entscheid 23.09.)', () {
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versendet: d(2026, 5, 2))), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail', uebergeben: d(2026, 5, 1))), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_tresen')), isTrue);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail')), isFalse);
      expect(istZugestellt(_r(datum: d(2026, 5, 1), versandart: 'rechnung_post')), isFalse);
    });
    test('Zustelldatum: Mail, dann Uebergabe, dann Rechnungsdatum', () {
      expect(zustelldatum(_r(datum: d(2026, 5, 1), versendet: d(2026, 6, 9))), d(2026, 6, 9));
      expect(zustelldatum(_r(datum: d(2026, 5, 1), versandart: 'rechnung_tresen')), d(2026, 5, 1));
    });
  });

  group('massgebendeFaelligkeit', () {
    test('normal: Faelligkeitsdatum', () {
      final r = _r(datum: d(2026, 8, 1), versendet: d(2026, 8, 1));
      expect(massgebendeFaelligkeit(r), d(2026, 8, 31));
    });
    test('nachtraeglich zugestellt: Zustellung + 30 Tage', () {
      final r = _r(datum: d(2026, 5, 8), versendet: d(2026, 9, 23));
      expect(massgebendeFaelligkeit(r), d(2026, 10, 23));
    });
  });

  group('faelligeStufe (Stichtag = Bankauszug)', () {
    // Faellig 31.08.; Erinnerung faellig ab 10.09.; mit Puffer 3 Tage
    // braucht es einen Auszug bis mindestens 13.09.
    final r = _r(datum: d(2026, 8, 1), versendet: d(2026, 8, 1));

    test('Erinnerung erst, wenn Faelligkeit + 10 mindestens 3 Tage vor Stichtag', () {
      expect(faelligeStufe(r, stichtag: d(2026, 9, 12)), isNull);
      expect(faelligeStufe(r, stichtag: d(2026, 9, 13)), MahnStufe.erinnerung);
    });

    test('1. Mahnung: Frist der Erinnerung + 5, mit Puffer', () {
      final e = _r(
        datum: d(2026, 8, 1),
        versendet: d(2026, 8, 1),
        status: 'erinnert',
        erinnerung: d(2026, 9, 15),
        frist: d(2026, 9, 25),
      );
      expect(faelligeStufe(e, stichtag: d(2026, 10, 2)), isNull);
      expect(faelligeStufe(e, stichtag: d(2026, 10, 3)), MahnStufe.mahnung1);
    });

    test('ohne gespeicherte Frist: Stufendatum + 10', () {
      final e = _r(
        datum: d(2026, 8, 1),
        versendet: d(2026, 8, 1),
        status: 'mahnung_1',
        mahnung1: d(2026, 9, 1),
      );
      // Frist 11.09. + 5 = 16.09. + 3 Puffer = 19.09.
      expect(faelligeStufe(e, stichtag: d(2026, 9, 18)), isNull);
      expect(faelligeStufe(e, stichtag: d(2026, 9, 19)), MahnStufe.letzte);
    });

    test('nach letzter Mahnung: Teil 2 (Heineken) — hier keine Stufe', () {
      final e = _r(
        datum: d(2026, 5, 1),
        versendet: d(2026, 5, 1),
        status: 'mahnung_2',
        mahnung2: d(2026, 7, 1),
        frist: d(2026, 7, 11),
      );
      expect(faelligeStufe(e, stichtag: d(2026, 9, 20)), isNull);
    });

    test('nicht zugestellt oder Altlast: nie', () {
      expect(faelligeStufe(_r(datum: d(2026, 5, 1), versandart: 'rechnung_mail'), stichtag: d(2026, 9, 20)), isNull);
      expect(faelligeStufe(_r(datum: d(2025, 5, 1), versendet: d(2025, 5, 1)), stichtag: d(2026, 9, 20)), isNull);
    });

    test('nur bekannte Status loesen Erinnerung aus (I-4)', () {
      final storniert = _r(
        datum: d(2026, 8, 1),
        versendet: d(2026, 8, 1),
        status: 'storniert',
      );
      expect(faelligeStufe(storniert, stichtag: d(2026, 9, 13)), isNull);
    });
  });

  group('bankSperre', () {
    test('ohne Auszug gesperrt', () {
      expect(bankSperre(null, heute: d(2026, 9, 23)), isTrue);
    });
    test('hoechstens 2 Tage alt', () {
      expect(bankSperre(d(2026, 9, 21), heute: d(2026, 9, 23)), isFalse);
      expect(bankSperre(d(2026, 9, 20), heute: d(2026, 9, 23)), isTrue);
    });
    test('Auszug-Luecke sperrt trotz aktuellem Datum (M-4)', () {
      expect(
        bankSperre(d(2026, 9, 23), heute: d(2026, 9, 23), auszugLuecke: true),
        isTrue,
      );
    });
  });

  group('gutschriftSperre', () {
    const g = (partei: 'BARBAR GMBH', betrag: 50.00);
    test('Zahlername passt (Alias oder Betriebsname)', () {
      expect(
        gutschriftSperre(
          betriebName: 'BarBar',
          aliase: const ['barbar gmbh'],
          offeneBetraege: const [94.05],
          gutschriften: const [g],
        ),
        isTrue,
      );
    });
    test('Zahlername enthaelt den Betriebsnamen, min. 4 Zeichen (M-2)', () {
      const g5 = (partei: 'BarBar GmbH', betrag: 999.00);
      expect(
        gutschriftSperre(
          betriebName: 'BarBar',
          aliase: const [],
          offeneBetraege: const [1.00],
          gutschriften: const [g5],
        ),
        isTrue,
      );
      // 'bar' ist zu kurz (< 4 Zeichen) und darf allein nicht treffen.
      const g6 = (partei: 'Barzahlung AG', betrag: 999.00);
      expect(
        gutschriftSperre(
          betriebName: 'Bar',
          aliase: const [],
          offeneBetraege: const [1.00],
          gutschriften: const [g6],
        ),
        isFalse,
      );
    });
    test('Betrag gleich einer Rechnung oder der Summe', () {
      const g2 = (partei: 'Unbekannt', betrag: 94.05);
      const g3 = (partei: 'Unbekannt', betrag: 188.10);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05, 94.05], gutschriften: const [g2]),
        isTrue,
      );
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05, 94.05], gutschriften: const [g3]),
        isTrue,
      );
    });
    test('Toleranz 0.10 bei Rundungsdifferenzen (I-2)', () {
      const g7 = (partei: 'Unbekannt', betrag: 94.05);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.07], gutschriften: const [g7]),
        isTrue,
      );
    });
    test('Teilsumme einer beliebigen Teilmenge sperrt (I-1, 2 von 3)', () {
      const g8 = (partei: 'Unbekannt', betrag: 70.00);
      expect(
        gutschriftSperre(
          betriebName: 'X',
          aliase: const [],
          offeneBetraege: const [30.00, 40.00, 50.00],
          gutschriften: const [g8],
        ),
        isTrue,
      );
    });
    test('mehr als 12 offene Betraege: sicherer Rueckfall sperrt (I-1)', () {
      final betraege = List<double>.generate(13, (i) => 10.0 + i);
      const g9 = (partei: 'Unbekannt', betrag: 12345.67);
      expect(
        gutschriftSperre(
          betriebName: 'X',
          aliase: const [],
          offeneBetraege: betraege,
          gutschriften: const [g9],
        ),
        isTrue,
      );
    });
    test('nichts passt: keine Sperre', () {
      const g4 = (partei: 'Fremd AG', betrag: 12.00);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05], gutschriften: const [g4]),
        isFalse,
      );
    });
  });

  group('passendeGutschrift (Sperrgrund sichtbar)', () {
    test('liefert die treffende Gutschrift (Index), Namens-Treffer ohne Rückfall', () {
      const fremd = (partei: 'Fremd AG', betrag: 12.00);
      const passt = (partei: 'Rössli Chur GmbH', betrag: 500.00);
      final t = passendeGutschrift(
        betriebName: 'Rössli Chur',
        aliase: const [],
        offeneBetraege: const [94.05],
        gutschriften: const [fremd, passt],
      );
      expect(t, isNotNull);
      expect(t!.index, 1);
      expect(t.rueckfall, isFalse);
    });
    test('Betrags-Treffer (Teilsumme) liefert den Index', () {
      const g = (partei: 'Unbekannt', betrag: 188.10);
      final t = passendeGutschrift(
        betriebName: 'X',
        aliase: const [],
        offeneBetraege: const [94.05, 94.05, 50.00],
        gutschriften: const [g],
      );
      expect(t?.index, 0);
      expect(t?.rueckfall, isFalse);
    });
    test('mehr als 12 offene Beträge: Rückfall-Sperre wird als solche gemeldet', () {
      const g = (partei: 'Unbekannt', betrag: 1.23);
      final t = passendeGutschrift(
        betriebName: 'X',
        aliase: const [],
        offeneBetraege: List.filled(13, 94.05),
        gutschriften: const [g],
      );
      expect(t?.index, 0);
      expect(t?.rueckfall, isTrue);
    });
    test('nichts passt: null — und gutschriftSperre bleibt gleich', () {
      const g = (partei: 'Fremd AG', betrag: 12.00);
      expect(
        passendeGutschrift(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05], gutschriften: const [g]),
        isNull,
      );
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05], gutschriften: const [g]),
        isFalse,
      );
    });
  });

  group('pruefeAuszugKette', () {
    ({DateTime von, DateTime bis, double? anfangssaldo, double? schlusssaldo}) a(
      DateTime von,
      DateTime bis, {
      double? opbd,
      double? clbd,
    }) =>
        (von: von, bis: bis, anfangssaldo: opbd, schlusssaldo: clbd);

    test('lückenlose Kette mit passenden Saldi: ok', () {
      final b = pruefeAuszugKette([
        a(d(2026, 8, 1), d(2026, 8, 31), opbd: 100, clbd: 200),
        a(d(2026, 9, 1), d(2026, 9, 20), opbd: 200, clbd: 250),
      ]);
      expect(b.status, AuszugKette.ok);
      expect(b.text, isNull);
    });
    test('fehlende Tage zwischen zwei Auszügen: Lücke', () {
      final b = pruefeAuszugKette([
        a(d(2026, 8, 1), d(2026, 8, 20)),
        a(d(2026, 9, 1), d(2026, 9, 20)),
      ]);
      expect(b.status, AuszugKette.luecke);
      expect(b.text, isNotNull);
    });
    test('nahtlos, aber Saldosprung (OPBD ≠ CLBD): Lücke', () {
      expect(
        pruefeAuszugKette([
          a(d(2026, 8, 1), d(2026, 8, 31), opbd: 100, clbd: 200),
          a(d(2026, 9, 1), d(2026, 9, 20), opbd: 150, clbd: 250),
        ]).status,
        AuszugKette.luecke,
      );
    });
    test('nahtlos, aber ein Saldo fehlt: ungeprüft (keine Sperre)', () {
      expect(
        pruefeAuszugKette([
          a(d(2026, 8, 1), d(2026, 8, 31), opbd: 100),
          a(d(2026, 9, 1), d(2026, 9, 20), opbd: 200, clbd: 250),
        ]).status,
        AuszugKette.ungeprueft,
      );
    });
    test('Lücke geht vor «ungeprüft»', () {
      expect(
        pruefeAuszugKette([
          a(d(2026, 7, 1), d(2026, 7, 31)),
          a(d(2026, 8, 1), d(2026, 8, 20), clbd: 1),
          a(d(2026, 9, 1), d(2026, 9, 20)),
        ]).status,
        AuszugKette.luecke,
      );
    });
    test('Überlappung ist harmlos; Reihenfolge der Eingabe egal', () {
      expect(
        pruefeAuszugKette([
          a(d(2026, 9, 10), d(2026, 9, 22)),
          a(d(2026, 8, 1), d(2026, 9, 15)),
        ]).status,
        AuszugKette.ok,
      );
    });
    test('Auszüge vor dem Mahnstart zählen nicht (alte Lücken sperren nie)', () {
      expect(
        pruefeAuszugKette([
          a(d(2025, 1, 1), d(2025, 3, 31)),
          a(d(2026, 3, 11), d(2026, 9, 22)),
        ]).status,
        AuszugKette.ok,
      );
    });
  });

  group('mahnKanal (eine Regel für Vorschau und Versand)', () {
    test('Mailadresse der Rechnungsadresse geht vor der des Betriebs', () {
      final k = mahnKanal(raMail: ' ra@x.ch ', betriebMail: 'b@x.ch', stufe: MahnStufe.erinnerung);
      expect(k.mail, 'ra@x.ch');
      expect(k.kanal, 'mail');
      expect(k.druck, isFalse);
    });
    test('ohne Rechnungsadress-Mail: Betrieb', () {
      final k = mahnKanal(raMail: '  ', betriebMail: 'b@x.ch', stufe: MahnStufe.mahnung1);
      expect(k.mail, 'b@x.ch');
      expect(k.kanal, 'mail');
    });
    test('keine Mailadresse: Druck', () {
      final k = mahnKanal(raMail: null, betriebMail: '', stufe: MahnStufe.erinnerung);
      expect(k.mail, isNull);
      expect(k.kanal, 'druck');
      expect(k.druck, isTrue);
    });
    test('letzte Mahnung: immer zusätzlich Druck (Einschreiben)', () {
      final k = mahnKanal(raMail: 'ra@x.ch', betriebMail: null, stufe: MahnStufe.letzte);
      expect(k.kanal, 'mail_und_druck');
      expect(k.druck, isTrue);
    });
  });

  group('Schreiben', () {
    test('Titel = hoechste Stufe', () {
      expect(hoechsteStufe([MahnStufe.erinnerung, MahnStufe.letzte, MahnStufe.mahnung1]), MahnStufe.letzte);
    });
    test('leere Liste wirft (M-5)', () {
      expect(() => hoechsteStufe(const []), throwsArgumentError);
    });
    test('Frist = Versand + 10 Tage', () {
      expect(mahnFrist(d(2026, 9, 23)), d(2026, 10, 3));
    });
    test('Stufen-Eigenschaften', () {
      expect(MahnStufe.erinnerung.wert, 1);
      expect(MahnStufe.mahnung1.wert, 2);
      expect(MahnStufe.letzte.wert, 3);
      expect(MahnStufe.letzte.status, 'mahnung_2');
      expect(MahnStufe.mahnung1.titel, '1. Mahnung');
      expect(MahnStufe.letzte.titel, 'Letzte Mahnung');
    });
  });

  group('unverknuepfteZahlungenAuswerten (24.09.2026)', () {
    UnverknuepfteZahlung z({
      DateTime? datum,
      double betrag = 94.05,
      String? belegnummer,
      String beschreibung = 'Zahlung',
    }) =>
        (
          datum: datum ?? d(2026, 1, 15),
          betrag: betrag,
          belegnummer: belegnummer,
          beschreibung: beschreibung,
        );

    const betriebe = [
      (id: 'b1', heinekenNr: '1234'),
      (id: 'b2', heinekenNr: '5678'),
    ];

    test('Heineken-Zahlung (022_-Belegnummer) sperrt nie', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(belegnummer: '022_2026_01_30_ZeHe_00889166')],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, isEmpty);
    });

    test('Heineken-Zahlung per Beschreibung sperrt nie', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [
          z(belegnummer: '999_egal', beschreibung: 'Zahlungseingang Heineken März'),
        ],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, isEmpty);
    });

    test('bekanntes Kürzel sperrt genau den Betrieb', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(datum: d(2026, 1, 15), betrag: 94.05, belegnummer: '020_2026_01_15_1234_94.05')],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren.keys, ['b1']);
      expect(erg.betriebsSperren['b1'], contains('15.01.2026'));
      expect(erg.betriebsSperren['b1'], contains('94.05'));
      expect(erg.betriebsSperren['b1'], contains('zuerst zuordnen'));
      expect(erg.ungeklaert, isEmpty);
    });

    test('ungültiges Kürzel (kein passender Betrieb) sperrt global', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(belegnummer: '020_2026_01_15_XXX_94.05')],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, hasLength(1));
    });

    test('Belegnummer ohne das Format (zu wenige Segmente) sperrt global', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(belegnummer: 'XXX')],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, hasLength(1));
    });

    test('keine Belegnummer sperrt global', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(belegnummer: null)],
        betriebe: betriebe,
      );
      expect(erg.ungeklaert, hasLength(1));
    });

    test('mehrdeutiges Kürzel (zwei Betriebe mit derselben Nummer) sperrt global', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(belegnummer: '020_2026_01_15_1234_94.05')],
        betriebe: const [
          (id: 'b1', heinekenNr: '1234'),
          (id: 'b3', heinekenNr: '1234'),
        ],
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, hasLength(1));
    });

    test('Zahlungen vor kMahnStart werden ignoriert', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [z(datum: d(2025, 12, 31), belegnummer: '020_2025_12_31_XXX_1.00')],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, isEmpty);
    });

    test('Stand 24.09.2026: nur die 2 Heineken-Zahlungen — keine Sperre', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [
          z(datum: d(2026, 1, 30), belegnummer: '022_2026_01_30_ZeHe_00889166'),
          z(datum: d(2026, 3, 2), belegnummer: '022_2026_03_02_ZeHe_00730691'),
        ],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren, isEmpty);
      expect(erg.ungeklaert, isEmpty);
    });

    test('mehrere Zahlungen: eine trifft Betrieb, eine bleibt ungeklärt', () {
      final erg = unverknuepfteZahlungenAuswerten(
        zahlungen: [
          z(belegnummer: '020_2026_01_15_1234_94.05'),
          z(belegnummer: '020_2026_02_01_XXX_50.00'),
        ],
        betriebe: betriebe,
      );
      expect(erg.betriebsSperren.keys, ['b1']);
      expect(erg.ungeklaert, hasLength(1));
    });
  });

  group('eskalationFaellig', () {
    test('mahnung_2, Frist + 5 Tage vor dem Puffer-Stichtag → true', () {
      final r = _r(
          datum: DateTime.utc(2026, 6, 1),
          status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 9, 1),
          frist: DateTime.utc(2026, 9, 11));
      // Frist 11.09. + 5 = 16.09.; Stichtag 19.09. − 3 = 16.09. → erreicht
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 19)), isTrue);
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 18)), isFalse);
    });
    test('ohne mahn_frist_bis zählt mahnung_2_am + 10', () {
      final r = _r(
          datum: DateTime.utc(2026, 6, 1),
          status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 9, 1));
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 19)), isTrue);
    });
    test('andere Stufe oder bezahlt → false', () {
      final r = _r(datum: DateTime.utc(2026, 6, 1), status: 'mahnung_1',
          mahnung1: DateTime.utc(2026, 8, 1));
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 12, 1)), isFalse);
      final b = _r(datum: DateTime.utc(2026, 6, 1), status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 8, 1), zahlungEingegangen: DateTime.utc(2026, 8, 5));
      expect(eskalationFaellig(b, stichtag: DateTime.utc(2026, 12, 1)), isFalse);
    });
  });
}
