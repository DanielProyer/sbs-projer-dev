"""Laedt Reinigungs-Scans (010 Protokoll, 020 Zahlung) in den Supabase-Storage
und erzeugt UPDATE-SQL fuer die Pfade. Match ueber Kern '<Datum>_<Anlage>_<Betrag>'
(Datei-Praefix unterscheidet sich von der Belegnummer).

Voraussetzung: Datenbank/import/.env mit
  SUPABASE_URL=https://pltbaqqwpnmdajwgnhpd.supabase.co
  SUPABASE_SERVICE_ROLE_KEY=...        (Dashboard > Settings > API > service_role)

Aufruf:
  python upload_scans.py --selftest
  python upload_scans.py               -> Upload + out/05_pfade_*.sql / out/06_pfade_*.sql
Resumebar: bereits hochgeladene Dateien stehen in out/uploaded.log und werden uebersprungen.
"""
import csv
import glob
import os
import sys
import time
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
BELEG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/010_Reinigung'
ZAHLUNG_DIR = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege/020_Zahlungseingang_Reinigung'
BUCKET = 'reinigung-fotos'


def load_env():
    p = os.path.join(HERE, '.env')
    env = {}
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                env[k.strip()] = v.strip()
    return env


def kern(name):
    """'000_2019_05_23_0243_00000000.pdf' -> '2019_05_23_0243_00000000'."""
    base = os.path.splitext(os.path.basename(name))[0]
    parts = base.split('_', 1)
    return parts[1] if len(parts) == 2 else base


def _index(folder):
    idx = {}
    for p in glob.glob(os.path.join(folder, '*.pdf')):
        idx.setdefault(kern(p), p)  # erster Treffer gewinnt
    return idx


def run():
    import requests
    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        sys.exit('FEHLT: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in Datenbank/import/.env')

    beleg_idx, zahl_idx = _index(BELEG_DIR), _index(ZAHLUNG_DIR)
    done_path = os.path.join(OUT, 'uploaded.log')
    done = set(open(done_path, encoding='utf-8').read().split('\n')) if os.path.exists(done_path) else set()
    done_f = open(done_path, 'a', encoding='utf-8')
    sess = requests.Session()
    sess.headers.update({'Authorization': f'Bearer {key}', 'Content-Type': 'application/pdf', 'x-upsert': 'true'})

    def upload(path, dest):
        if dest in done:
            return True
        for attempt in range(5):
            try:
                with open(path, 'rb') as fh:
                    r = sess.post(f'{url}/storage/v1/object/{BUCKET}/{quote(dest)}', data=fh.read(), timeout=60)
                if r.status_code in (200, 201):
                    done_f.write(dest + '\n')
                    done_f.flush()
                    return True
                time.sleep(2)
            except requests.RequestException:
                time.sleep(3)
        return False

    upd_rein, upd_rech = [], []
    n = miss = 0
    with open(os.path.join(OUT, 'reinigungen_map.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            if r['beleg']:
                k = kern(r['beleg'])
                if k in beleg_idx:
                    dest = f"import/010/{os.path.basename(beleg_idx[k])}"
                    if upload(beleg_idx[k], dest):
                        upd_rein.append((r['rid'], dest))
                    else:
                        miss += 1
            if r['einzbel'] and r['einzbel'].upper() != 'ABSCHREIBUNG':
                kz = kern(r['einzbel'])
                if kz in zahl_idx:
                    destz = f"import/020/{os.path.basename(zahl_idx[kz])}"
                    if upload(zahl_idx[kz], destz):
                        upd_rech.append((r['beleg'], destz))
                    else:
                        miss += 1
            n += 1
            if n % 200 == 0:
                print(f'  {n} verarbeitet (Protokoll {len(upd_rein)}, Zahlung {len(upd_rech)}, Fehler {miss})')

    with open(os.path.join(OUT, '05_pfade_reinigungen.sql'), 'w', encoding='utf-8') as f:
        for rid, dest in upd_rein:
            f.write(f"UPDATE reinigungen SET protokoll_foto_pfad='{dest}' WHERE id='{rid}';\n")
    with open(os.path.join(OUT, '06_pfade_rechnungen.sql'), 'w', encoding='utf-8') as f:
        for beleg, destz in upd_rech:
            b = beleg.replace("'", "''")
            f.write(f"UPDATE rechnungen SET zahlung_beleg_pfad='{destz}' WHERE extern_beleg='{b}';\n")
    print(f'FERTIG: Protokoll-Uploads {len(upd_rein)}, Zahlungs-Uploads {len(upd_rech)}, Fehler {miss}')
    print('Danach: npx supabase db query --linked -f out/05_pfade_reinigungen.sql (und 06_...)')


def _selftest():
    assert kern('000_2019_05_23_0243_00000000.pdf') == '2019_05_23_0243_00000000'
    assert kern('020_2019_05_13_0000_00006785.pdf') == '2019_05_13_0000_00006785'
    assert kern('011_2019_05_01_0025_00019925') == '2019_05_01_0025_00019925'
    print('OK')


if __name__ == '__main__':
    _selftest() if '--selftest' in sys.argv else run()
