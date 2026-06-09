# Phase 0 – Fundament Buchhaltung: Detail-Design

**Datum:** 2026-06-09 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** [Gesamtkonzept](2026-06-09-buchhaltung-gesamtkonzept-design.md) · **Baustein:** Phase 0 (voller Umfang)

**Ziel:** Den korrekten, vollständigen Buchhaltungs-Kern in der App bereitstellen, auf dem alle weiteren Phasen (Import, Bereinigung, Kreditoren-Erfassung, Zahlungen) aufbauen.

---

## 1. Ausgangslage (bereits vorhanden)

Aus dem camt-Feature existieren bereits (Supabase, online-only für Buchhaltung):

- **`Konto`** — `kontonummer, bezeichnung, beschreibung, kategorie, kontenklasse, istAktiv`
- **`Buchung`** (Journal) — `datum, belegnummer, vorlageId, sollKonto, habenKonto, mwstKonto, betragNetto, mwstSatz, mwstBetrag, betragBrutto, beschreibung, zahlungsweg, belegordner, belegTyp, belegId, geschaeftsjahr, monat, quartal, istStorniert, stornoVonId, notizen`
- **`BuchungsVorlage`** — `geschaeftsfallId, bezeichnung, sollKonto, habenKonto, mwstKonto, mwstSatz, zahlungsweg, belegordner, autoTrigger, istAktiv`
- **`BuchungsBeleg`** — verknüpft Scan ↔ Buchung (`storagePfad, belegQuelle`)
- Repositories, Provider, Screens (Liste/Detail/Formular), Services (`buchung_service`, `reinigung_buchung_service`, `heineken_buchung_service`)

Wir **erweitern & verfeinern** dieses Gerüst — kein Neubau.

## 2. Datenmodell-Änderungen

### 2.1 Geschäftsfall (Umbau von `BuchungsVorlage`)
Die Vorlage wird zum echten **Geschäftsfall** mit einer `art`:

| Feld | Bedeutung |
|---|---|
| `code` | z. B. `4` (Tanken), `1` (Reinigung Bar) — bisher `geschaeftsfallId` |
| `bezeichnung` | Klartext |
| `art` | `ausgabe` \| `einnahme` \| `fix` |
| `hauptkonto` | das fixe Konto (Aufwand bei `ausgabe`, Ertrag bei `einnahme`) |
| `mwstPflichtig` | bool |
| `mwstKonto` | bei `ausgabe`→Vorsteuer (1170/1171), bei `einnahme`→Umsatzsteuer (2200) |
| `erlaubteZahlungswege` | Liste, nur bei `ausgabe`/`einnahme` |
| `sollKonto`/`habenKonto` | **nur bei `art = fix`** (explizit, kein Zahlungsweg) |
| `belegordner`, `istAktiv` | wie bisher |

**Auflösung beim Buchen** (Zahlungsweg → Gegenkonto: Kasse 1000, Bank 1020, Privat 2260, Kreditor 2000):
- `ausgabe` + Zahlungsweg Z → **Soll = hauptkonto**, **Haben = Konto(Z)**, MWST = mwstKonto (Vorsteuer)
- `einnahme` + Zahlungsweg Z → **Soll = Konto(Z)**, **Haben = hauptkonto**, MWST = mwstKonto (2200)
- `fix` → Soll/Haben explizit aus dem Geschäftsfall

Die `Buchung` speichert weiterhin das **aufgelöste** `sollKonto`/`habenKonto` → Journal bleibt unverändert kompatibel.

### 2.2 MWST-Satz datumsabhängig (neue kleine Tabelle `mwst_satz`)
`gueltig_ab (date), satz (decimal)`. Seed: `2010-01-01 → 7.7`, `2024-01-01 → 8.1` (Datenbestand beginnt 2019; ältere Sätze nicht nötig). Beim Buchen: Satz = jüngster Eintrag mit `gueltig_ab ≤ Buchungsdatum`. Der Geschäftsfall hält nur noch `mwstPflichtig` + `mwstKonto`, **nicht** den Satz.

