"""out/reinigungen_map.csv -> rechnungen + rechnungs_positionen (Batch-SQL).
Nur Forderungen (Rechnungsart Mail/Post/Tresen). Aufruf:
  python extract_rechnungen.py [--selftest]
"""
import csv
import os
import sys
import uuid
from datetime import date, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
RECHNUNG_ARTEN = {'Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen'}
VERSANDART = {'Rechnung Mail': 'rechnung_mail', 'Rechnung Post': 'rechnung_post',
              'Rechnung Tresen': 'rechnung_tresen'}


def _q(s):
    return 'NULL' if s in (None, '') else "'" + str(s).replace("'", "''") + "'"


def run():
    with open(os.path.join(OUT, 'reinigungen_map.csv'), encoding='utf-8') as f:
        rows = [r for r in csv.DictReader(f) if r['art'] in RECHNUNG_ARTEN]

    rech, pos = [], []
    for r in rows:
        rzid = str(uuid.uuid4())
        d = date.fromisoformat(r['datum'])
        faellig = (d + timedelta(days=30)).isoformat()
        rech.append('(' + ','.join([
            _q(rzid), _q(USER_ID), _q(r['beleg']), "'kundenrechnung'", _q(r['betrieb_id']),
            _q(r['datum']), _q(faellig), r['netto'], r['mwst'], r['brutto'],
            _q(r['status']), _q(VERSANDART[r['art']]), _q(r['zdat'] or None),
            "'excel_import'", _q(r['beleg']), _q(r['einzbel'] or None),
        ]) + ')')
        pos.append('(' + ','.join([
            _q(str(uuid.uuid4())), _q(USER_ID), _q(rzid), '1', "'reinigung'", _q(r['rid']),
            _q('Reinigung ' + r['datum']), r['netto'], r['mwst'], r['brutto'],
        ]) + ')')

    rhead = ('INSERT INTO rechnungen (id,user_id,rechnungsnummer,rechnungstyp,betrieb_id,'
             'rechnungsdatum,faelligkeitsdatum,betrag_netto,mwst_betrag,betrag_brutto,'
             'zahlungsstatus,versandart,zahlung_eingegangen_am,quelle,extern_beleg,'
             'einzahlungsbeleg) VALUES\n')
    phead = ('INSERT INTO rechnungs_positionen (id,user_id,rechnung_id,position,service_typ,'
             'service_id,beschreibung,betrag_netto,mwst_betrag,betrag_brutto) VALUES\n')
    for i in range(0, len(rech), 1000):
        with open(os.path.join(OUT, f'03_rechnungen_{i // 1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(rhead + ',\n'.join(rech[i:i + 1000]) + ';\n')
        with open(os.path.join(OUT, f'04_positionen_{i // 1000:03d}.sql'), 'w', encoding='utf-8') as f:
            f.write(phead + ',\n'.join(pos[i:i + 1000]) + ';\n')

    from collections import Counter
    cnt = Counter(r['status'] for r in rows)
    print(f'Rechnungen: {len(rech)} | ' + ' '.join(f'{k}={v}' for k, v in sorted(cnt.items())))


def _selftest():
    assert _q("a'b") == "'a''b'" and _q('') == 'NULL' and _q(None) == 'NULL'
    from datetime import date as d
    assert (d.fromisoformat('2019-05-01') + timedelta(days=30)).isoformat() == '2019-05-31'
    print('OK')


if __name__ == '__main__':
    _selftest() if '--selftest' in sys.argv else run()
