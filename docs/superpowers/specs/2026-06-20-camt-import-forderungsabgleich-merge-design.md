# Bankauszug-Import + Forderungs-Abgleich zusammenführen — Design

**Datum:** 2026-06-20
**Kontext:** Heute gibt es zwei parallele camt-Wege: den transaktions-getriebenen **Bankauszug-Import** (Klassifizierer → Regeln/Auto-Buchung → Prüfliste; Stichtag-gebunden) und den forderungs-getriebenen **Forderungs-Abgleich** (Pull, nur Kundenzahlungen, bessere Matching-/UX-Qualität). Die Buchhaltung ist bis **11.03.2026** vollständig (Bankbewegungen + Forderungsabgleich aus Excel). Ab 12.03.2026 soll **ein** Weg genügen: der Bankauszug-Import — angereichert um die guten Teile des Forderungs-Abgleichs sowie um deterministisches **QR-Referenz-Matching** und lernendes **Zahler→Betrieb-Matching**.

## Ziel

Den Bankauszug-Import so umbauen, dass er für **Kundenzahlungen** die volle Forderungs-Abgleich-Qualität bietet (Zahlername aus `additionalInfo`, gruppierte Vorschau, geführte Zuordnung) und beim Matching **deterministisch zuerst** über QR-Referenz und gelernte Zahler-Aliase geht — während die bestehende, regelbasierte Pipeline für **Ausgaben/Heineken/Bargeld** erhalten bleibt. Der separate Abgleich-Screen bleibt vorerst als Fallback.

## Ist-Stand (verifiziert)

