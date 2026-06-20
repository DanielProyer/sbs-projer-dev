"""Gezielte Verknüpfung der 5 manuell bestätigten Altfälle (Subcode/Datum minimal
abweichend). Aufruf: python link_altfaelle.py
"""
import glob
import os
import sys
import time
from urllib.parse import quote

import requests

from link_belege import load_env, BELEG_BASE, BUCKET, USER_ID

# (Kategorie-Ordner, Datei-Stamm, Ziel-Buchung-ID)
MAP = [
    ('030_Spesen', '033_2024_06_25_MiEs_00001115', 'f878c430-af0c-4f39-9b98-762ca6bb2129'),
    ('030_Spesen', '033_2024_02_05_MiEs_00001930', '894c2f36-6ab2-40e6-aa4c-a4f882713e0e'),
    ('030_Spesen', '031_2023_11_23_MiEs_00002350', '4ed9885f-139c-49d9-8569-4c1608cb9b35'),
    ('040_Tanken', '043_2021_08_19_Benz_00001750', 'cd3bd0a1-87c1-4970-81e1-239a797f956a'),
    ('040_Tanken', '041_2024_02_01_AuVi_00004400', '5cfb7b5c-342e-4e8c-9960-6ea5980e4dfd'),
]


def main():
    env = load_env()
    url, key = env.get('SUPABASE_URL'), env.get('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        sys.exit('FEHLT: .env')
    sess = requests.Session()
    sess.headers.update({'apikey': key, 'Authorization': f'Bearer {key}'})

    for folder, stem, bid in MAP:
        hits = glob.glob(os.path.join(BELEG_BASE, folder, stem + '.*'))
        if not hits:
            print('DATEI FEHLT:', stem)
            continue
        path = hits[0]
        ext = os.path.splitext(path)[1].lower().lstrip('.')
        ct = {'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
              'png': 'image/png'}.get(ext, 'application/octet-stream')
        storage_pfad = f"{USER_ID}/{bid}/import/{os.path.basename(path)}"
        ok = False
        for _ in range(6):
            try:
                with open(path, 'rb') as fh:
                    r = sess.post(f'{url}/storage/v1/object/{BUCKET}/{quote(storage_pfad)}',
                                  headers={'Content-Type': ct, 'x-upsert': 'true'}, data=fh.read(), timeout=60)
                if r.status_code in (200, 201):
                    ins = sess.post(f'{url}/rest/v1/buchungs_belege',
                                    headers={'Content-Type': 'application/json', 'Prefer': 'return=minimal'},
                                    json={'user_id': USER_ID, 'buchung_id': bid,
                                          'dateiname': os.path.basename(path), 'dateityp': ext,
                                          'storage_pfad': storage_pfad, 'beleg_quelle': 'manuell'})
                    if ins.status_code in (200, 201, 204):
                        print('OK  ', os.path.basename(path), '->', bid)
                        ok = True
                        break
                time.sleep(2)
            except requests.RequestException:
                time.sleep(3)
        if not ok:
            print('FEHLER', os.path.basename(path))


if __name__ == '__main__':
    main()
