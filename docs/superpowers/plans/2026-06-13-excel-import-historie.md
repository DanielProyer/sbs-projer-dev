# Excel-Import der Buchhaltungs-Historie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die 14'552 Excel-Journal-Zeilen (< Dez 2025) 1:1 in die App-Tabelle `buchungen` importieren und Jahr für Jahr gegen eine aus dem Journal berechnete Referenz abgleichen.

**Architecture:** Einmaliger, reproduzierbarer Python-ETL (`Datenbank/import/`). `extract_journal.py` liest das Journal-Sheet, filtert/transformiert und schreibt batch-weise INSERT-SQL. Der Import wird scoped (reversibel) über die Supabase-MCP angewendet. `validate_import.py` rechnet aus dem Journal eine Referenz (gleiche SaldoExpansion-Regeln) und vergleicht sie mit den importierten Buchungen (±0.05/Konto, alle Diffs geloggt). Eine kleine Migration ergänzt 5 fehlende Konten. Kein App-Code, kein Deploy.

**Tech Stack:** Python 3 (pandas/openpyxl), Supabase MCP (`execute_sql`, `apply_migration`, project_id `pltbaqqwpnmdajwgnhpd`), PostgreSQL. Spec: [Excel-Import-Historie](../specs/2026-06-13-excel-import-historie-design.md).

**Konstanten:**
- Excel: `00_Buchhaltung/00_SBS_Projer_70.xlsm`, Sheet `Journal` (header in Zeile 0), Naht `datum < 2025-12-01`.
- Daniel `user_id = 1e1ec2dd-7836-4d8e-8256-c5649d994ee2`.
- Journal-Spalten: `ID BS, Gebucht, Geschäfftsfall, Unnamed: 3 (GF-Bezeichnung), Datum, Betrag, Kürzel, Bemerkung, Beleg, Belegordner, Soll Konto, …, Haben Konto, …, MWST Konto, …, MWST-Satz`.

---

## Task 1: Migration – 5 fehlende Konten ergänzen

**Files:**
- Create: `Datenbank/migrations/092_konten_fehlend_historie.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 092_konten_fehlend_historie.sql
-- Phase 1 Teil 2: vom Excel-Journal referenzierte, in der App fehlende Konten.
-- 8090/9100 sind Tippfehler-Konten (sollten 8900/9010 sein) → faithful importiert,
-- Korrektur in Phase 2.
INSERT INTO konten (id, user_id, kontonummer, bezeichnung, kategorie)
SELECT gen_random_uuid(), u.user_id, v.kontonummer, v.bezeichnung, v.kategorie
FROM (SELECT DISTINCT user_id FROM konten) u
CROSS JOIN (VALUES
  (2970, 'Gewinn-/Verlustvortrag',            'Eigenkapital'),
  (2980, 'Jahresgewinn/-verlust',             'Eigenkapital'),
  (5005, 'Lohnersatz (EO/KAE)',               'Lohnaufwand'),
  (8090, 'FEHLER – sollte 8900 (Phase 2)',    'Steuern'),
  (9100, 'FEHLER – sollte 9010 (Phase 2)',    'Abschluss')
) AS v(kontonummer, bezeichnung, kategorie)
WHERE NOT EXISTS (
  SELECT 1 FROM konten k WHERE k.user_id = u.user_id AND k.kontonummer = v.kontonummer
);
```

- [ ] **Step 2: Anwenden (Supabase MCP) + prüfen**

Anwenden via `mcp__supabase__apply_migration` (name `092_konten_fehlend_historie`), dann:
```sql
SELECT kontonummer, bezeichnung FROM konten WHERE kontonummer IN (2970,2980,5005,8090,9100) ORDER BY kontonummer;
```
Expected: 5 Zeilen.

- [ ] **Step 3: Commit**
```bash
git add Datenbank/migrations/092_konten_fehlend_historie.sql
git commit -m "feat(db): 5 vom Journal referenzierte Konten ergänzt (Historie-Import)"
```

---

