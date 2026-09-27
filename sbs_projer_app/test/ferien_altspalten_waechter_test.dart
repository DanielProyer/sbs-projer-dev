import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter: Die Ferien-Altspalten auf `betriebe` liest niemand mehr.
///
/// Hintergrund (27.09.2026): Die Tabelle `betrieb_ferien` ist seit 26.09.2026
/// vollständig, `ferienSlots()` fällt nicht mehr auf die fünf Spaltenpaare
/// `ferien*_start/ende` zurück. Nach einer Woche Beobachtung werden die
/// Spalten entfernt (DROP) — jeder Leser, der bis dahin wieder
/// dazukommt, hätte danach still «keine Ferien» und Daniel führe zu einem
/// geschlossenen Betrieb. Deshalb dürfen die Felder nur noch in der
/// Datenschicht stehen, die sie bis zum DROP mappt: `data/local/` (Isar-Model
/// + Web-Stub), `data/mappers/`, `data/models/`.
void main() {
  /// Die fünf Altspalten-Paare + die nie mehr gesetzte Ferienfrage-Ruhe.
  const verboten = [
    'ferienStart',
    'ferienEnde',
    'ferien2Start',
    'ferien2Ende',
    'ferien3Start',
    'ferien3Ende',
    'ferien4Start',
    'ferien4Ende',
    'ferien5Start',
    'ferien5Ende',
    'ferienFrageRuhtBis',
  ];

  /// `ferienBestaetigtAm` ist KEINE Altspalte (Pflegefeld aus Migration 160,
  /// weiter in Gebrauch): «War geschlossen» setzt es, der Vorjahres-Hinweis
  /// liest es. Erlaubt nur an diesen bekannten Stellen — jede neue Stelle
  /// soll bewusst entschieden werden, nicht einfach dazukommen.
  const bestaetigtErlaubt = {
    'lib/core/util/ferien_vorjahr.dart',
    'lib/presentation/widgets/war_geschlossen_sheet.dart',
  };

  const datenschicht = [
    'lib/data/local/',
    'lib/data/mappers/',
    'lib/data/models/',
  ];

  String norm(String p) => p.replaceAll('\\', '/');

  /// Quelltext ohne reine Kommentarzeilen — ein Hinweis im Kommentar liest
  /// keine Spalte.
  String ohneKommentare(String s) => s
      .split('\n')
      .where((z) => !z.trimLeft().startsWith('//'))
      .join('\n');

  List<File> dartDateien() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  test('Altspalten ferien*_start/ende nur noch in der Datenschicht', () {
    final muster = RegExp('\\b(${verboten.join('|')})\\b');
    final funde = <String>[];
    for (final f in dartDateien()) {
      final pfad = norm(f.path);
      if (datenschicht.any(pfad.startsWith)) continue;
      final zeilen = ohneKommentare(f.readAsStringSync()).split('\n');
      for (final z in zeilen) {
        final m = muster.firstMatch(z);
        if (m != null) funde.add('$pfad: ${m.group(0)} — ${z.trim()}');
      }
    }
    expect(
      funde,
      isEmpty,
      reason:
          'Ferien kommen nur noch aus betrieb_ferien (BetriebLocal.'
          'ferienPerioden, wirksameFerienSlots). Die Altspalten werden '
          'entfernt — hier nicht mehr lesen oder schreiben.',
    );
  });

  test('ferienBestaetigtAm nur an den bekannten Stellen', () {
    final muster = RegExp(r'\bferienBestaetigtAm\b');
    final funde = <String>[];
    for (final f in dartDateien()) {
      final pfad = norm(f.path);
      if (datenschicht.any(pfad.startsWith)) continue;
      if (bestaetigtErlaubt.contains(pfad)) continue;
      if (muster.hasMatch(ohneKommentare(f.readAsStringSync()))) {
        funde.add(pfad);
      }
    }
    expect(funde, isEmpty);
  });

  test('BetriebMapper.toJson schreibt keine Altspalten mehr', () {
    // Nach dem DROP liesse ein Upsert mit diesen Schlüsseln jedes Speichern
    // eines Betriebs scheitern; bis dahin überschriebe er eingefrorene Werte.
    final s = File('lib/data/mappers/betrieb_mapper.dart').readAsStringSync();
    final toJson = s.substring(s.indexOf('static Map<String, dynamic> toJson'));
    for (final spalte in [
      'ferien_start',
      'ferien_ende',
      'ferien2_start',
      'ferien2_ende',
      'ferien3_start',
      'ferien3_ende',
      'ferien4_start',
      'ferien4_ende',
      'ferien5_start',
      'ferien5_ende',
    ]) {
      expect(toJson.contains("'$spalte'"), isFalse, reason: spalte);
    }
  });
}
