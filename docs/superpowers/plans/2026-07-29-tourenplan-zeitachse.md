# Tourenplan-Zeitachse — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Tagesplan-Tab wird ein berechneter Tageszeitplan: Zeitleiste ab 06:00, Besuchs-Blöcke in Dauer-Höhe, Fahrzeiten aus lernender Kaskade, Termin-Anker mit sichtbarer Wartezeit, Anfahrt/Heimweg, Arbeitstag-Erfassung, Plan-Übernahme von beliebigem Datum.

**Architektur:** Reine, getestete Logik in `lib/core/util/` (besuch_dauer, fahrzeit, zeitplan); Persistenz über neue Tabelle `fahrzeiten` + erweiterte `tagesplaene`; Edge-Function als OSRM-Proxy mit Cache; UI zeichnet die bestehende ReorderableList auf eine Zeitleiste. Spec: `docs/superpowers/specs/2026-07-29-tourenplan-zeitachse-design.md` — bei Detailfragen gilt die Spec.

**Tech Stack:** Flutter Web (CanvasKit!) + Supabase (PostgREST, Edge Functions/Deno) + Riverpod. Tests: `flutter test`, `deno test`.

**Projektregeln (gelten für JEDEN Task):**
- Arbeit auf `main` (Projekt-Workflow, vom User freigegeben). NIEMALS `git stash`.
- Flutter in Bash: `export PATH="$PATH:/c/flutter/bin"`, Verzeichnis `sbs_projer_app`.
- CanvasKit-Falle: Aktions-Buttons als `GestureDetector`+`Container`, keine Material-Buttons in neuen Sheets.
- Supabase-DDL via MCP `apply_migration` (project_id `pltbaqqwpnmdajwgnhpd`), SQL-Datei zusätzlich in `Datenbank/migrations/` ablegen.
- Kommunikation/Kommentare Deutsch. Kommentare erklären das Warum.
- Commit je Task mit `git commit -F <msgdatei>` (Heredoc-Falle in Git Bash).

---

### Task 1: Migration 152 — fahrzeiten, tagesplaene-Erweiterung, Startort, Backfill

**Files:**
- Create: `Datenbank/migrations/152_fahrzeiten_tagesplan.sql`
- Ausführen via MCP `apply_migration` (name `152_fahrzeiten_tagesplan`)

- [ ] **Step 1: SQL-Datei schreiben** — exakt dieser Inhalt:

```sql
-- 152: Fahrzeiten-Kaskade + Arbeitstag-Rahmen (Spec 2026-07-29 Tourenplan-Zeitachse)

-- 1) Gelernte/gecachte Fahrzeiten zwischen Betrieben.
create table if not exists fahrzeiten (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  von_betrieb_id uuid not null references betriebe(id) on delete cascade,
  nach_betrieb_id uuid not null references betriebe(id) on delete cascade,
  minuten int not null check (minuten between 1 and 300),
  quelle text not null check (quelle in ('beobachtet','route')),
  anzahl int not null default 1,
  updated_at timestamptz not null default now(),
  unique (user_id, von_betrieb_id, nach_betrieb_id)
);
alter table fahrzeiten enable row level security;
create policy fahrzeiten_all on fahrzeiten
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2) Arbeitstag-Rahmen am Tagesplan.
alter table tagesplaene
  add column if not exists arbeitsbeginn text,
  add column if not exists arbeitsende text,
  add column if not exists km_stand int;

-- 3) Startort (Zuhause) fuer Anfahrt/Heimweg.
alter table geschaeft_einstellungen
  add column if not exists startort_lat numeric,
  add column if not exists startort_lng numeric;

-- 4) Backfill beobachteter Fahrzeiten aus historischen Reinigungen:
--    Uebergang = Ende bei Betrieb A -> Start bei Betrieb B am selben Tag,
--    Luecke 3-120 min gilt als Fahrzeit. Median je Richtungspaar.
with tagesfolge as (
  select user_id, betrieb_id, datum,
         (datum::timestamp + uhrzeit_start::time) as start_ts,
         (datum::timestamp + uhrzeit_ende::time) as ende_ts
  from reinigungen
  where uhrzeit_start is not null and uhrzeit_ende is not null
    and betrieb_id is not null
),
uebergaenge as (
  select a.user_id, a.betrieb_id as von_id, b.betrieb_id as nach_id,
         extract(epoch from (b.start_ts - a.ende_ts)) / 60.0 as luecke_min
  from tagesfolge a
  join lateral (
    select * from tagesfolge b
    where b.user_id = a.user_id and b.datum = a.datum
      and b.start_ts > a.ende_ts and b.betrieb_id <> a.betrieb_id
    order by b.start_ts limit 1
  ) b on true
  where extract(epoch from (b.start_ts - a.ende_ts)) / 60.0 between 3 and 120
)
insert into fahrzeiten (user_id, von_betrieb_id, nach_betrieb_id, minuten, quelle, anzahl)
select user_id, von_id, nach_id,
       round(percentile_cont(0.5) within group (order by luecke_min))::int,
       'beobachtet', count(*)
from uebergaenge
group by user_id, von_id, nach_id
on conflict (user_id, von_betrieb_id, nach_betrieb_id) do nothing;
```

