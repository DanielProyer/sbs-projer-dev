# Forderungen-Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Rechnungsliste zum einzigen „Forderungen"-Hub erweitern (Mahnfällig-Filter + Debitoren-Kopf), die separaten Mahnwesen-/Debitoren-Screens entfernen, Status-Logik zentralisieren.

**Architecture:** Reiner `ForderungService` (empfohleneAktion/istMahnfaellig, TDD) + `forderungenProvider`. Die Mahnfällig-Filterung läuft im Hub über den Service. Eine extrahierte `DebitorenHeader`-Komponente kapselt Salden + Sammel-Abschreibung + Delkredere (aus dem alten DebitorenScreen) und wird im Hub eingebettet. Mahnwesen-/Debitoren-Routen leiten auf den Hub um; die Screen-Dateien entfallen. Kein DB-Schema-Change, kein Deploy.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Supabase, `flutter_test`. Spec: [Forderungen-Hub](../specs/2026-06-13-forderungen-hub-design.md). Flutter via `export PATH="$PATH:/c/flutter/bin"`.

**Rechnung-Modell (Referenz):** `zahlungsstatus` (offen|erinnert|mahnung_1|mahnung_2|bezahlt|abgeschrieben), `faelligkeitsdatum` (DateTime), `erinnerungAm`/`mahnung1Am`/`mahnung2Am` (DateTime?), `mahnungStufe` (int), `rechnungstyp` ('rechnung_kunde'|'heineken_monat').

---

## Task 1: ForderungService (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/rechnung/forderung_service.dart`
- Test: `sbs_projer_app/test/forderung_service_test.dart`

- [ ] **Step 1: Failing Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';

Rechnung _r({
  required String status,
  required DateTime faellig,
  DateTime? erinnerungAm,
  DateTime? mahnung1Am,
  String typ = 'rechnung_kunde',
}) =>
    Rechnung(
      id: 'x',
      userId: 'u',
      rechnungstyp: typ,
      rechnungsdatum: faellig.subtract(const Duration(days: 30)),
      faelligkeitsdatum: faellig,
      betragNetto: 100,
      mwstBetrag: 8.1,
      betragBrutto: 108.1,
      zahlungsstatus: status,
      mahnungStufe: 0,
      erinnerungAm: erinnerungAm,
      mahnung1Am: mahnung1Am,
    );

void main() {
  final heute = DateTime(2026, 6, 13);

  test('offen, <5 Tage überfällig → warten', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'offen', faellig: DateTime(2026, 6, 10)),
            heute: heute),
        'warten');
  });
  test('offen, ≥5 Tage überfällig → erinnerung_faellig', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'offen', faellig: DateTime(2026, 6, 1)),
            heute: heute),
        'erinnerung_faellig');
  });
  test('erinnert, ≥25 Tage seit Erinnerung → mahnung_1_faellig', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'erinnert', faellig: DateTime(2026, 4, 1), erinnerungAm: DateTime(2026, 5, 1)),
            heute: heute),
        'mahnung_1_faellig');
  });
  test('mahnung_1, ≥30 Tage seit Mahnung 1 → mahnung_2_faellig', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'mahnung_1', faellig: DateTime(2026, 3, 1), mahnung1Am: DateTime(2026, 5, 1)),
            heute: heute),
        'mahnung_2_faellig');
  });
  test('mahnung_2 → eskalation', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'mahnung_2', faellig: DateTime(2026, 1, 1)),
            heute: heute),
        'eskalation');
  });
  test('bezahlt → warten', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'bezahlt', faellig: DateTime(2026, 1, 1)),
            heute: heute),
        'warten');
  });
  test('heineken_monat → warten', () {
    expect(
        ForderungService.empfohleneAktion(
            _r(status: 'offen', faellig: DateTime(2026, 1, 1), typ: 'heineken_monat'),
            heute: heute),
        'warten');
  });
  test('istMahnfaellig', () {
    expect(
        ForderungService.istMahnfaellig(
            _r(status: 'offen', faellig: DateTime(2026, 6, 1)), heute: heute),
        isTrue);
    expect(
        ForderungService.istMahnfaellig(
            _r(status: 'bezahlt', faellig: DateTime(2026, 1, 1)), heute: heute),
        isFalse);
  });
}
```

- [ ] **Step 2: Test → FAIL**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/forderung_service_test.dart`
(Falls der `Rechnung`-Konstruktor andere Pflichtfelder verlangt → vorher `grep -n "Rechnung({" lib/data/models/rechnung.dart` und die Test-Fabrik `_r` anpassen.)

