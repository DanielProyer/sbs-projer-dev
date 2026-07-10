# Betrieb-Lifecycle & Auto-„mein Kunde" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `istMeinKunde` automatisch aus Status + Zapfsystem ableiten (mit manuellem Override), den Bestand bereinigen, und dauerhaft geschlossene Betriebe mit Grund/Datum abbilden sowie inaktive/geschlossene aus Karte + Liste ausblenden.

**Architecture:** Flutter + Supabase + Riverpod (kIsWeb: Web = Supabase direkt). Eine reine, getestete Dart-Funktion kapselt die „mein Kunde"-Regel; das Betrieb-Formular ruft sie reaktiv auf. Zwei additive DB-Spalten + zweistufiger Backfill via Migration. Sichtbarkeit über bestehende Filter (Liste) bzw. neuen Karten-Toggle.

**Tech Stack:** Dart/Flutter, Supabase (MCP `apply_migration`/`execute_sql`), Isar (native) + Web-Stub, flutter_test.

**Referenz-Spec:** `docs/superpowers/specs/2026-07-10-betrieb-lifecycle-design.md`

**Reihenfolge:** Migration+Backfill (DB) → B-Funktion (TDD) → Model/Mapper → Formular → Detail → Liste/Karte → Verifikation+Deploy. **Deploy v0.26.0.**

**Vorab verifizierte Fakten (nicht erneut recherchieren):**
- `betriebe.status`-Werte: `aktiv` (290), `inaktiv` (12), `geschlossen` (104). `saisonpause` aktuell 0.
- 4 inaktiv-true: **Clavadeleralp**, **Weissfluhjoch** (beide `ist_saisonbetrieb=true`), **AMERON**, **Valentinos**. 104 geschlossen-true (0 saison, 0 ferien).
- „Konventionell/Orion" = **Zapfsysteme** (`betriebe.zapfsysteme`), Chips `['David','Konventionell','Higenie','Orion','Veranstaltungen']`.
- **Betrieb-DTO**: `sbs_projer_app/lib/data/models/betrieb.dart` — Felder + `fromJson`/`toJson`; Datums-Felder als `?.toIso8601String().split('T').first`.
- **Isar-Local (native)**: `sbs_projer_app/lib/data/local/betrieb_local.dart` (@Collection); **Web-Stub**: `sbs_projer_app/lib/data/local/web/betrieb_local_web.dart` (plain). `BetriebLocal.routeId => kIsWeb ? serverId! : id.toString()`.
- **Mapper**: `sbs_projer_app/lib/data/mappers/betrieb_mapper.dart` — `fromDto` (Zeile 6–63) + `toJson` (ab 65).
- **Formular**: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart` — State `_status` (Z.48), `_istMeinKunde` (Z.47), `_zapfsysteme` (Set<String>); Status-Dropdown Z.789–804 (Items aktiv/inaktiv/saisonpause); Zapfsystem-Chips Z.360–381 mit alter Inline-Auto-Regel Z.372–377; Save-Block ab Z.348 (`betrieb.status = _status;` Z.363, `betrieb.istMeinKunde = _istMeinKunde;` Z.364); `_loadBetrieb` setzt `_status`, `_istMeinKunde` (Z.120/124).
- **Detail**: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart` — Details-Karte Z.117–133 (`_InfoRow`-Zeilen). `_formatDate(DateTime)` existiert (Z.312).
- **Betriebe-Liste**: `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart` — `_statusFilter='alle'` (Z.19), Listen-Filter Z.30–49 (`if (_statusFilter != 'alle' && b.status != _statusFilter) return false;`); Karten-State `_karteNurMeine/_karteNurFaellig/_karteRegionId`; `_buildKarte` Z.261 mit `gefiltert`-where Z.270–275 und Filter-Row Z.287–302.
- Flutter-PATH in Bash: `export PATH="$PATH:/c/flutter/bin"`. Migration-Datei-Ablage: `Datenbank/migrations/`. Supabase project_id: `pltbaqqwpnmdajwgnhpd`.

---

## File Structure

**Neu:**
- `Datenbank/migrations/127_betrieb_lifecycle.sql` — DDL (2 Spalten) + zweistufiger Backfill.
- `sbs_projer_app/lib/core/util/betrieb_kunde.dart` — reine Funktion `istMeinKundeVorschlag`.
- `sbs_projer_app/test/betrieb_kunde_test.dart` — Tests.

