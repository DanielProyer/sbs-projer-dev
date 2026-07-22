# Google-Kontakte-Sync + Contact Picker — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App-Kontakte + operative Betriebe landen automatisch im Google-Adressbuch (Label «SBS App») → Anrufer-Erkennung auf dem Pixel 9; plus Contact-Picker-Import im Kontakt-Formular.

**Architecture:** Abgleich-basiert (Ansatz A der Spec): Eine Edge-Function `google-contacts-sync` berechnet pro Lauf Soll (Supabase) vs. Ist (Google-Label) und gleicht per People-API-Batches ab; Identität über `clientData.sbs_id` im Google-Kontakt, keine Mapping-Tabelle. Die App triggert den Lauf entprellt nach Kontakt-/Betrieb-Speichern; Status lebt in `google_calendar_status`.

**Tech Stack:** Flutter Web (Riverpod), Supabase Edge Functions (Deno/TS), Google People API v1, bestehender Google-OAuth (PKCE, `google-oauth-exchange`).

**Spec:** `docs/superpowers/specs/2026-07-21-google-kontakte-sync-design.md` (freigegeben; inkl. Korrektur: Status in `google_calendar_status`, nicht `google_calendar_tokens`).

**Projekt-Konventionen:** Arbeit direkt auf `main` (Projekt-Workflow). Flutter in Bash: `export PATH="$PATH:/c/flutter/bin"`, App-Verzeichnis `sbs_projer_app`. Supabase via MCP-Tools (`apply_migration`, `deploy_edge_function`, `execute_sql`), project_id `pltbaqqwpnmdajwgnhpd`. UI-Texte und Kommentare Deutsch. Commit-Schritte sind eigene Schritte; Spec-Reviewer: fehlender Commit innerhalb eines Tasks ist KEINE Verletzung.

---

## Datei-Landkarte

| Datei | Verantwortung | Task |
|---|---|---|
| `Datenbank/migrations/148_google_kontakte_sync.sql` | Status-Spalten + tote Spalten droppen | GK-1 |
| `sbs_projer_app/lib/data/models/kontakt.dart` u. a. | `phoneContactId` entfernen (DTO/Local/Web/Mapper) | GK-1 |
| `supabase/functions/google-contacts-sync/index.ts` | Reconcile-Kern (Soll/Ist/Diff/People-API) | GK-2 |
| `sbs_projer_app/lib/core/util/google_kontakte.dart` | Reine Helfer: Scope-Check, Statustext, Picker-Split | GK-3 |
| `sbs_projer_app/test/google_kontakte_test.dart` | TDD für die Helfer | GK-3 |
| `sbs_projer_app/lib/services/google_calendar/google_calendar_auth_service.dart` | Scope erweitern | GK-4 |
| `supabase/functions/google-oauth-exchange/index.ts` | Scope in Status-Tabelle spiegeln | GK-4 |
| `sbs_projer_app/lib/presentation/providers/google_calendar_providers.dart` | Status um scope/contacts-Felder erweitern | GK-4 |
| `sbs_projer_app/lib/services/google/google_contacts_service.dart` | syncJetzt + entprellter Hintergrund-Sync | GK-5 |
| `sbs_projer_app/lib/presentation/screens/kontakte/kontakt_form_screen.dart` | Trigger + Picker-Button | GK-5, GK-7 |
| `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart` | Trigger nach Speichern | GK-5 |
| `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart` | Bereich «Google Kontakte» | GK-6 |
| `sbs_projer_app/lib/services/google/kontakt_picker_export.dart` + `_web.dart` + `_stub.dart` | Contact Picker API (Web-only, Conditional Export) | GK-7 |

---

> **NACHTRAG 22.07. (Controller):** Bei Ausführungsbeginn entdeckt: Die
> `phone_*`-Spalten sind KEIN toter Bestand — es existiert ein alter, rein
> NATIVER Handy-Sync (`lib/services/phone_contact_service.dart` mit
> `flutter_contacts`; alle Einstiege `if (kIsWeb) return`, im Web nie aktiv).
> Daniel hat am 22.07. entschieden: **komplett entfernen** (ersetzt durch den
> Google-Sync). Zudem: `BetriebKontakt` ist ein zweites, AKTIV genutztes DTO
> über dieselbe Tabelle `kontakte` (Betrieb-Detail, Heineken-Raster, Sync
> Tier 2) — es bleibt bestehen, verliert nur die `phone_*`-Felder.
> Konsequenzen (ersetzen die ursprünglichen Task-Texte, wo abweichend):
> - **GK-1 NEU:** Alten Handy-Sync entfernen statt nur Felder: 
>   `phone_contact_service.dart` löschen; alle Aufrufe entfernen in
>   `kontakt_form_screen.dart`, `betrieb_kontakt_form_screen.dart`,
>   `kontakte_list_screen.dart` (inkl. zugehöriger Buttons/Menüpunkte «aus
>   Handykontakten»/«auf Handy speichern» o. ä. und `_phoneContactId`-State);
>   `flutter_contacts` aus `pubspec.yaml`; `phoneContactId`/
>   `phoneLastSyncedAt` aus BEIDEN DTOs (`kontakt.dart`, `betrieb_kontakt.dart`),
>   BEIDEN Locals + Web-Stubs + BEIDEN Mappern; build_runner; Tests.
>   Migration 148 (nur Status-Spalten) ist bereits auf Prod; die DB-Spalten
>   `phone_*` bleiben VORERST (Live-Version schreibt sie noch!).
> - **GK-8 NEU zusätzlich:** NACH erfolgreichem Deploy v0.52.0 Migration
>   `149_drop_phone_contact_spalten.sql` anwenden (Controller):
>   `ALTER TABLE public.kontakte DROP COLUMN IF EXISTS phone_contact_id, DROP COLUMN IF EXISTS phone_last_synced_at;`
> - **GK-5 zusätzlich:** Trigger auch nach `BetriebKontaktRepository.save/delete`
>   bzw. in `betrieb_kontakt_form_screen.dart` (zweiter Speicherweg für Kontakte).
> - **GK-7 zusätzlich:** Picker-Button in BEIDEN Formularen (kontakt_form +
>   betrieb_kontakt_form), als Ersatz des entfernten nativen Pickers.