## Task 2: extract_journal.py – Journal lesen & transformieren (mit Selbsttest)

**Files:**
- Create: `Datenbank/import/extract_journal.py`

**Verantwortung:** Journal lesen, auf `datum < 2025-12-01` filtern, Spalten mappen, netto/MWST berechnen, als Liste von Dicts zurückgeben. Enthält eine `transform_row`-Funktion (rein, testbar) + einen Selbsttest-Block.

- [ ] **Step 1: Skript schreiben**

```python
# Datenbank/import/extract_journal.py
"""Liest das Excel-Journal und transformiert es auf die buchungen-Struktur.
Aufruf: python extract_journal.py  → schreibt batched INSERT-SQL nach ./out/.
"""
import math
import os
import sys

import pandas as pd

XLSM = os.path.join(os.path.dirname(__file__), '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
CUTOFF = pd.Timestamp('2025-12-01')
OUT_DIR = os.path.join(os.path.dirname(__file__), 'out')
BATCH = 1000


def _num(v):
    """Konto/Satz robust zu float; '-'/leer → None."""
    if v is None:
        return None
    s = str(v).strip()
    if s in ('', '-', 'nan', 'None'):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def transform_row(row):
    """Eine Journal-Zeile (dict) → buchungen-dict, oder None wenn keine gültige Buchung."""
    datum = row['Datum']
    if pd.isna(datum):
        return None
    datum = pd.Timestamp(datum)
    if datum >= CUTOFF:
        return None
    brutto = _num(row['Betrag'])
    soll = _num(row['Soll Konto'])
    haben = _num(row['Haben Konto'])
    if brutto is None or soll is None or haben is None:
        return None

    satz = _num(row['MWST-Satz']) or 0.0
    mwst_konto = _num(row['MWST Konto'])
    if satz and satz != 0:
        netto = round(brutto / (1 + satz / 100), 2)
        mwst = round(brutto - netto, 2)
    else:
        netto = brutto
        mwst = 0.0
        mwst_konto = None

    bemerkung = row.get('Bemerkung')
    if bemerkung is None or str(bemerkung).strip() in ('', 'nan'):
        bemerkung = row.get('Unnamed: 3')  # GF-Bezeichnung als Fallback
    bemerkung = '' if bemerkung is None or str(bemerkung) == 'nan' else str(bemerkung).strip()
    if bemerkung == '':
        bemerkung = 'Import Historie'

    return {
        'user_id': USER_ID,
        'datum': datum.strftime('%Y-%m-%d'),
        'belegnummer': _txt(row.get('ID BS')),
        'soll_konto': int(soll),
        'haben_konto': int(haben),
        'mwst_konto': int(mwst_konto) if mwst_konto is not None else None,
        'betrag_netto': netto,
        'mwst_satz': satz,
        'mwst_betrag': mwst,
        'betrag_brutto': brutto,
        'beschreibung': bemerkung,
        'belegordner': _txt(row.get('Belegordner')),
        'geschaeftsjahr': datum.year,
        'monat': datum.month,
        'quartal': (datum.month - 1) // 3 + 1,
        'ist_storniert': False,
    }


def _txt(v):
    if v is None:
        return None
    s = str(v).strip()
    return None if s in ('', 'nan', 'None') else s


def load_rows():
    df = pd.read_excel(XLSM, sheet_name='Journal', header=0)
    out = []
    for _, r in df.iterrows():
        t = transform_row(r.to_dict())
        if t is not None:
            out.append(t)
    return out


def _sql_str(s):
    if s is None:
        return 'NULL'
    return "'" + s.replace("'", "''") + "'"


def _sql_int(v):
    return 'NULL' if v is None else str(int(v))


def _sql_num(v):
    return 'NULL' if v is None else repr(round(float(v), 2))


def write_batches(rows):
    os.makedirs(OUT_DIR, exist_ok=True)
    cols = ('user_id,datum,belegnummer,soll_konto,haben_konto,mwst_konto,betrag_netto,'
            'mwst_satz,mwst_betrag,betrag_brutto,beschreibung,belegordner,'
            'geschaeftsjahr,monat,quartal,ist_storniert')
    n = 0
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        vals = []
        for r in chunk:
            vals.append(
                '(' + ','.join([
                    _sql_str(r['user_id']),
                    _sql_str(r['datum']),
                    _sql_str(r['belegnummer']),
                    _sql_int(r['soll_konto']),
                    _sql_int(r['haben_konto']),
                    _sql_int(r['mwst_konto']),
                    _sql_num(r['betrag_netto']),
                    _sql_num(r['mwst_satz']),
                    _sql_num(r['mwst_betrag']),
                    _sql_num(r['betrag_brutto']),
                    _sql_str(r['beschreibung']),
                    _sql_str(r['belegordner']),
                    _sql_int(r['geschaeftsjahr']),
                    _sql_int(r['monat']),
                    _sql_int(r['quartal']),
                    'false',
                ]) + ')')
        sql = f"INSERT INTO buchungen ({cols}) VALUES\n" + ',\n'.join(vals) + ';\n'
        path = os.path.join(OUT_DIR, f'journal_batch_{n:02d}.sql')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(sql)
        n += 1
    return n


def _selftest():
    # netto/MWST-Residuum
    t = transform_row({'Datum': pd.Timestamp('2019-05-01'), 'Betrag': 67.85,
                       'Soll Konto': 1000, 'Haben Konto': 3400, 'MWST Konto': 2200,
                       'MWST-Satz': 7.7, 'Bemerkung': 'Test', 'ID BS': 'X', 'Belegordner': '010'})
    assert t['betrag_netto'] == 63.0, t['betrag_netto']
    assert t['mwst_betrag'] == 4.85, t['mwst_betrag']
    assert abs(t['betrag_brutto'] - t['betrag_netto'] - t['mwst_betrag']) < 0.005
    # ohne MWST
    t2 = transform_row({'Datum': pd.Timestamp('2019-03-27'), 'Betrag': 4000.0,
                        'Soll Konto': 1020, 'Haben Konto': 2800, 'MWST Konto': '-',
                        'MWST-Satz': '-', 'Bemerkung': 'StK', 'ID BS': 'Y', 'Belegordner': '990'})
    assert t2['mwst_konto'] is None and t2['mwst_betrag'] == 0.0 and t2['betrag_netto'] == 4000.0
    # Naht: ab Dez 2025 ausgeschlossen
    assert transform_row({'Datum': pd.Timestamp('2025-12-05'), 'Betrag': 10, 'Soll Konto': 1,
                          'Haben Konto': 2, 'MWST Konto': '-', 'MWST-Satz': '-',
                          'Bemerkung': 'x', 'ID BS': 'z', 'Belegordner': 'o'}) is None
    # negativer Betrag erlaubt
    t3 = transform_row({'Datum': pd.Timestamp('2020-01-01'), 'Betrag': -50.0, 'Soll Konto': 1000,
                        'Haben Konto': 3400, 'MWST Konto': '-', 'MWST-Satz': '-',
                        'Bemerkung': 'Korrektur', 'ID BS': 'k', 'Belegordner': 'o'})
    assert t3['betrag_brutto'] == -50.0
    print('selftest OK')


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        _selftest()
    else:
        rows = load_rows()
        nb = write_batches(rows)
        total = sum(r['betrag_brutto'] for r in rows)
        print(f'Zeilen: {len(rows)}  Brutto-Summe: {round(total,2)}  Batches: {nb}')
```

