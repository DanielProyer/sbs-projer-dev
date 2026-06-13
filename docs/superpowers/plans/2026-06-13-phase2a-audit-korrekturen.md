# Phase 2a – Audit-Ansicht + mechanische Korrekturen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Einen read-only Audit-Screen bereitstellen, der verdächtige Buchungen/Salden kategorisiert, und die eindeutigen Fehler 8090→8900 + 2500-Restsaldo korrigieren (rückdatiert/in-place, mit Spur).

**Architecture:** Reiner Dart-`AuditService` (testbar) erzeugt aus den Saldi + Konten eine Befundliste. Provider lädt `BuchungService.getAllSaldi()` + `KontoRepository.getAll()` und ruft den Service; `AuditScreen` rendert nach Kategorie (Muster `BilanzScreen`). Die Korrekturen laufen als idempotente SQL-Migration (in-place Konto-Umklassierung + `notizen`-Spur). Kein Deploy.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase MCP (project_id `pltbaqqwpnmdajwgnhpd`), `flutter_test`, go_router. Spec: [Phase-2a](../specs/2026-06-13-phase2a-audit-korrekturen-design.md). Flutter via `export PATH="$PATH:/c/flutter/bin"`. Daniel `user_id=1e1ec2dd-7836-4d8e-8256-c5649d994ee2`.

---

## Task 1: AuditService (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/audit_service.dart`
- Test: `sbs_projer_app/test/audit_service_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/audit_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart' show KontoInfo;
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';

KontoInfo _k(int nr, String bez, String kat) =>
    KontoInfo(kontonummer: nr, bezeichnung: bez, kategorie: kat);

void main() {
  final konten = [
    _k(8090, 'FEHLER – sollte 8900 (Phase 2)', 'Steuern'),
    _k(8900, 'Direkte Steuern', 'Steuern'),
    _k(1100, 'Debitoren', 'Umlaufvermögen'),
    _k(1020, 'Bankguthaben', 'Umlaufvermögen'),
    _k(2980, 'Jahresgewinn/-verlust', 'Eigenkapital'),
    _k(9000, 'Gewinn-/Verlustübertrag', 'Abschluss'),
  ];

  test('Fehler-Konto mit Saldo wird gelistet', () {
    final b = AuditService.befunde({8090: 1365.15}, konten);
    expect(b.any((x) => x.konto == 8090 && x.kategorie == 'Fehler-Konto'), isTrue);
  });

  test('negativer Saldo auf Aktivkonto (Klasse 1) wird gelistet', () {
    final b = AuditService.befunde({1020: -50.0}, konten);
    expect(b.any((x) => x.konto == 1020 && x.kategorie == 'Negativer Saldo'), isTrue);
  });

  test('negativer Saldo auf 8900 wird gelistet', () {
    final b = AuditService.befunde({8900: -7380.20}, konten);
    expect(b.any((x) => x.konto == 8900 && x.kategorie == 'Negativer Saldo'), isTrue);
  });

  test('Abschluss-Konto mit Restsaldo wird gelistet', () {
    final b = AuditService.befunde({9000: -76289.27, 2980: 100.0}, konten);
    expect(b.where((x) => x.kategorie == 'Abschluss-Rest').length, 2);
  });

  test('hoher Debitorensaldo wird gelistet', () {
    final b = AuditService.befunde({1100: 116255.48}, konten);
    expect(b.any((x) => x.konto == 1100 && x.kategorie == 'Debitoren'), isTrue);
  });

  test('saubere/kleine Salden erzeugen keinen Befund', () {
    final b = AuditService.befunde({1020: 4602.90, 8900: 0.03}, konten);
    expect(b, isEmpty);
  });
}
```

- [ ] **Step 2: Test → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/audit_service_test.dart`
Expected: FAIL (`AuditService` undefiniert).

- [ ] **Step 3: Service implementieren**

```dart
// lib/services/buchhaltung/audit_service.dart
import 'bilanz_service.dart' show KontoInfo;

/// Ein auffälliger Posten aus der Buchhaltung.
class AuditBefund {
  final String kategorie;
  final int konto;
  final String bezeichnung;
  final double saldo;
  final String hinweis;
  const AuditBefund(this.kategorie, this.konto, this.bezeichnung, this.saldo, this.hinweis);
}

/// Findet verdächtige Salden (reine Regeln; Eingabe = Anzeige-Saldi wie getAllSaldi).
class AuditService {
  static const _eps = 0.05;

