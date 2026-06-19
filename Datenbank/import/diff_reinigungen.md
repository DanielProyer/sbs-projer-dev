# Reinigungen-/Forderungs-Import — Treue-Gate (19.06.2026)

Quelle: `00_Buchhaltung/00_SBS_Projer_70.xlsm`, Sheet „Reinigung", Stichtag < 2025-12-01.
Reversibel über `quelle='excel_import'`.

## Mengen/Summen SOLL (Excel) = IST (DB)

| Kennzahl | SOLL | IST | Status |
|---|---|---|---|
| Reinigungen | 9'094 | 9'094 | ✅ |
| Rechnungen (Mail/Post/Tresen) | 4'438 | 4'438 | ✅ |
| bezahlt | 3'425 | 3'425 | ✅ |
| offen | 1'013 | 1'013 | ✅ |
| Offene Summe brutto | 105'240.95 | 105'240.95 | ✅ |
| Rechnungs-Positionen | 4'438 | 4'438 | ✅ |
| Neue geschlossene Betriebe | — | 106 | — |

Gesamt Forderungen brutto 441'274.33 · netto 409'135.55.

## Status-Logik
- **bezahlt**: echter 020-Zahlbeleg + Einzahlungsdatum (3'425).
- **offen**: alles ohne echten 020-Zahlbeleg (1'013) — inkl. der 181 „ABSCHREIBUNG"-Markierungen,
  da diese real **nicht** abgeschrieben wurden (Vorgabe Daniel 19.06.2026). Kein Status `abgeschrieben`.

## service_typ (aus Grundtarif-Spalten)
reinigung_bier 7'952 · reinigung_fremd 836 · reinigung_orion 306.

## Betrieb-Zuordnung
- 7 Schreibvarianten als Alias auf bestehende Betriebe gemappt (`betrieb_aliase.csv`).
- 106 echte ehemalige Kunden als `status='geschlossen'` neu angelegt (`inaktiv_seit` = letzte Reinigung).
- 8 „unsicher" gematchte (Score 70, aber korrekt: Conditorei Fischer, Garden Lounge & Bar, …) — siehe `out/review_betriebe.csv`.

## Offen / Folge
- **1100-Plausibilität**: offene Forderungen 105'240.95 sind die Detail-Schicht; mit dem 1100-Debitoren-Saldo
  per 30.11.2025 im App-Debitoren-Screen gegenprüfen (Heineken/Bar laufen separat).
- 2 doppelte `extern_id` in der Quelle (unkritisch, je eigene UUID).
- **Scans (FI6) noch offen**: Upload 010/020 in den Storage braucht den Service-Role-Key.

## DB-Eigenheiten beim Import
- `dauer_minuten` ist generierte Spalte → nicht eingefügt.
- `service_typ`-CHECK: nur reinigung_bier/orion/fremd/heigenie/wein.
- Betrieb-IDs deterministisch (uuid5) gegen FK-Drift bei Re-Runs.
- `set_rechnungsnummer`-Trigger für den Import deaktiviert (historische Belegnummer bleibt erhalten), danach reaktiviert.
- Auto-Buchungs-Trigger feuern nur bei UPDATE von zahlungsstatus → bei INSERT keine Buchungen (wie geplant).
