import openpyxl

wb = openpyxl.load_workbook(
    r"d:\01_SBS_Projer_GmbH\00_Entwicklung\SBS Projer DEV\Datenanalyse\SBS_Projer_Hauptexcel.xlsm",
    keep_vba=True,
    data_only=True
)
ws = wb["Artikel Heineken"]

sql_lines = []
sql_lines.append("-- Heineken Artikelstamm - Seed-Daten")
sql_lines.append("-- Quelle: SBS_Projer_Hauptexcel.xlsm, Sheet 'Artikel Heineken'")
sql_lines.append("-- 885 Artikel, Stand 12.02.2026")
sql_lines.append("-- Ausfuehren NACH material_kategorien Seed")
sql_lines.append("")
sql_lines.append("DO $$")
sql_lines.append("DECLARE")
sql_lines.append("  v_user_id UUID := auth.uid();")
sql_lines.append("BEGIN")
sql_lines.append("")

current_kategorie = None
rows = list(ws.iter_rows(min_row=2, values_only=True))

for row in rows:
    dbo_nr, name, kategorie = row
    if dbo_nr is None or name is None:
        continue
    dbo_nr = str(dbo_nr).strip()
    name = str(name).strip().replace(chr(39), chr(39)+chr(39))
    kategorie = str(kategorie).strip() if kategorie else "Sonstiges"
    if kategorie \!= current_kategorie:
        sql_lines.append(f"  -- {kategorie}")
        current_kategorie = kategorie
    sql_lines.append(f"  INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id)")
    sql_lines.append(f"  SELECT v_user_id, '{dbo_nr}', '{name}', 'Stueck',")
    sql_lines.append(f"    (SELECT id FROM material_kategorien WHERE user_id=v_user_id AND name='{kategorie}')")
    sql_lines.append(f"  ON CONFLICT (user_id, dbo_nr) DO UPDATE SET name=EXCLUDED.name, kategorie_id=EXCLUDED.kategorie_id;")
    sql_lines.append("")

sql_lines.append("END $$;")

output = chr(10).join(sql_lines)
output_path = r"d:\01_SBS_Projer_GmbH\00_Entwicklung\SBS Projer DEV\Datenanalyse\07_Artikelstamm_Heineken.sql"
with open(output_path, "w", encoding="utf-8") as f:
    f.write(output)

print(f"Fertig\! {len(rows)} Zeilen verarbeitet.")
print(f"Datei: {output_path}")
unique_dbo = set(str(r[0]).strip() for r in rows if r[0] is not None)
print(f"Unique DBO-Nummern: {len(unique_dbo)}")
