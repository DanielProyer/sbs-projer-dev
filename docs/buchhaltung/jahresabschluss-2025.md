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
- Offen: Papierstapel Lieferantenrechnungen 2025? (falls 2025er-Belege dabei → Aufwand 2025 nachbuchen VOR Abschluss).

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
- Steuerzahlungen für 2025 (provisorisch/definitiv) gegen **2208** buchen, nicht 8900 — prüfen, ob die Belastung 05.05.2026 (2'748.00) die provisorische Rechnung 2025 ist → auf 2208 umbuchen.
- Delkredere jährlich auf 5 % des Debitorenbestands nachführen; Jahrgang 2020 im Abschluss 2026 abschreiben (76 Rg, 7'216.30).
- Tresen-Rechnungen Dez 2025, die per Excel-Delta bezahlt, aber noch «offen» sind (~20 Stück, z. B. Center Fontauna, Stau, Surselva, Hotel Chur) → Status nachziehen (Debitoren-Hygiene, ergebnisneutral).