- [ ] **Step 2: Selbsttest laufen lassen**

Run: `cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/Datenbank/import" && python extract_journal.py --selftest`
Expected: `selftest OK`.

- [ ] **Step 3: Vollen Extrakt erzeugen + Eckwerte prüfen**

Run: `cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/Datenbank/import" && python extract_journal.py`
Expected: `Zeilen: 14552  Brutto-Summe: <Wert>  Batches: 15`. (Zeilenzahl muss 14552 sein.)

- [ ] **Step 4: Commit** (Skript + `.gitignore` für die generierten SQL-Batches)

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
printf 'out/\n' > Datenbank/import/.gitignore
git add Datenbank/import/extract_journal.py Datenbank/import/.gitignore
git commit -m "feat(import): extract_journal.py (Journal→buchungen Transformation) + Selbsttest"
```

---

## Task 3: Import anwenden (scoped, reversibel)

**Files:** keine neuen (nutzt die in Task 2 erzeugten `Datenbank/import/out/journal_batch_*.sql`).

- [ ] **Step 1: Sicherheits-DELETE (scoped) anwenden**

Via `mcp__supabase__execute_sql`:
```sql
DELETE FROM buchungen WHERE user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND datum < '2025-12-01';
```
Erwartung: erster Lauf löscht 0 Zeilen (dort liegen aktuell keine).

- [ ] **Step 2: Batches anwenden**

Für jede Datei `Datenbank/import/out/journal_batch_00.sql` … `journal_batch_14.sql`: Inhalt lesen und via `mcp__supabase__execute_sql` ausführen (eine Datei pro Aufruf). Nach jeder Datei kurz die laufende Zahl prüfen.

- [ ] **Step 3: Import verifizieren (Anzahl + Brutto-Summe)**

```sql
SELECT count(*) AS zeilen,
       round(sum(betrag_brutto)::numeric, 2) AS brutto_summe,
       min(datum) AS von, max(datum) AS bis