- [ ] **Step 2: Migration anwenden** via MCP `apply_migration`, dann Kontrolle per `execute_sql`:

```sql
select quelle, count(*) as paare, round(avg(minuten)) as schnitt_min,
       min(minuten) as min, max(minuten) as max from fahrzeiten group by quelle;
```
Erwartet: eine Zeile `beobachtet` mit >0 Paaren, Minuten im Bereich 3–120. Zweite Kontrolle: `select column_name from information_schema.columns where table_name='tagesplaene';` enthält arbeitsbeginn/arbeitsende/km_stand.

- [ ] **Step 3: Commit** — `git add Datenbank/migrations/152_fahrzeiten_tagesplan.sql`, Message `feat(db): Migration 152 - fahrzeiten-Tabelle mit Backfill, Arbeitstag-Spalten, Startort`.

---

### Task 2: Edge-Function `fahrzeit-route` (OSRM-Proxy mit Cache)

**Files:**
- Create: `supabase/functions/fahrzeit-route/index.ts`
- Deploy: `npx supabase functions deploy fahrzeit-route --project-ref pltbaqqwpnmdajwgnhpd` (dangerouslyDisableSandbox nötig)

- [ ] **Step 1: Function schreiben** — Muster von `supabase/functions/google-contacts-sync/index.ts` übernehmen (CORS-Header, Auth via `createClient` mit Authorization-Header des Aufrufers, Admin-Client mit SERVICE_ROLE für DB-Schreiben). Kern:

```ts
// Supabase Edge Function: fahrzeit-route
// Liefert die Fahrzeit zwischen zwei Betrieben. Reihenfolge:
// 1) Cache/Beobachtung aus `fahrzeiten` (beide Richtungen; beobachtet > route)
// 2) OSRM-Demo-Server (kein Key, Fair-Use — dank Cache selten gebraucht),
//    Ergebnis wird als quelle='route' gecached.
// Antwort: { ok: true, minuten, quelle } | { ok: false, error }
// Kein Treffer/OSRM down -> ok:false; die App faellt auf die Heuristik zurueck.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), {
    status: s, headers: { ...CORS, "Content-Type": "application/json" },
  });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const { data: { user: u } } = await user.auth.getUser();
    if (!u) return json({ ok: false, error: "unauthorized" }, 401);
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { vonBetriebId, nachBetriebId } = await req.json();
    if (!vonBetriebId || !nachBetriebId || vonBetriebId === nachBetriebId) {
      return json({ ok: false, error: "bad_request" }, 400);
    }

    // 1) Cache: gespeicherte Richtung, dann Gegenrichtung.
    const { data: hin } = await admin.from("fahrzeiten").select("minuten, quelle")
      .eq("user_id", u.id).eq("von_betrieb_id", vonBetriebId)
      .eq("nach_betrieb_id", nachBetriebId).maybeSingle();
    if (hin) return json({ ok: true, minuten: hin.minuten, quelle: hin.quelle });
    const { data: rueck } = await admin.from("fahrzeiten").select("minuten, quelle")
      .eq("user_id", u.id).eq("von_betrieb_id", nachBetriebId)
      .eq("nach_betrieb_id", vonBetriebId).maybeSingle();
    if (rueck) return json({ ok: true, minuten: rueck.minuten, quelle: rueck.quelle });

    // 2) OSRM. Koordinaten der beiden Betriebe laden.
    const { data: bs } = await admin.from("betriebe").select("id, latitude, longitude")
      .in("id", [vonBetriebId, nachBetriebId]);
    const von = bs?.find((b: { id: string }) => b.id === vonBetriebId);
    const nach = bs?.find((b: { id: string }) => b.id === nachBetriebId);
    if (!von?.latitude || !nach?.latitude) return json({ ok: false, error: "no_gps" });

    const url = `https://router.project-osrm.org/route/v1/driving/` +
      `${von.longitude},${von.latitude};${nach.longitude},${nach.latitude}` +
      `?overview=false`;
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return json({ ok: false, error: `osrm_${res.status}` });
    const data = await res.json();
    const sek = data.routes?.[0]?.duration;
    if (typeof sek !== "number") return json({ ok: false, error: "osrm_no_route" });
    const minuten = Math.max(1, Math.round(sek / 60));

    // Cachen — Beobachtungen ueberschreibt das nie (do nothing bei Konflikt).
    await admin.from("fahrzeiten").insert({
      user_id: u.id, von_betrieb_id: vonBetriebId, nach_betrieb_id: nachBetriebId,
      minuten, quelle: "route",
    }).select().maybeSingle();
    return json({ ok: true, minuten, quelle: "route" });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
