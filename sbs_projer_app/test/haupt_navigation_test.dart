import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/presentation/widgets/haupt_navigation.dart';

Widget rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: Column(children: [const Spacer(), kind])),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt alle vier Ziele', (tester) async {
    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.heute, onZiel: (_) {})),
    );
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('das aktive Ziel ist gruen, die uebrigen grau', (tester) async {
    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.betriebe, onZiel: (_) {})),
    );
    final aktiv = tester.widget<Text>(find.text('Betriebe'));
    final andere = tester.widget<Text>(find.text('Heute'));
    expect(aktiv.style?.color, AppColors.primary);
    expect(andere.style?.color, AppColors.textSecondary);
  });

  testWidgets('ohne aktives Ziel ist nichts hervorgehoben', (tester) async {
    await tester.pumpWidget(
      rahmen(const HauptNavigation(aktiv: null, onZiel: _nichts)),
    );
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      expect(
        tester.widget<Text>(find.text(t)).style?.color,
        AppColors.textSecondary,
        reason: t,
      );
    }
  });

  testWidgets('Tippen meldet das Ziel', (tester) async {
    NavZiel? gewaehlt;
    await tester.pumpWidget(
      rahmen(
        HauptNavigation(aktiv: NavZiel.heute, onZiel: (z) => gewaehlt = z),
      ),
    );
    await tester.tap(find.text('Tour'));
    expect(gewaehlt, NavZiel.tour);
    await tester.tap(find.text('Einsätze'));
    expect(gewaehlt, NavZiel.einsaetze);
  });

  testWidgets('passt auf 360 px, keine Beschriftung wird gekuerzt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.einsaetze, onZiel: (_) {})),
    );

    expect(tester.takeException(), isNull);
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });

  testWidgets('kein NavigationBar, kein BottomNavigationBar', (tester) async {
    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.heute, onZiel: (_) {})),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });
}

void _nichts(NavZiel _) {}
