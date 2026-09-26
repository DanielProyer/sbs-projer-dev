import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';

/// Hält `Zahlungsstatus.alle` synchron mit dem DB-CHECK.
///
/// WARUM: `rechnungen.zahlungsstatus` hat einen CHECK-Constraint. Frühere
/// Werte (entwurf, versendet, gestellt, teilbezahlt, ueberfaellig,
/// storniert) wurden in den Migrationen 081–083 entfernt — Code, der sie
/// schreibt, wirft eine PostgrestException. Ohne Wächter merkt man das erst
/// live, nicht beim `flutter analyze`.
///
/// Dieser Test liest alle SQL-Migrationen, findet den LETZTEN CHECK, der
/// `zahlungsstatus` einschränkt (Stand 26.09.2026: 083_heineken_zahlungsstatus.sql
/// — 'offen', 'gesendet', 'freigegeben', 'bezahlt', 'erinnert', 'mahnung_1',
/// 'mahnung_2', 'abgeschrieben') und vergleicht ihn mit [Zahlungsstatus.alle].
/// Kommt eine neue Migration mit einem neuen CHECK dazu, schlägt der Test an
/// und zeigt genau, was fehlt.
void main() {
  test('Zahlungsstatus.alle entspricht dem letzten DB-CHECK', () {
    final migrationsOrdner = Directory('../Datenbank/migrations');
    expect(
      migrationsOrdner.existsSync(),
      isTrue,
      reason: 'Migrationsordner nicht gefunden: ${migrationsOrdner.path}',
    );

    final dateien =
        migrationsOrdner
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // CHECK-Constraints, die zahlungsstatus einschränken, sehen in 081–083 so
    // aus:
    //   CHECK (zahlungsstatus IN ('offen', 'gesendet', ...));
    // teils über mehrere Zeilen. Wir suchen "zahlungsstatus IN (...)" nur
    // innerhalb eines CHECK-Ausdrucks (nicht z. B. "WHERE ... IN (...)").
    final checkRegex = RegExp(
      r'CHECK\s*\(\s*zahlungsstatus\s+IN\s*\(([^)]*)\)\s*\)',
      caseSensitive: false,
      dotAll: true,
    );

    String? letzteDatei;
    Set<String>? letzteWerte;

    for (final f in dateien) {
      final text = f.readAsStringSync();
      final match = checkRegex.firstMatch(text);
      if (match == null) continue;

      final rohliste = match.group(1)!;
      final werte = rohliste
          .split(',')
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .map((w) => w.replaceAll(RegExp('^[\'"]|[\'"]\$'), ''))
          .toSet();

      letzteDatei = f.path;
      letzteWerte = werte;
    }

    expect(
      letzteWerte,
      isNotNull,
      reason: 'Keine Migration mit CHECK auf zahlungsstatus gefunden.',
    );

    expect(
      Zahlungsstatus.alle,
      equals(letzteWerte),
      reason:
          'Zahlungsstatus.alle ist nicht mehr synchron mit dem CHECK aus '
          '$letzteDatei (dort: $letzteWerte).',
    );
  });

  test('kein Code schreibt einen frueheren Zahlungsstatus-Wert', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final wert in Zahlungsstatus.altwerte) {
      final muster1 = RegExp("'zahlungsstatus'\\s*:\\s*'$wert'");
      final muster2 = RegExp("zahlungsstatus\\s*==\\s*'$wert'");
      for (final f in dateien) {
        final text = f.readAsStringSync();
        if (muster1.hasMatch(text) || muster2.hasMatch(text)) {
          verstoesse.add('${f.path}: $wert');
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Code schreibt/vergleicht einen Zahlungsstatus-Wert, den der '
          'DB-CHECK seit 081–083 nicht mehr erlaubt: $verstoesse',
    );
  });
}
