import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Unumkehrbare Bestätigungen laufen über `TapKnopf(gefahr: true)`,
/// nie über einen Material-Button (B7, v0.114.0).
///
/// WARUM: Auf CanvasKit-Web rendern Material-Buttons nicht zuverlässig —
/// bestätigt am 20.06.2026 (camt-Bestätigen unsichtbar) und am 13.08.2026
/// (Lageplan-Speichern ohne Klick-Reaktion). CLAUDE.md verlangt für kritische
/// Aktionen deshalb `GestureDetector`/`InkWell` + `Container`.
///
/// Diese Regel stand bisher nur als Text da. Bei einem Speichern-Knopf merkt
/// man den Ausfall sofort; bei einer Löschbestätigung steht man vor einem
/// Dialog, der sich scheinbar nicht bedienen lässt — und im schlimmsten Fall
/// tippt man daneben. 26 solche Knöpfe in 18 Dateien wurden umgestellt.
///
/// Der Wächter greift eng: nur Material-Buttons, die sich über
/// `AppColors.error` selbst als destruktiv ausweisen. Die übrigen rund 180
/// `FilledButton` im Bestand bleiben unangetastet — sie sind nicht das
/// Problem, das hier gelöst wird.
void main() {
  test('kein Material-Button in Rot fuer eine unumkehrbare Aktion', () {
    final treffer = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      final quelle = f.readAsStringSync();

      for (final m in RegExp(
        r'(FilledButton|ElevatedButton|OutlinedButton|TextButton)\(',
      ).allMatches(quelle)) {
        final block = _aufrufInhalt(quelle, m.end);
        if (!block.contains('AppColors.error')) continue;
        final zeile = '\n'.allMatches(quelle.substring(0, m.start)).length + 1;
        treffer.add('$pfad:$zeile (${m.group(1)})');
      }
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Destruktive Bestaetigung als Material-Button. Bitte '
          'TapKnopf(text: …, gefahr: true, onTap: …) nehmen:\n'
          '${treffer.join('\n')}',
    );
  });

  testWidgets('gefahr: true faerbt rot und bleibt bedienbar', (tester) async {
    var getippt = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TapKnopf(text: 'Löschen', gefahr: true, onTap: () => getippt++),
        ),
      ),
    );

    final kasten = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TapKnopf),
            matching: find.byType(Container),
          )
          .first,
    );
    final deko = kasten.decoration as BoxDecoration;
    expect(deko.color, AppColors.error);

    await tester.tap(find.byType(TapKnopf));
    expect(getippt, 1, reason: 'der Knopf muss auch wirklich ausloesen');
  });

  testWidgets('gesperrt wird grau und loest nicht aus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: TapKnopf(text: 'Löschen', gefahr: true, onTap: null),
        ),
      ),
    );

    final kasten = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TapKnopf),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((kasten.decoration as BoxDecoration).color, isNot(AppColors.error));
  });

  testWidgets('bricht auf 360 px bei 130 % Schrift nicht um den Text ab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        // Wie im echten Fall: als `actions` eines Dialogs. Die OverflowBar
        // dort bricht bei Platzmangel selbst um — eine nackte Row täte das
        // nicht und würde etwas prüfen, das es so nirgends gibt.
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AlertDialog(
              title: const Text('Eintrag löschen?'),
              content: const Text('Das lässt sich nicht rückgängig machen.'),
              actions: [
                TapKnopf(text: 'Abbrechen', primaer: false, onTap: () {}),
                TapKnopf(text: 'Rückgängig', gefahr: true, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

/// Der Inhalt eines Aufrufs ab der oeffnenden Klammer bis zur passenden
/// schliessenden; Klammern in Zeichenketten zaehlen nicht mit.
String _aufrufInhalt(String quelle, int ab) {
  var tiefe = 1;
  var i = ab;
  String? anfuehrung;
  while (i < quelle.length && tiefe > 0) {
    final c = quelle[i];
    if (anfuehrung != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == anfuehrung) anfuehrung = null;
    } else if (c == "'" || c == '"') {
      anfuehrung = c;
    } else if (c == '(') {
      tiefe++;
    } else if (c == ')') {
      tiefe--;
    }
    i++;
  }
  return quelle.substring(ab, i);
}
