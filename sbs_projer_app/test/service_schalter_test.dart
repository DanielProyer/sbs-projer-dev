import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/service_schalter.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

void main() {
  test('Anlage mit Eissäule und Booster nennt beide Komponenten', () {
    final k = ServiceSchalter.komponenten(booster: true, eissaeule: true);
    expect(k, ['Booster', 'Eissäule']);
  });

  test('Anlage ohne Booster und ohne Eissäule nennt keine Komponente', () {
    final k = ServiceSchalter.komponenten(booster: false, eissaeule: false);
    expect(k, isEmpty);
  });

  test('Beginn-Hinweis nennt beide Komponenten und den Grund', () {
    expect(
      ServiceSchalter.hinweisBeginn(const ['Booster', 'Eissäule']),
      'Booster und Eissäule vor der Reinigung ausschalten — sonst friert '
          'Wasser oder Lauge in der Leitung.',
    );
  });

  test('Beginn-Hinweis bleibt im Singular, wenn nur eine Komponente da ist', () {
    expect(
      ServiceSchalter.hinweisBeginn(const ['Eissäule']),
      'Eissäule vor der Reinigung ausschalten — sonst friert Wasser oder '
          'Lauge in der Leitung.',
    );
  });

  test('Ende-Hinweis erinnert ans Wiedereinschalten', () {
    expect(
      ServiceSchalter.hinweisEnde(const ['Booster', 'Eissäule']),
      'Booster und Eissäule wieder einschalten.',
    );
  });

  test('Ohne betroffene Komponente gibt es keinen Hinweis', () {
    expect(ServiceSchalter.hinweisBeginn(const []), isNull);
    expect(ServiceSchalter.hinweisEnde(const []), isNull);
  });

  test('Bei mehreren Anlagen zählt jede Komponente nur einmal', () {
    // Eine Reinigung kann mehrere Anlagen umfassen. Trägt die eine einen
    // Booster und die andere eine Eissäule, müssen beide im Hinweis stehen —
    // und der Booster nicht doppelt, wenn ihn zwei Anlagen haben.
    final a1 = AnlageLocal()
      ..booster = true
      ..eissaeule = false;
    final a2 = AnlageLocal()
      ..booster = true
      ..eissaeule = true;

    expect(
      ServiceSchalter.komponentenAusAnlagen([a1, a2]),
      ['Booster', 'Eissäule'],
    );
  });

  test('Anlagen ohne Booster und Eissäule ergeben keine Komponente', () {
    final a = AnlageLocal();
    expect(ServiceSchalter.komponentenAusAnlagen([a]), isEmpty);
  });
}
