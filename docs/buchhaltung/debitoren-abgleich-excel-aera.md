# Debitoren-Abgleich Excel-Ära (bis 30.11.2025) — Arbeitslisten

Stand 01.10.2026, erzeugt per SQL nach dem Lauf L2 (Jahrgang 2020).
Ausgangslage: Die Abschlussprüfung 2025 meldet **1100 = 121'281.79 gegen
offene Rechnungen 125'597.64 (−4'315.85)**. Die App-Ära ab 01.12.2025 stimmt
je Rechnung (+0.40 Rundung); die Differenz liegt in der Excel-Ära: 1100 per
30.11.2025 = 116'255.48, offene Excel-Rechnungen per 30.11.2025 = 120'571.73
→ **−4'316.25**. Herleitung und Einordnung: `jahresabschluss-2025.md` §10a.

Schlüssel: Die Excel-Belegnummern `011_JJJJ_MM_TT_<Betriebsnr>_<Betrag>` sind
zugleich die Rechnungsnummern; Zahlungen heissen `020_…`, Ausbuchungen `019_…`.
Damit lassen sich Forderungen, Rechnungen und Zahlungen exakt abgleichen
(4'362 von 4'411 Forderungen passen auf die Nummer genau).

**Zusammensetzung (Beiträge zur Differenz, gerundet):**

