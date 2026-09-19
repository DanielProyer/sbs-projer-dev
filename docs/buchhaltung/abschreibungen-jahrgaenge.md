# Abschreibung offener Rechnungen — jahrgangsweise, mit MWST-Rückholung

**Stand:** 19.09.2026 · Grundlage: Datenbank vom selben Tag, ESTV-Abrechnungen Q4/2020, Q4/2022, Q2/2026, `docs/buchhaltung/jahresabschluss-2025.md`
**Politik (Entscheid Daniel, 02.09.2026, präzisiert 19.09.2026):** Ein Jahrgang wird im Abschluss des Jahres abgeschrieben, in dem er verjährt — fünf Jahre nach der Leistung. Also 2019 im Abschluss 2025 (erledigt), **2020 und 2021 im Abschluss 2026**, 2022 im 2027, 2023 im 2028, 2024 im 2029, 2025 im 2030. Nie gestellte Rechnungen werden **nicht nachversendet** (Entscheid 19.09.2026); sie laufen in derselben Reihe mit.

---

## 1. Wo wir stehen

### Jahrgang 2019 — erledigt bis auf einen Schritt

| | |
|---|---|
| Abschreibung | 29 Rechnungen, 21 Betriebe, **2'235.90 brutto**, je Rechnung `3805 an 1100` per 31.12.2025, Status `abgeschrieben` |
| MWST-Rückholung | **159.90** (7.7 %), Buchung `JA2025_A_MWST` (`2200 an 3805`) datiert 02.09.2026 — liegt im Journal |
| **Offen** | **Deklaration in der MWST-Abrechnung Q3/2026 unter Ziff. 235** (Entgeltsminderung), fällig bis 30.11.2026. Siehe Abschnitt 3 zum Steuersatz. |

Gegengeprüft am 19.09.: Von den 29 Rechnungen trug keine eine echte Zahlung. Die
«Einzahlungen» Ende Dezember 2025 in der Excel-Quelle sind Daniels eigener
Abschreibungsvermerk (Beleg `ABSCHREIBUNG`), keine Zahlungseingänge. **Der
Abschluss 2025 ist in diesem Punkt sauber.**

### Jahrgang 2020 — vorbereitet für den Abschluss 2026

| | |
|---|---|
| Bestand | **76 Rechnungen, 36 Betriebe, 7'216.30 brutto** = 6'699.87 netto + **516.43 MWST** (7.7 %) |
| Zahlungen | **keine** — keine Rechnung trägt in App oder Excel einen Zahlungseingang |
| Verjährung | alle verjährt (Art. 128 Ziff. 3 OR: fünf Jahre ab Fälligkeit; ohne Rechnung ab Leistung, Art. 75 OR) |

Wie die 76 zustande kamen — das ist für die Bewertung wichtig:

| Art | Anzahl | Befund |
|---|---|---|
| Tresen | 29 | Am Tresen übergeben, nie bezahlt. 28 davon hat Daniel im Excel bereits als `ABSCHREIBUNG` abgehakt. **Echte Debitorenverluste.** |
| Mail/Post, **gestellt** | 24 | Versandt (13 davon erst am 05.07.2022, zwei Jahre nach der Leistung) und nicht bezahlt. **Echte Debitorenverluste.** |
| Mail/Post, **nie gestellt** | 23 | Nur als Forderung im Excel, kein Versand. Der Kunde hat nie eine Rechnung gesehen. **Nie fakturierter Ertrag.** |

