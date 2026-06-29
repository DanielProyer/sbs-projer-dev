import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_regel_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_bankauszug_screen.dart';

List<Override> _overrides() => [
      camtPrueflisteProvider
          .overrideWith((ref) async => <CamtPrueflisteEintrag>[]),
      camtRegelnProvider.overrideWith((ref) async => <CamtRegel>[]),
      camtDateienProvider.overrideWith((ref) async => <CamtDatei>[]),
      buchungsVorlagenProvider.overrideWithValue(<BuchungsVorlage>[]),
    ];

Future<void> _pump(WidgetTester tester, {int initialTab = 0}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(home: CamtBankauszugScreen(initialTab: initialTab)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zeigt vier Tabs', (tester) async {
    await _pump(tester);
    expect(find.byType(Tab), findsNWidgets(4));
    expect(find.widgetWithText(Tab, 'Import'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Prüfliste'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Regeln'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Dateien'), findsOneWidget);
  });

  testWidgets('FAB erscheint nur im Regeln-Tab', (tester) async {
    await _pump(tester);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Regeln'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Dateien'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('initialTab=2 öffnet den Regeln-Tab (FAB sichtbar)',
      (tester) async {
    await _pump(tester, initialTab: 2);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
