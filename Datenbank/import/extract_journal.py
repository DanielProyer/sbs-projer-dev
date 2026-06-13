"""Liest das Excel-Journal und transformiert es auf die buchungen-Struktur.
Aufruf: python extract_journal.py  -> schreibt batched INSERT-SQL nach ./out/.
        python extract_journal.py --selftest
"""
import os
import sys

import pandas as pd

XLSM = os.path.join(os.path.dirname(__file__), '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
CUTOFF = pd.Timestamp('2025-12-01')
OUT_DIR = os.path.join(os.path.dirname(__file__), 'out')
BATCH = 1000


def _num(v):
    """Konto/Satz robust zu float; '-'/leer -> None."""
    if v is None:
        return None
    s = str(v).strip()
    if s in ('', '-', 'nan', 'None'):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _txt(v):
    if v is None:
        return None
    s = str(v).strip()
    return None if s in ('', 'nan', 'None') else s


def transform_row(row):
    """Eine Journal-Zeile (dict) -> buchungen-dict, oder None wenn keine gueltige Buchung."""
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
    # monat/quartal sind GENERATED (aus datum) -> nicht einfuegen.
    cols = ('user_id,datum,belegnummer,soll_konto,haben_konto,mwst_konto,betrag_netto,'
            'mwst_satz,mwst_betrag,betrag_brutto,beschreibung,belegordner,'
            'geschaeftsjahr,ist_storniert')
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
                    'false',
                ]) + ')')
        sql = f"INSERT INTO buchungen ({cols}) VALUES\n" + ',\n'.join(vals) + ';\n'
        path = os.path.join(OUT_DIR, f'journal_batch_{n:02d}.sql')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(sql)
        n += 1
    return n


def _selftest():
    t = transform_row({'Datum': pd.Timestamp('2019-05-01'), 'Betrag': 67.85,
                       'Soll Konto': 1000, 'Haben Konto': 3400, 'MWST Konto': 2200,
                       'MWST-Satz': 7.7, 'Bemerkung': 'Test', 'ID BS': 'X', 'Belegordner': '010'})
    assert t['betrag_netto'] == 63.0, t['betrag_netto']
    assert t['mwst_betrag'] == 4.85, t['mwst_betrag']
    assert abs(t['betrag_brutto'] - t['betrag_netto'] - t['mwst_betrag']) < 0.005
    t2 = transform_row({'Datum': pd.Timestamp('2019-03-27'), 'Betrag': 4000.0,
                        'Soll Konto': 1020, 'Haben Konto': 2800, 'MWST Konto': '-',
                        'MWST-Satz': '-', 'Bemerkung': 'StK', 'ID BS': 'Y', 'Belegordner': '990'})
    assert t2['mwst_konto'] is None and t2['mwst_betrag'] == 0.0 and t2['betrag_netto'] == 4000.0
    assert transform_row({'Datum': pd.Timestamp('2025-12-05'), 'Betrag': 10, 'Soll Konto': 1,
                          'Haben Konto': 2, 'MWST Konto': '-', 'MWST-Satz': '-',
                          'Bemerkung': 'x', 'ID BS': 'z', 'Belegordner': 'o'}) is None
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
        print(f'Zeilen: {len(rows)}  Brutto-Summe: {round(total, 2)}  Batches: {nb}')
