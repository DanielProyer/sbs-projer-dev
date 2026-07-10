# Events-Modul — Phase E3: Inbetriebnahme + GPS-Karte + Pikett-Einsätze (Design)

**Datum:** 2026-07-10
**Aufbauend auf:** E1 (Kontakte, live v0.17.0), E2 (Stände/Anlagen/Dokumente, live v0.18.1)
**Phasenübersicht:** `2026-07-09-events-e1-design.md`
**Status:** Vom User abgenommen (10.07.2026)

## Ziel & Kontext

Am Event baut Daniel die Heineken-Schankanlagen auf, nimmt sie in Betrieb und leistet
Pikettdienst. E3 unterstützt genau das vor Ort: den Aufbau-Fortschritt festhalten
(Inbetriebnahme), Stände auf einer Karte wiederfinden (nachts, Festivalgelände) und
Pikett-Einsätze super einfach protokollieren. **Abrechnung bleibt unberührt** über
Montage Typ „Anlass". Die Einsatzliste ist die Grundlage für die spätere
**E4-Abschluss-Mail** an Eventverantwortlichen + RSL.

## Entscheidungen (mit User geklärt)

- **Inbetriebnahme pro Anlage** (nicht pro Stand): jede Schankanlage einzeln als „in Betrieb"
  markierbar. Der Stand zeigt den aggregierten Fortschritt.
- **GPS pro Stand** (nicht pro Anlage): ein Standort je Stand, bei der Inbetriebnahme erfasst.
- **Karte als Umschalter im Stände-Tab** (Liste ↔ Karte) + **neuer Tab „Einsätze"**.
  Tabs danach: Kontakte | Stände | Einsätze | Dokumente.
- **Alles in einem Paket** (ein Deploy als v0.19.0).

## Neue Abhängigkeiten

- `flutter_map` + `latlong2` (Karte), `geolocator` (GPS). Versionen passend zu Dart ^3.11
  wählen (aktuelle stabile).
- `web/index.html`: falls nötig `<meta http-equiv="Permissions-Policy" content="geolocation=(self)">`
  ergänzen. Live-URL ist HTTPS (GitHub Pages) → Browser-Geolocation funktioniert; localhost
  ebenfalls erlaubt (fürs Testen).

## Datenmodell (Migration 122)

**`event_staende`** — zwei Spalten ergänzen:
- `latitude` double precision (nullable), `longitude` double precision (nullable)

**`event_stand_anlagen`** — zwei Spalten ergänzen:
- `in_betrieb` boolean NOT NULL DEFAULT false
- `in_betrieb_am` timestamptz (nullable)

**`event_einsaetze`** — neue Tabelle:
- `id` uuid PK, `user_id` uuid NOT NULL
- `event_id` uuid NOT NULL → `events` ON DELETE CASCADE
- `stand_id` uuid → `event_staende` ON DELETE SET NULL (optional)
- `zeitpunkt` timestamptz NOT NULL DEFAULT now()
- `beschreibung` text NOT NULL
- `material` text (nullable)
- `created_at`/`updated_at`, RLS `user_id = auth.uid()`, updated_at-Trigger,
  Index (`user_id`, `event_id`)

**Flutter:** `event_einsaetze` als volle Sync-Vertikale nach E1/E2-Muster (DTO, Isar-Local,
Web-Stub, Export, Mapper, IsarService inkl. `…Get(int)`, Repository mit client-UUID +
serverseitigem Native-Delete, Provider, Sync-Tier 3). Die neuen Spalten von `event_staende`
und `event_stand_anlagen` werden in deren bestehende DTO/Local/Web/Mapper aufgenommen
(+ build_runner). Sync-`toJson`/`fromJson` erweitern.

## Bausteine

### 1. Inbetriebnahme (pro Anlage)

- In der **Stände-Ansicht** (aufgeklappte Stand-Karte) bekommt jede Anlagen-Zeile eine
  **Checkbox „in Betrieb"**. Umschalten setzt `in_betrieb` + `in_betrieb_am = now()`
  (bzw. löscht beides) und speichert die Anlage direkt (kein Formular-Umweg).
- Die **Stand-Karte** zeigt den Fortschritt als Chip: „3/5 in Betrieb" (X = Summe `anzahl`
  der Anlagen mit `in_betrieb`, Y = Summe aller `anzahl`) bzw. „✓ komplett" wenn alle laufen;
  „—" wenn keine Anlagen.
- **Formular-Erhalt (kritisch):** Das Stand-Formular bearbeitet Typ/Anzahl der Anlagen.
  Die bisherige „alles löschen + neu anlegen"-Ersetzung (`replaceForStand`) würde
  `in_betrieb` verwerfen. Sie wird auf einen **id-basierten Abgleich** umgestellt:
  bestehende Anlagen (per `serverId`) werden aktualisiert (Typ/Anzahl) und behalten
  `in_betrieb`/`in_betrieb_am`; nur entfernte Zeilen werden gelöscht, neue eingefügt.

