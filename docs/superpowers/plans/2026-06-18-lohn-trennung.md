# Lohn-Trennung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lohn-Einstellungen auf die variablen Sätze (Sozialversicherung + BVG) reduzieren, die fixen Arbeitnehmer-Stammdaten ins Geschäft verlagern, und die operative Lohnbuchhaltung von Einstellungs-Verweisen befreien.

**Architecture:** Geschäft-Tabelle/Model um AHV-Nr.+Geburtsdatum erweitern (Migration kopiert Altdaten). `LohnEinstellungen`-Schema bleibt; AN/AG werden beim Speichern als Snapshot aus dem Geschäft gesetzt (Lohnausweis unverändert). UI: Lohn-Einstellungen = nur Sätze; Lohnbuchhaltung ohne Settings-Buttons; Settings-Kachel korrekt verlinkt.

**Tech Stack:** Flutter, Riverpod, Supabase, `pdf`/`printing`.

**Spec:** `docs/superpowers/specs/2026-06-18-lohn-trennung-design.md`

**Arbeitsverzeichnis:** `flutter`-Befehle in `sbs_projer_app/`. DB via Supabase MCP (`apply_migration`, project_id `pltbaqqwpnmdajwgnhpd`).

---

## Datei-Übersicht
- **Neu:** `Datenbank/migrations/098_geschaeft_an_stammdaten.sql`
- **Geändert:** `data/models/geschaeft_einstellungen.dart` (+test), `services/buchhaltung/geschaeft_mapping.dart` (+test), `presentation/screens/einstellungen/widgets/geschaeft_form.dart`, `presentation/screens/buchhaltung/lohn_einstellungen_screen.dart`, `presentation/screens/buchhaltung/lohnlauf_screen.dart`, `presentation/screens/einstellungen/einstellungen_screen.dart`

---

## Task L1: Migration 098 — Geschäft um AN-Stammdaten erweitern

**Files:** Create `Datenbank/migrations/098_geschaeft_an_stammdaten.sql`

- [ ] **Step 1: SQL schreiben**

```sql
-- 098_geschaeft_an_stammdaten.sql
-- Arbeitnehmer-Stammdaten (AHV-Nr., Geburtsdatum) wandern ins Geschäft
-- (beim Geschäftsführer = einziger Arbeitnehmer).
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_ahv_nr text;
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_geburtsdatum date;

-- Bestehende AN-Stammdaten aus der neuesten Lohn-Einstellung übernehmen (kein Datenverlust).
UPDATE geschaeft_einstellungen g
SET gf_ahv_nr = COALESCE(g.gf_ahv_nr, le.arbeitnehmer_ahv_nr),
    gf_geburtsdatum = COALESCE(g.gf_geburtsdatum, le.arbeitnehmer_geburtsdatum)
FROM (
  SELECT DISTINCT ON (user_id) user_id, arbeitnehmer_ahv_nr, arbeitnehmer_geburtsdatum
  FROM lohn_einstellungen ORDER BY user_id, jahr DESC
) le
WHERE le.user_id = g.user_id;
```

- [ ] **Step 2: Anwenden (MCP `apply_migration`)** — name `geschaeft_an_stammdaten`, project_id `pltbaqqwpnmdajwgnhpd`, query = obiger Inhalt. Expected `{"success":true}`.

- [ ] **Step 3: Verifizieren (`execute_sql`)**: `SELECT gf_ahv_nr, gf_geburtsdatum FROM geschaeft_einstellungen WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2';` → eine Zeile (Werte ggf. null, falls in Lohn nie erfasst — ok).

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/098_geschaeft_an_stammdaten.sql
git commit -m "feat(db): Geschäft um AHV-Nr.+Geburtsdatum (Migration 098, Altdaten übernommen)"
```

---

## Task L2: Model — gfAhvNr / gfGeburtsdatum / gfGeburtsjahr

**Files:**
- Modify: `sbs_projer_app/lib/data/models/geschaeft_einstellungen.dart`
- Test: `sbs_projer_app/test/data/models/geschaeft_einstellungen_test.dart`

- [ ] **Step 1: Failing test** — am Ende der `main()` in `geschaeft_einstellungen_test.dart` ergänzen:

```dart
  test('gfGeburtsjahr aus Geburtsdatum, sonst 1990; AN-Felder via JSON', () {
    final g = GeschaeftEinstellungen(gfGeburtsdatum: DateTime(1985, 4, 12), gfAhvNr: '756.1234.5678.90');
    expect(g.gfGeburtsjahr, 1985);
    expect(const GeschaeftEinstellungen().gfGeburtsjahr, 1990);
    final json = g.toJson();
    expect(json['gf_ahv_nr'], '756.1234.5678.90');
    expect(json['gf_geburtsdatum'], '1985-04-12');
    final back = GeschaeftEinstellungen.fromJson({'id': '1', 'user_id': 'u', 'gf_geburtsdatum': '1985-04-12'});
    expect(back.gfGeburtsdatum, DateTime(1985, 4, 12));
  });
