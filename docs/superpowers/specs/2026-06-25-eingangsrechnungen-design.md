# Eingangspost / Eingangsrechnungen — Design-Spec

**Datum:** 2026-06-25
**Status:** Genehmigt (Entscheidungen unten), Plan TP-0..2 ausformuliert.

## Ziel

Ein Bereich, in dem Daniel geschäftsrelevante Post (PDF-Scans aus der externen App **ClearScanner**) hochlädt. Die App **erkennt automatisch per KI**, ob es eine **Rechnung** ist (und welche genau) oder ein **reines Info-Dokument**. Für Rechnungen entsteht (a) ein **Eintrag im GKB-Zahlungsfile** (pain.001, wird gesammelt ins E-Banking hochgeladen), (b) eine **Kreditoren-Buchung** (Aufwand [+Vorsteuer] an Kreditoren 2000), die später per **camt-Abgleich** abgeschlossen wird (Kreditoren an Bank). Ein **Lernverhalten** (Lieferanten-Regeln) reduziert den manuellen Aufwand über die Zeit. Alle Dateien werden in der App gespeichert.

## Getroffene Entscheidungen (25.06.2026)

1. **Plan-Tiefe:** Spec komplett + TP-0..2 task-by-task; TP-3..7 als Outline (iterativ vertiefen).
2. **Scan-Erfassung:** **extern via ClearScanner → PDF-Upload** in die App (kein App-Kamera-Scanner). Mehrseitige Rechnungen: entweder **mehrere PDFs hochladen → in der App zu einem Dokument zusammenfügen**, ODER ein bereits in ClearScanner zusammengefügtes PDF. **Beide Wege offenhalten.**
3. **Info-Dokumente:** als **Datensatz mit erkannten Metadaten** erfassen (`ist_nur_info=true`) — durchsuchbar/ablegbar, aber **nicht** gebucht/bezahlt.
4. **Buchungs-Modell:** **2-stufig (Kreditor).** Stufe 1 bei Bestätigung: Aufwand (+Vorsteuer 1170/1171) **an Kreditoren 2000**. Stufe 2 via camt: **Kreditoren 2000 an Bank 1020** + bezahlt. Matching-Schlüssel = QR/SCOR-Referenz.
5. **Genehmigungs-Queue:** ja — jede Rechnung muss **bestätigt** werden, bevor sie ins Zahlungsfile geht (verhindert Fehlzahlungen aus KI-Erkennung).
6. **Zahlungsfile-Format:** direkt **`pain.001.001.09.ch.03`** (GKB lehnt `.03` ab 14.11.2026 ab), strukturierte Adressen Pflicht.
7. **Konten:** kein neues Konto nötig — bestehende Excel-Kontologik (29/30 Konten vorhanden; Autoreparatur = **6250**, nicht 6260). Falls beim Echtbetrieb ein Konto fehlt → Migration on demand.
8. **Reversibilität:** Löschen einer camt-Buchung (per `camt_tx_key`) setzt den Kreditor-Status zurück auf offen (analog bestehender camt-Reversibilität).

## Architektur — Datenfluss

```
[Upload]   ClearScanner-PDF(s) → BelegUploadWidget (PDF) → Storage (Bucket buchungs-belege)
   │        (mehrere PDFs optional zu einem Dokument mergen)
[KI]       parse-rechnung (Claude Haiku 4.5, PDF base64)
   │        → RechnungScanResult {aussteller, iban, qr_referenz+typ, betrag_brutto, mwst_satz,
   │           rechnungsnummer, rechnungsdatum, faelligkeit, konfidenz, ist_nur_info, dok_typ}
[Klassif.] KreditorMatcher.matchRegel(aussteller, iban, referenz) → aufwandskonto/geschaeftsfall/mwst
   │        (Info-Doc → nur ablegen)
[Bestätig.] eingangsrechnung_detail: Mensch prüft Konto/Betrag/Referenz/Fälligkeit
   │        status: erkannt → bestätigt
   ├──────────────────────────┐
[Kreditor Stufe 1]            [Zahlungsfile-Vormerkung]
 Aufwand(+VSt) an 2000         status: zahlung_vorgemerkt
 status: gebucht                      │
   │                          [Export] pain.001-Batch (.09.ch.03) → Download → manueller GKB-Upload
   │                           status: exportiert
   │                                  │
[camt-Abschluss] camt.053 → KreditorenAbgleichService → CamtKreditorBooker:
   │   Match via QR/SCOR-Referenz → Kreditoren 2000 an Bank 1020 + camt_tx_key
   │   status: bezahlt
[Lernen]  bestätigte Zuordnung → kreditor_regel (idempotent, Konflikt-Check)
```

