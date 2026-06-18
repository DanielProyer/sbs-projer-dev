# MWST-Sätze Historie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MWST-Sätze in den Einstellungen datumsabhängig (Normal + Reduziert) abbilden, von den Preisen entkoppeln und neue Sätze hinzufügbar machen — ohne Buchungspfade zu ändern.

**Architecture:** `mwst_satz`-Tabelle um `satz_reduziert` erweitern; `MwstSatzService` liefert beide Sätze date-aware + `hinzufuegen`; eigenständige `MwstSaetzeSection` (aus `mwstSaetzeProvider`); Einstellungen-`body` so umgebaut, dass Geschäft/Lohn/MwSt preis-unabhängig sind.

**Tech Stack:** Flutter, Riverpod, Supabase, `intl`.

**Spec:** `docs/superpowers/specs/2026-06-18-mwst-saetze-historie-design.md`

**Arbeitsverzeichnis:** `flutter` in `sbs_projer_app/`. DB via Supabase MCP (`apply_migration`, project_id `pltbaqqwpnmdajwgnhpd`).

---

## Datei-Übersicht
- **Neu:** `Datenbank/migrations/099_mwst_satz_reduziert.sql`, `lib/presentation/providers/mwst_providers.dart`, `lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart`, `test/services/buchhaltung/mwst_satz_service_test.dart`
- **Geändert:** `lib/services/buchhaltung/mwst_satz_service.dart`, `lib/presentation/screens/einstellungen/einstellungen_screen.dart`

---

## Task M1: Migration 099 — `mwst_satz.satz_reduziert`

**Files:** Create `Datenbank/migrations/099_mwst_satz_reduziert.sql`

- [ ] **Step 1: SQL**

```sql
-- 099_mwst_satz_reduziert.sql
-- Reduzierten MWST-Satz datumsabhängig ergänzen.
ALTER TABLE mwst_satz ADD COLUMN IF NOT EXISTS satz_reduziert numeric;
UPDATE mwst_satz SET satz_reduziert = 2.50 WHERE gueltig_ab < '2024-01-01' AND satz_reduziert IS NULL;
UPDATE mwst_satz SET satz_reduziert = 2.60 WHERE gueltig_ab >= '2024-01-01' AND satz_reduziert IS NULL;
```

- [ ] **Step 2: Anwenden (MCP `apply_migration`)** — name `mwst_satz_reduziert`, project_id `pltbaqqwpnmdajwgnhpd`, query = obiger Inhalt. Expected `{"success":true}`.

- [ ] **Step 3: Verifizieren (`execute_sql`)**: `SELECT gueltig_ab, satz, satz_reduziert FROM mwst_satz ORDER BY gueltig_ab;` → `2010-01-01 7.70 2.50` und `2024-01-01 8.10 2.60`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/099_mwst_satz_reduziert.sql
git commit -m "feat(db): mwst_satz.satz_reduziert (7.7/2.5 bis 2023, 8.1/2.6 ab 2024)"
```

---

## Task M2: Model + Service (reduzierter Satz, hinzufügen)

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/mwst_satz_service.dart`
- Test: `sbs_projer_app/test/services/buchhaltung/mwst_satz_service_test.dart`

- [ ] **Step 1: Failing test** — `test/services/buchhaltung/mwst_satz_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

void main() {
  final saetze = [
    MwstSatz(DateTime(2010, 1, 1), 7.7, 2.5),
    MwstSatz(DateTime(2024, 1, 1), 8.1, 2.6),
  ];

  test('Normalsatz datumsabhängig (unverändert)', () {
    expect(MwstSatzService.satzFuer(DateTime(2023, 6, 1), saetze), 7.7);
    expect(MwstSatzService.satzFuer(DateTime(2024, 1, 1), saetze), 8.1);
  });

  test('reduzierter Satz datumsabhängig; vor erstem Eintrag 0', () {
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2023, 12, 31), saetze), 2.5);
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2024, 6, 1), saetze), 2.6);
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2009, 1, 1), saetze), 0.0);
  });
}
```

