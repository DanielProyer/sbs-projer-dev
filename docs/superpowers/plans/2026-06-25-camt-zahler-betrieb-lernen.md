# TP-B — Zahler→Betrieb-Lernen (Alias am Betrieb) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der camt-Forderungsabgleich lernt bei jeder manuellen Zuordnung den Zahlernamen → Betrieb (gespeichert als `betriebe.zahler_aliase`) und nutzt ihn beim nächsten Import als deterministische Matching-Stufe vor dem unscharfen Namensvergleich.

**Architecture:** Aliase werden **direkt am Betrieb** gehalten (Feld `zahler_aliase text[]`, im Form bearbeitbar) — keine separate Tabelle (Entscheidung Daniel 25.06.2026, siehe Spec). Matching-Kette: Stufe 2 = exakter Alias-Treffer (genau ein Betrieb), sonst Stufe 3 = bestehender unscharfer `CamtBetriebMatcher.findBestMatch`. Lernen passiert in den manuellen Zuordnungs-Dialogen (`_oeffneManuell`, `_ordneZu`) über `BetriebRepository.addZahlerAlias`, mit Konflikt-Check gegen andere Betriebe. Alle Vergleiche laufen über die reine Normalisierungsfunktion `zahlernameNorm`.

**Tech Stack:** Flutter (Dart) + Riverpod, Supabase (PostgREST, `text[]` nativ) + Isar (offline, `List<String>` nativ wie `ruhetage`/`zapfsysteme`). Tests: `flutter_test`. Bash mit `export PATH="$PATH:/c/flutter/bin"`, App-Verzeichnis `sbs_projer_app`.

