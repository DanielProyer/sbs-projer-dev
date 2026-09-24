import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahn_hinweis.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/mahn_hinweis_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/mahn_hinweis_band.dart';

Rechnung _r() => Rechnung.fromJson({
      'id': 'r1',
      'user_id': 'u',
      'rechnungsnummer': '2026-05-0001',
      'rechnungstyp': 'kundenrechnung',
      'betrieb_id': 'b1',
      'rechnungsdatum': '2026-05-01',
      'faelligkeitsdatum': '2026-05-31',
      'betrag_netto': 87.0,
      'mwst_betrag': 7.05,
      'betrag_brutto': 94.05,
      'zahlungsstatus': 'mahnung_1',
      'mahnung_1_am': '2026-07-20',
      'mahnung_stufe': 2,
    });

Future<void> _pump(WidgetTester tester, MahnHinweis h, {String? betriebId = 'b1'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mahnHinweisProvider.overrideWith((ref, id) async => h),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MahnHinweisBand(betriebId: betriebId),
              const Text('Formular'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final gemahnt = mahnHinweis(rechnungen: [_r()], imMahnfall: const {});
  const keine = MahnHinweis(
    stufe: MahnHinweisStufe.keine,
    offene: [],
    anzahlGemahnt: 0,
    summeOffen: 0,
  );

  testWidgets('gemahnt: Band mit Text, Antippen zeigt Sheet', (tester) async {
    await _pump(tester, gemahnt);
    expect(
      find.text('1 Rechnung gemahnt, CHF 94.05 offen (1. Mahnung vom 20.07.2026)'),
      findsOneWidget,
    );
    await tester.tap(find.byType(MahnHinweisBand));
    await tester.pumpAndSettle();
    expect(find.text('Offene Rechnungen'), findsOneWidget);
    expect(find.text('2026-05-0001'), findsOneWidget);
    expect(find.text('QR zeigen'), findsOneWidget);
    expect(find.textContaining('Bar einkassieren — CHF 94.05'), findsOneWidget);
  });

  testWidgets('keine: nichts gerendert', (tester) async {
    await _pump(tester, keine);
    expect(find.textContaining('gemahnt'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Formular'), findsOneWidget);
  });

  testWidgets('ohne Betrieb: nichts gerendert', (tester) async {
    await _pump(tester, gemahnt, betriebId: null);
    expect(find.textContaining('gemahnt'), findsNothing);
  });
}