  static List<AuditBefund> befunde(Map<int, double> saldi, List<KontoInfo> konten) {
    final byNr = {for (final k in konten) k.kontonummer: k};
    String bez(int nr) => byNr[nr]?.bezeichnung ?? '—';
    final out = <AuditBefund>[];

    saldi.forEach((konto, saldo) {
      final name = byNr[konto]?.bezeichnung ?? '';
      final klasse = konto ~/ 1000;

      // 1) Fehler-Konten
      if (name.toUpperCase().contains('FEHLER') && saldo.abs() > _eps) {
        out.add(AuditBefund('Fehler-Konto', konto, bez(konto), saldo,
            'Falsches Konto — umbuchen'));
      }
      // 2) Unerwartet negativer Saldo (Aktiven Klasse 1, oder 2200/8900)
      if (saldo < -_eps && (klasse == 1 || konto == 2200 || konto == 8900)) {
        out.add(AuditBefund('Negativer Saldo', konto, bez(konto), saldo,
            'Negativer Saldo prüfen'));
      }
      // 3) Abschluss-Konten mit Restsaldo (Klasse 9 oder 2980)
      if ((klasse == 9 || konto == 2980) && saldo.abs() > _eps) {
        out.add(AuditBefund('Abschluss-Rest', konto, bez(konto), saldo,
            'Abschlussbuchung unvollständig'));
      }
      // 4) Hoher Debitorensaldo
      if (konto == 1100 && saldo > _eps) {
        out.add(AuditBefund('Debitoren', konto, bez(konto), saldo,
            'Offene Forderungen prüfen/abschreiben (Phase 2c)'));
      }
    });

    out.sort((a, b) => a.kategorie.compareTo(b.kategorie) == 0
        ? a.konto.compareTo(b.konto)
        : a.kategorie.compareTo(b.kategorie));
    return out;
  }
}
```

- [ ] **Step 4: Test → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/audit_service_test.dart`
Expected: PASS (6 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/audit_service.dart sbs_projer_app/test/audit_service_test.dart
git commit -m "feat(buchhaltung): AuditService (verdächtige Salden) + Tests"
```

---

## Task 2: Provider + AuditScreen + Route + Dashboard-Tile

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/audit_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Provider ergänzen**

In `buchhaltung_providers.dart` (Imports für `KontoRepository`, `BuchungService`, `audit_service.dart`, `konto`-Modell ergänzen, falls noch nicht vorhanden — vorher `grep -n "import" lib/presentation/providers/buchhaltung_providers.dart` prüfen):

```dart
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';

final auditBefundeProvider = FutureProvider<List<AuditBefund>>((ref) async {
  final saldi = await BuchungService.getAllSaldi();
  final konten = await KontoRepository.getAll();
  final infos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return AuditService.befunde(saldi, infos);
});
```

- [ ] **Step 2: AuditScreen erstellen**

```dart
// lib/presentation/screens/buchhaltung/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditBefundeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit / Verdächtige Buchungen')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (befunde) {
          if (befunde.isEmpty) {
            return const Center(child: Text('Keine Auffälligkeiten gefunden.'));
          }
          final gruppen = <String, List<AuditBefund>>{};
          for (final b in befunde) {
            gruppen.putIfAbsent(b.kategorie, () => []).add(b);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in gruppen.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.key} (${entry.value.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const Divider(),
                        for (final b in entry.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${b.konto} · ${b.bezeichnung}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(b.hinweis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text('${b.saldo.toStringAsFixed(2)} CHF',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: b.saldo < 0
                                            ? AppColors.error
                                            : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

(Vorher `grep -n "error\|success\|textSecondary\|textPrimary" lib/core/theme/app_theme.dart` prüfen, dass die `AppColors`-Namen stimmen — sie werden auch in `bilanz_screen.dart` genutzt.)

- [ ] **Step 3: Route + Import in `router.dart`**

```dart
import 'package:sbs_projer_app/presentation/screens/buchhaltung/audit_screen.dart';
// im /buchhaltung-Block:
GoRoute(
  path: '/buchhaltung/audit',
  builder: (context, state) => const AuditScreen(),
),
```

- [ ] **Step 4: Dashboard-Tile** in `buchhaltung_dashboard_screen.dart` analog zum bestehenden Bilanz-/Berichte-Tile (gleicher `_NavTile`-Typ; `grep -n "_NavTile\|/buchhaltung/bilanz" lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`):

```dart
_NavTile(
  icon: Icons.fact_check,
  title: 'Audit',
  subtitle: 'Verdächtige Buchungen & Salden',
  onTap: () => context.push('/buchhaltung/audit'),
),
```

- [ ] **Step 5: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/audit_screen.dart lib/presentation/providers/buchhaltung_providers.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
Expected: No issues (außer evtl. vorbestehende info-Hinweise).

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/audit_screen.dart sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "feat(ui): Audit-Screen (verdächtige Buchungen) + Route + Dashboard-Tile"
```

---

## Task 3: Korrektur-Migration 8090→8900 + 2500-Restsaldo

**Files:**
- Create: `Datenbank/migrations/093_korrektur_8090_2500.sql`

- [ ] **Step 1: Ist-Stand 8090 + 2500-Rohsaldo erfassen (Referenz)**

Via `mcp__supabase__execute_sql`:
```sql
SELECT
 (SELECT count(*) FROM buchungen WHERE haben_konto=8090 AND datum<'2025-12-01') AS h8090,
 (SELECT count(*) FROM buchungen WHERE soll_konto=8090 AND datum<'2025-12-01') AS s8090,
 (SELECT round(sum(CASE WHEN soll_konto=2500 THEN betrag_brutto WHEN haben_konto=2500 THEN -betrag_brutto ELSE 0 END)::numeric,2)
    FROM buchungen WHERE (soll_konto=2500 OR haben_konto=2500) AND NOT ist_storniert) AS roh_2500;
```
Notieren: `h8090` (erwartet 6), `s8090` (erwartet 0), `roh_2500` (erwartet 1.35).

- [ ] **Step 2: Migration schreiben** (8090→8900 in-place; 2500-Glättung mit dem in Step 1 ermittelten Betrag)

```sql
-- 093_korrektur_8090_2500.sql
-- Phase 2a: mechanische Korrekturen (rückdatiert/in-place, mit notizen-Spur).

-- 8090 -> 8900 (Tippfehler-Konto; Steuer-Rückerstattungen). Haben + defensiv Soll.
UPDATE buchungen
   SET haben_konto = 8900,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2-Korrektur: 8090->8900')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND haben_konto = 8090 AND datum < '2025-12-01';
UPDATE buchungen
   SET soll_konto = 8900,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2-Korrektur: 8090->8900')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND soll_konto = 8090 AND datum < '2025-12-01';

-- 2500 Coronakredit Restsaldo glätten: Roh-Saldo +1.35 -> 0.
-- Soll 6940 / Haben 2500 über den Restbetrag, datiert im letzten Coronakredit-Jahr (2025).
-- (Betrag = roh_2500 aus Step 1; hier 1.35. Falls roh_2500 = 0, diesen INSERT weglassen.)
INSERT INTO buchungen
  (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag, betrag_brutto, beschreibung, geschaeftsjahr, ist_storniert, notizen)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','2025-11-30','KORR_2500', 6940, 2500, 1.35, 0, 0, 1.35,
   'Coronakredit Restsaldo-Glättung', 2025, false, 'Phase2-Korrektur: 2500 Restsaldo -> 0');
```

- [ ] **Step 3: Anwenden + verifizieren**

Anwenden via `mcp__supabase__apply_migration` (name `093_korrektur_8090_2500`), dann:
```sql
SELECT
 (SELECT count(*) FROM buchungen WHERE soll_konto=8090 OR haben_konto=8090) AS konto_8090_rest,
 (SELECT round(sum(CASE WHEN soll_konto=2500 THEN betrag_brutto WHEN haben_konto=2500 THEN -betrag_brutto ELSE 0 END)::numeric,2)
    FROM buchungen WHERE (soll_konto=2500 OR haben_konto=2500) AND NOT ist_storniert) AS roh_2500_neu,
 (SELECT count(*) FROM buchungen WHERE (soll_konto=8900 OR haben_konto=8900) AND notizen LIKE '%8090->8900%') AS umklassiert;
```
Expected: `konto_8090_rest = 0`; `roh_2500_neu = 0.00`; `umklassiert = 6`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/093_korrektur_8090_2500.sql
git commit -m "fix(db): Phase 2a Korrekturen 8090→8900 + 2500-Restsaldo (rückdatiert, mit Spur)"
```

---

## Task 4: Abschluss-Verifikation

- [ ] **Step 1: Tests + Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS (inkl. `audit_service_test`); analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Audit-Screen prüft sich selbst** — nach der Korrektur sollte der Audit-Screen 8090 nicht mehr listen (kein Saldo), 2500 verschwindet aus „Negativer Saldo". Verbleibend erwartet: Fehler-Konto 9100, Abschluss-Reste (9000/9100), negative 2202/2273/8900, Debitoren 1100 → das sind die Eingänge für 2b/2c.

- [ ] **Step 3: Erfolgskriterien (gegen Spec §7)**
  - Audit-Screen kategorisiert Auffälligkeiten ✔
  - 8090 ohne Buchungen, 8900 enthält die 6 Umklassierungen ✔
  - 2500-Saldo = 0 ✔
  - Keine Regression ✔

---

## Hinweise für die Umsetzung
- **Korrektur ist Prod-Schreibzugriff**, aber eng begrenzt (8090-Reclass + 1 Glättungsbuchung) und über `notizen` markiert → bei Bedarf zurücknehmbar (haben_konto zurück auf 8090 wo notizen den Vermerk trägt; Glättungsbuchung per belegnummer `KORR_2500` löschbar).
- **Reihenfolge:** Task 1 → 2 (App) → 3 (Korrektur-DB) → 4.
- **Folge:** 2b (9100/Abschluss-Reconciliation), 2c (Debitoren-Abschreibung, Treuhänder).
