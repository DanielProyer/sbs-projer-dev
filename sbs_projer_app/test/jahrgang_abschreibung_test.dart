import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/jahrgang_abschreibung.dart';

/// Reine Logik des Schritts «Jahrgang abschreiben» — Auswahl, Kategorie,
/// Summen je Satz. Die Beträge stammen aus dem Bestand vom 19.09.2026
/// (docs/buchhaltung/abschreibungen-jahrgaenge.md): 2020 = 76 Rg,
/// 7'216.30 brutto = 6'699.87 netto + 516.43 MWST.
Rechnung _rg({
  required String id,
  required DateTime datum,
  double netto = 100,
  double mwst = 7.7,
  double? brutto,
  String typ = 'kundenrechnung',
  String status = 'offen',
  String? versandart = 'rechnung_mail',
  DateTime? versendetAm,
  DateTime? uebergebenAm,
  DateTime? zahlungAm,
  double? zahlungBetrag,
  String? betriebId = 'b1',
}) => Rechnung(
  id: id,
  userId: 'u',
  rechnungsnummer: 'RG-$id',
  rechnungstyp: typ,
  betriebId: betriebId,
  rechnungsdatum: datum,
  faelligkeitsdatum: datum.add(const Duration(days: 30)),
  betragNetto: netto,
  mwstBetrag: mwst,
  betragBrutto: brutto ?? netto + mwst,
  zahlungsstatus: status,
  versandart: versandart,
  versendetAm: versendetAm,
  uebergebenAm: uebergebenAm,
  zahlungEingegangenAm: zahlungAm,
  zahlungBetrag: zahlungBetrag,
);

const _namen = {'b1': 'Helvetia', 'b2': 'Confetti'};

