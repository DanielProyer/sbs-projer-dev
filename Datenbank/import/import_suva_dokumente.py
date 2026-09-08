# -*- coding: utf-8 -*-
"""Laedt die SVA-/AHV-Dokumente ins Dokumente-Modul (Bereich versicherungen,
Kategorie ahv).

Aufruf:  py -3 Datenbank/import/import_pk_dokumente.py [--dry-run] [--ersetzen]

Zwei Quellen:
1. 00_Rechnungen/06_PK/aufbereitet/*.pdf - aus den 105 Handy-Fotos gebaut.
   Die Dokumentgrenzen stehen explizit in suva_dokumente_katalog.csv (Spalte
   `seiten`, 1-basiert auf den 76 Nutzseiten). Automatisch geht das NICHT
   zuverlaessig: Daniel hat nicht ueberall ein Trennblatt eingelegt - zwischen
   der Rechnung Q4/2022 und dem Kontoauszug 07.01.2023 etwa fehlt eines.
2. 00_Rechnungen/06_PK/*.pdf - die Original-PDFs aus dem AXA-Portal
   (Pensionskassenausweise, Vorsorgeplaene). Inhaltsgleiche Mehrfach-Downloads
   werden per MD5 uebersprungen.

`--ersetzen` loescht vorher alle Dokumente des Bereichs mit Kategorie
pensionskasse - noetig, wenn sich Zuschnitt oder Benennung geaendert haben.
Braucht Datenbank/import/.env mit SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY.
"""
import csv, hashlib, os, re, sys, uuid
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
load_dotenv(HERE / '.env')
USER = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
DRY = '--dry-run' in sys.argv
ERSETZEN = '--ersetzen' in sys.argv
sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])
safe = lambda n: re.sub(r'[^A-Za-z0-9._-]', '_', n)
QUELLE = ROOT / '00_Rechnungen' / '05_SUVA'

if ERSETZEN:
    alt = sb.table('dokumente').select('id,storage_pfad').eq('user_id', USER) \
            .eq('bereich', 'versicherungen').eq('kategorie', 'unfall').execute().data
    print(f'{len(alt)} bestehende Dokumente werden ersetzt')
    if alt and not DRY:
        sb.storage.from_('dokumente').remove([d['storage_pfad'] for d in alt])
        for d in alt:
            sb.table('dokumente').delete().eq('id', d['id']).execute()

vorhanden = {d['storage_pfad'] for d in
             sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
hoch = 0

def lade(pfad, *, typ, jahr, datum, betrag, titel, data=None):
    global hoch
    rel = pfad.relative_to(ROOT).as_posix()
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, rel))
    storage = f'{USER}/versicherungen/{jahr}/{doc_id}_{safe(pfad.name)}'
    if storage in vorhanden:
        print('schon da', pfad.name); return
    print(f'upload {pfad.name}  ({typ})')
    if DRY:
        return
    data = data or pfad.read_bytes()
    sb.storage.from_('dokumente').upload(storage, data,
        {'content-type': 'application/pdf', 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'versicherungen', 'typ': typ,
        'kategorie': 'unfall', 'jahr': jahr, 'dokument_datum': datum,
        'betrag': float(betrag) if betrag else None, 'referenz': '4-00003-10064',
        'titel': titel, 'dateiname': pfad.name, 'dateityp': 'application/pdf',
        'groesse_bytes': len(data), 'storage_pfad': storage,
    }).execute()
    hoch += 1

# 1) Aus den Fotos gebaute Dokumente
for r in csv.DictReader(open(HERE / 'suva_dokumente_katalog.csv', encoding='utf-8'), delimiter=';'):
    teile = [r['datum'][:4], 'SUVA', r['detail']]
    if r['betrag']:
        teile.append(r['betrag'])
    pfad = QUELLE / 'aufbereitet' / ('_'.join(teile) + '.pdf')
    if not pfad.exists():
        print('FEHLT', pfad.name); continue
    lade(pfad, typ=r['typ'], jahr=int(r['datum'][:4]), datum=r['datum'],
         betrag=r['betrag'], titel=r['titel'])

print('fertig —', hoch, 'Dokumente', '(dry-run)' if DRY else '')
