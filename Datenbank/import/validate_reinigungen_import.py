"""Treue-Gate: SOLL-Werte aus dem Excel fuer den Reinigungen-/Forderungs-Import.
Aufruf: python validate_reinigungen_import.py
Druckt SOLL-Zahlen + die IST-Pruef-SQL (via MCP execute_sql gegenpruefen)."""
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
CUTOFF = pd.Timestamp('2025-12-01')
ARTEN = ['Rechnung Mail', 'Rechnung Post', 'Rechnung Tresen']


def run():
    df = pd.read_excel(XLSM, sheet_name='Reinigung', header=0, engine='openpyxl')
    c = df.columns.tolist()
    df = df[df[c[3]].notna()]
    df = df[pd.to_datetime(df[c[3]], errors='coerce') < CUTOFF]
    rein = len(df[df[c[0]].notna()])

    inv = df[df[c[9]].isin(ARTEN)].copy()
    ez = pd.to_datetime(inv[c[10]], errors='coerce')
    eb = inv[c[11]].astype(str).str.strip()
    bezahlt = (ez.notna() & eb.str.startswith('020'))
    netto = pd.to_numeric(inv[c[20]], errors='coerce').fillna(0)
    brutto = pd.to_numeric(inv[c[19]], errors='coerce').fillna(0)

    print('=== SOLL (Excel, < 2025-12-01) ===')
    print(f'Reinigungen:            {rein}')
    print(f'Rechnungen (M/P/T):     {len(inv)}')
    print(f'  bezahlt:              {int(bezahlt.sum())}')
    print(f'  offen:                {int((~bezahlt).sum())}')
    print(f'Summe brutto gesamt:    {brutto.sum():.2f}')
    print(f'Summe netto gesamt:     {netto.sum():.2f}')
    print(f'Summe OFFEN brutto:     {brutto[~bezahlt].sum():.2f}')
    print()
    print('=== IST-Pruef-SQL (MCP execute_sql) ===')
    print("SELECT count(*) FROM reinigungen WHERE quelle='excel_import';  -- erw. " + str(rein))
    print("SELECT zahlungsstatus, count(*), round(sum(betrag_brutto),2) "
          "FROM rechnungen WHERE quelle='excel_import' GROUP BY zahlungsstatus;")
    print("SELECT count(*) FROM rechnungs_positionen p "
          "JOIN rechnungen r ON r.id=p.rechnung_id WHERE r.quelle='excel_import';  -- erw. "
          + str(len(inv)))


if __name__ == '__main__':
    run()