FROM buchungen
WHERE user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND datum < '2025-12-01';
```
Expected: `zeilen = 14552`; `brutto_summe` == der von `extract_journal.py` in Task 2/Step 3 ausgegebene Wert; `von = 2019-03-27`, `bis ≤ 2025-11-30`.

- [ ] **Step 4: Naht prüfen (native Dez-Daten unberührt)**

```sql
SELECT count(*) FROM buchungen
WHERE user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND datum >= '2025-12-01';
```
Expected: `1482` (unverändert).

---

## Task 4: validate_import.py – Treue-Gate (Pilot 2019)

**Files:**
- Create: `Datenbank/import/validate_import.py`

**Verantwortung:** Aus dem Journal die Referenz-Saldi je Konto **per-Stichtag** (Jahresende) mit denselben Regeln wie `SaldoExpansion` berechnen, und die Vergleichswerte aus den importierten `buchungen` (per SQL, via `npx supabase`) ziehen — Diff-Report. Diese Task erzeugt das Skript und prüft **2019** als Pilot.

- [ ] **Step 1: Skript schreiben**

```python
# Datenbank/import/validate_import.py
"""Vergleicht per-Konto-Saldo (Stichtag) zwischen Journal-Referenz und importierten buchungen.
Aufruf: python validate_import.py 2019-12-31
Gibt einen Diff-Report aus (Pass bei |Diff| <= 0.05/Konto; alle Diffs != 0 werden gelistet)."""
import sys
import pandas as pd
from extract_journal import load_rows

TOL = 0.05


def saldo_expansion(saldi, soll, haben, mwst_konto, netto, mwst, brutto):
    """Spiegelt lib/services/buchhaltung/saldo_expansion.dart."""
    def add(k, v):
        saldi[k] = saldi.get(k, 0.0) + v
    if mwst == 0 or mwst_konto is None:
        add(soll, brutto)
        add(haben, -brutto)
        return
    if mwst_konto // 1000 == 1:  # Vorsteuer
        add(soll, netto)
        add(mwst_konto, mwst)
        add(haben, -brutto)
    else:  # Umsatzsteuer
        add(soll, brutto)
        add(mwst_konto, -mwst)
        add(haben, -netto)


def referenz_saldi(stichtag):
    rows = load_rows()
    cut = pd.Timestamp(stichtag)
    saldi = {}
    for r in rows:
        if pd.Timestamp(r['datum']) > cut:
            continue
        saldo_expansion(saldi, r['soll_konto'], r['haben_konto'], r['mwst_konto'],
                        r['betrag_netto'], r['mwst_betrag'], r['betrag_brutto'])
    return {k: round(v, 2) for k, v in saldi.items()}


