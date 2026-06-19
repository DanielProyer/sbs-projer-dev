"""Excel 'Reinigung' -> reinigungen + neue geschlossene Betriebe (Batch-SQL).
Aufruf: python extract_reinigungen.py            -> schreibt nach ./out/
        python extract_reinigungen.py --selftest

Erzeugt:
  out/01_betriebe_neu.sql        fehlende Betriebe (status='geschlossen')
  out/02_reinigungen_NNN.sql     alle Reinigungen < 2025-12-01
  out/reinigungen_map.csv        extern_id->uuid + Betrag/Art/Beleg/Status (fuer FI4/FI6)
  out/review_betriebe.csv        neu angelegt / unsicher gematcht
"""
import csv
import datetime as dt
import os
import sys
import uuid

import pandas as pd

from match_betriebe import build_betrieb_index, match, _norm

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
OUT = os.path.join(HERE, 'out')
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
CUTOFF = pd.Timestamp('2025-12-01')
RECHNUNG_ARTEN = {'Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen'}
GRUND = 'Import Historie 2019-2025 (geschlossen/Anlage demontiert)'


def _txt(v):
    if v is None:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    s = str(v).strip()
    return None if s in ('', 'nan', 'None', 'NaT') else s


def _num(v):
    s = _txt(v)
    if s is None:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _q(s):
    """SQL-Literal: None -> NULL, sonst escaped String."""
    return 'NULL' if s is None else "'" + str(s).replace("'", "''") + "'"


