import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/lokalisierung.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';

/// Die App spricht in ALLEN Material-Texten Deutsch (Schweiz).
///
/// WARUM als Wächter: `MaterialApp.router` in `lib/app.dart` hatte bis
/// 26.09.2026 weder `localizationsDelegates` noch `locale`. Die
/// Datumsauswahl zeigte deshalb «Tue, Nov 17» und «Cancel/OK» — obwohl
/// `main.dart` `initializeDateFormatting('de_CH')` aufruft. Das eine lädt nur
/// die Datumsformate für `intl`, das andere stellt die Material-Texte um.
///
/// Die Konfiguration steht seit 26.09.2026 als Konstanten in
/// `lib/core/config/lokalisierung.dart`; `app.dart` und dieser Test nutzen
/// dieselben Werte — der Widget-Test prüft also die echte Konfiguration,
/// keine Kopie.
void main() {
  test('die Konstanten enthalten die drei Global-Delegates und de_CH', () {
    expect(
      kLokalisierungDelegates,
      contains(GlobalMaterialLocalizations.delegate),
    );
    expect(
      kLokalisierungDelegates,
      contains(GlobalWidgetsLocalizations.delegate),
    );
    expect(
      kLokalisierungDelegates,
      contains(GlobalCupertinoLocalizations.delegate),
    );
    expect(kAppLocale, const Locale('de', 'CH'));
    expect(kUnterstuetzteLocales, contains(kAppLocale));
  });

  test('app.dart setzt die Lokalisierung aus den Konstanten', () {
    final code = File('lib/app.dart').readAsStringSync();
    for (final pflicht in const [
      'localizationsDelegates: kLokalisierungDelegates',
      'supportedLocales: kUnterstuetzteLocales',
      'locale: kAppLocale',
    ]) {
      expect(
        code.contains(pflicht),
        isTrue,
        reason:
            '«$pflicht» fehlt in lib/app.dart — ohne die Lokalisierung zeigen '
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
        localizationsDelegates: kLokalisierungDelegates,
        supportedLocales: kUnterstuetzteLocales,
        locale: kAppLocale,
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