```

- [ ] **Step 2: `deno check index.ts` + `deno lint index.ts`** im Function-Ordner — 0 Fehler.
- [ ] **Step 3: Deployen**, danach Smoke-Test via `execute_sql` NICHT möglich — stattdessen per curl mit anon key testen ODER als erledigt markieren, wenn Deploy-Log ok (App-Test folgt in Task 9).
- [ ] **Step 4: Commit** `feat(edge): fahrzeit-route - OSRM-Proxy mit fahrzeiten-Cache`.

---

### Task 3: Dauer-Kette vervollständigen + `besuch_dauer.dart` (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/data/local/reinigung_local.dart` (Feld `int? dauerMinuten;` bei den Zeit-Feldern ~Z.25)
- Modify: `sbs_projer_app/lib/data/local/web/reinigung_local_web.dart` (gleiches Feld)
- Modify: `sbs_projer_app/lib/data/mappers/reinigung_mapper.dart` (fromDto/toJson: `dauer_minuten`)
- Modify: Reinigungs-Repository Web-Spaltenliste (`_listCols` o. ä. — suchen nach `uhrzeit_start` im Repository und `dauer_minuten` ergänzen, falls Spaltenliste existiert)
- Danach: `dart run build_runner build --delete-conflicting-outputs` (Isar-Codegen)
- Create: `sbs_projer_app/lib/core/util/besuch_dauer.dart`
- Test: `sbs_projer_app/test/besuch_dauer_test.dart`

- [ ] **Step 1: Datenkette erweitern** (Local + Web-Stub + Mapper + Spaltenliste + build_runner). `uhrzeitStart/uhrzeitEnde/anlageIds` existieren bereits.

- [ ] **Step 2: Failing Tests schreiben** — `test/besuch_dauer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/besuch_dauer.dart';

BesuchHistorie h(int anlagen, int minuten) =>
    (anlagenZahl: anlagen, dauerMinuten: minuten);

void main() {
  group('geschaetzteDauer (Spec 2026-07-29, Kaskade)', () {
    test('Median der Besuche mit gleicher Anlagenzahl', () {
      final hist = [h(1, 30), h(1, 34), h(1, 200), h(2, 50)];
      // Median von 30/34/200 = 34 — der Langlaeufer verzerrt nicht.
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 1), 34);
    });
    test('keine passende Anlagenzahl: Betriebs-Median ueber Kurve skaliert', () {
      final hist = [h(1, 30), h(1, 40)]; // Betriebs-Median (1 Anlage) = 35
      // Kurve 1->28, 2->33: 35 * 33/28 = 41.25 -> 41
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 2), 41);
    });
    test('Kurve ueber 4 Anlagen linear fortgeschrieben', () {
      // Stuetzwerte 3->54, 4->86, Schritt 32: 5 Anlagen -> 118 (global, ohne Historie
      // greift Default — also Historie mit 4er-Besuch: Median 86 -> 5er = 86*118/86)
      final hist = [h(4, 86)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 5), 118);
    });
    test('nur Werte 5-300 min zaehlen', () {
      final hist = [h(1, 2), h(1, 400), h(1, 30)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 1), 30);
    });
    test('ohne Historie: 60 min Default', () {
      expect(geschaetzteDauer(historie: [], anlagenZahl: 3), 60);
    });
    test('gemischte Anlagenzahl: gleicher Zahl-Median gewinnt vor Skalierung', () {
      final hist = [h(2, 44), h(2, 48), h(1, 20)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 2), 46);
    });
  });

  group('dauerAusReinigung', () {
    test('dauer_minuten hat Vorrang', () {
      expect(dauerAusReinigung(dauerMinuten: 42, start: '08:00', ende: '09:30'), 42);
    });
    test('sonst aus Start/Ende gerechnet', () {
      expect(dauerAusReinigung(dauerMinuten: null, start: '08:00', ende: '09:30'), 90);
    });
    test('unbrauchbare Zeiten -> null', () {
      expect(dauerAusReinigung(dauerMinuten: null, start: '09:00', ende: '08:00'), null);
      expect(dauerAusReinigung(dauerMinuten: null, start: null, ende: '08:00'), null);
    });
  });
}
```

- [ ] **Step 3: Test rot laufen lassen** (`flutter test test/besuch_dauer_test.dart` → Compile-Fehler erwartet).

- [ ] **Step 4: `besuch_dauer.dart` implementieren:**

