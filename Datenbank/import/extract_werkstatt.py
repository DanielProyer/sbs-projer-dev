"""Excel-Werkstatt-Aufträge (2019 - 30.11.2025) -> Batch-SQL nach ./out/.
Aufruf: python extract_werkstatt.py            -> schreibt out/03..07 + Report
        python extract_werkstatt.py --selftest
Idempotent: INSERT ... ON CONFLICT (user_id, extern_id) DO NOTHING.
"""
import datetime as dt
import os
import sys

import pandas as pd

from match_betriebe import build_betrieb_index, match

HERE = os.path.dirname(os.path.abspath(__file__))
XLSM = r"D:/01_SBS_Projer_GmbH/00_SBS_Projer_70.xlsm"
OUT = os.path.join(HERE, "out")
USER_ID = "1e1ec2dd-7836-4d8e-8256-c5649d994ee2"
CUTOFF = pd.Timestamp("2025-12-01")

ANLAGE_TYP = {"david": "david", "konventionell": "konventionell",
              "heigenie": "heigenie", "orion": "orion"}
MONTAGE_TYP = {"neumontage": "neumontage", "abänderung": "abaenderung",
               "demontage": "demontage"}
EE_ART = {"eröffnung": "eroeffnung", "endreinigung": "endreinigung"}