```

- [ ] **Step 2: Run → fails** (`cd sbs_projer_app && flutter test test/data/models/geschaeft_einstellungen_test.dart`).

- [ ] **Step 3: Implement** — in `geschaeft_einstellungen.dart`:
  1. Felder + Konstruktor-Parameter ergänzen (nach `uidNummer`): `final String? gfAhvNr;` `final DateTime? gfGeburtsdatum;` und im `const`-Konstruktor `this.gfAhvNr,` `this.gfGeburtsdatum,`.
  2. Getter ergänzen (z. B. nach `mailEmpfaenger`): `int get gfGeburtsjahr => gfGeburtsdatum?.year ?? 1990;`
  3. In `fromJson` ergänzen: `gfAhvNr: j['gf_ahv_nr'],` und `gfGeburtsdatum: j['gf_geburtsdatum'] != null ? DateTime.parse(j['gf_geburtsdatum']) : null,`.
  4. In `toJson` ergänzen: `'gf_ahv_nr': gfAhvNr,` und `'gf_geburtsdatum': gfGeburtsdatum?.toIso8601String().split('T').first,`.

- [ ] **Step 4: Run → passes** (alle Tests in der Datei grün).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/data/models/geschaeft_einstellungen.dart sbs_projer_app/test/data/models/geschaeft_einstellungen_test.dart
git commit -m "feat(geschaeft): AHV-Nr. + Geburtsdatum + gfGeburtsjahr"
```

---

## Task L3: Mapping — arbeitnehmer(g) statt arbeitnehmerPrefill

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/geschaeft_mapping.dart`
- Test: `sbs_projer_app/test/services/buchhaltung/geschaeft_mapping_test.dart`

- [ ] **Step 1: Test ersetzen** — `geschaeft_mapping_test.dart` komplett ersetzen mit:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';

void main() {
  final g = GeschaeftEinstellungen(
    firmaName: 'SBS Projer GmbH',
    strasse: 'Via Rezia 8',
    plzOrt: '7013 Domat/Ems',
    gfVorname: 'Daniel',
    gfName: 'Projer',
    gfAhvNr: '756.1234.5678.90',
    gfGeburtsdatum: DateTime(1985, 4, 12),
  );

  test('arbeitgeber liefert Firma/Strasse/PLZ-Ort aus Geschäft', () {
    final ag = GeschaeftMapping.arbeitgeber(g);
    expect(ag.name, 'SBS Projer GmbH');
    expect(ag.adresse, 'Via Rezia 8');
    expect(ag.plzOrt, '7013 Domat/Ems');
  });

  test('arbeitnehmer liefert vollständigen Snapshot inkl. Geburtsjahr', () {
    final an = GeschaeftMapping.arbeitnehmer(g);
    expect(an.name, 'Projer');
    expect(an.vorname, 'Daniel');
    expect(an.adresse, 'Via Rezia 8');
    expect(an.plzOrt, '7013 Domat/Ems');
    expect(an.ahvNr, '756.1234.5678.90');
    expect(an.geburtsdatum, DateTime(1985, 4, 12));
    expect(an.geburtsjahr, 1985);
  });

  test('arbeitnehmer ohne Geburtsdatum → Geburtsjahr 1990', () {
    final an = GeschaeftMapping.arbeitnehmer(const GeschaeftEinstellungen());
    expect(an.geburtsjahr, 1990);
    expect(an.geburtsdatum, isNull);
  });
}
```