### Task GK-1: Migration 148 + Dart-Modell aufräumen

**Files:**
- Create: `Datenbank/migrations/148_google_kontakte_sync.sql`
- Modify: `sbs_projer_app/lib/data/models/kontakt.dart` (phoneContactId raus)
- Modify: `sbs_projer_app/lib/data/local/kontakt_local.dart` (Feld raus)
- Modify: `sbs_projer_app/lib/data/local/web/kontakt_local_web.dart` (Feld raus)
- Modify: `sbs_projer_app/lib/data/mappers/kontakt_mapper.dart` (Zuweisungen raus)

- [ ] **Step 1: Migration auf Prod anwenden** — via MCP `apply_migration`, name `148_google_kontakte_sync`:

```sql
-- 148: Google-Kontakte-Sync (Spec 2026-07-21)
-- a) Status-Felder fuer den Kontakte-Sync in der App-lesbaren Status-Tabelle.
--    scope wird gespiegelt, weil google_calendar_tokens bewusst nur fuer die
--    Service-Role lesbar ist (Refresh-Tokens!).
ALTER TABLE public.google_calendar_status
  ADD COLUMN IF NOT EXISTS scope text,
  ADD COLUMN IF NOT EXISTS contacts_last_sync_at timestamptz,
  ADD COLUMN IF NOT EXISTS contacts_last_sync_info text;
UPDATE public.google_calendar_status s SET scope = t.scope
  FROM public.google_calendar_tokens t WHERE t.user_id = s.user_id;
-- b) Tote Spalten entfernen: nie genutzt (0 Zeilen belegt, verifiziert
--    21.07.); Identitaet lebt kuenftig im Google-Kontakt (clientData.sbs_id).
ALTER TABLE public.kontakte
  DROP COLUMN IF EXISTS phone_contact_id,
  DROP COLUMN IF EXISTS phone_last_synced_at;
```

- [ ] **Step 2: Migrations-Datei im Repo ablegen** — gleichen SQL-Inhalt nach `Datenbank/migrations/148_google_kontakte_sync.sql` schreiben.

- [ ] **Step 3: `phoneContactId` aus dem DTO entfernen** — in `lib/data/models/kontakt.dart` das Feld `final String? phoneContactId;`, den Konstruktor-Parameter `this.phoneContactId,`, die fromJson-Zeile `phoneContactId: json['phone_contact_id'],` und die toJson-Zeile `'phone_contact_id': phoneContactId,` löschen. Falls ein `phoneLastSyncedAt`-Feld existiert (grep!), ebenso entfernen.

- [ ] **Step 4: Isar-Local + Web-Stub + Mapper bereinigen** — in `lib/data/local/kontakt_local.dart` das Feld `String? phoneContactId;` (und ggf. `phoneLastSyncedAt`) löschen; dieselben Felder in `lib/data/local/web/kontakt_local_web.dart` löschen; in `lib/data/mappers/kontakt_mapper.dart` alle Zuweisungen dieser Felder löschen (grep nach `phoneContactId` muss danach 0 Treffer in `lib/` liefern, ausser `.g.dart`).

- [ ] **Step 5: Isar-Code regenerieren**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && dart run build_runner build --delete-conflicting-outputs
```

Erwartung: Succeeded; danach `grep -rn "phoneContactId" lib/` → 0 Treffer.

- [ ] **Step 6: Analyse + Tests**

```bash
flutter analyze   # keine NEUEN Fehler/Warnungen (Isar-.g.dart-Warnungen sind Bestand)
flutter test      # alle Tests gruen
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(kontakte): Migration 148 — Status-Spalten für Google-Sync, tote phone_contact-Spalten entfernt"
```

---

### Task GK-2: Edge-Function `google-contacts-sync`

**Files:**
- Create: `supabase/functions/google-contacts-sync/index.ts`

**Kontext für den Implementer:** Muster ist `supabase/functions/google-calendar-sync/index.ts` — von dort `getAccessToken` (inkl. Persistieren des erneuerten access_token) UNVERÄNDERT übernehmen. Auth: User via Authorization-Header + anon-Client, Daten via Service-Role-Client (`admin`). People-API-Basis: `https://people.googleapis.com/v1`.

- [ ] **Step 1: Function-Datei schreiben** — vollständiger Inhalt (getAccessToken aus google-calendar-sync einkopieren, Rest wie folgt):

