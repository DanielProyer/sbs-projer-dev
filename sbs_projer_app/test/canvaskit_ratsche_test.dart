import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratsche + AppBar-Wächter für die CanvasKit-tote Widget-Familie
/// FilledButton/OutlinedButton (siehe `canvaskit_sichere_widgets_test.dart`
/// für ExpansionTile/ListTile — dort dateilistenbasiert, hier über alle
/// Screens).
///
/// Drei bestätigte Vorfälle: FilledButton/OutlinedButton unsichtbar
/// (20.06.2026, camt-Bestätigen), FilledButton in der AppBar ohne
/// Klick-Reaktion (13.08.2026, Lageplan-Speichern), ExpansionTile mit
/// dense: true unsichtbar (13.08.2026, Stand-Übersicht).
///
/// events/ ist ausgenommen: dort gilt ein eigenes Zielmodell
/// (siehe CLAUDE.md / Memory "Event-Technik: Anstiche & Leitungen") — dieser
/// Wächter greift nicht in fremde Baustellen ein.
final _knopfMuster = RegExp(
  r'\b(FilledButton|OutlinedButton)(\.icon|\.tonal|\.tonalIcon)?\(',
);

const kMaxMaterialKnoepfe = 97; // Stand 26.09.2026 — Ratsche: darf nur sinken; neue Knöpfe sind TapKnopf (CLAUDE.md)

/// Vorbestehende AppBar-actions-Treffer, die noch umgestellt werden müssen.
/// Heute (26.09.2026) leer — jeder neue Eintrag hier ist ein Rückschritt und
/// muss stattdessen in der PR-Diskussion begründet werden.
const Set<String> kAppBarAusnahmen = {};

int _matchendeKlammer(String text, int offenIdx, String offen, String zu) {
  var tiefe = 0;
  for (var i = offenIdx; i < text.length; i++) {
    if (text[i] == offen) {
      tiefe++;
    } else if (text[i] == zu) {
      tiefe--;
      if (tiefe == 0) return i;
    }
  }
  return -1;
}

void main() {
  final dateien = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !f.path.replaceAll('\\', '/').contains(
          'lib/presentation/screens/events/',
        ),
      )
      .toList();

  test(
    'Ratsche: FilledButton/OutlinedButton in lib/ (ausser events/) darf nur sinken',
    () {
      final zaehlerJeDatei = <String, int>{};
      var gesamt = 0;

      for (final f in dateien) {
        final text = f.readAsStringSync();
        final treffer = _knopfMuster.allMatches(text).length;
        if (treffer > 0) {
          zaehlerJeDatei[f.path] = treffer;
          gesamt += treffer;
        }
      }

      expect(
        gesamt,
        lessThanOrEqualTo(kMaxMaterialKnoepfe),
        reason:
            'FilledButton/OutlinedButton-Treffer gestiegen auf $gesamt '
            '(erlaubt: $kMaxMaterialKnoepfe). Neue Knöpfe müssen TapKnopf '
            'sein (CanvasKit rendert FilledButton/OutlinedButton teils nicht '
            'oder reagiert nicht, CLAUDE.md). Zähler je Datei:\n'
            '${zaehlerJeDatei.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
      );
    },
  );

  test('kein FilledButton/OutlinedButton in AppBar.actions', () {
    final verstoesse = <String>[];

    for (final f in dateien) {
      final text = f.readAsStringSync();
      var suchStart = 0;
      while (true) {
        final appBarIdx = text.indexOf('AppBar(', suchStart);
        if (appBarIdx == -1) break;
        final offenerKlammer = appBarIdx + 'AppBar'.length;
        final schliessenderKlammer = _matchendeKlammer(
          text,
          offenerKlammer,
          '(',
          ')',
        );
        if (schliessenderKlammer == -1) {
          suchStart = appBarIdx + 1;
          continue;
        }
        final appBarBody = text.substring(
          offenerKlammer,
          schliessenderKlammer + 1,
        );
        final actionsMatch = RegExp(r'actions\s*:').firstMatch(appBarBody);
        if (actionsMatch != null) {
          final klammerAufIdx = appBarBody.indexOf('[', actionsMatch.end);
          if (klammerAufIdx != -1) {
            final klammerZuIdx = _matchendeKlammer(
              appBarBody,
              klammerAufIdx,
              '[',
              ']',
            );
            if (klammerZuIdx != -1) {
              final actionsText = appBarBody.substring(
                klammerAufIdx,
                klammerZuIdx + 1,
              );
              if (_knopfMuster.hasMatch(actionsText) &&
                  !kAppBarAusnahmen.contains(f.path)) {
                verstoesse.add(f.path);
              }
            }
          }
        }
        suchStart = schliessenderKlammer + 1;
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'FilledButton/OutlinedButton in AppBar.actions gefunden in: '
          '${verstoesse.join(', ')}. Vorfall 13.08.2026 (Lageplan-Speichern): '
          'ein FilledButton in AppBar.actions reagierte auf CanvasKit nicht '
          'auf Klicks. IconButton oder TapKnopf verwenden.',
    );
  });
}
