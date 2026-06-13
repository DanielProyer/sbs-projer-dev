import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart' show KontoInfo;
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';

KontoInfo _k(int nr, String bez, String kat) =>
    KontoInfo(kontonummer: nr, bezeichnung: bez, kategorie: kat);

void main() {
  final konten = [
    _k(8090, 'FEHLER – sollte 8900 (Phase 2)', 'Steuern'),
    _k(8900, 'Direkte Steuern', 'Steuern'),
    _k(1100, 'Debitoren', 'Umlaufvermögen'),
    _k(1020, 'Bankguthaben', 'Umlaufvermögen'),
    _k(2980, 'Jahresgewinn/-verlust', 'Eigenkapital'),
    _k(9000, 'Gewinn-/Verlustübertrag', 'Abschluss'),
  ];

  test('Fehler-Konto mit Saldo wird gelistet', () {
    final b = AuditService.befunde({8090: 1365.15}, konten);
    expect(b.any((x) => x.konto == 8090 && x.kategorie == 'Fehler-Konto'), isTrue);
  });

  test('negativer Saldo auf Aktivkonto (Klasse 1) wird gelistet', () {
    final b = AuditService.befunde({1020: -50.0}, konten);
    expect(b.any((x) => x.konto == 1020 && x.kategorie == 'Negativer Saldo'), isTrue);
  });

  test('negativer Saldo auf 8900 wird gelistet', () {
    final b = AuditService.befunde({8900: -7380.20}, konten);
    expect(b.any((x) => x.konto == 8900 && x.kategorie == 'Negativer Saldo'), isTrue);
  });

  test('Abschluss-Konto mit Restsaldo wird gelistet', () {
    final b = AuditService.befunde({9000: -76289.27, 2980: 100.0}, konten);
    expect(b.where((x) => x.kategorie == 'Abschluss-Rest').length, 2);
  });

  test('hoher Debitorensaldo wird gelistet', () {
    final b = AuditService.befunde({1100: 116255.48}, konten);
    expect(b.any((x) => x.konto == 1100 && x.kategorie == 'Debitoren'), isTrue);
  });

  test('saubere/kleine Salden erzeugen keinen Befund', () {
    final b = AuditService.befunde({1020: 4602.90, 8900: 0.03}, konten);
    expect(b, isEmpty);
  });
}