**Geändert:**
- `betrieb.dart` (DTO), `betrieb_local.dart` (native), `web/betrieb_local_web.dart` (Stub), `betrieb_mapper.dart` — je 2 Felder `schliessungsgrund`/`schliessungsdatum`.
- `betrieb_form_screen.dart` — Status-Dropdown `geschlossen`, Auto-mein-Kunde, Schliessungsfelder.
- `betrieb_detail_screen.dart` — Schliessungsanzeige.
- `betriebe_list_screen.dart` — Default-Statusfilter `aktiv`, Karten-Toggle.
- `pubspec.yaml` — v0.26.0.

---

## Task 1: Migration 127 — Spalten + zweistufiger Backfill

**Files:**
- Create: `Datenbank/migrations/127_betrieb_lifecycle.sql`
- DB: via MCP `apply_migration` (project_id `pltbaqqwpnmdajwgnhpd`)

- [ ] **Step 1: Migrationsdatei schreiben** (`Datenbank/migrations/127_betrieb_lifecycle.sql`):

```sql
-- 127: Betrieb-Lifecycle
-- (1) Schliessungs-Doku fuer dauerhaft geschlossene Betriebe
-- (2) Bereinigung "mein Kunde": Saison != inaktiv

-- Spalten
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS schliessungsgrund text;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS schliessungsdatum date;

-- (a) Fehl-eingeordnete Saisonbetriebe zurueck auf aktiv (bleiben Kunde)
UPDATE betriebe SET status = 'aktiv'
WHERE status = 'inaktiv' AND ist_saisonbetrieb = true;

-- (b) Echte inaktive + geschlossene -> mein Kunde false; Saisonbetriebe geschuetzt
UPDATE betriebe SET ist_mein_kunde = false
WHERE status IN ('inaktiv', 'geschlossen')
  AND ist_saisonbetrieb = false
  AND ist_mein_kunde = true;
```

- [ ] **Step 2: Migration anwenden** (MCP `apply_migration`, name `betrieb_lifecycle`, query = Inhalt der Datei ohne die reinen Kommentarzeilen ist ok — der volle Text funktioniert ebenso).

Expected: `{"success": true}`.

- [ ] **Step 3: Backfill verifizieren** (MCP `execute_sql`):

```sql
SELECT
  (SELECT count(*) FROM betriebe WHERE name IN ('Clavadeleralp','Weissfluhjoch') AND status='aktiv' AND ist_mein_kunde) AS saison_aktiv_ok,
  (SELECT count(*) FROM betriebe WHERE status IN ('inaktiv','geschlossen') AND ist_saisonbetrieb=false AND ist_mein_kunde) AS noch_falsch,
  (SELECT count(*) FROM betriebe WHERE name IN ('AMERON','Valentinos') AND ist_mein_kunde=false) AS amveron_valentinos_false;
```

Expected: `saison_aktiv_ok = 2`, `noch_falsch = 0`, `amveron_valentinos_false = 2`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/127_betrieb_lifecycle.sql
git commit -m "feat(db): Migration 127 — Betrieb-Lifecycle (Schliessungsfelder + mein-Kunde-Bereinigung)"
```

---

## Task 2: Reine Funktion `istMeinKundeVorschlag` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/betrieb_kunde.dart`
- Test: `sbs_projer_app/test/betrieb_kunde_test.dart`

