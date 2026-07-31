# Betriebsferien und Öffnungszeiten aktuell halten — Implementierungsplan

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`. Schritte sind als Checkboxen (`- [ ]`) geführt.

**Ziel:** Betriebsferien und Öffnungszeiten so pflegen, dass Daniel nicht mehr vor einem geschlossenen Betrieb steht — durch Erfassung im Arbeitsfluss (vor Ort, beim Abschluss), einen Vorjahres-Hinweis und einen täglichen Abgleich über Google und Website.

**Architektur:** Ferien wandern von fünf festen Spaltenpaaren in eine eigene Tabelle `betrieb_ferien` mit Quelle und Bestätigungsdatum. Automatisch geholte Werte landen in `betrieb_vorschlaege` und werden nie still übernommen. Ein täglicher `pg_cron`-Lauf stösst zwei Edge-Functions für je zehn Betriebe an.

**Tech-Stack:** Flutter + Riverpod + Isar (Conditional Exports) + Supabase (PostgREST, RLS, Edge Functions/Deno), `pg_cron` + `pg_net`.

**Spec:** `docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md`

**Arbeitsweise:** Direkt auf `main` (Projekt-Workflow: main → gh-pages-Deploy). Flutter-PATH in PowerShell: `$env:PATH += ";C:\flutter\bin"`. Supabase project_id `pltbaqqwpnmdajwgnhpd`. Tests laufen mit `flutter test` im Verzeichnis `sbs_projer_app` (Stand vor Beginn: **784 grün**).

---

## Dateiübersicht

| Datei | Verantwortung |
|---|---|
| `Datenbank/migrations/160_betrieb_ferien.sql` | neue Tabellen + Felder + Übernahme der 40 Perioden |
| `lib/data/models/betrieb_ferien.dart` | Supabase-DTO einer Ferienperiode |
| `lib/data/local/betrieb_ferien_local.dart` (+ `_export`, `web/`) | Isar-Local + Web-Stub |
| `lib/data/mappers/betrieb_ferien_mapper.dart` | DTO ↔ Local |
| `lib/data/repositories/betrieb_ferien_repository.dart` | Datenzugriff (kIsWeb) |
| `lib/core/util/betrieb_ferien.dart` | **bestehend** — Aussenform bleibt, liest neu Perioden |
| `lib/core/util/ferien_vorjahr.dart` | **neu** — Vorjahres-Hinweis (reine Funktion) |
| `lib/data/models/betrieb_vorschlag.dart` + Repo/Provider | Vorschlags-Vertikale |
| `lib/presentation/screens/betriebe/betrieb_vorschlaege_screen.dart` | Prüfliste |
| `lib/presentation/screens/touren/tourenplanung_screen.dart` | «War geschlossen», Vorjahres-Band |
| `lib/presentation/screens/reinigungen/reinigung_form_screen.dart` | Ferienfrage beim Abschluss |
| `supabase/functions/betrieb-google-abgleich/index.ts` | **neu** — Google-Lauf |
| `supabase/functions/parse-oeffnungszeiten/index.ts` | **erweitert** — Ferien mitlesen |
| `Datenbank/migrations/161_datenpflege_cron.sql` | pg_cron-Jobs |

---

## Task 1: Migration 160 — Datenmodell

**Files:**
- Create: `Datenbank/migrations/160_betrieb_ferien.sql`

- [ ] **Schritt 1: Migration schreiben**

```sql
-- 160_betrieb_ferien.sql
-- Ferien als eigene Tabelle (statt 5 feste Spaltenpaare): traegt Historie,
-- Quelle und Bestaetigungsdatum. Grundlage fuer den Vorjahres-Hinweis.

create table if not exists betrieb_ferien (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betriebe(id) on delete cascade,
  von           date not null,
  bis           date not null,
  quelle        text not null default 'kunde'
                check (quelle in ('kunde','vor_ort','website','google','import')),
  bestaetigt_am timestamptz,
  notiz         text,
  user_id       uuid not null default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (bis >= von)
);

