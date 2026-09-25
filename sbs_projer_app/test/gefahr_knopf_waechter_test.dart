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
/// Seit 25.09.2026 (Analyse §3.2, Q1) greift der Wächter breiter, weil 17
/// Stellen durch die alte, enge Fassung gerutscht waren:
/// - auch die `.icon`-/`.tonal`-Varianten (`TextButton.icon(` …),
/// - auch `Colors.red` / `Colors.red.shade*`, nicht nur `AppColors.error`,
/// - und UNGEFÄRBTE Material-Buttons, deren Beschriftung ein Gefahrwort
///   trägt (Löschen, Entfernen, Stornieren, Verwerfen, Zurücknehmen,
///   Rückgängig, Leeren, Trennen, Abschreiben).
/// Kommentare werden vorher ausgeblendet, damit ein Beispiel in einem
/// Doc-Kommentar nicht anschlägt.
void main() {
  test('kein Material-Button fuer eine unumkehrbare Aktion', () {
    final treffer = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      if (_ausgenommen.any(pfad.endsWith)) continue;
      treffer.addAll(gefahrKnopfTreffer(pfad, f.readAsStringSync()));
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Destruktive Aktion als Material-Button. Bitte '
          'TapKnopf(text: …, gefahr: true, onTap: …) nehmen:\n'
          '${treffer.join('\n')}',
    );
  });

  group('Waechter erkennt', () {
    List<String> pruefe(String code) => gefahrKnopfTreffer('x.dart', code);

    test('rote .icon-Variante', () {
      expect(
        pruefe(
          "TextButton.icon(onPressed: f, icon: i, label: const Text('X'), "
          'style: TextButton.styleFrom(foregroundColor: AppColors.error))',
        ),
        hasLength(1),
      );
    });

    test('Colors.red und Colors.red.shade700', () {
      expect(
        pruefe(
          "FilledButton(style: s(backgroundColor: Colors.red), "
          "child: Text('A'))",
        ),
        hasLength(1),
      );
      expect(
        pruefe(
          'OutlinedButton(style: s(foregroundColor: Colors.red.shade700), '
          "child: Text('A'))",
        ),
        hasLength(1),
      );
    });

    test('ungefaerbter Button mit Gefahrwort in der Beschriftung', () {
      for (final wort in [
        'Löschen',
        'Entfernen',
        'Stornieren',
        'Verwerfen',
        'Zurücknehmen',
        'Rückgängig',
        'Leeren',
        'Trennen',
        'Abschreiben',
      ]) {
        expect(
          pruefe("FilledButton(onPressed: f, child: const Text('$wort'))"),
          hasLength(1),
          reason: wort,
        );
      }
    });

    test('harmlose Knoepfe und Kommentare nicht', () {
      expect(
        pruefe("TextButton(onPressed: f, child: const Text('Abbrechen'))"),
        isEmpty,
      );
      expect(
        pruefe(
          "// FilledButton(child: Text('Löschen'))\n"
          "/* TextButton.icon(label: Text('Trennen')) */",
        ),
        isEmpty,
      );
      // Gefahrwort nur in einer Meldung im Handler, nicht in der Beschriftung.
      expect(
        pruefe(
          "TextButton(onPressed: () => zeige('Löschen fehlgeschlagen'), "
          "child: const Text('Nochmals'))",
        ),
        isEmpty,
      );
    });
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

/// Dateien, die bei der Schärfung (25.09.2026) parallel in anderen
/// Arbeitssträngen umgebaut wurden. Ihre Treffer sind bekannt und werden
/// dort nachgezogen — danach den Eintrag hier streichen.
const _ausgenommen = <String>[
  // «Löschen» einer camt-Regel (FilledButton im Dialog)
  'screens/buchhaltung/camt/camt_regeln_tab.dart',
  // «Rückgängig machen» der Zahlung + «Zahlung rückgängig (Bankabgleich)»
  'screens/rechnungen/rechnung_detail_screen.dart',
];

final _knopf = RegExp(
  r'\b(FilledButton|ElevatedButton|OutlinedButton|TextButton)'
  r'(\.icon|\.tonal|\.tonalIcon)?\(',
);
final _rot = RegExp(r'AppColors\.error\b|Colors\.red\b');
final _beschriftung = RegExp(
  r'''(?:child|label)\s*:\s*(?:const\s+)?Text\(\s*(?:'([^']*)'|"([^"]*)")''',
);
final _gefahrwort = RegExp(
  r'l(ö|oe)sch|entfern|stornier|verwerf|zur(ü|ue)cknehm|r(ü|ue)ckg(ä|ae)ngig'
  r'|leeren|trennen|abschreib',
  caseSensitive: false,
);

/// Alle verdächtigen Material-Buttons in [quelle] als `pfad:zeile (Art)`.
List<String> gefahrKnopfTreffer(String pfad, String quelle) {
  final code = _ohneKommentare(quelle);
  final treffer = <String>[];
  for (final m in _knopf.allMatches(code)) {
    final block = _aufrufInhalt(code, m.end);
    final beschriftung = _beschriftung
        .allMatches(block)
        .map((b) => b.group(1) ?? b.group(2) ?? '')
        .join(' ');
    final rot = _rot.hasMatch(block);
    final gefahr = _gefahrwort.hasMatch(beschriftung);
    if (!rot && !gefahr) continue;
    final zeile = '\n'.allMatches(code.substring(0, m.start)).length + 1;
    final grund = [if (rot) 'rot', if (gefahr) '«$beschriftung»'].join(', ');
    treffer.add('$pfad:$zeile (${m.group(1)}${m.group(2) ?? ''}: $grund)');
  }
  return treffer;
}

/// Ersetzt `//`- und `/* */`-Kommentare durch Leerzeichen; Zeilenumbrüche
/// bleiben, damit die Zeilennummern stimmen. Zeichenketten bleiben
/// unangetastet — `'http://…'` ist kein Kommentar.
String _ohneKommentare(String q) {
  final b = StringBuffer();
  var i = 0;
  String? anfuehrung;
  var roh = false; // r'…' kennt kein Escape
  while (i < q.length) {
    final c = q[i];
    final n = i + 1 < q.length ? q[i + 1] : '';
    if (anfuehrung != null) {
      b.write(c);
      if (!roh && c == r'\' && n.isNotEmpty) {
        b.write(n);
        i += 2;
        continue;
      }
      if (c == anfuehrung || c == '\n') anfuehrung = null;
      i++;
    } else if (c == '/' && n == '/') {
      while (i < q.length && q[i] != '\n') {
        b.write(' ');
        i++;
      }
    } else if (c == '/' && n == '*') {
      while (i < q.length &&
          !(q[i] == '*' && i + 1 < q.length && q[i + 1] == '/')) {
        b.write(q[i] == '\n' ? '\n' : ' ');
        i++;
      }
      b.write('  ');
      i += 2;
    } else {
      if (c == "'" || c == '"') {
        anfuehrung = c;
        roh = i > 0 && q[i - 1] == 'r';
      }
      b.write(c);
      i++;
    }
  }
  return b.toString();
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
