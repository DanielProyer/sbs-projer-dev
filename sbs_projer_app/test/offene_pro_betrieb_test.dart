import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/offene_pro_betrieb.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Offene Rechnungen pro Betrieb, auf ein Jahr eingegrenzt.
///
/// WARUM: Die Sicht beantwortet «wer schuldet mir wie viel aus diesem Jahr?».
/// Fällt dabei eine Rechnung still durch den Filter, sieht man das Fehlen
/// nicht — es fehlt ja nur ein Betrag in einer Summe. Deshalb sind hier vor
/// allem die Randfälle festgenagelt.
void main() {
  Rechnung rg({
    required String id,
    String? betriebId,
    required DateTime datum,
    required double brutto,
    String status = 'offen',
    String typ = 'kundenrechnung',
    String? versandart,
    DateTime? uebergebenAm,
    DateTime? versendetAm,
  }) => Rechnung(
    id: id,
    userId: 'u1',
    rechnungsnummer: id,
    rechnungstyp: typ,
    betriebId: betriebId,
    rechnungsdatum: datum,
    faelligkeitsdatum: datum.add(const Duration(days: 30)),
    betragBrutto: brutto,
    zahlungsstatus: status,
    versandart: versandart,
    uebergebenAm: uebergebenAm,
    versendetAm: versendetAm,
  );

  final namen = {'b1': 'Rössli', 'b2': 'Türmli'};
  final orte = {'b1': 'Cham', 'b2': 'Sempach'};

  group('Filter', () {
    test('nur das gewählte Jahr, gemessen am Rechnungsdatum', () {
      final r = rechnungenProBetrieb(
        alle: [
          rg(
            id: 'a',
            betriebId: 'b1',
            datum: DateTime(2026, 3, 1),
            brutto: 100,
          ),
          rg(
            id: 'b',
            betriebId: 'b1',
            datum: DateTime(2025, 12, 31),
            brutto: 900,
          ),
          rg(
            id: 'c',
            betriebId: 'b1',
            datum: DateTime(2027, 1, 1),
            brutto: 700,
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.anzahl, 1);
      expect(r.single.summe, 100);
    });

    test('jahr null nimmt alle Jahrgänge', () {
      final r = rechnungenProBetrieb(
        alle: [
          rg(
            id: 'a',
            betriebId: 'b1',
            datum: DateTime(2026, 3, 1),
            brutto: 100,
          ),
          rg(id: 'b', betriebId: 'b1', datum: DateTime(2019, 5, 2), brutto: 50),
        ],
        jahr: null,
        namen: namen,
        orte: orte,
      );
      expect(r.single.anzahl, 2);
      expect(r.single.summe, 150);
    });

    test('bezahlt und abgeschrieben fallen raus, Zwischenstatus bleiben', () {
      // Negativliste: Ein neu eingeführter Status zählt automatisch als offen.
      final r = rechnungenProBetrieb(
        alle: [
          rg(id: 'a', betriebId: 'b1', datum: DateTime(2026, 1, 1), brutto: 10),
          rg(
            id: 'b',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 2),
            brutto: 20,
            status: 'gesendet',
          ),
          rg(
            id: 'c',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 3),
            brutto: 40,
            status: 'mahnung_2',
          ),
          rg(
            id: 'd',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 4),
            brutto: 80,
            status: 'erfundener_neuer_status',
          ),
          rg(
            id: 'e',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 5),
            brutto: 1000,
            status: 'bezahlt',
          ),
          rg(
            id: 'f',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 6),
            brutto: 2000,
            status: 'abgeschrieben',
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.summe, 150);
    });

    test('kein Treffer ergibt eine leere Liste, keinen Eintrag mit 0', () {
      expect(
        rechnungenProBetrieb(
          alle: [
            rg(
              id: 'a',
              betriebId: 'b1',
              datum: DateTime(2026, 1, 1),
              brutto: 10,
              status: 'bezahlt',
            ),
          ],
          jahr: 2026,
          namen: namen,
          orte: orte,
        ),
        isEmpty,
      );
    });
  });

  group('Gruppierung und Reihenfolge', () {
    test('höchster offener Betrag zuoberst', () {
      final r = rechnungenProBetrieb(
        alle: [
          rg(id: 'a', betriebId: 'b1', datum: DateTime(2026, 1, 1), brutto: 50),
          rg(
            id: 'b',
            betriebId: 'b2',
            datum: DateTime(2026, 1, 1),
            brutto: 300,
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.map((e) => e.name).toList(), ['Türmli', 'Rössli']);
      expect(r.first.ort, 'Sempach');
    });

    test(
      'gleicher Betrag: alphabetisch, damit die Reihenfolge stabil bleibt',
      () {
        final r = rechnungenProBetrieb(
          alle: [
            rg(
              id: 'a',
              betriebId: 'b2',
              datum: DateTime(2026, 1, 1),
              brutto: 100,
            ),
            rg(
              id: 'b',
              betriebId: 'b1',
              datum: DateTime(2026, 1, 1),
              brutto: 100,
            ),
          ],
          jahr: 2026,
          namen: namen,
          orte: orte,
        );
        expect(r.map((e) => e.name).toList(), ['Rössli', 'Türmli']);
      },
    );

    test(
      'Rechnungen eines Betriebs: jüngste zuoberst, ältestes Datum separat',
      () {
        final r = rechnungenProBetrieb(
          alle: [
            rg(
              id: 'alt',
              betriebId: 'b1',
              datum: DateTime(2026, 1, 8),
              brutto: 10,
            ),
            rg(
              id: 'neu',
              betriebId: 'b1',
              datum: DateTime(2026, 9, 2),
              brutto: 10,
            ),
          ],
          jahr: 2026,
          namen: namen,
          orte: orte,
        );
        expect(r.single.rechnungen.first.id, 'neu');
        expect(r.single.aeltestes, DateTime(2026, 1, 8));
      },
    );
  });

  group('Rechnungen ohne Betrieb', () {
    test('Heineken-Monatsrechnung bekommt einen sprechenden Namen', () {
      final r = rechnungenProBetrieb(
        alle: [
          rg(
            id: 'h',
            datum: DateTime(2026, 8, 31),
            brutto: 13966.09,
            typ: 'heineken_monat',
            status: 'gesendet',
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.name, 'Heineken-Monatsrechnung');
      expect(r.single.betriebId, isNull);
      expect(r.single.ort, isNull);
    });

    test('anderer Typ ohne Betrieb heisst schlicht «Ohne Betrieb»', () {
      final r = rechnungenProBetrieb(
        alle: [rg(id: 'x', datum: DateTime(2026, 2, 1), brutto: 20)],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.name, 'Ohne Betrieb');
    });

    test('unbekannte Betriebs-ID wird benannt, nicht verschwiegen', () {
      final r = rechnungenProBetrieb(
        alle: [
          rg(
            id: 'x',
            betriebId: 'weg',
            datum: DateTime(2026, 2, 1),
            brutto: 20,
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.name, 'Unbekannter Betrieb');
      expect(r.single.summe, 20);
    });
  });

  group('Zustellung', () {
    test('zählt die Rechnungen ohne jeden Zustellnachweis', () {
      // Der Unterschied zwischen «schuldet mir Geld» und «hat nie eine
      // Rechnung gesehen» — bei Blue Cinema vier Jahre lang übersehen.
      final r = rechnungenProBetrieb(
        alle: [
          rg(id: 'a', betriebId: 'b1', datum: DateTime(2026, 1, 1), brutto: 10),
          rg(
            id: 'b',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 2),
            brutto: 10,
            uebergebenAm: DateTime(2026, 1, 2),
          ),
          rg(
            id: 'c',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 3),
            brutto: 10,
            versendetAm: DateTime(2026, 1, 4),
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.anzahl, 3);
      expect(r.single.ohneZustellung, 1);
    });
  });

  group('Auswahl: offen gegen alle', () {
    // WARUM: Bis v0.126.0 zeigte der Screen nur Unbezahltes. Daniel wollte am
    // 21.09.2026 auch die bezahlten sehen — dieselbe Achse, andere Frage:
    // «wer schuldet mir was» wird zu «was habe ich diesem Kunden verrechnet».
    final daten = [
      rg(
        id: 'offen1',
        betriebId: 'b1',
        datum: DateTime(2026, 2, 1),
        brutto: 100,
      ),
      rg(
        id: 'bezahlt1',
        betriebId: 'b1',
        datum: DateTime(2026, 3, 1),
        brutto: 250,
        status: 'bezahlt',
      ),
      rg(
        id: 'abg',
        betriebId: 'b1',
        datum: DateTime(2026, 4, 1),
        brutto: 40,
        status: 'abgeschrieben',
      ),
    ];

    test('offen zeigt nur Unbezahltes', () {
      final r = rechnungenProBetrieb(
        alle: daten,
        jahr: 2026,
        namen: namen,
        orte: orte,
        auswahl: RechnungsAuswahl.offen,
      );
      expect(r.single.anzahl, 1);
      expect(r.single.summe, 100);
      expect(r.single.summeOffen, 100);
    });

    test('alle nimmt bezahlt und abgeschrieben dazu', () {
      final r = rechnungenProBetrieb(
        alle: daten,
        jahr: 2026,
        namen: namen,
        orte: orte,
        auswahl: RechnungsAuswahl.alle,
      );
      expect(r.single.anzahl, 3);
      expect(r.single.summe, 390);
      // Der offene Anteil bleibt getrennt ausweisbar — sonst verschwindet die
      // Mahn-Information in der Umsatzsumme.
      expect(r.single.summeOffen, 100);
      expect(r.single.anzahlOffen, 1);
    });

    test('Vorgabe ohne Angabe ist offen', () {
      final r = rechnungenProBetrieb(
        alle: daten,
        jahr: 2026,
        namen: namen,
        orte: orte,
      );
      expect(r.single.anzahl, 1);
    });

    test('bezahlte Rechnungen zaehlen NICHT als fehlende Zustellung', () {
      // Ist das Geld da, ist die Frage «kam sie an?» beantwortet. Sonst
      // meldete die Liste hunderte erledigte Tresen-Rechnungen.
      final r = rechnungenProBetrieb(
        alle: [
          rg(id: 'a', betriebId: 'b1', datum: DateTime(2026, 1, 1), brutto: 10),
          rg(
            id: 'b',
            betriebId: 'b1',
            datum: DateTime(2026, 1, 2),
            brutto: 10,
            status: 'bezahlt',
          ),
        ],
        jahr: 2026,
        namen: namen,
        orte: orte,
        auswahl: RechnungsAuswahl.alle,
      );
      expect(r.single.anzahl, 2);
      expect(r.single.ohneZustellung, 1);
    });
  });
  group('versandartKurz', () {
    test('kennt die gängigen Wege', () {
      expect(versandartKurz('rechnung_tresen'), 'Tresen');
      expect(versandartKurz('rechnung_mail'), 'E-Mail');
      expect(versandartKurz('rechnung_post'), 'Post');
    });

    test('fehlende Angabe wird benannt, nicht leer gelassen', () {
      expect(versandartKurz(null), 'ohne Angabe');
      expect(versandartKurz(''), 'ohne Angabe');
    });

    test('unbekannter Wert wird durchgereicht statt verschluckt', () {
      expect(versandartKurz('neuer_weg'), 'neuer_weg');
    });
  });
}
