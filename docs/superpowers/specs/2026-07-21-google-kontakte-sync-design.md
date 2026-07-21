# Google-Kontakte-Sync + Contact Picker — Design

**Datum:** 21.07.2026 · **Status:** von Daniel freigegeben (Chat 21.07.)

## Ziel

Die App-Kontakte landen automatisch im Google-Adressbuch von Daniels Konto und
damit nativ auf dem Pixel 9: Eingehende Anrufe und WhatsApp zeigen den Namen
samt Betrieb (Anrufer-Erkennung). Sync ist strikt **einseitig App → Google**;
die App bleibt die einzige Wahrheit. Zusätzlich ein Import-Helfer im
Kontakt-Formular (Contact Picker, Handy → App).

## Entscheidungen (Daniel, 21.07.2026)

| Frage | Entscheid |
|---|---|
| Umfang | Kontaktpersonen **und** operative Betriebe mit Telefonnummer |
| Trigger | Automatisch nach Speichern/Löschen + manueller «Jetzt syncen»-Button |
| Löschungen | Mitlöschen; Betriebe bei Statuswechsel zurück auf aktiv **wieder anlegen** |
| Namensformat | Neutral, ohne SBS-Kennzeichnung |
| Contact Picker | Ja, Teil dieses Pakets |
| Architektur | Ansatz A: Abgleich-basiert (Reconcile), keine Mapping-Tabelle |

## Ist-Zustand (verifiziert 21.07.)

- `kontakte`: 104 Zeilen, **alle** mit Telefon; Felder u. a. `vorname`,
  `nachname`, `funktion`, `telefon`, `email`, `betrieb_id`, `rolle`,
  `kategorie`. Event-Kontakte (`event_kontakte`) sind reine Verknüpfungen auf
  `kontakte` → eine einzige Kontaktquelle.
- `kontakte.phone_contact_id` / `phone_last_synced_at`: vorbereitet, nie
  genutzt (0 Zeilen) — werden in diesem Paket **entfernt**.
- Google-OAuth existiert (Kalender-Integration): PKCE im Client,
  `google-oauth-exchange` tauscht den Code, `google_calendar_tokens` hält
  `refresh_token`, `access_token`, `scope` (aktuell `calendar.events openid
  userinfo.email`), `google_email`. `google-calendar-sync` zeigt das Muster
  für Edge-Functions mit `getAccessToken` via Refresh-Token.
- App-Links heute: nur `tel:` / `wa.me` / `mailto:` — keine Verbindung zum
  Adressbuch.

## Architektur

### 1. OAuth-Scope-Erweiterung

- Auth-URL im Client zusätzlich mit Scope
  `https://www.googleapis.com/auth/contacts` (inkrementell zum Kalender-Scope,
  ein gemeinsamer Consent).
- `google-oauth-exchange` bleibt unverändert (speichert Scope aus der
  Token-Antwort bereits generisch).
- Einstellungen-Bereich «Google Kontakte»: erkennt am gespeicherten
  `scope`-Feld, ob `auth/contacts` fehlt → zeigt dann «Google-Verbindung
  erneuern» (startet denselben OAuth-Flow neu). Kalender-Sync bleibt von der
  Erneuerung unberührt.

### 2. Edge-Function `google-contacts-sync` (Kern)

Eine einzige Action `reconcile`; jeder Lauf ist ein voller, selbstheilender
Abgleich:

1. **Access-Token** via Refresh-Token (gleiches Muster wie
   `google-calendar-sync`); User-Auth via Authorization-Header, Daten via
   Service-Role.
2. **Soll-Zustand** aus Supabase:
   - Kontakte: alle Zeilen aus `kontakte` mit Telefon **oder** E-Mail.
   - Betriebe: alle aus `betriebe` mit `status IN ('aktiv','saisonpause')`
     und nicht-leerem `telefon`.
3. **Label**: Contact Group «SBS App» suchen, sonst anlegen
   (`contactGroups.create`).