## Status-Lebenszyklus (`eingangsrechnung.status`)

`erkannt` → `bestaetigt` → `gebucht` (Stufe-1) → `zahlung_vorgemerkt` → `exportiert` → `bezahlt`
Nebenzweige: `abgelegt` (Info-Doc), `verworfen` (Fehlerkennung/Dublette).
Gebucht + zahlung_vorgemerkt können gleichzeitig gelten (Buchung und Zahlungsvormerkung passieren beide bei Bestätigung) — Modellierung als **eigene Flags** statt strikt linearer Status: `gebucht_am`, `zahlung_vorgemerkt`, `exportiert_am`, `bezahlt_am` zusätzlich zum Hauptstatus.

## Datenmodell (neue Tabellen)

### `eingangsrechnung` (Kopf je Dokument)
```
id uuid PK, user_id uuid,
aussteller_name text,            -- erkannter Lieferant
lieferant_iban text,             -- Zahlungsempfänger-IBAN/QR-IBAN
qr_referenz text, referenz_typ text,   -- 'QRR'|'SCOR'|'NON'
betrag_brutto numeric, mwst_satz numeric, vorsteuer_konto int,
rechnungsnummer text, rechnungsdatum date, faelligkeit date,
aufwandskonto int, geschaeftsfall_id text, mwst_pflichtig bool,
ist_nur_info bool DEFAULT false, dok_typ text,   -- z.B. 'rechnung'|'mahnung'|'info_police'|...
status text DEFAULT 'erkannt',
gebucht_am timestamptz, zahlung_vorgemerkt bool DEFAULT false,
exportiert_am timestamptz, bezahlt_am date,
buchung_stufe1_id uuid, buchung_stufe2_id uuid, camt_tx_key text,
konfidenz numeric, beleg_id uuid,    -- → buchungs_belege (PDF im Storage)
created_at/updated_at
```

### `kreditor_regel` (Lieferanten-Lernen)
```
id uuid PK, user_id uuid,
lieferant_name_pattern text NOT NULL,   -- Substring, case-insensitive
lieferant_iban text,                     -- exakt, nullable
referenz_praefix text,                   -- Multi-Konto-Disambiguierung (z.B. '98', '15 37129')
aufwandskonto int NOT NULL,
geschaeftsfall_id text,                  -- → buchungs_vorlagen (A-* Codes)
vorsteuer_konto int, mwst_satz_percent numeric, mwst_pflichtig bool DEFAULT true,
prioritaet int DEFAULT 0, ist_aktiv bool DEFAULT true,
lernquelle text, gelernt_am timestamptz, created_at/updated_at
```
**Multi-Konto = mehrere Zeilen pro Lieferant**, je `referenz_praefix`.

### `zahlungsfile` (Batch-Tracking, optional in TP-4)
```
id uuid PK, user_id uuid, msg_id text, erstellt_am timestamptz,
anzahl_tx int, ctrl_sum numeric, status text   -- 'erstellt'|'hochgeladen'
```
Zeilen referenzieren `eingangsrechnung.id` (via Spalte `zahlungsfile_id` auf eingangsrechnung).

### Storage
Belege weiter im bestehenden Bucket **`buchungs-belege`** über `BuchungsBelegRepository`; neue `beleg_quelle='eingangsrechnung_scan'`. Pfad `{userId}/{id}/{ts}_{name}`.

## KI-Erkennung — `parse-rechnung` (neue Edge Function)

Eigene Function (parse-beleg bleibt schlank für Spesen). Eingabe: `{ file_base64, media_type }` (PDF → `media_type='application/pdf'`, Claude `type:"document"`; JPG → `type:"image"`). Modell `claude-haiku-4-5-20251001`.