- [ ] **Step 3: Implementieren**

```dart
// lib/services/rechnung/forderung_service.dart
import '../../data/models/rechnung.dart';

/// Zentrale Forderungs-Logik: empfohlene Mahn-Aktion (bildet
/// view_mahnwesen_dashboard in Dart ab).
class ForderungService {
  static String empfohleneAktion(Rechnung r, {DateTime? heute}) {
    final h = heute ?? DateTime.now();
    if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') {
      return 'warten';
    }
    if (r.rechnungstyp == 'heineken_monat') return 'warten';
    int tage(DateTime d) => h.difference(d).inDays;
    switch (r.zahlungsstatus) {
      case 'offen':
        return tage(r.faelligkeitsdatum) >= 5 ? 'erinnerung_faellig' : 'warten';
      case 'erinnert':
        return (r.erinnerungAm != null && tage(r.erinnerungAm!) >= 25)
            ? 'mahnung_1_faellig'
            : 'warten';
      case 'mahnung_1':
        return (r.mahnung1Am != null && tage(r.mahnung1Am!) >= 30)
            ? 'mahnung_2_faellig'
            : 'warten';
      case 'mahnung_2':
        return 'eskalation';
      default:
        return 'warten';
    }
  }

  static bool istMahnfaellig(Rechnung r, {DateTime? heute}) =>
      empfohleneAktion(r, heute: heute) != 'warten';
}
```

- [ ] **Step 4: Test → PASS (8)**
- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/services/rechnung/forderung_service.dart sbs_projer_app/test/forderung_service_test.dart
git commit -m "feat(rechnung): ForderungService (empfohlene Mahn-Aktion) + Tests"
```

---

## Task 2: forderungenProvider

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/rechnung_providers.dart`

- [ ] **Step 1: Provider ergänzen** (Imports `Rechnung`/`ForderungService` ergänzen falls nötig)

```dart
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';

/// Kundenrechnungen mit berechneter empfohlener Mahn-Aktion (ersetzt das
/// View-basierte Mahnwesen-Dashboard).
final forderungenProvider = Provider<List<Rechnung>>((ref) {
  final alle = ref.watch(rechnungenProvider); // bestehende Liste aller Rechnungen
  return alle.where((r) => r.rechnungstyp == 'rechnung_kunde').toList();
});
```
(Falls `rechnungenProvider` bereits nur Kundenrechnungen liefert oder Heineken separat ist → den Filter entsprechend; `grep -n "rechnungenProvider" lib/presentation/providers/rechnung_providers.dart` prüfen. Die Mahnfällig-Berechnung erfolgt im Screen via `ForderungService`, der Provider liefert die Datenbasis.)

- [ ] **Step 2: Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/rechnung_providers.dart`

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/providers/rechnung_providers.dart
git commit -m "feat(rechnung): forderungenProvider (Kundenforderungen)"
```

---