4. **Ist-Zustand**: `people.connections.list` (personFields inkl. `clientData`,
   `names`, `organizations`, `phoneNumbers`, `emailAddresses`, `memberships`,
   `metadata`), gefiltert auf Mitgliedschaft im Label.
5. **Identität**: `clientData` mit Key `sbs_id`, Wert `kontakt:<uuid>` bzw.
   `betrieb:<uuid>`. Google-Kontakte ohne `sbs_id` oder ausserhalb des Labels
   werden **nie** angefasst (private Kontakte sind sicher).
6. **Diff & Ausführung**:
   - Soll ohne Ist → `people.batchCreateContacts` (Batch ≤ 200).
   - Beide vorhanden, Felder abweichend → `people.updateContact` (mit etag
     des gelesenen Kontakts).
   - Ist ohne Soll → `people.batchDeleteContacts`.
   - Damit sind Löschungen UND Reaktivierungen abgedeckt: ein wieder aktiver
     Betrieb ist beim nächsten Lauf einfach wieder im Soll.
7. **Antwort**: `{created, updated, deleted, total}`; wird zusammen mit dem
   Zeitstempel in `google_calendar_tokens` gespeichert (siehe Datenmodell).

**Feld-Mapping Person** (`kontakt:<uuid>`):

| Google-Feld | Quelle |
|---|---|
| names.givenName / familyName | `vorname` / `nachname` |
| organizations[0].name | Betriebsname + `, ` + Ort (via `betrieb_id`) |
| organizations[0].title | `funktion` (fallback `rolle`) |
| phoneNumbers[0] (mobile) | `telefon` |
| emailAddresses[0] | `email` |
| memberships | Label «SBS App» |
| clientData.sbs_id | `kontakt:<uuid>` |

**Feld-Mapping Betrieb** (`betrieb:<uuid>`):

| Google-Feld | Quelle |
|---|---|
| names.unstructuredName | `name` + ` ` + `ort` (z. B. «Muloin Lenzerheide/Lai») |
| organizations[0].name | `name` |
| phoneNumbers[0] (work) | `telefon` |
| emailAddresses[0] | leer (Betriebs-Mail ist reine Info, Entscheid 16.07.) |
| memberships / clientData | Label + `betrieb:<uuid>` |

Die Mapping-/Diff-Logik liegt als reine TS-Funktionen oben in der
Function-Datei (Soll-Bau, Feldvergleich), getrennt vom I/O-Teil.

### 3. App-Seite

- **`GoogleContactsService`** (`lib/services/google/google_contacts_service.dart`):
  - `syncJetzt()` → ruft die Edge-Function, liefert Zähler/Fehler (für den
    Button).
  - `syncImHintergrund()` → fire-and-forget mit Entprellung (~5 s Debounce,
    mehrere schnelle Änderungen = ein Lauf); schluckt Fehler (nur debugPrint),
    No-op wenn nicht verbunden oder Scope fehlt.
- **Trigger**: Kontakt-Formular nach Speichern/Löschen; Betrieb-Formular nach
  Speichern (deckt Status- und Telefonänderungen ab). Kein Trigger in
  Sync-/Import-Pfaden nötig — der nächste Lauf gleicht ohnehin alles ab.
- **Einstellungen-Bereich «Google Kontakte»** (bei der bestehenden
  Google-Kalender-Sektion):
  - Verbunden + Scope ok → letzter Sync («21.07. 18:32 · 104 Kontakte,
    240 Betriebe») + Button «Jetzt syncen».
  - Scope fehlt → Hinweis + «Google-Verbindung erneuern».
  - Nicht verbunden → Verweis auf die Google-Verbindung.
- Kein Isar/Offline-Anteil: Sync setzt Online voraus; offline schlägt der
  Hintergrund-Lauf still fehl und der nächste Lauf holt alles nach.