```dart
/// Dauer-Schaetzung fuer Besuchs-Bloecke im Tourenplan (Spec 2026-07-29).
///
/// Kaskade: Median der Besuche dieses Betriebs mit gleicher Anlagenzahl ->
/// Betriebs-Median ueber die globale Kurve skaliert -> 60 min. Der Median ist
/// bewusst gewaehlt: einzelne Langlaeufer (Reparatur nebenbei) verzerren ihn
/// nicht — genau Daniels «Durchschnitt ohne Ausreisser», ohne erfundene Grenze.
library;

typedef BesuchHistorie = ({int anlagenZahl, int dauerMinuten});

/// Globale Median-Kurve je Anlagenzahl (aus 8'472 Reinigungen, 29.07.2026).
/// Ueber 4 Anlagen linear fortgeschrieben (+32 min je weitere Anlage).
const _kurve = <int, int>{1: 28, 2: 33, 3: 54, 4: 86};

int _kurvenWert(int anlagen) {
  if (anlagen <= 0) return _kurve[1]!;
  final k = _kurve[anlagen];
  if (k != null) return k;
  return _kurve[4]! + (anlagen - 4) * (_kurve[4]! - _kurve[3]!);
}

int? _median(List<int> werte) {
  if (werte.isEmpty) return null;
  final s = [...werte]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
}

const int kDauerDefaultMinuten = 60;

/// Voraussichtliche Dauer eines Besuchs mit [anlagenZahl] Anlagen.
int geschaetzteDauer({
  required List<BesuchHistorie> historie,
  required int anlagenZahl,
}) {
  final gueltig = historie.where((b) =>
      b.dauerMinuten >= 5 && b.dauerMinuten <= 300).toList();
  final gleiche = _median([
    for (final b in gueltig) if (b.anlagenZahl == anlagenZahl) b.dauerMinuten,
  ]);
  if (gleiche != null) return gleiche;

  // Betriebs-Median (haeufigste Anlagenzahl als Referenz) ueber Kurve skalieren.
  if (gueltig.isNotEmpty) {
    final zaehlung = <int, int>{};
    for (final b in gueltig) {
      zaehlung[b.anlagenZahl] = (zaehlung[b.anlagenZahl] ?? 0) + 1;
    }
    final refZahl = (zaehlung.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first.key;
    final refMedian = _median([
      for (final b in gueltig) if (b.anlagenZahl == refZahl) b.dauerMinuten,
    ])!;
    return (refMedian * _kurvenWert(anlagenZahl) / _kurvenWert(refZahl)).round();
  }
  return kDauerDefaultMinuten;
}

/// Dauer einer historischen Reinigung: dauer_minuten hat Vorrang, sonst
/// Ende - Start (HH:mm); unbrauchbar -> null.
int? dauerAusReinigung({int? dauerMinuten, String? start, String? ende}) {
  if (dauerMinuten != null && dauerMinuten > 0) return dauerMinuten;
  if (start == null || ende == null) return null;
  int? min(String s) {
    final t = s.split(':');
    if (t.length < 2) return null;
    final h = int.tryParse(t[0]), m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
  final a = min(start), b = min(ende);
  if (a == null || b == null || b <= a) return null;
  return b - a;
}
```

- [ ] **Step 5: Tests grün + `flutter analyze` 0 Fehler.** (Erwartung Test 3 prüfen: Historie 4→86 = Kurvenwert 4, Skalierung 86×118/86=118 ✓; Test 2: 35×33/28=41.25→41 ✓.)
- [ ] **Step 6: Commit** `feat(touren): Besuchsdauer-Schaetzung (Median-Kaskade) + dauerMinuten in lokaler Kette`.

---

### Task 4: Fahrzeit-Kaskade Client — `fahrzeit.dart` + Repository

**Files:**
- Create: `sbs_projer_app/lib/core/util/fahrzeit.dart` (rein: Haversine, Heuristik, Cache-Wahl)
- Create: `sbs_projer_app/lib/data/repositories/fahrzeit_repository.dart`
- Test: `sbs_projer_app/test/fahrzeit_test.dart`

- [ ] **Step 1: Failing Tests:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';

void main() {
  group('haversineKm', () {
    test('Chur -> Davos ~ 42 km Luftlinie', () {
      final km = haversineKm(46.8508, 9.5320, 46.8027, 9.8360);
      expect(km, closeTo(23.7, 1.5)); // echte Luftlinie Chur-Davos ~23-24 km
    });
    test('identischer Punkt = 0', () {
      expect(haversineKm(47.0, 9.0, 47.0, 9.0), 0);
    });
  });

  group('heuristikMinuten', () {
    test('45 km/h Schnitt x Faktor 1.6', () {
      // 30 km Luftlinie -> 48 km Strasse -> 64 min
      expect(heuristikMinuten(luftlinieKm: 30, faktor: 1.6), 64);
    });
    test('Minimum 3 min fuer Nachbarn', () {
      expect(heuristikMinuten(luftlinieKm: 0.3, faktor: 1.6), 3);
    });
  });

  group('waehleFahrzeit', () {
    test('beobachtet schlaegt route schlaegt heuristik', () {
      expect(waehleFahrzeit(beobachtet: 12, route: 20, heuristik: 30), (12, FahrzeitQuelle.beobachtet));
      expect(waehleFahrzeit(beobachtet: null, route: 20, heuristik: 30), (20, FahrzeitQuelle.route));
      expect(waehleFahrzeit(beobachtet: null, route: null, heuristik: 30), (30, FahrzeitQuelle.heuristik));
    });
  });
}
```

- [ ] **Step 2: `fahrzeit.dart` implementieren:**

```dart
/// Fahrzeit-Heuristik + Kaskaden-Wahl (Spec 2026-07-29).
/// Die gelernten/gerouteten Werte kommen aus der Tabelle `fahrzeiten`
/// (FahrzeitRepository); hier liegt nur die reine, testbare Logik.
library;
import 'dart:math';