### 2.3 `Konto` — unverändertes Modell, bereinigter Inhalt (siehe §3).

### 2.4 Offene Posten (Ableitung, kein neues Schweres Modell)
- **Debitoren (1100):** offene Ausgangsrechnungen = bestehende `rechnung` minus Zahlungseingänge (camt/manuell). Bereits weitgehend vorhanden.
- **Kreditoren (2000):** offene Eingangsrechnungen = Buchungen mit Haben 2000, noch nicht durch eine Zahlung (Soll 2000) ausgeglichen, gruppiert je Beleg. Die eigentliche Kreditoren-**Erfassung** kommt in Phase 3; Phase 0 liefert nur die **Sicht/Ableitung** „offen/fällig/bezahlt".

## 3. Kontenrahmen (bereinigt)

Basis: die 61 Excel-Konten 1:1 übernehmen. **Änderungen:**

- **Vorlagen-Fehler korrigieren** (betrifft Geschäftsfälle, nicht den Kontenrahmen selbst): `8090 → 8900`, `9100 → 9010`, „Privat 1010" → `2260`, `1120` (existiert nicht) → korrektes Konto je Fall.
- **Neu für Abschreibungen (Phase 2):** Wertberichtigung/Delkredere auf Debitoren + ein Debitorenverlust-Konto. Genaue Kontonummern/Methode (Einzel- vs. Pauschalwertberichtigung) **mit Treuhänder** festlegen — Platzhalter im Seed, finalisierbar.
- Ungenutzte Konten (z. B. 2206 Verrechnungssteuer) bleiben bestehen (schaden nicht), werden aber nicht aktiv bebucht.

