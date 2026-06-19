# Forderungen-Historie: Reinigungen + Protokolle + Forderungen importieren — Design

**Datum:** 2026-06-19 · **Status:** Spec zur Freigabe durch Daniel

---

## 0. Gesamt-Fahrplan (3 Teilprojekte)
1. **Historischer Import** (diese Spec): alle Reinigungen 2019–Nov 2025 + Protokoll-Scans + die echten Forderungen (offen/bezahlt/abgeschrieben) aus dem Excel in die App — vollautomatisch, **ohne neue Buchungen**.
2. **camt-Abgleich-Engine**: Kundenzahlung → Betrieb → Auto-Match per Betrags-Subset über offene Forderungen + manuelle Sammelzahlungs-Allokation + Prüfliste.
3. **Hub / Mahnwesen / Debitoren** auf den echten Daten (grossteils bestehend).

Diese Spec deckt **Teilprojekt 1**. Es ist ein ETL-/Daten-Vorhaben (kein UI-Feature) — die App liest danach die Daten mit ihren bestehenden Screens.

---

## 1. Ziel
Lückenlose Erfassung aller Reinigungen + Forderungen seit Geschäftsaufnahme (2019), damit Forderungen-Hub, Mahnwesen und Debitoren auf echten Einzelposten statt nur dem 1100-Aggregat arbeiten.

---

## 2. Ausgangslage (verifiziert)
- **App** `reinigungen` (767) und `kundenrechnungen` (521) starten erst **ab Dez 2025**. Die Historie 2019–Nov 2025 lebt nur im Excel `00_Buchhaltung/00_SBS_Projer_70.xlsm`.
- **Excel-Sheet „Reinigung"** (9'975 Zeilen, 2019–Nov 2025): pro Reinigung u. a. `ID Reinigung` (A), `ID Anlage` (C), `Datum` (D), `Betrieb` (E), `Ort` (F), `Bergkunde` (G), `Beleg` (I), `Rechnungsart` (J), `Einzahlungsdatum` (K), `Einzahlungsbeleg` (L), `Serviceart` (M), `Dauer` (P), `Total mit MwSt` (T), `Total ohne MwSt` (U), `Bemerkung` (S).
- **Rechnungsart-Verteilung:** Rechnung Tresen 3'601 · Bar 2'713 · Zusätzliche Anlage 1'666 · Rechnung Mail 1'077 · Gratis 436 · Rechnung Post 270 · Heineken 212. → **Forderung** entsteht nur bei **Mail/Post/Tresen**.
- **Deterministischer Datei-Schlüssel:** `Beleg` (Spalte I, z. B. `011_2019_05_01_0025_00019925`) = Dateiname im Ordner `20_Buchaltung/01_Belege/010_Reinigung` (8'197 PDFs). `Einzahlungsbeleg` (Spalte L, `020_…`) = Dateiname in `20_Buchaltung/01_Belege/020_Zahlungseingang_Reinigung` (3'305 PDFs). Kern-Schlüssel `<Datum>_<AnlageID>_<Betrag>` ist eindeutig. `Einzahlungsbeleg = ABSCHREIBUNG` → abgeschrieben.
- **Buchungen 2019–Nov 2025 sind bereits importiert** (Journal-Import Phase 1). → Der Forderungs-Import ist eine **Detail-Schicht über dem bereits korrekten 1100-Debitoren-Saldo** und erzeugt **KEINE neuen Buchungen** (sonst Doppelzählung).
- 292 Betriebe in der App; Betrieb-Zuordnung über Namen (bestehende `CamtBetriebMatcher`-Logik nutzbar).

---

## 3. Leitprinzipien
1. **Nichts manuell** — alle Daten sind strukturiert (Excel) + deterministisch benannt (Scans). Vollautomatischer ETL- + Upload-Lauf.
2. **Keine Buchungen** — reiner Direkt-Insert in `reinigungen`/`rechnungen`/Storage; keine App-Services (kein Auto-Booking, kein Raster).
3. **Reversibel** — alles über `quelle='excel_import'` markiert und per `DELETE` rückrollbar.
4. **Treue-Gate** — Mengen/Summen gegen Excel + offene Forderungen ≈ historischer Anteil des 1100-Saldos; unmatched Betriebe/Anlagen gelistet.