**Spec:** `docs/superpowers/specs/2026-06-20-camt-import-forderungsabgleich-merge-design.md` (Abschnitt „Zahler→Betrieb-Lernen (Alias)").

---

## Hinweise für alle Tasks

- Alle `flutter`/`dart`-Befehle laufen aus `sbs_projer_app`. Vorher in der Bash-Session einmal:
  ```bash
  export PATH="$PATH:/c/flutter/bin"
  cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
  ```
- Bestehendes Vorbild für `List<String>`-Felder am Betrieb: `ruhetage` / `zapfsysteme` (direktes `List<String>`-Feld, **kein** JSON-Puffer). `zahlerAliase` exakt analog.
- Die gespeicherten Aliase sind **immer normalisiert** (`zahlernameNorm`). Beim Vergleich trotzdem defensiv erneut normalisieren.

---

## Task 1: DB-Migration — Spalte `betriebe.zahler_aliase`

**Files:**
- Create: `Datenbank/migrations/103_betrieb_zahler_aliase.sql`

- [ ] **Step 1: Migrations-Datei schreiben**

Create `Datenbank/migrations/103_betrieb_zahler_aliase.sql`:

```sql
-- Migration 103: Zahlernamen-Aliase für Betriebe (TP-B Zahler→Betrieb-Lernen)
-- Speichert je Betrieb die (normalisierten) Bank-Zahlernamen, unter denen er zahlt.
-- Wird beim camt-Forderungsabgleich gelernt (manuelle Zuordnung) und als
-- deterministische Matching-Stufe vor dem unscharfen Namensvergleich angewandt.
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS zahler_aliase text[] NOT NULL DEFAULT '{}';
```

- [ ] **Step 2: Migration auf Supabase anwenden**

Über den Supabase-MCP (Projekt-ID `pltbaqqwpnmdajwgnhpd`):
`mcp__supabase__apply_migration` mit `name: "betrieb_zahler_aliase"` und dem `query` aus Step 1 (nur das `ALTER TABLE`).

Erwartung: Erfolg, keine Fehlermeldung.

- [ ] **Step 3: Spalte verifizieren**

`mcp__supabase__execute_sql`:
```sql
select column_name, data_type, column_default
from information_schema.columns
where table_name = 'betriebe' and column_name = 'zahler_aliase';
```
Erwartung: eine Zeile, `data_type = ARRAY`, `column_default = '{}'::text[]`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/103_betrieb_zahler_aliase.sql
git commit -m "feat(db): Migration 103 — betriebe.zahler_aliase (TP-B)"
```

---

## Task 2: Feld `zahlerAliase` im Datenmodell (DTO, Isar, Web-Stub, Mapper)

**Files:**
- Modify: `sbs_projer_app/lib/data/models/betrieb.dart`
- Modify: `sbs_projer_app/lib/data/local/betrieb_local.dart`
- Modify: `sbs_projer_app/lib/data/local/web/betrieb_local_web.dart`
- Modify: `sbs_projer_app/lib/data/mappers/betrieb_mapper.dart`
- Test: `sbs_projer_app/test/betrieb_mapper_test.dart`

- [ ] **Step 1: Failing-Test für Mapper-Round-Trip schreiben**

Create `sbs_projer_app/test/betrieb_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';

void main() {
  test('zahlerAliase überlebt DTO→Local→JSON', () {
    final dto = Betrieb(
      id: 'b1',
      userId: 'u1',
      name: 'Hotel Alpina',
      zahlerAliase: const ['hotel alpina ag', 'alpina gastro'],
    );
    final local = BetriebMapper.fromDto(dto);
    expect(local.zahlerAliase, ['hotel alpina ag', 'alpina gastro']);

    final json = BetriebMapper.toJson(local);
    expect(json['zahler_aliase'], ['hotel alpina ag', 'alpina gastro']);
  });

  test('fromJson liest zahler_aliase (oder leer wenn fehlt)', () {
    final mit = Betrieb.fromJson({
      'id': 'b1', 'user_id': 'u1', 'name': 'X',
      'zahler_aliase': ['a', 'b'],
    });
    expect(mit.zahlerAliase, ['a', 'b']);

    final ohne = Betrieb.fromJson({'id': 'b2', 'user_id': 'u1', 'name': 'Y'});
    expect(ohne.zahlerAliase, isEmpty);
  });
}
```

- [ ] **Step 2: Test ausführen → muss fehlschlagen (Compile-Fehler: `zahlerAliase` existiert nicht)**

```bash
flutter test test/betrieb_mapper_test.dart
```
Erwartung: FAIL (`The named parameter 'zahlerAliase' isn't defined` / `getter 'zahlerAliase' isn't defined`).

- [ ] **Step 3: DTO erweitern (`betrieb.dart`)**

In `betrieb.dart` Feld-Deklaration nach Zeile 28 (`final List<String> zapfsysteme;`) einfügen:
```dart
  final List<String> zahlerAliase;
```
Im Konstruktor nach `this.zapfsysteme = const [],` (Zeile 75) einfügen:
```dart
    this.zahlerAliase = const [],
```
In `fromJson` nach dem `zapfsysteme:`-Block (nach Zeile 128) einfügen:
```dart
      zahlerAliase: json['zahler_aliase'] != null
          ? List<String>.from(json['zahler_aliase'])
          : [],
```
In `toJson` nach `'zapfsysteme': zapfsysteme,` (Zeile 180) einfügen:
```dart
      'zahler_aliase': zahlerAliase,
```

- [ ] **Step 4: Isar-Local erweitern (`betrieb_local.dart`)**

Nach Zeile 46 (`List<String> zapfsysteme = [];`) einfügen:
```dart
  List<String> zahlerAliase = [];
```

- [ ] **Step 5: Web-Stub erweitern (`web/betrieb_local_web.dart`)**

Nach Zeile 37 (`List<String> zapfsysteme = [];`) einfügen:
```dart
  List<String> zahlerAliase = [];
```

- [ ] **Step 6: Mapper erweitern (`betrieb_mapper.dart`)**

In `fromDto` nach `local.zapfsysteme = dto.zapfsysteme;` (Zeile 34) einfügen:
```dart
    local.zahlerAliase = dto.zahlerAliase;
```
In `toJson` nach `'zapfsysteme': local.zapfsysteme,` (Zeile 87) einfügen:
```dart
      'zahler_aliase': local.zahlerAliase,
```

- [ ] **Step 7: Isar-Code neu generieren (wegen neuem @collection-Feld)**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Erwartung: „Succeeded", `lib/data/local/betrieb_local.g.dart` aktualisiert.

- [ ] **Step 8: Test ausführen → muss bestehen**

```bash
flutter test test/betrieb_mapper_test.dart
```
Erwartung: PASS (2 Tests).

- [ ] **Step 9: Commit**

```bash
git add lib/data/models/betrieb.dart lib/data/local/betrieb_local.dart lib/data/local/web/betrieb_local_web.dart lib/data/mappers/betrieb_mapper.dart lib/data/local/betrieb_local.g.dart test/betrieb_mapper_test.dart
git commit -m "feat(model): betrieb.zahlerAliase (DTO/Isar/Web/Mapper) (TP-B)"
```

---

## Task 3: Normalisierungsfunktion `zahlernameNorm`

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/zahlername.dart`
- Test: `sbs_projer_app/test/zahlername_test.dart`

- [ ] **Step 1: Failing-Test ergänzen**

In `test/zahlername_test.dart` vor der schließenden `}` von `main()` (nach Zeile 14) einfügen:
```dart
  test('zahlernameNorm: trim, lowercase, Mehrfach-Whitespace', () {
    expect(zahlernameNorm('  Hotel   Alpina AG '), 'hotel alpina ag');
    expect(zahlernameNorm('GASTRO\tLatina'), 'gastro latina');
    expect(zahlernameNorm(''), '');
  });
```

- [ ] **Step 2: Test ausführen → muss fehlschlagen**

```bash
flutter test test/zahlername_test.dart
```
Erwartung: FAIL (`The function 'zahlernameNorm' isn't defined`).

- [ ] **Step 3: Funktion implementieren**

In `zahlername.dart` am Dateiende (nach Zeile 13) einfügen:
```dart

/// Normalisiert einen Zahlernamen für den Alias-Vergleich:
/// trim, Kleinschreibung, Mehrfach-Whitespace → einfaches Leerzeichen.
/// Reine Funktion — identisch in Lernen (Speichern) und Anwenden (Matching).
String zahlernameNorm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
```

- [ ] **Step 4: Test ausführen → muss bestehen**

```bash
flutter test test/zahlername_test.dart
```
Erwartung: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/camt/zahlername.dart test/zahlername_test.dart
git commit -m "feat(camt): zahlernameNorm — reine Alias-Normalisierung (TP-B)"
```

---

## Task 4: Alias-Matching-Stufe `CamtBetriebMatcher.matchByAlias`

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/camt_betrieb_matcher.dart`
- Test: `sbs_projer_app/test/camt_betrieb_matcher_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/camt_betrieb_matcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';

void main() {
  final betriebe = [
    {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': 'hotel alpina ag\nalpina gastro'},
    {'id': 'b2', 'name': 'Gastro Latina', 'aliase': 'latina gmbh'},
    {'id': 'b3', 'name': 'Ohne Alias', 'aliase': ''},
  ];

  test('eindeutiger Alias-Treffer (normalisiert)', () {
    final m = CamtBetriebMatcher.matchByAlias('  Hotel  Alpina AG ', betriebe);
    expect(m?['id'], 'b1');
  });

  test('zweiter Alias desselben Betriebs trifft', () {
    expect(CamtBetriebMatcher.matchByAlias('Alpina Gastro', betriebe)?['id'], 'b1');
  });

  test('kein Treffer → null', () {
    expect(CamtBetriebMatcher.matchByAlias('Unbekannt AG', betriebe), isNull);
  });

  test('mehrdeutig (zwei Betriebe, gleicher Alias) → null', () {
    final ambig = [
      {'id': 'b1', 'name': 'A', 'aliase': 'doppelt ag'},
      {'id': 'b2', 'name': 'B', 'aliase': 'doppelt ag'},
    ];
    expect(CamtBetriebMatcher.matchByAlias('Doppelt AG', ambig), isNull);
  });

  test('leerer/fehlender Name → null', () {
    expect(CamtBetriebMatcher.matchByAlias(null, betriebe), isNull);
    expect(CamtBetriebMatcher.matchByAlias('   ', betriebe), isNull);
  });
}
```

- [ ] **Step 2: Test ausführen → muss fehlschlagen**

```bash
flutter test test/camt_betrieb_matcher_test.dart
```
Erwartung: FAIL (`The method 'matchByAlias' isn't defined`).

- [ ] **Step 3: `matchByAlias` implementieren**

In `camt_betrieb_matcher.dart` den Import-Block (nach Zeile 1) ergänzen:
```dart
import 'package:sbs_projer_app/services/camt/zahlername.dart';
```
Innerhalb der Klasse `CamtBetriebMatcher`, direkt vor `findBestMatch` (vor Zeile 21 `/// Findet den besten Betrieb-Match...`), einfügen:
```dart
  /// Stufe 2 der Matching-Kette: exakter Treffer gegen gelernte Zahler-Aliase.
  /// [betriebe]-Maps tragen optional `aliase` = normalisierte Aliase, mit `\n`
  /// verbunden. Liefert den **eindeutigen** Betrieb oder null (0 oder mehrere).
  static Map<String, String>? matchByAlias(
    String? zahlername,
    List<Map<String, String>> betriebe,
  ) {
    if (zahlername == null) return null;
    final norm = zahlernameNorm(zahlername);
    if (norm.isEmpty) return null;
    Map<String, String>? treffer;
    for (final b in betriebe) {
      final aliase = (b['aliase'] ?? '')
          .split('\n')
          .where((a) => a.trim().isNotEmpty);
      if (aliase.any((a) => zahlernameNorm(a) == norm)) {
        if (treffer != null) return null; // mehrdeutig → kein Auto-Treffer
        treffer = b;
      }
    }
    return treffer;
  }

```

- [ ] **Step 4: Test ausführen → muss bestehen**

```bash
flutter test test/camt_betrieb_matcher_test.dart
```
Erwartung: PASS (5 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/camt/camt_betrieb_matcher.dart test/camt_betrieb_matcher_test.dart
git commit -m "feat(camt): matchByAlias — Alias-Matching-Stufe (TP-B)"
```

---

## Task 5: Alias-Stufe in den Abgleich einhängen + `aliase` in die Betriebe-Maps

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart:46`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart:319`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart:159`
- Test: `sbs_projer_app/test/forderungs_abgleich_service_test.dart`

- [ ] **Step 1: Failing-Test schreiben (Alias schlägt Unscharf)**

In `test/forderungs_abgleich_service_test.dart` einen Test ergänzen, der zeigt: eine Gutschrift mit einem Zahlernamen, der **nicht** unscharf auf den Betriebsnamen passt, aber als Alias hinterlegt ist, landet beim richtigen Betrieb. Vor der schließenden `}` von `main()` einfügen:

```dart
  test('Alias-Treffer ordnet Gutschrift dem Betrieb zu (Stufe 2 vor Unscharf)', () {
    final betriebe = [
      {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': 'znueni beiz'},
    ];
    final gut = CamtTransaction(
      amount: 100.00, currency: 'CHF', isCredit: true,
      bookingDate: DateTime(2026, 4, 1),
      partyName: 'Znueni Beiz', txKey: 'g1',
    );
    final rechnung = Rechnung(
      id: 'r1', userId: 'u', rechnungstyp: 'kundenrechnung',
      betriebId: 'b1', betragBrutto: 100.00,
      rechnungsdatum: DateTime(2026, 3, 20), zahlungsstatus: 'offen',
    );
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [gut], offeneForderungen: [rechnung], betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.auto.first.forderungen.first.id, 'r1');
  });
```

> **Hinweis für den Umsetzer:** Falls die `CamtTransaction`/`Rechnung`-Konstruktor-Parameter in den o.g. Pflichtfeldern abweichen, an die im selben Test-File bereits vorhandenen Hilfs-Konstruktoren/`firstWhere`-Beispiele (Zeile 18/19) anpassen — Pflichtfelder identisch zu den dort schon konstruierten Objekten setzen. Inhaltlich muss gelten: `partyName` passt **nicht** unscharf auf „Hotel Alpina", nur der Alias verbindet sie.

- [ ] **Step 2: Test ausführen → muss fehlschlagen**

```bash
flutter test test/forderungs_abgleich_service_test.dart
```
Erwartung: FAIL (Gutschrift wird nicht zugeordnet → `erg.auto` leer), weil der Abgleich Aliase noch ignoriert.

- [ ] **Step 3: Alias-Stufe im Service einhängen**

In `forderungs_abgleich_service.dart` Zeile 46 ersetzen:
```dart
      final match = CamtBetriebMatcher.findBestMatch(name, betriebe);
```
durch:
```dart
      // Stufe 2 (gelernter Alias) vor Stufe 3 (unscharf).
      final match = CamtBetriebMatcher.matchByAlias(name, betriebe) ??
          CamtBetriebMatcher.findBestMatch(name, betriebe);
```

- [ ] **Step 4: Test ausführen → muss bestehen**

```bash
flutter test test/forderungs_abgleich_service_test.dart
```
Erwartung: PASS (alle bisherigen + der neue Test).

- [ ] **Step 5: `aliase` in die Import-Betriebe-Map**

In `camt_import_screen.dart` Zeile 317-320 ersetzen:
```dart
      final betriebe = ref.read(betriebeProvider)
          .where((b) => b.serverId != null)
          .map((b) => {'id': b.serverId!, 'name': b.name})
          .toList();
```
durch:
```dart
      final betriebe = ref.read(betriebeProvider)
          .where((b) => b.serverId != null)
          .map((b) => {
                'id': b.serverId!,
                'name': b.name,
                'aliase': b.zahlerAliase.join('\n'),
              })
          .toList();
```

- [ ] **Step 6: `aliase` in die Standalone-Abgleich-Betriebe-Map**

In `camt_abgleich_screen.dart` Zeile 159 ersetzen:
```dart
          .map((b) => {'id': b.serverId!, 'name': b.name})
```
durch:
```dart
          .map((b) => {
                'id': b.serverId!,
                'name': b.name,
                'aliase': b.zahlerAliase.join('\n'),
              })
```

- [ ] **Step 7: Analyse + betroffene Tests grün**

```bash
flutter analyze lib/services/camt/forderungs_abgleich_service.dart lib/presentation/screens/buchhaltung/camt_import_screen.dart lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart
flutter test test/forderungs_abgleich_service_test.dart
```
Erwartung: keine neuen Analyse-Fehler; Tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/services/camt/forderungs_abgleich_service.dart lib/presentation/screens/buchhaltung/camt_import_screen.dart lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart test/forderungs_abgleich_service_test.dart
git commit -m "feat(camt): Alias als Matching-Stufe 2 im Abgleich + aliase in Betriebe-Maps (TP-B)"
```

---

## Task 6: `BetriebRepository.addZahlerAlias` + reine Entscheidung `entscheideAlias`

**Files:**
- Modify: `sbs_projer_app/lib/data/repositories/betrieb_repository.dart`
- Test: `sbs_projer_app/test/betrieb_alias_test.dart`

- [ ] **Step 1: Failing-Test für die reine Entscheidungslogik schreiben**

Create `sbs_projer_app/test/betrieb_alias_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

BetriebLocal _b(String sid, List<String> aliase) =>
    BetriebLocal()
      ..serverId = sid
      ..name = sid
      ..zahlerAliase = aliase;

void main() {
  test('neuer Alias → gelernt', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel Alpina AG',
      alleBetriebe: [_b('b1', []), _b('b2', [])],
    );
    expect(res, AliasLernResultat.gelernt);
  });

  test('schon vorhanden → schonVorhanden', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel  Alpina  AG',
      alleBetriebe: [_b('b1', ['hotel alpina ag'])],
    );
    expect(res, AliasLernResultat.schonVorhanden);
  });

  test('Alias bei anderem Betrieb → konflikt', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel Alpina AG',
      alleBetriebe: [_b('b1', []), _b('b2', ['hotel alpina ag'])],
    );
    expect(res, AliasLernResultat.konflikt);
  });

  test('leerer Name → schonVorhanden (No-Op)', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: '   ',
      alleBetriebe: [_b('b1', [])],
    );
    expect(res, AliasLernResultat.schonVorhanden);
  });
}
```

- [ ] **Step 2: Test ausführen → muss fehlschlagen**

```bash
flutter test test/betrieb_alias_test.dart
```
Erwartung: FAIL (`AliasLernResultat`/`entscheideAlias` nicht definiert).

- [ ] **Step 3: Enum + reine Entscheidung + IO-Methode implementieren**

In `betrieb_repository.dart` den Import-Block (nach Zeile 6) ergänzen:
```dart
import 'package:sbs_projer_app/services/camt/zahlername.dart';
```
Vor der Klasse `BetriebRepository` (vor Zeile 8) einfügen:
```dart
/// Ergebnis eines Alias-Lernversuchs.
enum AliasLernResultat { gelernt, schonVorhanden, konflikt }
```
Innerhalb der Klasse, am Ende (vor der schließenden `}`, nach `delete(...)` Zeile 90), einfügen:
```dart

  /// Reine Entscheidung, ob ein Zahlername als Alias für [betriebServerId]
  /// gelernt werden soll. Konflikt = Name bereits bei einem ANDEREN Betrieb.
  static AliasLernResultat entscheideAlias({
    required String betriebServerId,
    required String zahlername,
    required List<BetriebLocal> alleBetriebe,
  }) {
    final norm = zahlernameNorm(zahlername);
    if (norm.isEmpty) return AliasLernResultat.schonVorhanden;
    for (final b in alleBetriebe) {
      final hat = b.zahlerAliase.any((a) => zahlernameNorm(a) == norm);
      if (hat) {
        return b.serverId == betriebServerId
            ? AliasLernResultat.schonVorhanden
            : AliasLernResultat.konflikt;
      }
    }
    return AliasLernResultat.gelernt;
  }

  /// Lernt [zahlername] als Alias für den Betrieb [betriebServerId] (idempotent,
  /// mit Konflikt-Check gegen andere Betriebe). Speichert nur bei `gelernt`.
  static Future<AliasLernResultat> addZahlerAlias(
    String betriebServerId,
    String zahlername,
  ) async {
    final alle = await getAll();
    final res = entscheideAlias(
      betriebServerId: betriebServerId,
      zahlername: zahlername,
      alleBetriebe: alle,
    );
    if (res != AliasLernResultat.gelernt) return res;
    BetriebLocal? ziel;
    for (final b in alle) {
      if (b.serverId == betriebServerId) {
        ziel = b;
        break;
      }
    }
    if (ziel == null) return AliasLernResultat.schonVorhanden;
    ziel.zahlerAliase = [...ziel.zahlerAliase, zahlernameNorm(zahlername)];
    await save(ziel);
    return AliasLernResultat.gelernt;
  }
