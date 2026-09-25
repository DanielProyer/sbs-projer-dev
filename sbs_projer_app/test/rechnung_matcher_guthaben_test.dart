import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';

Rechnung _rg(String id, double brutto, {double guthaben = 0}) => Rechnung(
    id: id, userId: 'u', rechnungstyp: 'kundenrechnung', betriebId: 'b1',
    rechnungsdatum: DateTime(2026, 11, 1), faelligkeitsdatum: DateTime(2026, 11, 30),
    betragBrutto: brutto, zahlungsstatus: 'offen', guthabenVerrechnet: guthaben);

void main() {
  test('Zahlung = zu zahlen (nach Guthaben) → eindeutig', () {
    final m = RechnungMatcher.match(
        zahlbetrag: 113.75, offeneRechnungen: [_rg('a', 143.75, guthaben: 30)]);
    expect(m.eindeutig, isTrue);
    expect(m.rechnungen.single.id, 'a');
  });
  test('Brutto trotz Guthaben → kein Auto-Treffer (manuell)', () {
    final m = RechnungMatcher.match(
        zahlbetrag: 143.75, offeneRechnungen: [_rg('a', 143.75, guthaben: 30)]);
    expect(m.eindeutig, isFalse);
  });
  test('ganz durch Guthaben gedeckte Rechnung zählt nicht mit', () {
    final m = RechnungMatcher.match(
        zahlbetrag: 100, offeneRechnungen: [_rg('a', 20, guthaben: 20), _rg('b', 100)]);
    expect(m.eindeutig, isTrue);
    expect(m.rechnungen.map((r) => r.id), ['b']);
  });
}