---

## 4. Datenmodell (Schema-Erweiterungen, additiv)
### 4.1 `reinigungen`
Neue Spalten: `quelle text` ('excel_import' für importierte), `extern_id text` (Excel `ID Reinigung`, eindeutiger Import-Schlüssel + Idempotenz).
Befüllung pro Excel-Zeile: user_id (Daniel), betrieb_id (Name→Match), anlage_id (best effort über `ID Anlage`), datum, service_typ='reinigung', service_art (Excel Serviceart), dauer_minuten (Excel Dauer), ist_bergkunde, preis_netto (Total ohne MwSt), preis_mwst (Differenz), preis_brutto (Total mit MwSt), mwst_satz (datumsabhängig aus `mwst_satz`), status='abgeschlossen', abgerechnet=true bei Rechnungs-/Bar-Arten, notizen (Bemerkung), protokoll_foto_pfad (Pfad des hochgeladenen 010-Scans), quelle, extern_id. Digitale Checklisten-Felder bleiben null/Default (der Scan ist der Nachweis).

### 4.2 `rechnungen` (nur Forderungen Mail/Post/Tresen)
Neue Spalten: `quelle text` ('excel_import'), `extern_beleg text` (Excel `Beleg`), `einzahlungsbeleg text` (Excel `Einzahlungsbeleg` — **Anker für Teilprojekt 2**).
Befüllung pro berechneter Reinigung: rechnungstyp='kundenrechnung', betrieb_id, rechnungsdatum (Reinigungsdatum), faelligkeitsdatum (+30 T), betrag_netto/mwst/brutto (aus Reinigung), versandart (Mail/Post/Tresen), rechnungsnummer (aus Beleg abgeleitet), **zahlungsstatus**: `bezahlt` (Einzahlungsdatum gesetzt) · `abgeschrieben` (Einzahlungsbeleg='ABSCHREIBUNG') · sonst `offen`; zahlung_eingegangen_am (Einzahlungsdatum); pdf_url (Pfad des 010-Scans), quelle, extern_beleg, einzahlungsbeleg.
**Verknüpfung Rechnung↔Reinigung:** ein `rechnungs_positionen`-Eintrag (service_typ='reinigung', service_id = importierte reinigung.id) — konsistent mit dem laufenden Modell, damit der Forderungen-Hub greift.

### 4.3 Zahlungs-Scan (020)
Der `020`-Scan ist der **Zahlungsbeleg**; sein Pfad wird auf der Rechnung hinterlegt (z. B. `notizen` oder Feld `zahlung_beleg_pfad` — Detail im Plan). Nicht zwingend, aber wertvoll als Nachweis + Teilprojekt-2-Validierung.

### 4.4 Betrieb-Zuordnung & fehlende (geschlossene) Betriebe
Manche Reinigungen betreffen Betriebe, die nicht (mehr) in der App sind (geschlossen / Anlage demontiert). Mehrstufige Zuordnung pro Excel-Name:
1. **Exakter** Name-Match → bestehender Betrieb.
2. **Fuzzy** (bestehende `CamtBetriebMatcher`-Logik: Contains / Wort-Overlap).
3. **Alias-Tabelle** (`Datenbank/import/betrieb_aliase.csv`, `excel_name → betrieb_id`) für Schreibvarianten — verhindert Dubletten zu noch existierenden Betrieben.
4. **Rest = wirklich ehemalige Kunden** → **automatisch als inaktiver Betrieb anlegen**: `name`+`ort` aus Excel, `inaktiv_seit` = Datum der letzten Reinigung dieses Betriebs, `inaktiv_grund='Import Historie 2019–2025 (geschlossen/Anlage demontiert)'`, `status` = inaktiv-Wert (bestehende Werte prüfen), `quelle='excel_import'`. Reinigung + Forderung hängen an diesem Betrieb → Forderungs-Historie **pro Kunde** erhalten.

