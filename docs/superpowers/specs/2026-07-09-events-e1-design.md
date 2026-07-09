# Events-Modul — Phase E1: Event-Gerüst + Kontaktliste (Design)

**Datum:** 2026-07-09
**Quellen:** `Prompts/06_Optimierung_App_2026_07_07.txt` (Kontakte/Events), `Prompts/07_Events_Ablauf.txt` (Ablauf), Beispieldateien `00_Event/Lageplan 2024.pdf` + `00_Event/Verteilung.pdf`
**Status:** Vom User abgenommen (09.07.2026)

## Kontext (Ablauf Daniel)

Heineken bietet Daniel Monate vor einem Event (Gampel, Chant du Gros, OpenAir Val Lumnezia,
Albani Fest …) auf. Vor dem Event kommen Geländeplan (PDF) und eine „Verteilung"
(Pro-POS-Liste: pro Stand die zugeteilten Schankanlagen + Material). Daniels Aufgaben:
Aufbau/Inbetriebnahme der Anlagen und Pikettdienst. **Abrechnung (Zeit + Spesen) läuft
unverändert über Montage Typ „Anlass" + Montage-PDF in die Heineken-Monatsrechnung —
das Events-Modul ersetzt NICHT die Abrechnung.** Kommunikation am Event: primär WhatsApp.
Kontakte (OK, Bau, Standbetreiber, Eventverantwortlicher, RSL) bleiben über Jahre oft gleich.

## Phasenübersicht (Gesamtmodul, je eigene Spec → Plan → Umsetzung)

| Phase | Inhalt |
|---|---|
| **E1 (diese Spec)** | Event-Jahr-Entität + Kontaktliste pro Event-Jahr (Rollen, Vorjahres-Übernahme) + WhatsApp/Anruf |
| E2 | Lageplan-PDF (hochladen/ansehen/zoomen) + Stände + Anlagen pro Stand (manuell + Vorjahres-Übernahme) |
| E3 | Inbetriebnahme-Checkliste pro Stand/Anlage, GPS-Erfassung des Stands bei Inbetriebnahme, Karten-Tab (`flutter_map` + swisstopo-Luftbild SWISSIMAGE, Open Data, kein API-Key), Pikett-Einsätze (super-einfach: Beschreibung + 1 Material-Slot) |
| E4 | Abschluss-Mail: Liste aller Einsätze als PDF an Eventverantwortlichen + RSL + optional weiteren Kontakt (`MailConfig`-Bereich `event`); Schnellzugriff auf Anlass-Montage |
| später (optional) | Verteilung-PDF-Import per KI-Extraktion (Stände/Anlagen), analog `parse-rechnung` |

**Architektur-Grundsatz:** Ein Event-Jahr referenziert den bestehenden
**Veranstaltungs-Betrieb** (erkennbar an `zapfsysteme` enthält `'Veranstaltungen'`).
Betriebe, Montagen, Störungen und deren Historie bleiben unangetastet.
„Auslagern" = eigenes Modul in der App (`presentation/screens/events/`), keine separate App.

## E1 — Scope

### Datenmodell (Migration 119)

**Tabelle `events`** (das Event-Jahr):
- `id` uuid PK, `user_id` uuid (RLS wie übrige Tabellen)
- `betrieb_id` uuid NOT NULL → `betriebe` (der Veranstaltungs-Betrieb)
- `jahr` int NOT NULL (z. B. 2025)
- `termin_von` date, `termin_bis` date (nullable — Termin steht anfangs oft noch nicht)
- `notizen` text
- `created_at`, `updated_at`
- UNIQUE (`user_id`, `betrieb_id`, `jahr`) — pro Veranstaltung und Jahr genau ein Event
- Kein Status-Feld: „kommend / laufend / vorbei" wird aus `termin_von/bis` abgeleitet.
  Felder für Lageplan (E2) und Abschluss-Mail (E4) werden in den jeweiligen Phasen ergänzt.

**Tabelle `event_kontakte`** (Zuordnung Person ↔ Event-Jahr):
- `id` uuid PK, `user_id` uuid
- `event_id` uuid NOT NULL → `events` (ON DELETE CASCADE)
- `kontakt_id` uuid NOT NULL → `kontakte`
- `rolle` text NOT NULL, CHECK IN (`'ok'`, `'bau'`, `'stand'`, `'event_heineken'`,
  `'rsl'`, `'monteur'`, `'stardrinks'`, `'sonstige'`)