```ts
// Supabase Edge Function: google-contacts-sync
// Einseitiger Abgleich App -> Google Kontakte (Label "SBS App").
// Identitaet: clientData.sbs_id = "kontakt:<uuid>" | "betrieb:<uuid>".
// Sicherheitsregel: Nur Eintraege MIT sbs_id werden je angefasst/geloescht.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const PEOPLE = "https://people.googleapis.com/v1";
const LABEL_NAME = "SBS App";
const PERSON_FIELDS =
  "names,organizations,phoneNumbers,emailAddresses,memberships,clientData";
// deno-lint-ignore no-explicit-any
type Any = any;

// ── Reine Funktionen (Soll-Filter + Mapping + Vergleich) ──

export function istSyncWuerdigKontakt(k: Any): boolean {
  const tel = (k.telefon ?? "").trim();
  const mail = (k.email ?? "").trim();
  return tel !== "" || mail !== "";
}

export function istSyncWuerdigBetrieb(b: Any): boolean {
  const tel = (b.telefon ?? "").trim();
  return (b.status === "aktiv" || b.status === "saisonpause") && tel !== "";
}

// Person-Payload fuer einen App-Kontakt. betriebText = "Name, Ort" oder "".
export function personAusKontakt(k: Any, betriebText: string): Any {
  const p: Any = {
    names: [{
      givenName: (k.vorname ?? "").trim(),
      familyName: (k.nachname ?? "").trim(),
    }],
    clientData: [{ key: "sbs_id", value: `kontakt:${k.id}` }],
  };
  if (betriebText || (k.funktion ?? k.rolle)) {
    p.organizations = [{
      name: betriebText,
      title: ((k.funktion ?? k.rolle) ?? "").trim(),
    }];
  }
  const tel = (k.telefon ?? "").trim();
  if (tel) p.phoneNumbers = [{ value: tel, type: "mobile" }];
  const mail = (k.email ?? "").trim();
  if (mail) p.emailAddresses = [{ value: mail }];
  return p;
}

export function personAusBetrieb(b: Any): Any {
  const anzeige = [b.name, b.ort].filter((x: Any) => (x ?? "").trim() !== "")
    .join(" ");
  return {
    names: [{ unstructuredName: anzeige }],
    organizations: [{ name: (b.name ?? "").trim() }],
    phoneNumbers: [{ value: (b.telefon ?? "").trim(), type: "work" }],
    clientData: [{ key: "sbs_id", value: `betrieb:${b.id}` }],
  };
}

// Vergleichs-Schluessel: alles, was wir schreiben, normalisiert.
export function vergleichsKey(p: Any): string {
  const n = p.names?.[0] ?? {};
  const o = p.organizations?.[0] ?? {};
  return JSON.stringify([
    n.givenName ?? "", n.familyName ?? "", n.unstructuredName ?? "",
    o.name ?? "", o.title ?? "",
    p.phoneNumbers?.[0]?.value ?? "",
    p.emailAddresses?.[0]?.value ?? "",
  ]);
}

export function sbsIdVon(p: Any): string | null {
  for (const c of p.clientData ?? []) {
    if (c.key === "sbs_id" && c.value) return c.value as string;
  }
  return null;
}

// ── People-API-Helfer ──

async function gapi(token: string, method: string, path: string, body?: Any) {
  const res = await fetch(`${PEOPLE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`People API ${res.status}: ${data.error?.message ?? path}`);
  }
  return data;
}

async function ensureLabel(token: string): Promise<string> {
  const list = await gapi(token, "GET", "/contactGroups?pageSize=200");
  const found = (list.contactGroups ?? []).find(
    (g: Any) => g.name === LABEL_NAME && g.groupType === "USER_CONTACT_GROUP",
  );
  if (found) return found.resourceName;
  const created = await gapi(token, "POST", "/contactGroups", {
    contactGroup: { name: LABEL_NAME },
  });
  return created.resourceName;
}

// Alle Google-Kontakte im Label MIT sbs_id -> Map sbs_id -> Person.
async function listeIst(token: string, label: string): Promise<Map<string, Any>> {
  const ist = new Map<string, Any>();
  let pageToken = "";
  do {
    const q = `personFields=${PERSON_FIELDS}&pageSize=1000` +
      (pageToken ? `&pageToken=${pageToken}` : "");
    const data = await gapi(token, "GET", `/people/me/connections?${q}`);
    for (const p of data.connections ?? []) {
      const imLabel = (p.memberships ?? []).some(
        (m: Any) => m.contactGroupMembership?.contactGroupResourceName === label,
      );
      const id = sbsIdVon(p);
      if (imLabel && id) ist.set(id, p);
    }
    pageToken = data.nextPageToken ?? "";
  } while (pageToken);
  return ist;
}

function chunks<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

// ── Reconcile ──