Der Seed bildet zusätzlich `kategorie`/`kontenklasse` ab (für die Auswertungs-Gliederung, wie in der Excel-Spalte „Kategorie").

## 4. Geschäftsfälle (optimiert, ~30 statt 88)

Die 88 Excel-Vorlagen werden zu Geschäftsfällen verdichtet, indem die 3 Varianten (Kasse/Bank/Privat) + künftig Kreditor in den **Zahlungsweg** wandern:

- **Ausgaben** (je 1 Geschäftsfall, `erlaubteZahlungswege = [Kasse, Bank, Privat, Kreditor]`): Spesen→5820, Tanken→6200, Parkgebühren→6270, Bussen→6280, Fahrbewilligung→6275, Autoreparatur/Selbstbehalt→6250, Büromaterial→6500, Werkzeug/Material→4004, Berufskleider→5850, Kaffee→5880, Kehricht→6460, Briefmarken→6510 (ohne MWST), Internet/Mobile→6510, Software→6560, Büromiete→6000 (ohne MWST), Buchführung→6530, Sachversicherung/Haftpflicht→6300, Entsorgung→6460.
- **Einnahmen:** Reinigung→3400 (Zahlungsweg Kasse/Debitor), Heineken-Monatsrechnung→3400.
- **Fixe Geschäftsfälle** (explizit Soll/Haben, kein Zahlungsweg): Franchise (6301/2000 + 1170 → 2-stufig), Lohnlauf (22.x: Brutto + AG-/AN-Anteile + Nettozahlung), MWST-Abrechnung (25.x), Steuern (8900 — Behandlung „direkt vs. Rückstellung 2208" mit Treuhänder), Corona-Kredit (2500), KAE/EO (5005/2276), Härtefall (8510), Bankgebühren (6940), Sozialversicherungs-Zahlungen (2271/2272/2273 → 1020), Gründung (2800/6550), Gewinn-/Verlustvortrag & Abschluss.

Jeder Geschäftsfall trägt seinen `belegordner` (für die Ablage-Zusammenführung in Phase 3).

## 5. Auswertungen (Berechnung aus dem Journal)

**1:1 nach der Gliederung der Excel-Sheets**, damit der Phase-1-Abgleich exakt aufgeht:

- **Bilanz** (per Stichtag): Saldo je Konto (Σ Soll − Σ Haben bis Stichtag), gruppiert nach Kategorie (Umlaufvermögen / Anlagevermögen / kfr. + lfr. Fremdkapital / Eigenkapital); Aktiv-/Passiv-Summen + Differenz-Anzeige.
- **Erfolgsrechnung** (Periode wählbar): KMU-Stufengliederung wie Excel — Nettoerlös (3), Material (4) → Bruttoergebnis 1; Personal (5) → Bruttoergebnis 2; übriger Betriebsaufwand (6000–6700) → EBITDA; Abschreibungen (6800) → EBIT; Finanz (6900) → EBT; betriebsfremd/ausserordentlich (7/8) + Steuern (8900) → Jahresergebnis. Plus Detail-/Kontoaufstellung.
- **MWST-Abrechnung** (Quartal): Umsatz (Σ 3400), geschuldete MWST (2200), Vorsteuer (1170 + 1171), Zahllast/Guthaben — als Vorschau der ESTV-Abrechnung. (Die eigentliche Abrechnungs-Buchung GF 25.x bleibt eine Buchung.)

Implementierung: reine Berechnungs-Services über die Buchungen; keine Speicherung redundanter Salden.

## 6. Datenfluss

```
Geschäftsfall (Stamm) ─┐
Zahlungsweg (Auswahl) ─┼─► Auflösung Soll/Haben/MWST ─► Buchung (Journal) ─► Auswertungen (Bilanz/ER/MWST)
MWST-Satz (Datum)     ─┘                                      │
                                                              └─► Offene-Posten-Sicht (1100/2000)
```

## 7. Migrationen & Code

- **DB-Migrationen** (`Datenbank/migrations/`): Geschäftsfall-Felder (`art, hauptkonto, mwst_pflichtig, erlaubte_zahlungswege`), Tabelle `mwst_satz`, neue Konten (Delkredere/Debitorenverlust), Seeds (Konten 61, Geschäftsfälle ~30, MWST-Sätze).
- **Modelle/Repos/Provider** erweitern (Konto, Buchung unverändert; `BuchungsVorlage`→`Geschäftsfall`). Falls Isar betroffen: Conditional Exports + `*_web.dart`-Stubs gemäss CLAUDE.md. Buchhaltung ist Supabase-online — Isar nur falls bereits genutzt.
- **`buchung_service`** um die Auflösungs-Logik (§2.1) + MWST-Satz-Lookup (§2.2) erweitern.
- **Neue Services:** `bilanz_service`, `erfolgsrechnung_service`, `mwst_abrechnung_service`, `offene_posten_service`.
- **Screens:** Buchungs-Formular auf „Geschäftsfall + Zahlungsweg" umstellen; neue Auswertungs-Screens (Bilanz/ER/MWST) + Offene-Posten-Liste.

## 8. Erfolgskriterien

- Eine Ausgabe lässt sich über „Geschäftsfall + Zahlungsweg" erfassen; Soll/Haben/MWST werden korrekt aufgelöst (inkl. Kreditor-Weg).
- MWST-Satz wird automatisch aus dem Datum bestimmt (7.7/8.1).
- Bilanz, Erfolgsrechnung und MWST-Vorschau lassen sich aus den Buchungen berechnen und sind in der Gliederung deckungsgleich mit den Excel-Sheets (Voraussetzung für Phase-1-Abgleich).
- Offene Posten (Debitoren/Kreditoren) sind als Liste sichtbar.
- Bestehende Buchungen/Screens funktionieren weiter (keine Regression).

## 9. Offen / mit Treuhänder

- Genaue Konten & Methode für **Debitoren-Wertberichtigung/Abschreibung** (Phase 2).
- **Steuern: direkt 8900 vs. Rückstellung 2208** — Entscheid mit Treuhänder (Default: wie Excel, direkt 8900).
- Detail der Lohn-Geschäftsfälle (Bruttomethode-Abbildung) wird beim Import (Phase 1) an realen Buchungen verifiziert.
