# -*- coding: utf-8 -*-
"""Laedt die uebrigen Ordner aus 00_Rechnungen ins Dokumente-Modul.

Aufruf: py -3 Datenbank/import/import_rest_dokumente.py [--dry-run]

Diese acht Ordner enthalten ueberwiegend gleichartige Kleinbelege, die in
20_Buchaltung/01_Belege bereits nach Belegnummer abgelegt sind. Sie werden
deshalb je Ordner gebuendelt als ein PDF gefuehrt - auffindbar, ohne jede
einzelne Fahrbewilligung zu katalogisieren. Ausnahme: 13_Unfall_Krankheit,
dort trennen Trennblaetter die Dokumente des Schadenfalls.
"""
import csv, os, re, sys, uuid
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
load_dotenv(HERE / '.env')
USER = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
DRY = '--dry-run' in sys.argv
sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])
safe = lambda n: re.sub(r'[^A-Za-z0-9._-]', '_', n)
vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
hoch = 0
for r in csv.DictReader(open(HERE / 'rest_dokumente_katalog.csv', encoding='utf-8'), delimiter=';'):
    pfad = ROOT / '00_Rechnungen' / r['datei']
    if not pfad.exists():
        print('FEHLT', r['datei']); continue
    jahr = int(r['jahr'])
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, pfad.relative_to(ROOT).as_posix()))
    storage = f"{USER}/{r['bereich']}/{jahr}/{doc_id}_{safe(pfad.name)}"
    if storage in vorhanden:
        print('schon da', pfad.name); continue
    print(f"upload {pfad.name}  ({r['bereich']}/{r['kategorie'] or '-'})")
    if DRY: continue
    data = pfad.read_bytes()
    sb.storage.from_('dokumente').upload(storage, data,
        {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': r['bereich'], 'typ': r['typ'],
        'kategorie': r['kategorie'] or None, 'jahr': jahr, 'dokument_datum': r['datum'],
        'titel': r['titel'], 'dateiname': pfad.name, 'dateityp': 'application/pdf',
        'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1
print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
