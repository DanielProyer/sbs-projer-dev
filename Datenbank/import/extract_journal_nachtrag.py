"""Nachtrag-Import: Journal-Buchungen NACH dem 28.11.2025, NUR Ausgaben/Lohn/diverse
(ohne Reinigungen + Zahlungseingänge — die hat die App schon bzw. kommen via camt).
Erzeugt out/journal_nachtrag_NNN.sql.

Aufruf: python extract_journal_nachtrag.py [--selftest]
"""
import os
import sys

import pandas as pd

from extract_journal import (USER_ID, XLSM, _num, _txt, _sql_str, _sql_int,
                             _sql_num, OUT_DIR, BATCH)

START = pd.Timestamp('2025-11-28')  # exklusiv (> START)

# Geschäftsfälle, die die App selbst bucht / die Zahlungseingänge sind -> NICHT importieren.
EXCLUDE_GF = {
    'Reinigung Rechnung', 'Reinigung Bar',
    'Zahlungseingang Reinigung', 'Zahlungseingang Heineken', 'Zahlungseingang Kasse',
    'Heineken Rechnung',
}

# Belegnummern, die bereits in der DB existieren (vermeidet Dubletten).
EXCLUDE_BELEG = {'190_2025_11_30_FrGe_00377270'}


def transform(row):
    datum = row['Datum']
    if pd.isna(datum):
        return None
    datum = pd.Timestamp(datum)
    if datum <= START:
        return None
    gf = _txt(row.get('Unnamed: 3')) or ''
    if gf in EXCLUDE_GF:
        return None
    if _txt(row.get('ID BS')) in EXCLUDE_BELEG:
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

    bem = _txt(row.get('Bemerkung')) or gf or 'Import Nachtrag'
    return {
        'user_id': USER_ID, 'datum': datum.strftime('%Y-%m-%d'),
        'belegnummer': _txt(row.get('ID BS')),
        'soll_konto': int(soll), 'haben_konto': int(haben),
        'mwst_konto': int(mwst_konto) if mwst_konto is not None else None,
        'betrag_netto': netto, 'mwst_satz': satz, 'mwst_betrag': mwst, 'betrag_brutto': brutto,
        'beschreibung': bem, 'belegordner': _txt(row.get('Belegordner')),
        'geschaeftsjahr': datum.year, 'gf': gf,
    }


def run():
    os.makedirs(OUT_DIR, exist_ok=True)
    df = pd.read_excel(XLSM, sheet_name='Journal', header=0, engine='openpyxl')
    rows = [t for t in (transform(r.to_dict()) for _, r in df.iterrows()) if t]

    cols = ('user_id,datum,belegnummer,soll_konto,haben_konto,mwst_konto,betrag_netto,'
            'mwst_satz,mwst_betrag,betrag_brutto,beschreibung,belegordner,geschaeftsjahr,ist_storniert')
    n = 0
    for i in range(0, len(rows), BATCH):
        vals = []
        for r in rows[i:i + BATCH]:
            vals.append('(' + ','.join([
                _sql_str(r['user_id']), _sql_str(r['datum']), _sql_str(r['belegnummer']),
                _sql_int(r['soll_konto']), _sql_int(r['haben_konto']), _sql_int(r['mwst_konto']),
                _sql_num(r['betrag_netto']), _sql_num(r['mwst_satz']), _sql_num(r['mwst_betrag']),
                _sql_num(r['betrag_brutto']), _sql_str(r['beschreibung']), _sql_str(r['belegordner']),
                _sql_int(r['geschaeftsjahr']), 'false']) + ')')
        with open(os.path.join(OUT_DIR, f'journal_nachtrag_{n:02d}.sql'), 'w', encoding='utf-8') as f:
            f.write(f"INSERT INTO buchungen ({cols}) VALUES\n" + ',\n'.join(vals) + ';\n')
        n += 1

    from collections import Counter
    gfc = Counter(r['gf'] for r in rows)
    print(f'Nachtrag-Zeilen: {len(rows)}  Brutto-Summe: {round(sum(r["betrag_brutto"] for r in rows),2)}  Batches: {n}')
    print('--- nach Geschäftsfall ---')
    for gf, c in gfc.most_common():
        print(f'  {c:4}  {gf}')


def _selftest():
    assert transform({'Datum': pd.Timestamp('2025-11-20'), 'Unnamed: 3': 'Spesen (Kasse)',
                      'Betrag': 10, 'Soll Konto': 5820, 'Haben Konto': 1000,
                      'MWST Konto': '-', 'MWST-Satz': '-'}) is None  # vor START
    assert transform({'Datum': pd.Timestamp('2025-12-05'), 'Unnamed: 3': 'Reinigung Bar',
                      'Betrag': 10, 'Soll Konto': 1000, 'Haben Konto': 3400,
                      'MWST Konto': '-', 'MWST-Satz': '-'}) is None  # ausgeschlossen
    t = transform({'Datum': pd.Timestamp('2025-12-02'), 'Unnamed: 3': 'Spesen (Kasse)',
                   'Betrag': 15.70, 'Soll Konto': 5820, 'Haben Konto': 1000,
                   'MWST Konto': 1171, 'MWST-Satz': 2.6, 'ID BS': '031_2025_12_02_MiEs_00001570',
                   'Bemerkung': 'Mittagessen', 'Belegordner': '030_Spesen'})
    assert t and t['soll_konto'] == 5820 and t['betrag_brutto'] == 15.70
    print('selftest OK')


if __name__ == '__main__':
    _selftest() if '--selftest' in sys.argv else run()