## Task 3: DebitorenHeader-Komponente extrahieren

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/rechnungen/widgets/debitoren_header.dart`

**Kontext:** Der bestehende `DebitorenScreen` (`lib/presentation/screens/buchhaltung/debitoren_screen.dart`) enthält die Salden-Karten + Sammel-Abschreibung-Dialog + Delkredere-Button, gespeist von `debitorenUebersichtProvider` und `AbschreibungService`. Diese Logik wird in ein einklappbares Widget extrahiert, damit sie im Hub einsetzbar ist.

- [ ] **Step 1: Widget erstellen** — den Inhalt aus `debitoren_screen.dart` (Salden-Cards, `_sammelDialog`, `_delkredere`) in ein `ConsumerStatefulWidget` `DebitorenHeader` übernehmen, als **einklappbares** `ExpansionTile` („Debitoren / Abschreibungen"). Die genaue Card-/Dialog-Logik 1:1 aus `debitoren_screen.dart` übernehmen (gleiche Provider `debitorenUebersichtProvider`, gleiche `AbschreibungService`-Aufrufe, `ref.invalidate(debitorenUebersichtProvider)` nach Aktionen). Vorher `cat`/Read von `debitoren_screen.dart` zum 1:1-Übernehmen.

Gerüst:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

class DebitorenHeader extends ConsumerStatefulWidget {
  const DebitorenHeader({super.key});
  @override
  ConsumerState<DebitorenHeader> createState() => _DebitorenHeaderState();
}

class _DebitorenHeaderState extends ConsumerState<DebitorenHeader> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(debitorenUebersichtProvider);
    return Card(
      child: ExpansionTile(
        title: const Text('Debitoren / Abschreibungen'),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Fehler: $e'),
            data: (d) => Column(children: [
              // Salden-Zeilen (debitoren_total / native_offen / historisch_aggregat / delkredere)
              // + Buttons "Sammel-Abschreibung" (_sammelDialog) und "Delkredere 5%" (_delkredere)
              // 1:1 aus debitoren_screen.dart übernehmen.
            ]),
          ),
        ],
      ),
    );
  }
  // _sammelDialog + _delkredere 1:1 aus debitoren_screen.dart übernehmen.
}
```

- [ ] **Step 2: Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/rechnungen/widgets/debitoren_header.dart`
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/rechnungen/widgets/debitoren_header.dart
git commit -m "feat(rechnung): DebitorenHeader-Komponente (aus DebitorenScreen extrahiert)"
```

---

## Task 4: Hub-Screen — Mahnfällig-Filter + Debitoren-Kopf

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/rechnungen/rechnungen_list_screen.dart`

**Kontext:** Der Screen (`RechnungenListScreen`, ConsumerStatefulWidget) hat einen Status-Filter (`_statusLabel`/`_statusColor`, ein `_filterStatus`-State) und rendert die Rechnungen. Erweitern um (a) einen zusätzlichen Filter-Chip „Mahnfällig" und (b) den `DebitorenHeader` oben.

- [ ] **Step 1: AppBar-Titel + Debitoren-Kopf**
- AppBar-Titel auf „Forderungen" ändern.
- Direkt über der Filter-/Listenfläche `const DebitorenHeader()` einsetzen (Import `widgets/debitoren_header.dart`).

- [ ] **Step 2: Mahnfällig-Filter** — den Filter-Mechanismus finden (`grep -n "_filterStatus\|FilterChip\|ChoiceChip\|where(" lib/presentation/screens/rechnungen/rechnungen_list_screen.dart`). Einen zusätzlichen Filter-Wert `'mahnfaellig'` einführen: wenn aktiv, die Liste auf `ForderungService.istMahnfaellig(r)` filtern (Import `forderung_service.dart`). In der Zeile einer mahnfälligen Rechnung die empfohlene Aktion anzeigen (`ForderungService.empfohleneAktion(r)`) + den bestehenden „Mahnen/Eskalieren"-Pfad (`MahnwesenService.eskalieren`) bzw. „Abschreiben" (`MahnwesenService.abschreiben`) nutzen — die existieren bereits im Screen/Service, NICHT duplizieren.

- [ ] **Step 3: Analyse + App-Konsistenz**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/rechnungen/rechnungen_list_screen.dart`
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/rechnungen/rechnungen_list_screen.dart
git commit -m "feat(rechnung): Rechnungsliste → Forderungen-Hub (Mahnfällig-Filter + Debitoren-Kopf)"
```

---

## Task 5: Aufräumen — Routen-Redirects, Screens entfernen, Tiles konsolidieren

**Files:**
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/mahnwesen_screen.dart`, `sbs_projer_app/lib/presentation/screens/buchhaltung/debitoren_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`, `sbs_projer_app/lib/presentation/screens/home_screen.dart`