- [ ] **Step 2: Run → fails** (`cd sbs_projer_app && flutter test test/services/buchhaltung/mwst_satz_service_test.dart`).

- [ ] **Step 3: Implement** — `lib/services/buchhaltung/mwst_satz_service.dart` komplett ersetzen mit:

```dart
import '../supabase/supabase_service.dart';

class MwstSatz {
  final DateTime gueltigAb;
  final double satz;
  final double satzReduziert;
  const MwstSatz(this.gueltigAb, this.satz, this.satzReduziert);
}

class MwstSatzService {
  /// Jüngster Normalsatz mit gueltigAb <= datum; sonst 0.0.
  static double satzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) result = s.satz;
    }
    return result;
  }

  /// Jüngster reduzierter Satz mit gueltigAb <= datum; sonst 0.0.
  static double reduzierterSatzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) result = s.satzReduziert;
    }
    return result;
  }

  static List<MwstSatz>? _cache;
  static void cacheLeeren() => _cache = null;

  static Future<List<MwstSatz>> laden() async {
    if (_cache != null) return _cache!;
    final rows = await SupabaseService.client
        .from('mwst_satz')
        .select('gueltig_ab, satz, satz_reduziert')
        .eq('user_id', SupabaseService.dataUserId);
    _cache = (rows as List)
        .map((r) => MwstSatz(
              DateTime.parse(r['gueltig_ab']),
              double.parse(r['satz'].toString()),
              r['satz_reduziert'] != null ? double.parse(r['satz_reduziert'].toString()) : 0.0,
            ))
        .toList();
    return _cache!;
  }

  /// Normalsatz für ein Buchungsdatum (lädt + cached).
  static Future<double> satzFuerDatum(DateTime datum) async {
    return satzFuer(datum, await laden());
  }

  /// Reduzierter Satz für ein Datum (lädt + cached).
  static Future<double> reduzierterSatzFuerDatum(DateTime datum) async {
    return reduzierterSatzFuer(datum, await laden());
  }

  /// Legt einen neuen Satz ab Datum an und leert den Cache.
  static Future<void> hinzufuegen({
    required DateTime gueltigAb,
    required double satz,
    required double satzReduziert,
  }) async {
    await SupabaseService.client.from('mwst_satz').insert({
      'user_id': SupabaseService.dataUserId,
      'gueltig_ab': gueltigAb.toIso8601String().split('T').first,
      'satz': satz,
      'satz_reduziert': satzReduziert,
    });
    cacheLeeren();
  }
}
```

- [ ] **Step 4: Run → passes (2 tests).** Auch `flutter analyze lib/services/buchhaltung/mwst_satz_service.dart`.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/mwst_satz_service.dart sbs_projer_app/test/services/buchhaltung/mwst_satz_service_test.dart
git commit -m "feat(mwst): reduzierter Satz date-aware + hinzufuegen + cacheLeeren"
```

---

## Task M3: Provider

**Files:** Create `sbs_projer_app/lib/presentation/providers/mwst_providers.dart`

- [ ] **Step 1: Implement**

```dart
// lib/presentation/providers/mwst_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

/// MWST-Sätze, neueste zuerst (für die Anzeige in den Einstellungen).
final mwstSaetzeProvider = FutureProvider<List<MwstSatz>>((ref) async {
  final saetze = await MwstSatzService.laden();
  final sorted = [...saetze]..sort((a, b) => b.gueltigAb.compareTo(a.gueltigAb));
  return sorted;
});
```

- [ ] **Step 2: Analyze.** `cd sbs_projer_app && flutter analyze lib/presentation/providers/mwst_providers.dart`. Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/mwst_providers.dart
git commit -m "feat(mwst): mwstSaetzeProvider (Historie, neueste zuerst)"
```

---

## Task M4: MwstSaetzeSection-Widget

**Files:** Create `sbs_projer_app/lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart`

- [ ] **Step 1: Implement** — exakt:

