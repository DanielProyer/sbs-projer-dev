# Historie-Backfill Werkstatt-Aufträge — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die historischen Heineken-Werkstatt-Aufträge (Störung/Montage/Eigenauftrag/Eröffnung-Endreinigung/Pikett, 2019 → 30.11.2025) aus dem Excel `00_SBS_Projer_70.xlsm` als echte, duplikatfreie App-Datensätze nach Supabase-Prod importieren, sodass sich die Buchhaltungs-Auswertung rückwirkend füllt.

**Architecture:** Ein einmaliges, idempotentes Python-Skript in `Datenbank/import/` liest das Excel (pandas/openpyxl), mappt Betriebe über den bestehenden `match_betriebe.py`, transformiert je Kategorie und schreibt Batch-SQL (`INSERT … ON CONFLICT (user_id, extern_id) DO NOTHING`) nach `out/`. Die SQL wird per Supabase-MCP angewandt. Doppelt-Schutz: Datumsgrenze `< 2025-12-01` (App besitzt alles ab Dez 2025) **plus** partieller Unique-Index `(user_id, extern_id)`.

**Tech Stack:** Python 3.9 (pandas, openpyxl — beide vorhanden), Supabase Postgres, Muster wie `Datenbank/import/extract_reinigungen.py`. Tests = `python <script>.py --selftest` (assert-basiert, Projekt-Konvention; KEIN pytest).

**Referenz-Spec:** `docs/superpowers/specs/2026-07-12-historie-backfill-werkstattauftraege-design.md`

**Gelockte Fakten (bei der Erstellung geprüft):**
- Excel-Pfad (verifiziert, alle 37 Blätter ladbar): `D:/01_SBS_Projer_GmbH/00_SBS_Projer_70.xlsm`
- `USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'` (Daniel; identisch zu `extract_reinigungen.py`)
- `CUTOFF = 2025-12-01` (App-Daten aller 5 Tabellen beginnen Dez 2025 → null Überlappung)
- Excel-Betragsfelder sind **netto** (2019-Summe trifft je Kategorie exakt das Auswertung-Blatt).
- CHECK-Constraints: `stoerungen.anlage_typ ∈ {konventionell,heigenie,orion,david}` (Excel David/Konventionell/Heigenie/Orion → `.lower()` mappt 1:1); `stoerungen.status ∈ {offen,in_bearbeitung,behoben,nicht_behebbar}`; `montagen.montage_typ ∈ {neumontage,demontage,abaenderung,heigenie_service,anlass,spesen,aufwandsentschaedigung}` (Excel Neumontage/Abänderung/Demontage); `montagen.status ∈ {geplant,in_bearbeitung,abgeschlossen,abgebrochen}`; `eigenauftraege.status ∈ {behoben,nicht_behebbar,nachbearbeitung_noetig}`; `eroeffnungsreinigungen.art ∈ {eroeffnung,endreinigung}` (Excel Eröffnung/Endreinigung); `pikett_dienste`-CHECK `datum_ende >= datum_start`.
- `betrieb_id` ist nullable bei stoerungen/montagen/eroeffnungsreinigungen; **NOT NULL** bei eigenauftraege → Migration lockert es.

**Excel-Spalten-Indizes (0-basiert, Header Zeile 1):**
- Störung: [0]ID, [1]ID Betrieb, [2]Datum, [3]Betrieb, [4]Ort, [5]Bergkunde, [7]Störungsnummer, [9]Anlagentyp, [10]Bemerkung, [11]Total Störung
- Montage: [0]ID, [1]ID Betrieb, [2]Datum, [4]Betrieb, [5]Ort, [6]Montagetyp, [7]Bemerkung, [8]Anzahl Stunden, [10]Betrag
- Eigenauftrag: [0]ID, [1]ID Betrieb, [2]Datum, [3]Störungsnummer, [4]Betrieb, [5]Ort, [6]Beschreibung, [8]Total
- EE_Reinigung: [0]ID, [1]ID Betrieb, [2]Datum, [4]Betrieb, [5]Ort, [6]Bergkunde, [7]Eröffnung/Endreinigung, [8]Rechnungsbetrag
- Pikett: [0]ID, [1]Datum, [3]Feiertage, [4]Betrag

