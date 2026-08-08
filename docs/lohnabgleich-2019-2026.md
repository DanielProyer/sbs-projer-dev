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

## 4b. Stufe (b) AUSGEFÜHRT 08.08.2026 — Umgliederung statt Massen-Umbuchung

Reines Umbenennen war nicht mehr möglich (seit den April–Juli-Lohnläufen tragen die Konten die korrekte Semantik, Alt-Bestände lagen verschoben darunter). Stattdessen **3 Salden-Umgliederungen per 31.03.2026** (reiner Passivtausch, ergebnisneutral):

| Buchung per 31.03.2026 | Betrag |
|---|---|
| 2271 an 2270 (AHV/ALV/FAK-Schuld an den richtigen Platz) | 4'055.97 |
| 2272 an 2271 (BVG-Schuld an den richtigen Platz) | 5'945.97 |
| 2272 an 2273 (UVG/SUVA-Soll-Saldo von 2273 weg) | 5'494.11 |

**Salden danach:** 2002 = 0.00 · 2270 AHV/ALV/FAK = 6'780.87 · 2271 BVG = 7'071.82 (rechnerisch exakt: Alt 5'945.97 + 4 Läufe 4'503.60 − AXA-Q2 3'377.75) · 2273 KTG = 0.00. Kontobezeichnungen in der DB waren bereits korrekt — Inhalt und Beschriftung passen jetzt zusammen.

**Aufwand-Nachholung B4.3 (Entscheid Daniel «Ja», 08.08.2026):** Der 2272-Negativsaldo (Prämien seit Dez 2024 bezahlt ohne Aufwandwirkung) ist mit 4 belegten Nachbuchungen aufgelöst:
- 31.12.2025: SUVA **definitive** Prämie 2025 = **1'125.40** (Beleg SUVA-Abrechnung 10.02.2026, Lohnsumme 70'700, BUV 0.6618 % + NBUV 0.93 %; prov. 1'910.15 bezahlt, 784.75 Rückerstattung = camt-Gutschrift 12.02. ✓)
- 31.12.2025: AXA Personenversicherung Professional 2025 = **1'290.00** (Police 44.127.389)
- 02.01.2026: SUVA provisorisch 2026 = **1'768.80** (Zahlung war 08.12.2025, Periode 2026)
- 28.01.2026: AXA Personenversicherung 2026 = **1'796.00**

Wirkung: Ergebnis 2025 −2'415.40, Ergebnis 2026 −3'564.80. **2272 danach = +731.04** = Altbestand 486.09 + aufgelaufene BU-AG-Beiträge 244.95 — rappengenau konsistent. Nebenbefund SUVA 2025: deklarierte Lohnsumme = 70'700 (= Auszahlungs-/Nettosumme) — bei der 2025er-Lohndeklaration (Soll-Brutto 83'124) mitziehen.

**FAK-Korrektur:** SVA-Factsheet (Scan) belegt FAK GR 2026 = **1.50 %** (2025: 1.60 %) — App-Einstellung stand auf 1.35 %. Einstellung + die 4 gebuchten FAK-Zeilen der Nachhol-Läufe korrigiert (April 89.15 · Mai 145.25 · Juni 121.20 · Juli 169.30).

**Amtliche Bestätigung der Soll-Formel:** Die SVA-«Anleitung zur Lohndeklaration» (ab 2023, Scan in `04_SVA/Unterlagen/`) schreibt die Aufrechnung wörtlich vor: «Werden Löhne ohne Abzug der Beiträge ausbezahlt, muss der Nettolohn mit 6,4 Prozent in einen Bruttolohn aufgerechnet werden: CHF 50'000 ÷ (100−6,4) × 100» — exakt die Divisions-Formel aus Abschnitt 2.

## 4c. 2026er-Normalisierung KOMPLETT (08.08.2026, Punkt 5.4 erledigt)