```dart
// lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/mwst_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

/// Eigenständige MwSt-Sätze-Sektion (datumsabhängig, entkoppelt von Preisen).
class MwstSaetzeSection extends ConsumerWidget {
  const MwstSaetzeSection({super.key});

  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mwstSaetzeProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.percent, color: AppColors.primary),
        title: const Text('MwSt-Sätze', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Normal & reduziert, datumsabhängig'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Fehler: $e'),
            data: (saetze) {
              if (saetze.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8), child: Text('Keine Sätze erfasst.'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < saetze.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'ab ${_df.format(saetze[i].gueltigAb)} — Normal ${saetze[i].satz.toStringAsFixed(1)} % · '
                        'Reduziert ${saetze[i].satzReduziert.toStringAsFixed(1)} %'
                        '${i == 0 ? '  (aktuell)' : ''}',
                        style: TextStyle(fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neuen Satz hinzufügen'),
                      onPressed: () => _addDialog(context, ref),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final datumCtrl = TextEditingController();
    final normalCtrl = TextEditingController();
    final reduziertCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuer MwSt-Satz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: datumCtrl,
              decoration: const InputDecoration(
                  labelText: 'Gültig ab (TT.MM.JJJJ)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: normalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Normal (%)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reduziertCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Reduziert (%)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok != true) return;
    final datum = _parseDatum(datumCtrl.text);
    final normal = double.tryParse(normalCtrl.text.replaceAll(',', '.'));
    final reduziert = double.tryParse(reduziertCtrl.text.replaceAll(',', '.'));
    if (datum == null || normal == null || reduziert == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ungültige Eingabe (Datum TT.MM.JJJJ, Sätze als Zahl).')));
      }
      return;
    }
    try {
      await MwstSatzService.hinzufuegen(gueltigAb: datum, satz: normal, satzReduziert: reduziert);
      ref.invalidate(mwstSaetzeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('MwSt-Satz hinzugefügt')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  static DateTime? _parseDatum(String text) {
    final p = text.trim().split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
}
```

- [ ] **Step 2: Analyze.** `cd sbs_projer_app && flutter analyze lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart`. Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart
git commit -m "feat(einstellungen): MwstSaetzeSection (Historie + neuen Satz hinzufügen)"
```

---

## Task M5: Einstellungen-Screen — MWST entkoppeln

**Files:** Modify `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

