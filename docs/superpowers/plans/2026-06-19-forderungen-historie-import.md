# Forderungen-Historie-Import (TP1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alle Reinigungen 2019–Nov 2025 + Protokoll-/Zahlungs-Scans + die echten Forderungen (offen/bezahlt/abgeschrieben) aus dem Excel automatisch in die App importieren — ohne neue Buchungen, reversibel, mit Treue-Gate.

**Architecture:** Python-ETL (pandas) liest das Excel-Sheet „Reinigung", mappt Betriebe (exakt/fuzzy/alias, fehlende als inaktiv neu), erzeugt Batch-INSERT-SQL für `betriebe`/`reinigungen`/`rechnungen`/`rechnungs_positionen` (ETL vergibt UUIDs für die Verknüpfung). Einspielen via Supabase Management-API. Separates Skript lädt alle Scans in den Storage und setzt die Pfade. Validierung gegen Excel + 1100-Saldo.

**Tech Stack:** Python 3 + pandas + openpyxl + requests (Storage-Upload); Supabase (Postgres + Storage); `npx supabase db query --linked`.

**Spec:** `docs/superpowers/specs/2026-06-19-forderungen-historie-import-design.md`

**Referenz-Muster:** `Datenbank/import/extract_journal.py` (+ `validate_import.py`) — gleiche Konventionen (USER_ID, CUTOFF, OUT_DIR, BATCH, `_num`/`_txt`, `--selftest`).

**Wichtig:** Dies läuft gegen die **Produktiv-DB**. Jeder Apply-Schritt erst nach grünem `--selftest` + Sichtprüfung der generierten SQL. Alles reversibel über `quelle='excel_import'`.

---

## Konstanten (in allen Skripten)
```python
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
CUTOFF  = '2025-12-01'   # nur Reinigungen davor (App ab Dez 2025)
XLSM    = '../../00_Buchhaltung/00_SBS_Projer_70.xlsm'  # relativ zu Datenbank/import/
SHEET   = 'Reinigung'
BELEG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/010_Reinigung'
ZAHLUNG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/020_Zahlungseingang_Reinigung'
STORAGE_BUCKET = 'reinigung-fotos'
```
Excel-Spalten (0-basiert): A0 ID Reinigung · C2 ID Anlage · D3 Datum · E4 Betrieb · F5 Ort · G6 Bergkunde · I8 Beleg · J9 Rechnungsart · K10 Einzahlungsdatum · L11 Einzahlungsbeleg · M12 Serviceart · P15 Dauer · S18 Bemerkung · T19 Total mit MwSt · U20 Total ohne MwSt.
Forderungs-Arten: `RECHNUNG_ARTEN = {'Rechnung Mail','Rechnung Post','Rechnung Tresen'}`.

---

## Task 1: Migration 100 — Import-Spalten

**Files:** Create `Datenbank/migrations/100_forderungen_import_spalten.sql`

- [ ] **Step 1: SQL**

```sql
-- 100_forderungen_import_spalten.sql
-- Spalten für den historischen Reinigungen-/Forderungs-Import (reversibel via quelle).
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS extern_id text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS extern_beleg text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS einzahlungsbeleg text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS zahlung_beleg_pfad text;
ALTER TABLE betriebe    ADD COLUMN IF NOT EXISTS quelle text;
CREATE INDEX IF NOT EXISTS idx_reinigungen_extern_id ON reinigungen(extern_id);
CREATE INDEX IF NOT EXISTS idx_rechnungen_einzahlungsbeleg ON rechnungen(einzahlungsbeleg);
```

- [ ] **Step 2: Anwenden (MCP `apply_migration`)** — name `forderungen_import_spalten`, project_id `pltbaqqwpnmdajwgnhpd`, query = obiger Inhalt. Expected `{"success":true}`.

