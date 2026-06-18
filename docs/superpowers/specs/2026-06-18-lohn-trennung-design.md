# Lohn: Trennung Einstellungen ↔ Lohnbuchhaltung — Design

**Datum:** 2026-06-18 · **Status:** Spec zur Freigabe durch Daniel

---

## 1. Ziel

Klare Trennung:
- **Einstellungen → Lohn-Einstellungen** = **nur variable Werte**: Sozialversicherungssätze (AHV/IV/EO, ALV, NBU, BU, FAK, KTG) + BVG-Fixbeträge, pro Jahr.
- **Einstellungen → Geschäft** = alle **fixen** Daten, inkl. Arbeitnehmer-Stammdaten (AHV-Nr., Geburtsdatum) beim Geschäftsführer.
- **Buchhaltung → Lohnbuchhaltung** (operativ) = nur Lohnläufe + Lohnausweis, **keine Einstellungen, keine Einstellungs-Links**.

**Leitprinzip:** Lohnausweis-PDF und Lohnlauf-Logik bleiben unverändert — die `LohnEinstellungen`-Spalten (`arbeitnehmer*`/`arbeitgeber*`/`geburtsjahr`) bleiben erhalten und werden beim Speichern als **Snapshot aus dem Geschäft** befüllt.

---

## 2. Ausgangslage (Ist)

