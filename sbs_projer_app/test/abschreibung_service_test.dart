import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

void main() {
  test('Split 8.1%: netto+mwst = brutto', () {
    final s = AbschreibungService.split(108.10, 8.1);
    expect(s.netto, 100.00);
    expect(s.mwst, 8.10);
  });
  test('Split 7.7%', () {
    final s = AbschreibungService.split(107.70, 7.7);
    expect(s.netto, 100.00);
    expect(s.mwst, 7.70);
  });
  test('Split ohne MWST (Satz 0)', () {
    final s = AbschreibungService.split(50.0, 0);
    expect(s.netto, 50.0);
    expect(s.mwst, 0.0);
  });
  test('mwst = brutto - netto (Residuum)', () {
    final s = AbschreibungService.split(94.05, 8.1);
    expect((s.netto + s.mwst - 94.05).abs() < 0.005, isTrue);
  });
}
