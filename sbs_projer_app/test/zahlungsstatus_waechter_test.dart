import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';

/// Hält `Zahlungsstatus.alle` synchron mit dem DB-CHECK.
///
/// WARUM: `rechnungen.zahlungsstatus` hat einen CHECK-Constraint. Frühere
/// Werte wurden entfernt — Code, der sie schreibt, wirft eine
/// PostgrestException. Ohne Wächter merkt man das erst live, nicht beim
/// `flutter analyze`:
/// - 081–083: entwurf, versendet, gestellt, teilbezahlt, ueberfaellig,
///   storniert;
/// - 211 (27.09.2026, Statusmodell-Zielbild): gesendet, freigegeben,
///   erinnert, mahnung_1, mahnung_2 — seither nur noch
///   'offen', 'bezahlt', 'abgeschrieben'. Zustellung, Mahnstufe und
///   Heineken-Freigabe sind Felder (`versendet_am`/`uebergeben_am`,
///   `mahnung_stufe`, `freigegeben_am`).
///
/// Dieser Test liest alle SQL-Migrationen, findet den LETZTEN CHECK, der
/// `zahlungsstatus` einschränkt (Stand 27.09.2026:
/// 211_zahlungsstatus_zielbild.sql) und vergleicht ihn mit
/// [Zahlungsstatus.alle]. Kommt eine neue Migration mit einem neuen CHECK
/// dazu, schlägt der Test an und zeigt genau, was fehlt.
///
/// GRENZE: Erkannt wird nur die Schreibweise `CHECK (zahlungsstatus IN (...))`.
/// Eine künftige Migration in der Form `= ANY (ARRAY[...])` fände der Regex
/// nicht — dann bliebe der Test grün, obwohl die Liste veraltet ist. Neue
/// CHECKs deshalb in derselben Schreibweise wie 083/211 formulieren.
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

    // CHECK-Constraints, die zahlungsstatus einschränken, sehen so aus:
    //   CHECK (zahlungsstatus IN ('offen', 'bezahlt', ...));
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
      letzteDatei!.replaceAll('\\', '/'),
      endsWith('211_zahlungsstatus_zielbild.sql'),
      reason: 'Der CHECK aus 211 muss der letzte sein.',
    );

    expect(
      Zahlungsstatus.alle,
      equals(letzteWerte),
      reason:
          'Zahlungsstatus.alle ist nicht mehr synchron mit dem CHECK aus '
          '$letzteDatei (dort: $letzteWerte).',
    );
  });

  test('Zielbild: nur offen, bezahlt, abgeschrieben', () {
    expect(Zahlungsstatus.alle, {'offen', 'bezahlt', 'abgeschrieben'});
    expect(Zahlungsstatus.alle.intersection(Zahlungsstatus.altwerte), isEmpty);
  });

  test('kein Code schreibt, vergleicht oder filtert einen früheren Wert', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final wert in Zahlungsstatus.altwerte) {
      final muster = [
        // 'zahlungsstatus': 'gesendet'
        RegExp("'zahlungsstatus'\\s*:\\s*'$wert'"),
        // zahlungsstatus == 'gesendet', r['zahlungsstatus'] != 'erinnert'
        RegExp("zahlungsstatus'?\\]?\\s*[!=]=\\s*'$wert'"),
        // .eq('zahlungsstatus', 'mahnung_1')
        RegExp("\\.(eq|neq)\\(\\s*'zahlungsstatus'\\s*,\\s*'$wert'"),
        // 'zahlungsstatus.eq.gesendet' in .or(...)
        RegExp('zahlungsstatus\\.(eq|neq)\\.$wert\\b'),
      ];
      for (final f in dateien) {
        final zeilen = f.readAsLinesSync();
        for (var i = 0; i < zeilen.length; i++) {
          final k = zeilen[i].indexOf('//');
          final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
          if (muster.any((m) => m.hasMatch(code))) {
            verstoesse.add('${f.path}:${i + 1}: $wert');
          }
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Code schreibt/vergleicht einen Zahlungsstatus-Wert, den der '
          'DB-CHECK nicht mehr erlaubt (081–083, 211): $verstoesse',
    );
  });
}
