# -*- coding: utf-8 -*-
"""Laedt die Pensionskassenausweise und Vorsorgeplaene ins Dokumente-Modul.

Aufruf: py -3 Datenbank/import/import_pk_ausweise.py [--dry-run]

Quelle: die Original-PDFs aus dem AXA-Portal in 00_Rechnungen/06_PK/.
Mehrfach heruntergeladene, inhaltsgleiche Kopien (Ausweis 2026 dreimal,
Vorsorgeplan 2024 zweimal) werden ueber den MD5 erkannt; hochgeladen wird je
Inhalt nur eine. Idempotent ueber eine aus dem Dateipfad abgeleitete Dokument-ID.
"""
import hashlib, os, re, sys, uuid
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

QUELLE = ROOT / '00_Rechnungen' / '06_PK'
vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}

gesehen, hoch = {}, 0
for pfad in sorted(QUELLE.glob('*.pdf')):
    data = pfad.read_bytes()
    h = hashlib.md5(data).hexdigest()
    if h in gesehen:
        print('Duplikat von', gesehen[h], '->', pfad.name, '(uebersprungen)'); continue
    gesehen[h] = pfad.name
    jahr = int(pfad.stem.split('_')[2][:4])
    ist_plan = pfad.stem.startswith('Vorsorgeplan')
    titel = (f'AXA Vorsorgeplan gueltig ab 01.01.{jahr}' if ist_plan
             else f'AXA Pensionskassenausweis gueltig ab 01.01.{jahr}')
    rel = f'00_Rechnungen/06_PK/{pfad.name}'
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, rel))
    storage = f'{USER}/versicherungen/{jahr}/{doc_id}_{safe(pfad.name)}'
    if storage in vorhanden:
        print('schon da', pfad.name); continue
    print('upload', pfad.name, '->', titel)
    if DRY:
        continue
    sb.storage.from_('dokumente').upload(storage, data,
        {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'versicherungen',
        'typ': 'vorsorgeplan' if ist_plan else 'ausweis', 'kategorie': 'bvg',
        'jahr': jahr, 'dokument_datum': f'{jahr}-01-01', 'referenz': '2/452968',
        'titel': titel, 'dateiname': pfad.name, 'dateityp': 'application/pdf',
        'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1
print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