- [ ] **Step 2: Run → fails.**

- [ ] **Step 3: Implement** — `geschaeft_mapping.dart` ersetzen mit:

```dart
// lib/services/buchhaltung/geschaeft_mapping.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

class GeschaeftMapping {
  /// Arbeitgeber-Felder für den Lohnausweis aus dem Geschäft.
  static ({String name, String adresse, String plzOrt}) arbeitgeber(GeschaeftEinstellungen g) =>
      (name: g.firma, adresse: g.adresseStrasse, plzOrt: g.adressePlzOrt);

  /// Vollständiger Arbeitnehmer-Snapshot aus dem Geschäft (GF = einziger AN).
  static ({
    String? name,
    String? vorname,
    String? adresse,
    String? plzOrt,
    String? ahvNr,
    DateTime? geburtsdatum,
    int geburtsjahr,
  }) arbeitnehmer(GeschaeftEinstellungen g) => (
        name: g.gfName,
        vorname: g.gfVorname,
        adresse: g.adresseStrasse,
        plzOrt: g.adressePlzOrt,
        ahvNr: g.gfAhvNr,
        geburtsdatum: g.gfGeburtsdatum,
        geburtsjahr: g.gfGeburtsjahr,
      );
}
```

(Das alte `typedef AnFelder` und `arbeitnehmerPrefill` fallen weg.)

