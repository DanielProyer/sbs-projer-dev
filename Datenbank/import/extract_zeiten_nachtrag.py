"""Excel 'Reinigung' -> Zeiten-Nachtrag (Zeit Beginn/Ende) als Staging-SQL.

Hintergrund (Daniel 30.07.2026): Die importierten Reinigungen (extern_id
gesetzt) kamen ohne Uhrzeiten in die App, die von Hand nacherfassten haben
teils 1-Minuten-Zeiten. Beides verfaelscht die Dauer-Schaetzung und die
beobachteten Fahrzeiten der Tourenplanung. Die echten Zeiten stehen im Excel
(Spalten 15/16/17: Dauer, Zeit Beginn, Zeit Ende).

Aufruf: py extract_zeiten_nachtrag.py   -> schreibt out/zeiten_nachtrag.sql

Gueltig ist eine Zeile nur mit Beginn UND Ende als Zeitwert, Ende > Beginn
und Dauer 3..600 Minuten - alles andere bleibt aussen vor (Daniel: wenige
Ausnahmen sind nicht erfasst).
"""
import datetime as dt
import os

import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
OUT = os.path.join(HERE, 'out')


def _zeit(v):
    """Zellwert -> 'HH:MM' oder None."""
    if isinstance(v, dt.time):
        return f'{v.hour:02d}:{v.minute:02d}'
    if isinstance(v, dt.datetime):
        return f'{v.hour:02d}:{v.minute:02d}'
    if isinstance(v, str) and ':' in v:
        t = v.strip().split(':')
        try:
            h, m = int(t[0]), int(t[1])
        except ValueError:
            return None
        if 0 <= h <= 23 and 0 <= m <= 59:
            return f'{h:02d}:{m:02d}'
    return None


def _minuten(hhmm):
    h, m = hhmm.split(':')
    return int(h) * 60 + int(m)


def main():
    os.makedirs(OUT, exist_ok=True)
    wb = openpyxl.load_workbook(XLSM, read_only=True, data_only=True)
    ws = wb['Reinigung']

    zeilen = []
    verworfen = 0
    for r in ws.iter_rows(min_row=2, values_only=True):
        extern_id = r[0]
        datum = r[3]
        if extern_id is None or not isinstance(datum, (dt.date, dt.datetime)):
            continue
        beginn = _zeit(r[16])
        ende = _zeit(r[17])
        if beginn is None or ende is None:
            verworfen += 1
            continue
        dauer = _minuten(ende) - _minuten(beginn)
        if dauer < 3 or dauer > 600:
            verworfen += 1
            continue
        betrieb = str(r[4] or '').strip().replace("'", "''")
        ort = str(r[5] or '').strip().replace("'", "''")
        # Auch die ID maskieren — im Excel steckt mind. ein Tippfehler mit
        # Apostroph ("2022_08_23_0089_0'2").
        eid = str(extern_id).strip().replace("'", "''")
        d = (datum.date() if isinstance(datum, dt.datetime) else datum)
        zeilen.append(
            f"('{eid}','{d.isoformat()}','{betrieb}','{ort}','{beginn}','{ende}')"
        )
    wb.close()

    pfad = os.path.join(OUT, 'zeiten_nachtrag.sql')
    with open(pfad, 'w', encoding='utf-8') as f:
        f.write('-- Zeiten-Nachtrag Staging (erzeugt von '
                'extract_zeiten_nachtrag.py, 30.07.2026)\n')
        f.write('create schema if not exists import;\n')
        f.write('drop table if exists import.zeiten_nachtrag;\n')
        f.write('create table import.zeiten_nachtrag (\n'
                '  extern_id text primary key, datum date, betrieb text,\n'
                '  ort text, beginn time, ende time\n);\n')
        for i in range(0, len(zeilen), 500):
            f.write('insert into import.zeiten_nachtrag values\n')
            f.write(',\n'.join(zeilen[i:i + 500]))
            f.write(';\n')

    print(f'{len(zeilen)} Zeilen mit gueltigen Zeiten, {verworfen} verworfen')
    print(f'-> {pfad}')


if __name__ == '__main__':
    main()
