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
| 6 | Verlustverrechnung | 0.00 | keine Vorjahresverluste (Ziffer 28 leer) |
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
| 14 | Einbezahltes Stammkapital | **20'000.00** | Konto 2800 |
| 15.1–15.4 | Offene Reserven (Kapital-, gesetzliche, freiwillige, übrige) | 0.00 | keine Reserven ausgeschieden |
| 16 | Nicht verteilte Gewinne (Bilanzgewinn nach Gewinnverwendung) | **53'677.41** | Vortrag 35'060.71 + Gewinn 2025 18'616.70, laut GV-Beschluss vollständig vorgetragen |
| 17 | ./. Eigene Kapitalanteile | 0.00 | – |
| 18 | Eigenkapital laut Bilanz | **73'677.41** | 14 + 16 |
| 19 | Als Gewinn versteuerte stille Reserven | 0.00 | – |
| 20 | Verdecktes Eigenkapital | 0.00 | Fremdkapital 51'347.82 = 41 % der Aktiven, weit unter 80 %; das Privatkonto 2260 ist keine verdeckte Eigenkapitalfinanzierung |
| 21 | Steuerbefreiter Betrag (ideeller Zweck) | 0.00 | – |
| 22 | Ermässigung des Eigenkapitals | 0.00 | – |
| 23 | **Steuerbares Eigenkapital** | **73'677.41** | = Steuerjahr 2025 in der App |
| 24 / 26 | Ausland / andere Kantone | 0.00 | – |
| 27 | In Graubünden steuerbares Eigenkapital | **73'677.41** | – |

## 5. Ergänzende Fragen (Ziffern 28–31)

| Ziffer | Antwort |
|---|---|
| 28 Verlustverrechnung | leer (keine Verluste 2018–2024) |
| 29 Immobiliengesellschaft | nein |
| 30 Gesellschaft ohne Geschäftstätigkeit | nein |
| 31 Multinationale Gruppe (OECD-Mindeststeuer) | nein |

## 6. Hilfsformulare

**Formular 12 — Leistungen an Gesellschafter / Geschäftsführung** (ein
Formular für Daniel Projer, einziger Gesellschafter und Geschäftsführer):

| Angabe | Wert CHF | Herkunft |
|---|---|---|
| Bruttolohn 2025 (Lohnausweis Ziffer 8) | 83'124 | Lohnausweis im Dossier |
| Nettolohn (Lohnausweis Ziffer 11) | 70'700 | – |
| Spesen | effektive Spesen laut Beleg (Lohnausweis Ziffer 13.1 angekreuzt), kein Pauschalbetrag | Konto 5820 2'907.42 |
| Kontokorrent / Darlehen Gesellschafter | Privatkonto 2260: **16'748.98** Guthaben Daniel Projer gegenüber der GmbH per 31.12.2025 (Vorjahr 13'933.21), unverzinst | Kontoauszug 2260 beilegen (App: Buchhaltung → Konto 2260, PDF) |
| Dividende, Tantiemen, Naturalbezüge, Privatanteil Fahrzeug | keine | wie Vorjahre |

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

- Übermittlungsquittung aus SofTax als PDF speichern und in der App ablegen:
  Steuern → 2025 → Dokument hochladen (Typ Steuererklärung).
- Steuerjahr 2025: Status «eingereicht», Datum; steuerbarer Gewinn 18'927.71
  und Kapital 73'677.41 stehen schon drin.
- Provisorisch bezahlt 5'153.50 (Bund 2'405.50, Kanton 2'748.00), Rückstellung
  3'400 → nach der definitiven Veranlagung Differenz gegen 2208 buchen
  (Rückerstattung ≈ 1'753.50).
- MWST Q4/2026: Zeile 302 Umsatz +2'795.00 (Steuer 218.50 schon gebucht) und
  Ziff. 235 516.43 nicht vergessen.