enum FahrzeitQuelle { beobachtet, route, heuristik }

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Standard-Umwegfaktor Strasse/Luftlinie im Berggebiet.
const double kFahrzeitFaktor = 1.6;
/// Angenommene Durchschnittsgeschwindigkeit (Berggebiet, Ortsdurchfahrten).
const double kSchnittKmh = 45.0;

int heuristikMinuten({required double luftlinieKm, double faktor = kFahrzeitFaktor}) {
  final min = (luftlinieKm * faktor) / kSchnittKmh * 60;
  return max(3, min.round());
}

(int, FahrzeitQuelle) waehleFahrzeit({int? beobachtet, int? route, required int heuristik}) {
  if (beobachtet != null) return (beobachtet, FahrzeitQuelle.beobachtet);
  if (route != null) return (route, FahrzeitQuelle.route);
  return (heuristik, FahrzeitQuelle.heuristik);
}
```

- [ ] **Step 3: Repository** — `fahrzeit_repository.dart`: lädt beim Screen-Start ALLE `fahrzeiten` des Users in eine Map `'$von>$nach' -> (minuten, quelle)` (eine Abfrage, kein N+1); `fahrzeitFuer(vonId, nachId)` prüft Hin- dann Gegenrichtung; `routeAnfordern(vonId, nachId)` ruft die Edge-Function `fahrzeit-route` (functions.invoke) fire-and-forget, aktualisiert die Map bei Erfolg und benachrichtigt via Callback (Provider invalidiert). Fehler still (Heuristik zeigt derweil). Startort: `fahrzeitVonStartort(lat, lng, betrieb)` nur Heuristik ODER Route via Koordinaten — vereinfacht: Startort-Strecken IMMER Heuristik (keine Betriebs-ID, kein Cache) — Kommentar mit Begründung.
- [ ] **Step 4: Beobachtung nachführen** (Spec §3.1, «wird mit der Zeit genauer»): `FahrzeitRepository.beobachtungNachfuehren({vonBetriebId, nachBetriebId, minuten})` — upsert mit gleitendem Median-Ersatz: bestehender Eintrag `beobachtet` → `minuten = round((alt*anzahl + neu)/(anzahl+1))`, `anzahl+1`; Eintrag `route` oder fehlend → überschreiben mit `quelle='beobachtet', anzahl=1`. Verdrahtung: Beim Speichern einer Reinigung MIT `uhrzeitStart`+`uhrzeitEnde` (Abschluss-Fluss in `reinigung_form_screen.dart` — Stelle per `grep -n "uhrzeitEnde" lib/presentation/screens/reinigungen/reinigung_form_screen.dart` finden) wird die zeitlich letzte frühere Reinigung DESSELBEN Tages mit anderem Betrieb gesucht (aus `reinigungenProvider`); Lücke 3–120 min → nachführen, fire-and-forget, Fehler still.
- [ ] **Step 5: Tests grün, analyze 0 Fehler, Commit** `feat(touren): Fahrzeit-Heuristik + Kaskaden-Repository + Beobachtungs-Nachfuehrung`.

---

### Task 5: TourEintrag-Erweiterung + `zeitplan.dart` (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart:315-365` (TourEintrag), `:849-893` (JSON), `:895-930` (Laden/Speichern inkl. neue tagesplaene-Spalten)
- Create: `sbs_projer_app/lib/core/util/zeitplan.dart`
- Test: `sbs_projer_app/test/zeitplan_test.dart`

- [ ] **Step 1: TourEintrag erweitern** — neue Felder, alle optional mit Default (bestehende Aufrufer kompilieren unverändert):

```dart
  final List<String> anlageIds;   // Besuchs-Anlagen (Reinigung); ersetzt anlageId fachlich
  final int? dauerMinuten;        // manuelle Uebersteuerung der Dauer
  final String? ankerZeit;        // 'HH:mm' — fruehestens ab (Termin/Servicezeit)
  final bool uebernommen;         // aus Plan-Uebernahme, heute nicht faellig -> grau
```
Konstruktor: `this.anlageIds = const [], this.dauerMinuten, this.ankerZeit, this.uebernommen = false`. `alsPlanEintrag()` reicht alle vier durch. `copyWith`-Methode ergänzen (typ/id fest, Rest optional — wird vom Block-Sheet gebraucht).
JSON: `'anlageIds': e.anlageIds, 'dauerMinuten': e.dauerMinuten, 'ankerZeit': e.ankerZeit, 'uebernommen': e.uebernommen`; beim Lesen **Lademigration**: `anlageIds` = Liste aus JSON, sonst `[if (j['anlageId'] != null) j['anlageId'] as String]` (Altpläne). `anlageId`-Getter bleibt als `anlageIds.firstOrNull`-Weiche? NEIN — Feld `anlageId` bleibt vorhanden und wird weiter befüllt (erste Anlage), damit bestehende Screens (Reinigung starten) nicht brechen; Kommentar dazu.

