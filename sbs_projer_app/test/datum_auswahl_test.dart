import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';

void main() {
  test('DatumFeld.text formatiert oder zeigt Gedankenstrich', () {
    expect(DatumFeld.text(null), '—');
    expect(DatumFeld.text(DateTime(2026, 9, 6)), '06.09.2026');
  });

  testWidgets('zeigeDatumsauswahl klemmt initial in die Grenzen und öffnet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => zeigeDatumsauswahl(
              context,
              initial: DateTime(2010),
              erstes: DateTime(2019),
              letztes: DateTime(2030),
            ),
            child: const Text('öffnen'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
