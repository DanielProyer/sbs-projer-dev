# Steuererklärung 2025 — Ausfüllanleitung (SBS Projer GmbH, Kanton Graubünden)

Stand 01.10.2026, Zahlen aus der Jahresrechnung 2025 **Fassung 3** (App
v0.154.1, per SQL geprüft). Grundlage: Wegleitung 2025 JP der Steuerverwaltung
Graubünden (Formular 11a Kapitalgesellschaften), Hilfsformulare 12/13/14/17.

## 0. Zuerst: Frist

Die ordentliche Frist für Kapitalgesellschaften ist **9 Monate nach
Geschäftsabschluss = 30.09.2026**, sie ist seit gestern abgelaufen. Eine
Fristerstreckung wird nur **vor** Ablauf gewährt (einmalig, maximal 3 Monate).
Bei Nichteinreichung folgt zuerst eine Mahnung, keine Busse. Darum:

1. **Heute** kurze Mail an `revisorat@stv.gr.ch` (Tel. 081 257 33 67):
   > Betreff: Steuererklärung 2025 SBS Projer GmbH, CHE-413.083.919 — Einreichung in den nächsten Tagen
   > Sehr geehrte Damen und Herren, die Jahresrechnung 2025 der SBS Projer GmbH
   > wurde am 01.10.2026 fertiggestellt. Wir reichen die Steuererklärung 2025
   > elektronisch (SofTax GR JP) bis spätestens __.10.2026 ein und bitten um
   > Kenntnisnahme. Freundliche Grüsse, Daniel Projer, Geschäftsführer
2. Einreichen innerhalb weniger Tage.

## 1. Werkzeug: SofTax GR 2025 JP

- Download: gr.ch → Steuerverwaltung → Steuererklärung → Gewinn- und
  Kapitalsteuer → Deklarationssoftware → **SofTax GR 2025 JP** (Windows .msi,
  64-Bit; Standardversion bis 5 Steuererklärungen). Achtung: Version **2025**
  wählen, nicht 2026.
- Einreichung **elektronisch aus SofTax mit allen Beilagen als PDF**: dann ist
  keine Unterschrift und kein Quittungsblatt per Post nötig. Eine Einreichung
  nur per E-Mail gilt nicht.
- **Datei zum Einlesen:** SofTax JP kennt keinen Import von Buchhaltungs-
  oder Jahresrechnungsdaten (weder XML noch eCH). Übernommen werden können
  nur Stammdaten aus der SofTax-Datei des Vorjahrs, falls 2024 mit SofTax
  erstellt wurde (Datei → Vorjahresdaten übernehmen). Die Zahlen unten sind
  von Hand einzutippen: es sind rund 15 Werte.

## 2. Stammdaten (Seite 1)

| Feld | Wert |
|---|---|
| Firma | SBS Projer GmbH |
| UID / MWST | CHE-413.083.919 |
| Adresse | Via Rezia 8, 7013 Domat/Ems |
| Rechtsform | GmbH, Sitz Domat/Ems GR |
| Geschäftsjahr | 01.01.2025 – 31.12.2025 |
| Kontaktperson | Daniel Projer, Geschäftsführer |
| Beteiligungen, Liegenschaften, Betriebsstätten in anderen Kantonen/Ausland | keine |
| Zustellung Formulare Folgejahr | «Aufforderung zur Einreichung» ankreuzen (Deklaration per Software) |

## 3. Formular 11a — Reingewinn (Ziffern 1–12)