- [ ] **Step 3: Verifizieren (`execute_sql`)**: `SELECT column_name FROM information_schema.columns WHERE table_name='rechnungen' AND column_name IN ('quelle','extern_beleg','einzahlungsbeleg','zahlung_beleg_pfad');` → 4 Zeilen.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/100_forderungen_import_spalten.sql
git commit -m "feat(db): Import-Spalten für Reinigungen-/Forderungs-Historie (Migration 100)"
```

---

## Task 2: Betrieb-Mapping (exakt/fuzzy/alias + fehlende inaktiv)

**Files:**
- Create: `Datenbank/import/match_betriebe.py`
- Create: `Datenbank/import/betrieb_aliase.csv` (leer mit Header)
- Export: `Datenbank/import/in/betriebe.csv` (aus der DB)

- [ ] **Step 1: App-Betriebe exportieren.** `execute_sql` (MCP): `SELECT id, name, ort FROM betriebe WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2';` → Ergebnis als `Datenbank/import/in/betriebe.csv` speichern (Spalten id,name,ort).

- [ ] **Step 2: Alias-CSV anlegen** `Datenbank/import/betrieb_aliase.csv`:
```csv
excel_name;betrieb_id
```

- [ ] **Step 3: Matcher schreiben** `match_betriebe.py` — liefert `match(name, ort) -> (betrieb_id | None, score)` und sammelt fehlende Betriebe:

```python
"""Mappt Excel-Betriebsnamen auf betrieb_id (exakt/fuzzy/alias).
Aufruf: python match_betriebe.py --selftest
Export: build_betrieb_index() laedt in/betriebe.csv + betrieb_aliase.csv.
"""
import csv, os, re

HERE = os.path.dirname(__file__)

def _norm(s):
    s = (s or '').lower().strip()
    return re.sub(r'\s+', ' ', s)

IGNORE = {'gmbh','ag','und','the','zum','zur','der','die','das','von','restaurant','hotel','bar'}
def _words(s):
    return {w for w in re.split(r'[\s,.\-/+&]+', _norm(s)) if len(w) >= 3 and w not in IGNORE}

def build_betrieb_index():
    rows = []
    with open(os.path.join(HERE, 'in', 'betriebe.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            rows.append({'id': r['id'], 'name': r['name'], 'ort': r.get('ort', '') or ''})
    aliase = {}
    ap = os.path.join(HERE, 'betrieb_aliase.csv')
    if os.path.exists(ap):
        with open(ap, encoding='utf-8') as f:
            for r in csv.DictReader(f, delimiter=';'):
                if r.get('excel_name') and r.get('betrieb_id'):
                    aliase[_norm(r['excel_name'])] = r['betrieb_id']
    return rows, aliase

def match(name, ort, rows, aliase):
    n = _norm(name)
    if n in aliase:
        return aliase[n], 100
    for b in rows:                                  # exakt
        if _norm(b['name']) == n:
            return b['id'], 100
    for b in rows:                                  # contains
        bn = _norm(b['name'])
        if bn and (n in bn or bn in n):
            return b['id'], 80
    nw = _words(name); best = None; bs = 0           # wort-overlap (+ort-bonus)
    for b in rows:
        ov = len(nw & _words(b['name']))
        sc = ov * 30 + (10 if _norm(b['ort']) == _norm(ort) and ort else 0)
        if ov >= 2 and sc > bs:
            bs = sc; best = b['id']
    return (best, bs) if best else (None, 0)

def _selftest():
    rows = [{'id': 'X', 'name': 'Restaurant Hemingway', 'ort': 'Chur'}]
    assert match('Hemingway', 'Chur', rows, {})[0] == 'X'
    assert match('Unbekannt XY', 'Zug', rows, {})[0] is None
    print('OK')

if __name__ == '__main__':
    _selftest()
```

- [ ] **Step 4: Selftest** `cd Datenbank/import && python match_betriebe.py --selftest` → `OK`. (Aufruf ohne Flag ruft `_selftest` ebenfalls.)

- [ ] **Step 5: Commit**

```bash
git add Datenbank/import/match_betriebe.py Datenbank/import/betrieb_aliase.csv Datenbank/import/in/betriebe.csv
git commit -m "feat(import): Betrieb-Matcher (exakt/fuzzy/alias) + Betriebe-Export"
```

---

## Task 3: Reinigungen-ETL → SQL + neue inaktive Betriebe

**Files:** Create `Datenbank/import/extract_reinigungen.py`

