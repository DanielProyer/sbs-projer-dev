# Eingangsrechnung-Kategorien Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (empfohlen) oder superpowers:executing-plans. Steps mit Checkbox (`- [ ]`).

**Goal:** Jedes Eingangsdokument (Rechnung + Info) bekommt eine KI-vergebene, inhaltsbasierte Kategorie (1 von 15), die es auffindbar macht und bei Rechnungen das Aufwandskonto vorschlägt (löst die inhaltliche Bussen-Erkennung).

**Architecture:** Neue Config-Tabelle `eingangsrechnung_kategorie` (code→Konto-Defaults) + Spalte `eingangsrechnung.kategorie`. Die `parse-rechnung`-KI liefert `kategorie`. Reine Funktion `schlageKontoVor` (Aussteller-Regel > Kategorie-Default > leer). UI: Kategorie-Dropdown + Liste mit „Rechnungen | Ablage"-Umschalter + Kategorie-Filter.

**Tech Stack:** Flutter, Supabase (Postgres + Edge Function/Deno), Riverpod. Eingangsrechnung ist Supabase-only (kein Isar).

**Spec:** `docs/superpowers/specs/2026-06-29-eingangsrechnung-kategorien-design.md`

---

## File Structure

- **Create** `sbs_projer_app/lib/data/models/eingangsrechnung_kategorie.dart` — DTO der Kategorie-Tabelle.
- **Create** `sbs_projer_app/lib/data/repositories/eingangsrechnung_kategorie_repository.dart` — getAll.
- **Create** `sbs_projer_app/lib/services/eingangsrechnung/konto_vorschlag.dart` — reine Funktion `schlageKontoVor` + `KontoVorschlag`.
- **Create** `sbs_projer_app/test/konto_vorschlag_test.dart`.
- **Create** `Datenbank/migrations/116_eingangsrechnung_kategorie.sql` — Tabelle + Seed + Spalte (per MCP angewendet; Datei = Repo-Record).
- **Modify** `sbs_projer_app/lib/data/models/eingangsrechnung.dart` — Feld `kategorie`.
- **Modify** `sbs_projer_app/lib/data/models/rechnung_scan_result.dart` — Feld `kategorie`.
- **Modify** `sbs_projer_app/lib/presentation/providers/eingangsrechnung_providers.dart` — `eingangsrechnungKategorienProvider`.
- **Modify** `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_upload_screen.dart` — `kategorie` + `schlageKontoVor` im create.
- **Modify** `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_detail_screen.dart` — Kategorie-Dropdown + Speichern.
- **Modify** `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart` — Umschalter + Filter + Label.
- **Modify (PROD)** `supabase/functions/parse-rechnung/index.ts` — Prompt + Output `kategorie`. **Migration/Redeploy mache ich selbst.**

---

## TP-1: Datenmodell (Migration + Kategorie-Modell)

### Task 1.1: Migration anlegen (vom Plan-Ausführer NICHT via psql — ich wende sie per MCP an; hier nur die Datei)

