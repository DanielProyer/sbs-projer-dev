import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/pdf_oeffnen.dart';

/// K6 (Review 27.09.2026): Blockiert der Browser das PDF-Fenster, steht eine
/// SnackBar mit «Herunterladen» da — nie Stille. (Den Download selbst prüft
/// der Wächter in test/pdf_tab_vorbereiten_waechter_test.dart; hier würde er
/// ins echte Dateisystem schreiben.)
void main() {
  testWidgets('blockiert: SnackBar mit «Herunterladen»', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    pdfBlockiertMelden(
      ScaffoldMessenger.of(ctx),
      Uint8List.fromList([1, 2, 3]),
      'Mahnung.pdf',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Browser hat das Fenster blockiert — Download'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SnackBarAction, 'Herunterladen'), findsOneWidget);
  });

  testWidgets('ohne Messenger kein Absturz', (tester) async {
    pdfBlockiertMelden(null, Uint8List(0), 'x.pdf');
  });
}
