import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wohin führt «Zurück»? `null` = eine Seite zurück (pop), sonst die
/// Rückfall-Route [fallback].
///
/// WARUM: Ein direkt per URL/Link geöffneter Screen (Aufgabe, Kalender,
/// Reload) hat nichts zum Zurückgehen — die AppBar zeigte dann gar keinen
/// Pfeil, und ein `context.pop()` lief ins Leere (Runde 5, 26.09.2026).
String? rueckwegZiel(bool canPop, String fallback) => canPop ? null : fallback;

/// Eine Seite zurück — oder auf [fallback], wenn der Screen direkt geöffnet
/// wurde. Auch für programmatisches Verlassen (z. B. nach dem Löschen).
void zurueckOderZu(BuildContext context, String fallback) {
  final ziel = rueckwegZiel(context.canPop(), fallback);
  if (ziel == null) {
    context.pop();
  } else {
    context.go(ziel);
  }
}

/// Zurück-Pfeil für `AppBar.leading`, der immer erscheint — auch wenn der
/// Screen direkt per URL geöffnet wurde (dann führt er auf [fallback]).
///
/// Aus GestureDetector + Icon statt IconButton: Material-Knöpfe rendern auf
/// CanvasKit-Web nicht zuverlässig (CLAUDE.md).
class RueckwegKnopf extends StatelessWidget {
  /// Route, auf die der Pfeil führt, wenn es nichts zum Zurückgehen gibt.
  final String fallback;

  const RueckwegKnopf({super.key, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Zurück',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => zurueckOderZu(context, fallback),
          // 48 px Tippziel wie ein AppBar-Standardpfeil; Farbe kommt aus dem
          // IconTheme der AppBar.
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(Icons.arrow_back)),
          ),
        ),
      ),
    );
  }
}
