import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb_ferien_liste.dart';

void main() {
  test('quelleLabel', () {
    expect(quelleLabel('kunde'), 'Kunde');
    expect(quelleLabel('vor_ort'), 'vor Ort');
    expect(quelleLabel('website'), 'Website');
    expect(quelleLabel('google'), 'Google');
    expect(quelleLabel('import'), 'Altbestand');
    expect(quelleLabel('x'), 'x');
  });
  test('periodeText: gleiches Jahr kurz, sonst mit Jahr', () {
    expect(periodeText(DateTime(2026, 10, 11), DateTime(2026, 11, 4)), '11.10. – 04.11.2026');
    expect(periodeText(DateTime(2026, 12, 20), DateTime(2027, 1, 5)), '20.12.2026 – 05.01.2027');
  });
  test('periodenSortiert: kuenftige zuerst aufsteigend, vergangene danach absteigend', () {
    final heute = DateTime(2026, 9, 26);
    final p = [
      (von: DateTime(2026, 1, 1), bis: DateTime(2026, 1, 10)),
      (von: DateTime(2026, 12, 1), bis: DateTime(2026, 12, 26)),
      (von: DateTime(2026, 10, 11), bis: DateTime(2026, 11, 4)),
      (von: DateTime(2025, 12, 20), bis: DateTime(2026, 1, 5)),
    ];
    final s = periodenSortiert(p, heute: heute);
    expect(s.map((e) => e.von.month).toList(), [10, 12, 1, 12]);
  });
}