Die Excel-Stil-Lohnblöcke Jan+März 2026 (24 Zeilen, «Auszahlung als Brutto + Beiträge obendrauf») wurden gelöscht und durch **korrekte App-Lohnläufe** ersetzt (Bankzahlungen blieben unangetastet): **Jan Brutto 7'011.70/Netto 6'000 · März 9'148.45/8'000** (die 1'000 vom 23.03. steckt im April-Lauf). Damit sind alle 6 Lohnmonate 2026 im App-Modell, `lohn_abrechnungen` vollständig (Jan, Mär–Jul), **Lohnaufwand 5000/2026 = 51'151.45 = exakt die Summe der 6 Bruttos.** Die Umgliederungsbuchungen wurden auf die 31.12.2025-Basis nachjustiert (AHV 7'703.97 · BVG 9'372.07 · UVG 4'482.90) und die 5 Alt-Zahlungen Jan–Apr auf die richtigen Konten gedreht (BVG-Nachzahlung «Q2+Q3 2025» 6'239.40 → 2271 · SVA-Schlusszahlung 2025 5'962.20 → 2270 · AXA-Police 1'796 → 2272 · SUVA-Gutschrift 784.75 → 2272 · AXA-BVG Q 3'377.75 → 2271).

**End-Salden (alle rappengenau hergeleitet):** 2002 = 0.00 · **2270 AHV/ALV/FAK = 6'777.62** · **2271 BVG = 6'510.32** · **2272 UVG = +844.15** · 2273 KTG = 0.00. Nebenbefund: Die SVA hat 2025 **definitiv abgerechnet** («SVA 2025 - Restbetrag» 5'962.20 am 11.03.2026).

## 4d. Lohnausweis 2025 ERSTELLT + in der App verfügbar (08.08.2026)

- **Formular-PDF:** `00_Rechnungen/12_Lohnausweis/Lohnausweis 2025.pdf` (Form-11-Struktur, Ziff. 15 dokumentiert die Netto-Aufrechnung).
- **App:** `lohn_einstellungen` 2025 (Sätze 5.3/1.1/NBU 0/BU 0.66/FAK 1.60) + **12 Monats-`lohn_abrechnungen` 2025** angelegt (Netto = effektive Monatsauszahlungen, Brutto per SVA-Aufrechnungsformel, BVG = gebuchte Monatsanteile). Jahres-Totale runden auf **exakt dieselben Werte wie das Formular-PDF: 83'124 / 5'320 / 7'104 / 70'700.** → Lohnlauf-Screen, Jahr 2025, «Lohnausweis generieren».
- ⚠️ Semantik: Die 2025er-`lohn_abrechnungen` sind die **Soll-Darstellung fürs Lohnausweis-Modul** (`ist_gebucht=true` verhindert Doppelbuchung); die 2025er-BUCHUNGEN bleiben bewusst Excel-Journal-treu (siehe Abschnitt 3 — interne Systematik ≠ Lohnausweis).

## 4e. SVA-Belege gesichtet (08.08.2026) — Punkt 5.1 TEILWEISE beantwortet, Erwartung WIDERLEGT

Quelle: gescannte Originalbelege `00_Rechnungen/04_SVA/` — **vollständig gesichtet**: alle 43 Dokumente im Hauptordner und alle 24 in `Unterlagen/`. (Die übrigen 52 der 119 Scans sind Trennblätter; per Dateigrössen-Filter <208 KB aussortiert, an 4 Stichproben verifiziert.)

### 🔴 Befund 1: Ab 2020 wurde der NETTOlohn deklariert — 2019 war noch korrigiert worden

**Die Auflösung liegt in zwei Belegen zu 2019:**
- **Schlussrechnung 2019** (`1375181113`, 17.02.2020): AHV 10.250 % auf **Basis 52'000.00** — dem reinen Nettolohn. Handnotiz Daniel: «*Nachtrag Differenz — sva.gr.ch Nachtrag zur Lohndekl.*»
- **Nachtragsrechnung 2019** (`1332133964`, 24.08.2020): dieselbe Periode, jetzt **Basis 59'571.00** = exakt das Lohnausweis-Brutto 2019 → Nachzahlung 1'106.30.

**Daniel hat den Fehler 2019 also selbst bemerkt und per Nachtragsdeklaration korrigiert. Ab 2020 unterblieb dieser Nachtrag.**

| Jahr | deklarierte Basis (SVA) | Nettolohn (Konto 2002) | Lohnausweis Z.8 | Urteil |
|---|---|---|---|---|
| 2019 | **59'571.00** ✅ | 52'000 | 59'571 | korrekt (nach Nachtrag) |
| 2020 | **88'500.00** ❌ | 88'500 | 101'395 | = Nettolohn |
| 2021 | ⌂ 77'100 | 77'100 | 89'035 | Schlussrechnung 7'130.45 passt zur Netto-Basis |
| 2022 | ⌂ 61'000 | 61'000 | 71'092 | **rappengenau nachgerechnet** (s. u.) |
| 2023 | **58'500.00** ❌ | 58'500 | 68'480 | = Nettolohn |
| 2024 | ⌂ 59'500 | 59'500 | 69'593 | Schlussrechnung 4'267.10 passt |
| 2025 | **70'700.00** ❌ | 70'700 | *(83'124 neu erstellt)* | = Nettolohn |

✅ = belegt · ❌ = belegt, Nettolohn · ⌂ = rechnerisch erschlossen (keine Detail-Schlussrechnung im Archiv)

**Belegte Schlussrechnungen:** 2019 → 52'000 dann 59'571 · **2020 → 88'500** (Total 13'245.70) · **2023 → 58'500** (Total 4'605.30, darin 300.00 **Bussen** + 50.00 Mahngebühr «Einreichung Unterlagen») · **2025 → 70'700** (Total 5'962.20 = die SVA-Zahlung vom 11.03.2026).

**Dritte, unabhängige Bestätigung für 2020:** Die CO2-Rückverteilung 2022 (`1306217906`) nennt als Bemessungsgrundlage «AHV-Lohnsumme 2020, abgerechnet bei der AHV-Ausgleichskasse GR: **88'500.00**».

**2022 rappengenau nachgerechnet:** 61'000 × (AHV 10.6 % + ALV 2.2 % + FAK 1.65 %) + VK 5 % = 9'137.80 − Akonti 4 × 1'151.05 = **4'533.60** — exakt der Schlussrechnungsbetrag 2022. Für 2021 und 2024 stimmt dieselbe Rechnung im Rahmen der Rundungen/CO2-Gutschriften ebenfalls.

**Umfang:** Nicht deklarierte Lohnsumme **2020–2024 rund 55'900** (2019 ist korrigiert, zählt nicht mit); bei ~14.9 % Gesamtbeitrag grössenordnungsmässig **~8'300 CHF zu wenig Beiträge**. Rechnet man 2025 hinzu (12'424), kämen ~1'850 dazu. **Das ersetzt die frühere Bagatell-Einschätzung von «~170 CHF» aus Abschnitt 2.**

**Die Aufrechnungspflicht war jedes Jahr schriftlich beigelegt:** Die «Anleitung zur Lohndeklaration» nennt sie wörtlich — gültig ab 01.01.2019 (`1684434534`) mit **6,225 %** (Beispiel 50'000 → 53'319.00), ab 01.01.2023 (`1004523090`) und ab 01.01.2025 (`1401272057`) mit **6,4 %** (50'000 → 53'418.80).

### 🟢 Befund 2: FAK war doch im Aufwand — Ausweisthema, kein fehlender Aufwand

SVA-Total 2020 ohne Verzugszins = 9'336.75 + 1'947.00 + 1'460.25 + 466.85 = **13'210.85**.
Buchhaltung 2020: AN-AHV 6'372.00 + AG-AHV 6'372.00 + Verwaltungskosten 466.90 = **13'210.90** — Differenz **5 Rappen**.

Der interne «8 %»-Split war also eine reine Aufteilungsfiktion, deren **Summe exakt die SVA-Rechnung trifft**. Die FAK steckt in den «AG»-Zeilen auf 5700 und wurde nur nie separat auf 5710 ausgewiesen. Ein zwischenzeitlich vermuteter «~7'000 fehlender FAK-Aufwand» existiert nicht.

### Befund 3: Akonto-Grundlage seit April 2021 eingefroren auf 30'734

Die SVA setzte die Jahreslohnsumme am 25.01.2021 zunächst auf **88'500** (`1203094480`). Auf Daniels Antrag — Handnotiz «*Mail 31.03.2021 wegen Anpassung Lohnsumme*» auf der Q1-Rechnung (`1443425804`) — wurde sie am **09.04.2021 auf 30'734.00** herabgesetzt (`1356619190`). Diese Grundlage läuft **bis heute unverändert**: alle Akontorechnungen von Q3/2021 bis Q1/2026 rechnen mit **7'683.50 pro Quartal**, bei tatsächlichen Auszahlungen von 59'500–77'100.

Folge: jedes Jahr eine grosse Schlussrechnung plus Verzugszinsen und Mahngebühren. **Praktisch jeder Beleg im Ordner trägt einen Mahnvermerk** — Mahngebühren 24.35–87.05, Verzugszinsen 31.80–160.20, 2020 eine Ratenzahlung über zehn Monate, 2023 zusätzlich **CHF 300.00 Bussen** wegen nicht eingereichter Unterlagen. Auch die Deklarationen selbst gingen regelmässig erst nach Fristablauf ein (Handnotizen: 2022 «eingereicht via AHV-easy 30.01.23», 2023 «abgeschickt 02.02.24», 2024 «eingereicht 03.02.25», 2025 «eingereicht 10.02.26» — Frist ist jeweils der 30.01.).

Derselbe Mechanismus läuft 2026 weiter (Punkt 5.3) — beim Melden der neuen Lohnsumme gleich die Akonto-Grundlage mit anheben.

### Belegte Satz-Historie GR

| Jahr | AHV/IV/EO | ALV AG | FAK AG | VK AG |
|---|---|---|---|---|
| 2019 | 10.250 | 2.200 | 1.650 | 5.000 |
| 2020 | 10.550 | 2.200 | 1.650 | 5.000 |
| 2021/2022 | 10.600 | 2.200 | 1.650 | 5.000 |
| 2023 | 10.600 | 2.200 | 1.600 | 4.500 |
| 2024/2025 | 10.600 | 2.200 | 1.600 | 5.000 / 4.500 |
| 2026 | 10.600 | 2.200 | **1.500** | 5.000 |

Der VK-Satz schwankt nicht zufällig: Das «Merkblatt Verwaltungskostenbeiträge ab 01.01.2023» (`1911008591`) weist für Lohnsummen bis 100'000 **5.00 % ohne / 4.50 % mit AHVeasy** aus — der tiefere Satz gilt bei elektronischer Abwicklung.

## 5. Offene Punkte für den Vollabschluss

- [x] ~~**5.1a Restliche SVA-Scans sichten**~~ **ERLEDIGT 08.08.2026:** alle 67 Dokumente gesichtet (43 Hauptordner + 24 Unterlagen). Gefunden: Schlussrechnungen 2019 (beide Fassungen), 2020, 2023, 2025 im Detail; 2021/2022/2024 nur als Betrag aus Mahnungen/Verfügungen, rechnerisch aber eindeutig der Netto-Basis zuzuordnen. **Ausgefüllte Lohndeklarationen existieren nicht als Scan** — die Einreichung läuft seit 2022 über AHVeasy (Handnotizen belegen es); im Archiv liegen nur Begleitschreiben, Anleitungen, Merkblätter und Blanko-Formulare.
- [x] **5.1b ENTSCHIEDEN (Daniel, 08.08.2026): bisherige Deklaration belassen.** Die Lohnsummen 2019–2024 werden bei der SVA **nicht nachgemeldet**. Konsequenzen, bewusst in Kauf genommen: (a) die AHV-Gutschriften auf dem individuellen Konto bleiben auf Basis der deklarierten (Netto-)Lohnsummen stehen — geringere spätere Rentenbasis; (b) Lohnausweis (Steuer) und AHV-Deklaration bleiben für 2019–2024 nicht deckungsgleich; (c) bei einer AHV-Arbeitgeberkontrolle wäre die Differenz nachzuzahlen (Verjährung Beiträge: 5 Jahre ab Ende des Beitragsjahres, Art. 16 AHVG — die Jahre bis und mit 2020 sind heute verjährt, 2021–2024 grundsätzlich noch offen). **Ab 2025/2026 wird korrekt aufgerechnet deklariert** (Soll-Brutto per SVA-Formel, siehe Abschnitt 4d/5.3) — der Fehler läuft nicht weiter.
- [x] ~~**5.1 SVA-Jahresabrechnungen beiziehen**~~ — für 2020 erledigt, siehe Abschnitt 4e.
- [ ] **5.2 Lohnausweis 2025 erstellen** (Werte oben; via App-PDF-Service oder Formular) — vor der Steuererklärung 2025.
- [ ] **5.3 SVA-Lohnsumme 2026 melden** (Akonti 1'139.50/Q basieren auf altem Niveau; aufgelaufene Verbindlichkeit 4'043.20).
- [ ] **5.4 2026 normalisieren:** Jan–März laufen noch im Excel-Modell (Auszahlung 14'000 als «Brutto» gebucht, AN-Beiträge als Aufwand) — vor dem Lohnausweis 2026 auf das App-Modell umrechnen (wie Nachhol-Läufe April–Juli).
- [ ] **5.5 SUVA:** Wechsel UVG AXA→SUVA — **teilweise geklärt**: Das ausgefüllte Rückmeldeformular zur Lohndeklaration **2019** (`Unterlagen/1585525098`) nennt handschriftlich BVG = AXA und UVG = «**AXA (bisher)**»; das Formular **2025** (`Unterlagen/1509046298`) nennt BVG = AXA Stiftung und UVG = **Suva**. Der Wechsel liegt also zwischen 2020 und 2025 — das genaue Jahr aus den SUVA-Prämienrechnungen (`00_Rechnungen/05_SUVA/`) bestimmen.
- [ ] G6-Restentscheide: Alt-Konten 2270–2273 umbenennen vs. umbuchen (Kosmetik, keine Zahlenwirkung).

**Quellen (FAK-Recherche):** [SVA Graubünden](https://www.sva.gr.ch/aktuelles.html) · [SVA St. Gallen FAK 2024](https://www.svasg.ch/news/meldungen/fak-beitragssaetze-2024.php) (Vergleichswert; GR-Jahreswerte aus SVA-Abrechnungen verifizieren)