Erzeugt: `out/01_betriebe_neu.sql` (fehlende inaktiv), `out/02_reinigungen_*.sql`, sowie `out/reinigungen_map.csv` (extern_id → uuid, betrieb_id, betrag, art, beleg, einzahlungsbeleg, status) für Task 4 + 6. Plus `out/review_betriebe.csv`.

- [ ] **Step 1: Skript** (mirror der Boilerplate aus `extract_journal.py`: `_num`, `_txt`, Batch-Writer):

```python
"""Excel 'Reinigung' -> reinigungen + neue inaktive Betriebe (SQL).
Aufruf: python extract_reinigungen.py            -> schreibt nach ./out/
        python extract_reinigungen.py --selftest
"""
import os, csv, uuid
import pandas as pd
from match_betriebe import build_betrieb_index, match, _norm

HERE = os.path.dirname(__file__)
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
OUT = os.path.join(HERE, 'out'); os.makedirs(OUT, exist_ok=True)
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
CUTOFF = pd.Timestamp('2025-12-01')
RECHNUNG_ARTEN = {'Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen'}

def _txt(v):
    if v is None: return None
    s = str(v).strip()
    return None if s in ('', 'nan', 'None', '-') else s

def _num(v):
    s = _txt(v)
    if s is None: return None
    try: return float(s)
    except ValueError: return None

def _q(s):  # SQL-String-Escape oder NULL
    return 'NULL' if s is None else "'" + str(s).replace("'", "''") + "'"

def _dur_min(v):
    s = _txt(v)
    if not s or ':' not in s: return None
    h, m, *_ = s.split(':')
    try: return int(h) * 60 + int(m)
    except ValueError: return None

def run():
    df = pd.read_excel(XLSM, sheet_name='Reinigung', header=0, engine='openpyxl')
    cols = df.columns.tolist()
    C = {  # robuster Spaltenzugriff per Position
        'id': cols[0], 'anlage': cols[2], 'datum': cols[3], 'betrieb': cols[4], 'ort': cols[5],
        'berg': cols[6], 'beleg': cols[8], 'art': cols[9], 'einzdat': cols[10], 'einzbel': cols[11],
        'serviceart': cols[12], 'dauer': cols[15], 'bem': cols[18], 'totmwst': cols[19], 'totnetto': cols[20],
    }
    rows, aliase = build_betrieb_index()
    neue = {}        # name|ort -> {id,name,ort,letzte}
    review = []      # (name, ort, score, status)
    maprows = []     # fuer Task 4/6
    rein_sql = []

    for _, r in df.iterrows():
        extern_id = _txt(r[C['id']])
        datum = r[C['datum']]
        if extern_id is None or pd.isna(datum): continue
        datum = pd.Timestamp(datum)
        if datum >= CUTOFF: continue

        name = _txt(r[C['betrieb']]) or 'Unbekannt'
        ort = _txt(r[C['ort']]) or ''
        bid, score = match(name, ort, rows, aliase)
        if bid is None:
            key = _norm(name) + '|' + _norm(ort)
            nb = neue.get(key)
            if nb is None:
                nb = {'id': str(uuid.uuid4()), 'name': name, 'ort': ort, 'letzte': datum}
                neue[key] = nb; review.append((name, ort, 0, 'neu inaktiv'))
            else:
                nb['letzte'] = max(nb['letzte'], datum)
            bid = nb['id']
        elif score < 80:
            review.append((name, ort, score, 'unsicher'))

        rid = str(uuid.uuid4())
        brutto = _num(r[C['totmwst']]) or 0.0
        netto = _num(r[C['totnetto']]) or 0.0
        mwst = round(brutto - netto, 2)
        art = _txt(r[C['art']])
        maprows.append({
            'extern_id': extern_id, 'rid': rid, 'betrieb_id': bid, 'datum': datum.date().isoformat(),
            'brutto': brutto, 'netto': netto, 'mwst': mwst, 'art': art or '',
            'beleg': _txt(r[C['beleg']]) or '', 'einzbel': _txt(r[C['einzbel']]) or '',
            'einzdat': (pd.Timestamp(r[C['einzdat']]).date().isoformat() if _txt(r[C['einzdat']]) else ''),
        })
        rein_sql.append(
            "(" + ",".join([
                _q(rid), _q(USER_ID), _q(bid), _q(datum.date().isoformat()),
                "'reinigung'", _q(_txt(r[C['serviceart']])),
                str(_dur_min(r[C['dauer']]) if _dur_min(r[C['dauer']]) is not None else 'NULL'),
                ('true' if (_txt(r[C['berg']]) or '').lower().startswith('ja') else 'false'),
                str(netto), str(mwst), str(brutto), "'abgeschlossen'",
                ('true' if art else 'false'), _q(_txt(r[C['bem']])), "'excel_import'", _q(extern_id),
            ]) + ")"
        )

    # 01 neue inaktive Betriebe
    with open(os.path.join(OUT, '01_betriebe_neu.sql'), 'w', encoding='utf-8') as f:
        for nb in neue.values():
            f.write(
                "INSERT INTO betriebe (id,user_id,name,ort,status,inaktiv_seit,inaktiv_grund,quelle) VALUES (" +
                ",".join([_q(nb['id']), _q(USER_ID), _q(nb['name']), _q(nb['ort']), "'inaktiv'",
                          _q(nb['letzte'].date().isoformat()),
                          "'Import Historie 2019-2025 (geschlossen/Anlage demontiert)'", "'excel_import'"]) + ");\n")

    # 02 reinigungen (batched)
    HEAD = ("INSERT INTO reinigungen (id,user_id,betrieb_id,datum,service_typ,service_art,dauer_minuten,"
            "ist_bergkunde,preis_netto,preis_mwst,preis_brutto,status,abgerechnet,notizen,quelle,extern_id) VALUES\n")
    for i in range(0, len(rein_sql), 1000):
        with open(os.path.join(OUT, f'02_reinigungen_{i//1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(HEAD + ",\n".join(rein_sql[i:i+1000]) + ";\n")

    with open(os.path.join(OUT, 'reinigungen_map.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(maprows[0].keys())); w.writeheader(); w.writerows(maprows)
    with open(os.path.join(OUT, 'review_betriebe.csv'), 'w', newline='', encoding='utf-8') as f:
        csv.writer(f).writerows([('name', 'ort', 'score', 'status'), *review])

    print(f'Reinigungen: {len(rein_sql)} | neue inaktive Betriebe: {len(neue)} | review: {len(review)}')

def _selftest():
    assert _dur_min('01:15:00') == 75
    assert _num('67.85') == 67.85 and _num('-') is None
    assert _q("a'b") == "'a''b'"
    print('OK')

if __name__ == '__main__':
    import sys
    _selftest() if '--selftest' in sys.argv else run()
```