42 der 76 Rechnungen (3'618.90) stammen von Betrieben, die seit 2021 fünf und
mehr Rechnungen bezahlt haben — Helvetia, Tgantieni, Grand Hotel Surselva,
Confetti, Spiga, Franziskaner … Das sind keine schlechten Zahler. Es sind
Rechnungen, die sie nie oder zwei Jahre zu spät bekamen. Für die Abschreibung
2020 ändert das nichts (verjährt, nicht mehr stellbar), für die jüngeren
Jahrgänge alles — siehe Abschnitt 6.

---

## 2. Buchungslogik

**Je Rechnung, Datum 31.12. des Abschlussjahres:**

```
3805 Debitorenverluste   an 1100 Debitoren    netto      (Aufwand)
2200 Geschuldete MWST    an 1100 Debitoren    MWST       (Rückholung)
```

Beide `beleg_typ = 'abschreibung'`, `beleg_id` = Rechnung, Text
«Debitorenverlust <Nr> <Betrieb> (Abschreibung Jahrgang JJJJ, verjährt Art. 128 OR)».
Rechnung → `zahlungsstatus = 'abgeschrieben'`.

**Der MWST-Betrag kommt aus `rechnungen.mwst_betrag`** — der Steuer, die auf
diese Rechnung tatsächlich abgeliefert wurde — nicht aus dem Satz des
Buchungstages. Für 2020–2023 sind das 7.7 %, ab 2024 8.1 %. Wer den Satz des
Abschreibungstages nimmt, holt bei einem 2020er-Jahrgang 542.69 statt 516.43
zurück.

**Delkredere nachführen** (Konto 1109, Ziel 5 % des Debitorenbestands nach der
Abschreibung), Differenz gegen 3805. Per 31.12.2025 stand es auf 5'629.38.

**Anders als 2019:** Dort wurde brutto auf 3805 gebucht und die MWST erst im
Folgejahr zurückgeholt (`2200 an 3805`), weil Q4/2025 schon eingereicht war.
Ergebnis über zwei Jahre gleich, aber 2025 trug 159.90 zu viel Aufwand. Ab
2020 vermeiden wir das: siehe Zeitplan in Abschnitt 4.

---

## 3. MWST — drei Punkte, die geprüft sind

**a) Die Rückholung ist zulässig.** Sie setzt voraus, dass die Steuer auf die
abgeschriebenen Rechnungen damals deklariert wurde — also Abrechnung nach
*vereinbarten* Entgelten (Rechnungsstellung), nicht nach vereinnahmten
(Zahlung). Beleg: ESTV Q4/2020 deklarierte 26'792.01 netto = 28'855 brutto;
das Journal führt für Q4/2020 29'147 brutto Ertrag, die *bezahlten*
Rechnungen dagegen nur 21'442. Deklariert wurde, was gestellt war — Differenz
zum Journal rund 1 %. Die MWST der offenen 2020er ist damit abgeliefert und
darf zurückgeholt werden (Art. 41 Abs. 2 MWSTG: Korrektur in der Periode, in
der der Verlust eintritt).

*Restrisiko, benannt:* Über das ganze Jahr 2020 lag das Journal 825.28 USt über
den ESTV-Saldierungen (im Abschluss 2025 als Altlast über 8000 bereinigt). Ein
kleiner Teil der 2020er-Rechnungen könnte nie deklariert gewesen sein. Bei
516.43 Rückholung ist die Exposition gering; die Perioden gelten mit den
ESTV-Verfügungen als abgerechnet.

**b) Der Satz ist der der Leistung, nicht der des Abschreibungstages.**
2019–2023: 7.7 %, ab 2024: 8.1 %. Das aktuelle Formular (Q2/2026) führt die
Zeile **302 «Normalsatz 7.7 %»** neben 303 «8.1 %» weiter — die Rückholung
für Altjahrgänge gehört in die 7.7 %-Zeile. Würde man sie über 8.1 % laufen
lassen, ergäbe das für 2019 168.16 statt 159.90 (+8.26), für 2020 542.69 statt
516.43 (+26.26). **Beim Ausfüllen im ePortal prüfen, ob Zeile 302 im
Quartal eine negative bzw. reduzierende Eingabe annimmt; sonst ESTV-Hotline.**

**c) Formularmechanik:** Ziff. 235 (Entgeltsminderungen) = Netto-Summe der
abgeschriebenen Rechnungen des Jahrgangs, in Zeile 302 zum Satz 7.7 %. Die
Buchung `2200 an 1100` im Journal und die Deklaration müssen zusammen in
dieselbe Periode.

---

## 4. Ablauf für den Abschluss 2026 (Jahrgang 2020)

| Wann | Was |
|---|---|
| **Jetzt** | Nichts buchen. Liste ist bekannt (76 Rg). Bis Jahresende beobachten, ob doch eine Zahlung eintrifft (unwahrscheinlich). |
| **Q3/2026-Abrechnung** (bis 30.11.2026) | **Ziff. 235: 2'076.00 netto, Zeile 302 (7.7 %) → 159.90** — die 2019er-Rückholung, Buchung `JA2025_A_MWST` liegt bereits vor. |
| **Januar 2027**, vor der Q4/2026-Abrechnung | Jahrgänge **2020 und 2021** abschreiben, **datiert 31.12.2026**: 160 × (`3805 an 1100` netto + `2200 an 1100` MWST) = 15'374.70 brutto — **per App-Schritt «Jahrgang abschreiben»** (Abschlussprüfung 2026 → rote Zeile; seit v0.116.0, Abschnitt 5). Delkredere auf 5 % nachführen. Snapshot = Lauf-Tabellen. |
| **Q4/2026-Abrechnung** (bis 28.02.2027) | **Ziff. 235: 14'274.88 netto, Zeile 302 (7.7 %) → 1'099.82.** Aufwand und Rückholung fallen so ins selbe Jahr — kein Periodenversatz wie bei 2019. |
| **Abschlussprüfung 2026** | Regel «Offene Rechnungen älter als 5 Jahre» ist danach grün — Regel und Politik stimmen seit dem 19.09.2026 überein. |

