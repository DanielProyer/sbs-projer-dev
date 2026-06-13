"""Treue-Gate: vergleicht per-Konto-Saldo (Stichtag, Roh-Saldo Soll-Haben mit
MWST-Expansion) zwischen Journal-Referenz und importierten buchungen.

Aufruf: python validate_import.py 2019-12-31 [2020-12-31 ...]
Pass bei |Diff| <= 0.05/Konto; alle Diffs != 0 werden gelistet.
"""
import json
import os
import subprocess
import sys

import pandas as pd

from extract_journal import load_rows, USER_ID

TOL = 0.05
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')

_ROWS_CACHE = None


def _rows():
    global _ROWS_CACHE
    if _ROWS_CACHE is None:
        _ROWS_CACHE = load_rows()
    return _ROWS_CACHE


def saldo_expansion(saldi, soll, haben, mwst_konto, netto, mwst, brutto):
    """Spiegelt lib/services/buchhaltung/saldo_expansion.dart (Roh-Saldo Soll-Haben)."""
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
    cut = pd.Timestamp(stichtag)
    saldi = {}
    for r in _rows():
        if pd.Timestamp(r['datum']) > cut:
            continue
        # Brutto wie in der DB auf 2 Dezimalen runden (faithful 2-Dezimal-CHF),
        # damit der Vergleich nicht durch Float-Rundungsrauschen verschmiert wird.
        saldo_expansion(saldi, r['soll_konto'], r['haben_konto'], r['mwst_konto'],
                        r['betrag_netto'], r['mwst_betrag'], round(r['betrag_brutto'], 2))
    return {k: round(v, 2) for k, v in saldi.items()}


def _db_query_sql(stichtag):
    return f"""WITH b AS (
  SELECT soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto
  FROM buchungen
  WHERE user_id='{USER_ID}' AND datum <= '{stichtag}' AND NOT ist_storniert
), legs AS (
  SELECT soll_konto AS konto, betrag_brutto AS v FROM b WHERE mwst_betrag=0 OR mwst_konto IS NULL
  UNION ALL SELECT haben_konto, -betrag_brutto FROM b WHERE mwst_betrag=0 OR mwst_konto IS NULL
  UNION ALL SELECT soll_konto, betrag_netto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  UNION ALL SELECT mwst_konto, mwst_betrag FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  UNION ALL SELECT haben_konto, -betrag_brutto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto<2000
  UNION ALL SELECT soll_konto, betrag_brutto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
  UNION ALL SELECT mwst_konto, -mwst_betrag FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
  UNION ALL SELECT haben_konto, -betrag_netto FROM b WHERE mwst_betrag<>0 AND mwst_konto IS NOT NULL AND mwst_konto>=2000
)
SELECT konto, round(sum(v)::numeric,2) AS saldo FROM legs GROUP BY konto ORDER BY konto;"""


def db_saldi(stichtag):
    os.makedirs(OUT, exist_ok=True)
    qf = os.path.join(OUT, f'dbq_{stichtag}.sql')
    with open(qf, 'w', encoding='utf-8') as f:
        f.write(_db_query_sql(stichtag))
    res = subprocess.run(
        f'npx --yes supabase db query --linked --output-format json -f "{qf}"',
        shell=True, capture_output=True, text=True, cwd=ROOT)
    out = res.stdout
    start = out.find('{')
    if start < 0:
        raise RuntimeError('Keine JSON-Antwort:\n' + out + '\n' + res.stderr)
    data = json.loads(out[start:])
    return {int(r['konto']): float(r['saldo']) for r in data['rows']}


def vergleich(stichtag):
    ref = referenz_saldi(stichtag)
    db = db_saldi(stichtag)
    konten = sorted(set(ref) | set(db))
    diffs = []
    for k in konten:
        rv = ref.get(k, 0.0)
        dv = db.get(k, 0.0)
        d = round(rv - dv, 2)
        if abs(d) > 0.0001:
            diffs.append((k, rv, dv, d))
    over = [x for x in diffs if abs(x[3]) > TOL]
    status = 'PASS' if not over else 'FAIL'
    lines = [f'## {stichtag}: {status} — {len(konten)} Konten, {len(diffs)} Diff!=0, {len(over)} > {TOL}']
    for k, rv, dv, d in diffs:
        flag = '  <== UEBER TOLERANZ' if abs(d) > TOL else ''
        lines.append(f'- Konto {k}: ref={rv} db={dv} diff={d}{flag}')
    report = '\n'.join(lines)
    print(report)
    return report, over


if __name__ == '__main__':
    stichtage = sys.argv[1:] or ['2019-12-31']
    all_reports = []
    any_fail = False
    for s in stichtage:
        rep, over = vergleich(s)
        all_reports.append(rep)
        if over:
            any_fail = True
        print()
    sys.exit(1 if any_fail else 0)