- `bemerkung` text (z. B. Standname „Signina Bar")
- `created_at`, `updated_at`
- UNIQUE (`event_id`, `kontakt_id`, `rolle`) — verhindert Doppel-Zuordnung

Kontakte bleiben globale Personen in `kontakte` (Telefon einmal gepflegt); die Rolle liegt
auf der **Zuordnung** (dieselbe Person kann je Jahr/Event andere Rollen haben). Die
globale `kontakte.kategorie/rolle` bleibt unverändert bestehen.

**Flutter:** Beide Entities nach der 13-Schritte-Checkliste (CLAUDE.md): DTO, Isar-Collection
(`event_local.dart`, `event_kontakt_local.dart`), Web-Stubs, Conditional Exports, Mapper,
IsarService-Queries, Repositories (kIsWeb-Branching, Supabase-Listen paginieren),
Riverpod-Provider, SyncService (Pull-Reihenfolge: nach `betriebe` und `kontakte`,
da FK-abhängig). `dart run build_runner build` nach Collection-Anlage.

### Screens & Bedienung

1. **Dashboard-Kachel „Events"** im Kachel-Grid (`home_screen.dart`), Zähler = Anzahl
   Event-Jahre im aktuellen Jahr.
2. **Events-Liste** (`events_list_screen.dart`): flache Liste der Event-Jahre
   („Lumnezia 2025", „Gampel 2024" …). Sortierung: laufende zuerst, dann kommende
   (nächster Termin zuerst), dann vergangene (neueste zuerst). Suche nach Name/Ort.
   Status-Badge je Karte (laufend = grün, kommend = blau mit „in X Tagen", vorbei = grau).
3. **Event anlegen** (FAB → `event_form_screen.dart`):
   - Veranstaltungs-Betrieb wählen (Auswahl gefiltert auf `zapfsysteme` enthält
     `'Veranstaltungen'`; Hinweistext, falls Betrieb fehlt → zuerst als Betrieb anlegen)
   - Jahr (Default: aktuelles Jahr), Termin von/bis (optional), Notizen
   - **Checkbox „Kontakte aus Vorjahr übernehmen"**: sichtbar + vorausgewählt, wenn zum
     gewählten Betrieb ein Event mit kleinerem Jahr existiert (das jüngste wird kopiert)
4. **Event-Detail** (`event_detail_screen.dart`):
   - Kopf: Name (Betrieb + Jahr), Termin, Status-Badge, Ort, Notizen; Bearbeiten/Löschen
   - **Kontaktliste, nach Rolle gruppiert** in fixer Reihenfolge: Eventverantwortlicher
     (event_heineken), RSL, OK, Bau, Stand, Monteur, Stardrinks, Sonstige
   - Pro Kontakt-Zeile: Name, Bemerkung/Funktion, Telefonnummer, Aktionen:
     **WhatsApp-Button** + **Anruf-Button**; überflüssige Zuordnung entfernbar
     (Zuordnung löschen, NICHT den Kontakt selbst)
   - Button „Aus Vorjahr übernehmen" (nachträglich; ergänzt fehlende, keine Duplikate)
5. **Kontakt zuordnen** (BottomSheet/Screen):
   - Suche über ALLE bestehenden Kontakte (jede Kategorie — auch Heineken-Leute wie
     RSL/Event Manager), Anzeige mit Name/Kategorie/Telefon
   - Oder „Neuer Kontakt" → bestehendes `kontakt_form_screen.dart` (Kategorie-Vorschlag
     `event`), danach zurück zur Zuordnung
   - Rolle wählen (Pflicht) + Bemerkung (optional) → speichern

### Vorjahres-Übernahme (Regel)

Quelle = Event desselben Betriebs mit dem grössten Jahr < Ziel-Jahr. Kopiert werden alle
`event_kontakte` (kontakt_id, rolle, bemerkung). Merge-Regel: existiert die Kombination
(kontakt_id, rolle) im Ziel bereits, wird sie übersprungen. Ergebnis-Snackbar:
„X Kontakte übernommen".

### WhatsApp & Anruf

- WhatsApp: `https://wa.me/<E.164-Nummer ohne +>` via bestehendem `url_launcher`
  (externe App). Nummern-Basis: vorhandene Normalisierung (`telefonNormalized`,
  CH-Default +41). Ohne Telefonnummer: Button ausgeblendet.
- Anruf: `tel:` wie im bestehenden Kontakte-Screen.

### Abgrenzung E1

Nicht enthalten: Stände, Lageplan-Upload, Karte/GPS, Einsätze, Abschluss-Mail,
Verteilung-Import (→ E2–E4). Keine Änderungen an Montage/Abrechnung, Betrieben,
bestehenden Kontakt-Screens (ausser Wiederverwendung des Formulars).

### Tests & Verifikation

- Unit-Tests: Status-Ableitung aus Termin (kommend/laufend/vorbei, Randtage),
  Merge-Regel der Vorjahres-Übernahme, wa.me-Link-Bildung aus Rohnummern.
- `flutter analyze` ohne neue Findings; bestehende Tests grün.
- Visueller Browser-Test vor Deploy (Pflicht): Kachel, Anlegen mit Übernahme,
  Gruppierung, WhatsApp-/Anruf-Buttons (Link-Ziel prüfen), Löschen einer Zuordnung.
