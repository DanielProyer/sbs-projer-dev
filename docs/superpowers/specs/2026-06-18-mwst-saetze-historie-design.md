# MWST-Sätze Historie (Normal + Reduziert, datumsabhängig) — Design

**Datum:** 2026-06-18 · **Status:** Spec zur Freigabe durch Daniel

---

## 1. Ziel

In den Einstellungen die MWST-Sätze **datumsabhängig** und **mit reduziertem Satz** abbilden:
- bis 31.12.2023: Normal **7.7 %** · Reduziert **2.5 %**
- ab 01.01.2024: Normal **8.1 %** · Reduziert **2.6 %**

Bestehende Sätze sind **fix** (read-only Anzeige). **Neue Sätze** lassen sich künftig hinzufügen („ab Datum" + Normal + Reduziert).

---

## 2. Ausgangslage (Ist)

- Tabelle **`mwst_satz`** (user_id, `gueltig_ab` date, `satz` numeric) — hält **nur den Normalsatz**. Aktuell: `2010-01-01 → 7.70`, `2024-01-01 → 8.10` (korrekt).
- **`MwstSatzService`** (`services/buchhaltung/mwst_satz_service.dart`): `laden()` (Cache `_cache`), `satzFuer(datum, saetze)`, `satzFuerDatum(datum)`. Genutzt von `buchung_service`, `abschreibung_service`, `buchung_form_screen` → **datumsabhängiger Normalsatz für Buchungen**.
- **Reduzierter Satz**: aktuell als `Preis.mwstSatzReduziert` (Einzelwert pro Preis-Version) **angezeigt/editiert** in der Einstellungen-Sektion „MwSt-Sätze" (`_editMwst`-Dialog). **Wird tatsächlich gebucht** — der Spesen-Import (`spesen_import_service`) bucht `pos.mwstSatz` pro Position, wobei der Satz aus dem **gescannten Beleg (OCR)** stammt (reduzierter Satz kommt vor). Quelle für die Spesen-Buchung ist also der Beleg, **nicht** die Einstellungen.
- **Kopplung MWST ↔ Preis:** Die MwSt-Sektion liegt heute **innerhalb** des `aktuellePreise.when(data: preis)`-Blocks und liest/editiert `preis.mwstSatz`/`preis.mwstSatzReduziert`. Das soll **entkoppelt** werden (kein Zusammenhang Preis ↔ MWST).

---

## 3. Datenmodell

### 3.1 Migration 099 — `mwst_satz` um reduzierten Satz
```sql
ALTER TABLE mwst_satz ADD COLUMN IF NOT EXISTS satz_reduziert numeric;
UPDATE mwst_satz SET satz_reduziert = 2.50 WHERE gueltig_ab < '2024-01-01' AND satz_reduziert IS NULL;
UPDATE mwst_satz SET satz_reduziert = 2.60 WHERE gueltig_ab >= '2024-01-01' AND satz_reduziert IS NULL;
```
Damit: `2010-01-01 → 7.70/2.50`, `2024-01-01 → 8.10/2.60`.

### 3.2 `MwstSatz` (Model in `mwst_satz_service.dart`)
Feld ergänzen: `final double satzReduziert;` (Konstruktor `MwstSatz(this.gueltigAb, this.satz, this.satzReduziert)`).

---

## 4. Service (`mwst_satz_service.dart`)
- `laden()` selektiert zusätzlich `satz_reduziert` (parst zu double, null → 0.0).
- `satzFuer(datum, saetze)` (Normalsatz) **unverändert**.
- Neu `reduzierterSatzFuer(DateTime datum, List<MwstSatz> saetze)` (analog, jüngster gültiger reduzierter Satz).
- Neu `static void cacheLeeren() => _cache = null;` (nach dem Hinzufügen eines Satzes).
- Neu `static Future<void> hinzufuegen({required DateTime gueltigAb, required double satz, required double satzReduziert})` → Insert in `mwst_satz` (user_id = `SupabaseService.dataUserId`) + `cacheLeeren()`.

---

## 5. Provider
`mwstSaetzeProvider` = `FutureProvider<List<MwstSatz>>` → `MwstSatzService.laden()`, **absteigend nach `gueltigAb` sortiert** (neueste zuerst). Nach `hinzufuegen` wird `mwstSaetzeProvider` invalidiert.

---

## 6. UI — Einstellungen „MwSt-Sätze" entkoppeln (`einstellungen_screen.dart`)
- **Entkopplung von der Preis-Version:** Die MwSt-Sektion wird zu einer **eigenständigen** Sektion, die **nicht** mehr `preis.*` liest, sondern `mwstSaetzeProvider`. Sie wird **unabhängig vom Preis** gerendert (auch wenn keine Preis-Version existiert): Der `body` wird so umgebaut, dass die preis-unabhängigen Sektionen (Geschäft, Lohn, **MwSt-Sätze**) immer angezeigt werden und nur die **preis-abhängigen** Sektionen (Reinigungs-/Störungs-/Weitere Preise, Biersorten, Heineken, „Neue Preise erfassen") in einem inneren `aktuellePreise.when(...)` liegen.
- **MwSt-Sektion neu** (aus `mwstSaetzeProvider`):
  - Pro Eintrag eine Zeile: **„ab TT.MM.JJJJ — Normal X.X % · Reduziert Y.Y %"** (jüngster Eintrag mit Zusatz „(aktuell)").
  - Button **„Neuen Satz hinzufügen"** → Dialog (Gültig ab TT.MM.JJJJ, Normal %, Reduziert %) → `MwstSatzService.hinzufuegen(...)` → `ref.invalidate(mwstSaetzeProvider)` + Snackbar.
- Den `_editMwst`-Dialog (Preis-basiert) + dessen Aufruf + die preis-basierte MwSt-Anzeige entfernen.
- `Preis.mwstSatz`/`mwstSatzReduziert` bleiben im Schema/Model (von der Preis-Versions-Erfassung weiter genutzt) — **nicht** angefasst.

---

## 7. „App läuft gleich"
- Buchungs-MWST (Normalsatz via `satzFuerDatum`) **unverändert**.
- Spesen-Buchungen nehmen den Satz weiterhin **vom gescannten Beleg** (`pos.mwstSatz`) — durch diese Änderung **nicht** betroffen.
- Migration nur additive Spalte + Daten-Backfill; reduzierter Satz wird in den Einstellungen nur korrekt **abgebildet/erfassbar** (date-aware), ohne bestehende Buchungspfade zu ändern.

---

## 8. Tests (TDD, reine Logik)
- `mwst_satz_service_test.dart`:
  - `satzFuer`: Datum 2023 → 7.7; Datum 2024 → 8.1 (bestehende Logik bleibt grün).
  - `reduzierterSatzFuer`: Datum 2023 → 2.5; Datum 2024 → 2.6; Datum vor erstem Eintrag → 0.0.

---

## 9. Erfolgskriterien
- Einstellungen zeigen die MWST-Historie (ab-Datum, Normal + Reduziert): 7.7/2.5 und 8.1/2.6.
- „Neuen Satz hinzufügen" legt einen Eintrag an, der sofort in der Liste erscheint und (für den Normalsatz) ab dem Datum in Buchungen greift.
- Buchungen unverändert; `flutter analyze` 0 Errors; Tests grün.

---

## 10. Nicht im Scope
- Bearbeiten/Löschen bestehender Sätze (fix; nur Hinzufügen neuer).
- Spesenscanner-Umbau: der Satz kommt weiter vom Beleg (OCR), keine Anbindung an `mwst_satz`.
- Migration der `Preis.mwst*`-Felder (bleiben für die Preis-Versions-Erfassung).