- [ ] **Step 2: Selftest** `cd Datenbank/import && python extract_reinigungen.py --selftest` → `OK`.

- [ ] **Step 3: Lauf** `python extract_reinigungen.py` → erwartet ca. „Reinigungen: 9000–9975 | neue inaktive Betriebe: N | review: M". Sichtprüfung `out/review_betriebe.csv` (unmatched/unsicher) — bekannte Varianten in `betrieb_aliase.csv` eintragen und neu laufen.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/import/extract_reinigungen.py
git commit -m "feat(import): Reinigungen-ETL + fehlende Betriebe inaktiv"
```

---

## Task 4: Rechnungen-ETL (Forderungen) → SQL

**Files:** Create `Datenbank/import/extract_rechnungen.py`

Liest `out/reinigungen_map.csv`, erzeugt für Mail/Post/Tresen je eine `rechnung` + `rechnungs_positionen`.

- [ ] **Step 1: Skript**

```python
"""out/reinigungen_map.csv -> rechnungen + rechnungs_positionen (SQL).
Aufruf: python extract_rechnungen.py [--selftest]
"""
import os, csv, uuid
from datetime import date, timedelta

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, 'out')
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
RECHNUNG_ARTEN = {'Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen'}
VERSANDART = {'Rechnung Mail': 'rechnung_mail', 'Rechnung Post': 'rechnung_post', 'Rechnung Tresen': 'rechnung_tresen'}

def _q(s):
    return 'NULL' if s in (None, '') else "'" + str(s).replace("'", "''") + "'"

def status_fuer(einzdat, einzbel):
    if (einzbel or '').strip().upper() == 'ABSCHREIBUNG':
        return 'abgeschrieben', None
    if (einzdat or '').strip():
        return 'bezahlt', einzdat
    return 'offen', None