| Ziffer | Bezeichnung | Wert CHF | Herkunft |
|---|---|---|---|
| 1 | Reingewinn laut Erfolgsrechnung 2025 | **18'616.70** | ER Fassung 3, Jahresgewinn |
| 2 | Aufrechnungen: nicht abzugsfähige Bussen | **311.01** | Verkehrsbussen 6280 111.01 (netto) + Steuerbusse Kanton 200.00 (auf 8900) |
| 3 | Total | 18'927.71 | 1 + 2 |
| 4 | Abzüge | 0.00 | keine |
| 5 / 5.1 | Reingewinn nach Korrekturen / STAF-Entlastungen | 18'927.71 / 0.00 | keine STAF-Entlastung |
| 6 | Verlustverrechnung | **0.00** | Die Verluste 2019/2020 (41'257) sind 2021–2023 vollständig verrechnet, siehe Ziffer 28 unten. **SofTax trägt aus der Vorjahresdatei 41'257 ein und rechnet −22'329 — das ist falsch und muss auf 0 korrigiert werden** (derselbe Fehler stand in der Steuererklärung 2024, die Veranlagung hat ihn stillschweigend berichtigt). |
| 7 | **Steuerbarer Reingewinn** | **18'927.71** | = Steuerjahr 2025 in der App |
| 8 | Auslandanteil | 0.00 | – |
| 10 | Anteil andere Kantone | 0.00 | – |
| 11 | In Graubünden steuerbarer Reingewinn | **18'927.71** | = Ziffer 7 |
| 12 | Beteiligungsabzug | 0 | keine Beteiligungen |

Nicht aufzurechnen: direkte Steuern 8900 (abzugsfähig), Delkredere 5 %
(steuerlich anerkannte Pauschale auf Inland-Debitoren), Steuerrückstellung
3'400 (geschätzte Gewinn- und Kapitalsteuer 2025). Der periodenfremde Ertrag
6'367.89 auf 8000 ist im Reingewinn enthalten und wird besteuert; der Anhang
erklärt ihn.

## 4. Formular 11a — Kapital und Reserven (Ziffern 14–27)

| Ziffer | Bezeichnung | Wert CHF | Herkunft |
|---|---|---|---|
| 14 | Einbezahltes Stammkapital | **20'000.00** | Konto 2800, Handelsregister (2024 stand fälschlich 13'599; die Veranlagung 2024 hat 20'000 eingesetzt) |
| 15.1–15.4 | Offene Reserven (Kapital-, gesetzliche, freiwillige, übrige) | 0.00 | keine Reserven ausgeschieden |
| 16 | Nicht verteilte Gewinne (Bilanzgewinn nach Gewinnverwendung) | **53'677.41** | Vortrag 35'060.71 + Gewinn 2025 18'616.70, laut GV-Beschluss vollständig vorgetragen |
| 17 | ./. Eigene Kapitalanteile | 0.00 | – |
| 18 | Eigenkapital laut Bilanz | **73'677.41** | 14 + 16 |
| 19 | Als Gewinn versteuerte stille Reserven | 0.00 | – |
| 20 | Verdecktes Eigenkapital | **leer / 0.00** | Nur Gesellschafterdarlehen, soweit das Fremdkapital die zulässige Fremdfinanzierung nach ESTV-Kreisschreiben 6 übersteigt (100 % flüssige Mittel 18'872.97 + 85 % Forderungen ≈ 109'000 zulässig). Effektives Fremdkapital 51'347.82 inkl. Rückstellung → kein verdecktes Eigenkapital. Das Privatkonto 2260 (16'748.98, Guthaben Daniel) ist normales Fremdkapital: Formular 14 Code 01 und Formular 12 Ziffer 5. Frage Daniel 01.10.2026 («letztes Jahr als verdecktes Eigenkapital eingegeben?»): Im Formular 2024 war Ziffer 20 leer, die 13'599 standen in Ziffer 14; die Veranlagung 2024 setzte Kapital 55'319 = 20'000 + 35'319, nichts nachzuholen |
| 21 | Steuerbefreiter Betrag (ideeller Zweck) | 0.00 | – |
| 22 | Ermässigung des Eigenkapitals | 0.00 | – |
| 23 | **Steuerbares Eigenkapital** | **73'677.41** | = Steuerjahr 2025 in der App |
| 24 / 26 | Ausland / andere Kantone | 0.00 | – |
| 27 | In Graubünden steuerbares Eigenkapital | **73'677.41** | – |