- [ ] **Step 2: tagesplaene-Rahmen** — `tagesplanSpeichern` um benannte Parameter `String? arbeitsbeginn, String? arbeitsende, int? kmStand` erweitern (ins upsert-Map, nur wenn nicht null: `if (arbeitsbeginn != null) 'arbeitsbeginn': arbeitsbeginn, ...`); `gespeicherterTagesplanProvider` liefert neu ein Record `({List<TourEintrag> eintraege, String? arbeitsbeginn, String? arbeitsende, int? kmStand})?` — Aufrufer in `tourenplanung_screen.dart:78-108` anpassen (nur `.eintraege` nutzen, Rahmen in State übernehmen).

- [ ] **Step 3: Failing Tests `zeitplan_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';

PlanBlock b(String id, int dauer, {String? anker}) =>
    PlanBlock(id: id, dauerMinuten: dauer, ankerZeit: anker);

void main() {
  group('berechneZeitplan (Spec 2026-07-29)', () {
    test('Kette: Anfahrt, Besuche, Fahrten, Heimweg', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30), b('c', 60)],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: 20,
        heimwegMinuten: 25,
        fahrzeitZwischen: (von, nach) => 10,
      );
      expect(s.map((x) => x.art).toList(), [
        SegmentArt.anfahrt, SegmentArt.besuch, SegmentArt.fahrt,
        SegmentArt.besuch, SegmentArt.heimweg,
      ]);
      expect(s[0].startMin, 6 * 60);          // 06:00 Anfahrt
      expect(s[1].startMin, 6 * 60 + 20);     // 06:20 Besuch a
      expect(s[3].startMin, 6 * 60 + 60);     // 07:00 Besuch c (06:50 + 10 Fahrt)
      expect(s[4].endMin, 6 * 60 + 120 + 25); // Heimweg-Ende 08:25
    });
    test('Anker erzeugt Wartezeit', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 30), b('c', 30, anker: '08:00')],
        arbeitsbeginn: '06:00',
        anfahrtMinuten: 0, heimwegMinuten: 0,
        fahrzeitZwischen: (v, n) => 10,
      );
      final warte = s.firstWhere((x) => x.art == SegmentArt.wartezeit);
      expect(warte.startMin, 6 * 60 + 40);           // nach Fahrt 06:40
      expect(warte.endMin, 8 * 60);                  // bis Anker
      expect(s.last.startMin, 8 * 60);               // Besuch c ab 08:00
    });
    test('Anker in der Vergangenheit: keine Wartezeit', () {
      final s = berechneZeitplan(
        bloecke: [b('a', 120, anker: '06:30')],
        arbeitsbeginn: '07:00', anfahrtMinuten: 0, heimwegMinuten: 0,
        fahrzeitZwischen: (v, n) => 0,
      );
      expect(s.any((x) => x.art == SegmentArt.wartezeit), isFalse);
    });
    test('leer: nur nichts', () {
      expect(berechneZeitplan(bloecke: [], arbeitsbeginn: '06:00',
        anfahrtMinuten: 0, heimwegMinuten: 0, fahrzeitZwischen: (v, n) => 0), isEmpty);
    });
    test('ohne Anfahrt (kein Startort): beginnt mit Besuch', () {
      final s = berechneZeitplan(bloecke: [b('a', 30)], arbeitsbeginn: '06:00',
        anfahrtMinuten: null, heimwegMinuten: null, fahrzeitZwischen: (v, n) => 0);
      expect(s.first.art, SegmentArt.besuch);
      expect(s.first.startMin, 6 * 60);
    });
  });
}
```

- [ ] **Step 4: `zeitplan.dart` implementieren** — `SegmentArt {anfahrt, besuch, fahrt, wartezeit, heimweg}`, `PlanBlock {id, dauerMinuten, ankerZeit}`, `ZeitSegment {art, blockId?, startMin, endMin, minuten}`; Funktion baut die Kette exakt wie in den Tests; `ankerZeit` als `HH:mm` geparst (Helfer teilen mit besuch_dauer? Nein — lokale Kopie, 6 Zeilen, Kommentar). Fahrt-Segmente nur zwischen zwei Besuchen (`fahrzeitZwischen(blockIdVorher, blockId)`), 0 Minuten → kein Segment.
- [ ] **Step 5: Tests grün, volle Suite grün (Altplan-Lademigration!), analyze 0, Commit** `feat(touren): TourEintrag-Besuchsfelder + Zeitplan-Berechnung`.

---