**Files:** Create `Datenbank/migrations/116_eingangsrechnung_kategorie.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- Migration 116: Eingangsrechnung-Kategorien (Config-Tabelle, global wie konten).
create table if not exists public.eingangsrechnung_kategorie (
  code text primary key,
  bezeichnung text not null,
  default_aufwandskonto int,
  default_vorsteuer_konto int,
  reihenfolge int not null default 0,
  ist_aktiv boolean not null default true
);

alter table public.eingangsrechnung add column if not exists kategorie text;

insert into public.eingangsrechnung_kategorie
  (code, bezeichnung, default_aufwandskonto, default_vorsteuer_konto, reihenfolge) values
 ('versicherung','Versicherung',6300,null,10),
 ('sozialversicherung','Sozialversicherung',null,null,20),
 ('unfall_krankheit','Unfall & Krankheit',null,null,30),
 ('steuern','Steuern & MwSt',null,null,40),
 ('busse','Busse',6280,null,50),
 ('fahrzeug','Fahrzeug',6250,1171,60),
 ('telekom_it','Telekom & IT',6510,1171,70),
 ('franchise','Franchise',6301,1170,80),
 ('miete_raum','Miete & Raum',6000,null,90),
 ('entsorgung_gemeinde','Entsorgung & Gemeinde',6460,1171,100),
 ('material_werkzeug','Material & Werkzeug',4004,1170,110),
 ('treuhand_beratung','Treuhand & Beratung',6530,1171,120),
 ('lohn_personal','Lohn & Personal',null,null,130),
 ('behoerde_amtliches','Behörde & Amtliches',null,null,140),
 ('sonstiges','Sonstiges',null,null,150)
on conflict (code) do nothing;

-- RLS: global lesbar (wie konten). Falls RLS aktiv ist, Read-Policy für authenticated.
alter table public.eingangsrechnung_kategorie enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='eingangsrechnung_kategorie' and policyname='kategorie_read') then
    create policy kategorie_read on public.eingangsrechnung_kategorie for select to authenticated using (true);
  end if;
end $$;
```

- [ ] **Step 2: Commit** `git add Datenbank/migrations/116_eingangsrechnung_kategorie.sql && git commit -m "feat(kategorie): Migration 116 eingangsrechnung_kategorie + Seed"`

> **HINWEIS:** Die Migration wird vom Projektverantwortlichen (Claude-Hauptloop) per `mcp__supabase__apply_migration` / `execute_sql` auf PROD angewendet, BEVOR Code, der die Tabelle liest, getestet wird. Der Plan-Ausführer schreibt nur die Datei.

### Task 1.2: Kategorie-Modell

**Files:** Create `sbs_projer_app/lib/data/models/eingangsrechnung_kategorie.dart`

- [ ] **Step 1: Modell schreiben**

```dart
/// DTO der Config-Tabelle `eingangsrechnung_kategorie` (global, kein user_id).
class EingangsrechnungKategorie {
  final String code;
  final String bezeichnung;
  final int? defaultAufwandskonto;
  final int? defaultVorsteuerKonto;
  final int reihenfolge;
  final bool istAktiv;

  const EingangsrechnungKategorie({
    required this.code,
    required this.bezeichnung,
    this.defaultAufwandskonto,
    this.defaultVorsteuerKonto,
    this.reihenfolge = 0,
    this.istAktiv = true,
  });

  factory EingangsrechnungKategorie.fromJson(Map<String, dynamic> json) =>
      EingangsrechnungKategorie(
        code: json['code'] as String,
        bezeichnung: json['bezeichnung'] as String,
        defaultAufwandskonto: _toInt(json['default_aufwandskonto']),
        defaultVorsteuerKonto: _toInt(json['default_vorsteuer_konto']),
        reihenfolge: _toInt(json['reihenfolge']) ?? 0,
        istAktiv: json['ist_aktiv'] ?? true,
      );

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
```

- [ ] **Step 2:** `flutter analyze lib/data/models/eingangsrechnung_kategorie.dart` → No issues. Commit.

### Task 1.3: Kategorie-Repository

**Files:** Create `sbs_projer_app/lib/data/repositories/eingangsrechnung_kategorie_repository.dart`

- [ ] **Step 1: Repository schreiben**

```dart
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für die Kategorie-Config (global).
class EingangsrechnungKategorieRepository {
  static Future<List<EingangsrechnungKategorie>> getAll() async {
    final rows = await SupabaseService.client
        .from('eingangsrechnung_kategorie')
        .select()
        .eq('ist_aktiv', true)
        .order('reihenfolge');
    return rows.map((r) => EingangsrechnungKategorie.fromJson(r)).toList();
  }
}
```

- [ ] **Step 2:** `flutter analyze` der Datei → No issues. Commit.

### Task 1.4: `kategorie` ins Eingangsrechnung-Modell

**Files:** Modify `sbs_projer_app/lib/data/models/eingangsrechnung.dart`