### 2. GPS-Standort pro Stand

- Button **„📍 Standort erfassen"** an der Stand-Karte (und im Stand-Formular). Klick →
  `geolocator` fragt (einmalig) die Berechtigung ab und holt die aktuelle Position;
  `latitude`/`longitude` werden am Stand gespeichert. Erneutes Erfassen überschreibt.
- Zustände: kein Standort → Button „Standort erfassen"; erfasst → Indikator „📍 Standort
  erfasst" + Button „Neu erfassen". Fehler/kein Zugriff → verständliche Snackbar
  („Standortzugriff nicht möglich").
- Genauigkeit `LocationAccuracy.high`; kein Dauer-Tracking (einmaliger `getCurrentPosition`).

### 3. Karte (im Stände-Tab)

- Oben im Stände-Tab ein **Umschalter Liste ↔ Karte** (SegmentedButton/IconButtons).
- **Karte:** `flutter_map` mit **swisstopo-Luftbild** (SWISSIMAGE, WMTS Pseudo-Mercator):
  Tile-URL `https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg`
  (kein API-Key, Open Data). Attribution „© swisstopo" sichtbar.
- **Marker** pro Stand mit `latitude`/`longitude`; Karte zoomt automatisch auf die
  Marker-Bounds (bei einem Marker fester Zoom, bei keinem: Hinweis „Noch keine Stand-Standorte
  erfasst" + Karte auf die Schweiz zentriert). Tap auf Marker → kleines Popup: Stand-Name +
  Inbetriebnahme-Fortschritt + Button „Öffnen" (öffnet das Stand-Detail/-Formular).
- Braucht Netz (Tiles laden); GPS-Erfassung selbst geht offline.

### 4. Pikett-Einsätze (Tab „Einsätze")

- Neuer Tab mit Liste **neueste zuerst** (Zeitpunkt `dd.MM. HH:mm`, Beschreibung,
  Material-Zeile, optional Stand-Name-Chip). Leer-Zustand „Noch keine Einsätze".
- **FAB „+ Einsatz"** → bewusst minimales Formular:
  - Beschreibung (Pflicht, mehrzeilig)
  - Material (Freitext, optional — ein Feld, kein Lager-Lookup)
  - Stand (optional, Dropdown der Event-Stände + „—")
  - Zeitpunkt: Default = jetzt, editierbar (Datum/Zeit-Picker)
- Bearbeiten (Tap) und Löschen (Swipe/Menü, mit Bestätigung).

### Bedienfluss

Event-Detail → Tab „Stände": Karte finden/aufbauen, pro Stand GPS erfassen, Anlagen
abhaken. Tab „Einsätze": während des Piketts schnell Einsätze erfassen. E4 mailt die Liste.

## Abgrenzung E3

Nicht enthalten: Abschluss-Mail + PDF (E4), Verknüpfung zu App-Störungen, Montage/Abrechnung,
Verteilung-KI-Import. Keine Änderungen an bestehenden Features ausserhalb des Events-Moduls
(ausser der id-basierten Anlagen-Speicherung, die den Stand-Bearbeiten-Flow verbessert).

## Technik-Risiken (im visuellen Test verifizieren)

- **swisstopo-Tiles im Web-Canvas (CanvasKit):** Cross-Origin-Bilder brauchen CORS —
  swisstopo liefert CORS-Header; im Browser-Test bestätigen, dass Kacheln laden.
- **geolocator Web:** Berechtigungsabfrage + `getCurrentPosition` im Browser; auf localhost
  und HTTPS testbar.
- flutter_map-Version muss zu Dart ^3.11 / Flutter-Version passen (aktuelle stabile wählen,
  `flutter pub get` erfolgreich, `flutter analyze` sauber).

## Tests & Verifikation

- Unit-Tests: Inbetriebnahme-Fortschritt (x/y aus Anlagenliste, inkl. „komplett"/„keine"),
  Einsatz-Sortierung (neueste zuerst), Marker-Bounds-/Zentrums-Berechnung (0/1/n Punkte).
- `flutter analyze` ohne neue Findings; alle Tests grün; build_runner „Succeeded".
- Visueller Browser-Test vor Deploy (Pflicht): Anlage abhaken → Fortschritt am Stand;
  GPS erfassen (localhost erlaubt) → Marker auf swisstopo-Karte, Tap → Popup → Öffnen;
  Einsatz anlegen/bearbeiten/löschen; Stand-Formular bearbeiten (Anzahl ändern) →
  Inbetriebnahme-Häkchen bleiben erhalten; Kontakte/Dokumente unverändert.