### Task 6: UI — Zeitleiste im Tagesplan-Tab + Block-Sheet + Arbeitstag

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/zeitplan_leiste.dart` (Zeitleiste + Segment-Rendering, eigenständig testbar)
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` (Tagesplan-Tab ~Z.199-300: Umschalter Liste/Zeitachse ENTFÄLLT — Zeitachse ERSETZT die Liste; ReorderableList bleibt als Anzeige-Grundlage: jedes Kind wird mit seiner berechneten Zeitspanne + Fahrt/Warte-Zeile darunter gerendert, links durchgehende Zeitleisten-Spalte)
- Test: `sbs_projer_app/test/zeitplan_leiste_test.dart`

Kernpunkte (Detailfreiheit beim Implementer, aber verbindlich):
- Links feste Spalte (36 px) mit Stunden-Marken ab 06:00 bis max(18:00, Planende); rechts die Einträge. Block-Höhe = `max(44, dauerMinuten * pxProMinute)` mit `pxProMinute = 1.1`.
- Jeder Besuchs-Block zeigt: Zeitspanne («06:20–06:50»), Betrieb - Ort, Chip «n von m Anlagen» (nur Reinigung), Dauer-Text mit «~» wenn geschätzt (kein `dauerMinuten` gesetzt). Warnbänder: rot wenn `ruhetagKonflikt`, orange wenn `servicezeitKonflikt` (Berechnung: `istOffenerTag` aus touren_saison + Servicefenster-Vergleich mit Ankunft — im Screen, nicht im Util, da BetriebLocal nötig).
- Fahrt-Verbinder: schmale Zeile «🚗 12 min» (grau, Quelle-Punkt: grün beobachtet/blau route/grau heuristik); Wartezeit gelb «⏳ 25 min Wartezeit»; Anfahrt/Heimweg als erste/letzte graue Zeile (nur wenn Startort gesetzt).
- Block-Tap → Bottom-Sheet (GestureDetector-Buttons!): Anlagen-Checkboxen (aktive Anlagen des Betriebs, gewählte = anlageIds; Änderung rechnet Dauer neu via geschaetzteDauer), Dauer-Stepper (±5 min, «zurücksetzen auf Schätzung»), Anker (TimePicker + entfernen), «Aus Plan entfernen».
- Kopfzeile über der Liste: «Start 06:00» (Tap → TimePicker → arbeitsbeginn) · rechts «Ende + km» (Tap → Sheet mit zwei Feldern arbeitsende/km_stand). Werte am Tagesplan gespeichert (Task 5-Parameter), beim Laden befüllt.
- Servicezeit-Vorschlag: liegt Ankunft vor dem nächsten Servicefenster-Beginn, kleiner Hinweis-Chip am Block «Anker HH:mm?» → Tap setzt ankerZeit.
- Dauer-/Fahrzeitdaten via neue Provider in tour_providers.dart: `besuchDauerProvider` (Historie je Betrieb aus reinigungenProvider gruppiert; Anlagenzahl je Besuch = `anlageIds.length + 1` bzw. 1) und `fahrzeitenMapProvider` (FutureProvider, lädt Repository-Map; `routeAnfordern` für fehlende Paare des aktuellen Plans einmalig anstossen).
- Widget-Test: Leiste mit 3 Blöcken auf 360/375/412 px ohne Überlauf; Wartezeit-Segment sichtbar; Mindesthöhe 44 px eingehalten.

- [ ] Step 1: `zeitplan_leiste.dart` + Widget-Tests (rot→grün)
- [ ] Step 2: Screen-Umbau (Tagesplan-Tab zeichnet Segmente; Reorder erhalten)
- [ ] Step 3: Block-Sheet
- [ ] Step 4: Arbeitstag Kopf-/Fusszeile + Speichern
- [ ] Step 5: analyze 0, volle Suite grün, Commit `feat(touren): Tagesplan als Zeitachse mit Besuchs-Bloecken`

---

### Task 7: Besuchs-Bündelung + Plan-Übernahme

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart` (TagesplanNotifier: `fuegeHinzu` bündelt) 
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` (Fällig-Tab «in Plan»-Aktion; Menüpunkt «Plan von Datum übernehmen»)
- Test: `sbs_projer_app/test/besuch_buendelung_test.dart` (reine Bündelungs-Funktion)

