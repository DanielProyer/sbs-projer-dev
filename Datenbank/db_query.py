"""
Supabase DB Helper – SQL via Supabase Management API ausführen.

Hintergrund: Die direkte Postgres-Verbindung (db.<ref>.supabase.co:5432) ist
seit 31.03.2026 wegen DNS-Problemen unzuverlässig. Stattdessen nutzen wir
den Management-API-Endpoint POST /v1/projects/{ref}/database/query.

Setup:
  1. Personal Access Token (PAT) erstellen:
     https://supabase.com/dashboard/account/tokens
  2. In .env (Repo-Root) eintragen:
       SUPABASE_PAT=sbp_xxx...
       SUPABASE_PROJECT_REF=pltbaqqwpnmdajwgnhpd

Usage:
  python db_query.py "SELECT * FROM regionen LIMIT 5;"
  python db_query.py -f migrations/007_artikelstamm_heineken.sql
"""

import sys
import os
import json
import urllib.request
import urllib.error


def load_env():
    env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
    values = {}
    with open(env_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, _, val = line.partition('=')
            values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def run_query(sql):
    env = load_env()
    pat = env.get('SUPABASE_PAT')
    ref = env.get('SUPABASE_PROJECT_REF')
    if not pat:
        raise RuntimeError(
            'SUPABASE_PAT fehlt in .env. PAT erstellen unter '
            'https://supabase.com/dashboard/account/tokens'
        )
    if not ref:
        raise RuntimeError('SUPABASE_PROJECT_REF fehlt in .env')

    url = f'https://api.supabase.com/v1/projects/{ref}/database/query'
    body = json.dumps({'query': sql}).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=body,
        method='POST',
        headers={
            'Authorization': f'Bearer {pat}',
            'Content-Type': 'application/json',
        },
    )

    try:
        with urllib.request.urlopen(req) as resp:
            payload = resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        err = e.read().decode('utf-8', errors='replace')
        print(f'HTTP {e.code}: {err}', file=sys.stderr)
        sys.exit(1)

    try:
        rows = json.loads(payload)
    except json.JSONDecodeError:
        print(payload)
        return

    if not isinstance(rows, list):
        print(json.dumps(rows, indent=2, ensure_ascii=False))
        return

    if not rows:
        print('OK (keine Zeilen)')
        return

    cols = list(rows[0].keys())
    print('\t'.join(cols))
    print('-' * 40)
    for row in rows:
        print('\t'.join(str(row.get(c, '')) for c in cols))
    print(f'\n({len(rows)} rows)')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == '-f':
        with open(sys.argv[2], encoding='utf-8') as f:
            sql = f.read()
    else:
        sql = ' '.join(sys.argv[1:])

    run_query(sql)