- [ ] **Step 1: Failing test schreiben** (`test/betrieb_kunde_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_kunde.dart';

void main() {
  group('istMeinKundeVorschlag', () {
    test('inaktiv -> false, auch mit Konventionell', () {
      expect(istMeinKundeVorschlag('inaktiv', ['Konventionell']), isFalse);
    });

    test('geschlossen -> false, auch mit Orion', () {
      expect(istMeinKundeVorschlag('geschlossen', ['Orion']), isFalse);
    });

    test('aktiv + Konventionell -> true', () {
      expect(istMeinKundeVorschlag('aktiv', ['Konventionell']), isTrue);
    });

    test('aktiv + Orion -> true', () {
      expect(istMeinKundeVorschlag('aktiv', ['David', 'Orion']), isTrue);
    });

    test('saisonpause + Konventionell -> true (weiterhin Kunde)', () {
      expect(istMeinKundeVorschlag('saisonpause', ['Konventionell']), isTrue);
    });

    test('aktiv + nur David/Higenie/Veranstaltungen -> false', () {
      expect(
          istMeinKundeVorschlag('aktiv', ['David', 'Higenie', 'Veranstaltungen']),
          isFalse);
    });

    test('aktiv + leere Zapfsysteme -> false', () {
      expect(istMeinKundeVorschlag('aktiv', const []), isFalse);
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/betrieb_kunde_test.dart`
Expected: FAIL (`istMeinKundeVorschlag` undefined).

- [ ] **Step 3: Implementieren** (`lib/core/util/betrieb_kunde.dart`):

```dart
/// Zapfsysteme, die einen Betrieb zu einem SBS-Kunden machen (werden von uns
/// serviciert & verrechnet).
const _kundenZapfsysteme = {'Konventionell', 'Orion'};

/// Vorschlag für den "mein Kunde"-Flag aus Status + Zapfsystemen.
///
/// - Status `inaktiv`/`geschlossen` -> immer false (kein Kunde mehr / weg).
/// - sonst (aktiv/saisonpause) -> true, wenn ein Kunden-Zapfsystem vorhanden ist.
///
/// Der zurückgegebene Wert ist nur ein Vorschlag; im Formular kann er manuell
/// übersteuert werden.
bool istMeinKundeVorschlag(String status, List<String> zapfsysteme) {
  if (status == 'inaktiv' || status == 'geschlossen') return false;
  return zapfsysteme.any(_kundenZapfsysteme.contains);
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/betrieb_kunde_test.dart`
Expected: PASS (7 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/betrieb_kunde.dart sbs_projer_app/test/betrieb_kunde_test.dart
git commit -m "feat(betrieb): reine Funktion istMeinKundeVorschlag (TDD)"
```

---

## Task 3: Schliessungsfelder in DTO, Local, Web-Stub, Mapper

**Files:**
- Modify: `sbs_projer_app/lib/data/models/betrieb.dart`
- Modify: `sbs_projer_app/lib/data/local/betrieb_local.dart`
- Modify: `sbs_projer_app/lib/data/local/web/betrieb_local_web.dart`
- Modify: `sbs_projer_app/lib/data/mappers/betrieb_mapper.dart`

- [ ] **Step 1: DTO-Felder** in `betrieb.dart` ergänzen.

Bei den Feld-Deklarationen (z.B. nach `final String rechnungsstellung;`):
```dart
  final String? schliessungsgrund;
  final DateTime? schliessungsdatum;
```
Im Konstruktor (bei den optionalen benannten Parametern):
```dart
    this.schliessungsgrund,
    this.schliessungsdatum,
```
In `factory Betrieb.fromJson` (bei den anderen Zuweisungen):
```dart
      schliessungsgrund: json['schliessungsgrund'],
      schliessungsdatum: json['schliessungsdatum'] != null
          ? DateTime.parse(json['schliessungsdatum'])
          : null,
```
In `Map<String,dynamic> toJson()`:
```dart
      'schliessungsgrund': schliessungsgrund,
      'schliessungsdatum': schliessungsdatum?.toIso8601String().split('T').first,
```

- [ ] **Step 2: Native Isar-Local** in `betrieb_local.dart` ergänzen (bei den Feldern, z.B. nach `String rechnungsstellung = 'rechnung_mail';`):
```dart
  String? schliessungsgrund;
  DateTime? schliessungsdatum;
```

- [ ] **Step 3: Web-Stub** in `web/betrieb_local_web.dart` — dieselben zwei Felder an gleicher Stelle:
```dart
  String? schliessungsgrund;
  DateTime? schliessungsdatum;
```

- [ ] **Step 4: Mapper** in `betrieb_mapper.dart`.

In `fromDto` (z.B. nach `local.rechnungsstellung = dto.rechnungsstellung;`):
```dart
    local.schliessungsgrund = dto.schliessungsgrund;
    local.schliessungsdatum = dto.schliessungsdatum;
```
In `toJson` (bei den anderen Feldern, vor `if (local.serverId != null)`):
```dart
      'schliessungsgrund': local.schliessungsgrund,
      'schliessungsdatum':
          local.schliessungsdatum?.toIso8601String().split('T').first,
```

- [ ] **Step 5: Isar-Code generieren** (native @Collection wurde geändert)

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && dart run build_runner build --delete-conflicting-outputs`
Expected: „Succeeded" (regeneriert `betrieb_local.g.dart`). Hinweis: `.g.dart` ist gitignored — nicht committen.

- [ ] **Step 6: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/data/models/betrieb.dart lib/data/local/betrieb_local.dart lib/data/local/web/betrieb_local_web.dart lib/data/mappers/betrieb_mapper.dart`
Expected: keine neuen Findings.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/data/models/betrieb.dart sbs_projer_app/lib/data/local/betrieb_local.dart sbs_projer_app/lib/data/local/web/betrieb_local_web.dart sbs_projer_app/lib/data/mappers/betrieb_mapper.dart
git commit -m "feat(betrieb): schliessungsgrund + schliessungsdatum durch DTO/Local/Mapper"
```

---

## Task 4: Formular — Status `geschlossen`, Auto-mein-Kunde, Schliessungsfelder

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart`

- [ ] **Step 1: Import der reinen Funktion** oben ergänzen:
```dart
import 'package:sbs_projer_app/core/util/betrieb_kunde.dart';
```

- [ ] **Step 2: State-Felder** (neben `_status`/`_istMeinKunde`):
```dart
  String? _schliessungsgrund;
  DateTime? _schliessungsdatum;
```

- [ ] **Step 3: Laden** in `_loadBetrieb` (im setState-Block, bei `_status = betrieb.status;`):
```dart
      _schliessungsgrund = betrieb.schliessungsgrund;
      _schliessungsdatum = betrieb.schliessungsdatum;
```

- [ ] **Step 4: `geschlossen` ins Status-Dropdown** — die `items`-Liste (aktuell aktiv/inaktiv/saisonpause) um einen Eintrag ergänzen:
```dart
                DropdownMenuItem(value: 'aktiv', child: Text('Aktiv')),
                DropdownMenuItem(value: 'inaktiv', child: Text('Inaktiv')),
                DropdownMenuItem(
                    value: 'saisonpause', child: Text('Saisonpause')),
                DropdownMenuItem(
                    value: 'geschlossen', child: Text('Geschlossen (dauerhaft)')),
```

- [ ] **Step 5: Status-`onChanged` → Auto-mein-Kunde**. Den bestehenden Status-`onChanged` ersetzen durch:
```dart
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _status = v;
                    _istMeinKunde = istMeinKundeVorschlag(
                        _status, _zapfsysteme.toList());
                    if (_status != 'geschlossen') {
                      _schliessungsgrund = null;
                      _schliessungsdatum = null;
                    }
                  });
                }
              },