def _txt(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    s = str(v).strip()
    return None if s in ("", "nan", "None", "NaT", "-") else s


def _num(v):
    s = _txt(v)
    if s is None:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _q(s):
    return "NULL" if s is None else "'" + str(s).replace("'", "''") + "'"


def _bid(name, ort, rows, aliase):
    """Betrieb-UUID oder None (Waise). None -> betrieb_id=NULL, zaehlt trotzdem."""
    b, _score = match(name or "", ort or "", rows, aliase)
    return b


def _uniq(seen, key):
    """Deterministisch eindeutiger extern_id: manche Excel-IDs (Betrieb_Datum)
    sind nicht eindeutig (2 Aufträge selber Betrieb/Tag). 1. Vorkommen = key,
    weitere = key#2, key#3 … Reihenfolge stabil (Blatt-Reihenfolge) -> idempotent.
    """
    seen[key] = seen.get(key, 0) + 1
    return key if seen[key] == 1 else f"{key}#{seen[key]}"


def _rows_before_cutoff(sheet, datum_col):
    """Alle Excel-Zeilen des Blatts mit gueltigem Datum < CUTOFF (als DataFrame-Iter)."""
    df = pd.read_excel(XLSM, sheet_name=sheet, header=0, engine="openpyxl")
    out = []
    for _, r in df.iterrows():
        d = r.iloc[datum_col]
        if pd.isna(d):
            continue
        d = pd.Timestamp(d)
        if d >= CUTOFF or d.year < 2019:
            continue
        out.append((d, r))
    return out


def build_stoerungen(rows, aliase):
    """-> (head_sql, [value_tuple_str, ...]). Netto = 'Total Störung' (col 11)."""
    vals = []
    seen = {}
    for d, r in _rows_before_cutoff("Störung", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        extern = _uniq(seen, extern)
        bid = _bid(_txt(r.iloc[3]), _txt(r.iloc[4]), rows, aliase)
        typ = ANLAGE_TYP.get((_txt(r.iloc[9]) or "").lower())
        netto = _num(r.iloc[11])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(typ), _q(_txt(r.iloc[10]) or "-"), _q(_txt(r.iloc[7])),
            "'behoben'", "false",
            ("NULL" if netto is None else str(netto)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO stoerungen (id,user_id,betrieb_id,datum,anlage_typ,"
            "problem_beschreibung,stoerungsnummer,status,ist_kilometerabrechnung,"
            "preis_netto,abgerechnet,quelle,extern_id) VALUES\n")
    return head, vals


def build_montagen(rows, aliase):
    """Netto = 'Betrag' (col 10) -> kosten_arbeit. montage_typ Pflicht."""
    vals = []
    seen = {}
    for d, r in _rows_before_cutoff("Montage", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        extern = _uniq(seen, extern)
        typ = MONTAGE_TYP.get((_txt(r.iloc[6]) or "").lower(), "abaenderung")
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        netto = _num(r.iloc[10])
        std = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(typ), _q(_txt(r.iloc[7]) or "-"),
            ("NULL" if std is None else str(std)),
            ("NULL" if netto is None else str(netto)),
            "'abgeschlossen'", "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO montagen (id,user_id,betrieb_id,datum,montage_typ,"
            "beschreibung,dauer_stunden,kosten_arbeit,status,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals


def build_eigenauftraege(rows, aliase):
    """Netto = 'Total' (col 8) -> pauschale. problem_beschreibung Pflicht."""
    vals = []
    seen = {}
    for d, r in _rows_before_cutoff("Eigenauftrag", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        extern = _uniq(seen, extern)
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        netto = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(_txt(r.iloc[6]) or "-"), _q(_txt(r.iloc[3]) or "-"), "'behoben'",
            ("NULL" if netto is None else str(netto)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO eigenauftraege (id,user_id,betrieb_id,datum,"
            "problem_beschreibung,stoerungsnummer,status,pauschale,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals


def build_ee(rows, aliase):
    """Netto = 'Rechnungsbetrag' (col 8) -> preis. art Pflicht (eroeffnung/endreinigung)."""
    vals = []
    seen = {}
    for d, r in _rows_before_cutoff("EE_Reinigung", 2):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        extern = _uniq(seen, extern)
        art = EE_ART.get((_txt(r.iloc[7]) or "").lower())
        if art is None:
            continue  # ohne gueltige Art nicht importierbar (art NOT NULL)
        bid = _bid(_txt(r.iloc[4]), _txt(r.iloc[5]), rows, aliase)
        berg = (_txt(r.iloc[6]) or "").lower() == "ja"
        preis = _num(r.iloc[8])
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(bid), _q(d.date().isoformat()),
            _q(_txt(r.iloc[3]) or "-"), _q(art), ("true" if berg else "false"),
            ("NULL" if preis is None else str(preis)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO eroeffnungsreinigungen (id,user_id,betrieb_id,datum,"
            "stoerungsnummer,art,ist_bergkunde,preis,abgerechnet,quelle,extern_id) VALUES\n")
    return head, vals


def build_pikett(rows, aliase):
    """Netto = 'Betrag' (col 4) -> pauschale_gesamt. Datum col 1 -> datum_start/-ende."""
    vals = []
    seen = {}
    for d, r in _rows_before_cutoff("Pikett", 1):
        extern = _txt(r.iloc[0])
        if extern is None:
            continue
        extern = _uniq(seen, extern)
        betrag = _num(r.iloc[4])
        feiertage = _num(r.iloc[3])
        ft = 0 if feiertage is None else int(feiertage)
        vals.append("(" + ",".join([
            "gen_random_uuid()", _q(USER_ID), _q(d.date().isoformat()),
            _q(d.date().isoformat()), _q(extern), str(ft),
            ("NULL" if betrag is None else str(betrag)),
            "true", "'excel_import'", _q(extern),
        ]) + ")")
    head = ("INSERT INTO pikett_dienste (id,user_id,datum_start,datum_ende,"
            "referenz_nr,anzahl_feiertage,pauschale_gesamt,abgerechnet,"
            "quelle,extern_id) VALUES\n")
    return head, vals


def _write(fname, head, vals):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, fname)
    with open(path, "w", encoding="utf-8") as f:
        if vals:
            f.write(head + ",\n".join(vals)
                    + "\nON CONFLICT (user_id, extern_id) WHERE extern_id IS NOT NULL DO NOTHING;\n")
    return len(vals)


def run():
    rows, aliase = build_betrieb_index()
    n = {}
    n["stoerungen"] = _write("03_stoerungen.sql", *build_stoerungen(rows, aliase))
    n["montagen"] = _write("04_montagen.sql", *build_montagen(rows, aliase))
    n["eigenauftraege"] = _write("05_eigenauftraege.sql", *build_eigenauftraege(rows, aliase))
    n["ee"] = _write("06_ee_reinigung.sql", *build_ee(rows, aliase))
    n["pikett"] = _write("07_pikett.sql", *build_pikett(rows, aliase))
    print("Geschrieben:", n, "-> Datenbank/import/out/")


def _selftest():
    assert _num("67.85") == 67.85 and _num("-") is None and _num(None) is None
    assert _q("a'b") == "'a''b'"
    assert ANLAGE_TYP.get("heigenie") == "heigenie"
    assert MONTAGE_TYP.get("abänderung") == "abaenderung"
    assert EE_ART.get("eröffnung") == "eroeffnung"
    rows, aliase = build_betrieb_index()

    _h, v = build_stoerungen(rows, aliase)
    # 2019: 106 Zeilen, Netto-Summe 12878.5 (aus Auswertung-Blatt)
    v2019 = [x for x in v if ",'2019-" in x]
    assert len(v2019) == 106, len(v2019)

    def netto_sum(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                parts = x.rstrip(")").split(",")
                p = parts[-4]  # preis_netto-Position (…,preis_netto,abgerechnet,quelle,extern)
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    ziel = {2019: 12878.5, 2020: 16405, 2021: 19605.8, 2022: 22975, 2023: 20270, 2024: 21916.4}
    for j, soll in ziel.items():
        got = netto_sum(v, j)
        assert abs(got - soll) < 0.05, (j, got, soll)

    _h, vm = build_montagen(rows, aliase)
    zielm = {2019: 18712.5, 2020: 21068.8, 2021: 14461.2, 2022: 26040, 2023: 22755, 2024: 23603.1}
    def netto_sum_m(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-5]  # kosten_arbeit (status,abgerechnet,quelle,extern folgen)
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielm.items():
        assert abs(netto_sum_m(vm, j) - soll) < 0.05, (j, netto_sum_m(vm, j), soll)

    _h, ve = build_eigenauftraege(rows, aliase)
    ziele = {2019: 840, 2020: 600, 2021: 510, 2022: 690, 2023: 420, 2024: 120}
    def nse(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-4]  # pauschale
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in ziele.items():
        assert abs(nse(ve, j) - soll) < 0.05, (j, nse(ve, j), soll)

    _h, vee = build_ee(rows, aliase)
    zielee = {2019: 420, 2020: 720, 2021: 495, 2022: 1500, 2023: 2265, 2024: 1710}
    def nsee(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f",'{jahr}-" in x:
                p = x.rstrip(")").split(",")[-4]  # preis
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielee.items():
        assert abs(nsee(vee, j) - soll) < 0.05, (j, nsee(vee, j), soll)

    _h, vp = build_pikett(rows, aliase)
    zielp = {2019: 2225, 2020: 3000, 2021: 1620, 2022: 2960, 2023: 2480, 2024: 3200}
    def nsp(vlist, jahr):
        tot = 0.0
        for x in vlist:
            if f"'{jahr}-" in x.split(",")[2]:  # datum_start-Position
                p = x.rstrip(")").split(",")[-4]  # pauschale_gesamt
                if p != "NULL":
                    tot += float(p)
        return round(tot, 2)
    for j, soll in zielp.items():
        assert abs(nsp(vp, j) - soll) < 0.05, (j, nsp(vp, j), soll)

    print("OK stoerungen", len(v))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        run()
