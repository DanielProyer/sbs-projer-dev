"""Erzeugt DELETE-SQL fuer die 0.00 'Zusaetzliche Anlage'-Reinigungen (zusammenfuehren
in die Hauptreinigung des Besuchs). Sicherheits-Check: nur loeschen, wenn am selben
Tag fuer denselben Betrieb eine bezahlte (preis_brutto>0) Import-Reinigung existiert.
Aufruf: python extract_zusatz_merge.py   -> out/07_zusatz_merge.sql (+ Vorschau-SELECT)
"""
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = os.path.join(HERE, '..', '..', '00_Buchhaltung', '00_SBS_Projer_70.xlsm')
OUT = os.path.join(HERE, 'out')
CUTOFF = pd.Timestamp('2025-12-01')


def run():
    df = pd.read_excel(XLSM, sheet_name='Reinigung', header=0, engine='openpyxl')
    c = df.columns.tolist()
    df = df[df[c[3]].notna()]
    df = df[pd.to_datetime(df[c[3]], errors='coerce') < CUTOFF]
    za = df[(df[c[9]] == 'Zusätzliche Anlage')]
    ids = [str(x).strip() for x in za[c[0]] if str(x).strip() not in ('', 'nan')]
    ids = sorted(set(ids))

    # Loeschen, wenn am selben Tag/Betrieb eine ANDERE Reinigung existiert (Mehr-Anlagen-Besuch).
    # Alleinstehende 0.00-Zusatzzeilen (einziger Eintrag des Besuchs) bleiben erhalten.
    cond = (
        "EXISTS (SELECT 1 FROM reinigungen m WHERE m.quelle='excel_import' "
        "AND m.betrieb_id=z.betrieb_id AND m.datum=z.datum AND m.id<>z.id)"
    )

    def in_list(chunk):
        return ','.join("'" + i.replace("'", "''") + "'" for i in chunk)

    with open(os.path.join(OUT, '07_zusatz_merge.sql'), 'w', encoding='utf-8') as f:
        for i in range(0, len(ids), 500):
            f.write(
                "DELETE FROM reinigungen z WHERE z.quelle='excel_import' "
                "AND z.preis_brutto=0 AND z.extern_id IN (" + in_list(ids[i:i + 500]) + ") AND "
                + cond + ";\n")

    # Vorschau-SELECT (gleiche Bedingung) zum Gegenpruefen via MCP
    with open(os.path.join(OUT, '07_zusatz_preview.sql'), 'w', encoding='utf-8') as f:
        f.write(
            "SELECT count(*) AS wuerde_geloescht FROM reinigungen z WHERE z.quelle='excel_import' "
            "AND z.preis_brutto=0 AND z.extern_id = ANY(ARRAY[" + in_list(ids) + "]) AND " + cond + ";\n")
    print(f"Zusatz-IDs: {len(ids)} -> out/07_zusatz_merge.sql")


if __name__ == '__main__':
    run()