- [ ] **Step 1: Routen umstellen** — in `router.dart` die beiden Routen auf Redirect setzen statt eigener Screens:
```dart
GoRoute(path: '/buchhaltung/mahnwesen', redirect: (c, s) => '/rechnungen'),
GoRoute(path: '/buchhaltung/debitoren', redirect: (c, s) => '/rechnungen'),
```
Die Imports `mahnwesen_screen.dart` + `debitoren_screen.dart` aus `router.dart` entfernen.

- [ ] **Step 2: Screen-Dateien löschen**
```bash
rm sbs_projer_app/lib/presentation/screens/buchhaltung/mahnwesen_screen.dart sbs_projer_app/lib/presentation/screens/buchhaltung/debitoren_screen.dart
```
Danach `grep -rn "MahnwesenScreen\|DebitorenScreen" lib/` — verbleibende Referenzen (außer den jetzt entfernten Routen) auf den Hub umbiegen.

- [ ] **Step 3: Tiles konsolidieren** — in `buchhaltung_dashboard_screen.dart` und `home_screen.dart` die Tiles „Rechnungen"/„Mahnwesen"/„Debitoren" durch **ein** Tile „Forderungen" (→ `/rechnungen`, Icon z. B. `Icons.receipt_long`) ersetzen. (`grep -n "Mahnwesen\|Debitoren\|Rechnungen\|/rechnungen" lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart lib/presentation/screens/home_screen.dart`.)

- [ ] **Step 4: Tote Provider entfernen** — `mahnwesenDashboardProvider` (und ggf. `offeneRechnungenViewProvider`), falls nach den Änderungen ungenutzt: `grep -rn "mahnwesenDashboardProvider\|offeneRechnungenViewProvider" lib/` — wenn keine Nutzer mehr, die Provider-Definition entfernen. (DB-View `view_mahnwesen_dashboard` bleibt bestehen.)

- [ ] **Step 5: Analyse (gesamt)**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze`
Expected: keine neuen Errors/Warnings; keine Referenz auf gelöschte Screens.

- [ ] **Step 6: Commit**
```bash
git add -A
git commit -m "refactor(rechnung): Mahnwesen/Debitoren-Screens entfernt, Routen→Hub, Tiles konsolidiert"
```

---

## Task 6: Abschluss-Verifikation

- [ ] **Step 1: Tests + Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS (inkl. `forderung_service_test`); analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Erfolgskriterien (Spec §6)**
  - Ein „Forderungen"-Einstieg ersetzt drei Screens ✔
  - Mahnfällig-Filter + Debitoren-Kopf integriert ✔
  - Mahnwesen-/Debitoren-Routen leiten auf den Hub ✔; Tiles zusammengeführt ✔
  - Bestehende Aktionen (Sammelzahlung/Eskalation/Abschreibung/Sammel-Abschreibung/Delkredere) verfügbar; keine Regression ✔

---

## Hinweise für die Umsetzung
- **Reihenfolge:** Task 1 (Service) → 2 (Provider) → 3 (DebitorenHeader) → 4 (Hub) → 5 (Aufräumen) → 6.
- **Kein DB-Schema-Change, kein Deploy** (Deploy am Sessionende separat nachfragen).
- **Heineken** bleibt unberührt (separater Bereich).
- **Folge (separat):** Buchungsvorlagen-Bereinigung (Dubletten 20.1≡F-bankgeb, 19.1≡F-fran-zg, 24.1↔A-sachvers, 15.1↔A-telekom, 30.x↔A-sozvers; Titel/IDs vereinheitlichen; camt-Regeln umhängen).
