import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';

/// `AbschreibungLauf` seit Migration 215: die Sammelbuchungen der
/// MWST-Rückholung (`buchung_mwst_ids`) und die Unterscheidung zwischen dem
/// Muster vor 215 (je Rechnung netto + MWST per 31.12.) und dem 2019-Muster
/// (brutto per 31.12., Rückholung am Entscheidtag).
///
/// WARUM `fromJson` ohne die Spalte nicht brechen darf: Die App kann vor der
/// Migration ausgeliefert werden — dann fehlt `buchung_mwst_ids` in der
/// Antwort, und der Screen «Jahrgang abschreiben» muss trotzdem laden.
Map<String, dynamic> _json({
  Object? mwstIds = const ['m1'],
  bool mitIds = true,
  int geschaeftsjahr = 2025,
  int mwstJahr = 2026,
  int mwstQuartal = 4,
  bool ruecknahme = true,
  String mwst = '516.43',
}) => {
  'id': 'l2',
  'geschaeftsjahr': geschaeftsjahr,
  'jahrgaenge': [2020],
  'buchungsdatum': '$geschaeftsjahr-12-31',
  'mwst_jahr': mwstJahr,
  'mwst_quartal': mwstQuartal,
  'anzahl': 76,
  'netto': '6699.87',
  'mwst': mwst,
  'brutto': '7216.30',
  'status': 'gebucht',
  'ruecknahme_moeglich': ruecknahme,
  'created_at': '2026-10-01T09:00:00+00:00',
  if (mitIds) 'buchung_mwst_ids': mwstIds,
};

void main() {
  group('fromJson', () {
    test('liest die Sammelbuchungen der MWST-Rückholung', () {
      final l = AbschreibungLauf.fromJson(_json(mwstIds: ['m1', 'm2']));
      expect(l.buchungMwstIds, ['m1', 'm2']);
    });

    test('ohne Spalte (215 noch nicht angewendet) → leer, kein Absturz', () {
      final l = AbschreibungLauf.fromJson(_json(mitIds: false));
      expect(l.buchungMwstIds, isEmpty);
      expect(l.anzahl, 76);
    });

    test('Spalte null → leer', () {
      expect(AbschreibungLauf.fromJson(_json(mwstIds: null)).buchungMwstIds,
          isEmpty);
    });

    test('Konstruktor ohne Ids → leer (bestehende Aufrufer)', () {
      final l = AbschreibungLauf(
        id: 'x',
        geschaeftsjahr: 2026,
        jahrgaenge: const [2021],
        buchungsdatum: DateTime(2026, 12, 31),
        mwstJahr: 2027,
        mwstQuartal: 1,
        anzahl: 1,
        netto: 100,
        mwst: 7.7,
        brutto: 107.7,
        status: 'gebucht',
        ruecknahmeMoeglich: true,
      );
      expect(l.buchungMwstIds, isEmpty);
    });
  });

  group('Buchungsmuster', () {
    test('seit 215: Sammelbuchung vorhanden → Rückholung am Entscheidtag', () {
      final l = AbschreibungLauf.fromJson(_json());
      expect(l.rueckholungJeRechnung, isFalse);
      expect(l.buchungenPer31Dez, 76);
    });

    test('vor 215 (App): Q4 des Geschäftsjahrs, je Rechnung zwei Buchungen',
        () {
      final l = AbschreibungLauf.fromJson(
        _json(mitIds: false, geschaeftsjahr: 2026, mwstJahr: 2026),
      );
      expect(l.rueckholungJeRechnung, isTrue);
      expect(l.buchungenPer31Dez, 152);
    });

    test('2019er per SQL (brutto, Rückholung Q3/2026) → 2019-Muster', () {
      final l = AbschreibungLauf.fromJson(
        _json(mitIds: false, mwstQuartal: 3, ruecknahme: false),
      );
      expect(l.rueckholungJeRechnung, isFalse);
    });

    test('seit 215, im laufenden Jahr gebucht (Q4 = Geschäftsjahr) → '
        'trotzdem 2019-Muster, weil die Sammelbuchung da ist', () {
      final l = AbschreibungLauf.fromJson(
        _json(geschaeftsjahr: 2026, mwstJahr: 2026),
      );
      expect(l.rueckholungJeRechnung, isFalse);
    });

    test('ohne MWST gibt es nichts zurückzuholen → eine Buchung je Rechnung',
        () {
      final l = AbschreibungLauf.fromJson(
        _json(mitIds: false, geschaeftsjahr: 2026, mwstJahr: 2026, mwst: '0'),
      );
      expect(l.buchungenPer31Dez, 76);
    });
  });
}