Für die Folgejahre identisch mit verschobenem Jahrgang:

| Abschluss | Jahrgang | Rg | brutto | MWST (Satz) |
|---|---|---|---|---|
| 2026 | 2020 + 2021 | 160 | 15'374.70 | 1'099.82 (7.7 %) |
| 2027 | 2022 | 188 | 18'217.50 | 1'302.76 (7.7 %) |
| 2028 | 2023 | 154 | 17'217.85 | 1'228.85 (7.7 %) |
| 2029 | 2024 | 228 | 25'221.40 | 1'918.40 (8.1 %) |
| 2030 | 2025 | 289* | 30'327.10 | 2'266.10 (8.1 %) |

*\* 2025 enthält 35 App-Rechnungen vom Dezember 2025 im normalen Zahlungslauf — kein Altbestand.*
*Stand 19.09.2026; die Zahlen sinken, wo bis dahin doch noch bezahlt wird.*

---

## 5. Zwei Regelfragen, die Daniel entscheidet

**Politik «minus 6» oder «minus 5»? — Entschieden 19.09.2026: minus 5.** Die
Abschlussprüfung meldet Rechnungen als verjährt, sobald sie fünf Jahre vor dem
Stichtag liegen; per 31.12.2026 sind das die Jahrgänge 2020 **und** 2021. Die
ursprüngliche Lesart «2021 erst im Abschluss 2027» war konservativer als das
Recht und hätte die Regel 2026 rot gelassen. Jetzt: 2020 + 2021 zusammen im
Abschluss 2026 (160 Rg, 15'374.70, MWST 1'099.82). Regel und Politik stimmen
überein; an der Prüfregel ändert sich nichts.

**Werkzeug: App-Schritt oder SQL? — Entschieden 19.09.2026: App-Schritt.
Gebaut am selben Tag (v0.116.0, Migration 194).**
2019 lief per SQL mit Snapshot. Der alte `AbschreibungService` nahm den Satz
des Buchungstages (für Jahrgänge falsch) und setzte keinen Status; er nimmt
jetzt die MWST der Rechnung. Der Schritt selbst:

- **Einstieg:** Buchhaltung → Abschlussprüfung → rote Zeile «Offene Rechnungen
  älter als 5 Jahre» → Screen «Jahrgang abschreiben» (`/buchhaltung/abschreibung?jahr=`).
- **Vorschau:** Grenze Jahr − 5, je Jahrgang die Aufteilung Tresen / gestellt /
  nie gestellt, Summen netto und MWST je Satz mit Formularzeile (302/303),
  Ausschlüsse mit Grund (Zahlung vermerkt, Summe unstimmig), Liste aufklappbar.
- **Buchen:** ein Klick, eine Datenbank-Transaktion (`abschreibung_jahrgang_buchen`):
  je Rechnung `3805 an 1100` netto + `2200 an 1100` MWST aus `mwst_betrag`,
  Status `abgeschrieben`, Position in `abschreibung_positionen` mit Status
  vorher und beiden Buchungs-IDs, Lauf in `abschreibung_laeufe` mit Summen und
  MWST-Quartal. Die Funktion prüft jede Rechnung selbst nochmals; ein zweiter
  Lauf fürs selbe Jahr wird abgewiesen.
- **Rückweg:** «Lauf zurücknehmen» im selben Screen (`abschreibung_lauf_zuruecknehmen`):
  Buchungen weg, Status vorher — verweigert, sobald eine der Buchungen
  storniert wurde.