def _dur_min(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    if isinstance(v, dt.time):
        return v.hour * 60 + v.minute
    if isinstance(v, pd.Timedelta):
        return int(v.total_seconds() // 60)
    s = _txt(v)
    if s and ':' in s:
        p = s.split(':')
        try:
            return int(p[0]) * 60 + int(p[1])
        except ValueError:
            return None
    return None


def _satz(d):
    """MwSt-Normalsatz datumsabhaengig (Reinigung = immer Normalsatz)."""
    return 8.1 if d.year >= 2024 else 7.7


def _status_zdat(einzdat, einzbel):
    """bezahlt nur bei echtem 020-Zahlbeleg + Datum; sonst offen.
    ABSCHREIBUNG-Marker (Dummy-Zukunftsdatum) zaehlt NICHT als bezahlt -> offen,
    da diese Forderungen real nicht abgeschrieben wurden (Vorgabe Daniel)."""
    eb = _txt(einzbel) or ''
    ez = _txt(einzdat)
    if ez and eb.startswith('020'):
        try:
            return 'bezahlt', pd.Timestamp(einzdat).date().isoformat()
        except (ValueError, TypeError):
            return 'bezahlt', None
    return 'offen', None


def run():
    os.makedirs(OUT, exist_ok=True)
    df = pd.read_excel(XLSM, sheet_name='Reinigung', header=0, engine='openpyxl')
    c = df.columns.tolist()
    I = {'id': c[0], 'anlage': c[2], 'datum': c[3], 'betrieb': c[4], 'ort': c[5],
         'berg': c[6], 'beleg': c[8], 'art': c[9], 'einzdat': c[10], 'einzbel': c[11],
         'serviceart': c[12], 'dauer': c[15], 'bem': c[18], 'totmwst': c[19],
         'totnetto': c[20], 'abschr': c[32]}
    rows, aliase = build_betrieb_index()

    neue = {}          # key -> {id,name,ort,letzte}
    review = []        # (name, ort, score, status)
    maprows = []
    rein_vals = []

    for _, r in df.iterrows():
        extern_id = _txt(r[I['id']])
        datum = r[I['datum']]
        if extern_id is None or pd.isna(datum):
            continue
        datum = pd.Timestamp(datum)
        if datum >= CUTOFF:
            continue

        name = _txt(r[I['betrieb']]) or 'Unbekannt'
        ort = _txt(r[I['ort']]) or ''
        bid, score = match(name, ort, rows, aliase)
        if bid is None:
            key = _norm(name) + '|' + _norm(ort)
            nb = neue.get(key)
            if nb is None:
                nb = {'id': str(uuid.uuid4()), 'name': name, 'ort': ort, 'letzte': datum}
                neue[key] = nb
                review.append((name, ort, 0, 'neu geschlossen'))
            else:
                nb['letzte'] = max(nb['letzte'], datum)
            bid = nb['id']
        elif score < 80:
            review.append((name, ort, score, 'unsicher'))

        rid = str(uuid.uuid4())
        brutto = _num(r[I['totmwst']]) or 0.0
        netto = _num(r[I['totnetto']]) or 0.0
        mwst = round(brutto - netto, 2)
        art = _txt(r[I['art']])
        st, zdat = _status_zdat(r[I['einzdat']], r[I['einzbel']])
        abgerechnet = bool(art) and art != 'Gratis (Kulanz)'
        dauer = _dur_min(r[I['dauer']])
        berg = (_txt(r[I['berg']]) or '').lower() == 'ja'

        maprows.append({
            'extern_id': extern_id, 'rid': rid, 'betrieb_id': bid,
            'datum': datum.date().isoformat(), 'brutto': brutto, 'netto': netto,
            'mwst': mwst, 'art': art or '', 'beleg': _txt(r[I['beleg']]) or '',
            'einzbel': _txt(r[I['einzbel']]) or '', 'status': st, 'zdat': zdat or '',
        })
        rein_vals.append('(' + ','.join([
            _q(rid), _q(USER_ID), _q(bid), _q(datum.date().isoformat()),
            "'reinigung'", _q(_txt(r[I['serviceart']])),
            (str(dauer) if dauer is not None else 'NULL'),
            ('true' if berg else 'false'),
            str(netto), str(mwst), str(brutto), str(_satz(datum)),
            "'abgeschlossen'", ('true' if abgerechnet else 'false'),
            _q(_txt(r[I['bem']])), "'excel_import'", _q(extern_id),
        ]) + ')')

    with open(os.path.join(OUT, '01_betriebe_neu.sql'), 'w', encoding='utf-8') as f:
        for nb in neue.values():
            f.write('INSERT INTO betriebe (id,user_id,name,ort,status,inaktiv_seit,'
                    'inaktiv_grund,quelle) VALUES (' + ','.join([
                        _q(nb['id']), _q(USER_ID), _q(nb['name']), _q(nb['ort'] or None),
                        "'geschlossen'", _q(nb['letzte'].date().isoformat()),
                        _q(GRUND), "'excel_import'"]) + ');\n')

    head = ('INSERT INTO reinigungen (id,user_id,betrieb_id,datum,service_typ,'
            'service_art,dauer_minuten,ist_bergkunde,preis_netto,preis_mwst,'
            'preis_brutto,mwst_satz,status,abgerechnet,notizen,quelle,extern_id) VALUES\n')
    for i in range(0, len(rein_vals), 1000):
        with open(os.path.join(OUT, f'02_reinigungen_{i // 1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(head + ',\n'.join(rein_vals[i:i + 1000]) + ';\n')

    with open(os.path.join(OUT, 'reinigungen_map.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(maprows[0].keys()))
        w.writeheader()
        w.writerows(maprows)
    with open(os.path.join(OUT, 'review_betriebe.csv'), 'w', newline='', encoding='utf-8') as f:
        csv.writer(f, delimiter=';').writerows([('name', 'ort', 'score', 'status'), *review])

    inv = sum(1 for m in maprows if m['art'] in RECHNUNG_ARTEN)
    print(f'Reinigungen: {len(rein_vals)} | Forderungen(M/P/T): {inv} | '
          f'neue Betriebe: {len(neue)} | review-Zeilen: {len(review)}')


def _selftest():
    assert _dur_min('01:15:00') == 75
    assert _dur_min(dt.time(1, 5)) == 65
    assert _num('67.85') == 67.85 and _num('-') is None
    assert _q("a'b") == "'a''b'"
    assert _satz(pd.Timestamp('2024-03-01')) == 8.1
    assert _satz(pd.Timestamp('2023-12-31')) == 7.7
    assert _status_zdat('2025-12-29', 'ABSCHREIBUNG')[0] == 'offen'   # nicht abgeschrieben
    assert _status_zdat('2019-05-21', '020_x') == ('bezahlt', '2019-05-21')
    assert _status_zdat('2019-01-01', '011_x')[0] == 'offen'          # kein 020-Zahlbeleg
    assert _status_zdat(None, None)[0] == 'offen'
    print('OK')


if __name__ == '__main__':
    _selftest() if '--selftest' in sys.argv else run()