async function reconcile(admin: Any, token: string, userId: string) {
  // Soll-Zustand laden
  const { data: kontakte } = await admin.from("kontakte").select(
    "id, vorname, nachname, funktion, rolle, telefon, email, betrieb_id",
  ).eq("user_id", userId);
  const { data: betriebe } = await admin.from("betriebe").select(
    "id, name, ort, telefon, status",
  ).eq("user_id", userId);
  const betriebText = new Map<string, string>();
  for (const b of betriebe ?? []) {
    betriebText.set(
      b.id,
      [b.name, b.ort].filter((x: Any) => (x ?? "").trim() !== "").join(", "),
    );
  }

  const label = await ensureLabel(token);
  const membership = {
    memberships: [{ contactGroupMembership: { contactGroupResourceName: label } }],
  };

  const soll = new Map<string, Any>(); // sbs_id -> Person-Payload
  for (const k of (kontakte ?? []).filter(istSyncWuerdigKontakt)) {
    soll.set(`kontakt:${k.id}`, {
      ...personAusKontakt(k, betriebText.get(k.betrieb_id) ?? ""),
      ...membership,
    });
  }
  for (const b of (betriebe ?? []).filter(istSyncWuerdigBetrieb)) {
    soll.set(`betrieb:${b.id}`, { ...personAusBetrieb(b), ...membership });
  }

  const ist = await listeIst(token, label);

  // Diff
  const anlegen: Any[] = [];
  const aktualisieren: { resourceName: string; etag: string; person: Any }[] = [];
  for (const [id, person] of soll) {
    const vorhanden = ist.get(id);
    if (!vorhanden) {
      anlegen.push(person);
    } else if (vergleichsKey(person) !== vergleichsKey(vorhanden)) {
      aktualisieren.push({
        resourceName: vorhanden.resourceName,
        etag: vorhanden.etag,
        person,
      });
    }
  }
  const loeschen = [...ist.entries()]
    .filter(([id]) => !soll.has(id))
    .map(([, p]) => p.resourceName);

  // Ausfuehren (Batch-Limits: create 200, delete 500)
  for (const teil of chunks(anlegen, 200)) {
    await gapi(token, "POST", "/people:batchCreateContacts", {
      contacts: teil.map((p) => ({ contactPerson: p })),
      readMask: "names",
    });
  }
  for (const u of aktualisieren) {
    await gapi(
      token,
      "PATCH",
      `/${u.resourceName}:updateContact?updatePersonFields=names,organizations,phoneNumbers,emailAddresses`,
      { ...u.person, etag: u.etag },
    );
  }
  for (const teil of chunks(loeschen, 500)) {
    await gapi(token, "POST", "/people:batchDeleteContacts", {
      resourceNames: teil,
    });
  }

  const kontakteAnz = [...soll.keys()].filter((k) => k.startsWith("kontakt:")).length;
  const betriebeAnz = soll.size - kontakteAnz;
  return {
    created: anlegen.length,
    updated: aktualisieren.length,
    deleted: loeschen.length,
    total: soll.size,
    info: `${kontakteAnz} Kontakte, ${betriebeAnz} Betriebe`,
  };
}

// ── HTTP-Handler ──

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceKey);
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const at = await getAccessToken(admin, user.id);
    if (at === null) return json({ skipped: "not_connected" });
    if (at.error) return json({ error: at.error }, 502);

    try {
      const r = await reconcile(admin, at.token, user.id);
      await admin.from("google_calendar_status").update({
        contacts_last_sync_at: new Date().toISOString(),
        contacts_last_sync_info: r.info,
      }).eq("user_id", user.id);
      return json({ ok: true, ...r });
    } catch (e) {
      await admin.from("google_calendar_status").update({
        contacts_last_sync_at: new Date().toISOString(),
        contacts_last_sync_info: `Fehler: ${e instanceof Error ? e.message : e}`,
      }).eq("user_id", user.id);
      throw e;
    }
  } catch (e) {
    console.error("google-contacts-sync", e);
    return json({ error: e instanceof Error ? e.message : "unknown" }, 500);
  }
});

// getAccessToken: WOERTLICH aus supabase/functions/google-calendar-sync/index.ts
// uebernehmen (Zeilen ab "async function getAccessToken(" bis zum Ende der
// Funktion, inkl. Persistieren des erneuerten access_token).
```

- [ ] **Step 2: `getAccessToken` einkopieren** — aus `google-calendar-sync/index.ts` die komplette Funktion ans Dateiende kopieren, Kommentar-Platzhalter am Ende der neuen Datei ersetzen.

- [ ] **Step 3: Deployen** — via MCP `deploy_edge_function`, name `google-contacts-sync`, mit dem Dateiinhalt. Erwartung: success.

- [ ] **Step 4: Smoke-Test der Function** — die Function verlangt einen User-JWT; ohne App-Login genügt als Smoke-Test der 401-Pfad:

```bash
curl -s -X POST "https://pltbaqqwpnmdajwgnhpd.supabase.co/functions/v1/google-contacts-sync" -H "Content-Type: application/json" -d '{}'
```

Erwartung: `{"error":"unauthorized"}` (oder `{"code":401,...}` vom Gateway) — Function ist erreichbar. Der echte Lauf wird in GK-8 über die App verifiziert (Scope fehlt bis GK-4 ohnehin).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/google-contacts-sync/index.ts && git commit -m "feat(google): Edge-Function google-contacts-sync — Reconcile App -> Google Kontakte"
```

---

### Task GK-3: Reine Dart-Helfer (TDD): Scope-Check, Statustext, Picker-Split

**Files:**
- Create: `sbs_projer_app/lib/core/util/google_kontakte.dart`
- Test: `sbs_projer_app/test/google_kontakte_test.dart`