**Verifikations-Zielwerte (Anzahl / Netto-Total CHF, aus Excel-Blatt „Auswertung"):**
```
Jahr  Störung          Eigenauftrag  Eröffn+Endr   Montage          Pikett
2019  106 / 12878.5    23 / 840      7 / 420       63 / 18712.5     8 / 2225
2020  131 / 16405      20 / 600      12 / 720      84 / 21068.8     12 / 3000
2021  151 / 19605.8    17 / 510      7 / 495       82 / 14461.2     9 / 1620
2022  179 / 22975      23 / 690      25 / 1500     143 / 26040      16 / 2960
2023  149 / 20270      12 / 420      34 / 2265     113 / 22755      15 / 2480
2024  152 / 21916.4    4 / 120       26 / 1710     106 / 23603.1    18 / 3200
```
(2025 nur bis 30.11. → wird NICHT gegen die Excel-Jahreszeile geprüft, da diese Dez enthält.)

---

## File Structure

- **Migration:** `Datenbank/migrations/135_werkstatt_extern_id.sql` — `extern_id` + `quelle` + partielle Unique-Indizes auf den 5 Tabellen; `eigenauftraege.betrieb_id` nullable.
- **Betrieb-Index:** `Datenbank/import/in/betriebe.json` — aktueller Export (id/name/ort) aller App-Betriebe (Input für `match_betriebe.py`).
- **Import-Skript:** `Datenbank/import/extract_werkstatt.py` — liest 5 Blätter, transformiert, schreibt `out/03_stoerungen.sql`, `out/04_montagen.sql`, `out/05_eigenauftraege.sql`, `out/06_ee_reinigung.sql`, `out/07_pikett.sql` + druckt Verifikations-Report. `--selftest` mit assert-Tests.
- **Anwendung:** SQL aus `out/` via Supabase-MCP (`execute_sql`) einspielen (durch den ausführenden Agenten/Claude, kein Skript-DB-Zugriff — psycopg2 hat DNS-Probleme).

---

## Task 1: Migration — extern_id / quelle / Unique-Index / eigenauftraege nullable

**Files:**
- Create: `Datenbank/migrations/135_werkstatt_extern_id.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 135_werkstatt_extern_id.sql
-- Backfill-Infrastruktur: stabiler Import-Schlüssel + Idempotenz für die
-- 5 Werkstatt-Tabellen (analog reinigungen.extern_id/quelle).
ALTER TABLE stoerungen              ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE montagen                ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE eigenauftraege          ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE eroeffnungsreinigungen  ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE pikett_dienste          ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;

-- Partielle Unique-Indizes: Idempotenz für Import-Zeilen, Live-Zeilen (extern_id NULL) ausgenommen.
CREATE UNIQUE INDEX IF NOT EXISTS uq_stoerungen_extern     ON stoerungen             (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_montagen_extern       ON montagen               (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_eigenauftraege_extern ON eigenauftraege         (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_ee_extern             ON eroeffnungsreinigungen (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_pikett_extern         ON pikett_dienste         (user_id, extern_id) WHERE extern_id IS NOT NULL;

-- Waisen-Eigenaufträge (Betrieb nicht in App) importierbar machen (konsistent mit Schwester-Tabellen).
ALTER TABLE eigenauftraege ALTER COLUMN betrieb_id DROP NOT NULL;
```

- [ ] **Step 2: Migration auf Prod anwenden**

Via Supabase-MCP `apply_migration` (name `135_werkstatt_extern_id`, project_id `pltbaqqwpnmdajwgnhpd`) mit obigem SQL.

- [ ] **Step 3: Anwendung verifizieren**

Via MCP `execute_sql`:
```sql
SELECT table_name, column_name FROM information_schema.columns
WHERE column_name IN ('extern_id','quelle')
  AND table_name IN ('stoerungen','montagen','eigenauftraege','eroeffnungsreinigungen','pikett_dienste')
ORDER BY table_name, column_name;
SELECT is_nullable FROM information_schema.columns WHERE table_name='eigenauftraege' AND column_name='betrieb_id';
```
Expected: 10 Spalten-Zeilen (5×extern_id + 5×quelle); `betrieb_id` is_nullable = `YES`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/135_werkstatt_extern_id.sql
git commit -m "feat(db): Migration 135 — extern_id/quelle + Unique-Index fuer Werkstatt-Backfill"
```

---

## Task 2: Aktuellen Betrieb-Index exportieren (`in/betriebe.json`)

Der bestehende `match_betriebe.py` liest `in/betriebe.json`. Diese Datei neu aus der aktuellen DB erzeugen (enthält die vom Reinigungen-Import angelegten „geschlossenen" Betriebe → hohe Trefferquote).

**Files:**
- Create/Overwrite: `Datenbank/import/in/betriebe.json`

- [ ] **Step 1: Betriebe aus DB exportieren**

Via MCP `execute_sql`:
```sql
SELECT json_agg(json_build_object('id', id, 'name', name, 'ort', coalesce(ort,''))) AS j
FROM betriebe;
```

- [ ] **Step 2: Ergebnis nach `Datenbank/import/in/betriebe.json` schreiben**

Den zurückgegebenen JSON-Array (Feld `j`) unverändert als Datei-Inhalt speichern (UTF-8).

- [ ] **Step 3: match_betriebe-Selftest gegen die neuen Daten**

Run: `cd Datenbank/import && python match_betriebe.py`
Expected: `OK <n> Betriebe` mit n ~ 400 (Assertion `len(real) > 250`).

- [ ] **Step 4: Commit**

```bash
git add Datenbank/import/in/betriebe.json
git commit -m "chore(import): aktuellen Betrieb-Index fuer Werkstatt-Backfill exportiert"
```

---

## Task 3: Skript-Grundgerüst + gemeinsame Helfer + Störung-Transform

**Files:**
- Create: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: Failing selftest schreiben (Grundgerüst + Störung)**

```python
"""Excel-Werkstatt-Aufträge (2019 - 30.11.2025) -> Batch-SQL nach ./out/.
Aufruf: python extract_werkstatt.py            -> schreibt out/03..07 + Report
        python extract_werkstatt.py --selftest
Idempotent: INSERT ... ON CONFLICT (user_id, extern_id) DO NOTHING.
"""
import datetime as dt
import os
import sys

import pandas as pd

from match_betriebe import build_betrieb_index, match

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = r"D:/01_SBS_Projer_GmbH/00_SBS_Projer_70.xlsm"
OUT = os.path.join(HERE, "out")
USER_ID = "1e1ec2dd-7836-4d8e-8256-c5649d994ee2"
CUTOFF = pd.Timestamp("2025-12-01")

ANLAGE_TYP = {"david": "david", "konventionell": "konventionell",
              "heigenie": "heigenie", "orion": "orion"}
MONTAGE_TYP = {"neumontage": "neumontage", "abänderung": "abaenderung",
               "demontage": "demontage"}
EE_ART = {"eröffnung": "eroeffnung", "endreinigung": "endreinigung"}


def _txt(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    s = str(v).strip()
    return None if s in ("", "nan", "None", "NaT", "-") else s


def _num(v):
    s = _txt(v)
    if s is None:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _q(s):
    return "NULL" if s is None else "'" + str(s).replace("'", "''") + "'"


def _bid(name, ort, rows, aliase):
    """Betrieb-UUID oder None (Waise). None -> betrieb_id=NULL, zaehlt trotzdem."""
    b, _score = match(name or "", ort or "", rows, aliase)
    return b


def _rows_before_cutoff(sheet, datum_col):
    """Alle Excel-Zeilen des Blatts mit gueltigem Datum < CUTOFF (als DataFrame-Iter)."""
    df = pd.read_excel(XLSM, sheet_name=sheet, header=0, engine="openpyxl")
    out = []
    for _, r in df.iterrows():
        d = r.iloc[datum_col]
        if pd.isna(d):
            continue
        d = pd.Timestamp(d)
        if d >= CUTOFF or d.year < 2019:
            continue
        out.append((d, r))
    return out


def build_stoerungen(rows, aliase):
    """-> (head_sql, [value_tuple_str, ...]). Netto = 'Total Störung' (col 11)."""
    vals = []
    for d, r in _rows_before_cutoff("Störung", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        bid = _bid(_txt(r.iloc[3]), _txt(r.iloc[4]), rows, aliase)
        typ = ANLAGE_TYP.get((_txt(r.iloc[9]) or "").lower())
        netto = _num(r.iloc[11])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(typ), _q(_txt(r.iloc[10]) or "-"), _q(_txt(r.iloc[7])),
            "'behoben'", "false",
            ("NULL" if netto is None else str(netto)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO stoerungen (id,user_id,betrieb_id,datum,anlage_typ,"
            "problem_beschreibung,stoerungsnummer,status,ist_kilometerabrechnung,"
            "preis_netto,abgerechnet,quelle,extern_id) VALUES\n")
    return head, vals


def _selftest():
    assert _num("67.85") == 67.85 and _num("-") is None and _num(None) is None
    assert _q("a'b") == "'a''b'"
    assert ANLAGE_TYP.get("heigenie") == "heigenie"
    assert MONTAGE_TYP.get("abänderung") == "abaenderung"
    assert EE_ART.get("eröffnung") == "eroeffnung"
    rows, aliase = build_betrieb_index()
    _h, v = build_stoerungen(rows, aliase)
    # 2019: 106 Zeilen, Netto-Summe 12878.5 (aus Auswertung-Blatt)
    v2019 = [x for x in v if ",'2019-" in x]
    assert len(v2019) == 106, len(v2019)
    print("OK stoerungen", len(v))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
```

- [ ] **Step 2: Selftest laufen lassen (muss zunächst grün sein für Störung-Count)**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: `OK stoerungen <N>` (N = alle Störung-Zeilen 2019 bis < Dez 2025, keine feste Zahl) und die **Assertion `len(v2019)==106`** (exakte 2019-Anzahl aus dem Auswertung-Blatt) grün. Falls `len(v2019)` abweicht → Spaltenindex/Cutoff prüfen.

- [ ] **Step 3: Netto-Summen-Assertion für Störung 2019-2024 ergänzen**

Ergänze in `_selftest()` vor `print`:
```python
    def netto_sum(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                parts = x.rstrip(")").split(",")
                p = parts[-4]  # preis_netto-Position (…,preis_netto,abgerechnet,quelle,extern)
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    ziel = {2019: 12878.5, 2020: 16405, 2021: 19605.8, 2022: 22975, 2023: 20270, 2024: 21916.4}
    for j, soll in ziel.items():
        got = netto_sum(v, j)
        assert abs(got - soll) < 0.05, (j, got, soll)
```

- [ ] **Step 4: Selftest erneut laufen lassen**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: `OK stoerungen 830` (alle Netto-Assertions 2019-2024 grün). Falls eine Jahres-Summe abweicht → Netto-Feld ist evtl. brutto: dann `_num(r.iloc[11]) / (1.081 if d.year>=2024 else 1.077)` prüfen (Erwartung: nicht nötig).

- [ ] **Step 5: Commit**

```bash
git add Datenbank/import/extract_werkstatt.py
git commit -m "feat(import): Werkstatt-Backfill Grundgeruest + Stoerung-Transform (Netto-Abnahme 2019-2024)"
```

---

## Task 4: Montage-Transform

**Files:**
- Modify: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: `build_montagen` ergänzen**

```python
def build_montagen(rows, aliase):
    """Netto = 'Betrag' (col 10) -> kosten_arbeit. montage_typ Pflicht."""
    vals = []
    for d, r in _rows_before_cutoff("Montage", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        typ = MONTAGE_TYP.get((_txt(r.iloc[6]) or "").lower(), "abaenderung")
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        netto = _num(r.iloc[10])
        std = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(typ), _q(_txt(r.iloc[7]) or "-"),
            ("NULL" if std is None else str(std)),
            ("NULL" if netto is None else str(netto)),
            "'abgeschlossen'", "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO montagen (id,user_id,betrieb_id,datum,montage_typ,"
            "beschreibung,dauer_stunden,kosten_arbeit,status,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals
```

- [ ] **Step 2: Selftest für Montage ergänzen**

In `_selftest()` vor `print`:
```python
    _h, vm = build_montagen(rows, aliase)
    zielm = {2019: 18712.5, 2020: 21068.8, 2021: 14461.2, 2022: 26040, 2023: 22755, 2024: 23603.1}
    def netto_sum_m(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-4]  # kosten_arbeit
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielm.items():
        assert abs(netto_sum_m(vm, j) - soll) < 0.05, (j, netto_sum_m(vm, j), soll)
```

- [ ] **Step 3: Selftest laufen lassen**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: alle Montage-Netto-Assertions 2019-2024 grün.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/import/extract_werkstatt.py
git commit -m "feat(import): Montage-Transform (Netto-Abnahme 2019-2024)"
```

---

## Task 5: Eigenauftrag-Transform

**Files:**
- Modify: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: `build_eigenauftraege` ergänzen**

```python
def build_eigenauftraege(rows, aliase):
    """Netto = 'Total' (col 8) -> pauschale. problem_beschreibung Pflicht."""
    vals = []
    for d, r in _rows_before_cutoff("Eigenauftrag", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        netto = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(_txt(r.iloc[6]) or "-"), _q(_txt(r.iloc[3])), "'behoben'",
            ("NULL" if netto is None else str(netto)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO eigenauftraege (id,user_id,betrieb_id,datum,"
            "problem_beschreibung,stoerungsnummer,status,pauschale,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals
```

- [ ] **Step 2: Selftest ergänzen**

```python
    _h, ve = build_eigenauftraege(rows, aliase)
    ziele = {2019: 840, 2020: 600, 2021: 510, 2022: 690, 2023: 420, 2024: 120}
    def nse(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-4]  # pauschale
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in ziele.items():
        assert abs(nse(ve, j) - soll) < 0.05, (j, nse(ve, j), soll)
```

- [ ] **Step 3: Selftest laufen lassen**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: Eigenauftrag-Assertions grün.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(import): Eigenauftrag-Transform (Netto-Abnahme 2019-2024)"
```

---

## Task 6: Eröffnung/Endreinigung-Transform

**Files:**
- Modify: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: `build_ee` ergänzen**

```python
def build_ee(rows, aliase):
    """Netto = 'Rechnungsbetrag' (col 8) -> preis. art Pflicht (eroeffnung/endreinigung)."""
    vals = []
    for d, r in _rows_before_cutoff("EE_Reinigung", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        art = EE_ART.get((_txt(r.iloc[7]) or "").lower())
        if art is None:
            continue  # ohne gueltige Art nicht importierbar (art NOT NULL)
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        berg = (_txt(r.iloc[6]) or "").lower() == "ja"
        preis = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(art), ("true" if berg else "false"),
            ("NULL" if preis is None else str(preis)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO eroeffnungsreinigungen (id,user_id,betrieb_id,datum,"
            "art,ist_bergkunde,preis,abgerechnet,quelle,extern_id) VALUES\n")
    return head, vals
```

- [ ] **Step 2: Selftest ergänzen**

```python
    _h, vee = build_ee(rows, aliase)
    zielee = {2019: 420, 2020: 720, 2021: 495, 2022: 1500, 2023: 2265, 2024: 1710}
    def nsee(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-4]  # preis
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielee.items():
        assert abs(nsee(vee, j) - soll) < 0.05, (j, nsee(vee, j), soll)
```

- [ ] **Step 3: Selftest laufen lassen**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: EE-Assertions grün. (Falls eine Summe abweicht → prüfen, ob Zeilen ohne gültige Art fälschlich Betrag tragen.)

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(import): Eroeffnung/Endreinigung-Transform (Netto-Abnahme 2019-2024)"
```

---

## Task 7: Pikett-Transform

**Files:**
- Modify: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: `build_pikett` ergänzen** (Datum in col 1; kein Betrieb; datum_ende = datum_start)

```python
def build_pikett(rows, aliase):
    """Netto = 'Betrag' (col 4) -> pauschale_gesamt. Datum col 1 -> datum_start/-ende."""
    vals = []
    for d, r in _rows_before_cutoff("Pikett", 1):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        betrag = _num(r.iloc[4])
        feiertage = _num(r.iloc[3])
        ft = 0 if feiertage is None else int(feiertage)
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(d.date().isoformat()),
            _q(d.date().isoformat()), _q(extern), str(ft),
            ("NULL" if betrag is None else str(betrag)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO pikett_dienste (id,user_id,datum_start,datum_ende,"
            "referenz_nr,anzahl_feiertage,pauschale_gesamt,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals
```

- [ ] **Step 2: Selftest ergänzen**

```python
    _h, vp = build_pikett(rows, aliase)
    zielp = {2019: 2225, 2020: 3000, 2021: 1620, 2022: 2960, 2023: 2480, 2024: 3200}
    def nsp(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x.split(",")[2]:  # datum_start-Position
                p = x.rstrip(")").split(",")[-4]  # pauschale_gesamt
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielp.items():
        assert abs(nsp(vp, j) - soll) < 0.05, (j, nsp(vp, j), soll)
```

- [ ] **Step 3: Selftest laufen lassen**

Run: `cd Datenbank/import && python extract_werkstatt.py --selftest`
Expected: Pikett-Assertions grün.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(import): Pikett-Transform (Netto-Abnahme 2019-2024)"
```

---

## Task 8: `run()` — SQL-Dateien schreiben + Verifikations-Report (Gesamt-Abnahme)

**Files:**
- Modify: `Datenbank/import/extract_werkstatt.py`

- [ ] **Step 1: `run()` + `_write` ergänzen und in `__main__` verdrahten**

```python
def _write(fname, head, vals):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, fname)
    with open(path, "w", encoding="utf-8") as f:
        if vals:
            f.write(head + ",\n".join(vals)
                    + "\nON CONFLICT (user_id, extern_id) WHERE extern_id IS NOT NULL DO NOTHING;\n")
    return len(vals)


def run():
    rows, aliase = build_betrieb_index()
    n = {}
    n["stoerungen"] = _write("03_stoerungen.sql", *build_stoerungen(rows, aliase))
    n["montagen"] = _write("04_montagen.sql", *build_montagen(rows, aliase))
    n["eigenauftraege"] = _write("05_eigenauftraege.sql", *build_eigenauftraege(rows, aliase))
    n["ee"] = _write("06_ee_reinigung.sql", *build_ee(rows, aliase))
    n["pikett"] = _write("07_pikett.sql", *build_pikett(rows, aliase))
    print("Geschrieben:", n, "-> Datenbank/import/out/")
```

Und `__main__` erweitern:
```python
if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        run()
```

- [ ] **Step 2: Skript real laufen lassen (Dateien erzeugen)**

Run: `cd Datenbank/import && python extract_werkstatt.py`
Expected: `Geschrieben: {'stoerungen': …, 'montagen': …, 'eigenauftraege': …, 'ee': …, 'pikett': …} -> …/out/`
(Genaue Zahlen ergeben sich aus den Blättern < Dez 2025. Plausibilität: stoerungen ≈ 850, montagen ≈ 570,
eigenauftraege ≈ 99, ee ≈ 111, pikett ≈ 78 — die exakte Abnahme erfolgt über die Netto-Summen in Step 2 der
Selftests und den DB-Query in Task 9.)

- [ ] **Step 3: SQL-Dateien sichten (Stichprobe)**

Run: `head -3 Datenbank/import/out/03_stoerungen.sql`
Expected: `INSERT INTO stoerungen (…) VALUES` gefolgt von `(gen_random_uuid(),'1e1ec2dd…',…)`-Zeilen; Datei endet auf `ON CONFLICT … DO NOTHING;`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/import/extract_werkstatt.py
git commit -m "feat(import): run() schreibt out/03..07 SQL mit ON CONFLICT DO NOTHING"
```

---

## Task 9: Import anwenden + DB-Verifikation + App-Sichtung

**Files:** (keine Code-Änderung; Ausführung + Verifikation)

- [ ] **Step 1: SQL einspielen (idempotent)**

Jede Datei `out/03_stoerungen.sql` … `out/07_pikett.sql` via Supabase-MCP `execute_sql` (project_id `pltbaqqwpnmdajwgnhpd`) anwenden. Bei >1000 Zeilen ggf. datei-intern splitten. `ON CONFLICT DO NOTHING` macht Wiederholungen gefahrlos.

- [ ] **Step 2: DB-Aggregat gegen Excel-Zielwerte prüfen**

Via MCP `execute_sql`:
```sql
SELECT 'stoerung' k, extract(year from datum)::int j, count(*) n, round(sum(preis_netto)::numeric,2) netto
  FROM stoerungen WHERE quelle='excel_import' GROUP BY j
UNION ALL SELECT 'montage', extract(year from datum)::int, count(*), round(sum(kosten_arbeit)::numeric,2)
  FROM montagen WHERE quelle='excel_import' GROUP BY 2
UNION ALL SELECT 'eigenauftrag', extract(year from datum)::int, count(*), round(sum(pauschale)::numeric,2)
  FROM eigenauftraege WHERE quelle='excel_import' GROUP BY 2
UNION ALL SELECT 'ee', extract(year from datum)::int, count(*), round(sum(preis)::numeric,2)
  FROM eroeffnungsreinigungen WHERE quelle='excel_import' GROUP BY 2
UNION ALL SELECT 'pikett', extract(year from datum_start)::int, count(*), round(sum(pauschale_gesamt)::numeric,2)
  FROM pikett_dienste WHERE quelle='excel_import' GROUP BY 2
ORDER BY k, j;
```
Expected: Für **2019-2024** exakt die Zielwerte-Tabelle (oben). 2025 nur Jan-Nov (< Excel-Jahreszeile, da Dez fehlt).

- [ ] **Step 3: Idempotenz prüfen (Re-Run gefahrlos)**

`out/03_stoerungen.sql` ein zweites Mal via MCP anwenden → Zeilenzahl in `stoerungen WHERE quelle='excel_import'` bleibt gleich (ON CONFLICT DO NOTHING). Kurz `SELECT count(*) FROM stoerungen WHERE quelle='excel_import';` vor/nach vergleichen.

- [ ] **Step 4: App-Auswertung sichten**

App live (hart neu laden) → Buchhaltung → Auswertung → Modus „Jahre": die Heineken-Spalte ist für **2019-2025** gefüllt (vorher nur ab Dez 2025). Kurz gegen die Excel-„Rechnung HK"-Werte querlesen (2019 ≈ 50'034 inkl.).

- [ ] **Step 5: ToDo.md aktualisieren + Commit**

In `ToDo.md` den Auswertung-Phase-2-Eintrag: 5 Werkstatt-Kategorien backfilled ✓; offen bleiben BK-Pauschale + Heineken-Rechnungs-Abgleich.
```bash
git add ToDo.md
git commit -m "docs: ToDo — Werkstatt-Historie backfilled (Auswertung Phase 2a)"
```

---

## Offene Punkte / Grenzen (bewusst)
- **Betrieb-Zuordnung** läuft über den **bewährten Name-Matcher** (`match_betriebe.py` inkl. Alias-CSV), der
  bereits den Reinigungen-Import erfolgreich verknüpft hat — nicht über `heineken_nr` (Spec nannte es als
  Option). Grund: die Werkstatt-Betriebe sind eine Teilmenge der Reinigungen-Betriebe (alle bereits in der App
  angelegt), und die **Betrieb-Zuordnung beeinflusst die Auswertung nicht** (aggregiert nach Datum/Kategorie).
  Eine `heineken_nr`-Präzisierung ist bei Bedarf ein späterer, unkritischer Zusatz.
- **BK-Pauschale** und **Heineken-Rechnungs-Abgleich** sind separate Folgeschritte (nicht in diesem Plan).
- **Material-Positionen** werden nicht importiert (für Auswertung irrelevant).
- **Betrieb-Waisen** (Betrieb nicht in App) → `betrieb_id=NULL`; zählen korrekt in der Auswertung, erscheinen in Listen als „Unbekannt". Der Report/DB-Query zeigt, wie viele.
