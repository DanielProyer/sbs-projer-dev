import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_reiter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<String>> pump(
    WidgetTester tester,
    List<BereichReiterEintrag> reiter,
    String aktiv,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gewaehlt = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('X'),
            bottom: BereichReiter(
              reiter: reiter,
              aktiverPfad: aktiv,
              onWechsel: gewaehlt.add,
            ),
          ),
        ),
      ),
    );
    return gewaehlt;
  }

  testWidgets('aktiver Reiter gruen, andere grau', (tester) async {
    await pump(tester, kReiterBetriebe, '/kontakte');
    expect(
      tester.widget<Text>(find.text('Personen')).style?.color,
      AppColors.primary,
    );
    expect(
      tester.widget<Text>(find.text('Betriebe')).style?.color,
      AppColors.textSecondary,
    );
  });

  testWidgets('Tippen wechselt, der aktive meldet nichts', (tester) async {
    final gewaehlt = await pump(tester, kReiterBetriebe, '/betriebe');
    await tester.tap(find.text('Betriebe'));
    await tester.tap(find.text('Personen'));
    expect(gewaehlt, ['/kontakte']);
  });

  testWidgets('vier Reiter passen auf 360 px', (tester) async {
    await pump(tester, const [
      BereichReiterEintrag('Kunden', '/rechnungen'),
      BereichReiterEintrag('Heineken', '/heineken'),
      BereichReiterEintrag('Pro Betrieb', '/rechnungen/pro-betrieb'),
      BereichReiterEintrag('Jährlich', '/jahresrechnung'),
    ], '/rechnungen');
    expect(tester.takeException(), isNull);
    for (final t in ['Kunden', 'Heineken', 'Pro Betrieb', 'Jährlich']) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });
}
