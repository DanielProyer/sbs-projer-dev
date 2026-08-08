# Kassen-Abgleich DB ↔ Buchhaltungs-Excel — 08.08.2026

**Anlass:** Daniel war «fast sicher, dass der Kassenbestand (DB 1000 = 11'084.28) nicht stimmt».
**Ergebnis: Die DB ist korrekt und vollständig abgestimmt — falsch war die Excel-BILANZ (Hauptbuch-Übertragungslücke).**

Quelle Excel: `D:\01_SBS_Projer_GmbH\00_SBS_Projer_72.xlsm` (Journal 15'513 Zeilen, Hauptbuch, Bilanz per 31.12.2025).

## 1. Jahresabgleich Excel-Journal ↔ DB (Konto 1000)

| Jahr | Journal-Zugang | DB-Zugang | Diff | Journal-Abgang | DB-Abgang | Diff |
|---|---|---|---|---|---|---|
| 2019 | 28'794.55 | 28'794.55 | 0.00 | 24'061.10 | 24'061.10 | 0.00 |
| 2020 | 27'580.10 | 27'580.10 | 0.00 | 28'999.60 | 28'999.60 | 0.00 |
| 2021 | 24'190.90 | 24'190.90 | 0.00 | 23'963.15 | 23'963.15 | 0.00 |
| 2022 | 29'066.60 | 29'066.60 | 0.00 | 31'209.46 | 31'209.46 | 0.00 |
| 2023 | 29'129.50 | 29'129.50 | 0.00 | 29'200.95 | 29'200.95 | 0.00 |
| 2024 | 28'065.95 | 28'065.95 | 0.00 | 28'270.65 | 28'270.65 | 0.00 |
| 2025 | 34'408.60 | 34'483.20 | **+74.60** ¹ | 28'935.65 | 28'935.65 | 0.00 |
| 2026 | 8'238.75 ² | 21'358.55 | +13'119.80 ² | 8'413.76 ² | 16'944.51 | +8'530.75 ² |

¹ Reinigung **Seeblick Sufers 23.12.2025** (74.60, barzahlung): von der Live-App gebucht, im Excel-Journal vergessen. Die App ist hier die Quelle der Wahrheit.
² Erwartet: Excel-Journal endete faktisch (Kasse-Zugänge bis 07.03., Abgänge bis Juni-Fragmente); ab Dez 2025 bucht die App live. Die 2026er-Journal-Zeilen wurden beim Voll-Import bewusst NICHT importiert (live vorhanden). Bekannte Parallel-Drift Jan 2026: App +71.35 gegenüber Excel (App-Buchungen hängen alle an realen Reinigungen).

## 2. Warum Daniels Bilanz-Gefühl trotzdem «zu hoch» sagte

Die **Excel-Bilanz per 31.12.2025 zeigt Kasse 2'041.24** — sie rechnet aus dem **Hauptbuch**, und dort fehlt das Übernahme-Fenster **29.01.–März 2025** (59 Zugänge = 5'317.85, der Februar komplett; dazu 774.65 Abgänge). Abstimmung:

```
Excel-Bilanz 31.12.2025           2'041.24
+ Hauptbuch-Lücke netto           4'554.40   (5'317.85 − 774.65 + 11.20)
+ Seeblick 23.12. (nur App)          74.60
= DB-Saldo 31.12.2025             6'670.24   ✓ rappengenau
+ 2026 (Live-Ära, verifiziert)    4'414.04
= DB-Saldo aktuell               11'084.28
```

Gleicher Fehlertyp wie der MwSt-Befund vom 06.08. (Journal↔Hauptbuch inkonsistent). Die Bank kennt dieses Problem nicht: 1020 Excel-Bilanz = DB = 12'202.73 exakt.

## 3. Vollständigkeit der Bankeinzahlungen (camt-Beweis)

- **2023–2026:** Jede Einzahlung im camt einzeln gegen die DB geprüft — 25 Stück, alle gebucht, Summen exakt (2023: 14'597.60 · 2024: 14'864.35 inkl. 10.– SIX-Token · 2025: 17'422.05 · 2026: 11'250.00). 2022 via Juni-Export ebenfalls TX-genau (17'138.45 + 0.11-Rundungszeile).
- **2019–2022:** Gesamt-camt (`00_Camt/…20260808_015746….xml`, Periode 01.01.2019–07.08.2026) liefert nur Jahres-Aggregate; kumuliert **11'438.31 per 31.12.2022 = DB-Saldo 1020 exakt** → Bankseite über die gesamte Firmengeschichte netto belegt.
- Schlusssaldo camt 07.08.: 15'816.07 = DB per 06.08. (15'165.92) + 7 neue Kundenzahlungen vom 07.08. (650.15) — Import macht Daniel selbst.

## 4. Offene Punkte

- [ ] **Kassensturz Daniel:** Soll laut Buch **11'084.28**; Differenz als Privatbezug **2260 an 1000** ausbuchen (deckt auch bar bezahlte, als «privat» gescannte Einkäufe ab).
- [ ] **28.05.2026, 2× «Benzin» 121.70** am selben Tag (beide aus dem Excel-Journal): Doppelerfassung oder wirklich zweimal getankt? Falls Doppler: 1 Zeile löschen → Kasse +121.70 (11'205.98), Aufwand 6200 −121.70.
- Scanner-Regel künftig: Geld aus dem Kässeli → Zahlungsweg **«bar»**; nur echtes Privatgeld → «privat».

## 5. Gratis-/Monteur-/Kulanz-Reinigungen: Kasse NICHT aufgebläht (Prüfung 08.08.)

**Live-Ära (ab Dez 2025):** Code-Guards in `reinigung_buchung_service.dart` (Kulanz + Heineken-Monteur buchen nie; nur Zahlungsart Barzahlung → 1000). Empirisch: Alle 258 Kasse-Buchungen geprüft — **0 Kulanz, 0 Monteur, 0 Heineken-abgerechnet, 0 mit Preis 0, 0 Betragsabweichungen** zur Reinigung.

**Excel-Ära (Reinigungs-Sheet, Rechnungsart «Bar» ↔ Journal-Kasse-Zugänge):** 2019/2022/2024/2025 exakt 0.00. Einzelfall-Diff über alle Jahre: nur **3 Kasse-Zugänge ohne Bar-Reinigung** (15.12.2020 67.85 · 02.05.2022 67.85 · 07.07.2023 74.30) — normale Tarife, davon mind. 2 erkennbare Datums-Shifts derselben Reinigung (Gegenstücke 01.06.2022 / 08.07.2023 in der Gegenliste). Die **2 einzigen Gratis-(Kulanz)-Zeilen mit Betrag** (06.11.2023 74.30 · 11.12.2024 94.05) sind **nicht** in der Kasse. Heineken-Reinigungen (215 St., via Monatsrechnung) tauchen in keiner Kasse-Buchung auf.

**Gegenrichtung:** 11 Bar-Reinigungen ohne Kasse-Buchung (v. a. März 2023, ~700) — die Kasse wäre historisch also eher etwas zu TIEF als zu hoch. Nicht korrigiert (Alt-Ära, Verkehrszahlen).

## 6. Nebenschauplatz: camt-Dateien-Archiv aufgeräumt (gleicher Tag)

7 von 8 Einträgen gelöscht (2 überholte Teil-Exporte + 5 Duplikate — der Bestätigungs-Flow archivierte dieselbe Datei pro Runde erneut). Verbleibt: 1 Eintrag 12.03.–06.08.2026. **Code-Guard v0.73.4:** `CamtDateiRepository.speichern` ist jetzt idempotent pro Datei (Name + Zeitraum). 7 verwaiste XML-Objekte bleiben im Bucket `camt-dateien` (Storage-API-Schutz; harmlos, ~7 MB).