```

- [ ] **Step 6: Zapfsystem-`onChanged` → dieselbe Regel** (alte Inline-Regel Z.372–377 ersetzen). Der Chip-`onSelected`-Block wird zu:
```dart
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _zapfsysteme.add(system);
                      } else {
                        _zapfsysteme.remove(system);
                      }
                      _istMeinKunde = istMeinKundeVorschlag(
                          _status, _zapfsysteme.toList());
                    });
                  },
```

- [ ] **Step 7: Schliessungsfelder rendern** — direkt nach dem Status-Dropdown (nach dessen schliessender `),` und der folgenden `SizedBox`), nur bei `geschlossen`:
```dart
            if (_status == 'geschlossen') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _schliessungsgrund,
                decoration: const InputDecoration(
                  labelText: 'Schliessungsgrund',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'umnutzung', child: Text('Umnutzung')),
                  DropdownMenuItem(value: 'abbruch', child: Text('Abbruch')),
                  DropdownMenuItem(value: 'konkurs', child: Text('Konkurs')),
                  DropdownMenuItem(value: 'sonstiges', child: Text('Sonstiges')),
                ],
                onChanged: (v) => setState(() => _schliessungsgrund = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _schliessungsdatum ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _schliessungsdatum = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Schliessungsdatum',
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(_schliessungsdatum == null
                      ? 'Datum wählen'
                      : '${_schliessungsdatum!.day.toString().padLeft(2, '0')}.'
                          '${_schliessungsdatum!.month.toString().padLeft(2, '0')}.'
                          '${_schliessungsdatum!.year}'),
                ),
              ),
            ],
```

- [ ] **Step 8: Speichern** — im Save-Block (nach `betrieb.status = _status;`) ergänzen:
```dart
      betrieb.schliessungsgrund =
          _status == 'geschlossen' ? _schliessungsgrund : null;
      betrieb.schliessungsdatum =
          _status == 'geschlossen' ? _schliessungsdatum : null;
```
Sicherstellen, dass `betrieb.istMeinKunde = _istMeinKunde;` unverändert bleibt (Schalterwert = Override).

- [ ] **Step 9: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betrieb_form_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 10: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(betrieb): Formular — Status geschlossen, Auto-mein-Kunde, Schliessungsfelder"
```

---

## Task 5: Detail — Schliessung anzeigen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart`

- [ ] **Step 1: Anzeige-Zeilen** in der Details-Karte (nach der `if (betrieb.istMeinKunde) _InfoRow('Rechnungsstellung', …)`-Zeile bzw. innerhalb der `children:`-Liste) ergänzen:
```dart
              if (betrieb.status == 'geschlossen') ...[
                _InfoRow('Schliessungsgrund',
                    _schliessungsgrundLabel(betrieb.schliessungsgrund)),
                if (betrieb.schliessungsdatum != null)
                  _InfoRow('Schliessungsdatum',
                      _formatDate(betrieb.schliessungsdatum!)),
              ],
```

