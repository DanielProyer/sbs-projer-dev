import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';

void main() {
  final basis = Steuerjahr(
    id: 's1',
    jahr: 2024,
    status: 'veranlagt',
    veranlagtAm: DateTime(2026, 5, 12),
    steuerbarerGewinn: 42000,
    bundProvisorisch: 1200.50,
    bundDefinitiv: 1180.35,
    kantonDefinitiv: 3400,
    notizen: 'Einsprache erledigt',
  );

  test('copyWith ohne Argumente ergibt gleiche Werte', () {
    final k = basis.copyWith();
    expect(k.id, basis.id);
    expect(k.jahr, basis.jahr);
    expect(k.status, basis.status);
    expect(k.veranlagtAm, basis.veranlagtAm);
    expect(k.steuerbarerGewinn, basis.steuerbarerGewinn);
    expect(k.bundProvisorisch, basis.bundProvisorisch);
    expect(k.bundDefinitiv, basis.bundDefinitiv);
    expect(k.kantonDefinitiv, basis.kantonDefinitiv);
    expect(k.notizen, basis.notizen);
  });

  test('copyWith setzt nullbare Felder wirklich auf null', () {
    final k = basis.copyWith(bundDefinitiv: null);
    expect(k.bundDefinitiv, isNull);
    // Die übrigen Felder bleiben unangetastet.
    expect(k.bundProvisorisch, 1200.50);
    expect(k.kantonDefinitiv, 3400);
    expect(k.notizen, 'Einsprache erledigt');
  });

  test('copyWith ändert einzelne Werte', () {
    final k = basis.copyWith(status: 'ermessen', jahr: 2025);
    expect(k.status, 'ermessen');
    expect(k.jahr, 2025);
    expect(k.id, 's1');
  });

  test('toJson enthält weder id noch user_id', () {
    final j = basis.toJson();
    expect(j.containsKey('id'), isFalse);
    expect(j.containsKey('user_id'), isFalse);
    expect(j['jahr'], 2024);
    expect(j['status'], 'veranlagt');
    expect(j['veranlagt_am'], '2026-05-12');
  });
}