if __name__ == '__main__':
    stichtag = sys.argv[1] if len(sys.argv) > 1 else '2019-12-31'
    ref = referenz_saldi(stichtag)
    # Vergleichswerte aus der DB werden vom Controller via execute_sql geholt (siehe Step 2)
    # und hier per stdin als 'konto,saldo'-Zeilen eingelesen, falls vorhanden.
    print(f'# Referenz-Saldi per {stichtag} (Konto: Saldo)')
    for k in sorted(ref):
        print(f'{k}\t{ref[k]}')
```

- [ ] **Step 2: Referenz für 2019 erzeugen**

Run: `cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/Datenbank/import" && python validate_import.py 2019-12-31`
Expected: Liste `Konto<TAB>Saldo` (Roh-Saldo Soll−Haben, **vor** Klassen-Vorzeichenumkehr).

- [ ] **Step 3: DB-Vergleichswerte holen + vergleichen**

Vergleichswerte aus den importierten Buchungen via `mcp__supabase__execute_sql` (Roh-Saldo Soll−Haben **mit** MWST-Expansion — identische Logik wie das Skript). Da reines SQL die MWST-Expansion abbilden muss, diese Query nutzen (Stichtag 2019-12-31):
```sql
WITH b AS (
  SELECT soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto
  FROM buchungen
  WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
    AND datum <= '2019-12-31' AND NOT ist_storniert
), legs AS (
  -- ohne MWST: brutto auf Soll(+)/Haben(-)
  SELECT soll_konto AS konto, betrag_brutto AS v FROM b WHERE mwst_betrag=0 OR mwst_konto IS NULL
  UNION ALL SELECT haben_konto, -betrag_brutto FROM b WHERE mwst_betrag=0 OR mwst_konto IS NULL
  -- Vorsteuer (mwst_konto < 2000): soll netto, mwst +, haben -brutto
  UNION ALL SELECT soll_konto, betrag_netto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  UNION ALL SELECT mwst_konto, mwst_betrag   FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  UNION ALL SELECT haben_konto, -betrag_brutto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  -- Umsatzsteuer (mwst_konto >= 2000): soll brutto, mwst -, haben -netto
  UNION ALL SELECT soll_konto, betrag_brutto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
  UNION ALL SELECT mwst_konto, -mwst_betrag  FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
  UNION ALL SELECT haben_konto, -betrag_netto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
)
SELECT konto, round(sum(v)::numeric,2) AS saldo FROM legs GROUP BY konto ORDER BY konto;
```
Den DB-Output mit der Python-Referenz Konto für Konto vergleichen. **Pass:** jede Differenz ≤ 0.05. **Alle** Differenzen ≠ 0 protokollieren (Konto, Referenz, DB, Diff) in `Datenbank/import/diff_2019.md`.

- [ ] **Step 4: Pilot-Ergebnis bewerten**

Wenn alle Konten innerhalb 0.05: 2019 grün → weiter Task 5.
Wenn größere Diffs: Ursache untersuchen (häufig: verlorene Zeilen → Anzahl prüfen; Rundung → Step-3-Query vs. Python; Mapping-Fehler). **STOP & melden**, falls die Differenz nicht durch Rundung erklärbar ist.

- [ ] **Step 5: Commit**
```bash
git add Datenbank/import/validate_import.py Datenbank/import/diff_2019.md
git commit -m "feat(import): validate_import.py + Pilot-Abgleich 2019 (Treue-Gate)"
```

---

## Task 5: Abgleich übrige Jahre + Excel-Stichprobe

**Files:**
- Create: `Datenbank/import/diff_report.md`

- [ ] **Step 1: Alle Jahresenden abgleichen**