**Output-Schema:**
```json
{
  "ist_rechnung": true,
  "dok_typ": "rechnung",            // rechnung|mahnung|akontorechnung|schlussrechnung|gutschrift|info
  "ist_nur_info": false,
  "aussteller_name": "Heineken Switzerland AG",
  "aussteller_uid": "CHE-488.708.502",
  "empfaenger_iban": "CH34 0868 6001 0857 4700 1",
  "referenz": "415025/000011/ZVHRE/...",
  "referenz_typ": "QRR",            // QRR|SCOR|NON
  "rechnungsnummer": "...",
  "rechnungsdatum": "YYYY-MM-DD",
  "faelligkeit": "YYYY-MM-DD",
  "betrag_zahlbar": 3772.70,        // QR-Betrag/Saldo, NICHT Brutto-Zeile
  "mwst_satz": 8.1,                 // 0 wenn hoheitlich/MwSt-frei
  "mwst_pflichtig": true,
  "konfidenz": 0.93
}
```
Prompt nutzt das in der Memory `rechnungserkennung-historik` dokumentierte Domänenwissen (Schweizer QR/ESR, „zahlbar=Saldo/QR-Betrag nicht Brutto", handschriftlicher Bezahlt-Vermerk = Status, hoheitliche Positionen 0% MwSt, Akonto vs. Schluss). **QR-Code-Auslesen** zusätzlich client- oder serverseitig (Swiss QR Payload → IBAN/Referenz/Betrag deterministisch, ergänzt/korrigiert die KI). QR liefert die Zahldaten **exakt**, die KI die Klassifikation (Konto/Typ).

## Kreditoren-Buchung (Stufe 1)

Bei Bestätigung, datiert auf `rechnungsdatum`:
- **MwSt-pflichtig:** zwei Buchungen (Bruttomethode, Muster aus `spesen_import_service`):
  1. Aufwand (netto) an Kreditoren 2000
  2. Vorsteuer (1170 Material/DL bzw. **1171** übr. Betriebsaufwand) an Kreditoren 2000
  Netto/Vorsteuer aus `betrag_zahlbar` + `mwst_satz` (date-aware via `MwstSatzService`).
- **MwSt-frei (hoheitlich, Behörden):** eine Buchung Aufwand (brutto) an Kreditoren 2000, keine Vorsteuer.
- **Sozialvers./Steuern (Sonderkonten):** statt 2000 ggf. spezifische Verbindlichkeitskonten (2271/2272/2273 SV, 2208 Steuerrückstellung, 2202 MWST) — gesteuert über `geschaeftsfall_id`/`kreditor_regel`.
`camt_tx_key` bleibt zunächst leer; wird in Stufe 2 gesetzt.

## GKB-Zahlungsfile — pain.001.001.09.ch.03

Drei Zahlungstypen, je nach Empfänger-Konto × Referenz:

| Fall | CdtrAcct | Referenz | RmtInf |
|---|---|---|---|
| **A — QRR** | QR-IBAN (IID 30000–31999) | 27-stellig mod10 | `Strd/CdtrRefInf/Tp/CdOrPrtry/Prtry=QRR` + `Ref`; **kein Ustrd** |
| **B — SCOR** | normale IBAN | `RF…` (ISO 11649, mod97) | `…/CdOrPrtry/Cd=SCOR` + `Ref` |
| **C — NON** | normale IBAN | — | `RmtInf/Ustrd` (max 140) |

**Harte Regeln** (sonst GKB-Fehler CH16/17/21): QR-IBAN ⟺ QRR untrennbar; SCOR nie mit QR-IBAN; `Strd` nur 1×.
**Pflichtfelder:** GrpHdr(MsgId, CreDtTm, NbOfTxs, InitgPty/Nm); PmtInf(PmtInfId, PmtMtd=TRF, ReqdExctnDt/Dt, Dbtr/Nm+PstlAdr, DbtrAcct/IBAN); CdtTrfTxInf(EndToEndId, InstdAmt@Ccy, Cdtr/Nm+PstlAdr, CdtrAcct/IBAN, RmtInf). Strukturierte Adressen (min. TwnNm+Ctry) bei Dbtr+Cdtr.
**Dbtr-Stammdaten** (eigene GKB-IBAN, Firmenname/Adresse) → aus `geschaeft_einstellungen`.
**Validierung:** IBAN-Prüfziffer, QR-IBAN-Erkennung (IID 30000–31999), `istGueltigeScor()` (vorhanden), QRR-mod10. Vor Export: pain.001 gegen offizielles XSD prüfbar.

## camt-Abschluss (Stufe 2) — Matching-Kette

In `KreditorenAbgleichService` (eingehender camt-**Ausgang**/DBIT → offener Kreditor), Reihenfolge:
1. **Strukturierte Referenz (SCOR/QRR) exakt** — deterministisch (scorRefNorm/Vergleich).
2. **IBAN + Betrag.**
3. **Name + Betrag.**
4. **Fallback:** `camt_regel` → direkte Ausgabe-Buchung (Aufwand an Bank), wie heute.
Treffer → `CamtKreditorBooker`: Kreditoren 2000 an Bank 1020 (echtes Bankdatum) + `setCamtTxKey` + `eingangsrechnung.status=bezahlt`. Integration als Stufe **vor** dem heutigen Regel-Match in `CamtAutoBooker`.

## Lernen — `KreditorMatcher`

Matching (Scan → Vorbelegung): **IBAN exakt → Referenz-Präfix → Name-Substring (höchste Priorität)**. Lernen idempotent bei Bestätigung: `(lieferant_name + referenz_praefix)` vorhanden → skip/`prioritaet++`, sonst INSERT (`lernquelle='scan'`), mit Konflikt-Check (Muster `entscheideAlias`).

## Seed-Regeln aus den 17 Scan-Kategorien (Bootstrap `kreditor_regel`)

Aus Memory `rechnungserkennung-historik` (Migration seedet diese Regeln; Daniel korrigiert beim ersten Echtbeleg):

| Aussteller / Schlüssel | Aufwandskonto | Vorsteuer | Referenz/IBAN-Hinweis | Sonderfall |
|---|---|---|---|---|
| ESTV (MWST-Abrechnung) | 2202 (kein Kreditor) | — | — | jedes Q = Zahllast an Bund |
| Steuerverw. GR / Bundessteuer | 8900 via 2208 | — | IBAN CH94…0187 9 | prov.→definitiv, Rückerstattung=Eingang an 2208 |
| Ordnungsbussen (Kapo, MWST-Strafe) | 6280 | keine | — | Firma zahlt ALLE Bussen, steuerl. n. abzugsfähig |
| Ausgleichskasse GR (SVA) | 5700 / 2271 | — | Abr. 10.000.969 | Akonto→Schluss; Rückerstattung=Eingang an 5700 |
| SUVA (UVG/NBU) | 5730 / 2273 | — | Kd 1318-17113.7 / 4-00003-10064 | Akonto→Schluss; Guthaben=Eingang an 5730; zahlt pünktlich |
| AXA Stiftung BVG | 5720 / 2272 | — | Ref-Präfix **98…52968** | nur AG-Anteil Aufwand (50/50 prüfen) |
| AXA Haftpflicht (Police 15.371.295) | 6300 | — (Stempelsteuer) | Ref-Präfix **15 37129 5** | — |
| AXA Personenvers. (Police 44.127.389) | 5730/5740 | — | Ref-Präfix **44 12738 9** | KTG/UVG-Zusatz, NICHT 6300 |
| Heineken Franchise | 6301 + **Vorsteuer 1170** | 7.7→8.1% | IBAN CH34 0868…, Ref `415025/…/ZVHRE/` | Heineken in BEIDE camt-Richtungen (Ein=Ertrag, Aus=Aufwand) |
| Gemeinde Domat/Ems (Kehricht/Feuerwehr) | 6460 (Kehricht) | Kehricht ja, Feuerwehr **0%** | IBAN CH54 3077…, Präfix 00473=Betrieb / 00376=privat | Feuerwehrabgabe hoheitlich 0% |
| Vögele Recycling | 6460 | ja | IBAN CH20 0077… | nur Rg-Nr (kein QR) |
| Garage Arpagaus / Autoreparatur | **6250** | 8.1% | — | Selbstbehalt-MwSt variiert pro Beleg! |
| Fahrbewilligung Flims (Gemeinde) | 6275 | **0%** (hoheitlich) | IBAN CH53 0900… | jährlich CHF 40 |
| Strassenverkehrsamt (Führerausweis) | Firmenaufwand (6275) | 0% | — | persönlich, aber Firma trägt (NICHT 2260) |
| Swisscom (Geschäftshandy, auf Daniel) | 6510 | 8.1% (Geräterate **0%**) | IBAN CH32 3000…, Präfix 00 13296 | Privatanteil/Vorsteuer prüfen; Rate splitten |
| UPC/Sunrise (Internet GmbH) | 6510 | ja | IBAN CH76 3000…, Ref …67211 43013 | — |
| Buchhalterin | 6530 | ja | — | — |
| Software (Office/Claude) | 6560 | ggf. (Ausland=Bezugsteuer) | — | — |
| Miete Büro | 6000 | ggf. | Daniel als Vermieter, Mitteilung „Miete Büro" | bereits camt-Regel vorhanden |
| Corona-Kredit Amortisation | 2500 an 1020 (intern) | — | Darlehenskonto …602 | nur Migration (vor Stichtag) |

**Behördliche EINGÄNGE** (eigener Klassifizierungs-Zweig, NICHT Kundenzahlung): SVA-Rückerstattung→5700, SUVA-Rückerstattung→5730, SUVA-Taggeld→5000, Steuer-Rückerstattung→2208, Corona-EO/KAE→Ertrag. (Primär Migration; Go-Forward selten.)

## Info-Dokumente (`ist_nur_info=true`)

Vorsorge-/Lohnausweise, Policen, Sozialversicherungssätze, Veranlagungsverfügungen, Lohndeklarationen, Wertpapier-/Vermögensbewertungen (privat!), Schadenberichte (ARVAL), Spital-Notfallberichte (vertraulich → Personalakte). → Datensatz mit Metadaten (Aussteller/Datum/Typ), Datei abgelegt, **keine Buchung/Zahlung**, in eigener Liste „Info/Ablage" durchsuchbar. **Sozialversicherungssätze** könnten später die Lohn-Einstellungen vorbefüllen (eigener, späterer TP).

## Wiederverwendbare Bausteine

`BelegUploadWidget` (PDF-Upload), `BuchungsBelegRepository` (Bucket buchungs-belege), `BuchungRepository.create`/`setCamtTxKey`/`delete`, `GeschaeftsfallResolver`, `MwstSatzService` (date-aware), `scor_referenz.dart` (`istGueltigeScor`/`scorRefNorm`), `camt053_parser` (Vorbild pain.001-Writer-Umkehr), `betrieb_repository.entscheideAlias` (Vorbild Lernen), `RegelMatcher` (Vorbild KreditorMatcher), `camt_auto_booker` (Orchestrator erweitern), `parse-beleg` (Template parse-rechnung).

## TP-Zerlegung

| TP | Inhalt |
|---|---|
| **TP-0** Fundament | Migration `eingangsrechnung` + Status; `EingangsrechnungRepository`; PDF-Upload-Anbindung (`beleg_quelle`) |
| **TP-1** Scan + KI | Edge `parse-rechnung`, QR-Decode, `RechnungScanService` + `RechnungScanResult`, Upload-/Erkennungs-Screen |
| **TP-2** Bestätigung + Kreditor-Buchung | Liste + Detail (prüfen/korrigieren/bestätigen), Stufe-1-Buchung (Aufwand+VSt an 2000), Info-Doc-Ablage |
| **TP-3** Lieferanten-Lernen | `kreditor_regel`, `KreditorMatcher`, Seed-Regeln, Auto-Vorbelegung + Lernen, Verwaltungs-Screen |
| **TP-4** GKB-Zahlungsfile | pain.001.001.09.ch.03-Writer (Fall A/B/C), Batch-Export-Screen, `zahlungsfile`-Tracking |
| **TP-5** camt-Kreditor-Abschluss | `KreditorenAbgleichService` + `CamtKreditorBooker`, Integration in `CamtAutoBooker`, Referenz-Matching |
| **TP-6** Info-Docs + Reversibilität | Info-Ablage-Verfeinerung, camt-Reversibilität (Storno setzt Status zurück), Multi-PDF-Merge |
| **TP-7** Datenhygiene | Vorlagen `A-*` konsolidieren, Konten-Altlasten |

Reihenfolge TP-0→1→2→3→4→5→6→7. TP-3 ∥ TP-4 möglich.

## Risiken / offene Punkte

- **QR-Auslesen aus PDF:** Swiss-QR im PDF zuverlässig dekodieren (Bibliothek wählen: client `zxing`/`mobile_scanner` auf gerendertem Bild, oder serverseitig). QR liefert exakte Zahldaten → reduziert KI-Fehler.
- **pain.001 XSD-Konformität** GKB (.09.ch.03) — vor Echt-Upload gegen offizielles SIX-XSD validieren; idealerweise erster Test-Upload mit 1 Zahlung.
- **MwSt-Sonderfälle** (Geräteraten-Split, hoheitlich 0%, Selbstbehalt variabel) — KI muss konservativ sein; Bestätigung fängt Fehler.
- **Multi-Konto-Disambiguierung** hängt am Referenz-Präfix — bei fehlendem QR/Referenz Fallback auf Name + manuelle Auswahl.
- **Privatanteil/Daniel-privat-Belege** (Swisscom, Wasser) — nicht automatisch 2260; Bestätigung entscheidet.

## Nicht im Scope (jetzt)

Voll-Migration Buchhaltung 2019–2025 (eigenes Projekt), kritische Gesamtprüfung, automatischer GKB-Upload (bleibt manueller File-Upload), App-Kamera-Scanner (ClearScanner extern).