create index if not exists idx_betrieb_ferien_betrieb on betrieb_ferien(betrieb_id);
create index if not exists idx_betrieb_ferien_zeitraum on betrieb_ferien(von, bis);

alter table betrieb_ferien enable row level security;
create policy "betrieb_ferien_own" on betrieb_ferien
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Uebernahme der bestehenden 5 Slots. quelle='import', bewusst OHNE
-- bestaetigt_am: diese Angaben sind ungeprueft alt.
insert into betrieb_ferien (betrieb_id, von, bis, quelle, user_id)
select b.id, s.von, s.bis, 'import', b.user_id
from betriebe b
cross join lateral (values
  (b.ferien_start,  b.ferien_ende),
  (b.ferien2_start, b.ferien2_ende),
  (b.ferien3_start, b.ferien3_ende),
  (b.ferien4_start, b.ferien4_ende),
  (b.ferien5_start, b.ferien5_ende)
) as s(von, bis)
where s.von is not null and s.bis is not null and s.bis >= s.von;

-- Pflege-Zustand am Betrieb.
alter table betriebe add column if not exists ferien_bestaetigt_am timestamptz;
alter table betriebe add column if not exists ferien_frage_ruht_bis date;
alter table betriebe add column if not exists ruhetage_bestaetigt_am timestamptz;
alter table betriebe add column if not exists oeffnungszeiten_geprueft_am timestamptz;
alter table betriebe add column if not exists google_place_id text;

comment on column betriebe.ruhetage_bestaetigt_am is
  'Trennt "kein Ruhetag bekannt" (null) von "geprueft, hat keinen Ruhetag".';
comment on column betriebe.ferien_frage_ruht_bis is
  'Antwort "weiss nicht" im Abschluss-Dialog: bis dahin nicht erneut fragen.';

-- Vorschlaege aus Fremdquellen. Ein offener Eintrag je (Betrieb, Feld, Quelle).
create table if not exists betrieb_vorschlaege (
  id          uuid primary key default gen_random_uuid(),
  betrieb_id  uuid not null references betriebe(id) on delete cascade,
  feld        text not null check (feld in ('ruhetage','oeffnungszeiten','ferien','status')),
  alt_wert    jsonb,
  neu_wert    jsonb not null,
  quelle      text not null check (quelle in ('google','website','google_website')),
  konfidenz   numeric,
  gefunden_am timestamptz not null default now(),
  status      text not null default 'offen' check (status in ('offen','uebernommen','verworfen')),
  user_id     uuid not null default auth.uid()
);

create unique index if not exists idx_vorschlag_offen
  on betrieb_vorschlaege(betrieb_id, feld, quelle) where status = 'offen';

alter table betrieb_vorschlaege enable row level security;
create policy "betrieb_vorschlaege_own" on betrieb_vorschlaege
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Leerfahrt als Wegpunkt-Stempel zulassen.
alter table wegpunkte drop constraint if exists wegpunkte_quelle_check;
alter table wegpunkte add constraint wegpunkte_quelle_check
  check (quelle in (
    'reinigung', 'stoerung', 'montage',
    'arbeitsbeginn', 'feierabend',
    'pause_start', 'pause_ende',
    'vergeblich'
  ));
```

- [ ] **Schritt 2: Anwenden**

```bash
npx supabase db query --linked --file Datenbank/migrations/160_betrieb_ferien.sql
```

- [ ] **Schritt 3: Übernahme kontrollieren**

Erwartung: **40 Zeilen** in `betrieb_ferien`, alle mit `quelle='import'`; die Slot-Spalten in `betriebe` bleiben unverändert stehen.

```sql
select count(*) as perioden,
       count(*) filter (where quelle='import') as importiert,
       min(von) as frueheste, max(bis) as spaeteste
