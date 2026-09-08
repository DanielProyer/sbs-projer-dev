# -*- coding: utf-8 -*-
"""Zieht Dokumente von einem Bereich (optional: einer Kategorie) in einen
anderen Bereich um - im Storage UND in der Datenbank.

    py -3 Datenbank/werkzeuge/dokument_bereich_umziehen.py \
        --von versicherungen --kategorie ahv --nach ahv [--dry-run]

Der Storage-Pfad enthaelt den Bereich (`{user}/{bereich}/{jahr}/{id}_{name}`),
darum genuegt ein UPDATE auf der Tabelle nicht - die Datei muss mit. Ohne den
Move zeigt die App auf einen Pfad, unter dem nichts liegt, und der Download
scheitert erst beim Anklicken.

Idempotent: liegt die Datei schon am Ziel (abgebrochener Lauf), wird das
gemeldet und nur die Tabellenzeile nachgezogen. `bereich` wird gesetzt,
`kategorie` geleert - die Kategorie war ja gerade der Grund fuer den Umzug.

WICHTIG: Der CHECK-Constraint `dokumente_bereich_check` muss den Zielbereich
schon kennen (Migration zuerst ausfuehren), sonst bricht der Lauf beim ersten
UPDATE ab.

Braucht Datenbank/import/.env mit SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY.
"""
import argparse, os, sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
load_dotenv(ROOT / 'Datenbank' / 'import' / '.env')
USER = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
BUCKET = 'dokumente'

p = argparse.ArgumentParser()
p.add_argument('--von', required=True, help='Quell-Bereich')
p.add_argument('--kategorie', help='nur Dokumente dieser Kategorie')
p.add_argument('--nach', required=True, help='Ziel-Bereich')
p.add_argument('--dry-run', action='store_true')
a = p.parse_args()

sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])

q = sb.table('dokumente').select('id,titel,jahr,storage_pfad,kategorie') \
      .eq('user_id', USER).eq('bereich', a.von)
if a.kategorie:
    q = q.eq('kategorie', a.kategorie)
docs = q.execute().data

label = f'{a.von}/{a.kategorie}' if a.kategorie else a.von
print(f'{len(docs)} Dokumente ziehen um: {label} -> {a.nach}')
if a.dry_run:
    for d in docs[:5]:
        print('  ', d['storage_pfad'], '->', d['storage_pfad'].replace(f'/{a.von}/', f'/{a.nach}/', 1))
    print('  (Probelauf, nichts geaendert)')
    sys.exit(0)

verschoben = lag_schon = 0
for d in docs:
    alt = d['storage_pfad']
    neu = alt.replace(f'/{a.von}/', f'/{a.nach}/', 1)
    if neu == alt:
        print(f'  ACHTUNG Pfad enthaelt den Bereich nicht: {alt} - uebersprungen')
        continue
    try:
        sb.storage.from_(BUCKET).move(alt, neu)
        verschoben += 1
    except Exception as e:
        # Ein abgebrochener Lauf hat die Datei evtl. schon verschoben. Dann ist
        # nur noch die Tabellenzeile offen - kein Grund zum Abbruch.
        if 'exists' in str(e).lower() or 'not found' in str(e).lower():
            lag_schon += 1
        else:
            raise
    sb.table('dokumente').update(
        {'bereich': a.nach, 'kategorie': None, 'storage_pfad': neu}
    ).eq('id', d['id']).execute()

print(f'fertig - {verschoben} Dateien verschoben, {lag_schon} lagen schon am Ziel')