- [ ] **Step 1: Fehlschlagende Tests schreiben** — `test/google_kontakte_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_kontakte.dart';

void main() {
  group('hatKontakteScope', () {
    test('null/leer/nur Kalender -> false', () {
      expect(hatKontakteScope(null), isFalse);
      expect(hatKontakteScope(''), isFalse);
      expect(
          hatKontakteScope(
              'https://www.googleapis.com/auth/calendar.events openid'),
          isFalse);
    });
    test('mit contacts-Scope -> true', () {
      expect(
          hatKontakteScope(
              'https://www.googleapis.com/auth/calendar.events '
              'https://www.googleapis.com/auth/contacts email'),
          isTrue);
    });
    test('contacts.readonly zaehlt NICHT als Schreib-Scope', () {
      expect(
          hatKontakteScope('https://www.googleapis.com/auth/contacts.readonly'),
          isFalse);
    });
  });

  group('kontaktAusPicker (Name-Split)', () {
    test('zwei Woerter: erstes = Vorname, letztes = Nachname', () {
      final r = kontaktAusPicker('Hans Muster', '+41791234567', 'h@m.ch');
      expect(r.vorname, 'Hans');
      expect(r.nachname, 'Muster');
      expect(r.telefon, '+41791234567');
      expect(r.email, 'h@m.ch');
    });
    test('drei Woerter: letztes Wort = Nachname, Rest = Vorname', () {
      final r = kontaktAusPicker('Hans Peter Muster', null, null);
      expect(r.vorname, 'Hans Peter');
      expect(r.nachname, 'Muster');
    });
    test('ein Wort: alles Nachname', () {
      final r = kontaktAusPicker('Muster', null, null);
      expect(r.vorname, isNull);
      expect(r.nachname, 'Muster');
    });
    test('leer/null: alles null', () {
      final r = kontaktAusPicker('  ', null, '');
      expect(r.vorname, isNull);
      expect(r.nachname, isNull);
      expect(r.telefon, isNull);
      expect(r.email, isNull);
    });
  });

  group('kontakteSyncStatusText', () {
    test('nie gesynct', () {
      expect(kontakteSyncStatusText(null, null), 'Noch nie synchronisiert');
    });
    test('mit Zeit und Info', () {
      expect(
          kontakteSyncStatusText(DateTime(2026, 7, 21, 18, 32),
              '104 Kontakte, 240 Betriebe'),
          'Letzter Sync 21.07.2026 18:32 · 104 Kontakte, 240 Betriebe');
    });
    test('Fehler-Info wird durchgereicht', () {
      expect(kontakteSyncStatusText(DateTime(2026, 7, 21, 6, 5), 'Fehler: 401'),
          'Letzter Sync 21.07.2026 06:05 · Fehler: 401');
    });
  });
}
```

- [ ] **Step 2: RED verifizieren**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/google_kontakte_test.dart
```

Erwartung: Compile-Fehler «google_kontakte.dart not found» bzw. Methoden fehlen.

- [ ] **Step 3: Implementierung** — `lib/core/util/google_kontakte.dart`:

```dart
/// Reine Helfer für den Google-Kontakte-Sync (testbar, kein I/O).

/// Hat der gespeicherte OAuth-Scope den SCHREIB-Zugriff auf Kontakte?
/// `contacts.readonly` genügt nicht.
bool hatKontakteScope(String? scope) {
  if (scope == null) return false;
  return scope.split(' ').contains('https://www.googleapis.com/auth/contacts');
}

/// Ergebnis des Contact Pickers, aufbereitet fürs Kontakt-Formular.
class PickerKontakt {
  final String? vorname;
  final String? nachname;
  final String? telefon;
  final String? email;
  const PickerKontakt({this.vorname, this.nachname, this.telefon, this.email});
}

/// Name-Split: letztes Wort = Nachname, Rest = Vorname; ein Wort = Nachname.
PickerKontakt kontaktAusPicker(String? name, String? telefon, String? email) {
  String? clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  final teile =
      (name ?? '').trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  String? vorname;
  String? nachname;
  if (teile.length == 1) {
    nachname = teile.first;
  } else if (teile.length > 1) {
    nachname = teile.last;
    vorname = teile.sublist(0, teile.length - 1).join(' ');
  }
  return PickerKontakt(
    vorname: vorname,
    nachname: nachname,
    telefon: clean(telefon),
    email: clean(email),
  );
}

String _zwei(int n) => n.toString().padLeft(2, '0');

/// Statuszeile für die Einstellungen.
String kontakteSyncStatusText(DateTime? at, String? info) {
  if (at == null) return 'Noch nie synchronisiert';
  final zeit = '${_zwei(at.day)}.${_zwei(at.month)}.${at.year} '
      '${_zwei(at.hour)}:${_zwei(at.minute)}';
  return info == null || info.isEmpty
      ? 'Letzter Sync $zeit'
      : 'Letzter Sync $zeit · $info';
}
```

- [ ] **Step 4: GREEN verifizieren**

```bash
flutter test test/google_kontakte_test.dart
```

Erwartung: alle Tests grün.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/google_kontakte.dart test/google_kontakte_test.dart && git commit -m "feat(google): reine Helfer für Kontakte-Sync (Scope, Statustext, Picker-Split, TDD)"
```

---

### Task GK-4: OAuth-Scope erweitern + Status-Provider

**Files:**
- Modify: `sbs_projer_app/lib/services/google_calendar/google_calendar_auth_service.dart:18-19`
- Modify: `supabase/functions/google-oauth-exchange/index.ts` (Scope in Status spiegeln)
- Modify: `sbs_projer_app/lib/presentation/providers/google_calendar_providers.dart`

- [ ] **Step 1: Client-Scope erweitern** — in `google_calendar_auth_service.dart`:

```dart
  static const _scope =
      'https://www.googleapis.com/auth/calendar.events '
      'https://www.googleapis.com/auth/contacts email';
```

- [ ] **Step 2: Scope in Status-Tabelle spiegeln** — `google-oauth-exchange/index.ts` lesen; dort wird nach erfolgreichem Token-Tausch in `google_calendar_tokens` UND `google_calendar_status` geschrieben (upsert). Beim Status-Upsert das Feld `scope: token.scope ?? null` ergänzen (das Token-Response-Feld heisst `scope`). Falls der Status-Upsert fehlt: beim vorhandenen Tokens-Upsert nachziehen und zusätzlich `admin.from("google_calendar_status").upsert({ user_id: user.id, scope: token.scope ?? null }, { onConflict: "user_id" })` ergänzen — vorhandene Felder (connected, google_email) unangetastet lassen (upsert nur mit user_id+scope wäre falsch, wenn die Zeile neu entsteht: dann connected/google_email mit setzen, exakt wie der bestehende Code es tut — Muster im File übernehmen).