```

- [ ] **Step 4: Test ausführen → muss bestehen**

```bash
flutter test test/betrieb_alias_test.dart
```
Erwartung: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/betrieb_repository.dart test/betrieb_alias_test.dart
git commit -m "feat(repo): addZahlerAlias + entscheideAlias mit Konflikt-Check (TP-B)"
```

---

## Task 7: Lernen in den manuellen Zuordnungs-Dialogen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart`

> Kein neuer Unit-Test: reine UI-Verdrahtung bestehender, bereits getesteter Bausteine. Verifikation über `flutter analyze` + Browser-Test (Task 9).

- [ ] **Step 1: Import + Hilfsmethode ergänzen**

In `abgleich_vorschau.dart` den Import-Block (nach Zeile 12 `import '.../zahlername.dart';`) ergänzen:
```dart
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
```
In der State-Klasse `_AbgleichVorschauState`, nach der `_ordneZu`-Methode (nach Zeile 673, vor der schließenden `}` der Klasse Zeile 674), einfügen:
```dart

  /// Lernt den Zahlernamen einer Gutschrift als Alias des Betriebs [betriebId].
  /// Zeigt bei Konflikt (Name schon bei anderem Betrieb) einen Hinweis.
  Future<void> _lerneAlias(String betriebId, CamtTransaction g) async {
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    if (name == null) return;
    try {
      final res = await BetriebRepository.addZahlerAlias(betriebId, name);
      if (res == AliasLernResultat.konflikt && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Zahlername „$name" ist bereits einem anderen Betrieb zugeordnet — '
              'nicht gelernt.'),
        ));
      }
    } catch (_) {
      // Lernen ist Best-Effort; Verbuchung darf dadurch nicht scheitern.
    }
  }
```

