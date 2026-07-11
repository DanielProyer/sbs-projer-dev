# Google-Kalender-Integration — Recherche & Lösungsvorschlag (Termine-Überarbeitung)

**Datum:** 2026-07-10
**Status:** Recherche abgeschlossen (Multi-Agent-Workflow), Entscheidungen offen — noch KEIN abgenommenes Design.
**Zweck:** Grundlage für die Termine-Komplettüberarbeitung mit Google-Kalender-Sync.

> Verifiziert gegen Codebase: `PikettDienst` hat bereits `googleCalendarEventId`,
> `kalenderSyncStatus`, `kalenderSyncFehler`, `kalenderSyncAt` + `datumStart`/`datumEnde`.
> `Termin` hat ein einzelnes `erinnerungVorlaufMinuten`/`erinnerungAktiv`/`erinnerungTage`,
> `betriebId` ist Pflichtfeld. `reminder_service_web.dart` existiert (Timer-basiert, nur bei
> offenem Tab).

## Kernaussage

- **Erinnerungs-Zustellung an Google delegieren.** Google Calendar API erlaubt pro Event bis zu
  **5 `reminders.overrides`** (Methode `popup`/`email`, Vorlauf minutengenau 0–40320 = 4 Wochen,
  `useDefault=false`). Google stellt selbst zu → **kein Service Worker / kein Web-Push nötig**
  (umgeht `--pwa-strategy=none` vollständig). Eigenbau-Web-Push wird **nicht** empfohlen.
- **OAuth nur serverseitig:** Authorization Code + PKCE, Token-Tausch in Supabase Edge Function,
  Refresh-Token verschlüsselt in Postgres (RLS service_role) — **nie im Browser**.
- **Sync per pg_cron-Polling** (alle 5–15 Min) + `syncToken` (inkrementell). Kein Webhook nötig.
- **CRM-Verknüpfung** via `extendedProperties.private` (unsichtbare `termin_id`/`betrieb_id`/… am Event).

## Optionen

| Option | Kurz | Erinnerungen | Eingabeaufwand | Empfohlen |
|---|---|---|---|---|
| **A Voll-Auslagerung** | Google = alleinige Quelle, App zeigt nur an | nativ, voll | minimal, aber App verliert strukturierte Termine (Tourenplanung/Rechnung/Pikett-Abrechnung) | ❌ |
| **B Hybrid** ⭐ | App führt Pikett/Events/Service-Termine → Einweg-Push nach Google; freie Termine erfasst User in Google → Import zurück | nativ via `reminders.overrides` | minimal (User arbeitet weiter in Google) | ✅ |
| **C App-nativ + ICS/Links** | Export per ICS-Abo/Add-to-Calendar | ICS-VALARM wird von Google **ignoriert**; Abo-Update nur alle 12–24 h | Doppelpflege bleibt | ❌ (nur Übergang) |

## Empfehlung: Option B (Hybrid), staged

1. Google-Cloud-Projekt + OAuth-Consent (Scope `calendar.events`; `calendar` nur falls Unterkalender
   per API angelegt werden). Consent auf **„In Production"** (bzw. **„Internal"** bei Workspace).
2. Edge Function `google-oauth-callback` (Code+PKCE → Refresh-Token → `google_calendar_tokens`).
   App-Einstellungen: Button „Mit Google Kalender verbinden".
3. Edge Function `google-calendar-sync` via pg_cron: Push App→Google (Pikett/Events/Service in
   Unterkalender mit Farben + `reminders.overrides`); Import Google→App (freie Termine via `syncToken`).
4. **Datenmodell:** `Termin` von einzelnem `erinnerungVorlaufMinuten` auf **JSON-Array**
   `[{methode, minuten}]` (≤5) erweitern → 1:1 auf `reminders.overrides`.
5. Flutter-Web spricht Google **nie** direkt an (nur gegen Supabase).

## Kritische Implementierungs-Caveats (aus adversarischer Kritik)