- [ ] **Step 1:** Feld ergänzen — nach `final String? geschaeftsfallId;` einfügen:

```dart
  final String? kategorie;
```

- [ ] **Step 2:** Konstruktor-Param ergänzen — nach `this.geschaeftsfallId,`:

```dart
    this.kategorie,
```

- [ ] **Step 3:** In `fromJson` — nach `geschaeftsfallId: json['geschaeftsfall_id'],`:

```dart
      kategorie: json['kategorie'],
```

- [ ] **Step 4:** In `toJson` — nach `'geschaeftsfall_id': geschaeftsfallId,`:

```dart
      'kategorie': kategorie,
```

- [ ] **Step 5:** `flutter analyze lib/data/models/eingangsrechnung.dart` → No issues. Commit.

### Task 1.5: Kategorien-Provider

**Files:** Modify `sbs_projer_app/lib/presentation/providers/eingangsrechnung_providers.dart`

- [ ] **Step 1:** Imports ergänzen (oben):

```dart
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_kategorie_repository.dart';
```

- [ ] **Step 2:** Provider am Ende der Datei ergänzen:

```dart
/// Eingangsrechnung-Kategorien (Config, global). Für Dropdown + Konto-Vorschlag.
final eingangsrechnungKategorienProvider =
    FutureProvider<List<EingangsrechnungKategorie>>((ref) async {
  return EingangsrechnungKategorieRepository.getAll();
});
```

- [ ] **Step 3:** `flutter analyze` → No issues. Commit.

---

## TP-2: KI-Klassifizierung

### Task 2.1: `kategorie` in `RechnungScanResult`

**Files:** Modify `sbs_projer_app/lib/data/models/rechnung_scan_result.dart`

- [ ] **Step 1:** Feld nach `final double konfidenz;` ergänzen:

```dart
  final String? kategorie; // code aus eingangsrechnung_kategorie
```

- [ ] **Step 2:** Konstruktor-Param nach `this.konfidenz = 0,`:

```dart
    this.kategorie,
```

- [ ] **Step 3:** In `fromJson` nach `konfidenz: _d(json['konfidenz']),`:

```dart
      kategorie: json['kategorie'] as String?,
```

- [ ] **Step 4:** `flutter analyze lib/data/models/rechnung_scan_result.dart` → No issues. Commit.

### Task 2.2: Edge-Function-Prompt (wird vom Hauptloop deployt)

**Files:** Modify `supabase/functions/parse-rechnung/index.ts`

- [ ] **Step 1:** Im `PROMPT` nach SCHRITT 1 (KLASSIFIZIEREN) einen Kategorie-Schritt ergänzen:

```
- kategorie: genau einer dieser Codes, nach INHALT/Thema des Dokuments:
  versicherung (Haftpflicht/Sach/Police/Prämie), sozialversicherung (Beiträge/Prämien AHV/SVA/BVG/PK/SUVA/KTG, Vorsorgeausweis), unfall_krankheit (Schadensmeldung, Krankschreibung, Apothekerschein, SUVA-Korrespondenz, Taggeldbescheid, Unfallschein), steuern (Bundes-/Kantons-/Gemeindesteuer, ESTV-MWST, Veranlagung), busse (JEDE Ordnungs-/Geschwindigkeitsbusse, egal welcher Kanton/Aussteller), fahrzeug (Tanken, Reparatur, Fahrbewilligung, Strassenverkehrsamt), telekom_it (Telefon, Internet, Software/Abos), franchise (Heineken-Franchisegebühr), miete_raum (Büromiete, Nebenkosten), entsorgung_gemeinde (Kehricht, Feuerwehrabgabe), material_werkzeug (Material-/Werkzeug-Einkauf), treuhand_beratung (Buchhaltung, Beratung), lohn_personal (Lohnausweis, Lohndeklaration, Personalpapiere), behoerde_amtliches (sonstige behördliche Schreiben), sonstiges (Auffang). Bei Unsicherheit: sonstiges.
```

