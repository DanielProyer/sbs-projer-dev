# Eingangsrechnung-Kategorien — Design

**Datum:** 2026-06-29
**Status:** Design freigegeben (Daniel), bereit für Plan
**Bezug:** baut auf dem Eingangsrechnungen-Feature (TP-0…7, `2026-06-25-eingangsrechnungen-design.md`) auf.

## Ziel

Eine **inhaltsbasierte Kategorie** für jedes Eingangsdokument (Rechnung **und** reines Info-Dokument), die drei Anliegen auf einmal löst:

1. **Info-Dokumente auffindbar machen** — Ablage nach Thema/Typ (primärer Wunsch).
2. **Rechnungen kategorisieren** — Auswertung/Filter nach Thema.
3. **Robuste Erkennung** — z.B. eine Busse wird am **Inhalt** erkannt (jede Ordnungs-/Geschwindigkeitsbusse), nicht mehr nur über den Aussteller-Namen. Heute scheitert das: die Regel `Kantonspolizei → 6280` erkennt eine Luzerner Busse mit anderem Aussteller nicht.

## Ansatz (gewählt: A)

Die `parse-rechnung`-KI liest ohnehin den ganzen Inhalt → sie vergibt zusätzlich eine **Kategorie** (eine von 15). Die Kategorie wird auf der Eingangsrechnung gespeichert und:
- macht das Dokument auffindbar (Filter / Ablage-Ansicht),
- schlägt bei Rechnungen das **Aufwandskonto** vor (Kategorie-Default).

