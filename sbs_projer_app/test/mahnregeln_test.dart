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
  });

  group('bankSperre', () {
    test('ohne Auszug gesperrt', () {
      expect(bankSperre(null, heute: d(2026, 9, 23)), isTrue);
    });
    test('hoechstens 2 Tage alt', () {
      expect(bankSperre(d(2026, 9, 21), heute: d(2026, 9, 23)), isFalse);
      expect(bankSperre(d(2026, 9, 20), heute: d(2026, 9, 23)), isTrue);
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
    test('nichts passt: keine Sperre', () {
      const g4 = (partei: 'Fremd AG', betrag: 12.00);
      expect(
        gutschriftSperre(betriebName: 'X', aliase: const [], offeneBetraege: const [94.05], gutschriften: const [g4]),
        isFalse,
      );
    });
  });

  group('Schreiben', () {
    test('Titel = hoechste Stufe', () {
      expect(hoechsteStufe([MahnStufe.erinnerung, MahnStufe.letzte, MahnStufe.mahnung1]), MahnStufe.letzte);
    });
    test('Frist = Versand + 10 Tage', () {
      expect(mahnFrist(d(2026, 9, 23)), d(2026, 10, 3));
    });
    test('Stufen-Eigenschaften', () {
      expect(MahnStufe.erinnerung.wert, 0);
      expect(MahnStufe.letzte.status, 'mahnung_2');
      expect(MahnStufe.mahnung1.titel, '1. Mahnung');
      expect(MahnStufe.letzte.titel, 'Letzte Mahnung');
    });
  });
}
