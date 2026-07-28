"""Delta-Import: Zahlungseingaenge 01.12.2025-11.03.2026 aus dem Excel-Journal.

Hintergrund: `extract_journal_nachtrag.py` hat ab 28.11.2025 bewusst ALLE
`Zahlungseingang*`-Geschaeftsfaelle ausgeschlossen ("kommen via camt"). Der
camt-Import beginnt aber erst am 11.03.2026 und ist bis heute nicht verbucht
-> die Eingaenge dieser Periode fehlen komplett. Bank 1020 steht dadurch bei
-51'869.44 statt real +3'322.26 (per 11.03., E-Banking bestaetigt 28.07.2026).

Dieses Skript zieht genau die fehlenden Zeilen. Es SCHREIBT NICHTS in die
Datenbank, sondern erzeugt out/journal_zahlungen.sql zur Durchsicht.

Das erzeugte SQL ist idempotent: jede Zeile wird nur eingefuegt, wenn ihre
Belegnummer noch nicht existiert (Anti-Join statt UNIQUE-Index, weil auf
buchungen.belegnummer bewusst kein UNIQUE liegt - Sammelzahlungen).

Aufruf: py extract_journal_zahlungen.py [--selftest]
"""
import datetime as dt
import io
import json
import os
import sys

import openpyxl

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

XLSM = r'D:\01_SBS_Projer_GmbH\00_SBS_Projer_70.xlsm'
USER_ID = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
BETRIEBE_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             'in', 'betriebe_heineken_nr.json')

VON = dt.datetime(2025, 12, 1)
BIS = dt.datetime(2026, 3, 11, 23, 59, 59)

# Spaltenindizes im Blatt 'Journal' (Kopfzeile Zeile 1)
ID_BS, GF_TEXT, DATUM, BETRAG = 0, 3, 4, 5
KUERZEL, BEMERKUNG, ORDNER, SOLL, HABEN = 6, 7, 9, 10, 12

# Zahlungseingang vom 05.12.2025 ohne Betriebszuordnung: von Daniel am
# 28.07.2026 anhand des Bankauszugs geklaert -> Blockhuus (Gehri Gastronomie).
KUERZEL_KORREKTUR = {'020_2025_12_05_XXX_00007460': '0080'}


def lade_betriebe():
    """heineken_nr -> Betriebsname (fuer lesbare Buchungstexte)."""
    if not os.path.exists(BETRIEBE_JSON):
        return {}
    with open(BETRIEBE_JSON, encoding='utf-8') as f:
        return json.load(f)


def ist_zahlungseingang(gf_text):
    return str(gf_text or '').strip().lower().startswith('zahlungseingang')


def beschreibung_bauen(gf_text, kuerzel, bemerkung, betriebe):
    """Lesbarer Buchungstext: Geschaeftsfall + Betrieb, sonst Bemerkung."""
    # Bei den Heineken-Zahlungen steht in der Bemerkung der abgerechnete Monat
    # als Datum -> als "Monatsrechnung MM/YYYY" schreiben statt roh.
    if isinstance(bemerkung, dt.datetime):
        return f'{str(gf_text).strip()} - Monatsrechnung {bemerkung:%m/%Y}'
    bemerkung = str(bemerkung or '').strip()
    if bemerkung.lower() in ('nan', 'none'):
        bemerkung = ''
    gf = str(gf_text or '').strip()

    name = betriebe.get(str(kuerzel or '').strip())
    if name:
        return f'{gf} - {name} ({kuerzel})'
    if bemerkung:
        return f'{gf} - {bemerkung}' if gf else bemerkung
    return gf or 'Zahlungseingang'


def lese_zeilen():
    betriebe = lade_betriebe()
    wb = openpyxl.load_workbook(XLSM, read_only=True, data_only=True)
    ws = wb['Journal']

    zeilen, uebersprungen = [], []
    for row in ws.iter_rows(min_row=2, values_only=True):
        datum = row[DATUM]
        if not isinstance(datum, dt.datetime) or not (VON <= datum <= BIS):
            continue
        if not ist_zahlungseingang(row[GF_TEXT]):
            continue

        beleg = str(row[ID_BS] or '').strip()
        soll = str(row[SOLL] or '').strip().replace('.0', '')
        haben = str(row[HABEN] or '').strip().replace('.0', '')

        # Sicherheitsnetz: ein Zahlungseingang MUSS auf die Bank laufen.
        if soll != '1020':
            uebersprungen.append((beleg, f'Soll={soll} statt 1020'))
            continue
        if haben not in ('1100', '1000'):
            uebersprungen.append((beleg, f'Haben={haben} unerwartet'))
            continue

        kuerzel = KUERZEL_KORREKTUR.get(beleg, str(row[KUERZEL] or '').strip())
        betrag = round(float(row[BETRAG] or 0), 2)
        if betrag <= 0:
            uebersprungen.append((beleg, f'Betrag={betrag}'))
            continue

        zeilen.append({
            'belegnummer': beleg,
            'datum': datum.strftime('%Y-%m-%d'),
            'soll_konto': int(soll),
            'haben_konto': int(haben),
            'betrag': betrag,
            'beschreibung': beschreibung_bauen(row[GF_TEXT], kuerzel,
                                               row[BEMERKUNG], betriebe),
            'belegordner': str(row[ORDNER] or '').strip() or None,
            'geschaeftsjahr': datum.year,
        })
    wb.close()
    return zeilen, uebersprungen