def run():
    with open(os.path.join(OUT, 'reinigungen_map.csv'), encoding='utf-8') as f:
        rows = [r for r in csv.DictReader(f) if r['art'] in RECHNUNG_ARTEN]
    rech, pos = [], []
    for r in rows:
        rzid = str(uuid.uuid4())
        st, zdat = status_fuer(r['einzdat'], r['einzbel'])
        d = date.fromisoformat(r['datum']); faellig = (d + timedelta(days=30)).isoformat()
        rnr = (r['beleg'] or r['extern_id'])  # eindeutige Rechnungsnummer aus Beleg
        rech.append("(" + ",".join([
            _q(rzid), _q(USER_ID), _q(rnr), "'kundenrechnung'", _q(r['betrieb_id']), _q(r['datum']), _q(faellig),
            r['netto'], r['mwst'], r['brutto'], _q(st), _q(VERSANDART.get(r['art'])),
            _q(zdat), _q('excel_import'), _q(r['beleg']), _q(r['einzbel']),
        ]) + ")")
        pos.append("(" + ",".join([
            _q(str(uuid.uuid4())), _q(rzid), "1", "'reinigung'", _q(r['rid']),
            _q('Reinigung ' + r['datum']), "1", r['brutto'],
        ]) + ")")

    RHEAD = ("INSERT INTO rechnungen (id,user_id,rechnungsnummer,rechnungstyp,betrieb_id,rechnungsdatum,"
             "faelligkeitsdatum,betrag_netto,mwst_betrag,betrag_brutto,zahlungsstatus,versandart,"
             "zahlung_eingegangen_am,quelle,extern_beleg,einzahlungsbeleg) VALUES\n")
    PHEAD = ("INSERT INTO rechnungs_positionen (id,rechnung_id,position,service_typ,service_id,"
             "beschreibung,menge,einzelpreis) VALUES\n")
    for i in range(0, len(rech), 1000):
        with open(os.path.join(OUT, f'03_rechnungen_{i//1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(RHEAD + ",\n".join(rech[i:i+1000]) + ";\n")
        with open(os.path.join(OUT, f'04_positionen_{i//1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(PHEAD + ",\n".join(pos[i:i+1000]) + ";\n")
    print(f'Rechnungen: {len(rech)}')

def _selftest():
    assert status_fuer('', 'ABSCHREIBUNG')[0] == 'abgeschrieben'
    assert status_fuer('2020-02-17', '')[0] == 'bezahlt'
    assert status_fuer('', '')[0] == 'offen'
    print('OK')

if __name__ == '__main__':
    import sys
    _selftest() if '--selftest' in sys.argv else run()
```

- [ ] **Step 2: Selftest** `python extract_rechnungen.py --selftest` → `OK`.

- [ ] **Step 3: Schema-Check.** `execute_sql`: `SELECT column_name FROM information_schema.columns WHERE table_name='rechnungs_positionen' ORDER BY ordinal_position;` — bestätigen, dass die im PHEAD genutzten Spalten existieren (id, rechnung_id, position, service_typ, service_id, beschreibung, menge, einzelpreis). Falls Namen abweichen, PHEAD anpassen.

- [ ] **Step 4: Lauf** `python extract_rechnungen.py` → erwartet „Rechnungen: ~4900".

- [ ] **Step 5: Commit**

```bash
git add Datenbank/import/extract_rechnungen.py
git commit -m "feat(import): Rechnungen/Forderungen-ETL aus reinigungen_map"
```

---

## Task 5: Einspielen in die Produktiv-DB (FK-Reihenfolge)

**Files:** keine Code-Änderung (Apply-Schritt).

- [ ] **Step 1: Trockensicht.** Generierte SQL stichprobenhaft lesen (`out/01_betriebe_neu.sql`, erste 2 INSERTs je 02/03/04). Plausibilität: Beträge, Datum < 2025-12-01, betrieb_id-Referenzen.

- [ ] **Step 2: Reihenfolge anwenden** (Betriebe → Reinigungen → Rechnungen → Positionen) je Datei:
```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
npx supabase db query --linked -f Datenbank/import/out/01_betriebe_neu.sql
for f in Datenbank/import/out/02_reinigungen_*.sql; do npx supabase db query --linked -f "$f"; done
for f in Datenbank/import/out/03_rechnungen_*.sql;  do npx supabase db query --linked -f "$f"; done
for f in Datenbank/import/out/04_positionen_*.sql;  do npx supabase db query --linked -f "$f"; done
```

- [ ] **Step 3: Zähl-Verifikation (`execute_sql`)**:
```sql
SELECT
 (SELECT count(*) FROM reinigungen WHERE quelle='excel_import') AS rein,
 (SELECT count(*) FROM rechnungen  WHERE quelle='excel_import') AS rech,
 (SELECT count(*) FROM betriebe    WHERE quelle='excel_import') AS betr_neu,
 (SELECT count(*) FROM rechnungen  WHERE quelle='excel_import' AND zahlungsstatus='offen') AS offen;
```
Expected: rein ≈ ETL-Ausgabe, rech ≈ ~4900, betr_neu = N, offen ≈ ~880.

- [ ] **Step 4: Commit** (Doku des Apply, keine Codeänderung):
```bash
git commit --allow-empty -m "chore(import): Reinigungen/Forderungen-Historie in Prod eingespielt"
```

---

## Task 6: Scan-Upload + Pfade setzen

**Files:** Create `Datenbank/import/upload_scans.py`

Lädt alle `010`-PDFs (Protokoll) + `020`-PDFs (Zahlung) in den Storage und setzt `reinigungen.protokoll_foto_pfad` (über extern_id/Beleg) bzw. `rechnungen.zahlung_beleg_pfad` (über einzahlungsbeleg).

- [ ] **Step 1: Skript** (nutzt Supabase Storage REST mit Service-Key aus `.env`):

```python
"""Lädt 010-/020-Scans in den Storage und schreibt die Pfade.
Aufruf: python upload_scans.py            -> upload + UPDATE-SQL nach out/
        python upload_scans.py --selftest
Setzt SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (aus Root-.env) voraus.
"""
import os, glob, csv, requests
from urllib.parse import quote

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, 'out')
BELEG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/010_Reinigung'
ZAHLUNG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/020_Zahlungseingang_Reinigung'
BUCKET = 'reinigung-fotos'
SUPA_URL = os.environ['SUPABASE_URL']
KEY = os.environ['SUPABASE_SERVICE_ROLE_KEY']

def kern(name):  # '<prefix>_<datum>_<anlage>_<betrag>.pdf' -> '<datum>_<anlage>_<betrag>'
    base = os.path.splitext(os.path.basename(name))[0]
    p = base.split('_', 1)
    return p[1] if len(p) == 2 else base

def upload(path, dest):
    with open(path, 'rb') as fh:
        r = requests.post(f'{SUPA_URL}/storage/v1/object/{BUCKET}/{quote(dest)}',
                          headers={'Authorization': f'Bearer {KEY}', 'Content-Type': 'application/pdf',
                                   'x-upsert': 'true'}, data=fh.read())
    r.raise_for_status()
    return dest

def run():
    # 1) Index Kern -> Datei
    beleg = {kern(p): p for p in glob.glob(os.path.join(BELEG_DIR, '*.pdf'))}
    zahl  = {kern(p): p for p in glob.glob(os.path.join(ZAHLUNG_DIR, '*.pdf'))}
    upd_rein, upd_rech = [], []
    with open(os.path.join(OUT, 'reinigungen_map.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            k = kern(r['beleg']) if r['beleg'] else None
            if k and k in beleg:
                dest = f"import/010/{os.path.basename(beleg[k])}"
                upload(beleg[k], dest)
                upd_rein.append((r['rid'], dest))
            kz = kern(r['einzbel']) if r['einzbel'] else None
            if kz and kz in zahl:
                destz = f"import/020/{os.path.basename(zahl[kz])}"
                upload(zahl[kz], destz)
                upd_rech.append((r['extern_id'], destz))
    with open(os.path.join(OUT, '05_pfade_reinigungen.sql'), 'w', encoding='utf-8') as f:
        for rid, dest in upd_rein:
            f.write(f"UPDATE reinigungen SET protokoll_foto_pfad='{dest}' WHERE id='{rid}';\n")
    with open(os.path.join(OUT, '06_pfade_rechnungen.sql'), 'w', encoding='utf-8') as f:
        for extid, destz in upd_rech:
            f.write("UPDATE rechnungen SET zahlung_beleg_pfad='" + destz +
                    "' WHERE einzahlungsbeleg IS NOT NULL AND id IN "
                    "(SELECT rechnung_id FROM rechnungs_positionen WHERE service_id="
                    "(SELECT id FROM reinigungen WHERE extern_id='" + extid + "'));\n")
    print(f'Protokoll-Uploads: {len(upd_rein)} | Zahlungs-Uploads: {len(upd_rech)}')

def _selftest():
    assert kern('011_2019_05_01_0025_00019925.pdf') == '2019_05_01_0025_00019925'
    print('OK')

if __name__ == '__main__':
    import sys
    _selftest() if '--selftest' in sys.argv else run()
```

- [ ] **Step 2: Selftest** `python upload_scans.py --selftest` → `OK`.

- [ ] **Step 3: Bucket prüfen/anlegen.** `execute_sql`: `SELECT id, public FROM storage.buckets WHERE id='reinigung-fotos';` — existiert (von Reinigungs-Fotos). Falls nicht: im Supabase-Dashboard anlegen (privat).

- [ ] **Step 4: Lauf** (Root-`.env` mit SERVICE_ROLE_KEY geladen). `python upload_scans.py` → lädt ~8'197 + ~3'305 Dateien (dauert; ggf. in Tranchen). Danach Pfad-SQL anwenden:
```bash
npx supabase db query --linked -f Datenbank/import/out/05_pfade_reinigungen.sql
npx supabase db query --linked -f Datenbank/import/out/06_pfade_rechnungen.sql
```

- [ ] **Step 5: Verifizieren (`execute_sql`)**: `SELECT count(*) FROM reinigungen WHERE quelle='excel_import' AND protokoll_foto_pfad IS NOT NULL;` → ≈ Anzahl Protokoll-Uploads.

- [ ] **Step 6: Commit**

```bash
git add Datenbank/import/upload_scans.py
git commit -m "feat(import): Scan-Upload (Protokoll 010 + Zahlung 020) + Pfade"
```

---

## Task 7: Treue-Gate — Validierung gegen Excel + 1100-Saldo

**Files:** Create `Datenbank/import/validate_reinigungen_import.py`

- [ ] **Step 1: Skript** — vergleicht Excel-Erwartung gegen die DB (per `execute_sql`-Resultate, manuell/halbautomatisch):

```python
"""Erwartungswerte aus dem Excel fuer das Treue-Gate.
Aufruf: python validate_reinigungen_import.py  -> druckt SOLL-Zahlen + die Pruef-SQL.
"""
import os
import pandas as pd

HERE = os.path.dirname(__file__)
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
CUTOFF = pd.Timestamp('2025-12-01')
ARTEN = {'Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen'}

def run():
    df = pd.read_excel(XLSM, sheet_name='Reinigung', header=0, engine='openpyxl')
    c = df.columns.tolist()
    df = df[df[c[3]].notna()]
    df = df[pd.to_datetime(df[c[3]]) < CUTOFF]
    rein = len(df[df[c[0]].notna()])
    inv = df[df[c[9]].isin(ARTEN)]
    def offen(row):
        ez = str(row[c[10]]).strip(); eb = str(row[c[11]]).strip().upper()
        return eb != 'ABSCHREIBUNG' and ez in ('', 'nan', 'None', '-', 'NaT')
    off = inv[inv.apply(offen, axis=1)]
    summe_offen = round(pd.to_numeric(off[c[19]], errors='coerce').fillna(0).sum(), 2)
    print(f'SOLL Reinigungen (<2025-12): {rein}')
    print(f'SOLL Rechnungen (Mail/Post/Tresen): {len(inv)}')
    print(f'SOLL offen: {len(off)}  Summe offen brutto: {summe_offen}')
    print('--- Pruef-SQL (execute_sql) ---')
    print("SELECT count(*) FROM reinigungen WHERE quelle='excel_import';")
    print("SELECT zahlungsstatus, count(*), round(sum(betrag_brutto),2) FROM rechnungen "
          "WHERE quelle='excel_import' GROUP BY zahlungsstatus;")
    print("-- Abgleich offen vs. 1100-Detail: offene Summe sollte dem historischen Anteil des 1100-Saldos entsprechen.")

if __name__ == '__main__':
    run()
```

- [ ] **Step 2: Lauf + Abgleich** `python validate_reinigungen_import.py` → SOLL-Zahlen. Dann die gedruckten `execute_sql`-Queries ausführen und IST vs. SOLL vergleichen: Reinigungen-Anzahl, Rechnungen je Status, offene Summe. Toleranz Rundung ≤ wenige CHF.

- [ ] **Step 3: 1100-Abgleich.** `execute_sql`: Saldo Konto 1100 per 30.11.2025 ermitteln (über `BuchungService`-Logik bzw. direkt) und mit der offenen Forderungssumme plausibilisieren (Grössenordnung; exakte Übereinstimmung nicht erzwingen, da Bar/Heineken separat laufen). Abweichungen dokumentieren in `Datenbank/import/diff_reinigungen.md`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/import/validate_reinigungen_import.py Datenbank/import/diff_reinigungen.md
git commit -m "feat(import): Treue-Gate Reinigungen/Forderungen + Diff-Report"
```

---

## Task 8: Review + App-Sichtprüfung

**Files:** keine Code-Änderung.

- [ ] **Step 1: App-Klicktest (Web).** Forderungen-Hub (`/rechnungen`): historische offene Posten erscheinen (Mahnfällig-Filter, Debitoren-Kopf-Salden). Eine historische Reinigung öffnen → Protokoll-Scan sichtbar. Ein paar inaktive Betriebe prüfen (erscheinen nicht in aktiven Listen/Tourenplanung).
- [ ] **Step 2: Review-Liste** `out/review_betriebe.csv` mit Daniel durchgehen — unsichere Matches/neue inaktive Betriebe bestätigen; bei Korrekturbedarf Alias eintragen, betroffene Reinigungen/Rechnungen löschen (`quelle='excel_import'` der betroffenen) und Re-Run der betroffenen Teilmenge.
- [ ] **Step 3: Memory/ToDo** aktualisieren (Import erledigt; TP2 camt-Engine als nächstes).

---

## Rollback (jederzeit)
```sql
DELETE FROM rechnungs_positionen WHERE rechnung_id IN (SELECT id FROM rechnungen WHERE quelle='excel_import');
DELETE FROM rechnungen  WHERE quelle='excel_import';
DELETE FROM reinigungen WHERE quelle='excel_import';
DELETE FROM betriebe    WHERE quelle='excel_import';
-- Storage: Objekte unter import/010/ und import/020/ im Bucket entfernen.
```

---

## Self-Review (vom Plan-Autor)
- **Spec-Abdeckung:** Schema-Spalten (T1) ✓; Betrieb-Match + inaktiv (T2/T3, Spec 4.4) ✓; alle Reinigungen importieren (T3) ✓; Forderungen Mail/Post/Tresen + Status (T4, Spec 4.2) ✓; keine Buchungen (nur Inserts) ✓; Scans 010+020 (T6, Spec 4.1/4.3) ✓; Treue-Gate + 1100-Abgleich (T7, Spec 3/5) ✓; Reversibilität (Rollback) ✓.
- **Typ-Konsistenz:** `reinigungen_map.csv`-Felder (extern_id/rid/betrieb_id/datum/brutto/netto/mwst/art/beleg/einzbel/einzdat) in T3 erzeugt, in T4/T6 gelesen; UUIDs (rid) verbinden reinigungen↔positionen; `quelle='excel_import'` durchgängig.
- **Risiken/Offen:** rechnungs_positionen-Spaltennamen in T4-Step3 verifizieren; Betrieb-Matching-Qualität über review_betriebe.csv + Aliase iterieren; Storage-Upload in Tranchen (11k Dateien). Status-Enum `reinigungen.status='abgeschlossen'` in T3 ggf. an Bestandswerte anpassen.
- **Charakter:** Datenpipeline gegen Prod — Selftests grün + Sichtprüfung vor jedem Apply; voll reversibel.
```
