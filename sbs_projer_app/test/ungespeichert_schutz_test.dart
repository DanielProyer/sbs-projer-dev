import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/ungespeichert_schutz.dart';

/// Ein Formular hinter einer Startseite, damit es etwas zum Zurückgehen gibt.
Widget _app({required bool geaendert}) => MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => UngespeichertSchutz(
                  geaendert: geaendert,
                  was: 'Der Kontakt',
                  child: Scaffold(
                    appBar: AppBar(title: const Text('Formular')),
                    body: const SizedBox(),
                  ),
                ),
              ),
            ),
            child: const Text('öffnen'),
          ),
        ),
      ),
    );

Future<void> _oeffnen(WidgetTester tester, {required bool geaendert}) async {
  await tester.pumpWidget(_app(geaendert: geaendert));
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
  expect(find.text('Formular'), findsOneWidget);
}

/// Zurück, wie es Geste, Browser und Titelleisten-Pfeil auslösen.
Future<void> _zurueck(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator));
  await nav.maybePop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ohne Änderungen verlässt Zurück das Formular sofort',
      (tester) async {
    await _oeffnen(tester, geaendert: false);
    await _zurueck(tester);
    expect(find.text('Formular'), findsNothing);
    expect(find.text('Änderungen verwerfen?'), findsNothing);
  });

  testWidgets('mit Änderungen fragt Zurück nach — «Weiter bearbeiten» bleibt',
      (tester) async {
    await _oeffnen(tester, geaendert: true);
    await _zurueck(tester);
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    expect(find.text('Der Kontakt wurde geändert, aber nicht gespeichert.'),
        findsOneWidget);

    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Formular'), findsOneWidget);
    expect(find.text('Änderungen verwerfen?'), findsNothing);
  });

  testWidgets('mit Änderungen verlässt «Verwerfen» das Formular',
      (tester) async {
    await _oeffnen(tester, geaendert: true);
    await _zurueck(tester);
    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    expect(find.text('Formular'), findsNothing);
  });

  testWidgets('die Dialog-Knöpfe sind TapKnopf, keine Material-Buttons',
      (tester) async {
    // FilledButton/OutlinedButton haben auf CanvasKit zweimal nicht reagiert
    // (CLAUDE.md) — ausgerechnet im Dialog, der Daten rettet, wäre das fatal.
    await _oeffnen(tester, geaendert: true);
    await _zurueck(tester);
    expect(find.byType(TapKnopf), findsNWidgets(2));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('Mixin: markieren rebuildet einmal, zurücksetzen hebt auf',
      (tester) async {
    final key = GlobalKey<_ProbeState>();
    await tester.pumpWidget(MaterialApp(home: _Probe(key: key)));
    final s = key.currentState!;
    expect(s.geaendert, isFalse);
    expect(s.builds, 1);

    s.markiereGeaendert();
    await tester.pump();
    expect(s.geaendert, isTrue);
    expect(s.builds, 2);

    // Ein zweites Markieren darf keinen weiteren Rebuild kosten — das
    // passiert bei jedem Tastendruck.
    s.markiereGeaendert();
    await tester.pump();
    expect(s.builds, 2);

    s.geaendertZuruecksetzen();
    await tester.pump();
    expect(s.geaendert, isFalse);
    expect(s.builds, 3);
  });
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with UngespeichertMixin {
  int builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return const SizedBox();
  }
}