from betrieb_ferien;
```

- [ ] **Schritt 4: Commit**

```bash
git add Datenbank/migrations/160_betrieb_ferien.sql && git commit -m "feat(daten): Migration 160 - betrieb_ferien, Vorschlaege, Pflegefelder"
```

---

## Task 2: Ferien-Vertikale (DTO, Local, Mapper, Repository, Sync)

Folgt der Checkliste «Neue Entity hinzufügen» aus `CLAUDE.md`.

**Files:**
- Create: `lib/data/models/betrieb_ferien.dart`, `lib/data/local/betrieb_ferien_local.dart`, `lib/data/local/betrieb_ferien_local_export.dart`, `lib/data/local/web/betrieb_ferien_local_web.dart`, `lib/data/mappers/betrieb_ferien_mapper.dart`, `lib/data/repositories/betrieb_ferien_repository.dart`
- Modify: `lib/services/storage/isar_service.dart`, `lib/services/sync/sync_service.dart`

- [ ] **Schritt 1: DTO**

```dart
class BetriebFerienDto {
  final String id;
  final String betriebId;
  final DateTime von;
  final DateTime bis;
  final String quelle;        // kunde | vor_ort | website | google | import
  final DateTime? bestaetigtAm;
  final String? notiz;

  const BetriebFerienDto({
    required this.id,
    required this.betriebId,
    required this.von,
    required this.bis,
    required this.quelle,
    this.bestaetigtAm,
    this.notiz,
  });

