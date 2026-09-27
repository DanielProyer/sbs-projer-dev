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

  testWidgets('zeigt alle fuenf Ziele', (tester) async {
    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.heute, onZiel: (_) {})),
    );
    for (final t in ['Heute', 'Betriebe', 'Material', 'Tour', 'Mehr']) {
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
    for (final t in ['Heute', 'Betriebe', 'Material', 'Tour', 'Mehr']) {
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
    await tester.tap(find.text('Material'));
    expect(gewaehlt, NavZiel.material);
    await tester.tap(find.text('Mehr'));
    expect(gewaehlt, NavZiel.mehr);
  });

  testWidgets('passt auf 360 px, keine Beschriftung wird gekuerzt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      rahmen(HauptNavigation(aktiv: NavZiel.material, onZiel: (_) {})),
    );

    expect(tester.takeException(), isNull);
    for (final t in ['Heute', 'Betriebe', 'Material', 'Tour', 'Mehr']) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });

  group('Zaehler-Badge am Material-Reiter (27.09.2026)', () {
    testWidgets('0 niedrig: kein Badge', (tester) async {
      await tester.pumpWidget(
        rahmen(
          HauptNavigation(
            aktiv: NavZiel.heute,
            onZiel: _nichts,
            zaehler: const {NavZiel.material: 0},
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
      // Ohne Angabe ebenso.
      await tester.pumpWidget(
        rahmen(const HauptNavigation(aktiv: NavZiel.heute, onZiel: _nichts)),
      );
      expect(find.textContaining(RegExp(r'^\d+$')), findsNothing);
    });

    testWidgets('3 niedrig: «3» rot am Material-Symbol', (tester) async {
      await tester.pumpWidget(
        rahmen(
          HauptNavigation(
            aktiv: NavZiel.heute,
            onZiel: _nichts,
            zaehler: const {NavZiel.material: 3},
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      // Sitzt am Material-Reiter, nicht an einem anderen.
      final symbol = tester.getRect(find.byIcon(navIcon(NavZiel.material)));
      final badge = tester.getRect(find.text('3'));
      expect(badge.left, greaterThan(symbol.center.dx));
      expect(badge.bottom, lessThan(symbol.bottom));
      // Stil der Glocke: roter Kreis, weisse Zahl.
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('3'), matching: find.byType(Container)).first,
      );
      expect((box.decoration! as BoxDecoration).color, AppColors.error);
      expect(tester.widget<Text>(find.text('3')).style?.color, Colors.white);
    });

    testWidgets('Tippen auf das Symbol mit Badge meldet weiter Material', (
      tester,
    ) async {
      NavZiel? gewaehlt;
      await tester.pumpWidget(
        rahmen(
          HauptNavigation(
            aktiv: NavZiel.heute,
            onZiel: (z) => gewaehlt = z,
            zaehler: const {NavZiel.material: 3},
          ),
        ),
      );
      await tester.tap(find.text('3'));
      expect(gewaehlt, NavZiel.material);
    });

    testWidgets('mit zweistelligem Badge auf 360 px kein Ueberlauf', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        rahmen(
          HauptNavigation(
            aktiv: NavZiel.material,
            onZiel: _nichts,
            zaehler: const {NavZiel.material: 12},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('12'), findsOneWidget);
    });
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