## 4a. Formular 11a — Ziffer 13 Gewinnverwendung (laut GV-Beschluss)

| Ziffer | Bezeichnung | Wert CHF |
|---|---|---|
| 13.1 | Gewinnvortrag aus dem Vorjahr | **35'060.71** (SofTax übernimmt 35'319 aus der Datei 2024 — überschreiben; siehe Bemerkung unten) |
| 13.2 | Reingewinn gemäss Erfolgsrechnung (Hertrag Ziffer 1) | 18'616.70 |
| 13.3 | Entnahmen aus den Reserven | 0.00 |
| 13.4 | Total zu verteilender Gewinn | 53'677.41 |
| 13.5–13.8 | Dividenden, Zuweisungen an Reserven, Übrige | 0.00 |
| 13.9 | Total Gewinnverwendung | 0.00 |
| 13.10 | Vortrag auf neue Rechnung | 53'677.41 (= Ziffer 16) |

**Warum 35'060.71 und nicht 35'319:** Die Steuererklärung 2024 setzte in 13.2
den steuerbaren Gewinn 28'399 statt des handelsrechtlichen 28'277.51 ein und
in 13.1 einen Vortrag von 6'920 statt 6'783.20; so entstand 35'319
(Differenz 258.29). Massgebend ist die Handelsbilanz: Eigenkapital
31.12.2024 = 55'060.71 (Vorjahresspalte der Jahresrechnung Fassung 3),
Vortrag 01.01.2025 = 35'060.71, Eigenkapital 31.12.2025 = 73'677.41. In
**Ziffer 32 Bemerkungen** eintragen: «Gewinnvortrag 01.01.2025 gemäss Bilanz
35'060.71; die Steuererklärung 2024 wies 35'319 aus (Reingewinn 2024
handelsrechtlich 28'277.51 statt 28'399, Vortrag 2023 6'783.20). Eigenkapital
31.12.2024 laut Bilanz 55'060.71.»

## 4b. Ziffer 28 Verlustverrechnung — so stimmt die Tabelle

Verrechenbar sind Verluste der sieben Vorjahre (2018–2024), soweit nicht schon
mit späteren Gewinnen verrechnet. Stand laut Veranlagungsverfügungen (Dossier):

| Geschäftsjahr | Verlust | Verrechnet in | Betrag |
|---|---|---|---|
| 2019 (Rumpfjahr) | 4'973 | 2021 | 4'973 |
| 2020 | 36'284 | 2021 / 2022 / 2023 | 11'099 / 18'049 / 7'136 |
| Zwischentotal Vorjahresverluste | **41'257** | | |
| Abzüglich bereits verrechnete Verluste | **41'257** | (2021: 16'072 · 2022: 18'049 · 2023: 7'136 laut Verfügungen vom 06.03.2023, 05.12.2023, 10.12.2024) | |
| Verrechenbarer Verlust (Übertrag auf Ziffer 6) | **0** | | |

In SofTax: entweder die zwei Verlustzeilen stehen lassen und in «Abzüglich
bereits verrechnete Verluste» 41'257 eintragen, oder die beiden Zeilen
löschen. Ergebnis in beiden Fällen: Ziffer 6 = 0, Ziffer 7 = 18'928.

## 5. Ergänzende Fragen (Ziffern 28–31)

| Ziffer | Antwort |
|---|---|
| 28 Verlustverrechnung | Tabelle wie unten ausfüllen: Verluste 2019 und 2020 aufführen, als «bereits verrechnet» 41'257 eintragen, verrechenbarer Verlust **0** |
| 29 Immobiliengesellschaft | nein |
| 30 Gesellschaft ohne Geschäftstätigkeit | **nein** (2024 stand fälschlich «ja», die Steuerberechnung rechnete mit Mindeststeuer; SofTax übernimmt das Häkchen aus dem Vorjahr) |
| 31 Multinationale Gruppe (OECD-Mindeststeuer) | nein |

