"""Verknüpft Ausgaben-/Spesenbelege mit Buchungen (Tabelle buchungs_belege).
Match: Dateiname-Stamm == buchungen.belegnummer (exakt); Fallback ohne Datum
(Code_Kürzel_Betrag, nur wenn eindeutig) für Spesen/Tanken mit Platzhalter-Datum.

Aufruf:
  python link_belege.py            -> DRY-RUN: Abdeckung pro Kategorie, kein Upload
  python link_belege.py --apply    -> Upload in Bucket 'buchungs-belege' + DB-Records
Voraussetzung: Datenbank/import/.env mit SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY.
Resumebar: out/belege_uploaded.log.
"""
import os
import sys
import glob
import time
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
BELEG_BASE = r'D:/01_SBS_Projer_GmbH/20_Buchaltung/01_Belege'
BUCKET = 'buchungs-belege'
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'

# Vom User gewünschte Kategorien (Ordnername)
KATEGORIEN = [
    '030_Spesen', '040_Tanken', '050_Parkgebuehren', '060_Bussen',
    '070_Fahrbewilligung', '080_Autoreperaturen', '090_Bueromaterial',
    '100_Werkzeug_Material', '110_Berufskleider', '120_Kaffee', '130_Kehricht',
    '140_Breifmarken', '150_Internet', '170_Software',
]


def load_env():
    env = {}
    p = os.path.join(HERE, '.env')
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                env[k.strip()] = v.strip()
    return env


def stem(name):
    return os.path.splitext(os.path.basename(name))[0]


def fuzzy_key(beleg):
    """Code_Kürzel_Betrag (Datum weggelassen) — für Platzhalter-Daten."""
    p = beleg.split('_')
    if len(p) >= 6:
        return p[0] + '_' + p[4] + '_' + p[5]
    return None


def fetch_buchungen(url, key):
    import requests
    sess = requests.Session()
    sess.headers.update({'apikey': key, 'Authorization': f'Bearer {key}'})
    rows = []
    step = 1000
    for off in range(0, 100000, step):
        page = None
        for attempt in range(8):  # DNS flackert -> Retry
            try:
                r = sess.get(f'{url}/rest/v1/buchungen',
                             params={'select': 'id,belegnummer', 'limit': step, 'offset': off},
                             timeout=60)
                r.raise_for_status()
                page = r.json()
                break
            except requests.RequestException:
                time.sleep(4)
        if page is None:
            sys.exit('Abbruch: Supabase nicht erreichbar (DNS).')
        rows.extend(page)
        if len(page) < step:
            break
    return rows


def build_index(buchungen):
    exact = {}          # belegnummer -> id
    fuzzy = {}          # code_kuerzel_betrag -> [ids]
    for b in buchungen:
        bn = b.get('belegnummer')
        if not bn:
            continue
        exact[bn] = b['id']
        fk = fuzzy_key(bn)
        if fk:
            fuzzy.setdefault(fk, []).append(b['id'])
    return exact, fuzzy


def match_file(s, exact, fuzzy):
    if s in exact:
        return exact[s], 'exakt'
    fk = fuzzy_key(s)
    if fk and len(fuzzy.get(fk, [])) == 1:
        return fuzzy[fk][0], 'fuzzy'
    if fk and len(fuzzy.get(fk, [])) > 1:
        return None, 'mehrdeutig'
    return None, 'kein_match'