- **Refresh-Token nur mit `access_type=offline` + `prompt=consent`** — sonst liefert Google keinen
  Refresh-Token. (Wichtiger noch als der 7-Tage-Verfall.)
- Google-Web-Client braucht **trotz PKCE weiterhin den `client_secret`** beim Token-Tausch.
- **„In Production" mit sensitive scope bleibt dauerhaft „unverified"** (100-User-Cap, Warnung bei
  jedem neuen Consent) — für Single-User unkritisch, aber nicht garantiert „einmalig für immer".
- **`popup` aus Sekundär-(Unter-)Kalendern ist NICHT garantiert:** feuert nur, wenn der Unterkalender
  am Handy sichtbar + benachrichtigungsaktiv gesynct ist. → **`email` ist der einzig geräteunabhängig
  robuste Kanal.** Bei iPhone + Apple-Kalender-Abo feuern Google-`popup` gar nicht.
- **All-day-Events:** `minutes`-Vorlauf zählt ab Mitternacht (00:00) des Starttags; `end.date` ist
  **exklusiv** (letzter Tag + 1). Für Pikett/Events relevant.
- **Timed Events:** `start/end.timeZone = 'Europe/Zurich'` zwingend (sonst DST-Verschiebung).
- **`syncToken` kann mit HTTP 410 invalidiert werden** → Full-Resync-Fallback nötig.
- **Einweg-Push Konflikt-Regel** definieren: Was, wenn Daniel ein app-gepushtes Event in Google
  verschiebt/löscht? (App gewinnt / Google-Änderung respektieren).
- **Wiederkehrende Pikett-Dienste (RRULE):** Ausnahmen (Ausfall/andere Zeit) brauchen EXDATE/
  Instanz-Overrides — komplexer als „einfach RRULE".
- **Alternative, die der User explizit erfragt hat:** Supabase-Auth **Google-Provider** mit
  Calendar-Scopes (Google wird App-Login, liefert `provider_token`/`provider_refresh_token`) — kann
  die eigene OAuth-Edge-Function ersparen. Caveat: Server-Cron-Refresh muss selbst persistiert werden.

## Offene Entscheidungsfragen (vor Design)

1. **Google-Workspace-Account (Firmendomain) vorhanden?** → „Internal" (kein Verfall/Warnung) vs.
   privates @gmail (In-Production, einmalige Warnung).
2. **Login-Ansatz:** Google als App-Login (Supabase-Provider) vs. separater „Verbinden"-Button.
3. **Umfang Schreib-Sync:** nur Pikett+Events, oder auch fällige Reinigungen/Service-Termine?
4. **Gerät/Kanal:** Android + Google-Kalender-App (popup ok) vs. iPhone/email-Pflichtkanal. Brauchen
   app-generierte Termine überhaupt Erinnerungen oder nur Sichtbarkeit?
5. **Freie Termine:** echter Zwei-Wege-Sync oder Read-only-Import (einfacher)?
6. **Unterkalender/Farben** (Vorschlag: SBS Pikett rot, SBS Events gelb, SBS Service grün #008200) —
   einmal manuell anlegen → kleinerer Scope `calendar.events`.
7. **`Termin.betriebId`** für importierte freie Termine ohne Betrieb optional machen?
8. **Sofort-Zwischenlösung** (Add-to-Calendar-Link ohne OAuth) zuerst, während API-Variante nachzieht?

## Quellen (Auswahl)

Google Calendar API: OAuth2, Scopes, Reminders/Notifications, Sync (syncToken), Push/watch,
Extended Properties, Quota, Service-Account. Supabase: Scheduled Edge Functions, pg_cron,
Google-Provider-Refresh-Token (#19384). Web-Push/PWA: iOS-Safari-Limits, FCM/FlutterFire,
flutter #74223 (Service Worker). ICS: Refresh-Rate 12–24 h, VALARM-ignoriert. (Volle Liste im
Workflow-Journal.)
