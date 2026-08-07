import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/paar_badge.dart';

void main() {
  testWidgets('PaarBadge zeigt die Nummer', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PaarBadge(nummer: 3)),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Farben wiederholen sich zyklisch, Paar 1 und 2 unterscheiden sich', () {
    const b1 = PaarBadge(nummer: 1);
    const b2 = PaarBadge(nummer: 2);
    final b9 = PaarBadge(nummer: kPaarFarben.length + 1);
    expect(b1.farbe == b2.farbe, isFalse);
    expect(b9.farbe, b1.farbe); // Zyklus
  });
}