## 6. Hilfsformulare

**Formular 12 — Bescheinigung über Leistungen an Gesellschafter** (eine
Zeile in der Übersicht, ein Formular: Daniel Projer, einziger Gesellschafter
und Geschäftsführer). Werte per SQL 01.10.2026. Antworten Daniel 01.10.2026:
die Büromiete (Konto 6000, 12 × 250.00 = 3'000) geht an ihn privat (Büro in
der Wohnung) und wird **wie in den Vorjahren nicht angegeben** (Entscheid
Daniel 01.10.2026); das Servicefahrzeug gehört Heineken, Leasing über die
AXA — die GmbH zahlt nur Benzin, Reparaturen und Vignette.

**Übersicht (Seite mit den zehn Zeilen):** Name **Projer**, Vorname
**Daniel** (SofTax hatte die beiden Felder vertauscht), AHV-Nr.
**756.7321.6431.61** (aus den Lohn-Einstellungen, Lohnausweis Ziffer «AHV-Nr.»;
die EAN-13-Prüfziffer stimmt, in der Datenbank stecken keine versteckten
Zeichen). Weist SofTax die Nummer ab («ungültig»): Feld komplett leeren und
die 13 Ziffern **ohne Punkte von Hand tippen** (7567321643161), nicht
einfügen — eingefügte Leer- oder Steuerzeichen lassen die Prüfung scheitern.
Bleibt die Meldung, die Nummer mit dem AHV-Versichertenausweis vergleichen
und bei einem Tippfehler auch die Lohn-Einstellungen in der App und den
Lohnausweis 2025 korrigieren.

**Ziffer 1 — Leistungsempfänger**

| Feld | Eintrag |
|---|---|
| Name / Vorname | Projer / Daniel |
| AHV-Nr. | 756.7321.6431.61 |
| Funktion | Gesellschafter (100 %) und Geschäftsführer |
| Genaue Wohnsitzadresse | Via Rezia 8, 7013 Domat/Ems |
| «Falls nicht identisch mit Leistungsempfänger» | leer |
| Beteiligung am Stammkapital | **Ja**, Anteil Fr. **20'000** |
| Quellensteuer bei Wohnsitz im Ausland | leer (Wohnsitz in der Schweiz) |
| Geschäftsjahr | 2025 (zweites Feld leer) |

**Ziffer 2 — Leistungs- und Funktionsentgelte** (Spalte Total; die Spalte
«zweites Kalenderjahr» bleibt leer)

