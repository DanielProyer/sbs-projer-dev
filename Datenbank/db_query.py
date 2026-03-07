"""
Supabase DB Helper – SQL direkt aus der Kommandozeile ausführen.

Usage:
  python db_query.py "SELECT * FROM regionen LIMIT 5;"
  python db_query.py -f migrations/007_artikelstamm_heineken.sql
"""

import sys
import os
import psycopg2

def get_connection_string():
    env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
    with open(env_path) as f:
        for line in f:
            if line.startswith('SUPABASE_DB_URL='):
                return line.strip().split('=', 1)[1]
    raise RuntimeError('.env not found or SUPABASE_DB_URL not set')

def run_query(sql):
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = True
    cur = conn.cursor()
    try:
        cur.execute(sql)
        if cur.description:
            cols = [d[0] for d in cur.description]
            rows = cur.fetchall()
            print('\t'.join(cols))
            print('-' * 40)
            for row in rows:
                print('\t'.join(str(v) for v in row))
            print(f'\n({len(rows)} rows)')
        else:
            print(f'OK ({cur.rowcount} rows affected)')
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == '-f':
        with open(sys.argv[2]) as f:
            sql = f.read()
    else:
        sql = ' '.join(sys.argv[1:])

    run_query(sql)
