# Jahresabschluss 2025 — Befund, Massnahmen, Entscheide

**Erstellt:** 02.09.2026 (Session Jahresschluss + Steuererklärung). Geschäftsjahr = Kalenderjahr.
**Grundregel:** keine Buchung ohne Freigabe Daniel. Dieses Dokument ist der Arbeitsstand; Haken werden nach Ausführung gesetzt.

## 1. Ist-Stand per 31.12.2025 (DB, App-Saldenlogik mit MwSt-Aufteilung, ohne Storni)

| Konto | Bezeichnung | 31.12.2024 | 31.12.2025 | Prüfung |
|---|---|---:|---:|---|
| 1000 | Kasse | 1'122.69 | 6'670.24 | journalgetreu (Kassenabgleich 08.08.) |
| 1020 | Bank | 11'829.71 | **12'202.73** | **= GKB camt-Historie 31.12.2025 rappengenau** (2024: camt 10'869.26 → Periodenverschiebung 960.45, per 2025 aufgelöst) |
| 1100 | Debitoren | 85'871.15 | 114'823.56 | journalgetreu; Soll 1100 je Jahr = Rechnungssumme (±≤1'063) |
| 1170 | Vorsteuer Material | 261.80 | 261.80 | Altlast 2019/20, nie saldiert |
| 1171 | Vorsteuer Betrieb | 51.60 | 51.60 | Altlast 2019–24 (Rundung), nie saldiert |
| 2000 | Kreditoren | 7'642.35 | 7'642.35 | = Franchise Nov+Dez 2025 (2×3'772.70, bez. 02.01./28.01.2026) + Altrest 96.95 |
| 2200 | Geschuldete MWST | 2'847.94 | 2'847.94 | Altlast: Journal-USt 2019–24 lag über den ESTV-Saldierungen (2020 825.28 · 2022 502.23 · 2023 1'395.64 [Einschätzungen] · Rest 124.79) |
| 2202 | MWST-Abrechnung | 6'360.47 | 6'122.25 | real geschuldet 31.12.2025 = Q3/25 3'333.74 + Q4/25 1'735.04 + Berichtigung 1'508.62 = **6'577.40** → DB 455.15 zu tief (Altlast, schon per 2024 identisch) |
| 2260 | Privatkonto (KK Gesellschafter) | 13'933.21 | 16'748.98 | |
| 2271 | (Inhalt AHV/ALV/FAK) | 6'115.96 | 7'703.97 | Alt-Semantik; Umgliederung liegt auf 31.03.2026 |
| 2272 | (Inhalt BVG + UVG-Nachbuchung) | 1'690.26 | 11'787.47 | dito |
| 2273 | (Inhalt UVG-Vorauszahlung) | −486.05 | **+4'482.90 Soll** | dito |
| 2500 | Coronakredit | 5'000.00 | 0.00 | getilgt |
| 2800 | Stammkapital | 20'000 | 20'000 | |

**Erfolgsrechnung 2025 (DB, netto):** Ertrag 197'566.76 · Material 649.97 · Personal 102'494.22 · Betrieb 58'935.41 · Steuern 8900 4'908.00 → **Gewinn 30'579.16**.
Vorjahre (DB): 2019 −4'768.35 · 2020 −37'581.59 · 2021 14'705.24 · 2022 17'468.65 · 2023 16'959.25 · 2024 28'277.51 → **Vortrag 01.01.2025 = 35'060.71** (Excel-Abschlüsse: 35'319.11, Differenz 258.40 = Periodenverschiebungen Systemwechsel, kumuliert erklärt am 05.08.).

**Excel-Bilanz ist als Referenz unbrauchbar:** Sie geht selbst nicht auf (Aktiven 118'083.62 / Passiven 103'467.46), Kasse 4'629 und Debitoren 15'786 zu tief (Hauptbuch-Lücke). Die früher notierten «Aufsetzwerte» (2200 17'223.38 / 1170 3'654.08 / 1171 1'148.11) werden **nicht** übernommen — Referenz sind ESTV-Abrechnungen und camt.

**EK/Gewinnvortrag «fehlt» ist erledigt:** Phase 2b (Modell 2) berechnet Vortrag + Jahresergebnis aus den Erfolgskonten; die 13 Excel-Abschlussbuchungen sind bewusst storniert. Bilanz geht auf.

## 2. Massnahmen (Vorschlag, alle per 31.12.2025 sofern nicht anders vermerkt)

**A — Abschreibung offene Rechnungen 2019** (Entscheid Daniel: nur 2019; 2020 → Abschluss 2026 usw.)
- 29 Rechnungen, 21 Betriebe, brutto **2'235.90** (netto 2'076.00 / MwSt 7.7 % 159.90), alle `excel_import`, Status `offen`, keine Buchung verknüpft.
- Buchung 31.12.2025: **3805 Debitorenverluste an 1100 = 2'235.90** (brutto); Rechnungen → `zahlungsstatus='abgeschrieben'`.
- MwSt-Rückholung 159.90: **separat 2026** (2200 an 3805, Q3/2026, Ziff. 235 Entgeltsminderung) — Q4/2025 ist eingereicht und berichtigt, eine dritte Korrektur für 159.90 lohnt nicht. Alternative: verzichten.

**B — MwSt-Altlast bereinigen (periodenfremd, 8000 Ausserordentlicher Ertrag)**
- 2200 an 1170 261.80 · 2200 an 1171 51.60 · 2200 an 2202 455.15 · 2200 an 8000 **2'079.39**.
- Danach: 2200 = 0, 1170 = 0, 1171 = 0, 2202 = 6'577.40 (= real geschuldet). Ergebnis 2025 +2'079.39.
- Optional gleich mit: 2000 an 8000 96.95 (Kreditor-Altrest ohne Beleg) → nur wenn Daniel bestätigt, dass nichts offen ist.
- Hinweis Risiko: 2022/2023 lagen Journal-USt über den Einschätzungen (1'897.87); die Perioden gelten mit den ESTV-Verfügungen als abgerechnet.

**C — Lohnkonten: Umgliederung auf 31.12.2025 datieren** (reiner Passivtausch, ergebnisneutral)
- Die 3 Umgliederungen (2271→2270 7'703.97 · 2272→2271 9'372.07 · 2272→2273 4'482.90) tragen heute Datum 31.03.2026 → auf 31.12.2025 umdatieren. Danach: 2270 AHV 7'703.97 · 2271 BVG 9'372.07 · 2273 0 · 2272 UVG **Soll 2'067.50** (= SUVA-Vorauszahlung 2026 1'768.80 + Rückerstattung 2025 784.75 − Altrest 486.09).
- Ausweis: 1180 an 2272 2'067.50 per 31.12.2025 (Forderung SVA/Vorsorge), Rückbuchung 01.01.2026 → keine negative Passivposition in der Bilanz.

**D — Steuerrückstellung 2025** (neu, bisher nur Zahlbasis auf 8900)
- 8900 an 2208 ≈ **4'600** (≈15 % auf ~30'900 steuerbar; Bund 8.5 % + GR/Domat-Ems). Betrag mit letzter Veranlagung 2024 plausibilisieren. Künftig Zahlungen gegen 2208.

**E — Delkredere pauschal** (optional, steuerlich üblich anerkannt: 5 % Inland)
- 3805 an 1109 = 5 % × (114'823.56 − 2'235.90) = **5'629.38**. Spiegelt die Qualität der Alt-Debitoren (2020–2024 offen 76'031.45) ehrlich; senkt Steuerlast.

**F — Steuererklärung: Aufrechnungen ohne Buchung**
- Bussen nicht abzugsfähig: 6280 120.00 + 8900 «Busse Kanton» 200.00 = 320.00.

## 3. Ergebnis nach A–E (D = 4'600, E = 5'629.38)

Gewinn 2025 = 30'579.16 − 2'235.90 + 2'079.39 − 4'600.00 − 5'629.38 = **20'193.27** · EK 31.12.2025 = 20'000 + 35'060.71 + 20'193.27 = 75'253.98 · Bilanzsumme 127'898.75 (geht auf).

## 4. Technik
- `buchungen.beleg_typ` CHECK kennt **kein** `abschreibung` → `AbschreibungService` der App würde mit PostgrestException scheitern. Migration: CHECK um `abschreibung`, `abschluss` erweitern.
- Belegnummern: `JA2025_<lfd>`; `notizen` = «Jahresabschluss 2025 (Freigabe Daniel 02.09.2026)». user_id 1e1ec2dd-7836-4d8e-8256-c5649d994ee2.
- Verifikation nach jedem Schritt per Saldenabfrage (Abschnitt 1 neu rechnen).

## 5. Unterlagen Steuererklärung 2025 (Zielbild)
- Bilanz 31.12.2025 + ER 2025 (App: Berichte → PDF) mit Vorjahreswerten; Anhang OR 959c (Kleinst-GmbH).
- Lohnausweis 2025 (liegt: `00_Rechnungen/12_Lohnausweis/Lohnausweis 2025.pdf`, 83'124 / 70'700).
- Bankauszug 31.12.2025 (12'202.73), Stammkapital 20'000, keine Beteiligungen, kein Anlagevermögen, Vortrag 35'060.71.
- ~~Offen: Papierstapel Lieferantenrechnungen 2025?~~ Geklärt 02.09.: keine 2025er-Belege im Stapel.

### 5a. Dossier in der App (seit v0.96.0, 02.09.2026)
- **Buchhaltung → Steuern → 2025** zeigt Veranlagungsdaten, Soll/Ist (provisorisch Bund 2'405.50 / Kanton 2'748.00 bezahlt, beide über 2208), die Dossier-Checkliste und die Dokumente des Jahres. Alle Steuerunterlagen 2019–2025 aus `00_Rechnungen/01_Steuern/` liegen im Bucket `dokumente` (Import-Skript `Datenbank/import/import_steuer_dokumente.py`, Echtlauf 02.09.: 76 Dokumente, 7 Steuerjahre, 63 Zahlungszuordnungen).
- **Noch hochzuladen (Daniel):** unterschriebene Jahresrechnung 2025 (Typ «Jahresrechnung»), Lohnausweis 2025, GKB Zins-/Kapitalausweis 31.12.2025 (bei der Bank holen). Nach Einreichung: Status «eingereicht» + Datum setzen, Formular 11a als «Steuererklärung» ablegen.
- Die **Abschlussprüfung** (Buchhaltung → Abschlussprüfung, Jahr 2025) ist die Checkliste vor dem Einreichen: Bank = camt, MWST saldiert, Delkredere 5 %, Rückstellung, Steuerzuordnung, Steuererklärung vorhanden.

## 6. Erledigt (02.09.2026, alle nach Freigabe Daniel)
- [x] Migration 181: `beleg_typ` um `abschreibung`/`abschluss` erweitert (ausgeführt).
- [x] **A** 29 Buchungen `3805 an 1100` je Rechnung (beleg_id = Rechnung), Summe 2'235.90, Status «abgeschrieben»; Rückholung `2200 an 3805` 159.90 datiert 02.09.2026 (`JA2025_A_MWST`, **Q3/2026 Ziff. 235 deklarieren!**).
- [x] **B** `JA2025_B1–B5`: 2200 an 1170 261.80 · 2200 an 1171 51.60 · 2200 an 2202 455.15 · 2200 an 8000 2'079.39 · 2000 an 8000 96.95.
- [x] **C** 3 Umgliederungen auf 31.12.2025 datiert (Snapshot `snapshot_jahresabschluss_2025.umgliederung_vorher`); `JA2025_C1` 1180 an 2272 2'067.50 per 31.12.2025, `JA2025_C2` Rückbuchung 01.01.2026.
- [x] **D** `JA2025_D` 8900 an 2208 **4'000.00** — kalibriert an Veranlagung 2024 (Bund 2'405.50 auf 28'300 steuerbar = 8.5 %; Kanton def. 2'748.00 = Gewinnsteuer 1'146 + Kapitalsteuer 114 + Kultus 158 + Gemeinde 1'330; effektiv 18.2 %). Scans in `00_Rechnungen/01_Steuern/`.
- [x] **E** `JA2025_E` 3805 an 1109 5'629.38.
- [x] **Verifikation:** Bilanz-Check 0.00 · **Gewinn 2025 = 20'890.22** · Vortrag 35'060.71 · EK 75'950.93 · Bilanzsumme 127'898.75 · 2202 heute 7'689.78 (= Q1/26 3'886.90 + Q2/26 2'294.26 + Berichtigung 1'508.62) · 2270/2271/2272 heute 6'777.62 / 6'510.32 / 844.15 (unverändert) · 2000 heute 0.00.
- [x] **Unterlagen:** `00_Buchhaltung/Jahresrechnung 2025.pdf` (Bilanz + ER mit Vorjahr, Anhang OR 959c, Beilage Steuererklärung mit Kennzahlen; steuerbarer Gewinn Vorschlag 21'201.23 nach Aufrechnung Bussen 311.01).

**Rollback:** Buchungen mit `notizen LIKE 'Jahresabschluss 2025 Schritt%'` löschen; Rechnungen aus `snapshot_jahresabschluss_2025.rechnungen_2019_vorher` zurücksetzen; Umgliederungen aus `umgliederung_vorher` zurückschreiben.

## 7. Folgepunkte 2026
- MWST Q3/2026: Ziff. 235 Entgeltsminderung 159.90 (Buchung `JA2025_A_MWST` liegt im Journal).
- ~~Belastung 05.05.2026 prüfen~~ Erledigt 02.09.: Bund 15.04.2026 (2'405.50) und Kanton 05.05.2026 (2'748.00) = provisorische Rechnungen 2025 → auf 2208 umgebucht (`JA2025_D_U1`, `JA2025_D_U2`). 2208 steht damit **1'153.50 im Soll** (Rückstellung 4'000 war zu tief) — bei der definitiven Veranlagung 2025 gegen 8900 ausgleichen. Künftige Steuerzahlungen kontiert der camt-Import selbst: 2208, solange die Rückstellung des Jahres offen ist, sonst 8900 (MWST 2202).
- Delkredere jährlich auf 5 % des Debitorenbestands nachführen; Jahrgang 2020 im Abschluss 2026 abschreiben (76 Rg, 7'216.30).
- Tresen-Rechnungen Dez 2025, die per Excel-Delta bezahlt, aber noch «offen» sind (~20 Stück, z. B. Center Fontauna, Stau, Surselva, Hotel Chur) → Status nachziehen (Debitoren-Hygiene, ergebnisneutral).


## 8. Steuerunterlagen-Inventar (02.09.2026)

**Ordner `00_Rechnungen/01_Steuern/`:** 22 Rechnungen/Mahnungen als benannte PDFs (`JJJJ_Steuerart_Typ_RgNr_Betrag.pdf`), `Unterlagen/` 27 PDFs (Verfügungen, Einspracheentscheide, Bewertungsmeldungen, Zinsausweise; 18 Trennblätter nur archiviert), Originale in `_Originalscans/`, Zuordnung in `_Index_PDF-zu-Originalscan.txt`. `Steuererklärungen 2019-2024/` = eingereichte 11a-Formulare + Bilanz/ER (2023 ohne 11a — Ermessenstaxation).

**Abgleich Zahlungen (8900/2208) ↔ Belege: alle 28 Zahlungen/Rückzahlungen belegt** (inkl. Rückzahlungen 2019 def. 434.20/553.00, 2020 def. 181.35/85.60, 2021 def. 78.00, 2022 def. 33.00). Noch fehlende Papiere (nur Vollständigkeit, keine Zahlungslücke): Bund-Rg 9766206 (2019 prov., 425), Kanton-Rg 9760463 (2019 prov., 600 — nur Mahnung), Rg 13985320/13985321 (2023 def., nur Mahnungen), Rg 14403952 (Bund 2024 prov., nur Mahnung), Bussen-Rg 11539779/13960127 (nur Mahnungen), Bussverfügung 21.11.2024, Bewertungsmeldung per 31.12.2023, **GKB Zins-/Kapitalausweis 31.12.2025** (für Steuererklärung 2025 nötig; 2024er liegt vor).

**Eingereichte Bilanz 31.12.2024 (10.11.2025):** Kasse 1'142.19 · Bank 11'829.71 (GKB-Zinsausweis: 10'869.26!) · Debitoren 85'749.45 · 1170 261.80 · 1171 33.14 · 2000 7'642.35 · 2200 2'803.06 · 2202 6'360.47 · 2260 13'599.36 · 2271 6'115.87 · 2272 1'690.10 · 2273 485.97 · 2500 5'000 · EK 20'000 + 6'920.04 + 28'399.07 = 55'319.11 · Bilanzsumme 99'016.29. Formular 11a 2024: Reingewinn 28'399, Verlustvortrag aufgebraucht (Vortrag 41'257 aus 2020 bis 2023 verrechnet), steuerbar 28'399 / Kapital 48'918. Jahresrechnung-2025-PDF zeigt diese Werte als Vorjahresspalte.

**Steuerhistorie (Verfügungen):** 2019 Verlust −4'973 · 2020 Verlust −36'284 (Einsprache gutgeheissen 16.03.2022; Busse 150 wegen verspäteter Erklärung) · 2021 Gewinn 16'072 voll verrechnet · 2022 Gewinn 18'049 voll verrechnet (Rest-Vortrag 7'136) · 2023 **Ermessenstaxation** (keine Erklärung; Aufrechnung 20'000, steuerbar 12'864; Busse 200) · 2024 steuerbar 28'399, Bund 2'405.50 / Kanton 2'748.00. Steuerwert Stammanteile per 31.12.2024: 985 (netto 689.50) je Anteil.


## 9. Nachtrag 01.10.2026 — Jahrgang 2020 ebenfalls per 31.12.2025 (Entscheid Daniel 29.09.2026)

**Entscheid:** «Die offenen Rechnungen 2019 und 2020 werden wir abschreiben (auf
Ende 2025).» 2019 ist gebucht (Schritt A, 02.09.2026). 2020 kommt am
01.10.2026 dazu: **76 Rechnungen, 36 Betriebe, 7'216.30 brutto = 6'699.87
netto + 516.43 MWST (7.7 %)**, keine mit Zahlung. Die Politik in
`abschreibungen-jahrgaenge.md` ist angepasst (2021 folgt im Abschluss 2026).

**Vorbereitung 29.09.2026:** Migration 214 (ein zweiter Lauf im selben
Geschäftsjahr ist erlaubt; vorher blockierte der 2019er-Lauf den App-Schritt
mit «Für 2025 gibt es schon einen gebuchten Lauf»), Navigationsfix (Bilanz und
Erfolgsrechnung unter «Abschlüsse und Steuern»), Skript
`Datenbank/wartung/jahresrechnung_beilage.py` (Anhang OR 959c + Steuerbeilage).

### 9a. App-Schritt (Daniel)

Mehr → Abschlüsse und Steuern → Abschlussprüfung → Jahr 2025 → rote Zeile
«Offene Rechnungen älter als 5 Jahre» → «Jahrgang abschreiben». Vorschau:
76 Rg / 7'216.30 / 6'699.87 / 516.43 (Jahrgänge bis 2020).

**Erwartetes Ergebnis (Migration 215, vor dem 01.10.2026 anwenden):** Lauf L2
(`geschaeftsjahr` 2025, `jahrgaenge` {2020}), je Rechnung `3805 an 1100
brutto` per 31.12.2025, EINE Sammelbuchung `JA2025_A_MWST_7_7_L2` (`2200 an
3805`, 516.43) datiert auf den Buchungstag, Lauf `mwst_jahr/quartal` =
Quartal des Buchungstags (am 01.10.2026: 2026/4). Der Screen zeigt seit 215
alle Läufe des Jahres und den Knopf auch neben dem 2019er-Lauf — vorher
blendete er ihn aus. 215 entfernt ausserdem den eindeutigen Index
`abschreibung_laeufe_ein_gebuchter` (194): den hatte 214 übersehen, L2 wäre
sonst an «duplicate key» gescheitert.

*Nur ohne 215 (gilt nicht mehr als Erwartung):* je Rechnung `3805 an 1100
netto` und `2200 an 1100 mwst`, beide per 31.12.2025, Lauf
`mwst_jahr/quartal` 2025/4 — dann Umbau per 9b.

### 9b. Umbau auf das 2019-Muster (Claude, SQL, direkt nach 9a)

> **Mit Migration 215 (angewendet vor dem 01.10.2026) macht der App-Schritt
> genau das — die SQL unten braucht es nur noch, wenn der Lauf VOR 215
> gebucht wurde.** Nach 215 heisst die Rückholung `JA2025_A_MWST_7_7_L2`
> statt `JA2025_A2_MWST`; Kontrollzahlen per 31.12.2025 unten gelten gleich.

WARUM: Q4/2025 ist eingereicht und viermal berichtigt; die Entgeltsminderung
gehört in die Periode des Entscheids (Art. 41 Abs. 2 MWSTG), also Q4/2026.
Wie beim Jahrgang 2019: der Verlust brutto im Abschlussjahr auf 3805, die
Rückholung `2200 an 3805` im Folgejahr. `view_entgeltsminderung` (196) nimmt
für Jahrgangsläufe `mwst_jahr/mwst_quartal` des Laufs — nach dem Umbau zeigt
Q4/2026 6'699.87 netto / 516.43 in Zeile 302 (7.7 %), Q4/2025 nichts. Die
Sammelbuchung JA2025_A2_MWST hat keine `beleg_id` und zählt in der Sicht
nicht doppelt.

```sql
-- L2 = id des neuen Laufs (jahrgaenge = {2020})
select id, jahrgaenge, anzahl, netto, mwst, brutto, mwst_jahr, mwst_quartal
from abschreibung_laeufe where geschaeftsjahr = 2025 order by created_at;

-- 1) Die 76 MWST-Zeilen (2200 an 1100 per 31.12.2025) auf 3805 an 1100 umstellen
update buchungen b
   set soll_konto = 3805,
       beschreibung = replace(b.beschreibung, 'MWST-Rückholung', 'Debitorenverlust MWST-Anteil'),
       notizen = replace(b.notizen, '(MWST-Rückholung', '(MWST-Anteil brutto auf 3805; Rückholung JA2025_A2_MWST per 01.10.2026'),
       updated_at = now()
 where b.id in (select buchung_mwst_id from abschreibung_positionen
                 where lauf_id = 'L2' and buchung_mwst_id is not null);
-- erwartet: UPDATE 76

-- 2) EINE Rückholung per 01.10.2026 (Q4/2026, Ziff. 235, 7.7 % → Zeile 302)
insert into buchungen (user_id, datum, belegnummer, soll_konto, haben_konto,
  betrag_netto, mwst_satz, mwst_betrag, betrag_brutto, beschreibung, zahlungsweg,
  beleg_typ, geschaeftsjahr, notizen)
values ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2026-10-01', 'JA2025_A2_MWST',
  2200, 3805, 516.43, 0, 0, 516.43,
  'MwSt-Rückholung Debitorenverluste Jahrgang 2020 (76 Rg, brutto 7''216.30, 7.7 %) — Ziff. 235 Q4/2026',
  'intern', 'abschreibung', 2026,
  'Jahresabschluss 2025 Schritt A2: MWST-Rückholung Jahrgang 2020 (Entscheid Daniel 29.09.2026, gebucht 01.10.2026)');

-- 3) Lauf auf die MWST-Periode des Entscheids
update abschreibung_laeufe
   set mwst_jahr = 2026, mwst_quartal = 4,
       notizen = notizen || ' — Umbau 01.10.2026: MWST-Anteil brutto auf 3805 per 31.12.2025, Rückholung JA2025_A2_MWST (2200 an 3805) per 01.10.2026, Ziff. 235 Q4/2026.'
 where id = 'L2';

-- Kontrolle per 31.12.2025 (vorher → nachher): 1100 112'568.26 → 105'351.96 ·
-- 3805 (2025) 7'865.28 → 15'081.58 · 2200 unverändert gegenüber vor 9a
```

### 9c. Delkredere nachziehen (Claude)

```sql
-- 5 % von 105'351.96 = 5'267.60; bisher 5'629.38 (JA2025_E) → 361.78 zurück
insert into buchungen (user_id, datum, belegnummer, soll_konto, haben_konto,
  betrag_netto, mwst_satz, mwst_betrag, betrag_brutto, beschreibung, zahlungsweg,
  beleg_typ, geschaeftsjahr, notizen)
values ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2025-12-31', 'JA2025_E2',
  1109, 3805, 361.78, 0, 0, 361.78,
  'Delkredere auf 5 % von 105''351.96 = 5''267.60 nachgeführt (nach Abschreibung Jahrgang 2020)',
  'intern', 'abschluss', 2025,
  'Jahresabschluss 2025 Schritt E2 (Freigabe Daniel 01.10.2026)');
```
Falls vorher die 10 Tresen-Rechnungen Dez 2025 (1'036.70) auf «bezahlt»
gesetzt werden: Basis 104'315.26 → Delkredere 5'215.76 → Betrag 413.62.

### 9d. Steuerrückstellung (Entscheid Daniel)

Vom gebuchten Gewinn 20'890.22 aus: − 7'216.30 (2020) + 361.78 (Delkredere)
= **14'035.70** mit Rückstellung 4'000. Steuerbar + 320 Bussen. Rückstellung
R so, dass R ≈ 18.2 % × (18'355.70 − R): R ≈ 2'826 → **2'800**. Buchung, wenn
Daniel zustimmt:
```sql
insert into buchungen (user_id, datum, belegnummer, soll_konto, haben_konto,
  betrag_netto, mwst_satz, mwst_betrag, betrag_brutto, beschreibung, zahlungsweg,
  beleg_typ, geschaeftsjahr, notizen)
values ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2025-12-31', 'JA2025_D2',
  2208, 8900, 1200.00, 0, 0, 1200.00,
  'Steuerrückstellung 2025 von 4''000 auf 2''800 angepasst (steuerbarer Gewinn ≈ 15''556)',
  'intern', 'abschluss', 2025,
  'Jahresabschluss 2025 Schritt D2 (Freigabe Daniel 01.10.2026)');
```
Danach: Gewinn 2025 = **15'235.70**, EK 31.12.2025 = 20'000 + 35'060.71 +
15'235.70 = **70'296.41**, steuerbar 15'555.70. Massgebend ist die App-Bilanz.
Provisorisch bezahlt 5'153.50 → Rückerstattung ≈ 2'300.

### 9e. Unterlagen (Fassung 2)

App-PDF Bilanz + ER per 31.12.2025 (Abschlüsse und Steuern → Bilanz und
Erfolgsrechnung) + `py -3 Datenbank/wartung/jahresrechnung_beilage.py --jahr
2025 --gewinn … --vortrag 35060.71 --ek … --debitoren … --delkredere …
--rueckstellung … --bank 12202.73 --kasse 6670.24 --bussen 320 --out …` (Anhang
OR 959c, Steuerbeilage mit Aufrechnung). Steuerjahr 2025 in der App:
steuerbarer Gewinn, Kapital, Status «eingereicht», Dokumente hochladen.

**Rollback 9a–9d:** Lauf L2 über die App zurücknehmen (löscht die 152
Zeilen und setzt die 76 Rechnungen zurück — auch nach dem Umbau, weil die
Positionen die Buchungs-Ids tragen); JA2025_A2_MWST, JA2025_E2, JA2025_D2
löschen (`belegnummer in (…)`). **Mit 215 gebucht:** die Rücknahme löscht die
76 Brutto-Zeilen UND die Sammelbuchung `JA2025_A_MWST_7_7_L2` selbst; von Hand
bleiben nur JA2025_E2 und JA2025_D2.
