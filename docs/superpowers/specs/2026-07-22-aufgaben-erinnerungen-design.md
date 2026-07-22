# Aufgaben-Erinnerungen (Dashboard + Glocke) — Design

**Datum:** 22.07.2026 · **Status:** von Daniel freigegeben (Chat 22.07.)

## Ziel

Wiederkehrende Pflichten (Heineken-Monatsrechnung, MWST-Abrechnung, Mahnläufe,
Saisondaten-Pflege) und frei erfasste Aufgaben erscheinen in der App als
Erinnerung und bleiben sichtbar, **bis sie erledigt sind**. Anzeige beim
App-Öffnen (Flutter Web, kein Push — GitHub Pages ohne Service Worker).

## Entscheidungen (Daniel, 22.07.2026)

| Frage | Entscheid |
|---|---|
| Automatische Quellen | Heineken-Monatsrechnung, MWST, Mahnwesen, Saisondaten (alle 4) |
| Termine | bleiben beim Google-Kalender (kein App-Doppel); zusätzlich freie eigene Aufgaben erfassbar |
| Darstellung | Dashboard-Karte zuoberst UND Glocke mit Zähler global auf jeder Seite |
| Snooze | Ja: 1/3/7 Tage; gesnoozte zählen nicht im Badge, kommen automatisch wieder |
| Architektur | Ansatz A: Detektoren client-seitig, Tabelle nur für Marker/Snooze/eigene Aufgaben |

## Architektur

### 1. Detektoren (reine Dart-Funktionen, kein Persistenz-Bedarf)

Jeder Detektor liefert 0..n `Aufgabe`-Objekte aus vorhandenen Daten; jede
Aufgabe hat einen **deterministischen Schlüssel** (`key`), über den Snooze und
manuelle Erledigung zugeordnet werden. Modul
`lib/core/util/aufgaben_regeln.dart` (TDD), pro Regel eine Funktion mit
injizierbarem `heute`.

**a) Heineken-Monatsrechnung** — key `heineken:<jahr>-<monat>` (Vormonat):
- Sichtbar ab dem 1. des Folgemonats.
- Stufe 1 «Heineken-Monatsrechnung <Monat> erstellen», solange KEINE Rechnung
  `rechnungstyp='heineken_monat'` mit Spalte `heineken_monat` = 1. des
  Vormonats existiert (so schreibt `erstelleMonatsrechnung` sie, verifiziert).
- Stufe 2 «… versenden», wenn die Rechnung existiert, aber
  `zahlungsstatus='offen'` (Workflow offen→gesendet→freigegeben→bezahlt).
- Erledigt (verschwindet automatisch): Rechnung existiert und Status ≠ offen.
- Fällig-Färbung: bis zum 10. des Folgemonats orange, danach rot.
- Daten: gezielte Supabase-Query (Web-Pfad) auf `rechnungen`
  (rechnungstyp, Monat) — kein neues Vertical.

**b) MWST-Abrechnung** — key `mwst:<jahr>-Q<quartal>`:
- Sichtbar ab Quartalsende für das abgelaufene Quartal.
- Abgabefristen wie im MWST-Screen: Q1→31.05., Q2→31.08., Q3→30.11.,
  Q4→28.02. des Folgejahres. Orange bis 14 Tage vor Frist, danach rot
  (auch nach Fristablauf rot, bleibt sichtbar).
- Erledigt: NUR manueller Marker (die App sieht die ESTV-Einreichung nicht) —
  Haken im Aufgaben-Sheet ODER Button «Als abgerechnet markieren» im
  MWST-Screen (schreibt denselben Marker `mwst:<jahr>-Q<x>`).

**c) Mahnwesen** — key konstant `mahnlauf` (anzahl-unabhängig):
- Nutzt EXAKT `ForderungService.istMahnfaellig` (bestehende Schwellen:
  offen ≥ 5 Tage über Fälligkeit → Erinnerung; erinnert ≥ 25 Tage →
  Mahnung 1; Mahnung 1 ≥ 30 Tage → Mahnung 2; Mahnung 2 → Eskalation;
  heineken_monat ausgenommen).
- Aufgabe «Mahnlauf: X Rechnungen fällig» solange X > 0; Zähler live.
- Erledigt automatisch, sobald X = 0 (gemahnt/bezahlt/abgeschrieben).
- Immer orange (Dauerthema, kein hartes Fristdatum).

**d) Saisondaten** — key `saisondaten` (konstant):
- Übernimmt `saisonAnkerFehltProvider` (bestehende Tourenplan-Warnleiste):
  «Saisondaten fehlen bei X Betrieben». Erledigt automatisch bei X = 0.
- Immer orange. Die Warnleiste im Tourenplan bleibt unverändert bestehen.

### 2. Tabelle `aufgaben` (Migration 150, Supabase only, kein Isar)