| Ziffer | Eintrag CHF | Herkunft |
|---|---|---|
| 2.1 Gehalt, Lohn | **83'124** | Lohnausweis Ziffer 8 |
| 2.2 Tantiemen | leer | keine |
| 2.3 Verwaltungsratshonorare | leer | keine |
| 2.4 Sonstige Vergütungen | leer | Entscheid Daniel 01.10.2026: die Büromiete an ihn privat (Konto 6000, 3'000) wird wie in den Vorjahren nicht angegeben. Zur Kenntnis: Die beigelegte Jahresrechnung zeigt Konto 6000 «Mietaufwand» 3'000 bei Firmensitz = Wohnadresse; fragt die Steuerverwaltung nach, gilt die Miete als Leistung an den Gesellschafter und privat als Einkommen aus Untervermietung (Nachsteuer auf 3'000) |
| 2.5 Total brutto | 83'124 (rechnet SofTax) | |
| 2.6 Abzüge AHV/IV/EO/ALV/NBUV | **5'320** | Lohnausweis Ziffer 9 |
| 2.6 Abzüge berufliche Vorsorge | **7'104** | Lohnausweis Ziffer 10 |
| 2.7 Total netto | 70'700 (rechnet SofTax, = Lohnausweis Ziffer 11) | |

**Ziffer 3 — Spesenvergütungen** (Spalte «effektiv»; «pauschal» und
«verbuchter Privatanteil» bleiben leer)

| Ziffer | Eintrag CHF | Herkunft |
|---|---|---|
| 3.1 Repräsentationsspesen | leer | |
| 3.2 Autospesen für das Privatfahrzeug | leer | kein Privatfahrzeug im Einsatz: Benzin 6200 7'389.62, Reparaturen 6250 945.00, Bewilligungen/Vignette 6275 251.30 (brutto) betreffen das Heineken-Fahrzeug |
| 3.3 Reisespesen | **3'014** | Konto 5820: 235 Verpflegungsbelege auswärts (Mittag-/Abendessen), brutto 3'014.20, netto 2'907.42 (Vorsteuer 106.72) |
| 3.4 Übrige Spesen | leer | |
| 3.5 Total | 3'014 | |

Der Lohnausweis 2025 im Dossier weist unter Ziffer 13 keinen Spesenbetrag
aus; richtig wäre 13.1.1 «effektive Spesen» 3'014. Der Betrag im Formular 12
ist trotzdem korrekt, die Steuerverwaltung sieht nur die Abweichung zum
Lohnausweis (ab Lohnausweis 2026 ausweisen, siehe ToDo).

**Ziffer 4 — private Nutzung**

| Ziffer | Eintrag |
|---|---|
| 4.1 Geschäftsfahrzeug | **Nein** — das Fahrzeug gehört Heineken Switzerland (Leasing AXA), nicht der GmbH; sie trägt nur die Betriebskosten. Wird es auch privat gefahren, gilt das trotzdem als Privatanteil (0.9 % des Kaufpreises je Monat, Lohnausweis Ziffer 2.2) — dann «Ja» und Marke/Kaufpreis von Heineken erfragen |
| 4.2 Telefon, Radio, TV | Nein (Geschäftshandy, Konto 6510) |
| 4.3 Räumlichkeiten | Nein |
| 4.4 Heizung, Strom | Nein |
| 4.5 Versicherungsprämien | Nein |
| 4.6 Übrige | Nein (Privateinkäufe laufen über das Privatkonto 2260, nicht über den Aufwand) |

**Ziffer 5 — Darlehen und Kontokorrente:** hat in SofTax **keine
Eingabefelder** (geprüft 01.10.2026), nur den Hinweis «Sämtliche Darlehens-
und Kontokorrentbeziehungen sind mittels Kontokopien zu dokumentieren». Also
nichts eintragen; das Privatkonto 2260 wird so dokumentiert:

| Wo | Eintrag |
|---|---|
| Formular 14 Schuldenverzeichnis | Daniel Projer, Kontokorrent (2260) 16'748.98, Code 01 |
| Beilage | Kontoauszug 2260 für 2025 (App: Buchhaltung → Konto 2260 → PDF): Saldo 01.01.2025 13'933.21, Gutschriften 2'815.77 (privat bezahlte Geschäftsauslagen: Benzin/AdBlue/Vignette 1'444.77, Arbeitskleider 430.20, Verpflegung 404.15, Material 277.80, MS Office 167.40, Kehrichtsäcke 91.45), Bezüge 0.00, Saldo 31.12.2025 16'748.98, unverzinst |

Datum 01.10.2026; bei elektronischer Einreichung keine Unterschrift.

**Formular 13 — Wertschriften und Guthaben:**

| Guthaben | Saldo 31.12.2025 | Ertrag 2025 | Verrechnungssteuer |
|---|---|---|---|
| Graubündner Kantonalbank, Kontokorrent CH66 0077 4010 3765 5060 1 | 12'202.73 | 0.00 | 0.00 |

(Beleg: GKB Zins-/Kapitalausweis 2025 im Dossier.) Kasse 6'670.24 gehört nicht
hierher, nur in die Bilanz.

**Formular 14 — Schuldenverzeichnis** (Stand 31.12.2025, alle unverzinst):

| Gläubiger | Betrag | Code |
|---|---|---|
| Kreditoren Lieferanten (Konto 2000) | 7'545.40 | – |
| MWST-Abrechnungskonto ESTV (2202) | 6'577.40 | – |
| Daniel Projer, Privatkonto / Kontokorrent (2260) | 16'748.98 | **01** (Gesellschafter) + Kontoauszug |
| SVA Graubünden AHV/IV/EO/ALV (2270) | 7'703.97 | – |
| AXA BVG / Pensionskasse (2271) | 9'372.07 | – |
| Total Schulden | 47'947.82 | (ohne Rückstellung 2208) |

**Formular 17 — Abschreibungen und Rückstellungen:** Seite 1 Abschreibungen:
keine (kein Anlagevermögen). Seite 2 Rückstellungen und Wertberichtigungen:

| Position | Betrag 31.12.2025 | Vorjahr | Begründung |
|---|---|---|---|
| 2208 Rückstellung Gewinn- und Kapitalsteuern 2025 | 3'400.00 | 0.00 | 18.2 % auf dem steuerbaren Gewinn nach Steuern, kalibriert an der Veranlagung 2024 |
| 1109 Delkredere (Wertberichtigung Debitoren) | 5'478.15 | 0.00 | 5 % pauschal auf Inland-Debitoren 109'562.91 |

Statt der Formulare 13/14/17 dürfen auch eigene Aufstellungen mit demselben
Inhalt eingereicht werden (Wegleitung «Beilagen»); die Jahresrechnung
Fassung 3 enthält Bilanz und ER je Konto, was die Steuerverwaltung
zusätzlich zur Mindestgliederung ausdrücklich wünscht.

## 7. Beilagen (als PDF in SofTax anhängen)

1. Jahresrechnung 2025 Fassung 3, **unterschrieben** (ausdrucken,
   unterschreiben, scannen) — App: Jahresabschluss → Schritt 6 →
   «Jahresrechnung herunterladen» (ab v0.154.2).
2. Lohnausweis 2025 (Dossier).
3. GKB Zins-/Kapitalausweis 2025 (Dossier).
4. Beschluss der Gesellschafterversammlung 2025, unterschrieben
   (`beschluss-gesellschafterversammlung-2025.md`, PDF-Entwurf liegt bei).
5. Kontoauszug Privatkonto 2260 (Formular 12/14, Code 01).

## 8. Nach dem Versand

✅ **Eingereicht am 01.10.2026** (elektronisch aus SofTax). Quittung/Steuererklärung
im Dossier Steuern → 2025 (Typ Steuererklärung, Referenz 130444), Steuerjahr
2025 auf «eingereicht» mit Datum 01.10.2026.

**Provisorische Steuerberechnung SofTax (01.10.2026, geprüft):** Gewinn
18'900 × 4.05 % = 765, Kapital 73'600 × 2.07 ‰ = 152, Zuschlag FAG 95 % 968,
Kultussteuer 11.3 % 115 → Kanton 2'000; Bund 18'900 × 8.5 % = 1'607;
**total 3'607**. Rückstellung 2208 3'400 → bei der definitiven Veranlagung
≈ 207 auf 8900. Provisorisch bezahlt 5'153.50 → Rückerstattung ≈ 1'546.50.

- Übermittlungsquittung aus SofTax als PDF speichern und in der App ablegen:
  Steuern → 2025 → Dokument hochladen (Typ Steuererklärung).
- Steuerjahr 2025: Status «eingereicht», Datum; steuerbarer Gewinn 18'927.71
  und Kapital 73'677.41 stehen schon drin.
- Provisorisch bezahlt 5'153.50 (Bund 2'405.50, Kanton 2'748.00), Rückstellung
  3'400 → nach der definitiven Veranlagung Differenz gegen 2208 buchen
  (Rückerstattung ≈ 1'753.50).
- MWST Q4/2026: Zeile 302 Umsatz +2'795.00 (Steuer 218.50 schon gebucht) und
  Ziff. 235 516.43 nicht vergessen.