def run(apply=False):
    os.makedirs(OUT, exist_ok=True)
    env = load_env()
    url, key = env.get('SUPABASE_URL'), env.get('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        sys.exit('FEHLT: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in Datenbank/import/.env')

    print('Lade Buchungen ...')
    buchungen = fetch_buchungen(url, key)
    exact, fuzzy = build_index(buchungen)
    print(f'  {len(buchungen)} Buchungen, {len(exact)} mit Belegnummer\n')

    done_path = os.path.join(OUT, 'belege_uploaded.log')
    done = set(open(done_path, encoding='utf-8').read().split('\n')) if os.path.exists(done_path) else set()
    sess = None
    if apply:
        import requests
        sess = requests.Session()
        sess.headers.update({'apikey': key, 'Authorization': f'Bearer {key}'})
        done_f = open(done_path, 'a', encoding='utf-8')

    total = {'exakt': 0, 'fuzzy': 0, 'mehrdeutig': 0, 'kein_match': 0}
    print(f'{"Kategorie":28} {"Dateien":>7} {"exakt":>6} {"fuzzy":>6} {"mehrd.":>6} {"offen":>6}')
    review = []
    for kat in KATEGORIEN:
        folder = os.path.join(BELEG_BASE, kat)
        if not os.path.isdir(folder):
            print(f'{kat:28}  ORDNER FEHLT')
            continue
        files = sorted(glob.glob(os.path.join(folder, '*.pdf')) +
                       glob.glob(os.path.join(folder, '*.jpg')) +
                       glob.glob(os.path.join(folder, '*.jpeg')) +
                       glob.glob(os.path.join(folder, '*.png')))
        c = {'exakt': 0, 'fuzzy': 0, 'mehrdeutig': 0, 'kein_match': 0}
        for f in files:
            s = stem(f)
            bid, how = match_file(s, exact, fuzzy)
            c[how] += 1
            total[how] += 1
            if how in ('mehrdeutig', 'kein_match'):
                review.append((kat, os.path.basename(f), how))
            if apply and bid:
                _upload_and_link(sess, url, key, f, bid, done, done_f)
        print(f'{kat:28} {len(files):7} {c["exakt"]:6} {c["fuzzy"]:6} {c["mehrdeutig"]:6} {c["kein_match"]:6}')

    print(f'\nSUMME: exakt {total["exakt"]}, fuzzy {total["fuzzy"]}, '
          f'mehrdeutig {total["mehrdeutig"]}, kein Match {total["kein_match"]}')
    if review:
        with open(os.path.join(OUT, 'belege_review.csv'), 'w', encoding='utf-8') as f:
            f.write('kategorie;datei;grund\n')
            for r in review:
                f.write(';'.join(r) + '\n')
        print(f'Review-Liste: out/belege_review.csv ({len(review)} Einträge)')


def _upload_and_link(sess, url, key, path, bid, done, done_f):
    dest = f"import/{os.path.basename(path)}"
    marker = f"{bid}|{dest}"
    if marker in done:
        return
    ext = os.path.splitext(path)[1].lower().lstrip('.')
    ct = {'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
          'png': 'image/png'}.get(ext, 'application/octet-stream')
    storage_pfad = f"{USER_ID}/{bid}/{dest}"
    for attempt in range(5):
        try:
            with open(path, 'rb') as fh:
                r = sess.post(f'{url}/storage/v1/object/{BUCKET}/{quote(storage_pfad)}',
                              headers={'Content-Type': ct, 'x-upsert': 'true'}, data=fh.read(), timeout=60)
            if r.status_code in (200, 201):
                # DB-Record (idempotent: vorher prüfen wäre teuer; upsert via storage_pfad-unique nicht garantiert)
                ins = sess.post(f'{url}/rest/v1/buchungs_belege',
                                headers={'Content-Type': 'application/json', 'Prefer': 'return=minimal'},
                                json={'user_id': USER_ID, 'buchung_id': bid,
                                      'dateiname': os.path.basename(path), 'dateityp': ext,
                                      'storage_pfad': storage_pfad, 'beleg_quelle': 'manuell'})
                if ins.status_code in (200, 201, 204):
                    done_f.write(marker + '\n')
                    done_f.flush()
                    return
            time.sleep(2)
        except Exception:
            time.sleep(3)


if __name__ == '__main__':
    run(apply='--apply' in sys.argv)
