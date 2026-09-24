import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahn_hinweis.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

String? _t(DateTime? d) => d?.toIso8601String().split('T').first;

Rechnung _r({
  String id = 'r1',
  required DateTime datum,
  String status = 'offen',
  DateTime? mahnung1,
  double brutto = 94.05,
}) =>
    Rechnung.fromJson({
      'id': id,
      'user_id': 'u',
      'rechnungsnummer': 'NR-$id',
      'rechnungstyp': 'kundenrechnung',
      'betrieb_id': 'b1',
      'rechnungsdatum': _t(datum),
      'faelligkeitsdatum': _t(datum.add(const Duration(days: 30))),
      'betrag_netto': brutto / 1.081,
      'mwst_betrag': brutto - brutto / 1.081,
      'betrag_brutto': brutto,
      'zahlungsstatus': status,
      'versandart': 'rechnung_mail',
      'mahnung_1_am': _t(mahnung1),
      'mahnung_stufe': 0,
    });

void main() {
  _abschliessbarTests();
  final d = DateTime.utc;

  test('keine Mahnung -> keine', () {
    final h = mahnHinweis(
      rechnungen: [_r(datum: d(2026, 5, 1))],
      imMahnfall: const {},
    );
    expect(h.stufe, MahnHinweisStufe.keine);
    expect(h.anzahlGemahnt, 0);
    expect(h.offene, hasLength(1));
  });

  test('eine mahnung_1 -> gemahnt, Text Einzahl', () {
    final h = mahnHinweis(
      rechnungen: [
        _r(datum: d(2026, 5, 1), status: 'mahnung_1', mahnung1: d(2026, 7, 20)),
      ],
      imMahnfall: const {},
    );
    expect(h.stufe, MahnHinweisStufe.gemahnt);
    expect(h.ersteMahnungAm, DateTime(2026, 7, 20));
    expect(h.text, '1 Rechnung gemahnt, CHF 94.05 offen (1. Mahnung vom 20.07.2026)');
  });

  test('zwei gemahnt + eine offene: Anzahl 2, Summe aller drei, Plural, frueheste Mahnung', () {
    final h = mahnHinweis(
      rechnungen: [
        _r(id: 'a', datum: d(2026, 6, 1), status: 'mahnung_2', mahnung1: d(2026, 8, 1), brutto: 1000),
        _r(id: 'b', datum: d(2026, 5, 1), status: 'mahnung_1', mahnung1: d(2026, 7, 20)),
        _r(id: 'c', datum: d(2026, 8, 1), status: 'offen', brutto: 100),
      ],
      imMahnfall: const {},
    );
    expect(h.stufe, MahnHinweisStufe.gemahnt);
    expect(h.anzahlGemahnt, 2);
    expect(h.summeOffen, 1194.05);
    expect(h.offene.map((r) => r.id), ['b', 'a', 'c']);
    expect(h.text,
        "2 Rechnungen gemahnt, CHF 1'194.05 offen (1. Mahnung vom 20.07.2026)");
  });

  test('Rechnung im Mahnfall -> mahnfall, nur gegen Barzahlung', () {
    final h = mahnHinweis(
      rechnungen: [
        _r(datum: d(2026, 5, 1), status: 'mahnung_2', mahnung1: d(2026, 7, 20)),
      ],
      imMahnfall: const {'r1'},
    );
    expect(h.stufe, MahnHinweisStufe.mahnfall);
    expect(h.text, endsWith(' — nur gegen Barzahlung'));
  });

  test('Mahnfall-Id einer bezahlten Rechnung zaehlt nicht', () {
    final h = mahnHinweis(
      rechnungen: [_r(datum: d(2026, 5, 1), status: 'bezahlt')],
      imMahnfall: const {'r1'},
    );
    expect(h.stufe, MahnHinweisStufe.keine);
  });

  test('bezahlte und Altlast 2025 zaehlen nicht', () {
    final h = mahnHinweis(
      rechnungen: [
        _r(id: 'alt', datum: d(2025, 11, 1), status: 'mahnung_1', mahnung1: d(2026, 1, 5)),
        _r(id: 'bez', datum: d(2026, 3, 1), status: 'bezahlt', mahnung1: d(2026, 5, 5)),
      ],
      imMahnfall: const {},
    );
    expect(h.stufe, MahnHinweisStufe.keine);
    expect(h.offene, isEmpty);
    expect(h.summeOffen, 0);
  });
}

void _abschliessbarTests() {
  final d = DateTime.utc;
  group('abschliessbareMahnfaelle', () {
    test('Fall, dessen Rechnungen alle bezahlt sind und der eine kassierte enthaelt', () {
      final ids = abschliessbareMahnfaelle(
        faelle: [
          (id: 'f1', rechnungIds: ['a', 'b']),
          (id: 'f2', rechnungIds: ['c']),
          (id: 'f3', rechnungIds: ['x']),
        ],
        rechnungen: [
          _r(id: 'a', datum: d(2026, 5, 1), status: 'bezahlt'),
          _r(id: 'b', datum: d(2026, 5, 2), status: 'bezahlt'),
          _r(id: 'c', datum: d(2026, 5, 3), status: 'mahnung_2'),
          _r(id: 'x', datum: d(2026, 5, 3), status: 'bezahlt'),
        ],
        kassierteIds: {'a', 'c'},
      );
      // f2: c noch offen; f3: nichts kassiert
      expect(ids, ['f1']);
    });
  });
}