**Verfeinerung statt Ersatz:** Die bestehenden **Aussteller-Regeln** (`kreditor_regel`, „Rechnungsregeln") bleiben und gewinnen über den Kategorie-Default (sie sind spezifischer, z.B. AXA-Policen per Referenz). Die KI-Kategorie ist immer **manuell überschreibbar**.

## Taxonomie (15 Kategorien)

| code | Bezeichnung | deckt ab |
|---|---|---|
| `versicherung` | Versicherung | Haftpflicht/Sach (AXA), Policen, Prämien |
| `sozialversicherung` | Sozialversicherung | AHV/SVA, BVG/PK, SUVA/UVG, KTG (Beiträge/Prämien), Vorsorgeausweis |
| `unfall_krankheit` | Unfall & Krankheit | Schadensmeldung, Krankschreibung, Apothekerschein, SUVA-Korrespondenz, Taggeldbescheid, Unfallschein |
| `steuern` | Steuern & MwSt | Bundes-/Kantons-/Gemeindesteuer, ESTV-MWST, Veranlagung |
| `busse` | Busse | Ordnungs-/Geschwindigkeitsbussen (jeder Kanton/Gemeinde) |
| `fahrzeug` | Fahrzeug | Tanken, Reparatur, Fahrbewilligung, Strassenverkehrsamt |
| `telekom_it` | Telekom & IT | Telefon, Internet, Software/Abos |
| `franchise` | Franchise | Heineken-Franchisegebühr |
| `miete_raum` | Miete & Raum | Büromiete, Nebenkosten |
| `entsorgung_gemeinde` | Entsorgung & Gemeinde | Kehricht, Feuerwehrabgabe |
| `material_werkzeug` | Material & Werkzeug | Einkauf Material/Werkzeug |
| `treuhand_beratung` | Treuhand & Beratung | Buchhaltung, Beratung |
| `lohn_personal` | Lohn & Personal | Lohnausweis, Lohndeklaration, Personalpapiere |
| `behoerde_amtliches` | Behörde & Amtliches | sonstige behördliche Schreiben (Info) |
| `sonstiges` | Sonstiges | Auffangkategorie |

*Bewusst nicht aufgenommen:* Corona-Kredit, Kurzarbeitsentschädigung (einmalig/vergangen).

## Datenmodell

### Neue Tabelle `eingangsrechnung_kategorie`
Kategorien sind erweiterbar ohne Deploy; hier wohnt das Kategorie→Konto-Mapping.

| Spalte | Typ | Hinweis |
|---|---|---|
| `code` | text PK | z.B. `busse` |
| `bezeichnung` | text NOT NULL | „Busse" |
| `default_aufwandskonto` | int NULL | Konto-Vorschlag (null = kein Default) |
| `default_vorsteuer_konto` | int NULL | Vorsteuer-Konto-Vorschlag |
| `reihenfolge` | int NOT NULL DEFAULT 0 | Sortierung im Dropdown |
| `ist_aktiv` | bool NOT NULL DEFAULT true | |

Seed mit den 15 (sinnvolle Start-Defaults, von Daniel anpassbar):

| code | default_aufwandskonto | default_vorsteuer_konto |
|---|---|---|
| versicherung | 6300 | — |
| sozialversicherung | — | — *(Aussteller-Regeln decken AHV/BVG/SUVA differenziert ab)* |
| unfall_krankheit | — | — *(meist Info/Eingang, keine Kreditor-Rechnung)* |
| steuern | — | — *(Sonderbehandlung 8900/2202 via Geschäftsfall)* |
| busse | 6280 | — |
| fahrzeug | 6250 | 1171 |
| telekom_it | 6510 | 1171 |
| franchise | 6301 | 1170 |
| miete_raum | 6000 | — |
| entsorgung_gemeinde | 6460 | 1171 |
| material_werkzeug | 4004 | 1170 |
| treuhand_beratung | 6530 | 1171 |
| lohn_personal | — | — *(meist Info)* |
| behoerde_amtliches | — | — *(meist Info)* |
| sonstiges | — | — |

### Erweiterung `eingangsrechnung`
- Neue Spalte **`kategorie text`** (NULL erlaubt; Wert = `code` aus der Kategorie-Tabelle). Gilt für Rechnungen **und** Info-Docs.
- Kein Backfill nötig (aktuell 0 Eingangsrechnungen in der DB).

## KI-Klassifizierung

`supabase/functions/parse-rechnung/index.ts` — Prompt um einen Schritt erweitern:
- Die KI klassifiziert `kategorie` (genau einer der 15 `code`s) aus dem **Inhalt**, mit kurzen Definitionen — besonders:
  - `busse` = jede Ordnungs-/Geschwindigkeitsbusse (egal welcher Kanton/Aussteller).
  - `unfall_krankheit` = Schadensmeldung, Krankschreibung, Apothekerschein, SUVA-Korrespondenz, Taggeldbescheid, Unfallschein.
  - `sozialversicherung` = **Beiträge/Prämien** an AHV/BVG/SUVA/KTG (Abgrenzung zu `unfall_krankheit`).
- Output-JSON erhält Feld `kategorie`. Bei Unsicherheit → `sonstiges`.
- **Edge-Function-Redeploy** nötig (`--no-verify-jwt` wie bisher).

`RechnungScanResult` (Dart-DTO) um `kategorie` erweitern (robustes Parsing, String oder null).

## Konto-Vorschlag-Logik (löst die Busse)

Beim Erfassen einer Rechnung wird das Aufwandskonto in dieser Reihenfolge vorgeschlagen:

1. **Aussteller-Regel** (`matchKreditorRegel`, spezifisch: Name + Referenz-Präfix / IBAN) → liefert aufwandskonto + vorsteuer_konto + mwst + geschaeftsfall **komplett**. Höchste Priorität.
2. **Kategorie-Default** (aus `eingangsrechnung_kategorie`) → `default_aufwandskonto` / `default_vorsteuer_konto`, falls keine Aussteller-Regel passt.
3. sonst leer (manuell).

MwSt-Satz/-Pflicht kommt unverändert von der KI (Busse → 0 / nicht pflichtig).

→ **Luzerner Busse:** keine Aussteller-Regel, aber Kategorie `busse` → 6280 automatisch. Die bestehende `Kantonspolizei`-Aussteller-Regel wird damit überflüssig (kann bleiben oder entfernt werden — gleiches Ergebnis).

Reine Funktion `schlageKontoVor(kategorie, kategorienById, regelTreffer?) → {aufwandskonto, vorsteuerKonto}` — testbar.

## UI

- **Upload/Detail (`eingangsrechnung_detail_screen` / `_upload_screen`):** KI-Kategorie als **Dropdown** (15, vorbelegt, korrigierbar). Beim „Bestätigen & buchen" / „Nur ablegen" mitgespeichert. Ändert man die Kategorie und es gibt keine Aussteller-Regel, wird der Konto-Vorschlag aktualisiert.
- **Liste (`eingangsrechnung_liste_screen`):**
  - **Umschalter „Rechnungen | Ablage"** — „Ablage" zeigt die Info-Docs (`istNurInfo`/`abgelegt`).
  - **Kategorie-Filter** (Dropdown/Chips) in beiden Ansichten — z.B. „alle Bussen" oder „alle Versicherungs-Dokumente".
  - Kategorie als kleines Label an der Listenzeile.

## Tests

- Unit: `schlageKontoVor` — Reihenfolge Regel > Kategorie-Default > leer; Busse-Default; null-Defaults.
- Unit: Listen-Filter/Gruppierung nach Kategorie + Rechnungen/Ablage-Aufteilung.
- KI-Klassifizierung: manueller Test (echte Dokumente, wie beim Scan-Feature).

## Bewusst NICHT jetzt (YAGNI)

- **Kein** Kategorie-Verwaltungs-Screen — die 15 sind geseedet, Ändern selten. Anpassen vorerst via DB; Management-UI später, falls nötig.
- Keine Volltextsuche / Aussteller-/Datums-Facetten (Daniel sucht nach Thema/Typ).

## TP-Zerlegung (für den Plan)

| TP | Inhalt |
|---|---|
| **TP-1** | Migration: Tabelle `eingangsrechnung_kategorie` + Seed (15), Spalte `eingangsrechnung.kategorie`. Modell/Repository. |
| **TP-2** | KI: `parse-rechnung`-Prompt + Output `kategorie`, `RechnungScanResult`-Feld, Redeploy. |
| **TP-3** | Konto-Vorschlag-Logik `schlageKontoVor` (rein, TDD) + Einbau in Upload/Detail. |
| **TP-4** | UI: Kategorie-Dropdown (Detail/Upload), Liste — Umschalter Rechnungen/Ablage + Kategorie-Filter + Label. |