- [ ] **Step 1: Reine Funktion** `buendleInPlan(List<TourEintrag> plan, TourEintrag neu, List<String> heuteFaelligeAnlagenDesBetriebs)` in `lib/core/util/besuch_buendelung.dart`: Existiert im Plan ein Reinigungs-Besuch desselben Betriebs → Anlage(n) dort ergänzen (keine Duplikate), sonst neuen Besuch anlegen mit `anlageIds = alle heute fälligen Anlagen des Betriebs` (mindestens die gewählte). Tests: bündelt, dedupliziert, nimmt fällige Geschwister automatisch, Störung/Montage unverändert einzeln.
- [ ] **Step 2: Verdrahten** im Notifier + Fällig-Tab (die heute fälligen Anlagen des Betriebs kommen aus `faelligeEintraegeProvider`-Daten).
- [ ] **Step 3: Plan-Übernahme:** Menüpunkt im Tagesplan (3-Punkte oder Icon `history`): DatePicker → `gespeicherterTagesplanProvider(datum)` lesen → Einträge in Reihenfolge anhängen (Betriebe, die schon im Plan sind, überspringen), Reinigungs-Besuche: `uebernommen = true` wenn der Betrieb heute keine fällige Anlage hat (graue Darstellung im Block: Opacity 0.55 + Label «übernommen»). 
- [ ] **Step 4: analyze 0, Tests grün, Commit** `feat(touren): Besuchs-Buendelung + Plan-Uebernahme von Datum`.

---

### Task 8: Fällig-Listen-Fixes + Startort in Einstellungen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart:751-767` und Zwilling ~Z.1176-1192 (Ort gleich gross), Badge-Zeile (letzte Reinigung)
- Modify: `sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart` + zugehöriges Model/Repository (startort_lat/lng)

- [ ] **Step 1: Titelzeile** an BEIDEN Stellen: statt zwei Texte (14 fett + 12 grau) EIN `Text('${eintrag.betriebName}${eintrag.betriebOrt != null ? ' - ${eintrag.betriebOrt}' : ''}', style: fontWeight w600 fontSize 14, maxLines 1, ellipsis)`.
- [ ] **Step 2: Letzte Reinigung** unter dem `_StatusBadge` (Fällig-Tab-Stelle): Spalte statt nur Badge — darunter `Text('zuletzt ${DateFormat('dd.MM.yyyy').format(letzte)}', fontSize 10, grau)`; Datum aus `anlage.letzteReinigung` — steht bereits im TourEintrag? NEIN: `datum`-Feld des Eintrags ist `naechsteReinigung`. Lösung: letzte Reinigung über `betriebLookupProvider`-Muster — neuer kleiner Provider `letzteReinigungJeAnlageProvider: Map<String,DateTime>` aus `anlagenProvider` (`a.letzteReinigung`), Screen liest per `eintrag.anlageId`.
- [ ] **Step 3: Startort** in Geschäftseinstellungen: zwei Zahlenfelder (lat/lng) + Hinweistext «für Anfahrt/Heimweg im Tourenplan», Kette Model→DTO→Repo→Form (bestehendes Muster `geschaeft_einstellungen`), Provider für den Tourenplan (`startortProvider`).
- [ ] **Step 4: analyze 0, Tests grün, Commit** `feat(touren): Faellig-Liste Ort/letzte Reinigung + Startort-Einstellung`.

---

### Task 9: Gesamtverifikation + Deploy

- [ ] **Faktor kalibrieren** (Spec §3.3): per `execute_sql` Median von `beobachtet-Minuten / (Haversine-km / 45 * 60)` über alle beobachteten Paare (Haversine in SQL: `6371*2*asin(sqrt(power(sin(radians(b2.latitude-b1.latitude)/2),2)+cos(radians(b1.latitude))*cos(radians(b2.latitude))*power(sin(radians(b2.longitude-b1.longitude)/2),2)))` mit Join auf betriebe). Liegt der Median ausserhalb 1.4–1.8, `kFahrzeitFaktor` in `fahrzeit.dart` auf den gerundeten Wert (1 Nachkommastelle) setzen und den Test `45 km/h Schnitt x Faktor 1.6` mitziehen; sonst 1.6 belassen. Ergebnis im Commit dokumentieren.
- [ ] `flutter analyze` 0 Fehler; volle Testsuite grün.
- [ ] Version bumpen: pubspec `0.55.0+625` + `kAppVersion '0.55.0'` (Minor-Sprung — grosses Feature).
- [ ] Visuelle Prüfung: Widget-Tests sind Pflicht; zusätzlich Browser-Versuch (`flutter build web --base-href "/" --pwa-strategy=none` + preview) — wenn der Pane keine Frames liefert (bekanntes Umgebungsproblem), Widget-Tests als Nachweis dokumentieren und Daniel um Handy-Check bitten.
- [ ] Deploy gemäss CLAUDE.md: committen → Build mit `--base-href "/sbs-projer-dev/"` → Cache-Bust (Scratchpad-Skript `cachebust.py` existiert) → gh-pages mit Branch-Guard → beide Branches pushen (Push: dangerouslyDisableSandbox).
- [ ] Projekt.md/ToDo.md: Kurzeintrag v0.55.0; ToDo: «Auswertungen km/Stunden» als späteres Paket notieren.

## Task-Abhängigkeiten

1 → 2 (Tabelle vor Function) · 1,3,4,5 → 6 · 5 → 7 · 8 unabhängig ab 5 · 9 zuletzt. 3 und 4 parallelisierbar, werden aber sequenziell ausgeführt (ein Implementer zur Zeit).