Read the file first. Ziel: Geschäft, Lohn und die neue `MwstSaetzeSection` werden **preis-unabhängig** (immer sichtbar); die preis-abhängigen Sektionen (Biersorten, Heineken, Reinigungs-/Störungs-/Weitere Preise, „Neue Preise erfassen") liegen in einem **inneren** `aktuellePreise.when(...)`. Die alte preis-basierte MwSt-Sektion + `_editMwst` entfallen.

- [ ] **Step 1: Import ergänzen** (oben):
```dart
import 'package:sbs_projer_app/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart';
```

- [ ] **Step 2: `_editMwst`-Methode entfernen** (die ganze `Future<void> _editMwst(...) async { ... }`-Methode).

- [ ] **Step 3: `build` umbauen.** Den `body:` ersetzen durch eine ListView, in der Geschäft/Lohn/MwSt oben stehen und die Preis-Sektionen in einem inneren `when` liegen. Konkret:
  1. Den Geschäft-`Card`-Block und den Lohn-`Card`-Block (aktuell die ersten Kinder im `data:`-ListView) **aus** dem `data:`-Block herausziehen — sie werden direkte ListView-Kinder auf oberster Ebene.
  2. **Direkt nach** dem Lohn-Block `const MwstSaetzeSection(),` einfügen.
  3. Den Rest (Biersorten-Card, Heineken-`_SectionCard`, „Aktuelle Preise"-Header, Reinigungspreise, Störungspreise, Weitere Preise, „Neue Preise erfassen"-Button) **unverändert** in den `data:`-Zweig eines **inneren** `aktuellePreise.when(...)` verschieben.
  4. Die **alte „MwSt-Sätze"-`_SectionCard`** (mit `_editMwst`-trailing + `preis.mwstSatz`/`preis.mwstSatzReduziert`) **ersatzlos entfernen**.

Die resultierende `build`-Struktur:

```dart
  @override
  Widget build(BuildContext context) {
    final aktuellePreise = ref.watch(aktuellePreiseProvider);
    final geschaeftAsync = ref.watch(geschaeftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Geschäft (preis-unabhängig)
          Card( /* … bestehender Geschäft-Card-Inhalt mit geschaeftAsync.when … */ ),
          // Lohn (preis-unabhängig)
          Card( /* … bestehender Lohn-ListTile-Card-Inhalt … */ ),
          // MwSt-Sätze (entkoppelt)
          const MwstSaetzeSection(),
          // Preis-abhängige Sektionen
          aktuellePreise.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Fehler: $e'),
            data: (preis) {
              if (preis == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Keine Preise hinterlegt.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/einstellungen/preise/neu'),
                      icon: const Icon(Icons.add),
                      label: const Text('Erste Preisversion erstellen'),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // … Biersorten-Card, Heineken-_SectionCard, „Aktuelle Preise"-Header,
                  //    Reinigungspreise, Störungspreise, Weitere Preise,
                  //    „Neue Preise erfassen"-Button (alle bestehenden Widgets, unverändert),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
```

(Die Inhalte der bestehenden Sektions-Widgets 1:1 übernehmen — nur verschoben. `_InfoRow`/`_TwoColRow`/`_SectionCard`/`_EditableInfoRow` bleiben.)

- [ ] **Step 4: Tote Helfer prüfen.** Falls nach dem Entfernen von `_editMwst` Importe/Felder ungenutzt sind (analyze meldet `unused_*`), bereinigen.

- [ ] **Step 5: Analyze + Tests.** `cd sbs_projer_app && flutter analyze && flutter test`. Expected: 0 Errors; alle Tests grün.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "feat(einstellungen): MwSt-Sätze von Preisen entkoppelt (eigene Sektion, preis-unabhängig)"
```

---

## Task M6: Gesamt-Verifikation + Deploy

**Files:** keine Code-Änderung.

- [ ] **Step 1: Voll-Analyse + Tests.** `cd sbs_projer_app && flutter analyze && flutter test`. Expected: 0 Errors; alle Tests grün.

- [ ] **Step 2: Manueller Klicktest (Web).** `cd sbs_projer_app && flutter run -d edge`. Prüfen:
  - Einstellungen zeigen „MwSt-Sätze" als eigene Sektion (unabhängig von Preisen): „ab 01.01.2010 — Normal 7.7 % · Reduziert 2.5 %" und „ab 01.01.2024 — Normal 8.1 % · Reduziert 2.6 % (aktuell)".
  - „Neuen Satz hinzufügen" legt einen Eintrag an, der oben erscheint.
  - Geschäft/Lohn/MwSt sind sichtbar; die Preis-Sektionen darunter funktionieren wie bisher.
  - Eine Buchung erfassen → MwSt-Satz weiterhin korrekt (Normalsatz datumsabhängig).
- [ ] **Step 3: Version bump + Deploy** (gemäss `CLAUDE.md`). (Nach Freigabe durch Daniel.)

---

## Self-Review (vom Plan-Autor)
- **Spec-Abdeckung:** Migration 099 (M1) ✓; Model+Service reduziert/hinzufügen/cache (M2) ✓; Provider (M3) ✓; MwstSaetzeSection Historie+Dialog (M4) ✓; Entkopplung im Einstellungen-Screen (M5) ✓; Verifikation/Deploy (M6) ✓.
- **Typ-Konsistenz:** `MwstSatz(gueltigAb, satz, satzReduziert)` (M2) in M3/M4 genutzt; `MwstSatzService.reduzierterSatzFuer`/`hinzufuegen`/`cacheLeeren` (M2) in M4; `mwstSaetzeProvider` (M3) in M4/M5; `MwstSaetzeSection` (M4) in M5.
- **App läuft gleich:** `satzFuer`/`satzFuerDatum` (Normalsatz, Buchungen) unverändert; Spesen-Pfad unberührt; Migration additiv.
- **Kompilierbarkeit:** M2/M3/M4 additiv; M5 ersetzt nur die MwSt-Anzeige + Struktur; jeder Commit eigenständig.
```