- [ ] **Step 2:** Im JSON-Beispiel das Feld `"kategorie": "franchise",` ergänzen (vor `"konfidenz"`).

- [ ] **Step 3:** **Deploy durch Hauptloop:** `supabase functions deploy parse-rechnung --no-verify-jwt` (bzw. via MCP `deploy_edge_function`). Manueller Test mit echtem Dokument.

---

## TP-3: Konto-Vorschlag-Logik

### Task 3.1: `schlageKontoVor` (rein, TDD)

**Files:** Create `sbs_projer_app/lib/services/eingangsrechnung/konto_vorschlag.dart`; Test `sbs_projer_app/test/konto_vorschlag_test.dart`

- [ ] **Step 1: Test schreiben** (`konto_vorschlag_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/konto_vorschlag.dart';

final _kategorien = [
  const EingangsrechnungKategorie(
      code: 'busse', bezeichnung: 'Busse', defaultAufwandskonto: 6280),
  const EingangsrechnungKategorie(
      code: 'telekom_it',
      bezeichnung: 'Telekom & IT',
      defaultAufwandskonto: 6510,
      defaultVorsteuerKonto: 1171),
  const EingangsrechnungKategorie(
      code: 'sonstiges', bezeichnung: 'Sonstiges'),
];

KreditorRegel _regel({int aufwand = 6301, int? vorsteuer = 1170}) =>
    KreditorRegel(
      lieferantNamePattern: 'Heineken',
      aufwandskonto: aufwand,
      vorsteuerKonto: vorsteuer,
    );

void main() {
  test('Aussteller-Regel gewinnt über Kategorie-Default', () {
    final v = schlageKontoVor(
        kategorie: 'busse', kategorien: _kategorien, regelTreffer: _regel());
    expect(v.aufwandskonto, 6301);
    expect(v.vorsteuerKonto, 1170);
  });

  test('ohne Regel: Kategorie-Default greift (Busse -> 6280)', () {
    final v = schlageKontoVor(kategorie: 'busse', kategorien: _kategorien);
    expect(v.aufwandskonto, 6280);
    expect(v.vorsteuerKonto, isNull);
  });

  test('Kategorie mit Vorsteuer-Default', () {
    final v = schlageKontoVor(kategorie: 'telekom_it', kategorien: _kategorien);
    expect(v.aufwandskonto, 6510);
    expect(v.vorsteuerKonto, 1171);
  });

  test('Kategorie ohne Default -> leer', () {
    final v = schlageKontoVor(kategorie: 'sonstiges', kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
    expect(v.vorsteuerKonto, isNull);
  });

  test('keine Kategorie + keine Regel -> leer', () {
    final v = schlageKontoVor(kategorie: null, kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
  });

  test('unbekannte Kategorie -> leer (kein Crash)', () {
    final v = schlageKontoVor(kategorie: 'gibtsnicht', kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
  });
}
```

> **Annahme zu `KreditorRegel`-Konstruktor:** benannte Parameter `lieferantNamePattern` (required), `aufwandskonto` (required), `vorsteuerKonto` (optional). Vor dem Test in `lib/data/models/kreditor_regel.dart` verifizieren; Konstruktor-Aufruf im Test entsprechend anpassen.

- [ ] **Step 2: Lauf (FAIL)** `flutter test test/konto_vorschlag_test.dart`

- [ ] **Step 3: Implementierung** (`konto_vorschlag.dart`):

```dart
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';

/// Vorgeschlagene Konten für eine Eingangsrechnung.
class KontoVorschlag {
  final int? aufwandskonto;
  final int? vorsteuerKonto;
  const KontoVorschlag({this.aufwandskonto, this.vorsteuerKonto});
}

/// Schlägt Aufwands-/Vorsteuerkonto vor. Reihenfolge:
/// 1. Aussteller-Regel (spezifisch) — komplett übernehmen.
/// 2. Kategorie-Default (aus der Config-Tabelle).
/// 3. sonst leer (manuell).
KontoVorschlag schlageKontoVor({
  required String? kategorie,
  required List<EingangsrechnungKategorie> kategorien,
  KreditorRegel? regelTreffer,
}) {
  if (regelTreffer != null) {
    return KontoVorschlag(
      aufwandskonto: regelTreffer.aufwandskonto,
      vorsteuerKonto: regelTreffer.vorsteuerKonto,
    );
  }
  if (kategorie != null) {
    for (final k in kategorien) {
      if (k.code == kategorie) {
        return KontoVorschlag(
          aufwandskonto: k.defaultAufwandskonto,
          vorsteuerKonto: k.defaultVorsteuerKonto,
        );
      }
    }
  }
  return const KontoVorschlag();
}
```

- [ ] **Step 4: Lauf (PASS).** Commit.

### Task 3.2: Einbau in den Upload (`_scanAndCreate`)

**Files:** Modify `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_upload_screen.dart`

- [ ] **Step 1:** Imports ergänzen:

```dart
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_kategorie_repository.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/konto_vorschlag.dart';
```

- [ ] **Step 2:** Nach dem `matchKreditorRegel`-Block (nach dem `} catch (_) {}` der Lernregel-Suche, vor `// 2) Eingangsrechnung anlegen`) den Konto-Vorschlag berechnen:

```dart
      // 1d) Konto-Vorschlag: Aussteller-Regel > Kategorie-Default > leer.
      List<EingangsrechnungKategorie> kategorien = const [];
      try {
        kategorien = await EingangsrechnungKategorieRepository.getAll();
      } catch (_) {}
      final konto = schlageKontoVor(
        kategorie: r.kategorie,
        kategorien: kategorien,
        regelTreffer: treffer,
      );
```

(Import `EingangsrechnungKategorie` falls nötig: `import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';`)

- [ ] **Step 3:** Im `create({...})`-Map die konten-Zeilen ersetzen. Statt:

```dart
        if (treffer != null) 'aufwandskonto': treffer.aufwandskonto,
        if (treffer != null) 'vorsteuer_konto': treffer.vorsteuerKonto,
        if (treffer != null) 'geschaeftsfall_id': treffer.geschaeftsfallId,
```

einsetzen:

```dart
        'kategorie': r.kategorie,
        if (konto.aufwandskonto != null) 'aufwandskonto': konto.aufwandskonto,
        if (konto.vorsteuerKonto != null) 'vorsteuer_konto': konto.vorsteuerKonto,
        if (treffer != null) 'geschaeftsfall_id': treffer.geschaeftsfallId,
```

- [ ] **Step 4:** `flutter analyze` der Datei → No issues. Commit.

---

## TP-4: UI (Detail-Dropdown + Liste)

### Task 4.1: Kategorie-Dropdown im Detail

**Files:** Modify `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_detail_screen.dart`

- [ ] **Step 1:** Import + State-Feld. Import ergänzen:

```dart
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart'; // bereits vorhanden
```

State-Variable bei den anderen `_…`-Feldern: `String? _kategorie;`

- [ ] **Step 2:** In `_load()` (wo die anderen Felder aus `_rechnung` gesetzt werden) ergänzen: `_kategorie = e.kategorie;` (mit dem geladenen Datensatz `e`).

- [ ] **Step 3:** Im `_buildForm` — vor `_label('Aufwandskonto …')` einen Kategorie-Block einfügen, der den Provider liest:

```dart
            _label('Kategorie'),
            Consumer(builder: (context, ref, _) {
              final kat = ref.watch(eingangsrechnungKategorienProvider).valueOrNull ?? [];
              return DropdownButtonFormField<String>(
                initialValue: _kategorie,
                isExpanded: true,
                items: [
                  for (final k in kat)
                    DropdownMenuItem(value: k.code, child: Text(k.bezeichnung)),
                ],
                onChanged: (v) => setState(() => _kategorie = v),
                decoration: const InputDecoration(hintText: 'Kategorie wählen'),
              );
            }),
            const SizedBox(height: 16),
```

- [ ] **Step 4:** In `_bestaetigenUndBuchen` UND `_nurAblegen` (in den `EingangsrechnungRepository.update(...)`-Maps) `'kategorie': _kategorie,` ergänzen, damit die (ggf. korrigierte) Kategorie persistiert wird.

- [ ] **Step 5:** `flutter analyze` der Datei → No issues. Commit.

### Task 4.2: Liste — Umschalter Rechnungen/Ablage + Kategorie-Filter + Label

**Files:** Modify `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart`

> Aktuell baut der Screen aus `eingangsrechnungenProvider` Gruppen, u.a. `infoAblage` (`istNurInfo || status=='abgelegt'`) als Sektion „Info / Ablage". Umbau: ein Ansicht-Umschalter (Rechnungen vs. Ablage) + ein Kategorie-Filter; Kategorie-Label an der Zeile.

- [ ] **Step 1:** Screen auf `ConsumerStatefulWidget` (falls noch `ConsumerWidget`) — State `String _ansicht = 'rechnungen';` (oder 'ablage') und `String? _katFilter;`.

- [ ] **Step 2:** Filter-UI über der Liste: ein `SegmentedButton`/zwei `ChoiceChip` „Rechnungen | Ablage" + ein `DropdownButton<String?>` für die Kategorie (Optionen aus `eingangsrechnungKategorienProvider`, plus „Alle").