  factory BetriebFerienDto.fromJson(Map<String, dynamic> j) => BetriebFerienDto(
    id: j['id'] as String,
    betriebId: j['betrieb_id'] as String,
    von: DateTime.parse(j['von'] as String),
    bis: DateTime.parse(j['bis'] as String),
    quelle: j['quelle'] as String? ?? 'kunde',
    bestaetigtAm: j['bestaetigt_am'] == null
        ? null
        : DateTime.parse(j['bestaetigt_am'] as String),
    notiz: j['notiz'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'betrieb_id': betriebId,
    'von': von.toIso8601String().substring(0, 10),
    'bis': bis.toIso8601String().substring(0, 10),
    'quelle': quelle,
    'bestaetigt_am': bestaetigtAm?.toIso8601String(),
    'notiz': notiz,
  };
}
```

- [ ] **Schritt 2: Isar-Local + Web-Stub + Conditional Export** nach dem Muster von `betrieb_local.dart` (Feldnamen identisch zum DTO, plus `isSynced`).
- [ ] **Schritt 3:** `dart run build_runner build --delete-conflicting-outputs`
- [ ] **Schritt 4: Mapper** `BetriebFerienMapper.fromDto` / `.toDto`
- [ ] **Schritt 5: IsarService** — typisierte Methoden `betriebFerienFindAll()`, `betriebFerienFuerBetrieb(String betriebId)`, `betriebFerienPut(...)`, `betriebFerienDelete(String id)` (Isar-Extensions nur hier, nie auf `dynamic`)
- [ ] **Schritt 6: Repository** mit `kIsWeb`-Branching nach bestehendem Muster; zusätzlich:

```dart
/// Legt eine Periode an und markiert den Betrieb als bestaetigt.
static Future<void> periodeErfassen({
  required String betriebId,
  required DateTime von,
  required DateTime bis,
  required String quelle,
  String? notiz,
}) async { ... }
```

- [ ] **Schritt 7: Sync** — Push/Pull für `betrieb_ferien` in der FK-Reihenfolge **nach** Betrieb einhängen.
- [ ] **Schritt 8:** `flutter analyze` (Baseline 54 Hinweise, keine neuen Fehler), `flutter test`
- [ ] **Schritt 9: Commit** `feat(daten): Ferien-Vertikale - DTO, Local, Mapper, Repository, Sync`

---

## Task 3: `betrieb_ferien.dart` auf Perioden umstellen (TDD)

Die Aussenform bleibt, damit Tourenplan, Heineken-Raster, Kalender-Sync und PDF unverändert weiterlaufen.

**Files:**
- Modify: `lib/core/util/betrieb_ferien.dart`
- Test: `test/betrieb_ferien_test.dart`

- [ ] **Schritt 1: Test schreiben** (schlägt fehl)

```dart
test('istInFerien erkennt eine Periode aus der Liste', () {
  final perioden = [
    (von: DateTime(2026, 7, 20), bis: DateTime(2026, 8, 10), quelle: 'kunde'),
  ];
  expect(istInFerienPerioden(perioden, DateTime(2026, 7, 25)), isTrue);
  expect(istInFerienPerioden(perioden, DateTime(2026, 7, 20)), isTrue); // Randtag
  expect(istInFerienPerioden(perioden, DateTime(2026, 8, 10)), isTrue); // Randtag
  expect(istInFerienPerioden(perioden, DateTime(2026, 8, 11)), isFalse);
});

test('mehrere Perioden werden alle geprueft', () { ... });
test('leere Liste heisst nie in Ferien', () { ... });
```

- [ ] **Schritt 2:** `flutter test test/betrieb_ferien_test.dart` → FAIL erwartet
- [ ] **Schritt 3: Implementieren** — `FerienPeriode` als Typedef, `istInFerienPerioden`, `ferienStartsAus`, `ferienEndenAus`; die alten Funktionen (`istInFerien(BetriebLocal, DateTime)`) bleiben als dünne Hülle, die die Perioden des Betriebs durchreicht.
- [ ] **Schritt 4:** Tests grün, `flutter test` gesamt grün
- [ ] **Schritt 5: Commit** `refactor(ferien): Perioden statt fester Slots, Aussenform unveraendert`

---

## Task 4: Baustein A — «War geschlossen»

**Files:**
- Modify: `lib/presentation/screens/touren/tourenplanung_screen.dart` (Block-Sheet)
- Create: `lib/presentation/widgets/war_geschlossen_sheet.dart`

- [ ] **Schritt 1: Sheet bauen** — CanvasKit-Regel beachten (GestureDetector + Container statt Material-Buttons). Drei Auswahlen:
  - **Betriebsferien** → zwei Datumsfelder, vorbelegt heute bis heute + 14 Tage → `BetriebFerienRepository.periodeErfassen(quelle: 'vor_ort')`, setzt `ferien_bestaetigt_am`
  - **Ruhetag** → Wochentags-Auswahl, vorbelegt heutiger Tag → ergänzt `ruhetage`, setzt `ruhetage_bestaetigt_am`
  - **Niemand da / anderes** → Notizfeld, keine Stammdaten-Änderung
- [ ] **Schritt 2:** In allen drei Fällen Wegpunkt `quelle: 'vergeblich'` mit Zeit, GPS und Notiz stempeln (bestehender `WegpunktRepository`-Aufruf wie bei Störung/Montage).
- [ ] **Schritt 3:** Block verschwindet aus dem Tagesplan; Hinweistext: «Besuch bleibt fällig — bitte neu einplanen.» **Keine automatische Neuplanung** (Entscheid Daniel).
- [ ] **Schritt 4:** Knopf «War geschlossen» im Block-Sheet ergänzen, nur bei heutigen und vergangenen Tagen.
- [ ] **Schritt 5:** `flutter analyze`, `flutter test`, visueller Test im Browser (Regel: UI vor Deploy visuell prüfen)
- [ ] **Schritt 6: Commit** `feat(touren): War-geschlossen-Knopf erfasst Ferien, Ruhetag und Leerfahrt`

---

## Task 5: Baustein B — Ferienfrage beim Reinigungs-Abschluss

**Files:**
- Modify: `lib/presentation/screens/reinigungen/reinigung_form_screen.dart` (Abschluss-Weg, ab `_save(abschliessen: true)`)
- Create: `lib/core/util/ferien_frage.dart` + `test/ferien_frage_test.dart`

- [ ] **Schritt 1: Test für die Sichtbarkeitsregel** (TDD)

```dart
test('Frage erscheint, wenn nie bestaetigt', () {
  expect(ferienFrageZeigen(bestaetigtAm: null, ruhtBis: null,
      heute: DateTime(2026, 7, 31)), isTrue);
});
test('Frage schweigt, wenn vor 3 Monaten bestaetigt', () {
  expect(ferienFrageZeigen(bestaetigtAm: DateTime(2026, 5, 1), ruhtBis: null,
      heute: DateTime(2026, 7, 31)), isFalse);
});
test('Frage erscheint wieder nach 12 Monaten', () {
  expect(ferienFrageZeigen(bestaetigtAm: DateTime(2025, 7, 1), ruhtBis: null,
      heute: DateTime(2026, 7, 31)), isTrue);
});
test('weiss nicht laesst die Frage 30 Tage ruhen', () {
  expect(ferienFrageZeigen(bestaetigtAm: null, ruhtBis: DateTime(2026, 8, 20),
      heute: DateTime(2026, 7, 31)), isFalse);
});
```

- [ ] **Schritt 2:** Test rot, dann `ferienFrageZeigen(...)` implementieren, Test grün
- [ ] **Schritt 3: UI** — im Abschluss-Dialog eine zusätzliche, **nicht blockierende** Zeile «Nächste Betriebsferien?» mit drei Antworten: *Keine geplant* (`keine_betriebsferien = true` + `ferien_bestaetigt_am`), *Von–bis* (Periode `quelle: 'kunde'`), *Weiss nicht* (`ferien_frage_ruht_bis = heute + 30 Tage`). Überspringen muss möglich sein, ohne den Abschluss zu blockieren.
- [ ] **Schritt 4:** `flutter analyze`, `flutter test`, visueller Test
- [ ] **Schritt 5: Commit** `feat(reinigung): Ferienfrage beim Abschluss, hoechstens einmal im Jahr`

---

## Task 6: Baustein D — Vorjahres-Hinweis

**Files:**
- Create: `lib/core/util/ferien_vorjahr.dart`, `test/ferien_vorjahr_test.dart`
- Modify: `lib/presentation/widgets/zeitplan_leiste.dart` (graues Band am Block)

- [ ] **Schritt 1: Tests schreiben**

```dart
test('Tag liegt im Vorjahres-Fenster -> Hinweis', () {
  final p = [(von: DateTime(2025, 7, 20), bis: DateTime(2025, 8, 10), quelle: 'kunde')];
  final h = vorjahresFerienHinweis(perioden: p, tag: DateTime(2026, 7, 31),
      hatAussageFuerJahr: false);
  expect(h, isNotNull);
  expect(h!.von, DateTime(2025, 7, 20));
});

test('Toleranz von 5 Tagen an den Raendern greift', () {
  final p = [(von: DateTime(2025, 7, 20), bis: DateTime(2025, 8, 10), quelle: 'kunde')];
  expect(vorjahresFerienHinweis(perioden: p, tag: DateTime(2026, 8, 14),
      hatAussageFuerJahr: false), isNotNull);   // 4 Tage nach Ende
  expect(vorjahresFerienHinweis(perioden: p, tag: DateTime(2026, 8, 20),
      hatAussageFuerJahr: false), isNull);      // 10 Tage nach Ende
});

test('kein Hinweis, wenn fuer dieses Jahr eine Aussage vorliegt', () {
  final p = [(von: DateTime(2025, 7, 20), bis: DateTime(2025, 8, 10), quelle: 'kunde')];
  expect(vorjahresFerienHinweis(perioden: p, tag: DateTime(2026, 7, 31),
      hatAussageFuerJahr: true), isNull);
});

test('zwei Jahre zurueck zaehlt auch, drei nicht mehr', () { ... });
```

- [ ] **Schritt 2:** Test rot → implementieren → grün
- [ ] **Schritt 3: UI** — graues Band am Tagesplan-Block: «Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen». Rein informativ: **keine** Fälligkeitsverschiebung, **keine** Umplanung, optisch klar von der roten Ferien-Warnung unterschieden.
- [ ] **Schritt 4:** `flutter test`, visueller Test
- [ ] **Schritt 5: Commit** `feat(touren): Vorjahres-Hinweis auf frueher erfasste Betriebsferien`

---

## Task 7: Vorschlags-Vertikale + Prüflisten-Screen

**Files:**
- Create: `lib/data/models/betrieb_vorschlag.dart`, `lib/data/repositories/betrieb_vorschlag_repository.dart`, `lib/presentation/providers/betrieb_vorschlag_providers.dart`, `lib/presentation/screens/betriebe/betrieb_vorschlaege_screen.dart`
- Modify: `lib/core/config/router.dart` (Route `/betriebe/vorschlaege`), `lib/presentation/screens/aufgaben/aufgaben_screen.dart` (Zeile mit Zähler)

- [ ] **Schritt 1:** DTO + Repository (`offene()`, `uebernehmen(id)`, `verwerfen(id)`, `alleUebernehmen(quelle)`); Web über Supabase, Native über Isar — Vorschläge sind reine Server-Daten, deshalb genügt hier der Supabase-Weg mit `kIsWeb`-Gate wie bei anderen Server-only-Listen.
- [ ] **Schritt 2:** Screen — je Zeile Betrieb, Feld, **alt → neu**, Quelle, Datum; Aktionen Übernehmen / Verwerfen; oben «Alle übernehmen, bei denen Google und Website übereinstimmen» (`quelle = 'google_website'`).
- [ ] **Schritt 3:** Übernehmen schreibt den Wert in den Betrieb und setzt `oeffnungszeiten_geprueft_am` bzw. `ruhetage_bestaetigt_am`; bei `feld = 'ferien'` entsteht eine Periode mit der jeweiligen Quelle (**ohne** `bestaetigt_am` — eine Fremdquelle bestätigt nichts).
- [ ] **Schritt 4:** Zeile im Aufgaben-Screen: «N Änderungsvorschläge prüfen» → Route.
- [ ] **Schritt 5:** `flutter analyze`, `flutter test`, visueller Test
- [ ] **Schritt 6: Commit** `feat(betriebe): Pruefliste fuer Aenderungsvorschlaege aus Google und Website`

---

## Task 8: Edge-Function `betrieb-google-abgleich`

**Files:**
- Create: `supabase/functions/betrieb-google-abgleich/index.ts`

- [ ] **Schritt 1:** Function schreiben. Ablauf je Betrieb:
  1. Ohne `google_place_id`: per `places:searchText` (Name + Adresse) ermitteln, mit `places.id` in der FieldMask, und am Betrieb speichern.
  2. Mit `place_id`: `GET https://places.googleapis.com/v1/places/{id}` mit FieldMask `regularOpeningHours,currentOpeningHours,businessStatus`.
  3. Öffnungszeiten in das App-Format (`{"Mo": [{"von","bis"}], …}`) normalisieren — dieselbe Struktur, die `parse-oeffnungszeiten` liefert.
  4. Abweichung zum gespeicherten Wert → Vorschlag `quelle='google'`. `businessStatus = CLOSED_TEMPORARILY` → Vorschlag `feld='status'`.
  5. `oeffnungszeiten_geprueft_am` setzen — auch wenn nichts abweicht, sonst prüft der Lauf denselben Betrieb ewig erneut.
- [ ] **Schritt 2:** Aufrufform: `{"betriebIds": [...]}` oder `{"limit": 10}` (älteste `oeffnungszeiten_geprueft_am` zuerst, `null` zuerst).
- [ ] **Schritt 3:** Deploy `supabase functions deploy betrieb-google-abgleich --no-verify-jwt`
- [ ] **Schritt 4:** Manueller Testlauf mit `{"limit": 3}`, Ergebnis in `betrieb_vorschlaege` prüfen.
- [ ] **Schritt 5: Commit** `feat(edge): betrieb-google-abgleich holt Oeffnungszeiten und Status`

---

## Task 9: `parse-oeffnungszeiten` um Ferien erweitern

**Files:**
- Modify: `supabase/functions/parse-oeffnungszeiten/index.ts`

- [ ] **Schritt 1:** Prompt ergänzen — zusätzlich zu Öffnungszeiten und Ruhetagen:

```
  "ferien": [{"von":"YYYY-MM-DD","bis":"YYYY-MM-DD"}],
  "ferien_konfidenz": 0.0
```

Regeln im Prompt: Betriebsferien erkennen an Formulierungen wie «Betriebsferien», «Ferien vom … bis …», «wir sind zurück ab …»; **Jahr nur übernehmen, wenn es dasteht** — sonst das laufende Jahr annehmen und die Konfidenz senken; nichts erfinden.

- [ ] **Schritt 2:** Ergebnis in Vorschläge schreiben (`quelle='website'`), nicht direkt in den Betrieb. Betriebe ohne Website überspringen (`website` leer bei 35 der aktiven).
- [ ] **Schritt 3:** Modell auf Haiku stellen — reine Extraktion, deutlich billiger.
- [ ] **Schritt 4:** Deploy + Testlauf an drei Betrieben mit bekannten Ferien-Angaben auf der Website.
- [ ] **Schritt 5: Commit** `feat(edge): parse-oeffnungszeiten liest auch Betriebsferien`

---

## Task 10: Täglicher Lauf, Zusammenführung, Deploy

**Files:**
- Create: `Datenbank/migrations/161_datenpflege_cron.sql`

- [ ] **Schritt 1:** `pg_cron` aktivieren und beide Läufe planen:

```sql
create extension if not exists pg_cron;

-- Taeglich 04:20: je zehn Betriebe bei Google UND auf der Website pruefen
-- (Entscheid Daniel 31.07.: immer beide Quellen, nicht entweder/oder).
select cron.schedule('betriebsdaten-google', '20 4 * * *', $$
  select net.http_post(
    url := 'https://pltbaqqwpnmdajwgnhpd.supabase.co/functions/v1/betrieb-google-abgleich',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{"limit":10}'::jsonb
  );
$$);

select cron.schedule('betriebsdaten-website', '40 4 * * *', $$
  select net.http_post(
    url := 'https://pltbaqqwpnmdajwgnhpd.supabase.co/functions/v1/parse-oeffnungszeiten',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{"limit":10}'::jsonb
  );
$$);
```

- [ ] **Schritt 2:** Zusammenführung — liefern beide Quellen für dasselbe Feld denselben Wert, wird daraus **ein** Vorschlag mit `quelle='google_website'` (Sammelübernahme). Widersprechen sie sich, bleiben beide stehen.
- [ ] **Schritt 3:** Ersten Lauf überwachen: `select * from cron.job_run_details order by start_time desc limit 10;`
- [ ] **Schritt 4:** Gesamtverifikation — `flutter analyze` (Baseline 54), `flutter test` (784 + neue Tests grün)
- [ ] **Schritt 5:** Version bumpen (`pubspec.yaml` + `kAppVersion` in `lib/core/app_version.dart`), Build, Cache-Bust, gh-pages-Deploy nach dem Ablauf in `CLAUDE.md`
- [ ] **Schritt 6:** `ToDo.md`, `Projekt.md` und Memory nachziehen
- [ ] **Schritt 7: Commit + Deploy**

---

## Prüfpunkte für Daniel nach dem Deploy

1. Bei einem geschlossenen Betrieb «War geschlossen» → Ferien eintragen → erscheint die Periode im Betriebs-Detail?
2. Eine Reinigung abschliessen → kommt die Ferienfrage, und schweigt sie beim nächsten Besuch desselben Betriebs?
3. Tagesplan eines Tages, an dem im Vorjahr Ferien waren → erscheint das graue Band?
4. Nach dem ersten nächtlichen Lauf: Sind in der Prüfliste plausible Vorschläge, und stimmen die Werte mit dem überein, was auf der Website steht?