- [ ] **Step 3: Function neu deployen** — via MCP `deploy_edge_function`, name `google-oauth-exchange`, aktualisierter Inhalt.

- [ ] **Step 4: Status-Provider erweitern** — `google_calendar_providers.dart` komplett so anpassen:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  final DateTime? lastSyncAt;
  final String? scope;
  final DateTime? contactsLastSyncAt;
  final String? contactsLastSyncInfo;
  const GoogleCalendarStatus({
    required this.connected,
    this.email,
    this.lastSyncAt,
    this.scope,
    this.contactsLastSyncAt,
    this.contactsLastSyncInfo,
  });
}

final googleCalendarStatusProvider =
    FutureProvider<GoogleCalendarStatus>((ref) async {
  final rows = await SupabaseService.client
      .from('google_calendar_status')
      .select()
      .limit(1);
  if (rows.isEmpty) return const GoogleCalendarStatus(connected: false);
  final r = rows.first;
  DateTime? ts(String key) {
    final raw = r[key] as String?;
    return raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
  }

  return GoogleCalendarStatus(
    connected: r['connected'] == true,
    email: r['google_email'] as String?,
    lastSyncAt: ts('last_sync_at'),
    scope: r['scope'] as String?,
    contactsLastSyncAt: ts('contacts_last_sync_at'),
    contactsLastSyncInfo: r['contacts_last_sync_info'] as String?,
  );
});
```

Achtung: `lastSyncAt` bekam `.toLocal()` — prüfen, dass die bestehende Kalender-Anzeige dadurch weiterhin korrekt ist (vorher wurde roh geparst; UTC-Strings aus Postgres enden auf `+00:00`, `toLocal()` ist die Verbesserung; bestehende Anzeige-Stelle in `einstellungen_screen.dart` kurz gegenlesen).

- [ ] **Step 5: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(google): contacts-Scope im OAuth-Flow + Status um Scope/Kontakte-Sync erweitert"
```

---

### Task GK-5: GoogleContactsService + Trigger in den Formularen

**Files:**
- Create: `sbs_projer_app/lib/services/google/google_contacts_service.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/kontakte/kontakt_form_screen.dart` (nach Save/Delete)
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart` (nach Save, ~Zeile 458)

- [ ] **Step 1: Service schreiben** — `lib/services/google/google_contacts_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ergebnis eines Sync-Laufs (Zähler aus der Edge-Function).
class KontakteSyncErgebnis {
  final int created, updated, deleted, total;
  final String info;
  const KontakteSyncErgebnis(
      this.created, this.updated, this.deleted, this.total, this.info);
}

/// Einseitiger Kontakte-Sync App -> Google (Edge-Function google-contacts-sync).
class GoogleContactsService {
  static Timer? _debounce;

  /// Manueller Lauf (Einstellungen-Button). Wirft bei Fehler.
  static Future<KontakteSyncErgebnis> syncJetzt() async {
    final res = await SupabaseService.client.functions
        .invoke('google-contacts-sync', body: {'action': 'reconcile'});
    final data = res.data;
    if (res.status != 200 || data is! Map || data['ok'] != true) {
      final msg = data is Map
          ? (data['error'] ?? data['skipped'] ?? 'Fehler').toString()
          : 'Fehler';
      throw Exception(msg);
    }
    return KontakteSyncErgebnis(
      (data['created'] as num?)?.toInt() ?? 0,
      (data['updated'] as num?)?.toInt() ?? 0,
      (data['deleted'] as num?)?.toInt() ?? 0,
      (data['total'] as num?)?.toInt() ?? 0,
      (data['info'] ?? '').toString(),
    );
  }

  /// Hintergrund-Lauf nach Speichern/Löschen: entprellt (5 s), Fehler still.
  /// Ohne Google-Verbindung oder Scope antwortet die Function mit
  /// skipped/Fehler — beides wird hier bewusst geschluckt.
  static void syncImHintergrund() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () {
      syncJetzt().catchError((Object e) {
        debugPrint('Kontakte-Sync (Hintergrund) übersprungen: $e');
        return const KontakteSyncErgebnis(0, 0, 0, 0, '');
      });
    });
  }
}
```

- [ ] **Step 2: Trigger im Kontakt-Formular** — in `kontakt_form_screen.dart` nach dem erfolgreichen `await KontaktRepository.save(kontakt);` (Zeile ~131) direkt `GoogleContactsService.syncImHintergrund();` einfügen (Import ergänzen). Danach ALLE Lösch-Stellen finden: `grep -rn "KontaktRepository.delete" lib/` — nach jedem erfolgreichen Delete-Aufruf ebenfalls `GoogleContactsService.syncImHintergrund();` einfügen.

- [ ] **Step 3: Trigger im Betrieb-Formular** — in `betrieb_form_screen.dart` nach `await BetriebRepository.save(betrieb);` (Zeile ~458) `GoogleContactsService.syncImHintergrund();` einfügen (Import ergänzen). Das deckt Status- und Telefonänderungen ab; Reaktivierung läuft über denselben Weg.

- [ ] **Step 4: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(google): GoogleContactsService + Hintergrund-Sync nach Kontakt-/Betrieb-Speichern"
```

---

### Task GK-6: Einstellungen-Bereich «Google Kontakte»

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

