"""Liest Sheet 'Reinigung' und exportiert die Einzahlungs-Zuordnung.

Hintergrund (28.07.2026): In der App stehen 1'313 Rechnungen bis zum
technischen Stichtag 11.03.2026 auf 'offen'. Im Excel ist die Zahlung je
Reinigung aber laengst erfasst - Spalte 'Einzahlungsdatum'. Statt die
Zuordnung aus Betraegen zu erraten, uebernehmen wir sie direkt aus der Quelle.

Aufruf: py extract_einzahlungen_reinigung.py [pfad.xlsm]
Schreibt out/einzahlungen_reinigung.csv
"""
import csv
import datetime as dt
import os
import sys

import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
STANDARD_XLSM = r'D:\01_SBS_Projer_GmbH\00_SBS_Projer_71.xlsm'
OUT = os.path.join(HERE, 'out')

# Spaltenindizes (1-basiert) aus der Kopfzeile des Sheets 'Reinigung'
C_ID, C_DATUM, C_BETRIEB, C_ORT = 1, 4, 5, 6
C_RECHNUNGSART, C_EINZAHLUNG, C_EINZAHLUNGSBELEG = 10, 11, 12
C_TOTAL_BRUTTO, C_RECHNUNG_GESTELLT = 20, 32
# Mengen (nicht Betraege): Grundtarife und zusaetzliche Haehne
C_TOTAL_NETTO = 21
C_GT_EIGEN, C_GT_ORION, C_GT_FREMD = 22, 23, 24
C_HAHN_EIGEN, C_HAHN_FREMD, C_HAHN_STANDORT = 25, 26, 27


def _txt(v):
    if v is None:
        return None
    s = str(v).strip()
    return None if s in ('', '-', 'nan', 'None', 'NaT') else s


def _datum(v):
    if isinstance(v, dt.datetime):
        return v.date().isoformat()
    if isinstance(v, dt.date):
        return v.isoformat()
    s = _txt(v)
    if not s:
        return None
    for fmt in ('%Y-%m-%d', '%d.%m.%Y', '%d.%m.%y'):
        try:
            return dt.datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            pass
    return None


def _zahl(v):
    s = _txt(v)
    if s is None:
        return None
    try:
        return round(float(str(s).replace("'", '').replace(',', '.')), 2)
    except ValueError:
        return None


def lese(pfad):
    wb = openpyxl.load_workbook(pfad, read_only=True, data_only=True)
    ws = wb['Reinigung']
    zeilen = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        def cell(i):
            return row[i - 1] if len(row) >= i else None
        rid = _txt(cell(C_ID))
        if not rid:
            continue
        zeilen.append({
            'id': rid,
            'datum': _datum(cell(C_DATUM)),
            'betrieb': _txt(cell(C_BETRIEB)) or '',
            'ort': _txt(cell(C_ORT)) or '',
            'rechnungsart': _txt(cell(C_RECHNUNGSART)) or '',
            'einzahlung': _datum(cell(C_EINZAHLUNG)),
            'einzahlungsbeleg': _txt(cell(C_EINZAHLUNGSBELEG)) or '',
            'brutto': _zahl(cell(C_TOTAL_BRUTTO)),
            'rechnung_gestellt': _txt(cell(C_RECHNUNG_GESTELLT)) or '',
            'netto': _zahl(cell(C_TOTAL_NETTO)),
            'gt_eigen': int(_zahl(cell(C_GT_EIGEN)) or 0),
            'gt_orion': int(_zahl(cell(C_GT_ORION)) or 0),
            'gt_fremd': int(_zahl(cell(C_GT_FREMD)) or 0),
            'hahn_eigen': int(_zahl(cell(C_HAHN_EIGEN)) or 0),
            'hahn_fremd': int(_zahl(cell(C_HAHN_FREMD)) or 0),
            'hahn_standort': int(_zahl(cell(C_HAHN_STANDORT)) or 0),
        })
    wb.close()
    return zeilen


def _sql(v):
    """Literal fuer SQL - None wird NULL, Apostrophe werden verdoppelt."""
    if v is None or v == '':
        return 'NULL'
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def schreibe_sql(zeilen, ziel):
    """Erzeugt import.einzahlung_excel - Grundlage fuer den Abgleich in SQL."""
    with open(ziel, 'w', encoding='utf-8') as f:
        f.write('-- Sheet Reinigung, Spalte Einzahlungsdatum (Quelle der Wahrheit)\n')
        f.write('create schema if not exists import;\n')
        f.write('drop table if exists import.einzahlung_excel;\n')
        f.write('create table import.einzahlung_excel (\n'
                '  extern_id text, datum date, betrieb text, ort text,\n'
                '  rechnungsart text, einzahlung date, einzahlungsbeleg text,\n'
                '  brutto numeric, rechnung_gestellt text,\n'
                '  netto numeric, gt_eigen int, gt_orion int, gt_fremd int,\n'
                '  hahn_eigen int, hahn_fremd int, hahn_standort int);\n')
        spalten = ('id', 'datum', 'betrieb', 'ort', 'rechnungsart',
                   'einzahlung', 'einzahlungsbeleg', 'brutto',
                   'rechnung_gestellt', 'netto', 'gt_eigen', 'gt_orion',
                   'gt_fremd', 'hahn_eigen', 'hahn_fremd', 'hahn_standort')
        for i in range(0, len(zeilen), 500):
            teil = zeilen[i:i + 500]
            f.write('insert into import.einzahlung_excel values\n')
            f.write(',\n'.join(
                '(' + ','.join(_sql(z[s]) for s in spalten) + ')' for z in teil))
            f.write(';\n')
        f.write('create index on import.einzahlung_excel (extern_id);\n')
        f.write('create index on import.einzahlung_excel (datum, brutto);\n')


def main():
    pfad = sys.argv[1] if len(sys.argv) > 1 else STANDARD_XLSM
    zeilen = lese(pfad)
    os.makedirs(OUT, exist_ok=True)
    schreibe_sql(zeilen, os.path.join(OUT, 'einzahlung_excel.sql'))
    ziel = os.path.join(OUT, 'einzahlungen_reinigung.csv')
    with open(ziel, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(zeilen[0].keys()), delimiter=';')
        w.writeheader()
        w.writerows(zeilen)

    mit = [z for z in zeilen if z['einzahlung']]
    ohne = [z for z in zeilen if not z['einzahlung']]
    print('Datei:', pfad)
    print('Zeilen gesamt      :', len(zeilen))
    print('mit Einzahlung     :', len(mit))
    print('ohne Einzahlung    :', len(ohne))
    if zeilen:
        daten = [z['datum'] for z in zeilen if z['datum']]
        print('Zeitraum           :', min(daten), '-', max(daten))
    # Verteilung der offenen (ohne Einzahlung) nach Jahr
    nach_jahr = {}
    for z in ohne:
        if z['datum']:
            nach_jahr.setdefault(z['datum'][:4], 0)
            nach_jahr[z['datum'][:4]] += 1
    print('ohne Einzahlung nach Jahr:', dict(sorted(nach_jahr.items())))
    print('Beispiele mit Einzahlung:')
    for z in mit[:3]:
        print('  ', z['id'], z['datum'], z['brutto'], '->', z['einzahlung'],
              z['einzahlungsbeleg'])
    print('geschrieben:', ziel)


if __name__ == '__main__':
    main()