Für `2020-12-31, 2021-12-31, 2022-12-31, 2023-12-31, 2024-12-31, 2025-11-30`: jeweils `python validate_import.py <stichtag>` (Referenz) + die DB-Query aus Task 4/Step 3 mit angepasstem Stichtag, Konto-für-Konto vergleichen. Ergebnisse (Pass/Diffs) in `Datenbank/import/diff_report.md` sammeln.

- [ ] **Step 2: Per-Jahr-Erfolgsrechnung (Nettoerlös) gegenprüfen**

Pro Jahr Nettoerlös (Konto 3400, netto) Referenz vs. DB:
```sql
-- DB, Jahr 2019 (für andere Jahre Jahr anpassen):
WITH b AS (
  SELECT mwst_konto, betrag_netto, betrag_brutto, mwst_betrag, soll_konto, haben_konto
  FROM buchungen
  WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
    AND geschaeftsjahr=2019 AND NOT ist_storniert
)
SELECT round(sum(
  CASE WHEN haben_konto=3400 AND mwst_betrag<>0 AND mwst_konto>=2000 THEN betrag_netto
       WHEN haben_konto=3400 THEN betrag_brutto ELSE 0 END
  - CASE WHEN soll_konto=3400 AND mwst_betrag<>0 AND mwst_konto>=2000 THEN betrag_netto
         WHEN soll_konto=3400 THEN betrag_brutto ELSE 0 END
)::numeric,2) AS nettoerloes
FROM b;
```
Mit der Python-Referenz (Summe netto auf 3400 je Jahr) vergleichen. In `diff_report.md` festhalten.

- [ ] **Step 3: Excel-Stichprobe (Rundungs-Bestätigung)**

Aus dem Excel-Sheet `Bilanz` (oder `Hauptbuch`) zentrale Konten-Saldi zu einem im Excel sichtbaren Stichtag lesen (Python, read-only) und gegen die App-Saldi vergleichen — Konten 1020 (Bank), 1100 (Debitoren), 1170, 1171, 2200, 2800. Ziel: Bestätigung, dass meine netto/MWST-Rundung der Excel entspricht (Differenzen ≤ 0.05). Ergebnis in `diff_report.md`.

- [ ] **Step 4: Commit**
```bash
git add Datenbank/import/diff_report.md
git commit -m "feat(import): Voll-Abgleich aller Jahre + Excel-Stichprobe"
```

---

## Task 6: Abschluss

- [ ] **Step 1: Erfolgskriterien prüfen (gegen Spec §8)**
  - 14'552 Zeilen importiert; Brutto-Summe == Extrakt ✔
  - Treue-Gate: per-Konto-Saldo (Jahresenden) + per-Jahr-Nettoerlös innerhalb ±0.05; alle Diffs geloggt ✔
  - Excel-Stichprobe bestätigt Rundung ✔
  - Native Dez-Buchungen unverändert (1482) ✔

- [ ] **Step 2: Zusammenfassung in `diff_report.md`** (Status je Jahr, verbleibende toleranzgedeckte Diffs, etwaige für Phase 2 vorgemerkte Auffälligkeiten).

---

## Hinweise für die Umsetzung
- **Prod-DB-Schreibzugriff:** Import-INSERTs gehen direkt auf Prod (`buchungen`), aber **scoped** auf `datum < 2025-12-01` (dort 0 Zeilen) → reversibel via DELETE. Die nativen Dez-Daten sind durch den Filter geschützt.
- **Reihenfolge:** Task 1 (Konten) → 2 (Extrakt) → 3 (Import) → 4 (Pilot 2019) → 5 (Rest) → 6.
- **Bei unerklärlichen Diffs (Task 4/5): STOP & melden**, nicht raten — die bekannten Excel-Fehler (8090/9100, fehlende MWST-Rückbuchung) sind als Diffs ERWARTET und gehören in Phase 2, dürfen aber das Treue-Gate nicht „rot" machen, weil Referenz und Import dieselben (fehlerhaften) Zeilen enthalten → sie heben sich im Vergleich auf.
- **Folge:** Phase 2 (Aufräumen) — bekannte Fehler korrigieren, offene Forderungen abschreiben, Bilanz ausgleichen.
