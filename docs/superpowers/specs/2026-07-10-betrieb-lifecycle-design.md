# Betrieb-Lifecycle & Auto-„mein Kunde" (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** User-Wunsch — inaktive Betriebe automatisch aus „mein Kunde" nehmen, Reaktivierung
automatisch, und ein sauberer Umgang mit dauerhaft geschlossenen Betrieben (Umnutzung/Abbruch).

## Ziel & Kontext

Der `istMeinKunde`-Flag wird heute manuell gepflegt (mit einer kleinen Auto-Regel im Formular, die
nur auf `zapfsysteme` reagiert). Dadurch sind in der DB **108 Betriebe** noch „mein Kunde", obwohl sie
inaktiv (4) oder geschlossen (104) sind. Dieses Paket macht `istMeinKunde` weitgehend automatisch
(mit manuellem Override), bereinigt den Bestand und formalisiert den Lebenszyklus eines Betriebs
inkl. dauerhafter Schliessung mit Grund/Datum.

## Verifizierte Fakten (Ist-Zustand)

- `betriebe.status` genutzte Werte: `aktiv` (290), `inaktiv` (12), `geschlossen` (104).
- **Formular-Status-Dropdown** (`betrieb_form_screen.dart:795`) bietet aktuell `aktiv`, `inaktiv`,
  `saisonpause` — **`geschlossen` fehlt** (die 104 kamen per Import).
- **Betriebe-Liste-Filter** (`betriebe_list_screen.dart`) kennt `alle/aktiv/inaktiv/geschlossen`,
  Default `alle`.
- „Konventionell/Orion" sind **Zapfsysteme** (`betriebe.zapfsysteme`, Chips
  `['David','Konventionell','Higenie','Orion','Veranstaltungen']`), **kein** Anlagentyp. Der
  `anlagen.typ_anlage` kennt nur Warmanstich/Kaltanstich/Buffetanstich/Orion.
- Bestehende Formular-Auto-Regel: `mein Kunde = false`, wenn `zapfsysteme` nicht leer ist und
  ausschliesslich aus `{David, Higenie, Veranstaltungen}` besteht (`betrieb_form_screen.dart:372`).
- Karten-Fälligkeit ignoriert inaktive Betriebe bereits seit v0.25.2 (grün); dieses Paket blendet
  sie zusätzlich standardmässig aus.

## Entscheidungen (mit User geklärt)

- **B „mein Kunde":** Auto-Vorschlag **mit manuellem Override** (Schalter bleibt).
- **C Schliessung:** dauerhaft geschlossene Betriebe bekommen **Grund + Datum**.
- **D Sichtbarkeit:** **inaktive UND geschlossene** Betriebe standardmässig aus Karte + Betriebs-Liste
  ausblenden (nur per Filter sichtbar).
- **Deploy:** ein Paket als **v0.26.0**.

## Status-Vokabular (vereinheitlicht)

Kanonische Werte: **`aktiv`**, **`inaktiv`** (temporär, reaktivierbar; inkl. „Saisonpause" als
Spezialfall von inaktiv), **`geschlossen`** (dauerhaft: Umnutzung/Abbruch/Konkurs).

- Formular-Dropdown erhält die Option **`geschlossen`**. `saisonpause` bleibt als Option erhalten
  (Rückwärtskompatibilität), zählt aber überall als „nicht aktiv" (wie `inaktiv`).
- Für alle Regeln unten gilt die Zweiteilung **`aktiv`** vs. **nicht `aktiv`**
  (= `inaktiv`/`saisonpause`/`geschlossen`).

## Baustein B — Auto-„mein Kunde" mit Override

### B.1 Reine Funktion (testbar)

`istMeinKundeVorschlag(String status, List<String> zapfsysteme) → bool`:

- `status != 'aktiv'` → **false**.
- `status == 'aktiv'` → **true**, wenn `zapfsysteme` `'Konventionell'` **oder** `'Orion'` enthält;
  sonst **false**.

Damit ist die alte „nur David/Higenie/Veranstaltungen"-Regel als Spezialfall abgedeckt (kein
Konventionell/Orion → false) und zusätzlich statusabhängig.

### B.2 Formular-Verhalten (Override)

- Bei **Status-Änderung** und bei **Zapfsystem-Änderung** wird der `_istMeinKunde`-Schalter auf
  `istMeinKundeVorschlag(...)` gesetzt (ersetzt die bestehende Inline-Auto-Regel).