- [ ] **Step 2: Label-Helfer** in derselben Klasse (`_BetriebDetailContent`), neben `_rechnungsstellungLabel`:
```dart
  String _schliessungsgrundLabel(String? value) {
    switch (value) {
      case 'umnutzung': return 'Umnutzung';
      case 'abbruch': return 'Abbruch';
      case 'konkurs': return 'Konkurs';
      case 'sonstiges': return 'Sonstiges';
      default: return '–';
    }
  }
```

- [ ] **Step 3: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betrieb_detail_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart
git commit -m "feat(betrieb): Detail zeigt Schliessungsgrund/-datum bei geschlossen"
```

---

## Task 6: Betriebe-Liste Default + Karten-Sichtbarkeit

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart`

- [ ] **Step 1: Default-Statusfilter** auf `aktiv` setzen. Zeile
```dart
  String _statusFilter = 'alle';
```
ändern zu:
```dart
  String _statusFilter = 'aktiv';
```

- [ ] **Step 2: Karten-Toggle-State** bei den anderen Karten-Feldern ergänzen:
```dart
  bool _karteZeigeInaktiv = false;
```

- [ ] **Step 3: Karten-Filter** — in `_buildKarte` die `gefiltert`-Bedingung um die Sichtbarkeitsregel erweitern. Der `where`-Block wird zu:
```dart
    final gefiltert = alle.where((b) {
      if (!_karteZeigeInaktiv &&
          b.status != 'aktiv' &&
          b.status != 'saisonpause') {
        return false;
      }
      if (_karteNurMeine && !b.istMeinKunde) return false;
      if (_karteRegionId != null && b.regionId != _karteRegionId) return false;
      if (_karteNurFaellig && !istFaellig(statusFuer(b))) return false;
      return true;
    }).toList();
```

- [ ] **Step 4: Toggle-Chip** in der Karten-Filter-Row (nach dem „Nur fällige"-`FilterChip`, vor der Region-Dropdown) ergänzen:
```dart
              FilterChip(
                label: const Text('Inaktive/geschl.'),
                selected: _karteZeigeInaktiv,
                onSelected: (v) => setState(() => _karteZeigeInaktiv = v),
              ),
              const SizedBox(width: 8),
```

- [ ] **Step 5: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/betriebe/betriebe_list_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart
git commit -m "feat(betrieb): Liste default nur aktive, Karte blendet inaktive/geschlossene aus"
```

---

## Task 7: Gesamtverifikation + Deploy v0.26.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Version bumpen** — `pubspec.yaml` Zeile 4: `version: 0.25.2+494` → `version: 0.26.0+495`.

- [ ] **Step 2: Volle Analyse + alle Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze && flutter test`
Expected: keine neuen Analyze-Findings; alle Tests grün (inkl. `betrieb_kunde_test`).

- [ ] **Step 3: Web-Build**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none`
Expected: `√ Built build\web`.

- [ ] **Step 4: Visueller Browser-Test (Pflicht)** — im Web-Build prüfen:
  - Formular: Status `aktiv`+Konventionell → „mein Kunde" an; auf `inaktiv` → aus; zurück auf `aktiv` → an; danach Schalter manuell umlegen und speichern → Override bleibt.
  - Status `geschlossen` → Schliessungsgrund + -datum erscheinen; speichern; Detail zeigt beide; auf `aktiv` zurück → Felder verschwinden, Werte werden geleert.
  - Betriebe-Liste: zeigt default nur **aktive**; über Filter `geschlossen` sichtbar.
  - Karte: default keine inaktiven/geschlossenen Marker; Chip „Inaktive/geschl." blendet sie ein (grau).

- [ ] **Step 5: Version-Commit**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.26.0+495 (Betrieb-Lifecycle)"
```

- [ ] **Step 6: Deploy nach gh-pages** (Workflow aus CLAUDE.md; vorher `main` pushen; **kein** `git stash`)

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.26.0 — Betrieb-Lifecycle (Auto-mein-Kunde, Schliessung, Sichtbarkeit)"
git push origin gh-pages
git checkout main
git push origin main
```

---

## Ausführungsreihenfolge

Task 1 → 2 → 3 → 4 → 5 → 6 → 7. Jede Task ist eigenständig committbar; die UI-Tasks (4–6) werden im Abschluss-Task 7 einmal gesammelt visuell verifiziert und deployt.