- **MWST-Abrechnung:** zeigt im Quartal des Laufs «Entgeltsminderung (Ziff. 235)»
  und die Rückholung je Satz. Der 2019er-Lauf ist nachgetragen (Q3/2026:
  2'076.00 → 159.90), aber nicht per App zurücknehmbar.

Probelauf 19.09.2026 in einer zurückgerollten Transaktion: 160 Rg, netto
14'274.88, MWST 1'099.82, brutto 15'374.70 — exakt die Zahlen aus Abschnitt 4.

*Schönheitsfehler, offen:* «gestellt» liest die App aus `versendet_am`, das
beim Excel-Import leer blieb. Für 2020+2021 zeigt sie deshalb 45 Tresen /
0 gestellt / 115 nie gestellt statt ~45 / ~62 / ~53. Migration 195 (Datei
bereit, nicht angewendet) trüge das Excel-Stelldatum für 516 Rechnungen nach —
Entscheid Daniel.

---

## 6. Der grössere Befund: nie gestellte Rechnungen 2021–2025

Die Excel-Spalte `rechnung_gestellt` zeigt, dass **ab 2023 praktisch keine
Mail-/Post-Rechnungen mehr gestellt wurden** (Excel: 2022 noch 52, 2023 7,
2024 0, 2025 2 — die App stellt seit 31.12.2025 wieder regelmässig). Die
«offenen Rechnungen» dieser Jahre sind zum grössten Teil Leistungen, für die
der Kunde **nie eine Rechnung erhalten hat**:

| Jahrgang | offen | davon Mail/Post nie gestellt | davon bei aktiven Zahlern (≥5 bezahlte Rg seither) | verjährt |
|---|---|---|---|---|
| 2021 | 84 | 36 | 13 Rg · 1'070.50 | im Lauf 2026 |
| 2022 | 188 | 115 | 53 Rg · 5'065.15 | im Lauf 2027 |
| 2023 | 154 | 119 | 71 Rg · **8'352.75** | im Lauf 2028 |
| 2024 | 228 | 188 | 112 Rg · **12'956.10** | im Lauf 2029 |
| 2025 | 289 | 188 | 104 Rg · **10'831.35** | im Lauf 2030 |

**Bei aktiven Kunden liegen aus 2023–2025 rund 32'000 CHF, die nie in Rechnung
gestellt wurden — nicht verjährt, Einzelbeträge 67–110 CHF, Kunden, die
seither jede Rechnung bezahlen.** Sie 2029–2031 abzuschreiben hiesse, Geld zu
verschenken, das mit einem Versand zu holen ist.

Buchhalterisch stehen diese Beträge heute als Ertrag und Debitoren im Buch;
die MWST darauf ist deklariert. Beim Nachversand entsteht keine neue Steuer —
die Rechnung existiert bereits, sie wird nur zugestellt. Zum Satz der Leistung
(2023: 7.7 %, ab 2024: 8.1 %) — die Rechnungen tragen ihn schon.

**Entscheid Daniel, 19.09.2026: nichts nachversenden.** Alle nie gestellten
Rechnungen bleiben in der jahrgangsweisen Abschreibung — 2023 im Abschluss
2028, 2024 im 2029, 2025 im 2030. Die Zahlen oben bleiben als Grundlage
stehen: Der Entscheid ist bis zur jeweiligen Abschreibung umkehrbar, eine
2024er-Rechnung lässt sich bis Ende 2029 stellen. Was zur Wahl stand — 2024
und 2025 nachversenden (~216 Rg, ~23'800 CHF), zusätzlich 2023 (~71 Rg,
~8'350 CHF) — ist damit nicht verworfen, sondern vertagt.

---

## 7. Rollback

**Ab 2026 (App-Lauf):** im Screen «Jahrgang abschreiben» → «Lauf zurücknehmen».
Das löscht beide Buchungen je Rechnung und setzt den Status aus
`abschreibung_positionen.status_vorher` zurück; der Lauf bleibt als
`zurueckgenommen` stehen. Per SQL dasselbe: `SELECT abschreibung_lauf_zuruecknehmen('<lauf-id>')`
als angemeldeter Nutzer. Delkredere-Buchung separat stornieren.

**2019 (SQL-Lauf, Abschluss 2025):** Buchungen mit `notizen LIKE 'Jahresabschluss
2025 Schritt A%'` löschen, Rechnungsstatus aus `snapshot_jahresabschluss_2025`
zurücksetzen, `JA2025_A_MWST` stornieren — der nachgetragene Lauf ist in der
App bewusst nicht zurücknehmbar (`ruecknahme_moeglich = false`).

Die MWST-Deklaration ist nach dem Einreichen nur über eine Korrekturabrechnung
rückgängig zu machen — deshalb erst buchen, dann prüfen, dann deklarieren.

---

## Quellen

- `docs/buchhaltung/jahresabschluss-2025.md` — Schritt A (2019), Schritt E (Delkredere), Rollback
- Journal: Buchungen `beleg_typ = 'abschreibung'`, `JA2025_A_MWST`, `JA2025_E`
- `import.einzahlung_excel` — Spalten `rechnung_gestellt`, `einzahlung`, `einzahlungsbeleg` (Wert `ABSCHREIBUNG` = von Daniel im Excel abgehakt)
- ESTV-Abrechnungen: Q4/2020 (`20_Buchaltung/90_Coronakrise/…/MWST Abrechnung 2019 und 2020/`), Q4/2022 (`20_Buchaltung/03_MWST_Abrechnung/`), Q2/2026 (`00_Rechnungen/02_MWST Abrechnung/`)
- `lib/services/buchhaltung/abschreibung_service.dart`, `abschluss_regeln.dart` (`DebitorenVerjaehrtRegel`)
- Art. 128 Ziff. 3 und Art. 75 OR; Art. 41 Abs. 2 MWSTG
