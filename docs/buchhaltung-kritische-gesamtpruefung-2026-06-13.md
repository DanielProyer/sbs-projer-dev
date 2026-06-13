# Kritische Gesamtprüfung der Buchhaltung — 2026-06-13

Read-only Audit nach Vollimport (Phase 1) + Reconciliation (Phase 2a/2b). Grundlage: importierte `buchungen` 2019–Nov 2025 (+ native ab Dez 2025), MWST-korrekt, Bilanz ausgeglichen. Referenz: Lohnausweise + ESTV-Quartale aus der Beleg-Analyse ([[rechnungserkennung_historik]]).

## Schlüsselzahlen pro Jahr

| Jahr | Lohn 5000 | SVA 5700 | BVG 5720 | SUVA 5730 | Franchise 6301 | Erlös netto 3400 | MWST-Zahllast |
|---|---|---|---|---|---|---|---|
| 2019 | 60'857 | 3'933 | 4'135 | 1'056 | 29'294 | 108'237 | 5'244 |
| 2020 | 102'635 | 6'539 | 6'202 | 1'288 | 43'942 | 135'471 | 6'284 |
| 2021 | 90'152 | 3'998 | 6'129 | 1'353 | 43'942 | 113'003 | 4'527 |
| 2022 | 73'030 | 5'203 | 6'129 | 1'021 | 43'942 | 165'501 | 8'297 |
| 2023 | 70'586 | 4'990 | 5'878 | 1'528 | 45'105 | 164'991 | 8'014 |
| 2024 | 71'680 | 5'075 | 5'978 | 1'442 | 45'272 | 178'970 | 9'443 |
| 2025* | 78'738 | 5'690 | 6'702 | — | 41'500 | 196'023 | 11'786 |

\* 2025 bis Nov (Teiljahr).

---

## Befunde

### ⚠️ Zu prüfen (mit Daniel/Treuhänder)

**B1 — Lohnaufwand 5000 > Lohnausweis-Brutto um ~1–2k/Jahr (durchgängig).** Der „Vier-Löhne-Knoten":
| Jahr | App 5000 | Lohnausweis-Brutto | Diff |
|---|---|---|---|
| 2019 | 60'857 | 59'571 | +1'286 |
| 2020 | 102'635 | 101'395 | +1'240 |
| 2021 | 90'152 | 89'035 | +1'117 |
| 2022 | 73'030 | 71'092 | +1'938 |
| 2023 | 70'586 | 68'480 | +2'106 |
| 2024 | 71'680 | 69'593 | +2'087 |
Der gebuchte Lohnaufwand liegt **systematisch über** dem deklarierten Bruttolohn. Klären: enthält 5000 Posten, die nicht im Lohnausweis sind (z. B. AG-getragene Beiträge, Spesen), oder ist der Lohn überbucht? Relevant für AHV-Basis + Steuerbasis.

**B2 — Debitoren 1100 ≈ 116k (Nov 2025), wächst ~15–22k/Jahr.** Alte Jahrgänge **2019–2022 ≈ 50k** = Abschreibungs-Kandidaten (Phase 2c, Treuhänder: Höhe, welche Kunden, Delkredere 5% vs. definitive Abschreibung mit MWST-Rückholung).

**B3 — MWST-Zahllast 2023: App 8'014 vs. deklariert ≈ 6'635 (Diff +1'379).** Andere Jahre decken sich eng (2024 exakt, 2021 exakt). 2023 prüfen (Quartals-Timing oder Buchungsdifferenz).

### ✅ Geprüft & in Ordnung (positive Bestätigungen)

**P1 — Sozialversicherungen = nur AG-Anteil.** 5700/5720/5730 betragen ~Hälfte der Gesamtbeiträge (BVG 5720 ≈ 6'129 vs. Gesamtbeitrag ~12'375). Der AN-Anteil läuft korrekt als Lohnabzug → **entkräftet die frühere BVG-Doppelzähl-Sorge.**

**P2 — MWST plausibel.** Jahres-Zahllast deckt sich eng mit den deklarierten ESTV-Quartalen (2024 exakt, 2021 exakt; Summe 2019–2024 ≈ 41'900 vs. deklariert ≈ 42'700). Vorsteuer 1170/1171 ~3'000–5'000/Jahr (Franchise + Betriebsaufwand) plausibel.

**P3 — Franchise 6301 konsistent.** ~43'900–45'300/Jahr = Heineken 3'661/Monat (7.7 %) bzw. 3'773 (8.1 % ab 2024) — deckt sich mit Kat. 08.

**P4 — Corona-Hilfen** (Konto 5005 Lohnersatz): 2020 −3'768 (KAE), 2021 −32'302 (EO ~32'949) — plausibel, mindern Lohnaufwand korrekt.

**P5 — Bilanz geht auf** (Phase 2b, Differenz 0 an allen Jahresenden); **ER MWST-korrekt** (Phase 1.1); **Import vollständig & treu** (Phase 1.2, Treue-Gate 0 Diff).

### ℹ️ Hinweise (kein Handlungsbedarf)

**H1 — Negative Verrechnungssalden 2202 (MWST-Abrechnung) / 2273 (KTG) / 8900 (Steuern):** Durchlauf-/Timing-Konten, schwanken jährlich um 0 — keine Fehler, keine Abschreibung.

**H2 — Chronisch verspätete Zahlungen** (SVA/MWST/BVG, lt. Beleg-Analyse): allfällige Verzugszinsen/Mahngebühren sind teils in den Beitragszahlungen enthalten bzw. unter 6280 (Bussen, inkl. MWST-Strafe 2025) — separater Verzugszins-Aufwand nicht ausgewiesen. Für die Detailprüfung: ob alle Mahn-/Verzugskosten korrekt erfasst sind.

---

## Empfohlene nächste Schritte
1. **B1 (Lohn)** + **B3 (MWST 2023)** mit Daniel aufklären (Belege/Lohnabrechnungen).
2. **B2 (Debitoren-Abschreibung)** mit Treuhänder festlegen → Phase 2c umsetzen.
3. Danach Schlussbilanz für den Go-Forward (01.07.2026) bestätigen.