| Ursache | Wirkung auf 1100 ↔ Rechnungen |
|---|---|
| A · März-2023-Lücke: Forderungen nie gebucht, Zahlungen aber auf 1100 (2'094.80) und 6 Rechnungen offen (630.05) | ≈ −2'724.85 |
| C · Betragsabweichungen Forderung ↔ Rechnung (38 Paare, netto −106.38) und 2 Forderungen ohne Rechnung (Grill Aueli 85.10, BarBar 67.85) | ≈ +47 |
| D · Zahlungen ohne Rechnung (27 Stück, 3'015.00) gegen bezahlte Rechnungen ohne Zahlung | ≈ −1'160 netto (unverknüpfte Zahlungen 45'089.87 gegen 43'929.90 bezahlte Rechnungen ohne Zahlungsbuchung) |
| G · Heineken 08/2019 (Excel-Forderung 4'366.16, Rechnung und Zahlung 4'204.61) | +161.55 |
| MWST-Aufteilung der App-Saldenlogik auf 1100-Buchungen mit MWST-Feldern | +19.40 |
| Rest: Datums-Tippfehler-Paare (Alte Schwendi, Crestasee, Fonduestübli, Glenner, Bräma), Sunstar «beide Anlagen», Kleinbeträge | Rundung |

**Vorschlag je Gruppe (Entscheid Daniel):**

- **A (März 2023):** Die 27 bezahlten Rechnungen sind Geld, das kam, ohne je als
  Ertrag gebucht zu sein (2023 ist abgeschlossen, auch MWST-seitig). Sauber:
  eine Korrekturbuchung `1100 an 8000` (periodenfremder Ertrag) über die
  Gutschriften auf 1100 (2'094.80), MWST 7.7 % in der laufenden Periode
  nachdeklarieren (Q4/2026, Zeile 302). Für die 6 offenen Rechnungen
  (630.05): entweder ebenfalls Forderung nachbuchen (dann sind sie
  echte, nie gestellte Forderungen für die Abschreibung 2028) oder löschen,
  falls sie nie gestellt werden sollten.
- **B/C (Paare):** keine Buchung nötig; Datums-Tippfehler in der Rechnung
  korrigieren (Alte Schwendi 2021→2020, Crestasee 01.06.→19.05.2022), Spiga
  und Sunstar auf den Excel-Betrag anpassen oder belassen.
- **D (Zahlungen ohne Rechnung):** je Zahlung: gehört sie zu einer offenen
  Rechnung des Betriebs → verknüpfen und bezahlt setzen (ohne neue Buchung);
  war es eine nicht erfasste Leistung → `1100 an 8000`; Rückerstattung → prüfen.
- **E (Sammelzahlungen):** exakte Treffer per Migration verknüpfen
  (beleg_id/beleg_typ 'zahlung' auf die bestehende Buchung, keine
  Saldenänderung); Teiltreffer mit Daniels Excel zuordnen.
- **F:** Sammelzahler-Zuordnungen (Capalari, Robinson Club, Strela) ändern am
  Total nichts, erklären aber die Betriebsliste.


## A. März-2023-Lücke: 33 Rechnungen vom 09.–27.03.2023 ohne Forderungsbuchung

Excel hat in diesen Tagen keine Forderung (1100/3400) gebucht. Bezahlt: 2'383.45, davon 2'094.80 mit Gutschrift auf 1100 (Zahlung gebucht, Ertrag nie) · offen: 630.05.

| Datum | Betrieb | Brutto | Status | Zustellweg | bezahlt am | Gutschrift 1100 | Rechnungsnummer |
|---|---|---|---|---|---|---|---|
| 2023-03-09 | BARacca | 85.10 | bezahlt | rechnung_mail | 2023-05-31 | 0.00 | 011_2023_03_09_0224_00008510 |
| 2023-03-14 | Fravi | 67.85 | bezahlt | rechnung_tresen | 2023-03-24 | 67.85 | 011_2023_03_14_0002_00006785 |
| 2023-03-14 | Stiva Raetica | 67.85 | bezahlt | rechnung_mail | 2023-06-30 | 0.00 | 011_2023_03_14_0054_00006785 |
| 2023-03-14 | Weiss Kreuz | 67.85 | bezahlt | rechnung_tresen | 2023-06-22 | 67.85 | 011_2023_03_14_0201_00006785 |
| 2023-03-15 | Bahnhöfli | 67.85 | bezahlt | rechnung_tresen | 2023-05-03 | 67.85 | 011_2023_03_15_0136_00006785 |
| 2023-03-15 | Bodega Española | 67.85 | bezahlt | rechnung_tresen | 2023-03-21 | 67.85 | 011_2023_03_15_0046_00006785 |
| 2023-03-15 | Löwen | 67.85 | bezahlt | rechnung_tresen | 2023-03-31 | 67.85 | 011_2023_03_15_0620_00006785 |
| 2023-03-15 | Marsöl | 102.30 | bezahlt | rechnung_tresen | 2023-03-21 | 102.30 | 011_2023_03_15_0031_00010230 |
| 2023-03-15 | Twelve | 85.10 | bezahlt | rechnung_tresen | 2023-03-28 | 85.10 | 011_2023_03_15_0460_00008510 |
| 2023-03-17 | Krone | 107.70 | offen | rechnung_tresen |  | 0.00 | 011_2023_03_17_0629_00010770 |
| 2023-03-17 | Lenzerhorn | 187.40 | bezahlt | rechnung_tresen | 2023-03-31 | 187.40 | 011_2023_03_17_0171_00018740 |
| 2023-03-17 | Ninos | 102.30 | bezahlt | rechnung_tresen | 2023-04-17 | 102.30 | 011_2023_03_17_0177_00010230 |
| 2023-03-17 | Posthotel | 107.70 | bezahlt | rechnung_tresen | 2023-03-28 | 107.70 | 011_2023_03_17_0390_00010770 |
| 2023-03-17 | Spescha | 107.70 | bezahlt | rechnung_tresen | 2023-03-31 | 107.70 | 011_2023_03_17_0169_00010770 |
| 2023-03-21 | Chesa | 107.70 | bezahlt | rechnung_tresen | 2023-06-08 | 107.70 | 011_2023_03_21_0362_00010770 |
| 2023-03-21 | Ochsen 2 | 85.10 | bezahlt | rechnung_tresen | 2023-03-28 | 85.10 | 011_2023_03_21_0363_00008510 |
| 2023-03-21 | Seehof | 67.85 | bezahlt | rechnung_tresen | 2023-06-08 | 67.85 | 011_2023_03_21_0076_00006785 |
| 2023-03-22 | Hapimag | 67.85 | bezahlt | rechnung_tresen | 2023-04-20 | 67.85 | 011_2023_03_22_0123_00006785 |
| 2023-03-22 | IKIGAI | 67.85 | offen | rechnung_mail |  | 0.00 | 011_2023_03_22_0231_00006785 |
| 2023-03-22 | Signina | 85.10 | offen | rechnung_mail |  | 0.00 | 011_2023_03_22_0162_00008510 |
| 2023-03-22 | Waldhaus | 85.10 | bezahlt | rechnung_tresen | 2023-08-21 | 85.10 | 011_2023_03_22_0235_00008510 |
| 2023-03-23 | Il Pub | 119.55 | offen | rechnung_mail |  | 0.00 | 011_2023_03_23_0158_00011955 |
| 2023-03-23 | Indy Bar | 142.15 | offen | rechnung_mail |  | 0.00 | 011_2023_03_23_0232_00014215 |
| 2023-03-23 | Snake Bar | 107.70 | offen | rechnung_mail |  | 0.00 | 011_2023_03_23_0233_00010770 |
| 2023-03-24 | Fondue Beizli (Bierkönig) | 67.85 | bezahlt | rechnung_post | 2024-02-16 | 0.00 | 011_2023_03_24_0039_00006785 |
| 2023-03-24 | Franziskaner | 67.85 | bezahlt | rechnung_post | 2024-02-16 | 0.00 | 011_2023_03_24_0032_00006785 |
| 2023-03-24 | Helvetia | 85.10 | bezahlt | rechnung_tresen | 2023-04-04 | 85.10 | 011_2023_03_24_0034_00008510 |
| 2023-03-24 | Hemingway | 85.10 | bezahlt | rechnung_tresen | 2023-06-01 | 85.10 | 011_2023_03_24_0023_00008510 |
| 2023-03-24 | Valentinos | 67.85 | bezahlt | rechnung_tresen | 2023-03-24 | 67.85 | 011_2023_03_24_0035_00006785 |
| 2023-03-27 | Alte Post | 67.85 | bezahlt | rechnung_tresen | 2023-04-05 | 67.85 | 011_2023_03_27_0092_00006785 |
| 2023-03-27 | Bräma | 107.70 | bezahlt | rechnung_tresen | 2023-04-25 | 107.70 | 011_2023_03_27_0532_00010770 |
| 2023-03-27 | Clubhotel | 102.30 | bezahlt | rechnung_tresen | 2023-04-05 | 102.30 | 011_2023_03_27_0633_00010230 |
| 2023-03-27 | Jodys | 133.55 | bezahlt | rechnung_tresen | 2023-04-25 | 133.55 | 011_2023_03_27_0566_00013355 |


## B. Offene Excel-Rechnungen ohne exakte Forderungsbuchung (ausserhalb März 2023): 5

«Forderung anders» = Forderung desselben Betriebs mit anderem Datum oder Betrag im Umkreis von 45 Tagen (Tippfehler im Datum oder abweichender Betrag).

| Datum | Betrieb | Brutto | Zustellweg | Forderung anders | Rechnungsnummer |
|---|---|---|---|---|---|
| 2021-01-01 | Alte Schwendi | 102.30 | rechnung_tresen |  | 011_2021_01_01_0060_00010230 |
| 2021-08-10 | Spiga | 85.10 | rechnung_post | 2021-08-10 67.85 | 011_2021_08_10_0383_00008510 |
| 2021-12-14 | Spiga | 85.10 | rechnung_post | 2021-12-14 67.85 | 011_2021_12_14_0383_00008510 |
| 2022-06-01 | Crestasee | 85.10 | rechnung_post | 2022-05-19 85.10 | 011_2022_06_01_0519_00008510 |
| 2022-10-31 | Sunstar | 85.10 | rechnung_mail | 2022-10-31 154.00 | 011_2022_10_31_0170_00008510 |


## C. Forderungsbuchungen ohne Rechnung gleicher Nummer: 45

Meist Paare: Excel buchte einen anderen Betrag als die Rechnung trägt (Preis beim Import aus der Preisliste, in Excel der tatsächlich verlangte). «Differenz» = Forderung − Rechnung; ohne Rechnung am selben Tag steht die volle Forderung.

| Datum | Betrieb | Forderung | Rechnung gleicher Tag | Differenz | Belegnummer |
|---|---|---|---|---|---|
| 2019-08-21 | Reinigung Rechnung – AMERON | 136.80 | 136.78 bezahlt | 0.02 | 011_2019_08_21_0088_00013680 |
| 2020-01-01 | Reinigung Rechnung – Alte Schwendi | 102.30 |  | 102.30 | 011_2020_01_01_0060_00010230 |
| 2020-01-01 | Reinigung Rechnung – Fonduestübli | 67.85 |  | 67.85 | 011_2020_01_01_0248_00006785 |
| 2020-02-01 | Reinigung Rechnung – Ustria Startgels | 67.85 | 85.10 bezahlt | −17.25 | 011_2020_02_01_0126_00006785 |
| 2020-03-18 | Reinigung Rechnung – Spiga | 90.45 | 85.10 abgeschrieben | 5.35 | 011_2020_03_18_0383_00009045 |
| 2020-10-08 | Reinigung Rechnung – Bahnhöfli | 67.85 | 67.50 bezahlt | 0.35 | 011_2020_10_08_0136_00006785 |
| 2020-11-20 | Reinigung Rechnung – AMERON | 102.30 | 136.80 abgeschrieben | −34.50 | 011_2020_11_20_0088_00010230 |
| 2021-06-18 | Reinigung Rechnung – Glenner | 67.25 |  | 67.25 | 011_2021_06_18_0223_00006725 |
| 2021-08-10 | Reinigung Rechnung – Spiga | 67.85 | 85.10 offen | −17.25 | 011_2021_08_10_0383_00006785 |
| 2021-11-18 | Reinigung Rechnung – Grill Aueli | 85.10 |  | 85.10 | 011_2021_11_18_0508_00008510 |
| 2021-11-22 | Reinigung Rechnung – Grand Hotel Surselva | 85.10 | 78.50 bezahlt | 6.60 | 011_2021_11_22_0132_00008510 |
| 2021-12-14 | Reinigung Rechnung – Spiga | 67.85 | 85.10 offen | −17.25 | 011_2021_12_14_0383_00006785 |
| 2022-02-23 | Reinigung Rechnung – Grand Hotel Surselva | 85.10 | 78.50 bezahlt | 6.60 | 011_2022_02_23_0132_00008510 |
| 2022-04-05 | Reinigung Rechnung – Surselva | 67.85 | 85.10 bezahlt | −17.25 | 011_2022_04_05_0045_00006785 |
| 2022-05-19 | Reinigung Rechnung – Crestasee | 85.10 |  | 85.10 | 011_2022_05_19_0519_00008510 |
| 2022-06-29 | Reinigung Rechnung – Grand Hotel Surselva | 85.10 | 78.50 bezahlt | 6.60 | 011_2022_06_29_0132_00008510 |
| 2022-09-06 | Reinigung Rechnung – BarBar | 67.85 |  | 67.85 | 011_2022_09_06_0030_00006785 |
| 2022-10-31 | Reinigung Rechnung – Sunstar | 154.00 | 85.10 offen | 68.90 | 011_2022_10_31_0170_00015400 |
| 2022-11-30 | Reinigung Rechnung – Tankstelle | 67.85 | 85.10 bezahlt | −17.25 | 011_2022_11_30_0454_00006785 |
| 2022-12-09 | Reinigung Rechnung – BARacca | 85.10 | 85.00 bezahlt | 0.10 | 011_2022_12_09_0224_00008510 |
| 2022-12-12 | Reinigung Rechnung – Fonduestübli | 67.85 | 67.65 bezahlt | 0.20 | 011_2022_12_12_0248_00006785 |
| 2022-12-14 | Reinigung Rechnung – Glenner | 67.85 | 67.25 bezahlt | 0.60 | 011_2022_12_14_0223_00006785 |
| 2023-01-16 | Reinigung Rechnung – Grand Hotel Surselva | 85.10 | 78.50 bezahlt | 6.60 | 011_2023_01_16_0132_00008510 |
| 2023-02-02 | Reinigung Rechnung – BARacca | 85.10 | 85.00 bezahlt | 0.10 | 011_2023_02_02_0224_00008510 |
| 2023-03-09 | Reinigung Rechnung – BARacca | 67.85 | 85.10 bezahlt | −17.25 | 011_2023_03_09_0224_00006785 |
| 2023-03-27 | Reinigung Rechnung – Jodys | 130.30 | 133.55 bezahlt | −3.25 | 011_2023_03_27_0566_00013030 |
| 2023-05-17 | Reinigung Rechnung – Posthotel | 118.45 | 118.50 bezahlt | −0.05 | 011_2023_05_17_0390_00011845 |
| 2023-08-04 | Reinigung Rechnung – Swissheidi | 74.30 | 74.90 bezahlt | −0.60 | 011_2023_08_04_0490_00007430 |
| 2023-08-21 | Reinigung Rechnung – Ochsen 2 | 74.30 | 74.90 bezahlt | −0.60 | 011_2023_08_21_0363_00007430 |
| 2023-09-27 | Reinigung Rechnung – Kulm | 118.45 | 118.75 bezahlt | −0.30 | 011_2023_09_27_0109_00011845 |
| 2023-10-27 | Reinigung Rechnung – Fondue Beizli (Bierkönig) | 93.10 | 93.70 bezahlt | −0.60 | 011_2023_10_27_0039_00009310 |
| 2023-12-08 | Reinigung Rechnung – Steak House & Pizzeria | 74.30 | 77.30 bezahlt | −3.00 | 011_2023_12_08_0644_00007430 |
| 2023-12-21 | Reinigung Rechnung – Bahnhöfli | 74.30 | 74.90 bezahlt | −0.60 | 011_2023_12_21_0136_00007430 |
| 2024-01-22 | Reinigung Rechnung – Hemingway | 94.05 | 93.70 bezahlt | 0.35 | 011_2024_01_22_0023_00009405 |
| 2024-06-19 | Reinigung Rechnung – Lenzerhorn | 214.05 | 214.00 bezahlt | 0.05 | 011_2024_06_19_0171_00021405 |
| 2024-07-05 | Reinigung Rechnung – Steak House & Pizzeria | 74.60 | 77.60 bezahlt | −3.00 | 011_2024_07_05_0644_00007460 |
| 2024-07-17 | Reinigung Rechnung – El Gusto | 74.60 | 80.00 bezahlt | −5.40 | 011_2024_07_17_0548_00007460 |
| 2024-08-12 | Reinigung Rechnung – Steak House & Pizzeria | 74.60 | 77.60 bezahlt | −3.00 | 011_2024_08_12_0644_00007460 |
| 2024-08-23 | Reinigung Rechnung – Tgantieni | 74.60 | 74.10 bezahlt | 0.50 | 011_2024_08_23_0178_00007460 |
| 2024-10-25 | Reinigung Rechnung – Bräma | 118.90 |  | 118.90 | 011_2024_10_25_0532_00011890 |
| 2024-12-13 | Reinigung Rechnung – Swissheidi | 74.60 | 74.90 bezahlt | −0.30 | 011_2024_12_13_0490_00007460 |
| 2024-12-27 | Reinigung Rechnung – Concordia | 74.60 | 74.90 bezahlt | −0.30 | 011_2024_12_27_0077_00007460 |
| 2025-01-06 | Reinigung Rechnung – Steak House & Pizzeria | 74.60 | 77.60 bezahlt | −3.00 | 011_2025_01_06_0644_00007460 |
| 2025-03-07 | Reinigung Rechnung – Hilton Garden Inn | 74.60 | 118.90 bezahlt | −44.30 | 011_2025_03_07_0085_00007460 |
| 2025-11-06 | Reinigung Rechnung – Flamingo Bar | 94.05 | 97.05 bezahlt | −3.00 | 011_2025_11_06_0720_00009405 |


## D. Zahlungen ohne bezahlte Rechnung am Zahltag: 27 (3'015.00)

Gutschriften auf 1100, zu denen am selben Tag keine als bezahlt geführte Rechnung ohne Zahlungsbuchung existiert. «Betrieb offen» = offene Rechnungen dieses Betriebs heute (Kandidaten, die diese Zahlung beglichen haben könnte).

| Zahltag | Betrag | Gegenkonto | Beschreibung | Betrieb (aus Nr.) | Betrieb offen n | Betrieb offen CHF | Belegnummer |
|---|---|---|---|---|---|---|---|
| 2019-05-13 | 67.85 | 1020 | A - Einzahlungen ohne Zuordnung | ? | 0 | 0.00 | 020_2019_05_13_0000_00006785 |
| 2020-10-25 | 67.85 | 3400 | KEIN BELEG; Weiss Kreuz Cazis, Pächter abgehauen | Edelweiss | 2 | 135.70 | 019_2020_10_25_0222_00006785 |
| 2020-10-25 | 67.85 | 3400 | KEIN BELEG; Neustadt Chur, Pächter abgehauen | Neustadt | 0 | 0.00 | 019_2020_10_25_0049_00006785 |
| 2020-10-26 | 67.85 | 3400 | KEIN BELEG; Neustadt Chur, Pächter abgehauen | Neustadt | 0 | 0.00 | 019_2020_10_26_0049_00006785 |
| 2020-10-26 | 67.85 | 3400 | KEIN BELEG; Weiss Kreuz Cazis, Pächter abgehauen | Edelweiss | 2 | 135.70 | 019_2020_10_26_0222_00006785 |
| 2021-01-12 | 85.10 | 1020 | Einzahlung von Schifer GmbH UNKLAR welcher Kunde, noch Abklären, Beleg erfassen und in Liste Reinigung eintragen | ? | 0 | 0.00 | 020_2021_01_12__00008510 |
| 2021-11-25 | 38.00 | 1020 | RÜCKERSTATTUNG DOPPELZAHLUNG KEHRICHTGEBÜHR 2019 | ? | 0 | 0.00 | 020_2021_11_25_0000_00003800 |
| 2022-11-25 | 159.40 | 1020 | Zahlungseingang Reinigung | Calanda | 0 | 0.00 | 020_2022_11_25_0026_00015940 |
| 2023-03-21 | 67.85 | 1020 | Zahlungseingang Reinigung | Foppa | 0 | 0.00 | 020_2023_03_21_0125_00006785 |
| 2023-05-12 | 99.10 | 1020 | Zahlungseingang Reinigung | Surselva | 0 | 0.00 | 020_2023_05_12_0045_00009910 |
| 2023-05-12 | 93.70 | 1020 | Zahlungseingang Reinigung | Surselva | 0 | 0.00 | 020_2023_05_12_0045_00009370 |
| 2023-05-12 | 74.30 | 1020 | Zahlungseingang Reinigung | Fravi | 0 | 0.00 | 020_2023_05_12_0002_00007430 |
| 2023-07-14 | 93.70 | 1020 | Zahlungseingang Reinigung | Helvetia | 8 | 689.75 | 020_2023_07_14_0034_00009370 |
| 2024-01-25 | 74.60 | 1020 | Zahlungseingang Reinigung | Weissfluhgipfel | 1 | 74.60 | 020_2024_01_25_0069_00007460 |
| 2024-02-07 | 100.00 | 1020 | NACHZAHLUNG von Einzahlung vom 11.01.24 | Golden Dragon | 1 | 143.75 | 020_2024_02_07_0364_00010000 |
| 2024-02-21 | 745.40 | 1020 | NOCH ABKLÄREN und Beleg ablegen | ? | 0 | 0.00 | 020_2024_02_21__00074540 |
| 2024-03-21 | 118.90 | 1020 | Zahlungseingang Reinigung | Krone | 4 | 463.95 | 020_2024_03_21_0629_00011890 |
| 2024-10-30 | 74.60 | 1020 | Zahlungseingang Reinigung | Cafe Bar | 0 | 0.00 | 020_2024_10_30_0250_00007460 |
| 2024-11-15 | 99.45 | 1020 | Zahlungseingang Reinigung | Rovanada | 0 | 0.00 | 020_2024_11_15_0221_00009945 |
| 2024-12-17 | 126.45 | 1020 | Zahlungseingang Reinigung | Grotto & Pizzeria da Elio | 0 | 0.00 | 020_2024_12_17_0180_00012645 |
| 2024-12-18 | 74.60 | 1020 | Zahlungseingang Reinigung | Cafe Alexanderplatz | 0 | 0.00 | 020_2024_12_18_0703_00007460 |
| 2024-12-24 | 118.90 | 1020 | Zahlungseingang Reinigung | Hilton Garden Inn | 0 | 0.00 | 020_2024_12_24_0085_00011890 |
| 2025-01-30 | 77.60 | 1020 | NOCH ABKLÄREN und Beleg ablegen | ? | 0 | 0.00 | 020_2025_01_30__00007760 |
| 2025-02-20 | 74.60 | 1020 | Zahlungseingang Reinigung | Hapimag | 0 | 0.00 | 020_2025_02_20_0123_00007460 |
| 2025-03-10 | 77.60 | 1020 | NOCH ABKLÄREN und Beleg ablegen | ? | 0 | 0.00 | 020_2025_03_10__00007760 |
| 2025-04-07 | 77.60 | 1020 | NOCH ABKLÄREN und Beleg ablegen | ? | 0 | 0.00 | 020_2025_04_07__00007760 |
| 2025-09-17 | 124.30 | 1020 | Service nicht erfasst | Eisstadion Davos | 1 | 124.30 | 020_2025_09_17_0082_00012430 |


## E. Unverknüpfte Zahlungen mit bezahlten Rechnungen am Zahltag: 102 (exakt 56 = 19'081.92, teilweise 46)

Exakte Treffer (Zahlung = Summe der am selben Tag als bezahlt geführten Rechnungen ohne Zahlungsbuchung) können per Migration verknüpft werden; das ändert keine Salden, macht aber die Rechnungsliste nachvollziehbar. Teilweise Treffer brauchen Daniels Zuordnung.

**Exakt:**

| Zahltag | Betrag | Beschreibung | Rg | Rechnungen |
|---|---|---|---|---|
| 2019-07-01 | 496.60 | Mehrere Reinigungen | 5 | IKIGAI 67.85; Il Pub 138.50; Legna Bar 142.20; Signina 80.20; Signina 67.85 |
| 2019-08-02 | 437.35 | Mehrere Reinigungen | 4 | IKIGAI 67.85; Il Pub 142.20; Legna Bar 142.20; Signina 85.10 |
| 2019-08-23 | 170.20 | Mehrere Reinigungen | 2 | Helvetia 85.10; Helvetia 85.10 |
| 2019-09-09 | 283.25 | Mehrere Reinigungen | 3 | Grand Hotel Surselva 107.70; Sunstar 107.70; Sunstar 67.85 |
| 2019-09-12 | 170.20 | Mehrere Reinigungen | 2 | Hemingway 85.10; Hemingway 85.10 |
| 2019-10-09 | 227.30 | Zahlungseingang Reinigung | 2 | Legna Bar 142.20; Signina 85.10 |
| 2019-10-21 | 187.40 | Zahlungseingang Reinigung | 2 | IKIGAI 67.85; Il Pub 119.55 |
| 2019-11-18 | 204.60 | Einzahlung über SBS Hassler; mehrere Reinigungen | 2 | Pub Pin 102.30; Rätia 102.30 |
| 2020-01-07 | 85.10 | Zahlungseingang Reinigung | 1 | Süsswinkel 85.10 |
| 2020-02-18 | 203.55 | Drei Reinigungen in einer Einzahlung | 3 | Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85 |
| 2020-02-19 | 135.70 | Zwei Reinigungen in einer Einzahlung | 2 | Sonnenhalde 67.85; Sonnenhalde 67.85 |
| 2020-02-27 | 170.20 | Zwei Reinigungen in einer Einzahlung | 2 | BARacca 85.10; BARacca 85.10 |
| 2020-03-11 | 271.40 | Sammelgutschrift | 4 | Merz 67.85; Merz 67.85; Merz 67.85; Merz 67.85 |
| 2020-03-23 | 227.25 | Sammelgutschrift | 2 | Hörnlihütte 102.30; Hörnlihütte 124.95 |
| 2020-03-25 | 271.40 | Sammelgutschrift | 4 | Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85 |
| 2020-03-31 | 340.40 | Sammelgutschrift | 4 | Stall Valär 85.10; Stall Valär 85.10; Stall Valär 85.10; Stall Valär 85.10 |
| 2020-04-29 | 170.20 | Sammelgutschrift | 2 | Waldhaus 85.10; Waldhaus 85.10 |
| 2020-04-30 | 239.10 | Sammelgutschrift | 2 | Il Pub 119.55; Il Pub 119.55 |
| 2020-09-30 | 85.10 | Zahlungseingang Reinigung | 1 | Hemingway 85.10 |
| 2020-11-18 | 135.70 | Zahlungseingang Reinigung | 2 | Clavadeleralp 67.85; Clavadeleralp 67.85 |
| 2020-11-20 | 717.20 | Zahlungseingang Reinigung | 6 | Bolgenschanze 154.00; Bolgenschanze 154.00; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30 |
| 2020-11-27 | 220.80 | Zahlungseingang Reinigung | 3 | Jatzmeder 67.85; Jatzmeder 67.85; Jatzmeder 85.10 |
| 2020-12-04 | 1'163.10 | Sammelgutschrift | 12 | Capalari 102.30; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; Indy Bar 142.15; Indy Bar 142.15; Signina 102.30; Signina 85.10; Signina 102.30; Snake Bar 107.70; Snake Bar 107.70 |
| 2020-12-08 | 662.40 | Sammelgutschrift | 9 | Ochsen 2 67.85; Ochsen 2 67.85; Ochsen 2 67.85; Ochsen 2 67.85; Ochsen 2 85.10; Ochsen 2 85.10; Ochsen 2 67.85; Ochsen 2 67.85; Ochsen 2 85.10 |
| 2020-12-09 | 474.95 | Sammelgutschrift | 7 | Merz 67.85; Merz 67.85; Merz 67.85; Merz 67.85; Merz 67.85; Merz 67.85; Merz 67.85 |
| 2020-12-11 | 135.70 | Sammelgutschrift | 2 | Blockhuus 67.85; Blockhuus 67.85 |
| 2020-12-21 | 738.80 | Sammelgutschrift | 6 | Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Signina 85.10; Signina 85.10 |
| 2020-12-30 | 597.75 | Sammelgutschrift | 5 | Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55 |
| 2021-04-21 | 407.10 | Zahlungseingang Reinigung | 6 | Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85 |
| 2021-04-22 | 204.65 | Zahlungseingang Reinigung | 2 | Altein 85.10; Altein 119.55 |
| 2021-05-27 | 260.60 | Zahlungseingang Reinigung | 2 | Alpenblick 130.30; Alpenblick 130.30 |
| 2021-08-10 | 158.30 | Zahlungseingang Reinigung | 2 | Surselva 67.85; Surselva 90.45 |
| 2021-09-24 | 238.00 | Zahlungseingang Reinigung | 2 | Robinson Club 135.70; Robinson Club 102.30 |
| 2021-10-29 | 67.85 | Zahlungseingang Reinigung | 1 | Zum Ochsen 67.85 |
| 2022-01-31 | 67.85 | Zahlungseingang Reinigung | 1 | Swissheidi 67.85 |
| 2022-03-04 | 470.65 | Zahlungseingang Reinigung | 2 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2022-04-08 | 352.20 | Zahlungseingang Reinigung | 2 | Robinson Club 204.65; Robinson Mittelstation 147.55 |
| 2022-06-03 | 470.65 | Zahlungseingang Reinigung | 2 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2022-07-18 | 1'221.30 | Sammelgutschrift | 18 | Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85 |
| 2022-09-08 | 170.20 | Sammelgutschrift | 2 | Helvetia 85.10; Helvetia 85.10 |
| 2022-09-15 | 407.10 | Sammelgutschrift | 6 | Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85; Bodega Española 67.85 |
| 2022-09-16 | 135.70 | Sammelgutschrift | 2 | Hotel Sportcenter Fünf Dörfer 67.85; Hotel Sportcenter Fünf Dörfer 67.85 |
| 2023-01-12 | 470.65 | Zahlungseingang Reinigung | 2 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2023-01-16 | 255.30 | Sammelgutschrift | 3 | Sunstar 85.10; Sunstar 85.10; Sunstar 85.10 |
| 2023-01-23 | 306.90 | Sammelgutschrift via SBS Hassler | 3 | Fuxägufer 102.30; Fuxägufer 102.30; Fuxägufer 102.30 |
| 2023-03-03 | 470.65 | Zahlungseingang Reinigung | 2 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2023-04-06 | 470.65 | Zahlungseingang Reinigung | 2 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2023-05-31 | 255.10 | Zahlungseingang Reinigung | 3 | BARacca 85.00; BARacca 85.00; BARacca 85.10 |
| 2023-06-30 | 135.70 | Zahlungseingang Reinigung | 2 | Stiva Raetica 67.85; Stiva Raetica 67.85 |
| 2023-10-16 | 118.75 | Zahlungseingang Reinigung | 1 | Kulm 118.75 |
| 2024-01-24 | 741.00 | Zahlungseingang Reinigung | 8 | Spiga 93.70; Spiga 93.70; Spiga 93.70; Spiga 93.70; Spiga 93.70; Spiga 93.70; Spiga 93.70; Spiga 85.10 |
| 2024-01-29 | 518.05 | Zahlungseingang Reinigung | 2 | Robinson Club 300.50; Robinson Mittelstation 217.55 |
| 2024-04-09 | 539.46 | Zahlungseingang Reinigung | 2 | Robinson Club 308.10; Robinson Mittelstation 231.35 |
| 2024-04-23 | 571.86 | Zahlungseingang Reinigung | 2 | Robinson Club 340.50; Robinson Mittelstation 231.35 |
| 2024-12-19 | 149.20 | zwei Reinigungen mit einer Einzahlung | 2 | Hapimag 74.60; Hapimag 74.60 |
| 2025-04-17 | 223.80 | Einzahlung für 3 Service | 3 | Steak House & Pizzeria 74.60; Steak House & Pizzeria 74.60; Steak House & Pizzeria 74.60 |

**Teilweise (Zahlung ≠ Tagessumme):**

| Zahltag | Betrag | Beschreibung | Rg | Tagessumme | Rechnungen |
|---|---|---|---|---|---|
| 2019-09-06 | 414.70 | Mehrere Reinigungen | 4 | 414.65 | IKIGAI 67.85; Il Pub 119.55; Legna Bar 142.15; Signina 85.10 |
| 2020-02-28 | 443.70 | Sammelgutschrift | 12 | 1'129.70 | Bolgenschanze 154.00; Bolgenschanze 154.00; Capalari 102.30; Capalari 102.30; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; Nagens 67.85; Signina 102.30; Snake Bar 107.70; Strela 67.85; Strela 67.85 |
| 2020-02-28 | 686.00 | Sammelgutschrift | 12 | 1'129.70 | Bolgenschanze 154.00; Bolgenschanze 154.00; Capalari 102.30; Capalari 102.30; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; Nagens 67.85; Signina 102.30; Snake Bar 107.70; Strela 67.85; Strela 67.85 |
| 2020-03-06 | 203.55 | Sammelgutschrift | 9 | 765.70 | Blockhuus 67.85; Blockhuus 67.85; Blockhuus 67.85; Rotliechtli 102.30; Rotliechtli 85.10; Rotliechtli 102.30; Rotliechtli 102.30; Waldhuus 67.85; Waldhuus 102.30 |
| 2020-03-06 | 562.15 | Sammelgutschrift | 9 | 765.70 | Blockhuus 67.85; Blockhuus 67.85; Blockhuus 67.85; Rotliechtli 102.30; Rotliechtli 85.10; Rotliechtli 102.30; Rotliechtli 102.30; Waldhuus 67.85; Waldhuus 102.30 |
| 2020-03-13 | 358.65 | Zahlungseingang Reinigung | 13 | 1'614.35 | Indy Bar 142.15; Indy Bar 142.15; Indy Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Montana Bar 119.55; Montana Bar 119.55; Montana Bar 119.55; Signina 85.10; Signina 102.30; Snake Bar 107.70; Snake Bar 107.70 |
| 2020-03-13 | 1'255.80 | Sammelgutschrift | 13 | 1'614.35 | Indy Bar 142.15; Indy Bar 142.15; Indy Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Montana Bar 119.55; Montana Bar 119.55; Montana Bar 119.55; Signina 85.10; Signina 102.30; Snake Bar 107.70; Snake Bar 107.70 |
| 2020-05-06 | 738.82 | Sammelgutschrift | 4 | 738.80 | Robinson Club 221.85; Robinson Club 221.85; Robinson Mittelstation 147.55; Robinson Mittelstation 147.55 |
| 2020-12-14 | 716.10 | Sammelgutschrift | 14 | 1'432.20 | Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30 |
| 2020-12-14 | 716.10 | Sammelgutschrift | 14 | 1'432.20 | Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Pub Pin 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30; Rätia 102.30 |
| 2021-01-14 | 820.74 | Zahlungseingang Reinigung | 6 | 820.80 | AMERON 136.80; AMERON 136.80; AMERON 136.80; AMERON 136.80; AMERON 136.80; AMERON 136.80 |
| 2021-02-26 | 470.69 | Zahlungseingang Reinigung | 2 | 470.65 | Robinson Club 272.50; Robinson Mittelstation 198.15 |
| 2021-09-07 | 67.50 | Zahlungseingang Reinigung | 1 | 67.85 | American Burger 67.85 |
| 2021-09-23 | 107.70 | Zahlungseingang Reinigung | 1 | 85.10 | Bräma 85.10 |
| 2021-10-21 | 86.16 | FALSCHER BETRAG 86.16 anstatt 107.70 NOCH ABKLàREN | 1 | 107.70 | Chesa 107.70 |
| 2022-03-17 | 337.57 | Zahlungseingang Reinigung | 2 | 352.20 | Robinson Club 204.65; Robinson Mittelstation 147.55 |
| 2022-07-25 | 1'023.20 | Sammelgutschrift | 40 | 3'488.50 | Sunstar 85.10; Sunstar 107.70; Sunstar 102.30; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 67.85; Sunstar 67.85; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30 |
| 2022-07-25 | 1'021.00 | Sammelgutschrift | 40 | 3'488.50 | Sunstar 85.10; Sunstar 107.70; Sunstar 102.30; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 67.85; Sunstar 67.85; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30 |
| 2022-07-25 | 765.80 | Sammelgutschrift | 40 | 3'488.50 | Sunstar 85.10; Sunstar 107.70; Sunstar 102.30; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 67.85; Sunstar 67.85; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30 |
| 2022-07-25 | 678.50 | Sammelgutschrift | 40 | 3'488.50 | Sunstar 85.10; Sunstar 107.70; Sunstar 102.30; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 85.10; Sunstar 107.70; Sunstar 67.85; Sunstar 85.10; Sunstar 85.10; Sunstar 67.85; Sunstar 85.10; Sunstar 67.85; Sunstar 67.85; Sunstar 67.85; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30; Waldhuus 102.30 |
| 2022-08-05 | 5'219.10 | Sammelgutschrift | 50 | 5'219.05 | Capalari 85.10; Capalari 85.10; Capalari 85.10; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; IKIGAI 67.85; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Il Pub 119.55; Indy Bar 142.15; Indy Bar 142.15; Indy Bar 142.15; Indy Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Legna Bar 142.15; Signina 85.10; Signina 102.30; Signina 85.10; Signina 67.85; Signina 67.85; Signina 67.85; Signina 102.30; Signina 85.10; Signina 102.30; Signina 102.30; Signina 85.10; Snake Bar 107.70; Snake Bar 107.70; Snake Bar 107.70; Snake Bar 107.70 |
| 2022-09-26 | 67.85 | Zahlungseingang Reinigung | 1 | 102.30 | Bodega Española 102.30 |
| 2022-11-20 | 107.70 | Vier Einzahlungen am selben Tag deshalb Datum angepasst | 1 | 67.85 | Chesa 67.85 |
| 2022-12-02 | 378.00 | Zahlungseingang Reinigung | 1 | 378.05 | Getränke Candreja 378.05 |
| 2023-01-11 | 521.05 | Einbezahlt von SBS Hassler 11.01.22 / 19.04.22 / 27.04.22 / 15.08.22 | 4 | 521.20 | Alpenblick 130.30; Alpenblick 130.30; Alpenblick 130.30; Alpenblick 130.30 |
| 2023-10-12 | 138.85 | Zahlungseingang Reinigung | 1 | 137.85 | Alpenblick 137.85 |
| 2023-11-21 | 93.70 | Zahlungseingang Reinigung | 1 | 93.10 | Hemingway 93.10 |
| 2023-12-19 | 93.10 | Zahlungseingang Reinigung | 2 | 168.00 | Hemingway 93.70; Tödi 74.30 |
| 2023-12-19 | 74.90 | falscher Betrag überwiesen | 2 | 168.00 | Hemingway 93.70; Tödi 74.30 |
| 2024-01-05 | 74.30 | Zahlungseingang Reinigung | 1 | 74.60 | Espresso Bar 74.60 |
| 2024-01-11 | 18.45 | Teilzahlung, 100 zu wenig | 1 | 118.45 | Golden Dragon 118.45 |
| 2024-01-22 | 579.50 | Zahlungseingang Reinigung | 5 | 579.45 | Hörnlihütte 113.10; Hörnlihütte 102.30; Hörnlihütte 113.10; Hörnlihütte 113.10; Hörnlihütte 137.85 |
| 2024-02-08 | 1'215.00 | Sammelrechnung | 6 | 1'215.95 | Jamies 196.00; Jamies 187.40; Jamies 206.80; Jamies 206.80; Jamies 212.15; Jamies 206.80 |
| 2024-02-16 | 700.00 | Sammelrechnung | 18 | 1'413.95 | Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 93.70; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 67.85; Fondue Beizli (Bierkönig) 93.70; Fondue Beizli (Bierkönig) 67.85; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 93.70; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 67.85; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 118.45; Franziskaner 74.30; Franziskaner 67.85 |
| 2024-02-16 | 714.00 | Sammelrechnung | 18 | 1'413.95 | Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 93.70; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 67.85; Fondue Beizli (Bierkönig) 93.70; Fondue Beizli (Bierkönig) 67.85; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 74.30; Fondue Beizli (Bierkönig) 93.70; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 67.85; Franziskaner 74.30; Franziskaner 74.30; Franziskaner 118.45; Franziskaner 74.30; Franziskaner 67.85 |
| 2024-02-19 | 254.05 | Zahlungseingang Reinigung | 3 | 235.85 | Armando 67.85; Armando 74.30; Armando 93.70 |
| 2024-02-23 | 155.20 | Zahlungseingang Reinigung | 2 | 149.20 | Steak House & Pizzeria 74.60; Steak House & Pizzeria 74.60 |
| 2024-03-01 | 513.47 | Zahlungseingang Reinigung | 2 | 513.45 | Robinson Club 295.10; Robinson Mittelstation 218.35 |
| 2024-06-21 | 126.45 | Zahlungseingang Reinigung | 1 | 126.50 | Rovanada 126.50 |
| 2025-02-25 | 112.50 | Zahlungseingang Reinigung | 1 | 126.50 | Tgantieni 126.50 |
| 2025-03-17 | 155.20 | Zahlungseingang Reinigung | 2 | 149.20 | Sezner 74.60; Sezner 74.60 |
| 2025-05-05 | 168.35 | Zahlungseingang Reinigung | 1 | 168.65 | Golden Dragon 168.65 |
| 2025-07-18 | 97.05 | Zahlungseingang Reinigung | 1 | 94.05 | Grand Hotel Surselva 94.05 |
| 2025-08-06 | 66.00 | falscher Betrag Eingezahlt 66.00 anstatt 94.05 | 1 | 94.05 | Postresidenz am See 94.05 |
| 2025-09-01 | 60.00 | falscher Betrag Eingezahlt 60.00 anstatt 94.05 | 1 | 94.05 | Postresidenz am See 94.05 |
| 2025-10-13 | 86.15 | Betrag in Euro bezahlt | 1 | 94.05 | Grand Hotel Surselva 94.05 |


## F. Betriebe mit Differenz Hauptbuch ↔ Rechnungen per 30.11.2025: 85

Saldo = Forderungen − unverknüpfte Gutschriften − verknüpfte Zahlungen (je Betrieb, Excel-Ära). Grosse Posten sind Sammelzahler: Capalari und Robinson Club zahlten für andere Betriebe (Davoser Bars, Robinson Mittelstation), deshalb erscheinen sie negativ und die bezahlten Betriebe positiv.

| Betrieb | Forderungen | Gutschr. unverkn. | Zahlungen verkn. | Saldo 1100 | Rg offen per 30.11.25 | Differenz | Rg offen heute n | Rg offen heute CHF |
|---|---|---|---|---|---|---|---|---|
| Capalari | 562.20 | 6'382.20 | 0.00 | −5'820.00 | 0.00 | −5'820.00 | 0 | 0.00 |
| Robinson Mittelstation | 3'190.35 | 0.00 | 295.10 | 2'895.25 | 217.55 | 2'677.70 | 1 | 217.55 |
| Robinson Club | 5'865.05 | 6'633.37 | 1'894.85 | −2'663.17 | 0.00 | −2'663.17 | 0 | 0.00 |
| (ohne Betrieb) | 0.00 | 1'508.70 | 0.00 | −1'508.70 | 0.00 | −1'508.70 | 0 | 0.00 |
| Il Pub | 5'914.45 | 1'024.25 | 119.55 | 4'770.65 | 3'362.30 | 1'408.35 | 26 | 3'362.30 |
| Indy Bar | 3'282.85 | 0.00 | 0.00 | 3'282.85 | 2'145.65 | 1'137.20 | 14 | 2'145.65 |
| Strela | 1'024.50 | 1'160.90 | 549.55 | −685.95 | 339.25 | −1'025.20 | 5 | 339.25 |
| Snake Bar | 3'351.95 | 0.00 | 107.70 | 3'244.25 | 2'382.65 | 861.60 | 22 | 2'382.65 |
| Signina | 5'168.90 | 1'255.80 | 0.00 | 3'913.10 | 3'147.90 | 765.20 | 28 | 3'147.90 |
| IKIGAI | 3'299.70 | 686.00 | 67.85 | 2'545.85 | 1'874.85 | 671.00 | 25 | 1'874.85 |
| Bolgenschanze | 4'200.00 | 0.00 | 0.00 | 4'200.00 | 3'584.00 | 616.00 | 21 | 3'584.00 |
| Waldhuus | 4'613.65 | 1'023.20 | 311.25 | 3'279.20 | 2'700.05 | 579.15 | 21 | 2'700.05 |
| Legna Bar | 4'816.55 | 2'314.75 | 0.00 | 2'501.80 | 2'115.55 | 386.25 | 14 | 2'115.55 |
| Edelweiss | 650.85 | 135.70 | 515.15 | 0.00 | 203.55 | −203.55 | 2 | 135.70 |
| Lenzerhorn | 6'919.25 | 0.00 | 7'004.30 | −85.05 | 102.30 | −187.35 | 1 | 102.30 |
| Sunstar | 2'676.50 | 1'559.55 | 1'292.40 | −175.45 | 0.00 | −175.45 | 0 | 0.00 |
| Rotliechtli | 3'681.00 | 562.15 | 527.80 | 2'591.05 | 2'761.20 | −170.15 | 25 | 2'761.20 |
| Bahnhöfli | 2'849.40 | 0.00 | 2'842.90 | 6.50 | 149.20 | −142.70 | 1 | 74.60 |
| Grand Hotel Surselva | 3'216.10 | 183.20 | 2'239.00 | 793.90 | 654.90 | 139.00 | 3 | 246.65 |
| Neustadt | 135.70 | 135.70 | 0.00 | 0.00 | 135.70 | −135.70 | 0 | 0.00 |
| Bräma | 3'763.65 | 107.70 | 3'786.25 | −130.30 | 0.00 | −130.30 | 0 | 0.00 |
| Grotto & Pizzeria da Elio | 2'051.85 | 126.45 | 1'925.40 | 0.00 | 126.45 | −126.45 | 0 | 0.00 |
| Chesa | 4'652.75 | 193.86 | 4'460.60 | −1.71 | 124.30 | −126.01 | 1 | 124.30 |
| Eisstadion Davos | 519.40 | 124.30 | 395.10 | 0.00 | 124.30 | −124.30 | 1 | 124.30 |
| Kulm | 6'750.20 | 0.00 | 6'405.15 | 345.05 | 226.60 | 118.45 | 0 | 0.00 |
| Posthotel | 1'674.85 | 0.00 | 1'782.60 | −107.75 | 0.00 | −107.75 | 0 | 0.00 |
| Krone | 2'958.70 | 118.90 | 2'364.65 | 475.15 | 582.85 | −107.70 | 4 | 463.95 |
| Spescha | 4'176.20 | 0.00 | 4'283.90 | −107.70 | 0.00 | −107.70 | 0 | 0.00 |
| Rätia | 6'224.00 | 920.70 | 614.40 | 4'688.90 | 4'791.20 | −102.30 | 39 | 4'791.20 |
| Pub Pin | 2'284.70 | 716.10 | 614.40 | 954.20 | 851.90 | 102.30 | 9 | 851.90 |
| Ninos | 4'874.10 | 0.00 | 4'862.90 | 11.20 | 113.50 | −102.30 | 0 | 0.00 |
| Marsöl | 3'760.45 | 0.00 | 3'582.25 | 178.20 | 280.50 | −102.30 | 2 | 280.50 |
| Clubhotel | 2'222.30 | 0.00 | 306.90 | 1'915.40 | 2'017.70 | −102.30 | 15 | 2'017.70 |
| 4eri Bar | 188.10 | 0.00 | 188.10 | 0.00 | 94.05 | −94.05 | 1 | 94.05 |
| Ochsen 2 | 3'547.70 | 662.40 | 2'971.00 | −85.70 | 0.00 | −85.70 | 0 | 0.00 |
| Twelve | 2'730.60 | 0.00 | 2'815.70 | −85.10 | 0.00 | −85.10 | 0 | 0.00 |
| Helvetia | 4'791.50 | 434.10 | 3'121.25 | 1'236.15 | 1'321.25 | −85.10 | 8 | 689.75 |
| Süsswinkel | 630.10 | 0.00 | 545.00 | 85.10 | 0.00 | 85.10 | 0 | 0.00 |
| Grill Aueli | 876.80 | 0.00 | 0.00 | 876.80 | 791.70 | 85.10 | 9 | 791.70 |
| Waldhaus | 2'731.75 | 170.20 | 2'136.05 | 425.50 | 510.60 | −85.10 | 4 | 340.40 |
| Hemingway | 4'796.70 | 442.10 | 2'961.40 | 1'393.20 | 1'477.95 | −84.75 | 14 | 1'307.75 |
| Cafe Alexanderplatz | 447.60 | 74.60 | 298.40 | 74.60 | 149.20 | −74.60 | 0 | 0.00 |
| Golden Dragon | 5'401.10 | 286.80 | 4'752.20 | 362.10 | 287.50 | 74.60 | 1 | 143.75 |
| Grischa | 9'912.20 | 0.00 | 9'803.80 | 108.40 | 182.70 | −74.30 | 0 | 0.00 |
| Sunstar | 2'008.95 | 765.80 | 936.10 | 307.05 | 238.05 | 69.00 | 3 | 238.05 |
| Fondue Beizli (Bierkönig) | 3'912.75 | 714.00 | 610.65 | 2'588.10 | 2'656.55 | −68.45 | 25 | 2'249.45 |
| Franziskaner | 3'989.65 | 700.00 | 542.80 | 2'746.85 | 2'814.75 | −67.90 | 31 | 2'339.80 |
| Weiss Kreuz | 1'877.35 | 0.00 | 487.85 | 1'389.50 | 1'457.35 | −67.85 | 20 | 1'457.35 |
| Valentinos | 2'404.25 | 0.00 | 2'099.40 | 304.85 | 372.70 | −67.85 | 4 | 298.10 |
| Sunstar | 1'424.85 | 678.50 | 610.65 | 135.70 | 67.85 | 67.85 | 1 | 67.85 |
| BarBar | 3'621.05 | 0.00 | 3'008.65 | 612.40 | 544.55 | 67.85 | 4 | 356.45 |
| Alte Post | 1'695.30 | 0.00 | 1'092.05 | 603.25 | 671.10 | −67.85 | 9 | 671.10 |
| Stiva Raetica | 644.10 | 135.70 | 0.00 | 508.40 | 576.25 | −67.85 | 8 | 576.25 |
| Plattas | 271.40 | 0.00 | 203.55 | 67.85 | 0.00 | 67.85 | 0 | 0.00 |
| Zum Ochsen | 203.55 | 0.00 | 135.70 | 67.85 | 0.00 | 67.85 | 0 | 0.00 |
| Löwen | 1'917.25 | 0.00 | 1'985.10 | −67.85 | 0.00 | −67.85 | 0 | 0.00 |
| Nagens | 861.15 | 0.00 | 67.85 | 793.30 | 725.45 | 67.85 | 9 | 657.60 |
| Hapimag | 3'247.85 | 223.80 | 3'024.05 | 0.00 | 67.85 | −67.85 | 0 | 0.00 |
| Seehof | 2'909.20 | 0.00 | 2'827.85 | 81.35 | 149.20 | −67.85 | 2 | 149.20 |
| Fravi | 3'762.70 | 74.30 | 3'756.25 | −67.85 | 0.00 | −67.85 | 0 | 0.00 |
| Swissheidi | 3'262.80 | 0.00 | 3'121.25 | 141.55 | 74.60 | 66.95 | 1 | 74.60 |
| Postresidenz am See | 1'222.30 | 126.00 | 846.10 | 250.20 | 188.10 | 62.10 | 1 | 94.05 |
| Hilton Garden Inn | 7'802.00 | 118.90 | 7'477.50 | 205.60 | 249.90 | −44.30 | 0 | 0.00 |
| AMERON | 2'017.50 | 820.74 | 273.58 | 923.18 | 957.60 | −34.42 | 3 | 410.40 |
| Bodega Española | 2'108.65 | 1'085.60 | 988.60 | 34.45 | 67.85 | −33.40 | 1 | 67.85 |
| Spiga | 4'379.95 | 741.00 | 85.10 | 3'553.85 | 3'583.00 | −29.15 | 35 | 3'157.50 |
| Armando | 1'384.10 | 254.05 | 373.75 | 756.30 | 774.50 | −18.20 | 8 | 621.55 |
| Steak House & Pizzeria | 1'491.40 | 379.00 | 683.10 | 429.30 | 447.30 | −18.00 | 5 | 372.70 |
| Tankstelle | 434.75 | 0.00 | 366.90 | 67.85 | 85.10 | −17.25 | 1 | 85.10 |
| Ustria Startgels | 577.30 | 0.00 | 238.05 | 339.25 | 356.50 | −17.25 | 3 | 203.55 |
| Surselva | 9'369.75 | 351.10 | 9'035.90 | −17.25 | 0.00 | −17.25 | 0 | 0.00 |
| BARacca | 869.20 | 425.30 | 281.80 | 162.10 | 179.15 | −17.05 | 1 | 94.05 |
| Tgantieni | 3'432.30 | 112.50 | 3'135.15 | 184.65 | 170.15 | 14.50 | 0 | 0.00 |
| Sezner | 650.85 | 155.20 | 148.90 | 346.75 | 352.75 | −6.00 | 5 | 352.75 |
| El Gusto | 309.60 | 0.00 | 315.00 | −5.40 | 0.00 | −5.40 | 0 | 0.00 |
| Jodys | 4'866.35 | 0.00 | 4'725.85 | 140.50 | 143.75 | −3.25 | 0 | 0.00 |
| Flamingo Bar | 188.10 | 0.00 | 191.10 | −3.00 | 0.00 | −3.00 | 0 | 0.00 |
| Jamies | 7'179.75 | 1'215.00 | 1'922.45 | 4'042.30 | 4'041.35 | 0.95 | 17 | 3'179.75 |
| Alpenblick | 4'132.75 | 920.50 | 2'529.40 | 682.85 | 683.70 | −0.85 | 5 | 683.70 |
| Tödi | 3'681.35 | 74.90 | 3'017.60 | 588.85 | 589.45 | −0.60 | 8 | 589.45 |
| Glenner | 3'667.55 | 0.00 | 3'456.65 | 210.90 | 210.30 | 0.60 | 0 | 0.00 |
| American Burger | 714.05 | 67.50 | 646.20 | 0.35 | 0.00 | 0.35 | 0 | 0.00 |
| Concordia | 1'118.70 | 0.00 | 671.40 | 447.30 | 447.60 | −0.30 | 6 | 447.60 |
| Espresso Bar | 1'862.90 | 74.30 | 744.80 | 1'043.80 | 1'043.50 | 0.30 | 14 | 1'043.50 |
| Fonduestübli | 488.15 | 0.00 | 420.10 | 68.05 | 67.85 | 0.20 | 1 | 67.85 |


## G. Heineken: drei Monate mit abweichender Excel-Forderung (aus Migration 217 ausgenommen)

| Monat | Rechnung | Excel-Forderung | Excel-Zahlung | Rechnungsnummer |
|---|---|---|---|---|
| 2019-05 | 3'237.68 | 3'237.70 | 2019-07-09 3237.70 | 2026-07-1011 |
| 2019-08 | 4'204.61 | 4'366.16 | 2019-10-01 4204.61 | 2026-07-1014 |
| 2022-05 | 4'967.66 | 4'477.63 | 2022-07-14 4477.63 | 2026-07-1047 |

