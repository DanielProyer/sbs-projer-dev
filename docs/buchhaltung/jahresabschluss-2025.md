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

### 9c. Delkredere nachziehen — in der App (seit v0.154.0)

Abschlussprüfung 2025 → Zeile «Delkredere = 5 % Debitoren» → Knopf «per 31.12.2025 buchen» (`AbschreibungService.delkredereSetzenPerStichtag`, Belegnummer `JA2025_E2`). Die SQL unten ist NUR der Rückfall, falls der Knopf fehlt — nie beides.

SQL-Rückfall:

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

### 9d. Steuerrückstellung — in der App (seit v0.154.0), Entscheid Daniel

Abschlussprüfung 2025 → Zeile «Steuerrückstellung 2208» → Knopf «Rückstellung buchen»: Dialog mit Gewinn vor Rückstellung, Aufrechnungen automatisch (6280/6281 netto 111.01 + 8900 `steuerart='busse'` 200.00 = 311.01), Satz 18.2 %, Vorschlag 2'800, Differenz → `JA2025_D2`. Die SQL unten ist NUR der Rückfall — nie beides.

Vom gebuchten Gewinn 20'890.22 aus: − 7'216.30 (2020) + 361.78 (Delkredere)
= **14'035.70** mit Rückstellung 4'000. Steuerbar + 311.01 Bussen. Rückstellung
R so, dass R ≈ 18.2 % × (18'346.71 − R): R ≈ 2'825 → **2'800**. Buchung, wenn
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

## 10. Vorprüfung 01.10.2026 — Monatsabschlüsse 2025 (Migrationen 217/218)

Vor Schritt 9a wurden die zwölf Monatsabschlüsse 2025 durchgesehen (SQL,
alle zehn Regeln). Zwei Ursachen für rote Zeilen, beide ohne neue Buchung und
ohne Wirkung auf Gewinn, Bilanz oder MWST:

| Regel | Monate | Ursache | Behebung |
|---|---|---|---|
| Heineken «ohne Ertragsbuchung» | Jan–Nov | Excel-Buchung 1100/3400 «Heineken Rechnung» je Monat (Belegordner 012) ohne `beleg_id`; Betrag = Monatsrechnung | 217: `beleg_id` + `beleg_typ 'rechnung'` auf 76 Buchungen 2019–11/2025, nur exakte Treffer |
| «Jede Reinigung hat ihre Ertragsbuchung» | Jan, Feb, Mär, Jun, Jul, Okt, Nov | 14 Excel-Reinigungen mit Trigger-Preis 74.59, in Excel nie verrechnet | 218: 6 Heineken-Monteur (`service_typ` NULL), 8 Kulanz — Entscheid Daniel |

Nicht verknüpft, weil Excel-Buchung und Rechnung abweichen (abgeschlossene
Jahre, Entscheid offen): 2019-05 (3'237.70 / 3'237.68), 2019-08 (4'366.16 /
4'204.61), 2022-05 (4'477.63 / 4'967.66). Die Rückwege stehen im Kopf der
beiden Migrationen. Ertrag 3400 im Jahr 2025 vor und nach 217: 213'571.17.
Die Falle dahinter: Der Hinweis «Im Detail der Rechnung nachholen» hätte den
Monatsertrag ein zweites Mal gebucht — bei Rechnungen aus der Excel-Ära nie
nachbuchen, sondern verknüpfen.

### 10a. Debitoren 1100 = offene Rechnungen: −4'315.85 zerlegt (01.10.2026, nach Lauf L2)

Die Abschlussprüfung 2025 meldet heute 1100 = 121'281.79 gegen offene
Rechnungen 125'597.64 (inkl. 658.35 Jahreskunden ohne Jahresrechnung). Per
SQL rappengenau nachvollzogen (Saldenlogik der App, MWST-Aufteilung):

| Teil | Befund |
|---|---|
| App-Ära ab 01.12.2025 | stimmt je Rechnung: 155 offene Kundenrechnungen 15'259.05 ↔ 1100-Soll 15'259.10; Heineken 08/2026 13'966.09 ↔ 13'966.09; 607 bezahlte ↔ Soll +0.60 / Haben +0.25 (Rundung). Beitrag **+0.40** |
| Excel-Ära bis 30.11.2025 | 1100 per 30.11.2025 = 116'255.48, offene Excel-Rechnungen per 30.11.2025 = 120'571.73 (heute offen 95'714.15 + seither bezahlt 3'628.95 + Heineken 10/11 + Seeblick 11'776.43 + abgeschrieben 9'452.20). Beitrag **−4'316.25** |

Innerhalb der Excel-Ära (Bestandteile, nicht additiv bis auf den Rappen):
- **11 offene Rechnungen ohne Forderungsbuchung in Excel, 1'073.40:** Alte
  Schwendi 01.01.2021 102.30 · Hotel Sport 18.10.2021 67.85 · Crestasee
  01.06.2022 85.10 (Notiz «in MR») · Krone 17.03.2023 107.70 · IKIGAI 67.85,
  Signina 85.10 (22.03.2023) · Il Pub 119.55, Indy Bar 142.15, Snake Bar
  107.70 (23.03.2023) · Türmli 18.07. und 29.08.2025 je 94.05. Dazu
  Preisabweichungen Spiga 2× (Excel 67.85, Rechnung 85.10) und Sunstar
  (Excel 154.00 «beide Anlagen», Rechnung 85.10). 33 weitere Treffer waren
  nur Namensvarianten (Arena Bar, WG Giovadin, Gipfelbar Setz Nair = Sezner,
  Alpina = Seven Alpina, Me and All Hotel, Vieri Bar, Central).
- **Excel-Zahlungen ohne Rechnung, ≈ 1'160:** «NOCH ABKLÄREN und Beleg»
  978.20 (4×, 2024–2025), «Service nicht erfasst» 124.30, «falscher Betrag»
  86.16/126.00/74.90, «Betrag in Euro» 86.15, Nachzahlung 100.00,
  Teilzahlung 18.45, Einzahlungen ohne Zuordnung 67.85 (unverknüpfte
  Zahlungseingänge 45'089.87 gegen 420 bezahlte Rechnungen ohne
  Zahlungsbuchung 43'929.90).
- **«KEIN BELEG, Pächter abgehauen» 271.40:** vier Excel-Ausbuchungen
  3400/1100 (Weiss Kreuz Cazis, Neustadt Chur, Oktober 2020) ohne Rechnung.
- **Heineken +161.55:** Monat 08/2019 in Excel 4'366.16 gebucht, Rechnung
  und Zahlung 4'204.61 (die drei nicht verknüpften Monate aus 217).
- Rest: Rundungen und kleine Doppel-/Fehlzuordnungen (z. B. 275.70 auf
  201.40, Ecqua 3'877.20 hebt sich auf).

**Einordnung:** Der Bilanzwert 1100 per 31.12.2025 (105'351.96) kommt aus
dem Hauptbuch und ist davon nicht berührt; das Delkredere rechnet darauf.
Betroffen ist nur die Rechnungsliste (Mahnwesen): rund 4'300 davon stehen
offen, ohne dass das Hauptbuch je eine Forderung kannte. Die Jahrgangs-
Abschreibung räumt sie mit den Jahrgängen ab (2021 im Abschluss 2026 usw.).

### 10b. Gebucht 01.10.2026 — Debitoren bereinigt (Migrationen 219–221, Schritt F)

Entscheid Daniel (vier Fragen einzeln): März-2023-Lücke buchen (beides per
31.12.2025), MWST in Q4/2026 auf Zeile 302, Verknüpfungen ohne Saldenwirkung,
Rest ausbuchen, bis die Regel grün ist. Arbeitslisten:
`debitoren-abgleich-excel-aera.md`.

| Beleg | Datum | Buchung | Betrag | Inhalt |
|---|---|---|---|---|
| Migration 219 | – | nur Verknüpfungen | 0.00 | 19 Excel-Zahlungen mit ihren Rechnungen verknüpft (4 exakt, 14 Zahldatum-Tippfehler korrigiert, Eisstadion Davos 124.30 bezahlt) |
| JA2025_F1 | 31.12.2025 | 1100 an 8000, 27 Buchungen | 2'383.45 | März-2023-Lücke, bezahlte Rechnungen (Zahlung auf 1100, Ertrag fehlte) |
| JA2025_F2 | 31.12.2025 | 1100 an 8000, 6 Buchungen | 630.05 | März-2023-Lücke, offene Rechnungen (bleiben offen, Jahrgang 2023 → Abschluss 2028) |
| JA2025_F3 | 31.12.2025 | 8000 an 1100 | 161.55 | Heineken 08/2019: Excel-Forderung zu hoch; dazu die drei Heineken-Monate aus 217 verknüpft, Rechnungsbeträge 05/2019 und 05/2022 auf Excel = Zahlung gesetzt |
| JA2025_F4 | 31.12.2025 | 1100 an 8000, 7 Buchungen | 1'169.15 | Zahlungen ohne Rechnung, Herkunft unklar (ohne MWST; bei Klärung nachdeklarieren) |
| JA2025_F_MWST | 01.10.2026 | 8000 an 2200 (mwst_konto 2200, 7.7 %) | 218.50 | MWST auf F1+F2 (33 Rg, netto 2'795.00), Ziff. 200/Zeile 302 Q4/2026 — **Umsatz 2'795.00 im Formular von Hand eintragen**, die App zeigt als Umsatz nur Konto 3400 |
| JA2025_F5 | 31.12.2025 | 1100 an 8000 | 170.45 | Schlussausgleich: Betragspaare (−106.38), Forderungen ohne Rechnung (+152.95), «KEIN BELEG» 2020, Rundungen |

Ergebnis per SQL (Saldenlogik der App): Regel «Debitoren 1100 = offene
Rechnungen» **0.00** · 1100 per 31.12.2025 **109'562.91** (vorher 105'351.96)
· Gewinn 2025 vor Delkredere/Rückstellung **17'865.47** (vorher 13'673.92,
+4'191.55 periodenfremder Ertrag auf 8000) · Delkredere 5 % neu **5'478.15**
→ Schritt 3 bucht `1109 an 3805 151.23` (statt 361.78) · alle 88
Heineken-Monate verknüpft.

Nicht gemacht (kosmetisch): 55 Sammelzahlungen bleiben je eine Buchung; die
Zuordnung zu ihren Rechnungen steht in `rechnungen.einzahlungsbeleg`
(Abschnitt E der Arbeitslisten). Rückwege in den Köpfen der Migrationen
219–221.

### 10c. Stand nach Schritt 3 und 4 (01.10.2026, per SQL)

Delkredere `JA2025_E2` 1109 an 3805 151.23 (1109 = 5'478.15 = 5 % von
109'562.91), Steuerrückstellung `JA2025_D2` 2208 an 8900 600.00 (Rückstellung
3'400: Gewinn vor Rückstellung 22'016.70 + Aufrechnungen 311.01, 18.2 % auf den
Gewinn nach Steuern, gerundet) — beide über die App.

| Grösse per 31.12.2025 | Wert |
|---|---|
| Aktiven = Passiven + kumulierter Erfolg | 125'025.23 = 71'347.82 + 53'677.41 |
| Gewinn 2025 | **18'616.70** (02.09.: 20'890.22; Jahrgang 2020 −7'216.30, Schritt F +4'191.55, Delkredere +151.23, Rückstellung +600.00) |
| Eigenkapital | **73'677.41** = 20'000 + Vortrag 35'060.71 + 18'616.70 |
| Debitoren 1100 / Delkredere 1109 | 109'562.91 / 5'478.15 |
| Bank 1020 (= camt) / Kasse 1000 | 12'202.73 / 6'670.24 |
| Steuerrückstellung 2208 / MWST 2200 | 3'400.00 / 0.00 |
| Steuerbarer Gewinn (Bussen 311.01 aufgerechnet) / Kapital | **18'927.71** / **73'677.41** |

Fassung 1 (02.09.) ist damit überholt; Fassung 2 über den App-Schritt
«Jahresrechnung» (Mehr → Abschlüsse und Steuern → Jahresabschluss → 2025).