**Kontext:** Es gibt bereits eine Karte «Google Kalender» (ExpansionTile/ListTile ab ~Zeile 204, Builder `_buildGoogleKalender` ab ~Zeile 57) mit Verbinden/Trennen und Reconcile-Button. Direkt darunter kommt eine eigene Karte «Google Kontakte», gleiche Optik (bestehende Karte als Muster nehmen).

- [ ] **Step 1: Abschnitt bauen** — neuen Builder `_buildGoogleKontakte(GoogleCalendarStatus status)` ergänzen und unter der Google-Kalender-Karte einhängen (gleiches `status`-Async-Value verwenden). Verhalten:

```dart
  Widget _buildGoogleKontakte(GoogleCalendarStatus status) {
    if (!status.connected) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'Zuerst oben Google Kalender verbinden — der Kontakte-Sync nutzt '
            'dieselbe Google-Verbindung.'),
      );
    }
    if (!hatKontakteScope(status.scope)) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Für den Kontakte-Sync fehlt noch die Google-Freigabe.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.sync_lock),
            label: const Text('Google-Verbindung erneuern'),
            onPressed: () => GoogleCalendarAuthService.verbinden(),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Kontakte und operative Betriebe landen automatisch im Google-'
            'Adressbuch (Label «SBS App») — für die Anrufer-Erkennung.'),
        const SizedBox(height: 8),
        Text(
          kontakteSyncStatusText(
              status.contactsLastSyncAt, status.contactsLastSyncInfo),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.sync),
          label: const Text('Jetzt syncen'),
          onPressed: _isKontakteSyncing ? null : _kontakteSyncJetzt,
        ),
      ]),
    );
  }

  bool _isKontakteSyncing = false;

  Future<void> _kontakteSyncJetzt() async {
    setState(() => _isKontakteSyncing = true);
    try {
      final r = await GoogleContactsService.syncJetzt();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync ok: ${r.info} '
              '(${r.created} neu, ${r.updated} geändert, ${r.deleted} gelöscht)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _isKontakteSyncing = false);
      ref.invalidate(googleCalendarStatusProvider);
    }
  }
```

Anmerkungen für den Implementer: Screen-Klasse ist vermutlich ein `ConsumerStatefulWidget` (prüfen — die Kalender-Karte nutzt bereits Buttons mit async-Handlern und `ref`); Imports ergänzen (`google_kontakte.dart`, `google_contacts_service.dart`, AppColors-Import existiert). Falls Buttons im Projekt wegen CanvasKit als `GestureDetector+Container` gebaut werden: Muster der NACHBAR-Karte übernehmen, nicht neu erfinden.

- [ ] **Step 2: Visuell prüfen (Pflicht vor Deploy, Memory-Regel)** — `flutter run -d edge`, Einstellungen öffnen: Karte erscheint, Zustände «nicht verbunden»/«Scope fehlt» korrekt (aktuell fehlt der Scope → Erneuern-Button sichtbar).

- [ ] **Step 3: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(einstellungen): Bereich Google Kontakte — Status, Scope-Erneuerung, Jetzt-syncen"
```

---

### Task GK-7: Contact Picker im Kontakt-Formular

**Files:**
- Create: `sbs_projer_app/lib/services/google/kontakt_picker_stub.dart`
- Create: `sbs_projer_app/lib/services/google/kontakt_picker_web.dart`
- Create: `sbs_projer_app/lib/services/google/kontakt_picker_export.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/kontakte/kontakt_form_screen.dart`

**Kontext:** Contact Picker API (`navigator.contacts.select`) gibt es nur in Chrome/Android. Muster für Web-only-Code: `lib/services/google_calendar/browser_redirect.dart` (Conditional Export) — Struktur ansehen und übernehmen.

- [ ] **Step 1: Stub (native)** — `kontakt_picker_stub.dart`:

```dart
/// Native/Test-Stub: Contact Picker gibt es nur im Web (Chrome/Android).
bool get kontaktPickerVerfuegbar => false;

Future<({String? name, String? telefon, String? email})?>
    waehleHandyKontakt() async => null;
```

- [ ] **Step 2: Web-Implementierung** — `kontakt_picker_web.dart`:

```dart
// Contact Picker API (nur Chrome/Android). Zugriff bewusst dynamisch über
// js_util, weil package:web keine Typen für navigator.contacts hat.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get kontaktPickerVerfuegbar =>
    web.window.navigator.hasProperty('contacts'.toJS).toDart;

Future<({String? name, String? telefon, String? email})?>
    waehleHandyKontakt() async {
  if (!kontaktPickerVerfuegbar) return null;
  final contacts = web.window.navigator.getProperty('contacts'.toJS) as JSObject;
  final props = ['name', 'tel', 'email'].map((p) => p.toJS).toList().toJS;
  final opts = JSObject()..setProperty('multiple'.toJS, false.toJS);
  final result = await (contacts.callMethod('select'.toJS, props, opts)
          as JSPromise<JSArray<JSObject>>)
      .toDart;
  final liste = result.toDart;
  if (liste.isEmpty) return null;
  final k = liste.first;
  String? erst(String feld) {
    final arr = k.getProperty(feld.toJS);
    if (arr == null || arr.isUndefinedOrNull) return null;
    final l = (arr as JSArray).toDart;
    return l.isEmpty ? null : (l.first as JSAny?).dartify()?.toString();
  }

  return (name: erst('name'), telefon: erst('tel'), email: erst('email'));
}
```

Hinweis: Abbruch des Pickers wirft eine Exception — der Aufrufer fängt sie (Step 4).

- [ ] **Step 3: Conditional Export** — `kontakt_picker_export.dart`:

```dart
export 'kontakt_picker_stub.dart'
    if (dart.library.js_interop) 'kontakt_picker_web.dart';