- Der Schalter bleibt bedienbar: Der User kann den Vorschlag **manuell übersteuern**; beim Speichern
  wird der Schalterwert gespeichert (kein erneutes Überschreiben beim Save).

### B.3 Einmal-Bereinigung (Migration)

`UPDATE betriebe SET ist_mein_kunde = false WHERE status <> 'aktiv';`

- Betrifft die 108 (4 inaktiv + 104 geschlossen). **Aktive Betriebe bleiben unangetastet** — die
  230 aktiv/true und 60 aktiv/false (bewusste manuelle Einstellungen) werden nicht verändert.

## Baustein C — Dauerhafte Schliessung dokumentieren

### C.1 Datenmodell (Migration, additiv)

Neue Spalten auf `betriebe`:
- `schliessungsgrund text` (nullable) — erlaubte Werte per App: `umnutzung`, `abbruch`, `konkurs`,
  `sonstiges` (kein DB-CHECK nötig; App-seitige Auswahl).
- `schliessungsdatum date` (nullable).

Durch DTO (`Betrieb`), Isar-Local (`BetriebLocal` + Web-Stub), Conditional Export unverändert,
`BetriebMapper` (fromDto/toJson) durchreichen.

### C.2 Formular

- Nur wenn **Status = `geschlossen`**: Dropdown „Schliessungsgrund" (Umnutzung/Abbruch/Konkurs/
  Sonstiges) + Datumsauswahl „Schliessungsdatum". Bei anderem Status ausgeblendet; Werte werden bei
  Nicht-`geschlossen` auf `null` gesetzt (analog zur Ferien-/Saison-Logik).

### C.3 Detail

- Wenn `status == 'geschlossen'`: Zeilen „Schliessungsgrund" (Label statt Code) und
  „Schliessungsdatum" in der Details-Karte anzeigen.

## Baustein D — Sichtbarkeit

### D.1 Betriebe-Liste

- Default-`_statusFilter` von `'alle'` → **`'aktiv'`** (zeigt standardmässig nur aktive). Über den
  bestehenden Status-Filter (`alle/aktiv/inaktiv/geschlossen`) sind inaktive/geschlossene erreichbar.

### D.2 Karte

- Marker standardmässig **nur `aktiv`**. Neuer Filter-Schalter „Inaktive/geschlossene zeigen"
  (default aus) in der Karten-Filterleiste; ist er an, werden auch nicht-aktive Betriebe (grau/nicht
  fällig, wie seit v0.25.2) angezeigt.
- Der „ohne Standort"-Zähler zählt konsistent nur die aktuell angezeigte Menge.

## Abgrenzung

- Keine Änderung an der bestehenden Fälligkeits-/Touren-Logik (die filtert `aktiv` bereits selbst).
- Kein Hard-Delete/Soft-Delete-Umbau: `geschlossen` bleibt ein Status (kein Löschen). Löschen bleibt
  wie in v0.25.1 (nur wenn keine verknüpften Daten).
- Kein DB-CHECK-Constraint für `schliessungsgrund` (App validiert die Auswahl).
- `saisonpause` wird nicht entfernt (nur als „nicht aktiv" behandelt).

## Tests & Verifikation

- **Unit-Tests** für `istMeinKundeVorschlag`: nicht-aktiv → false (für inaktiv/saisonpause/
  geschlossen); aktiv + Konventionell → true; aktiv + Orion → true; aktiv + nur David/Higenie/
  Veranstaltungen → false; aktiv + leere Zapfsysteme → false.
- `flutter analyze` ohne neue Findings; Tests grün.
- **Visueller Browser-Test** (Pflicht): Status-Wechsel im Formular schaltet „mein Kunde" korrekt
  (aktiv+Konv → an; auf inaktiv → aus; zurück auf aktiv → an); manueller Override bleibt beim
  Speichern erhalten; Schliessungsgrund/-datum erscheinen nur bei `geschlossen` und im Detail; Liste
  zeigt default nur aktive; Karte blendet nicht-aktive aus, Filter-Schalter zeigt sie.
- **DB-Backfill** nach Migration verifizieren: keine `status <> 'aktiv'`-Zeile mehr mit
  `ist_mein_kunde = true`.

## Deploy

Ein Paket **v0.26.0** nach Deploy-Workflow (CLAUDE.md). Migration (2 Spalten + Backfill-UPDATE) via
`apply_migration`; Migrationsdatei in `Datenbank/migrations/127_betrieb_lifecycle.sql` ablegen.
