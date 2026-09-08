# -*- coding: utf-8 -*-
"""Laedt die Gruendungsunterlagen ins Dokumente-Modul (Bereich vertraege).

Aufruf: py -3 Datenbank/import/import_gruendung_dokumente.py [--dry-run] [--ersetzen]

Quelle: 00_Rechnungen/17_Firmengruendung/aufbereitet/*.pdf, aus 80 Handy-Fotos
gebaut. Die Kategorie steht je Dokument im Katalog (gruendung, franchise,
fahrzeug) - anders als bei den Sozialversicherungs-Ordnern liegen hier
verschiedene Vertragsarten nebeneinander.
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
QUELLE = ROOT / '00_Rechnungen' / '17_Firmengründung' / 'aufbereitet'

if '--ersetzen' in sys.argv:
    alt = sb.table('dokumente').select('id,storage_pfad').eq('user_id', USER) \
            .eq('bereich', 'vertraege').execute().data
    print(f'{len(alt)} bestehende Vertrags-Dokumente werden ersetzt')
    if alt and not DRY:
        sb.storage.from_('dokumente').remove([d['storage_pfad'] for d in alt])
        for d in alt:
            sb.table('dokumente').delete().eq('id', d['id']).execute()

vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
hoch = 0
for r in csv.DictReader(open(HERE / 'gruendung_dokumente_katalog.csv', encoding='utf-8'), delimiter=';'):
    jahr = int(r['datum'][:4])
    pfad = QUELLE / f"{jahr}_{r['detail']}.pdf"
    if not pfad.exists():
        print('FEHLT', pfad.name); continue
    rel = pfad.relative_to(ROOT).as_posix()
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, rel))
    storage = f'{USER}/vertraege/{jahr}/{doc_id}_{safe(pfad.name)}'
    if storage in vorhanden:
        print('schon da', pfad.name); continue
    print(f"upload {pfad.name}  ({r['kategorie']}/{r['typ']})")
    if DRY:
        continue
    data = pfad.read_bytes()
    sb.storage.from_('dokumente').upload(storage, data,
        {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'vertraege', 'typ': r['typ'],
        'kategorie': r['kategorie'], 'jahr': jahr, 'dokument_datum': r['datum'],
        'referenz': 'CHE-413.083.919', 'titel': r['titel'], 'dateiname': pfad.name,
        'dateityp': 'application/pdf', 'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1
print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