- [ ] **Step 2: Lernen nach manueller Sammel-Zuordnung (`_oeffneManuell`)**

In `_oeffneManuell`, im Block nach erfolgreicher Verbuchung — direkt nach `if (verbucht != true) return;` (Zeile 491) und **vor** `ref.invalidate(rechnungenStreamProvider);` (Zeile 493) — einfügen:
```dart
    // Zahler→Betrieb lernen: alle gewählten Gutschriften → dieser Betrieb.
    for (final g in gewaehlteGutschriften) {
      await _lerneAlias(f.betriebId, g);
    }
```

- [ ] **Step 3: Lernen nach Zuordnung einer „nicht zugeordneten" Zahlung (`_ordneZu`)**

In `_ordneZu`, im `if (ok == true) {`-Block direkt nach `if (ok == true) {` (Zeile 657) einfügen (vor `ref.invalidate(...)` Zeile 658):
```dart
      // Lernen nur bei eindeutigem Betrieb der gewählten Forderungen.
      final betriebIds =
          gewaehlt.map((r) => r.betriebId).whereType<String>().toSet();
      if (betriebIds.length == 1) {
        await _lerneAlias(betriebIds.first, g);
      }
```

- [ ] **Step 4: Analyse**

```bash
flutter analyze lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart
```
Erwartung: keine Fehler. (Hinweis: `_lerneAlias` wird in beiden Dialogen verwendet → kein „unused".)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart
git commit -m "feat(camt): Zahler→Betrieb lernen bei manueller Zuordnung (TP-B)"
```

---

## Task 8: Alias-Pflege im Betrieb-Formular

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart`

> UI-Verdrahtung; Verifikation über `flutter analyze` + Browser-Test (Task 9).

- [ ] **Step 1: Import + State-Felder ergänzen**

In `betrieb_form_screen.dart` den Import-Block oben ergänzen (zu den bestehenden `import`-Zeilen hinzufügen):
```dart
import 'package:sbs_projer_app/services/camt/zahlername.dart';
```
Bei den State-Feldern, direkt nach `List<String> _zapfsysteme = [];` (Zeile 67), einfügen:
```dart
  List<String> _zahlerAliase = [];
  final _aliasController = TextEditingController();
```

- [ ] **Step 2: Beim Laden befüllen**

In `initState`/Load-Block nach `_zapfsysteme = List<String>.from(betrieb.zapfsysteme);` (Zeile 139) einfügen:
```dart
      _zahlerAliase = List<String>.from(betrieb.zahlerAliase);
```

- [ ] **Step 3: Beim Speichern übernehmen**

In `_save` nach `betrieb.zapfsysteme = _zapfsysteme;` (Zeile 196) einfügen:
```dart
      betrieb.zahlerAliase = _zahlerAliase;
```

- [ ] **Step 4: Controller freigeben**

In der `dispose`-Methode (sucht die bestehende `dispose()`-Override; alle anderen Controller werden dort mit `.dispose()` freigegeben) eine Zeile ergänzen:
```dart
    _aliasController.dispose();
```

- [ ] **Step 5: Editor-UI einfügen**

In der `build`-Methode nach dem Rechnungsstellung-Block — direkt vor `// === Adresse ===` (vor Zeile 394) — einfügen:
```dart
            // === Zahlernamen-Aliase (Bank → Betrieb-Lernen) ===
            Text('Zahlernamen (Bank)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Text(
              'Namen, unter denen dieser Betrieb Zahlungen überweist. '
              'Wird beim Bankauszug-Import automatisch gelernt.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_zahlerAliase.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in _zahlerAliase)
                    InputChip(
                      label: Text(a),
                      onDeleted: () => setState(() => _zahlerAliase.remove(a)),
                    ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aliasController,
                    decoration: const InputDecoration(
                      labelText: 'Zahlername hinzufügen',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _aliasHinzufuegen(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Hinzufügen',
                  onPressed: _aliasHinzufuegen,
                ),
              ],
            ),
            const SizedBox(height: 16),
```

- [ ] **Step 6: Hinzufügen-Helfer implementieren**

In der State-Klasse (z.B. direkt vor `_save`, vor Zeile 156) einfügen:
```dart
  void _aliasHinzufuegen() {
    final norm = zahlernameNorm(_aliasController.text);
    if (norm.isEmpty) return;
    setState(() {
      if (!_zahlerAliase.contains(norm)) _zahlerAliase.add(norm);
      _aliasController.clear();
    });
  }
```

- [ ] **Step 7: Analyse**

```bash
flutter analyze lib/presentation/screens/betriebe/betrieb_form_screen.dart
```
Erwartung: keine Fehler.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(betriebe): Zahlernamen-Aliase im Betrieb-Formular pflegen (TP-B)"
```

---

## Task 9: Gesamtverifikation + Deploy

**Files:** keine (Build/Deploy)

- [ ] **Step 1: Vollständige Analyse**

```bash
flutter analyze
```
Erwartung: „No issues found!" (oder nur vorbestehende, unveränderte Warnungen).

- [ ] **Step 2: Komplette Testsuite**

```bash
flutter test
```
Erwartung: alle Tests grün (bestehende + neue: betrieb_mapper, zahlername, camt_betrieb_matcher, forderungs_abgleich_service, betrieb_alias).

- [ ] **Step 3: Browser-Test (manuell, vor Deploy — Pflicht laut Memory `feedback-ui-vor-deploy-testen`)**

Per `preview_*`-Workflow oder lokal (`flutter run -d edge`) prüfen:
1. Betrieb öffnen/bearbeiten → Abschnitt „Zahlernamen (Bank)" sichtbar; Alias hinzufügen + löschen + speichern; nach Reload persistiert.
2. camt-Import mit einer Test-Gutschrift, deren Zahlername als Alias eines Betriebs hinterlegt ist → Gutschrift landet in 🟢/🟡 beim richtigen Betrieb (nicht in ⚪).
3. Eine ⚪-Zahlung manuell einem Betrieb zuordnen → danach ist der Zahlername im Betrieb-Formular als Alias sichtbar.
4. Konflikt: denselben Namen einem zweiten Betrieb zuzuordnen versuchen → Hinweis-SnackBar, kein zweiter Eintrag.

Screenshot der Betrieb-Alias-UI + des Import-Treffers an Daniel.

- [ ] **Step 4: Version bumpen**

In `sbs_projer_app/pubspec.yaml` Zeile 4 beide Teile erhöhen, z.B.:
```
version: 0.12.0+440
```

- [ ] **Step 5: Deploy nach gh-pages**

Gemäß `CLAUDE.md`-Deploy-Block (Build `--pwa-strategy=none`, `main.dart.js` cache-busten, `flutter_service_worker.js` löschen, Dateien auf `gh-pages` kopieren, committen, pushen, zurück auf `main`). Vorher **alle** Änderungen auf `main` committen + pushen (kein `git stash`).

- [ ] **Step 6: Abschluss-Commit der Version**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.12.0+440 — TP-B Zahler→Betrieb-Lernen"
git push origin main
```

---

## Selbst-Review (Spec-Abdeckung)

- **Feld `betriebe.zahler_aliase text[]`** → Task 1 (DB) + Task 2 (Model).
- **Normalisierung `zahlernameNorm` (rein, identisch Lernen/Anwenden)** → Task 3.
- **Lernen bei manueller Zuordnung, nur eindeutiger Betrieb, Konflikt-Check, kein Duplikat** → Task 6 (`entscheideAlias`/`addZahlerAlias`) + Task 7 (Hooks `_oeffneManuell` eindeutiger Betrieb; `_ordneZu` nur bei `betriebIds.length == 1`).
- **Anwenden als Matching-Stufe 2 (exakt, alle Betriebe, eindeutig)** → Task 4 (`matchByAlias`) + Task 5 (Einhängen vor `findBestMatch` + `aliase` in beide Betriebe-Maps).
- **Pflege im Betrieb-Form (anzeigen/hinzufügen/löschen)** → Task 8.
- **Tests: Norm, Matching-Reihenfolge (Alias vor Unscharf), Lernen/Konflikt** → Tasks 3/4/5/6.
- Offen aus Spec (bewusst Folge-TP): **TP-C QR-Referenz** (Stufe 1) — nicht in diesem Plan.
