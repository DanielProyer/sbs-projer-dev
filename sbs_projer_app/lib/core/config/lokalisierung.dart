/// Sprache der App: Deutsch (Schweiz) für alle Material-Texte.
///
/// Ohne diese Delegates zeigt die Datumsauswahl «Tue, Nov 17» und
/// «Cancel/OK» — `initializeDateFormatting('de_CH')` in `main.dart` lädt nur
/// die Datumsformate für `intl`, nicht die Material-Texte. Die 24-h-
/// Zeitauswahl erzwingt `zeigeZeitauswahl` weiterhin selbst über MediaQuery.
///
/// Eine Stelle für `lib/app.dart` UND den Wächter
/// `test/lokalisierung_waechter_test.dart` — der Test baut damit die echte
/// Konfiguration statt einer Kopie, die still auseinanderlaufen könnte.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const List<LocalizationsDelegate<dynamic>> kLokalisierungDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> kUnterstuetzteLocales = [Locale('de', 'CH'), Locale('de')];

const Locale kAppLocale = Locale('de', 'CH');