- DB: 3'425 Kundenrechnungen `bezahlt` (letzte Zahlung **2026-03-11** → 11.03-Schnitt sauber abgebildet), **1'523 `offen`** (CHF 157'452.91) + 11 `gesendet`.
- Stichtag wird nur an **einer** Stelle als Tor genutzt (`camt_auto_booker.dart:39`) + auf dem Bestätigungs-Screen angezeigt.
- Import matcht Zahler über **rohes `tx.partyName`** (`camt_auto_booker.dart:48`) — **nicht** über `effektiverZahlername`. Bereich 2 nutzt für Ausgaben/Bargeld bereits den `RegelMatcher` (`camt_regel`-Regeln).
- **0 von 2'623** historischen Gutschriften haben eine strukturierte Referenz → QR-Matching wirkt erst für künftige QR-Rechnungen.
- Beide Wege teilen den Idempotenz-Guard in `ZahlungsdifferenzService.verbuchenSammel` → keine Doppelbuchung.

## Architektur (Ziel-Zustand)

Nach dem Upload wird der Import in **zwei Bereiche** geteilt (alle Transaktionen weiterhin nur **ab Stichtag**):

### Bereich 1 — Kundenzahlungen (eingebetteter Forderungs-Abgleich)
- Eingang: **ausschließlich** Gutschriften mit `TxKategorie.kundenzahlung` (echte Kundenzahlungen). Geldautomaten-/Post-/Schaltereinzahlungen (Bargeld) und Heineken gehören **nicht** hierher.
- Verarbeitung: `ForderungsAbgleichService.abgleich(...)` mit erweiterter Matching-Reihenfolge (siehe unten).
- UI: **🟢/🟡/🔴/⚪-Vorschau** + geführte Zuordnen-Dialoge (Datum—Betrag, 5-Rappen 3805/8000, Such-/Zahler-Info) — responsive Komponenten aus dem Abgleich-Screen wiederverwendet.
- Buchung: **Vorschau + Bestätigen** statt stillem Auto-Buchen. „Alle verbuchen" für die eindeutigen 🟢-Treffer.

### Bereich 2 — Übriges (bestehende regelbasierte Pipeline)
- Eingang: Belastungen (Ausgaben), Heineken-Transaktionen, Bargeld/Geldautomaten/Post-Einzahlungen, Unbekannt.
- Verarbeitung: Klassifizierer → **`RegelMatcher` (camt-Regeln)** → Auto-Buchung; Rest → **Prüfliste**. Unverändert.
- UI: Zähler „gebucht/Prüfliste/übersprungen" + Prüflisten-Screen.

### Matching-Reihenfolge in Bereich 1 (neu)
Pro Kundenzahlung-Gutschrift, deterministisch zuerst, dann unscharf:
1. **QR-/strukturierte Referenz** (`CamtTransaction.strukturierteReferenz` → `rechnungen.qr_referenz`) — exakter, eindeutiger Treffer → 🟢.
2. **Gelernter Zahler-Alias** (`effektiverZahlername` → Betrieb, dessen `zahler_aliase` den normalisierten Namen enthält) → Betrieb fix, dann Subset-Summe der offenen Forderungen.
3. **Unscharf** (`effektiverZahlername` → `CamtBetriebMatcher` + `RechnungMatcher`) — wie bisher.
Mehrdeutig/kein Treffer → 🟡 manuell bzw. 🔴/⚪.

### Querschnitt
- **Stichtag** `CamtStichtag.stichtag` → **2026-03-11** (gilt für beide Bereiche).
- **Archivierung** der Datei in `camt_dateien` (aus dem Abgleich übernehmen) inkl. Doppel-Upload-Dialog.
- **Dedup** des Imports (`txKey`/`bereitsVerarbeitet`) bleibt für Bereich 2; für Bereich 1 schützt der Idempotenz-Guard.
- **Forderungs-Abgleich-Screen bleibt** vorerst (Route/Kachel) als Fallback.
- Abgleich-UI-Bausteine (`AutoMatchTile`, Gruppen-Karte, KPI, Zuordnen-Dialoge, Zahlungs-Info-Helfer) werden in **gemeinsame Widgets** ausgelagert (DRY), von Import + Standalone genutzt.

## Zahler→Betrieb-Lernen (Alias)
**Entscheidung 25.06.2026 (Daniel):** Aliase werden **direkt am Betrieb** gespeichert, nicht in einer separaten Tabelle. Begründung: der Zahlername ist eine Eigenschaft des Betriebs („dieser Betrieb zahlt unter diesem Namen"), wird im Betrieb-Detail gepflegt (kein Extra-Verwaltungs-Screen), kommt beim Abgleich gratis mit (alle Betriebe werden ohnehin geladen) und ist kein neuer gesyncter Entity-Typ (passt zu Isar↔Supabase offline-first).

- Neues Feld **`betriebe.zahler_aliase` (`text[]`, default `'{}'`)** + Isar `List<String>` im Local-Model. Inhalt: normalisierte Zahlernamen.
- **Normalisierung:** `zahlernameNorm(s)` = trim, lowercase, Mehrfach-Whitespace → einfach (reine, testbare Funktion; identisch in Lernen + Anwenden).
- **Lernen:** bei jeder manuellen Zuordnung wird `zahlernameNorm(effektiverZahlername(gutschrift))` zur `zahler_aliase`-Liste des gewählten Betriebs ergänzt — nur bei **eindeutigem** Betrieb (bei mehreren Betrieben nichts lernen), nur wenn noch nicht vorhanden. **Konflikt-Check:** ist der Name bereits bei einem **anderen** Betrieb gelernt, nicht still doppelt speichern — Hinweis an Daniel (der bestehende Eintrag bleibt, Mehrdeutigkeit fällt beim Matching ohnehin auf 🟡 zurück).
- **Anwenden:** Stufe 2 der Matching-Reihenfolge — `zahlernameNorm(effektiverZahlername)` gegen die `zahler_aliase` **aller** Betriebe (in-memory, exakt). Genau **ein** Betrieb mit Treffer → fix; null oder mehrere → weiter zu Stufe 3.
- **Verwalten:** im **Betrieb-Detail/-Form** wird die Alias-Liste angezeigt; Daniel kann Einträge hinzufügen/bearbeiten/löschen (falsche Lernung direkt dort korrigierbar). Kein separater Alias-Screen.

## QR-Referenz (deterministisch, für künftige Rechnungen)
- Neues Feld `rechnungen.qr_referenz` (text, unique pro user).
- **Vergabe bei Rechnungserstellung:** eindeutige QR-Referenz (27-stellig, Modulo-10 rekursiv) generieren, in `qr_referenz` speichern **und** in den QR-Code/das Rechnungs-PDF einbetten (bestehende QR-/IBAN-Generierung erweitern).
- **Anwenden:** Stufe 1 der Matching-Reihenfolge (`strukturierteReferenz` normalisiert vergleichen).
- Wirkt nur für ab jetzt erstellte QR-Rechnungen; Altbestand unberührt.

## Zerlegung in Teilprojekte (Reihenfolge)

Jedes TP liefert für sich lauffähige, getestete Software:

- **TP-A — Import-Merge + Stichtag** (Kern): Stichtag 11.03; Bereich-1/2-Aufteilung; Abgleich-UI-Bausteine extrahieren + im Import einbetten; Archivierung; Vorschau+Bestätigen. Matching bleibt vorerst Stufe 3 (unscharf, wie heute, aber mit `effektiverZahlername`).
- **TP-B — Zahler→Betrieb-Lernen:** Feld `betriebe.zahler_aliase`; Lernen bei manueller Zuordnung (eindeutiger Betrieb, Konflikt-Check); Anwenden als Matching-Stufe 2; Pflege im Betrieb-Detail.
- **TP-C — QR-Referenz:** `qr_referenz`-Feld; Vergabe + Einbettung bei Rechnungserstellung; Referenz-First als Matching-Stufe 1.

Die Matching-Reihenfolge wird in TP-A als erweiterbare Kette angelegt (Stufen 1/2 als spätere Einschübe vorgesehen), damit TP-B/C ohne Umbau andocken.

## Tests
- `CamtStichtag` neuer Wert (`camt_stichtag_test.dart`, `camt_parser_test.dart` anpassen).
- Routing „Transaktion → Bereich 1 vs 2" als reine, testbare Funktion.
- Matching-Reihenfolge als reine Funktion testbar (Referenz vor Alias vor Unscharf).
- Alias-Lernen/-Anwenden Unit-getestet; QR-Referenz-Generator (Modulo-10) Unit-getestet.
- Bestehende Abgleich-Service- und Widget-Tests bleiben grün.

## Offene Punkte / Risiken
- **Daten-Auffälligkeit:** offene Rechnung mit `zahlung_eingegangen_am = 2026-05-17` — vor TP-A prüfen.
- **Klassifizierer-Routing:** in TP-A gegen `camt_klassifizierer.dart` verifizieren, welche `TxKategorie` als Kundenzahlung in Bereich 1 fällt; Heineken-Gutschriften bleiben in Bereich 2/Heineken-Pfad.
- **QR-Einbettung:** Swiss-QR-Referenz korrekt in bestehendes QR-/PDF-Layout integrieren (QR-IBAN-Voraussetzungen prüfen).
- **Volumen:** 1'523 offene Forderungen — 50-Zeilen-Deckel + zugeklapptes 🔴 bleiben.

## Nicht im Scope
- Vereinheitlichte 🟢🟡🔴-Ansicht auch für Ausgaben/Heineken.
- Entfernen des Standalone-Abgleich-Screens (späterer Schritt).