- Routen: `/buchhaltung/lohn` → **LohnlaufScreen** (operativ, Titel „Lohnbuchhaltung"); `/buchhaltung/lohn/einstellungen` → **LohnEinstellungenScreen** (Sätze + AN + AG-read-only).
- **Bug aus G6:** Settings-Kachel „Lohn-Einstellungen" zeigt auf `/buchhaltung/lohn` (= Lohnbuchhaltung) statt auf `…/einstellungen`.
- **LohnlaufScreen** verlinkt 2× auf die Einstellungen: `_buildNoSettings()` (Button „Einstellungen öffnen", Zeile ~108) und `_buildContent` (Button „Einstellungen", Zeile ~177).
- **LohnEinstellungenScreen** (nach G7): Grunddaten (Geburtsjahr), Sätze, BVG, Arbeitnehmer-Block (Name/Vorname/Adresse/PLZ-Ort prefilled aus Geschäft + AHV-Nr./Geburtsdatum), Arbeitgeber read-only aus Geschäft. Speichert AN aus Controllern, AG aus Geschäft.
- **GeschaeftEinstellungen**: firma/strasse/plz_ort/gf_vorname/gf_name/telefon/mail_*/mwst/uid. Kein AHV-Nr./Geburtsdatum.
- **GeschaeftMapping**: `arbeitgeber(g)` + `arbeitnehmerPrefill(...)`.
- **lohnausweis_pdf_service** liest `einst.arbeitnehmer*` + `einst.arbeitgeber*`.

---

## 3. Datenmodell

### 3.1 Migration 098 — Geschäft um AN-Stammdaten erweitern
```sql
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_ahv_nr text;
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_geburtsdatum date;
```
- **Daten retten:** bestehende AN-Stammdaten aus der neuesten Lohn-Einstellung in das Geschäft übernehmen, damit nichts verloren geht:
```sql
UPDATE geschaeft_einstellungen g
SET gf_ahv_nr = COALESCE(g.gf_ahv_nr, le.arbeitnehmer_ahv_nr),
    gf_geburtsdatum = COALESCE(g.gf_geburtsdatum, le.arbeitnehmer_geburtsdatum)
FROM (
  SELECT DISTINCT ON (user_id) user_id, arbeitnehmer_ahv_nr, arbeitnehmer_geburtsdatum
  FROM lohn_einstellungen ORDER BY user_id, jahr DESC
) le
WHERE le.user_id = g.user_id;
```

### 3.2 `GeschaeftEinstellungen` (Model)
- Neue Felder: `String? gfAhvNr`, `DateTime? gfGeburtsdatum`.
- `fromJson`: `gf_ahv_nr`, `gf_geburtsdatum` (Datum via `DateTime.parse` wenn nicht null).
- `toJson`: `gf_ahv_nr`, `gf_geburtsdatum` (als `YYYY-MM-DD`-String oder null).
- Getter `int get gfGeburtsjahr => gfGeburtsdatum?.year ?? 1990;`

### 3.3 `LohnEinstellungen`
**Schema unverändert.** Die `arbeitnehmer*`/`arbeitgeber*`/`geburtsjahr`-Spalten bleiben; werden beim Speichern aus dem Geschäft befüllt (Snapshot). Lohnausweis-PDF unverändert.

---

## 4. Mapping (`geschaeft_mapping.dart`)
- **`arbeitnehmerPrefill`** wird **entfernt** (nicht mehr gebraucht — AN-Felder verschwinden aus dem Lohn-Screen).
- **Neu `arbeitnehmer(GeschaeftEinstellungen g)`** → vollständiger AN-Snapshot:
  `({String? name, String? vorname, String? adresse, String? plzOrt, String? ahvNr, DateTime? geburtsdatum, int geburtsjahr})`
  mit `name: g.gfName`, `vorname: g.gfVorname`, `adresse: g.adresseStrasse`, `plzOrt: g.adressePlzOrt`, `ahvNr: g.gfAhvNr`, `geburtsdatum: g.gfGeburtsdatum`, `geburtsjahr: g.gfGeburtsjahr`.
- `arbeitgeber(g)` bleibt.

---

## 5. UI

### 5.1 Geschäft-Form (`widgets/geschaeft_form.dart`)
Unter „Geschäftsführer" zwei Felder ergänzen: **AHV-Nr.** (`gf_ahv_nr`, Text) und **Geburtsdatum** (`gf_geburtsdatum`, Format TT.MM.JJJJ). Beim Speichern: AHV-Nr. als Text; Geburtsdatum geparst → `YYYY-MM-DD` (oder null).

### 5.2 Lohn-Einstellungen-Screen (`lohn_einstellungen_screen.dart`)
- **Entfernen:** Grunddaten-Section (Geburtsjahr), Arbeitnehmer-Section (alle AN-Felder), Arbeitgeber-Read-only-Block. Zugehörige Controller + `dispose`-Einträge + `_fillFromEinstellungen`-Zeilen + den AN-Prefill-Block aus `build`.
- **Behalten:** nur „Sozialversicherungen — Sätze (%)" + „BVG / Pensionskasse — Fixbeträge".
- **`_save()`**: Sätze aus Controllern; **AN + AG + geburtsjahr aus Geschäft** (`GeschaeftMapping.arbeitnehmer(geschaeft)` + `arbeitgeber(geschaeft)`):
  `geburtsjahr: an.geburtsjahr`, `arbeitnehmerName/Vorname/Adresse/PlzOrt/AhvNr/Geburtsdatum: an.*`, `arbeitgeberName/Adresse/PlzOrt: ag.*`.
- Screen liest weiterhin `geschaeftProvider` (für den Save-Snapshot).

### 5.3 Lohnbuchhaltung (`lohnlauf_screen.dart`)
- `_buildContent`: den „Einstellungen"-Button (Zeile ~177) **entfernen**.
- `_buildNoSettings`: den Button „Einstellungen öffnen" durch reinen **Hinweistext** ersetzen: „Sätze unter Einstellungen → Lohn-Einstellungen erfassen." (kein Navigations-Button).
- Ungenutzt gewordene Imports/`context.push('/buchhaltung/lohn/einstellungen')`-Aufrufe entfernen.

### 5.4 Routing-Fix (`einstellungen_screen.dart`)
Settings-Kachel „Lohn-Einstellungen" `onTap`: `'/buchhaltung/lohn'` → **`'/buchhaltung/lohn/einstellungen'`**.

---

## 6. „App funktioniert gleich"
- Migration kopiert bestehende AN-Stammdaten ins Geschäft → kein Datenverlust.
- Satz-Defaults unverändert; `LohnEinstellungen`-Schema unverändert; AN/AG-Snapshot aus Geschäft → Lohnausweis identisch.
- Lohnlauf-Berechnung nutzt nur die Sätze (unverändert).

---

## 7. Tests (TDD, reine Logik)
- `geschaeft_mapping_test.dart`: `arbeitnehmer(g)` liefert alle Felder aus Geschäft inkl. `geburtsjahr` aus `gfGeburtsdatum.year`; ohne Geburtsdatum → `geburtsjahr == 1990`.
- `geschaeft_einstellungen_test.dart`: `gfGeburtsjahr`-Getter (Datum gesetzt → year; null → 1990); fromJson/toJson für `gf_ahv_nr`/`gf_geburtsdatum`.
- Bestehende Tests bleiben grün.

---

## 8. Erfolgskriterien
- Lohn-Einstellungen zeigt **nur** Sätze + BVG.
- Geschäft erfasst AHV-Nr. + Geburtsdatum; AN-Snapshot beim Lohn-Speichern korrekt → Lohnausweis vollständig.
- Lohnbuchhaltung ohne Einstellungs-Buttons; Leer-Zustand nur Hinweis.
- Settings-Kachel „Lohn-Einstellungen" öffnet die Sätze (nicht die Lohnbuchhaltung).
- `flutter analyze` 0 Errors; neue + bestehende Tests grün.

---

## 9. Nicht im Scope
- Verschieben der Lohn-Einstellungen-Route nach `/einstellungen/…` (Adresse bleibt `/buchhaltung/lohn/einstellungen`, nur korrekt verlinkt).
- Mehrere Arbeitnehmer (weiterhin GF = einziger AN).
