# -*- coding: utf-8 -*-
"""Einmalige Erstbefüllung des Dokumente-Moduls mit den Steuerunterlagen 2019 ff.

Aufruf (aus dem Projekt-Root oder aus Datenbank/import):
    py -3 Datenbank/import/import_steuer_dokumente.py [--dry-run]

Liest drei Kataloge neben diesem Skript:
- steuerjahre_seed.csv            → Tabelle steuerjahre (upsert je Jahr)
- steuerzahlungen_zuordnung.csv   → buchungen.steuerjahr/steuerart (je Belegnummer)
- steuer_dokumente_katalog.csv    → Bucket `dokumente` + Tabelle dokumente (idempotent
                                    über die aus dem Dateipfad abgeleitete Dokument-ID)

Braucht in Datenbank/import/.env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (Service-Rolle,
weil RLS). Spec: docs/superpowers/specs/2026-09-02-steuern-dokumente-audit-design.md
"""
import csv
import os
import re
import sys
import uuid
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
load_dotenv(HERE / '.env')
USER = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
DRY = '--dry-run' in sys.argv

sb = create_client(os.environ['SUPABASE_URL'], os.environ.get('SUPABASE_SERVICE_ROLE_KEY') or os.environ['SUPABASE_SERVICE_KEY'])


def lese(name):
    with open(HERE / name, encoding='utf-8') as f:
        return list(csv.DictReader(f, delimiter=';'))


def safe(n):
    # Gleiche Regel wie dokumentStoragePfad() in Dart: nur ASCII A-Za-z0-9._- bleibt.
    return re.sub(r'[^A-Za-z0-9._-]', '_', n)


def leer_zu_none(row):
    return {k: (v if v != '' else None) for k, v in row.items()}


# 1) Steuerjahre --------------------------------------------------------------
for r in lese('steuerjahre_seed.csv'):
    row = leer_zu_none(r)
    row['jahr'] = int(row['jahr'])
    row['user_id'] = USER
    print('steuerjahr', row['jahr'], row['status'])
    if not DRY:
        sb.table('steuerjahre').upsert(row, on_conflict='user_id,jahr').execute()

# 2) Zahlungen zuordnen -------------------------------------------------------
fehlende_belege = []
for r in lese('steuerzahlungen_zuordnung.csv'):
    res = sb.table('buchungen').select('id').eq('user_id', USER).eq('belegnummer', r['belegnummer']).execute().data
    if not res:
        fehlende_belege.append(r['belegnummer'])
        continue
    print('zuordnung', r['belegnummer'], r['steuerjahr'], r['steuerart'], f'({len(res)} Buchung/en)')
    if not DRY:
        sb.table('buchungen').update({'steuerjahr': int(r['steuerjahr']), 'steuerart': r['steuerart']}) \
          .eq('user_id', USER).eq('belegnummer', r['belegnummer']).execute()
if fehlende_belege:
    print('ACHTUNG Belegnummern ohne Buchung:', fehlende_belege)

# 3) Dokumente ----------------------------------------------------------------
vorhanden = {d['storage_pfad'] for d in sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
hochgeladen = 0
for r in lese('steuer_dokumente_katalog.csv'):
    pfad = ROOT / r['datei']
    if not pfad.exists():
        print('FEHLT', pfad)
        continue
    jahr = int(r['jahr']) if r['jahr'] else None
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, r['datei']))  # stabil → idempotent
    storage = f"{USER}/steuern/{jahr or 'ohne-jahr'}/{doc_id}_{safe(pfad.name)}"
    if storage in vorhanden:
        print('schon da', pfad.name)
        continue
    buchung_id = None
    if r['zahlung_belegnummer']:
        res = sb.table('buchungen').select('id').eq('user_id', USER).eq('belegnummer', r['zahlung_belegnummer']).limit(1).execute().data
        buchung_id = res[0]['id'] if res else None
        if buchung_id is None:
            print('  (keine Buchung zu', r['zahlung_belegnummer'], ')')
    print('upload', pfad.name, '→', r['typ'], r['kategorie'] or '-', jahr, 'Buchung' if buchung_id else '')
    if DRY:
        continue
    data = pfad.read_bytes()
    mime = 'application/pdf' if pfad.suffix.lower() == '.pdf' else 'image/jpeg'
    sb.storage.from_('dokumente').upload(storage, data, {'content-type': mime, 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'steuern', 'typ': r['typ'], 'kategorie': r['kategorie'] or None,
        'jahr': jahr, 'dokument_datum': r['datum'] or None, 'betrag': float(r['betrag']) if r['betrag'] else None,
        'referenz': r['referenz'] or None, 'titel': r['titel'], 'dateiname': pfad.name, 'dateityp': mime,
        'groesse_bytes': len(data), 'storage_pfad': storage, 'buchung_id': buchung_id,
    }).execute()
    hochgeladen += 1
print('fertig —', hochgeladen, 'Dokumente hochgeladen', '(dry-run)' if DRY else '')
