# Lohnbuchhaltung 2019–2026 — Soll-Ist-Abgleich (Stufe a)

**Erstellt:** 08.08.2026 · Auftrag Daniel: «Lohnbuchhaltung für alle Jahre, Sätze recherchieren/ableiten, Lohnausweise erstellen bzw. abgleichen» — Stufe (a) = rein lesender Abgleich.

**Quellen:** Lohnausweis-PDFs 2019–2024 (`20_Buchaltung/04_Lohnausweis/` + `00_Rechnungen/12_Lohnausweis/`), DB-Buchungen (journalgetreu = Excel), AXA-Prämien aus camt. Sätze: AHV/IV/EO paritätisch 10.25 % (2019) → 10.55 % (2020) → 10.6 % (ab 2021), ALV 2.2 % — AN-Anteil je hälftig: 6.225 % / 6.375 % / 6.4 % (inkl. ALV). FAK GR (nur AG): ~1.40–1.45 %, exakte Jahreswerte aus SVA-Abrechnungen zu verifizieren.

## 1. Die zentrale Erkenntnis: durchgängiger «Netto-Deal», Brutto rückwärts konstruiert

**Auszahlungen (Bücher) = Lohnausweis-Netto, alle Jahre EXAKT:** 52'000 · 88'500 · 77'100 · 61'000 · 58'500 · 59'500. Der Lohnausweis-Brutto wurde als Netto + Ziff. 9 + BVG konstruiert. **Ziff. 9 ist ab 2022 exakt 6.4 % vom NETTO** (statt vom Brutto): 61'000×6.4 % = 3'904 ✓ · 58'500×6.4 % = 3'744 ✓ · 59'500×6.4 % = 3'808 ✓. 2019–2021 andere Formeln (nicht exakt rekonstruierbar, gleiche Bauart).

## 2. Abgleich deklariertes Brutto vs. korrekt gerechnetes Brutto

Korrekt (Netto-Deal): Brutto = (Netto + BVG-AN) ÷ (1 − AN-Satz). BVG-AN = gebuchter hälftiger AXA-Beitrag.

| Jahr | Netto | Soll-Brutto | deklariert (Z.8) | **Diff** | Soll-AN-Beitrag | Z.9 deklariert | intern gebucht («8 %») |
|---|---|---|---|---|---|---|---|
| 2019 | 52'000 | 59'861 | 59'571 | **−290** | 3'726 | 3'429 | 3'666 |
| 2020 | 88'500 | 101'151 | 101'395 | **+244** | 6'448 | 6'693 | 6'372 |
| 2021 | 77'100 | 88'920 | 89'035 | **+115** | 5'691 | 5'806 | 5'570 |
| 2022 | 61'000 | 71'719 | 71'092 | **−627** | 4'590 | 3'904 | 4'880 |
| 2023 | 58'500 | 68'780 | 68'480 | **−300** | 4'402 | 3'744 | 4'680 |
| 2024 | 59'500 | 69'955 | 69'593 | **−362** | 4'477 | 3'808 | 4'760 |

**Summe der Brutto-Differenzen 2019–2024: −1'220 (zu tief deklariert)** — bei ~14 % Beitragswirkung (AHV/ALV/FAK) wären das grössenordnungsmässig **~170 CHF zu wenig Beiträge über 6 Jahre. Bagatellbereich — keine Behördenkorrektur nötig**, sofern die SVA-Deklaration dem Lohnausweis-Brutto entsprach (→ offener Punkt 5.1).

## 3. Einordnung der Audit-Befunde B4/B1

- **«AHV 8 % vom Netto»** (B4.2): Das war die **firmeninterne Aufwandbuchung** (z. B. 2022: 4'880 = 8 % × 61'000) — NICHT die Deklaration. Dem AN wurde real nie etwas abgezogen (Netto-Deal); es floss auch nicht zu viel an die SVA. Wirkung: Lohnaufwand-Konten leicht verzerrt, Lohnausweis unberührt.
- **«5000 liegt über Lohnausweis-Brutto»** (B1): erklärt — 5000 enthielt Auszahlung + AN-Beiträge als Aufwand inkl. NBU (2019: 52'000+8'857 = 60'857 vs. Z.8 59'571).
- **NBU:** Die Firma trug den NBU-Anteil (gebucht 1'020–1'560/Jahr, 2025: 0.00 — Prämie lief da schon über die AXA-Police auf 2273). Streng genommen wäre die NBU-Übernahme als Gehaltsnebenleistung auf dem Lohnausweis aufzurechnen — Kleinbetrag, pragmatisch: ab 2026 ist NBU=0 als Firmen-Übernahme entschieden (08.08.), Alt-Jahre belassen.
- **KTG:** nie AN-Abzüge — konsistent, kein Handlungsbedarf.

## 4. Lohnausweis 2025 — FEHLT, Vorschlag (korrekt gerechnet)

2025 wurde nie ein Lohnausweis erstellt. Auszahlungen 2025: **70'700**, BVG-AN gebucht 7'103.63. Korrekt:

| Ziffer | Wert |
|---|---|
| 8. Bruttolohn | **83'124** |
| 9. AHV/IV/EO/ALV (6.4 %) | **5'320** |
| 10.1 BVG | **7'104** |
| 11. Nettolohn | **70'700** |

(Alte Konstruktionsmethode hätte 82'329 ergeben — der korrekte Wert liegt 795 darüber.)

## 5. Offene Punkte für den Vollabschluss

- [ ] **5.1 SVA-Jahresabrechnungen 2019–2025 beiziehen** (Daniel: Ordner/Post SVA GR): bestätigt, welche Lohnsumme effektiv deklariert wurde (Erwartung: = Lohnausweis-Brutto). Erst damit ist die Behörden-Seite hart bewiesen. Auch: exakte FAK-/VK-Sätze GR pro Jahr daraus ablesen.
- [ ] **5.2 Lohnausweis 2025 erstellen** (Werte oben; via App-PDF-Service oder Formular) — vor der Steuererklärung 2025.
- [ ] **5.3 SVA-Lohnsumme 2026 melden** (Akonti 1'139.50/Q basieren auf altem Niveau; aufgelaufene Verbindlichkeit 4'043.20).
- [ ] **5.4 2026 normalisieren:** Jan–März laufen noch im Excel-Modell (Auszahlung 14'000 als «Brutto» gebucht, AN-Beiträge als Aufwand) — vor dem Lohnausweis 2026 auf das App-Modell umrechnen (wie Nachhol-Läufe April–Juli).
- [ ] **5.5 SUVA:** Wechsel UVG AXA→SUVA (Jahr?) — SUVA-Prämienrechnungen für die AG-Seiten-Zuordnung prüfen.
- [ ] G6-Restentscheide: Alt-Konten 2270–2273 umbenennen vs. umbuchen (Kosmetik, keine Zahlenwirkung).

**Quellen (FAK-Recherche):** [SVA Graubünden](https://www.sva.gr.ch/aktuelles.html) · [SVA St. Gallen FAK 2024](https://www.svasg.ch/news/meldungen/fak-beitragssaetze-2024.php) (Vergleichswert; GR-Jahreswerte aus SVA-Abrechnungen verifizieren)