### 4. Contact Picker (Handy → App)

- Kontakt-Formular: Button «Aus Handy-Kontakten», nur sichtbar wenn
  `navigator.contacts` existiert (Contact Picker API, Chrome/Android;
  Desktop/iOS automatisch ausgeblendet). JS-Interop via `package:web`/`dart:js_interop`.
- `select(['name','tel','email'], {multiple:false})` → reine Funktion
  `kontaktAusPicker(name, tel, email)` splittet den Namen (letztes Wort =
  Nachname, Rest = Vorname; ein Wort = Nachname) und befüllt
  Vorname/Nachname/Telefon/E-Mail im Formular vor. Nutzer prüft und speichert
  normal — kein Rückkanal, kein Auto-Save.
- Abbruch des Pickers oder fehlende Berechtigung: Formular bleibt unverändert,
  keine Fehlermeldung nötig (SnackBar nur bei echter Exception).

## Datenmodell (Migration 148)

```sql
ALTER TABLE google_calendar_tokens
  ADD COLUMN contacts_last_sync_at timestamptz,
  ADD COLUMN contacts_last_sync_info text;   -- z.B. '104 Kontakte, 240 Betriebe' oder 'Fehler: ...'
ALTER TABLE kontakte
  DROP COLUMN phone_contact_id,
  DROP COLUMN phone_last_synced_at;          -- nie genutzt, Identität lebt in Google (clientData)
```

Kein neues Sync-Vertical, keine Isar-Änderung (die beiden gedroppten Spalten
waren im Dart-Modell nie vorhanden — im Plan verifizieren).

## Fehlerbehandlung

- Auto-Sync: still (debugPrint); Einstellungen zeigen
  `contacts_last_sync_info` — auch Fehlertext («Fehler: token expired»).
- Manueller Sync: SnackBar mit Ergebnis bzw. Fehler.
- Google-API-Fehler mitten im Lauf: Function bricht ab und meldet den Fehler;
  der nächste Reconcile heilt den Teilzustand (Kern-Eigenschaft von Ansatz A).
- Rate Limits: irrelevant bei ~350 Einträgen (Batch-Endpunkte, ≤ 200 pro Call).
- Sicherheits-Regel: `clientData.sbs_id` ist die einzige Lösch-Legitimation —
  ohne sie wird nie gelöscht, auch nicht im Label.

## Tests

- **TDD (Dart, reine Funktionen):** `kontaktAusPicker` (Name-Split: 0/1/2/3
  Wörter, leere Felder), Soll-Filterung (`istSyncWuerdig` für Kontakt/Betrieb:
  Telefon/Mail-Regeln, Status-Regeln inkl. saisonpause), Anzeige-Helfer für
  den Einstellungs-Status.
- **Edge-Function:** Mapping/Diff als reine TS-Funktionen; Verifikation nach
  Deploy gegen das echte Konto (kein Deno-Test-Harness im Projekt).
- **Abnahme (Daniel, Pixel 9):** Erst-Sync per Button → Stichprobe im
  Google-Adressbuch (Label «SBS App», Namen/Firmen korrekt); Kontakt ändern →
  Auto-Sync; Kontakt löschen → verschwindet; Betrieb inaktiv → verschwindet,
  wieder aktiv → kommt zurück; Anruf-Test: Betriebs-/Kontaktnummer ruft an →
  Name erscheint. Contact Picker: Handy-Kontakt übernehmen.

## Bewusst NICHT im Umfang (YAGNI)

- Kein Rück-Sync Google → App (App bleibt die Wahrheit).
- Kein Foto-, Adress- oder Notizen-Sync.
- Kein Sync für inaktive/geschlossene Betriebe oder Nicht-Kunden-Filter —
  operativ + Telefon ist das einzige Kriterium.
- Keine Mapping-Tabelle / keine Wiederverwendung von `phone_contact_id`.
- Kein Offline-Queue für Sync-Aufträge.