def _s(v):
    return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"


def schreibe_sql(zeilen):
    os.makedirs(OUT_DIR, exist_ok=True)
    pfad = os.path.join(OUT_DIR, 'journal_zahlungen.sql')

    werte = []
    for z in zeilen:
        werte.append(
            f"  ({_s(USER_ID)}::uuid, {_s(z['datum'])}::date, "
            f"{_s(z['belegnummer'])}, {z['soll_konto']}, {z['haben_konto']}, "
            f"{z['betrag']:.2f}, {z['betrag']:.2f}, "
            f"{_s(z['beschreibung'])}, {_s(z['belegordner'])}, "
            f"{z['geschaeftsjahr']})")

    sql = f"""-- Delta-Import Zahlungseingaenge 01.12.2025-11.03.2026
-- Erzeugt von extract_journal_zahlungen.py, Quelle: 00_SBS_Projer_70.xlsm (Journal)
-- {len(zeilen)} Zeilen, CHF {sum(z['betrag'] for z in zeilen):,.2f}
-- Idempotent: fuegt nur ein, was per belegnummer noch nicht existiert.

INSERT INTO buchungen (
  user_id, datum, belegnummer, soll_konto, haben_konto,
  betrag_netto, betrag_brutto, beschreibung, belegordner, geschaeftsjahr,
  mwst_satz, mwst_betrag, mwst_konto, ist_storniert, notizen
)
SELECT v.user_id, v.datum, v.belegnummer, v.soll_konto, v.haben_konto,
       v.betrag_netto, v.betrag_brutto, v.beschreibung, v.belegordner,
       v.geschaeftsjahr,
       0, 0, NULL, false, 'Excel-Delta-Import Zahlungseingaenge 28.07.2026'
FROM (VALUES
{(',' + chr(10)).join(werte)}
) AS v(user_id, datum, belegnummer, soll_konto, haben_konto,
       betrag_netto, betrag_brutto, beschreibung, belegordner, geschaeftsjahr)
WHERE NOT EXISTS (
  SELECT 1 FROM buchungen b WHERE b.belegnummer = v.belegnummer
);
"""
    with open(pfad, 'w', encoding='utf-8') as f:
        f.write(sql)
    return pfad


def selftest():
    """Prueft die Filterlogik gegen die bekannten Audit-Zahlen."""
    zeilen, uebersprungen = lese_zeilen()
    summe = round(sum(z['betrag'] for z in zeilen), 2)
    an_debitoren = [z for z in zeilen if z['haben_konto'] == 1100]
    an_kasse = [z for z in zeilen if z['haben_konto'] == 1000]

    fehler = []
    if len(zeilen) != 220:
        fehler.append(f'Erwartet 220 Zeilen, gefunden {len(zeilen)}')
    if abs(summe - 55191.70) > 0.005:
        fehler.append(f'Erwartet CHF 55191.70, gefunden {summe}')
    if len(an_debitoren) != 217:
        fehler.append(f'Erwartet 217x Haben 1100, gefunden {len(an_debitoren)}')
    if len(an_kasse) != 3:
        fehler.append(f'Erwartet 3x Haben 1000, gefunden {len(an_kasse)}')
    if len({z['belegnummer'] for z in zeilen}) != len(zeilen):
        fehler.append('Doppelte Belegnummern in der Auswahl')
    blockhuus = [z for z in zeilen if z['belegnummer'].endswith('XXX_00007460')]
    if len(blockhuus) != 1 or 'Blockhuus' not in blockhuus[0]['beschreibung']:
        fehler.append('Blockhuus-Korrektur nicht angewandt')

    print(f'Zeilen: {len(zeilen)} | Summe: CHF {summe:,.2f}')
    print(f'  davon an Debitoren 1100: {len(an_debitoren)}')
    print(f'  davon an Kasse 1000:     {len(an_kasse)}')
    if uebersprungen:
        print(f'  uebersprungen: {len(uebersprungen)} -> {uebersprungen[:5]}')
    if fehler:
        print('\nSELFTEST FEHLGESCHLAGEN:')
        for f in fehler:
            print('  -', f)
        return 1
    print('\nSelftest OK - Zahlen decken sich mit dem Audit.')
    return 0


def main():
    if '--selftest' in sys.argv:
        sys.exit(selftest())

    zeilen, uebersprungen = lese_zeilen()
    pfad = schreibe_sql(zeilen)
    summe = sum(z['betrag'] for z in zeilen)
    print(f'{len(zeilen)} Zeilen, CHF {summe:,.2f} -> {pfad}')
    if uebersprungen:
        print(f'Uebersprungen: {uebersprungen}')


if __name__ == '__main__':
    main()
