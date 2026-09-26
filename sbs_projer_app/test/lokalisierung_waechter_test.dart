import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';

/// Die App spricht in ALLEN Material-Texten Deutsch (Schweiz).
///
/// WARUM als Wächter: `MaterialApp.router` in `lib/app.dart` hatte bis
/// 26.09.2026 weder `localizationsDelegates` noch `locale`. Die
/// Datumsauswahl zeigte deshalb «Tue, Nov 17» und «Cancel/OK» — obwohl
/// `main.dart` `initializeDateFormatting('de_CH')` aufruft. Das eine lädt nur
/// die Datumsformate für `intl`, das andere stellt die Material-Texte um.
void main() {
  test('app.dart setzt die drei Global-Delegates und Locale de_CH', () {
    final code = File('lib/app.dart').readAsStringSync();
    for (final pflicht in const [
      'GlobalMaterialLocalizations.delegate',
      'GlobalWidgetsLocalizations.delegate',
      'GlobalCupertinoLocalizations.delegate',
      "Locale('de', 'CH')",
    ]) {
      expect(
        code.contains(pflicht),
        isTrue,
        reason:
            '$pflicht fehlt in lib/app.dart — ohne die Lokalisierung zeigen '
            'Datumsauswahl und Dialoge wieder englische Texte.',
      );
    }
  });

  test('flutter_localizations steht in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter_localizations:'), isTrue);
  });

  testWidgets('Datumsauswahl zeigt mit de_CH deutsche Knöpfe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'CH'), Locale('de')],
        locale: const Locale('de', 'CH'),
        home: Builder(
          builder: (context) => GestureDetector(
            onTap: () =>
                zeigeDatumsauswahl(context, initial: DateTime(2026, 11, 17)),
            child: const Text('öffnen'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    // Gross-/Kleinschreibung hängt vom Material-Stand ab («ABBRECHEN» vs.
    // «Abbrechen») — geprüft wird nur die Sprache.
    final texte = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .toList();
    expect(texte, contains('abbrechen'));
    expect(texte, isNot(contains('cancel')));
  });
}
