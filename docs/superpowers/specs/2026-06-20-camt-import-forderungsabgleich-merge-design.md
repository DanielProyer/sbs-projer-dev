# Bankauszug-Import + Forderungs-Abgleich zusammenführen — Design

**Datum:** 2026-06-20
**Kontext:** Heute gibt es zwei parallele camt-Wege: den transaktions-getriebenen **Bankauszug-Import** (Klassifizierer → Auto-Buchung/Regeln → Prüfliste; Stichtag-gebunden) und den forderungs-getriebenen **Forderungs-Abgleich** (Pull, ignoriert Stichtag, nur Kundenzahlungen, mit besserer Matching-/UX-Qualität). Die Buchhaltung ist bis **11.03.2026** vollständig (Bankbewegungen + Forderungsabgleich aus Excel). Ab 12.03.2026 soll **ein** Weg genügen: der Bankauszug-Import — angereichert um die guten Teile des Forderungs-Abgleichs.

## Ziel

Den Bankauszug-Import so umbauen, dass er für **Kundenzahlungen** die volle Forderungs-Abgleich-Qualität bietet (Zahlername aus `additionalInfo`, gruppierte Vorschau, geführte Zuordnung), während die bestehende Pipeline für **Ausgaben/Heineken/Bargeld** erhalten bleibt. Danach genügt der Import; der separate Abgleich-Screen bleibt vorerst als Fallback.

## Ist-Stand (verifiziert)

- DB: 3'425 Kundenrechnungen `bezahlt` (letzte Zahlung **2026-03-11** → 11.03-Schnitt sauber abgebildet), **1'523 `offen`** (CHF 157'452.91, Rechnungsdatum 2019–2026-06-12) + 11 `gesendet`.
- Stichtag wird nur an **einer** Stelle als Tor genutzt (`camt_auto_booker.dart:39`) + auf dem Bestätigungs-Screen angezeigt.
- Import matcht Zahler über **rohes `tx.partyName`** (`camt_auto_booker.dart:48`) — **nicht** über `effektiverZahlername`. Bei der GKB steht der Name im `additionalInfo` → Import würde fast alle Kundenzahlungen in die Prüfliste schieben.
- Prüfliste kann unklare Kundenzahlungen nur „erledigt/ignoriert" — kein geführter Zuordnen-Dialog.
- Beide Wege teilen den Idempotenz-Guard in `ZahlungsdifferenzService.verbuchenSammel` → keine Doppelbuchung.

## Architektur

Nach dem Upload wird der Import in **zwei Bereiche** geteilt (alle Transaktionen weiterhin nur **ab Stichtag**):

### Bereich 1 — Kundenzahlungen (eingebetteter Forderungs-Abgleich)
- Eingang: alle **Gutschriften** der Datei, die **keine Heineken-Zahlung** sind (Klassifizierer-Entscheid; Geldautomaten-/Post-/Schaltereinzahlungen ohne Namen gehören dazu — sie landen dann in ⚪).
- Verarbeitung: bestehender `ForderungsAbgleichService.abgleich(...)` — nutzt bereits `effektiverZahlername` + Subset-Summen-Matching. Damit ist die Matching-Lücke des Imports automatisch geschlossen (Kundenzahlungen laufen über den Abgleich-Service statt über `CamtBetriebMatcher(tx.partyName)`).
- UI: die **🟢/🟡/🔴/⚪-Vorschau** + geführte Zuordnen-Dialoge (Datum—Betrag, 5-Rappen 3805/8000, Schalter-Info, Suche) — die responsiven Komponenten aus dem Abgleich-Screen werden wiederverwendet (`AutoMatchTile`, Gruppen-Karten, Dialoge).
- Buchung: **Vorschau + Bestätigen** statt stillem Auto-Buchen. „Alle verbuchen" bleibt für die eindeutigen 🟢-Treffer.

### Bereich 2 — Übriges (bestehende Pipeline, unverändert)
- Eingang: alle **Belastungen** (Ausgaben), **Heineken**-Transaktionen, sowie alles, was der Klassifizierer nicht als Kundenzahlung führt.
- Verarbeitung: bestehender `CamtAutoBooker`-Pfad ohne den Kundenzahlungs-Teil → Klassifizierer → Regeln/Auto-Buchung → **Prüfliste**.
- UI: wie bisher (Zähler „gebucht/Prüfliste/übersprungen" + Prüflisten-Screen).

### Querschnitt
- **Stichtag** `CamtStichtag.stichtag` → **2026-03-11** (gilt für beide Bereiche; im Import-Kontext bekommt der Abgleich-Service nur Post-Stichtag-Gutschriften, womit die frühere „Abgleich ignoriert Stichtag"-Inkonsistenz im Import entfällt).
- **Archivierung** der Datei in `camt_dateien` (aus dem Abgleich übernehmen) — inkl. Doppel-Upload-Dialog.
- **Dedup** des Imports (`txKey`/`bereitsVerarbeitet`) bleibt für Bereich 2; für Bereich 1 schützt der Idempotenz-Guard.
- **Forderungs-Abgleich-Screen bleibt** vorerst bestehen (Route/Kachel) als Fallback für den Altbestand.

## Komponenten-Wiederverwendung

Die UI-Bausteine des Abgleich-Screens werden so extrahiert/geteilt, dass Import und Standalone-Abgleich sie gemeinsam nutzen:
- `AutoMatchTile` (bereits eigenes Widget).
- Gruppen-Karte (`_GruppeCard`), KPI-Kachel (`_Kpi`), die Zuordnen-Dialoge (`_oeffneManuell`, `_ordneZu`) und die Zahlungs-Info-Helfer → in wiederverwendbare Widgets/Helfer auslagern (z.B. `widgets/abgleich_*`), damit beide Screens dieselbe Logik teilen (DRY).

## Tests

- `CamtStichtag` neuer Wert (Unit-Test anpassen: `camt_stichtag_test.dart`, `camt_parser_test.dart`).
- Routing-Logik „welche Transaktion → Bereich 1 vs 2" als reine, testbare Funktion (Gutschrift-nicht-Heineken → Abgleich; Rest → Auto-Booker).
- Bestehende Abgleich-Service-Tests bleiben grün (Service unverändert).
- Widget-Tests der wiederverwendeten Komponenten bleiben grün.

## Offene Punkte / Risiken

- **Daten-Auffälligkeit:** bei `offen` existiert ein `zahlung_eingegangen_am = 2026-05-17` — vor dem Umbau prüfen (evtl. Altlast/Teilzahlung), damit der Offen-Bestand stimmt.
- **Klassifizierer-Routing:** exakt bestimmen, welche `TxKategorie` als „Kundenzahlung" in Bereich 1 fällt und ob Heineken-Gutschriften separat bleiben (im Plan gegen `camt_klassifizierer.dart` verifizieren).
- **Volumen:** 1'523 offene Forderungen — der 50-Zeilen-Deckel + zugeklapptes 🔴 bleiben.
- **Performance:** `RechnungRepository.getAll()` paginiert (vorhanden).

## Nicht im Scope

- Komplett vereinheitlichte 🟢🟡🔴-Ansicht auch für Ausgaben/Heineken (passt nicht ins Forderungs-Matching).
- Entfernen des Standalone-Abgleich-Screens (separater späterer Schritt, sobald der Import nachgezogen ist).
- QR-Referenz-Matching und Zahler→Betrieb-Lernen (eigene, bereits in `ToDo.md` geplante Folge-TPs).
