# Design: Termin-Erinnerungen (Popup/Alarm)

**Datum:** 2026-05-31
**Status:** Genehmigt (Design)
**Feature:** Erinnerungsfunktion für Kalender-Termine mit Benachrichtigung/Alarm

## Ziel

Wichtige Kalender-Termine sollen den Nutzer rechtzeitig per Benachrichtigung
erinnern — auf Android als echte System-Benachrichtigung (auch bei geschlossener
App), in der Web-App als Browser-Notification + In-App-Hinweis (solange die App
offen ist). **Kein Push-Server.**

## Anforderungen (aus Brainstorming)

- Erinnerungen auf Android UND Web, aber **ohne Push-Server**.
- Web: Erinnerung nur wenn die App/der Browser offen ist (akzeptiert — App ist
  tagsüber durchgehend offen).
- Erinnerungszeitpunkt **frei pro Termin wählbar** (Vorlaufzeit).
- Erinnerung **pro Termin aktivierbar, Standard AUS** ("wichtige Termine").
- Web-Darstellung: **Browser-Notification (mit Ton) + In-App-Hinweis**.

## 1. Datenmodell (DB-Migration)

Die bestehende Spalte `erinnerung_tage` (int, default 3) reicht für feingranulare
Vorläufe (30 Min, 1 Std) nicht. Neue Spalten auf Tabelle `termine`:

- `erinnerung_aktiv` (boolean, NOT NULL, default `false`)
- `erinnerung_vorlauf_minuten` (int, NOT NULL, default `1440` = 1 Tag)

`erinnerung_tage` bleibt vorerst unangetastet (keine Datenmigration nötig, da
Erinnerungen standardmäßig aus sind). Kann in einem späteren Cleanup entfernt werden.

Anzupassen (Conditional-Export-Pattern, vgl. CLAUDE.md):
- `data/models/termin.dart` (DTO: Felder + fromJson/toJson)
- `data/local/termin_local.dart` (@Collection) + `termin_local_web.dart` (Stub)
- `data/mappers/termin_mapper.dart`
- `isar_service.dart` falls typisierte Queries betroffen
- Nach Änderung an `@Collection`: `dart run build_runner build`

### Vorlauf-Optionen (UI-Dropdown)
0 Min (pünktlich), 15 Min, 30 Min, 1 Std, 2 Std, 1 Tag, 2 Tage, 3 Tage, 1 Woche.
Default beim Aktivieren: **1 Tag** (1440 Min).

### Bezugszeitpunkt der Erinnerung
- Termin **mit** Uhrzeit: `Datum + uhrzeit_von − Vorlauf`.
- Termin **ohne** Uhrzeit (ganztägig): Bezug `08:00` am Termintag, dann `− Vorlauf`.

## 2. Plattform-Mechanismus

Ein `ReminderService` (Conditional Export) mit klarer Schnittstelle:
- `Future<void> schedule(Termin t)` — plant/aktualisiert die Erinnerung eines Termins
- `Future<void> cancel(String terminId)` — entfernt die geplante Erinnerung
- `Future<void> rescheduleAll()` — plant alle zukünftigen aktiven Erinnerungen neu
- `Future<bool> requestPermission()` — fordert Benachrichtigungsrechte an

Benachrichtigungs-ID = stabiler Integer-Hash der Termin-UUID (für gezieltes
Cancel/Update).

### Android (nativ)
- Pakete: `flutter_local_notifications`, `timezone`.
- Beim Speichern/Ändern/Löschen eines Termins: `schedule`/`cancel` aufrufen.
  Funktioniert **auch bei geschlossener App** (lokal geplanter Alarm, kein Server).
- Beim App-Start (nach Login): `rescheduleAll()` — wichtig, da Android geplante
  Notifications nach Geräte-Neustart verliert (Boot-Receiver + Reschedule).
- Berechtigungen: `POST_NOTIFICATIONS` (Android 13+, Runtime-Request),
  exakte Alarme (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`); Fallback auf inexakte
  Alarme, falls exakte nicht erlaubt.
- AndroidManifest: Notification-Permission, Boot-Receiver, Icon.

### Web
- Kein Service Worker (bewusst deaktiviert, `--pwa-strategy=none`) → keine
  Background-Push.
- **In-App-Scheduler**: ein `Timer.periodic` (z.B. jede Minute), der prüft, ob
  eine aktive Erinnerung fällig ist. Läuft, solange die App offen ist.
- Bei Fälligkeit:
  - **Browser-Notification** über die Web Notification API (`dart:html`), mit Ton —
    erscheint auch, wenn die App in einem Hintergrund-Tab/-Fenster liegt (solange
    der Browser läuft).
  - **In-App-Hinweis** (Dialog/Banner) zusätzlich.
- Einmalige Berechtigungsabfrage (`Notification.requestPermission`).
- **Dedup**: bereits ausgelöste Erinnerungs-IDs in `localStorage` merken →
  kein erneutes Auslösen bei Reload/erneutem Tab-Fokus.

## 3. UI

- **Termin-Formular** (`termin_form_screen.dart`):
  - Schalter „Erinnerung" (Standard aus).
  - Wenn aktiv: Dropdown „Vorlaufzeit" (Optionen s.o.).
- **Kalender** (`termine_kalender_screen.dart`):
  - Kleines Glocken-Icon bei Terminen mit aktiver Erinnerung.

## 4. Integration / Datenfluss

1. Nutzer aktiviert Erinnerung + Vorlauf im Termin-Formular → Speichern.
2. Repository persistiert Termin → `ReminderService.schedule(t)` (bzw. `cancel`
   wenn deaktiviert/gelöscht).
3. Android: System plant lokalen Alarm. Web: nächster Scheduler-Tick erfasst ihn.
4. Bei Fälligkeit: Benachrichtigung/Popup mit Titel, Anlass, Betrieb, Datum/Uhrzeit.
5. App-Start: `rescheduleAll()` (Android) bzw. Scheduler-Start (Web).

## 5. Fehlerbehandlung

- Verweigerte Benachrichtigungsrechte: Feature degradiert sauber — Erinnerung
  wird gespeichert, aber kein System-Alarm; Hinweis an den Nutzer (einmalig).
- Termin in der Vergangenheit / Erinnerungszeitpunkt bereits vorbei: nicht planen.
- Web ohne Notification-Support: Fallback nur In-App-Hinweis.

## 6. Bewusst NICHT enthalten (YAGNI, v1)

- Kein Push-Server, keine Erinnerung bei vollständig geschlossenem Browser.
- Kein Snooze / keine Wiederholung.
- Keine Migration der bestehenden `erinnerung_tage`-Werte.

## Betroffene Komponenten (Überblick)

| Komponente | Änderung |
|---|---|
| DB-Migration `Datenbank/migrations/` | Neue Spalten `erinnerung_aktiv`, `erinnerung_vorlauf_minuten` |
| `termin.dart` / `termin_local*.dart` / `termin_mapper.dart` | Neue Felder |
| `services/notification/reminder_service*.dart` (neu) | Conditional Export: native + web |
| `termin_repository.dart` | schedule/cancel nach save/delete |
| `termin_form_screen.dart` | Toggle + Vorlauf-Dropdown |
| `termine_kalender_screen.dart` | Glocken-Icon |
| App-Start (nach Login) | `rescheduleAll()` / Scheduler-Start |
| `AndroidManifest.xml`, `pubspec.yaml` | Permissions, Pakete |