```

(Bestehende Exports im Projekt prüfen: nutzen sie `dart.library.html`? Dann dieselbe Bedingung verwenden wie im Projekt üblich.)

- [ ] **Step 4: Button im Kontakt-Formular** — in `kontakt_form_screen.dart` oberhalb der Namensfelder (im Formular-Aufbau) einfügen; Imports: `kontakt_picker_export.dart`, `google_kontakte.dart`:

```dart
            if (kontaktPickerVerfuegbar)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.contact_phone_outlined),
                  label: const Text('Aus Handy-Kontakten'),
                  onPressed: () async {
                    try {
                      final roh = await waehleHandyKontakt();
                      if (roh == null) return;
                      final k =
                          kontaktAusPicker(roh.name, roh.telefon, roh.email);
                      setState(() {
                        if (k.vorname != null) _vornameController.text = k.vorname!;
                        if (k.nachname != null) {
                          _nachnameController.text = k.nachname!;
                        }
                        if (k.telefon != null) _telefonController.text = k.telefon!;
                        if (k.email != null) _emailController.text = k.email!;
                      });
                    } catch (_) {
                      // Abbruch/Verweigerung: Formular unverändert lassen.
                    }
                  },
                ),
              ),
```

Controller-Namen vorher im File verifizieren (grep `TextEditingController` in `kontakt_form_screen.dart`) und exakt die vorhandenen verwenden.

- [ ] **Step 5: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(kontakte): Contact Picker — Handy-Kontakt ins Formular übernehmen (nur Chrome/Android)"
```

---

### Task GK-8: Gesamtverifikation, Deploy, Abnahme

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml:4` (Version), `sbs_projer_app/lib/core/app_version.dart` (kAppVersion), `ToDo.md`

- [ ] **Step 1: Volle Suite + Analyse**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test
```

Erwartung: 0 neue Analyse-Fehler, alle Tests grün.

- [ ] **Step 2: Version bumpen** — `pubspec.yaml` Zeile 4 → `version: 0.52.0+588`; `lib/core/app_version.dart` → `kAppVersion = '0.52.0'`.

- [ ] **Step 3: Build + Cache-Bust**

```bash
export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
```

- [ ] **Step 4: main committen + pushen, dann gh-pages-Deploy mit Branch-Guard**

```bash
git add -A && git commit -m "chore: v0.52.0 — Google-Kontakte-Sync + Contact Picker" && git push origin main
git checkout gh-pages && CUR=$(git branch --show-current) && if [ "$CUR" != "gh-pages" ]; then echo "ABBRUCH: $CUR"; exit 1; fi \
  && rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs \
  && cp -r sbs_projer_app/build/web/* . && touch .nojekyll \
  && git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/ \
  && git commit -m "deploy v0.52.0 — Google-Kontakte-Sync + Contact Picker" && git push origin gh-pages && git checkout main
```

- [ ] **Step 5: Live-Version prüfen** — `curl -s "https://danielproyer.github.io/sbs-projer-dev/version.json?nocache=$RANDOM"` bis `0.52.0` erscheint (Hintergrund-until-Loop).

- [ ] **Step 6: ToDo.md ergänzen** — neuen Punkt oben: v0.52.0 live, Abnahme-Checkliste für Daniel (siehe Step 7), committen + pushen.

- [ ] **Step 7: Abnahme durch Daniel (manuell, Pixel 9)** — Checkliste an Daniel:
  1. App laden (v0.52.0 im Forderungen-Titel), Einstellungen → «Google-Verbindung erneuern» → Google-Consent mit Kontakte-Freigabe.
  2. «Jetzt syncen» → SnackBar mit Zählern; Google Kontakte App: Label «SBS App» mit Kontakten + Betrieben, Stichprobe Namen/Firma/Nummern.
  3. Kontakt in der App ändern → nach ~1 Min in Google nachschauen (Auto-Sync).
  4. Test-Kontakt löschen → verschwindet; Betrieb auf inaktiv → verschwindet; wieder aktiv → kommt zurück (je «Jetzt syncen» oder kurz warten).
  5. Anruf-Test: Betriebs-/Kontaktnummer anrufen lassen → Name erscheint.
  6. Kontakt-Formular: «Aus Handy-Kontakten» → Felder vorbefüllt.

---

## Self-Review (erledigt)

- **Spec-Abdeckung:** OAuth-Scope+Erneuern (GK-4/GK-6), Edge-Function reconcile inkl. sbs_id-Regel/Batches/Status (GK-2), Migration 148 inkl. Dart-Aufräumen (GK-1), Service+Debounce+Trigger (GK-5), Einstellungs-Bereich (GK-6), Picker (GK-3/GK-7), Tests/Abnahme (GK-3/GK-8). Keine Lücken.
- **Platzhalter:** keine. Wo der Implementer etwas nachschlagen muss (Controller-Namen, Status-Upsert in oauth-exchange, Export-Bedingung), steht der exakte Suchbefehl bzw. die Referenzdatei.
- **Typ-Konsistenz:** `hatKontakteScope`/`kontaktAusPicker`/`kontakteSyncStatusText` (GK-3) werden in GK-6/GK-7 exakt so verwendet; `KontakteSyncErgebnis.info` (GK-5) passt zur Function-Antwort `info` (GK-2); Status-Felder `scope/contactsLastSyncAt/contactsLastSyncInfo` (GK-4) passen zu GK-6.