```sql
CREATE TABLE aufgaben (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  typ text NOT NULL CHECK (typ IN ('eigene','marker','snooze')),
  key text,                    -- Detektor-Schlüssel (marker/snooze); NULL bei eigene
  titel text,                  -- nur eigene
  faellig_am date,             -- nur eigene (optional)
  snooze_bis date,             -- nur snooze
  erledigt_am timestamptz,     -- eigene: Abhaken; marker: Zeitpunkt der Markierung
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- RLS wie üblich (user_id = auth.uid() für alle Operationen), Trigger updated_at.
-- UNIQUE (user_id, typ, key) für marker/snooze (Upsert-Ziel); eigene ohne key.
```

- **marker**: erledigt einen Detektor-Key dauerhaft (nur von MWST genutzt).
- **snooze**: `snooze_bis` pro Key; Upsert bei erneutem Snooze; abgelaufene
  Snoozes werden ignoriert (kein Aufräumen nötig).
- **eigene**: freie Aufgabe; offen = `erledigt_am IS NULL`.

### 3. Provider & Kombination

`aufgabenProvider` (FutureProvider) lädt die Tabelle + Detektor-Inputs und
liefert die offene Liste: Detektor-Aufgaben minus Marker, minus aktive
Snoozes, plus offene eigene Aufgaben (eigene mit `faellig_am` in der Zukunft
erscheinen erst ab Fälligkeitstag − 7; ohne Datum sofort). Sortierung:
rot → orange → eigene nach Datum. Badge-Zahl = Länge dieser Liste.
Invalidierung nach jeder Aktion im Sheet sowie beim Dashboard-Refresh.

### 4. UI

- **Dashboard-Karte** (zuoberst in `home_screen.dart`): «⚠ X Aufgaben offen»
  mit den ersten 3 Titeln; Tap öffnet das Sheet. Bei 0 Aufgaben unsichtbar.
- **Globale Glocke:** über `MaterialApp.builder` als Overlay auf jeder Seite
  (kleiner runder Button mit Badge-Zahl; unsichtbar bei 0). **Position unten
  links** (Korrektur bei Planerstellung: oben rechts würde AppBar-Actions
  verdecken; unten rechts kollidiert mit FABs; unten links ist einhändig
  erreichbar — Smartphone-first). Unsichtbar, solange kein User eingeloggt.
  Eine Code-Stelle, kein Umbau der einzelnen AppBars. CanvasKit-tauglich
  (GestureDetector + Container, Projekt-Muster).
- **Aufgaben-Sheet** (`showModalBottomSheet`): Liste mit Titel, Fällig-Text,
  Farbe; pro Eintrag: «Dorthin»-Link (heineken → `/heineken/raster` bzw.
  Rechnungen, mwst → MWST-Screen, mahnlauf → Forderungen, saisondaten →
  `/touren`, eigene → kein Link), Snooze-Menü (1/3/7 Tage), Abhaken (nur
  MWST + eigene; die übrigen erledigen sich selbst). «+»-Button für neue
  eigene Aufgabe (Dialog: Titel Pflicht, Datum optional).
- **MWST-Screen:** zusätzlicher Button «Als abgerechnet markieren» beim
  gewählten Quartal (setzt/löscht den Marker, zeigt Zustand).

### 5. Fehlerbehandlung

- Tabelle nicht erreichbar (offline): Glocke/Karte erscheinen nicht
  (kein Fehler-Banner); nächster App-Start lädt frisch.
- Aktionen (Snooze/Abhaken) mit SnackBar-Fehler bei Misserfolg.
- Detektoren dürfen bei Teil-Datenfehlern einzeln ausfallen (try/catch pro
  Regel, debugPrint) — die übrigen Aufgaben erscheinen trotzdem.

### 6. Tests (TDD)

Reine Funktionen mit injiziertem `heute` und In-Memory-Daten:
- Heineken: vor/nach Monatswechsel, Rechnung fehlt/offen/gesendet, Färbung ab 10.
- MWST: Quartalsgrenzen, Fristfärbung (14 Tage vor, nach Frist), Q4-Frist im
  Folgejahr, Marker unterdrückt.
- Mahnlauf/Saisondaten: Zähler > 0/= 0.
- Snooze: aktiv/abgelaufen; eigene: mit/ohne Datum, Vorlauf 7 Tage.
- Badge-Zählung und Sortierung.

## Bewusst NICHT im Umfang (YAGNI)

- Kein Push/keine Benachrichtigungen ausserhalb der App (technisch ohne
  Service Worker nicht möglich; Termine erinnern via Google Kalender).
- Kein Isar-/Offline-Sync für `aufgaben`.
- Keine Wiederholregeln für eigene Aufgaben (einmalig; wiederkehrend sind
  genau die 4 Detektoren).
- Kein Aufgaben-Archiv/Verlauf in der UI (erledigte bleiben nur als Zeilen).
