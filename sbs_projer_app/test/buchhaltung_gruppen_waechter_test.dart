import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jedes Ziel der Büro-Startseite steht in genau einer Gruppe (B3).
///
/// WARUM: Die 13 Ziele lagen auf einer Ebene — Kontenplan neben
/// Bankauszug-Import, Jahresrechnungen neben Lohn (Befund 4 der App-Analyse
/// 09/2026). Seit B3 gibt es «Laufend» und «Abschluss & Berichte». Ein neues
/// Ziel, das jemand einfach ans Ende hängt, landet sonst stumm in der
/// falschen Gruppe.
void main() {
  final quelle = File(
    'lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart',
  ).readAsStringSync();

  const laufend = [
    '/buchhaltung/camt-import',
    '/buchhaltung/eingangsrechnungen',
    '/rechnungen',
    '/heineken',
    '/buchhaltung/lohn',
  ];
  const abschluss = [
    '/buchhaltung/konten',
    '/buchhaltung/buchungen',
    '/buchhaltung/berichte',
    '/buchhaltung/auswertung',
    '/buchhaltung/mwst',
    '/buchhaltung/audit',
    '/buchhaltung/steuern',
    '/jahresrechnung',
  ];

  test('beide Gruppenueberschriften stehen im Screen', () {
    expect(quelle.contains("'Laufend'"), isTrue);
    expect(quelle.contains("'Abschluss & Berichte'"), isTrue);
    expect(
      quelle.contains("'Bereiche'"),
      isFalse,
      reason: 'die alte Sammelueberschrift ist ersetzt',
    );
  });

  test('jedes _NavTile-Ziel gehoert zu genau einer Gruppe', () {
    // Nur die Ziele der Navigations-Kacheln, nicht jeder push im Screen:
    // `_NavTile`-Bloecke tragen ihren push im selben Abschnitt.
    final ziele = <String>[];
    for (final block in _kachelBereich(quelle).split('_NavTile(').skip(1)) {
      final treffer = RegExp(r"context\.push\('([^']+)'\)").firstMatch(block);
      if (treffer != null) ziele.add(treffer.group(1)!);
    }
    expect(ziele, hasLength(13), reason: 'gefunden: $ziele');

    final beide = laufend.toSet().intersection(abschluss.toSet());
    expect(beide, isEmpty, reason: 'in beiden Gruppen: $beide');

    final heimatlos = ziele.where(
      (z) => !laufend.contains(z) && !abschluss.contains(z),
    );
    expect(
      heimatlos,
      isEmpty,
      reason: 'Ziele ohne Gruppe (Liste im Test ergaenzen): $heimatlos',
    );
  });

  test('die Reihenfolge im Screen folgt den Gruppen', () {
    // Ueber die Reihenfolge der Kacheln selbst pruefen, nicht ueber
    // `indexOf` in der ganzen Datei: `/rechnungen` kommt im Screen auch
    // ausserhalb der Kacheln vor, und `indexOf` faende das erste Vorkommen.
    final ziele = <String>[];
    for (final block in _kachelBereich(quelle).split('_NavTile(').skip(1)) {
      final treffer = RegExp(r"context\.push\('([^']+)'\)").firstMatch(block);
      if (treffer != null) ziele.add(treffer.group(1)!);
    }
    expect(ziele.take(laufend.length), orderedEquals(laufend));
    expect(ziele.skip(laufend.length), orderedEquals(abschluss));

    final iLaufend = quelle.indexOf("'Laufend'");
    final iAbschluss = quelle.indexOf("'Abschluss & Berichte'");
    expect(
      iLaufend,
      lessThan(iAbschluss),
      reason: 'Laufend steht vor Abschluss & Berichte',
    );
  });
}

/// Nur der Bereich, in dem die Kacheln stehen: ab der ersten
/// Gruppenüberschrift bis zur ersten Klassendefinition danach.
///
/// WARUM nicht die ganze Datei: Der Screen enthält weitere `context.push`
/// (Buchungsvorschau, Bank-Wächter), und die Klassendefinition
/// `const _NavTile({` sieht beim Teilen aus wie ein Aufruf. Beides zusammen
/// machte den Wächter von der Reihenfolge der Klassen im File abhängig —
/// eine Falle für den Nächsten, der hier aufräumt.
String _kachelBereich(String quelle) {
  final start = quelle.indexOf("'Laufend'");
  if (start == -1) return quelle;
  final ende = quelle.indexOf('\nclass ', start);
  return quelle.substring(start, ende == -1 ? quelle.length : ende);
}
