import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_matcher.dart';

KreditorRegel _r({String name = "", String? praefix, String? iban, int konto = 0, int prio = 0}) =>
    KreditorRegel.fromJson({'id': 'x', 'user_id': 'u', 'lieferant_name_pattern': name,
      'referenz_praefix': praefix, 'lieferant_iban': iban, 'aufwandskonto': konto,
      'mwst_pflichtig': true, 'prioritaet': prio, 'ist_aktiv': true});

void main() {
  final regeln = [
    _r(name: 'Heineken', konto: 6301, prio: 10),
    _r(name: 'AXA', praefix: '98', konto: 5720, prio: 20),
    _r(name: 'AXA', praefix: '1537129', konto: 6300, prio: 20),
    _r(name: 'AXA', praefix: '4412738', konto: 5730, prio: 20),
    _r(name: 'Garage', iban: 'CH8830154001085747001', konto: 6250, prio: 10),
  ];
  test('Name ohne Praefix', () {
    expect(matchKreditorRegel(regeln, ausstellerName: 'Heineken Switzerland AG')?.aufwandskonto, 6301);
  });
  test('AXA per Referenz-Praefix disambiguiert', () {
    expect(matchKreditorRegel(regeln, ausstellerName: 'AXA Leben AG', referenz: '98 67910 00000')?.aufwandskonto, 5720);
    expect(matchKreditorRegel(regeln, ausstellerName: 'AXA', referenz: '15 37129 5 0000')?.aufwandskonto, 6300);
    expect(matchKreditorRegel(regeln, ausstellerName: 'AXA', referenz: '44 12738 9 0000')?.aufwandskonto, 5730);
  });
  test('IBAN gewinnt', () {
    expect(matchKreditorRegel(regeln, ausstellerName: 'Irgendwer', iban: 'CH88 3015 4001 0857 4700 1')?.aufwandskonto, 6250);
  });
  test('kein Treffer -> null', () {
    expect(matchKreditorRegel(regeln, ausstellerName: 'Unbekannt GmbH'), isNull);
  });
}