So bleiben Debitoren/Abschreibung pro (auch ehemaligem) Kunden auswertbar; die inaktiven Betriebe werden in den aktiven Listen/Tourenplanung über `inaktiv_seit`/`status` herausgefiltert. Der Import erzeugt eine **Review-Liste**: „neu inaktiv angelegt" + „unsicher gematcht (Score)" zur einmaligen Durchsicht (Korrektur via Alias-Tabelle, Re-Run reversibel).

---

## 5. Pipeline (wie der bewährte Journal-Import)
1. **ETL (Python, `Datenbank/import/`):** Excel „Reinigung" lesen → Betrieb-/Anlage-Mapping (Name; Liste der unmatched) → Reinigungs-Zeilen + (für Mail/Post/Tresen) Rechnungs-/Positions-Zeilen generieren → Batch-SQL. Status-/Betrags-/MwSt-Ableitung wie oben. Naht: nur `datum < 2025-12-01` (App übernimmt ab Dez 2025).
2. **Einspielen:** via `npx supabase db query --linked -f <datei>` (Management API, wie beim Journal).
3. **Scan-Upload:** Skript lädt **alle** 8'197 `010`-PDFs + 3'305 `020`-PDFs in den Supabase-Storage (Bucket-Wahl im Plan, z. B. `reinigung-belege`) und schreibt die Pfade in `reinigungen.protokoll_foto_pfad` bzw. auf die Rechnung. Match über den Datei-Schlüssel.
4. **Treue-Gate (`validate_import.py`):** Anzahl Reinigungen = Excel; Anzahl/Summe Rechnungen je Status = Excel; **offene Forderungen ≈ historischer 1100-Detailsaldo**; Liste unmatched Betriebe/Anlagen + Scans ohne Reinigung.

---

## 6. „App läuft gleich" / Sicherheit
- Keine Buchungen, kein Auto-Booking; 1100-Saldo unverändert (nur als Detail untermauert).
- App-Daten ab Dez 2025 unberührt (Naht 30.11.2025).
- Vollständig reversibel (`DELETE FROM rechnungen/reinigungen WHERE quelle='excel_import'` + Storage-Cleanup).

---

## 7. Erfolgskriterien
- Alle ~9'975 Reinigungen 2019–Nov 2025 in der App, jede mit Protokoll-Scan.
- Forderungen (Mail/Post/Tresen) als `kundenrechnung` mit korrektem Status; offene Posten im Forderungen-Hub/Debitoren sichtbar; offene Summe stimmt mit dem 1100-Anteil überein.
- Unmatched-Liste klein/nachpflegbar; Import reversibel.

---

## 8. Nicht im Scope (Folge-Teilprojekte)
- **Teilprojekt 2:** camt-Auto-Match (Subset-Summe) + manuelle Sammelzahlungs-Allokation + Prüfliste.
- **Teilprojekt 3:** Anpassungen Hub/Mahnwesen/Debitoren (grösstenteils bestehend).
- Bargeld-/Gratis-/Heineken-Reinigungen erzeugen **keine** Forderung (werden als Reinigung importiert, ohne `rechnung`).

---

## 9. Offene Implementierungs-Details (im Plan zu klären, nicht Design-blockierend)
- Betrieb-Matching-Schwellen (Fuzzy-Score) + Format der `betrieb_aliase.csv`; konkrete `status`-/inaktiv-Werte beim Auto-Anlegen (siehe 4.4).
- Anlage-Zuordnung (`ID Anlage` → app anlage_id) — best effort; Forderung braucht nur betrieb_id.
- Exakte Status-Enum-Werte für `reinigungen.status` (vorhandene Werte prüfen).
- Storage-Bucket + Pfadschema für die Scans; Upload-Drosselung.
- Rechnungsnummer-Schema für historische Rechnungen (aus Beleg ableiten, kollisionsfrei).