- [ ] **Step 3:** Daten filtern: Liste aus dem Provider →
  - `_ansicht == 'ablage'` → nur `e.istNurInfo || e.status == 'abgelegt'`; sonst die übrigen.
  - falls `_katFilter != null` → zusätzlich `e.kategorie == _katFilter`.

- [ ] **Step 4:** In der Listen-Zeile (`_eintrag` / wo `_StatusChip` sitzt) ein kleines Kategorie-Label rendern, wenn `e.kategorie != null` (Bezeichnung aus dem Provider-Lookup; Fallback: der Code).

- [ ] **Step 5:** `flutter analyze` der Datei → No issues. Commit.

---

## TP-5: Verifikation

- [ ] `flutter analyze` (gesamt) — 0 Errors.
- [ ] `flutter test` — alle grün (inkl. `konto_vorschlag_test`).
- [ ] `flutter build web` — erfolgreich.
- [ ] Adversariale Review (Konto-Vorschlag-Reihenfolge, Null-Defaults, KI-Kategorie-Robustheit, Listen-Filter-Edge-Cases) → bestätigte Findings fixen.
- [ ] Version-Bump + Deploy. Manueller End-to-End-Test: Dokument hochladen (Busse aus anderem Kanton → Kategorie `busse`, Konto 6280 vorgeschlagen); Info-Doc → „Nur ablegen" → in „Ablage"-Ansicht nach Kategorie findbar.

## Self-Review (Plan ↔ Spec)

- **Spec-Abdeckung:** Tabelle+Seed (T1.1) ✓, kategorie-Spalte (T1.1/1.4) ✓, Modell+Repo+Provider (T1.2/1.3/1.5) ✓, KI-Output (T2.1/2.2) ✓, schlageKontoVor + Reihenfolge (T3.1) ✓, Einbau Upload (T3.2) ✓, Detail-Dropdown (T4.1) ✓, Liste Umschalter+Filter+Label (T4.2) ✓, Tests (T3.1, T5) ✓.
- **Typkonsistenz:** `EingangsrechnungKategorie` (code/bezeichnung/defaultAufwandskonto/defaultVorsteuerKonto), `KontoVorschlag` (aufwandskonto/vorsteuerKonto), `schlageKontoVor(kategorie, kategorien, regelTreffer)` durchgängig.
- **Offen/zu verifizieren beim Bau:** exakter `KreditorRegel`-Konstruktor (T3.1-Annahme); ob `eingangsrechnung_liste_screen` schon Consumer ist; RLS-Policy-Namen auf der neuen Tabelle.
