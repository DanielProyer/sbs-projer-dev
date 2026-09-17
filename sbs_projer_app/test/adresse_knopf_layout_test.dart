import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Der Knopf «Adresse und Mail aus den Betriebsdaten» steht im
/// Rechnungsadress-Formular unter der Überschrift «Adresse» — als eigene
/// Zeile, nicht daneben.
///
/// WARUM als Test: Neben der Überschrift lief die Zeile auf 360 px bei 130 %
/// Systemschrift um **44 px** über. Derselbe Fall wie im Dialog am
/// 08.09.2026, wo mit der echten Schrift alles passte und mit vergrösserter
/// nicht. Wer den Knopf zurück in eine Row neben den Titel setzt, bricht
/// diesen Test.
Widget _block() => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Builder(
          builder: (c) => Text(
            'Adresse',
            style: Theme.of(
              c,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TapKnopf(
            text: 'Adresse und Mail aus den Betriebsdaten',
            icon: Icons.download,
            primaer: false,
            onTap: () {},
          ),
        ),
      ],
    ),
  ),
);

Future<void> _pruefe(WidgetTester tester, double schrift) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(schrift)),
      child: _block(),
    ),
  );
  await tester.pumpAndSettle();

  expect(
    tester.takeException(),
    isNull,
    reason: 'Ueberlauf bei ${(schrift * 100).round()} % Schrift',
  );
  expect(find.text('Adresse'), findsOneWidget);
  expect(find.text('Adresse und Mail aus den Betriebsdaten'), findsOneWidget);
}

void main() {
  testWidgets('360 px, normale Schrift', (t) => _pruefe(t, 1.0));
  testWidgets('360 px, 130 % Schrift', (t) => _pruefe(t, 1.3));
  testWidgets('360 px, 170 % Schrift', (t) => _pruefe(t, 1.7));
}
