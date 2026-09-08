# -*- coding: utf-8 -*-
"""Laedt den Ordner 07_Versicherung ins Dokumente-Modul (Bereich versicherungen).

Aufruf: py -3 Datenbank/import/import_versicherung_dokumente.py [--dry-run]

Zwei Quellen mit je eigenem Katalog:
1. aufbereitet/*.pdf - aus 49 Handy-Fotos gebaut (versicherung_dokumente_katalog.csv)
2. die Original-PDFs aus dem myAXA-Portal (versicherung_pdf_katalog.csv)

Der Ordner enthaelt zwei Vertraege: Police 44.127.389 (Personenversicherung -
Unfallzusatz und Krankentaggeld) und Police 14.560.085 (KMU Versicherung mit
Modul Haftpflicht). Die Kategorie steht deshalb je Dokument im Katalog.
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
Q = ROOT / '00_Rechnungen' / '07_Versicherung'
vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
hoch = 0

def lade(pfad, *, kategorie, typ, jahr, datum, betrag, titel, referenz):
    global hoch
    rel = pfad.relative_to(ROOT).as_posix()
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, rel))
    storage = f'{USER}/versicherungen/{jahr}/{doc_id}_{safe(pfad.name)}'
    if storage in vorhanden:
        print('schon da', pfad.name); return
    print(f'upload {pfad.name}  ({kategorie}/{typ})')
    if DRY: return
    data = pfad.read_bytes()
    sb.storage.from_('dokumente').upload(storage, data,
        {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'versicherungen', 'typ': typ,
        'kategorie': kategorie, 'jahr': jahr, 'dokument_datum': datum,
        'betrag': float(betrag) if betrag else None, 'referenz': referenz,
        'titel': titel, 'dateiname': pfad.name, 'dateityp': 'application/pdf',
        'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1

for r in csv.DictReader(open(HERE / 'versicherung_dokumente_katalog.csv', encoding='utf-8'), delimiter=';'):
    t = [r['datum'][:4], 'AXA', r['detail']]
    if r['betrag']: t.append(r['betrag'])
    pfad = Q / 'aufbereitet' / ('_'.join(t) + '.pdf')
    if not pfad.exists():
        print('FEHLT', pfad.name); continue
    lade(pfad, kategorie=r['kategorie'], typ=r['typ'], jahr=int(r['datum'][:4]),
         datum=r['datum'], betrag=r['betrag'], titel=r['titel'], referenz='44.127.389')

for r in csv.DictReader(open(HERE / 'versicherung_pdf_katalog.csv', encoding='utf-8'), delimiter=';'):
    pfad = Q / r['datei']
    if not pfad.exists():
        print('FEHLT', r['datei']); continue
    ref = '14.560.085' if '14560085' in r['datei'] else (
          '44.127.389' if '44127389' in r['datei'] else None)
    lade(pfad, kategorie=r['kategorie'], typ=r['typ'], jahr=int(r['datum'][:4]),
         datum=r['datum'], betrag=r['betrag'], titel=r['titel'], referenz=ref)

print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
