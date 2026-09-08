# -*- coding: utf-8 -*-
"""Laedt die aufbereiteten PK-/BVG-Dokumente ins Dokumente-Modul (Bereich versicherungen).

Aufruf:  py -3 Datenbank/import/import_pk_dokumente.py [--dry-run]

Quelle: 00_Rechnungen/06_PK/aufbereitet/*.pdf, gebaut aus den 105 Handy-Fotos
(Dokumentgrenzen ueber die eingelegten Trennblaetter erkannt). Metadaten:
pk_dokumente_katalog.csv. Braucht Datenbank/import/.env mit SUPABASE_URL und
SUPABASE_SERVICE_ROLE_KEY. Idempotent ueber eine aus dem Dateipfad abgeleitete
Dokument-ID - ein zweiter Lauf laedt nichts doppelt.
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

def safe(n):
    return re.sub(r'[^A-Za-z0-9._-]', '_', n)

QUELLE = ROOT / '00_Rechnungen' / '06_PK' / 'aufbereitet'
katalog = list(csv.DictReader(open(HERE / 'pk_dokumente_katalog.csv', encoding='utf-8'), delimiter=';'))
vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}

hoch = 0
for r in katalog:
    betrag = r['betrag'].replace('.', '').zfill(8) if r['betrag'] else '00000000'
    pfad = QUELLE / f"{r['datum']}_{r['typ']}_{betrag}.pdf"
    if not pfad.exists():
        print('FEHLT', pfad.name); continue
    jahr = int(r['datum'][:4])
    rel = f"00_Rechnungen/06_PK/aufbereitet/{pfad.name}"
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, rel))
    storage = f"{USER}/versicherungen/{jahr}/{doc_id}_{safe(pfad.name)}"
    if storage in vorhanden:
        print('schon da', pfad.name); continue
    print('upload', pfad.name, '->', r['typ'], jahr)
    if DRY:
        continue
    data = pfad.read_bytes()
    sb.storage.from_('dokumente').upload(
        storage, data, {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'versicherungen', 'typ': r['typ'],
        'kategorie': 'bvg', 'jahr': jahr, 'dokument_datum': r['datum'],
        'betrag': float(r['betrag']) if r['betrag'] else None,
        'referenz': '2/452968', 'titel': r['titel'], 'dateiname': pfad.name,
        'dateityp': 'application/pdf', 'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1
print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