- [ ] **Step 4: Run → passes (3 tests).** Auch `flutter analyze lib/services/buchhaltung/geschaeft_mapping.dart`.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/geschaeft_mapping.dart sbs_projer_app/test/services/buchhaltung/geschaeft_mapping_test.dart
git commit -m "feat(geschaeft): Mapping arbeitnehmer(g) (voller Snapshot) statt Prefill"
```

---

## Task L4: Geschäft-Form — AHV-Nr. + Geburtsdatum

**Files:** Modify `sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart`

- [ ] **Step 1: Importe + Datums-Helfer.** Oben ergänzen: `import 'package:intl/intl.dart';`. In `_GeschaeftFormState` zwei statische Helfer ergänzen:

```dart
  static final _df = DateFormat('dd.MM.yyyy');

  static DateTime? _parseDatum(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final p = t.split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
```

- [ ] **Step 2: Controller ergänzen.** In `initState`, im `_c`-Map zwei Einträge dazu:

```dart
      'gf_ahv_nr': TextEditingController(text: g.gfAhvNr ?? ''),
      'gf_geburtsdatum': TextEditingController(
          text: g.gfGeburtsdatum != null ? _df.format(g.gfGeburtsdatum!) : ''),
```

- [ ] **Step 3: Felder anzeigen.** In `build`, direkt nach `_field('gf_name', 'Name'),` (unter „Geschäftsführer") ergänzen:

```dart
        _field('gf_ahv_nr', 'AHV-Nr. (756.xxxx.xxxx.xx)'),
        _field('gf_geburtsdatum', 'Geburtsdatum (TT.MM.JJJJ)'),
```

- [ ] **Step 4: Speichern mit Datums-Konvertierung.** In `_save()` den `GeschaeftRepository.save(...)`-Aufruf ersetzen durch:

```dart
      final fields = <String, dynamic>{
        for (final e in _c.entries) e.key: e.value.text.trim()
      };
      fields['gf_geburtsdatum'] =
          _parseDatum(_c['gf_geburtsdatum']!.text)?.toIso8601String().split('T').first;
      await GeschaeftRepository.save(fields);
```

- [ ] **Step 5: Analyze.** `cd sbs_projer_app && flutter analyze lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart`. Expected: keine Errors.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart
git commit -m "feat(geschaeft): Form-Felder AHV-Nr. + Geburtsdatum"
```

---

## Task L5: Lohn-Einstellungen-Screen — nur noch Sätze

**Files:** Modify `sbs_projer_app/lib/presentation/screens/buchhaltung/lohn_einstellungen_screen.dart`

Read the file first. Ziel: nur „Sozialversicherungen — Sätze (%)" + „BVG / Pensionskasse — Fixbeträge" bleiben. Grunddaten (Geburtsjahr), Arbeitnehmer-Block und Arbeitgeber-Read-only-Block raus. AN/AG/geburtsjahr werden beim Speichern aus dem Geschäft gesetzt.

- [ ] **Step 1: Import ergänzen** (falls nicht vorhanden): `import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';` (geschaeft_einstellungen + geschaeft_providers sind aus G7 bereits importiert).

- [ ] **Step 2: Controller entfernen.** Löschen: `_geburtsjahr` und die AN-Controller `_nameCtrl`, `_vornameCtrl`, `_adresseCtrl`, `_plzOrtCtrl`, `_ahvNrCtrl`, `_gebDatumCtrl` (Deklarationen). Aus der `dispose()`-Liste entfernen.

- [ ] **Step 3: `_fillFromEinstellungen`** auf die Satz-Zeilen reduzieren — nur die Zuweisungen für `_ahvAnCtrl … _ktgAgCtrl` behalten; die Zeilen für `_geburtsjahr`, `_nameCtrl … _gebDatumCtrl` löschen.

- [ ] **Step 4: `build`-Ladeblock vereinfachen.** Den in G7 eingefügten AN-Prefill-Block ersetzen durch reines Laden der Sätze (geschaeft wird nur noch beim Speichern gebraucht):

```dart
    if (!_loaded && !einst.isLoading) {
      final e = einst.valueOrNull;
      if (e != null) _fillFromEinstellungen(e);
      _loaded = true;
    }
```

Die Zeilen `final geschaeftAsync = ...` / `final geschaeft = ...` aus `build` entfernen; `data: (_) => _buildForm()` (ohne Parameter).

- [ ] **Step 5: `_buildForm()`** — Signatur zurück auf `Widget _buildForm()`. Entfernen: die Section „Grunddaten" (+ `_numberField(_geburtsjahr, …)`), die Section „Lohnausweis — Arbeitnehmer" (+ ihre `_textField`), und den Read-only-Arbeitgeber-Block. **Behalten:** „Sozialversicherungen — Sätze (%)" und „BVG / Pensionskasse — Fixbeträge" + Speichern-Button.

- [ ] **Step 6: `_save()`** — AN/AG/geburtsjahr aus Geschäft. Vor dem `LohnEinstellungen(...)`-Aufbau:

```dart
      final geschaeft = ref.read(geschaeftProvider).valueOrNull ?? const GeschaeftEinstellungen();
      final an = GeschaeftMapping.arbeitnehmer(geschaeft);
      final ag = GeschaeftMapping.arbeitgeber(geschaeft);
```

Im `LohnEinstellungen(...)`-Konstruktor:
- `geburtsjahr:` → `an.geburtsjahr`
- die `arbeitnehmer*`-Felder → `an.name / an.vorname / an.adresse / an.plzOrt / an.ahvNr / an.geburtsdatum`
- die `arbeitgeber*`-Felder → `ag.name / ag.adresse / ag.plzOrt`

(Die Sätze kommen weiterhin aus den Controllern wie bisher.)

- [ ] **Step 7: Analyze + Tests.** `cd sbs_projer_app && flutter analyze && flutter test`. Expected: 0 Errors; alle Tests grün. (Falls ein entfernter Controller noch referenziert wird, meldet analyze es → restlos entfernen.)

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/lohn_einstellungen_screen.dart
git commit -m "feat(lohn): Lohn-Einstellungen nur noch Sätze; AN/AG-Snapshot aus Geschäft"
```

---

## Task L6: Lohnbuchhaltung ohne Einstellungs-Verweise

**Files:** Modify `sbs_projer_app/lib/presentation/screens/buchhaltung/lohnlauf_screen.dart`

Read the file first (`_buildNoSettings` ~Z.86–116, der „Einstellungen"-Button in `_buildContent` ~Z.170–180).

- [ ] **Step 1: `_buildNoSettings` — Button durch Hinweis ersetzen.** Den `ElevatedButton/FilledButton.icon` mit „Einstellungen öffnen" (`context.push('/buchhaltung/lohn/einstellungen')`) entfernen und durch einen reinen Hinweistext ersetzen:

```dart
            const Text(
              'Sätze unter Einstellungen → Lohn-Einstellungen erfassen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
```

- [ ] **Step 2: „Einstellungen"-Button in `_buildContent` entfernen.** Den `TextButton`/Button mit Label „Einstellungen" und `context.push('/buchhaltung/lohn/einstellungen')` (~Z.177) ersatzlos entfernen.

- [ ] **Step 3: Ungenutzte Imports.** Falls `go_router`/`context.push` danach in der Datei nicht mehr verwendet wird, den Import entfernen (analyze meldet „unused_import"). Falls `context` noch anderweitig gebraucht wird, Import belassen.

- [ ] **Step 4: Analyze.** `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/lohnlauf_screen.dart`. Expected: keine Errors.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/lohnlauf_screen.dart
git commit -m "feat(lohn): Lohnbuchhaltung ohne Einstellungs-Verweise (nur Hinweis)"
```

---

## Task L7: Routing-Fix Settings-Kachel

**Files:** Modify `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

- [ ] **Step 1: onTap korrigieren.** In der „Lohn-Einstellungen"-`ListTile` (aus G6) den `onTap` ändern:

```dart
                  onTap: () => context.push('/buchhaltung/lohn/einstellungen'),
```

- [ ] **Step 2: Analyze.** `cd sbs_projer_app && flutter analyze lib/presentation/screens/einstellungen/einstellungen_screen.dart`. Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "fix(einstellungen): Lohn-Einstellungen-Kachel öffnet die Sätze statt der Lohnbuchhaltung"
```

---

## Task L8: Gesamt-Verifikation + Deploy

**Files:** keine Code-Änderung.

- [ ] **Step 1: Voll-Analyse + Tests.** `cd sbs_projer_app && flutter analyze && flutter test`. Expected: 0 Errors; alle Tests grün.

- [ ] **Step 2: Manueller Klicktest (Web).** `cd sbs_projer_app && flutter run -d edge`. Prüfen:
  - Einstellungen → Geschäft: AHV-Nr. + Geburtsdatum erfassbar/speicherbar.
  - Einstellungen → „Lohn-Einstellungen" öffnet den **Sätze**-Screen (nur Sätze + BVG, keine AN/AG-Felder).
  - Buchhaltung → Lohnbuchhaltung: keine Einstellungs-Buttons; Leer-Zustand zeigt Hinweis; Lohnlauf + Lohnausweis funktionieren (AN/AG aus Geschäft).
- [ ] **Step 3: Version bump + Deploy** (gemäss `CLAUDE.md`): `pubspec.yaml` Zeile 4 erhöhen, Build, Cache-Bust, gh-pages-Deploy. (Nach Freigabe durch Daniel.)

---

## Self-Review (vom Plan-Autor)
- **Spec-Abdeckung:** Migration+Altdaten (L1) ✓; Model AHV/Geburtsdatum/Geburtsjahr (L2) ✓; Mapping arbeitnehmer(g), Prefill entfernt (L3) ✓; Geschäft-Form-Felder (L4) ✓; Lohn-Einstellungen nur Sätze + AN/AG-Snapshot (L5) ✓; Lohnbuchhaltung ohne Verweise (L6) ✓; Routing-Fix (L7) ✓; Verifikation/Deploy (L8) ✓.
- **Typ-Konsistenz:** `GeschaeftEinstellungen.gfAhvNr/gfGeburtsdatum/gfGeburtsjahr` (L2) in L3/L4/L5 genutzt; `GeschaeftMapping.arbeitnehmer(g)`-Record-Felder (name/vorname/adresse/plzOrt/ahvNr/geburtsdatum/geburtsjahr) in L5 verwendet; `arbeitgeber(g)` (bestehend) in L5; `geschaeftProvider` (vorhanden) in L5.
- **Kompilierbarkeit:** L2/L3 (Model+Mapping) zuerst, dann UI; `LohnEinstellungen`-Schema unverändert → Lohnausweis/Lohnlauf intakt; jeder Task committet eigenständig.
- **Lücke geprüft:** AN-Prefill-Test (alt) wird in L3 durch arbeitnehmer-Tests ersetzt — kein verwaister Test.