void main() {
  group('Verjährungsgrenze', () {
    test('Abschluss 2026 → Jahrgänge bis 2021 (2020 und 2021)', () {
      expect(verjaehrtBisJahrgang(2026), 2021);
      expect(verjaehrtBisJahrgang(2025), 2020);
      expect(verjaehrtBisJahrgang(2027), 2022);
    });
  });

  group('Kategorie', () {
    test('Tresen schlägt alles — auch mit Versanddatum', () {
      expect(
        kategorieFuer(
          versandart: 'rechnung_tresen',
          uebergebenAm: null,
          versendetAm: DateTime(2020, 5, 1),
        ),
        AbschreibKategorie.tresen,
      );
      expect(
        kategorieFuer(
          versandart: 'rechnung_mail',
          uebergebenAm: DateTime(2020, 5, 1),
          versendetAm: null,
        ),
        AbschreibKategorie.tresen,
      );
    });
    test('Mail/Post mit Versanddatum = gestellt, ohne = nie gestellt', () {
      expect(
        kategorieFuer(
          versandart: 'rechnung_post',
          uebergebenAm: null,
          versendetAm: DateTime(2022, 7, 5),
        ),
        AbschreibKategorie.gestellt,
      );
      expect(
        kategorieFuer(
          versandart: 'rechnung_mail',
          uebergebenAm: null,
          versendetAm: null,
        ),
        AbschreibKategorie.nieGestellt,
      );
      expect(
        kategorieFuer(versandart: null, uebergebenAm: null, versendetAm: null),
        AbschreibKategorie.nieGestellt,
      );
    });
  });

  group('Auswahl', () {
    final offene = [
      _rg(id: 'a', datum: DateTime(2020, 3, 2)),
      _rg(
        id: 'b',
        datum: DateTime(2021, 12, 31),
        versandart: 'rechnung_tresen',
      ),
      _rg(id: 'c', datum: DateTime(2022, 1, 1)), // zu jung für 2026
      _rg(id: 'd', datum: DateTime(2019, 6, 1), typ: 'heineken_monat'),
      _rg(
        id: 'e',
        datum: DateTime(2020, 8, 8),
        zahlungAm: DateTime(2020, 9, 1),
      ),
      _rg(id: 'f', datum: DateTime(2020, 8, 9), brutto: 200), // Summe falsch
      _rg(id: 'g', datum: DateTime(2020, 8, 10), netto: 0, mwst: 0),
      _rg(id: 'h', datum: DateTime(2020, 1, 1), status: 'bezahlt'),
    ];

    test('nimmt Kundenrechnungen bis zur Grenze, sortiert nach Datum', () {
      final a = auswahlFuer(offene, geschaeftsjahr: 2026, betriebNamen: _namen);
      expect(a.positionen.map((p) => p.id), ['a', 'b']);
      expect(a.grenze, 2021);
      expect(a.buchungsdatum, DateTime(2026, 12, 31));
      expect(a.positionen.first.betrieb, 'Helvetia');
      expect(a.positionen.first.nummer, 'RG-a');
    });

    test('2027 nimmt auch 2022 dazu', () {
      final a = auswahlFuer(offene, geschaeftsjahr: 2027, betriebNamen: _namen);
      expect(a.positionen.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('weist aus, was nicht gebucht werden darf — mit Grund', () {
      final a = auswahlFuer(offene, geschaeftsjahr: 2026, betriebNamen: _namen);
      final gruende = {for (final x in a.ausgeschlossen) x.id: x.grund};
      expect(gruende.keys, unorderedEquals(['e', 'f', 'g']));
      expect(gruende['e'], contains('Zahlung'));
      expect(gruende['f'], contains('Brutto'));
      expect(gruende['g'], contains('0'));
    });

    test('mit Kundenguthaben → ausgeschlossen, einzeln abschreiben (Review I3)',
        () {
      final r = _rg(id: 'k', datum: DateTime(2020, 5, 1))
          .copyWith(guthabenVerrechnet: 30);
      final a = auswahlFuer([r], geschaeftsjahr: 2026, betriebNamen: _namen);
      expect(a.positionen, isEmpty);
      expect(a.ausgeschlossen.single.grund, contains('Kundenguthaben'));
    });

    test('Heineken und bezahlte bleiben stumm draussen', () {
      final a = auswahlFuer(offene, geschaeftsjahr: 2026, betriebNamen: _namen);
      final alle = [
        ...a.positionen.map((p) => p.id),
        ...a.ausgeschlossen.map((x) => x.id),
      ];
      expect(alle, isNot(contains('d')));
      expect(alle, isNot(contains('h')));
    });

    test('unbekannter Betrieb → leerer Name, kein Absturz', () {
      final a = auswahlFuer(
        [_rg(id: 'x', datum: DateTime(2020, 1, 1), betriebId: 'fremd')],
        geschaeftsjahr: 2026,
        betriebNamen: _namen,
      );
      expect(a.positionen.single.betrieb, '');
    });
  });

  group('Vorschau', () {
    test('Summen je Jahrgang, Kategorie und Satz — Satz aus den Beträgen', () {
      final a = auswahlFuer(
        [
          _rg(
            id: '1',
            datum: DateTime(2020, 2, 1),
            netto: 67.85,
            mwst: 5.20, // Residuum der 5-Rappen-Rundung (7.66 % → Satz 7.7)
            brutto: 73.05,
            versandart: 'rechnung_tresen',
          ),
          _rg(
            id: '2',
            datum: DateTime(2020, 3, 1),
            netto: 100,
            mwst: 7.70,
            versendetAm: DateTime(2022, 7, 5),
          ),
          _rg(id: '3', datum: DateTime(2021, 3, 1), netto: 100, mwst: 7.70),
          // ein 8.1er-Ausreisser (kommt real erst ab Jahrgang 2024 vor)
          _rg(id: '4', datum: DateTime(2021, 4, 1), netto: 100, mwst: 8.10),
        ],
        geschaeftsjahr: 2026,
        betriebNamen: _namen,
      );
      final v = AbschreibVorschau.aus(a);

      expect(v.total.anzahl, 4);
      expect(v.total.netto, 367.85);
      expect(v.total.mwst, 28.70);
      expect(v.total.brutto, 396.55);
      expect(v.jahrgangText, '2020, 2021');

      final j2020 = v.jahrgaenge.first;
      expect(j2020.jahrgang, 2020);
      expect(j2020.total.anzahl, 2);
      expect(j2020.jeKategorie[AbschreibKategorie.tresen]!.anzahl, 1);
      expect(j2020.jeKategorie[AbschreibKategorie.gestellt]!.anzahl, 1);
      expect(j2020.jeKategorie[AbschreibKategorie.nieGestellt]!.anzahl, 0);
      expect(
        v.jahrgaenge[1].jeKategorie[AbschreibKategorie.nieGestellt]!.anzahl,
        2,
      );

      expect(v.saetze.map((s) => s.satz), [7.7, 8.1]);
      expect(v.saetze[0].summe.anzahl, 3);
      expect(v.saetze[0].summe.mwst, 20.60);
      expect(v.saetze[0].formularZeile, 'Zeile 302');
      expect(v.saetze[1].formularZeile, 'Zeile 303');
    });

    test('krumme Rappen (5-Rappen-Rundung) landen beim Satz 7.7', () {
      // 2020er-Bestand: 7.68 % bis 7.72 % rechnerisch, weil brutto auf
      // 5 Rappen gerundet wurde — alles ist Satz 7.7.
      final p = AbschreibPosition(
        id: 'x',
        nummer: 'x',
        betrieb: '',
        datum: DateTime(2020),
        netto: 67.85,
        mwst: 5.20,
        brutto: 73.05,
        kategorie: AbschreibKategorie.tresen,
      );
      expect(p.satz, 7.7);
    });

    test('leere Auswahl → leere Vorschau', () {
      final v = AbschreibVorschau.aus(
        auswahlFuer(const [], geschaeftsjahr: 2026, betriebNamen: const {}),
      );
      expect(v.total.anzahl, 0);
      expect(v.jahrgaenge, isEmpty);
      expect(v.saetze, isEmpty);
      expect(v.auswahl.leer, isTrue);
    });
  });

  test('Buchungstext entspricht dem der SQL-Funktion (Migration 194)', () {
    expect(
      debitorenverlustText(
        nummer: '011_2020_05_02_0042',
        betrieb: 'Helvetia',
        jahrgang: 2020,
      ),
      'Debitorenverlust 011_2020_05_02_0042 Helvetia '
      '(Abschreibung Jahrgang 2020, verjährt Art. 128 OR)',
    );
  });
}
