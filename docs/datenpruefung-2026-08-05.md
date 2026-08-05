# Datenprüfung SBS Projer — 05.08.2026

**Stand:** 05.08.2026 · **App live:** v0.72.1 · **Datenbank:** sbs-projer-prod
**Umfang:** 6 Prüfbereiche (Stammdaten, Anlagen/Reinigungen, Rechnungen, Buchhaltung,
Bankauszug, Saison/Touren), nur lesend. Die schwersten Funde habe ich am Code und an
den Buchungen selbst nachgeprüft.

---

## Das Wichtigste zuerst

Der operative Betrieb ist gesund: Reinigungen, Störungen, Rechnungen und Buchungen sind
tagesaktuell, der Umsatz wächst stetig (2019 CHF 63'614 → 2025 CHF 120'061, 2026 nach
sieben Monaten bereits CHF 75'663), Netto + MwSt = Brutto stimmt bei **allen** 8'500
Reinigungen und 5'145 Rechnungen, und die Bank stimmte per Stichtag **auf den Rappen**.

Die Probleme liegen auf der Geldseite — und zwei davon laufen **heute noch weiter**:

| | |
|---|---|
| MwSt doppelt gebucht, seit 01.12.2025, jede Rechnung | **CHF 10'172.28** |
| Bankbewegungen unverbucht seit 12.03.2026 (147 Tage) | **≥ CHF 99'470** |
| Offene Forderungen gesamt | **CHF 173'123** |
| davon nie an den Kunden zugestellt | **CHF 34'478** |
| Heineken versendet, nicht als bezahlt erfasst | **CHF 19'082** |
| Heineken Juli 2026 — Rechnung fehlt ganz | **CHF ~5'325** |

---

## A. Läuft heute noch falsch — zuerst anfassen

### A1 · Die MwSt wird bei jeder Rechnung doppelt gebucht

**890 Buchungen · CHF 10'172.28 · seit 01.12.2025 · betrifft jede neue Rechnung**

Jede Reinigung erzeugt zwei Buchungen:

| | Soll | Haben | MwSt-Konto | Netto | MwSt | Brutto |
|---|---|---|---|---|---|---|
| Hauptbuchung (`rechnung`) | 1100 | 3400 | **2200** | 133.00 | 10.75 | 143.75 |
| Zusatzbuchung (`mwst`) | 3400 | 2200 | – | 10.75 | 0.00 | 10.75 |

Die Absicht war die Bruttomethode: brutto auf 3400 buchen, dann die MwSt herausnehmen.
Der Haken: Die Hauptbuchung setzt **zusätzlich** `mwst_konto = 2200`, und die
Saldenrechnung der App (`saldo_expansion.dart`) versteht das als «schon aufgeteilt» —
sie verteilt die Hauptbuchung bereits auf Debitor 143.75 / Ertrag 133.00 / MwSt 10.75.
Die zweite Buchung nimmt die MwSt danach **ein zweites Mal** heraus.

Nachgeprüft: Alle 890 Hauptbuchungen haben `mwst_konto` gesetzt und tragen zusammen
exakt CHF 10'172.28 MwSt — und es existieren 890 zusätzliche MwSt-Buchungen über
exakt dieselbe Summe. Bilanz, Erfolgsrechnung und die Buchhaltungs-Auswertungen nutzen
alle diese Saldenrechnung, der Fehler schlägt also überall durch.

**Folge:** Ertrag CHF 10'172.28 zu tief, ausgewiesene MwSt-Schuld um denselben Betrag zu
hoch. Eine MwSt-Abrechnung auf dieser Basis wäre zu hoch. Je Jahr: 2025 CHF 1'343.91,
2026 CHF 8'828.37.

**Wo:** `services/buchhaltung/reinigung_buchung_service.dart` Zeilen 125–141 und
`heineken_buchung_service.dart` Zeilen 60–75. Zwei Wege: entweder die Zusatzbuchung
entfällt (dann erledigt `mwst_konto` die Aufteilung), oder die Hauptbuchung lässt
`mwst_konto` leer (dann ist die Zusatzbuchung die richtige). **Nicht geändert** — das
ist deine Entscheidung, und sie hängt daran, ob für Q4/2025 und Q1/2026 bereits
abgerechnet wurde.

### A2 · Der camt-Import würde den 11.03.2026 ein zweites Mal buchen

**Risiko CHF 6'283.85 — vor dem nächsten Import erledigen**

In `services/camt/camt_stichtag.dart` Zeile 6 steht `!bookingDate.isBefore(stichtag)` —
das schliesst den Stichtag **ein**. Der 11.03.2026 ist aber bereits vollständig aus dem
Excel-Journal gebucht. Selbst nachgerechnet:

| Im Bankauszug | In der Buchhaltung bereits gebucht |
|---|---|
| Belastung 6'115.20 Ausgleichskasse GR | SVA 2025 Restbetrag 5'962.20 + Kehricht Domat/Ems 153.00 = **exakt 6'115.20** |
| Gutschrift 74.60 S'chleina Pub | Zahlungseingang Chleina Pub (0196) 74.60 |
| Gutschrift 94.05 HH Gastro AG | zwei Eingänge à 94.05 am selben Tag |

Korrektur wäre `isAfter(stichtag)` oder Stichtag auf den 12.03.2026.

---

## B. Die Geldseite steht seit fünf Monaten still

### B1 · Kein Bankkonto-Eintrag mehr seit dem 11.03.2026

Letzte Buchung auf Konto 1020: **11.03.2026**, danach null. Von 16'980 Buchungen trägt
keine einzige einen `camt_tx_key`.

Belegt für 12.03.–19.06.2026: 263 Transaktionen, Gutschriften CHF 51'775.75,
Belastungen CHF 47'694.04. Für 20.06.–14.07. kommen rund 54 weitere dazu; ab 15.07.
fehlen die Rohdaten ganz (22 Tage ohne Bankdaten).

Grösste unverbuchte Posten: Heineken-Belastungen 7'150.45 / 6'560.70 / 3'976.10,
Heineken-Gutschriften 7'104.98 / 6'288.61 / 5'794.81, Steuerverwaltung GR 5'014.00,
Privatbezüge 5'000 + 4'000 + 4'000 + 3'000 (zusammen CHF 14'000), Geldautomaten-
Einzahlungen 5'300.00 und 2'750.00.

**Was dadurch in der Erfolgsrechnung 2026 fehlt:**

- **Franchisegebühr Heineken (6301): CHF 0.00** — 2024 und 2025 je CHF 45'272.40.
  Der grösste Einzelaufwand fehlt komplett.
- **Lohnaufwand: letzte Buchung 04.03.2026** — CHF 16'527 statt CHF 44'622 im
  Vorjahresvergleich zum selben Stichtag. Rund fünf Monate Löhne fehlen.
- Sozialversicherungen ebenfalls Stopp am 04.03., Haftpflicht CHF 0.00,
  Büromiete CHF 500 statt CHF 3'000.
- Aufwand 2026 gesamt CHF 29'553 gegenüber CHF 155'691–164'264 in den Vorjahren.

**Folge:** Das ausgewiesene Ergebnis 2026 ist erheblich zu hoch, Q2/Q3 sind nicht
abschlussfähig, MwSt-Abrechnungen ab Q1/2026 nicht erstellbar.

**Die gute Nachricht:** Bis zum Stichtag stimmt alles. Konto 1020 laut Buchhaltung
CHF 3'322.26 = camt-Saldo per 11.03.2026 CHF 3'322.26 — Differenz **null**, über
2'668 Transaktionen seit 2019. Die heutige Differenz von CHF 4'081.71 erklärt sich
restlos aus den unverbuchten Bewegungen. Kein unerklärter Rest.

### B2 · Seit dem 11.03.2026 wurde keine Kundenzahlung mehr zugeordnet

Die jüngste Rechnung mit Zahlungsdatum stammt vom 11.03.2026, während im Bankauszug
243 Gutschriften über CHF 51'775.75 liegen. **Ein Mahnlauf auf dieser Grundlage würde
Kunden anschreiben, die längst bezahlt haben.**

Erschwerend: Von 243 Gutschriften trägt **keine einzige** eine QR-Referenz — die erste
Stufe der Zuordnung läuft ins Leere, alles hängt am Zahlernamen. Von 115 Zahlernamen
sind nur 23 (20 %) sicher zuzuordnen; es gibt erst 25 gelernte Aliase bei 432 Betrieben.
Der Nachhol-Abgleich wird also grösstenteils Handarbeit (~190 Posten). Jede
Handzuordnung sollte als Alias gelernt werden, dann trägt die Arbeit beim nächsten Mal.

### B3 · Die Rohdaten des Bankauszugs werden nirgends gespeichert

Es gibt keine Tabelle mit camt-Transaktionen. Persistiert werden nur Datei-Metadaten
(13 Zeilen) und eine Prüfliste mit **4 Zeilen** — bei 324 importierten Transaktionen.
Der Rest lebt nur im Bildschirmzustand: Verlässt man den Import ohne zu verbuchen, ist
alles weg. Im Storage liegen 51 Uploads mit nur 6 verschiedenen Inhalten, 38 davon ohne
Datenbank-Eintrag (abgebrochene Importe, darunter die grossen Vollauszüge).

Solange nichts verbucht ist, ist das ungefährlich. Sobald teilweise verbucht wird und
ein Import abbricht, entstehen stille Doppelbuchungen.

Beide Vollauszüge liegen lokal im Projektordner (`MX53D_*.xml`, 08.06. und 20.06.) —
der Nachhol-Import wäre also sofort möglich.

### B4 · Zwei Heineken-Gutschriften warten seit vier Monaten in der Prüfliste

CHF 12'899.79 (Februar- und März-Abrechnung) stehen seit dem 20.06.2026 auf «offen».
Die dritte Zahlung über CHF 6'288.61 hat es nicht einmal in die Prüfliste geschafft.
Deshalb gelten die Heineken-Rechnungen als unbezahlt, obwohl das Geld da ist.

---

## C. Forderungen

### C1 · 342 Live-Rechnungen wurden nie zugestellt — CHF 34'478

| Rechnungsweg | Anzahl | Summe CHF | Ø Alter |
|---|---|---|---|
| Tresen | 231 | 22'346.25 | 118 Tage |
| **Mail** | **85** | **9'920.75** | **146 Tage** |
| Post | 13 | 1'144.85 | 167 Tage |
| Bar | 13 | 1'065.95 | 126 Tage |

Die 85 Mail-Rechnungen sind der harte Kern: Der Kunde hat nie eine Rechnung bekommen
und kann gar nicht zahlen. Grösste Fälle: Calanda Chur (6 Rechnungen, CHF 1'063.80,
älteste 22.12.2025), Stadtcafé Sursee (4, 622.65), Posthotel Valbella (4, 583.80),
Sonne Seehotel Eich (5, 470.25), Hugos Davos (3, 415.05).

### C2 · Blue Cinema — der bisherige Verdacht ist widerlegt

Bisherige Annahme: Zahlungen laufen über eine Zentrale unter anderem Namen. **Das stimmt
nicht.** Die Zentrale ist längst erfasst (Rechnungsmail `invoice.blue@swisscom.com`,
Zahler-Alias `blue entertainment ag`).

Die tatsächliche Ursache: **Von den 38 offenen Rechnungen wurde keine einzige je
versendet.** Die einzige bezahlte ist genau die, bei der die Kundenbeziehung 2026 wieder
aufgenommen wurde. Seit Mai 2026 wird tatsächlich versendet — diese vier sind noch
offen, aber erst wenige Wochen alt. Offen: CHF 7'722.65, Bezahlquote 2.6 %.

### C3 · Mahnwesen existiert auf dem Papier nicht

In **allen 5'145 Rechnungen** sind sämtliche Mahnfelder leer, `mahnung_stufe` überall 0.
Gleichzeitig sind 1'419 Rechnungen über CHF 165'767 überfällig, davon **463 Rechnungen /
CHF 45'316 seit über drei Jahren**. Es fehlt damit jeder Nachweis für eine Betreibung —
und für eine steuerlich anerkannte Wertberichtigung.

**Verjährung:** 140 Rechnungen über CHF 12'865 sind älter als fünf Jahre. Ohne
Unterbrechung durch Mahnung oder Betreibung sind sie nach Art. 128 OR verjährt.

### C4 · CHF 41'529 bei Tresen- und Barzahlern stehen offen

449 Rechnungen bei Betrieben, die am Tresen oder bar zahlen. Rund ein Viertel der
ausgewiesenen Debitoren dürfte real längst kassiert sein — die Debitorenposition ist
überhöht, die Kasse untererfasst, und die echten Aussenstände sind zwischen den
Scheinposten nicht mehr erkennbar.

### C5 · CHF 14'356 offen bei geschlossenen oder inaktiven Betrieben

117 Rechnungen bei 37 geschlossenen Betrieben plus 15 bei 4 inaktiven. Grösster Posten:
Jamies Chur, 21 Rechnungen, CHF 4'041.35, Betrieb seit 20.03.2024 zu.

### C6 · Heineken Juli 2026 fehlt, April–Juni hängen auf «freigegeben»

Letzter erfasster Monat ist Juni. Für Juli liegen **42 Posten über CHF 4'926.20 netto**
(ca. 5'325 brutto) bereit, aber keine Rechnung. Die Rechnungen April, Mai und Juni
(zusammen **CHF 19'081.82**) wurden nie auf «bezahlt» gezogen — obwohl das Geld laut
Bankauszug teilweise längst eingegangen ist (siehe B4).

### C7 · Drei Zahlungsdaten mit Jahres-Tippfehler

Krone 21.03.**2002** statt 2024 · Rovanada 15.11.**2002** statt 2024 · Hapimag
20.02.**2024** statt 2025. Verzerrt jede Auswertung «Zahlungseingang pro Periode».

---

## D. Buchhaltung — weitere Befunde

### D1 · Gewinnvortrag CHF 35'319.11 fehlt weiterhin

Alle 13 Jahresabschluss-Buchungen 2019–2024 sind als storniert importiert, ohne
Gegenbuchung. **Konto 2970 und 2980 tragen null Saldo.**

Die Bilanzgleichung geht zwar an jedem 31.12. auf (Differenz CHF 0.00) — aber nur, weil
die App das Eigenkapital als Rest aus den Erfolgskonten herleitet statt aus
Abschlussbuchungen. Das ist eine rechnerische Selbstbestätigung, keine Prüfung.

Nachgerechnet stimmt das kumulierte Ergebnis auf **CHF 258.40** genau mit den
Excel-Abschlüssen überein; die Einzeljahre weichen bis CHF 3'190.21 ab und gleichen
sich gegenseitig aus — das deutet auf Periodenverschiebungen beim Import hin, nicht auf
fehlende Beträge.

### D2 · MwSt-Abrechnung wird nie abgeschlossen

Konto 2200 wächst ungebremst: CHF 2'848 (2024) → 20'196 (2025) → **37'853** heute.
Gleichzeitig steht 2202 (MwSt-Abrechnungskonto) mit CHF 8'615.76 im **Soll**, also
vorzeichenwidrig. Zahlungen an die ESTV laufen über 2202, ohne dass 2200 je dagegen
ausgebucht wird. Beide Konten müssen gegeneinander aufgelöst werden — und ein Teil der
37'853 ist die Doppelbuchung aus A1.

### D3 · Kassenbestand war an 157 Tagen negativ

Physisch unmöglich, beweist Buchungen in der falschen Periode: 2021 an 57 Tagen,
2022 an 21, 2023 an 37, 2024 an 42 (tiefster Stand −2'042.11 am 21.05.2024).
Ausschliesslich in der Excel-Ära, seit 2025 nicht mehr.

### D4 · Debitoren wachsen seit 2019 ununterbrochen — CHF 179'212.84

Bei rund CHF 200'000 Jahresumsatz entspricht das etwa elf Monaten Umsatz. Der Saldo
sinkt in keinem einzigen Jahr. Ein Teil davon ist C4 (Tresen-Scheinposten), ein Teil
B2 (keine Zahlungszuordnung seit März).

Auffällig: Gegen den bekannten Sollwert per 11.03.2026 weichen Debitoren um
**CHF −55'426** und Kasse um **CHF −9'082** ab — nur die Bank trifft exakt. Möglich ist,
dass die CHF 176'228.04 die *offenen Forderungen* aus Fach-Sicht meinen und nicht den
Kontosaldo 1100. Das sollte einmal geklärt werden.

### D5 · Kreditoren vorzeichenwidrig

Konto 2000 steht mit CHF 3'675.75 im Soll (bis 2025 korrekt im Haben). Lieferanten-
zahlungen werden gebucht, die Verbindlichkeiten nicht — passt zum Bild aus B1.
Ebenso 2273 (KTG) mit CHF 5'494.11 im Soll.

### D6 · Kleinere Buchhaltungs-Befunde

- **423 nicht unterscheidbare Mehrfachbuchungen** (949 Buchungen, rechnerisch
  CHF 41'053 überzählig) — die 400 Zahlungseingangs-Gruppen sind mit hoher
  Wahrscheinlichkeit echt (mehrere Kunden, gleicher Standardpreis, gleiche
  Beschreibung). **Kritisch sind neun Ertragsgruppen** (CHF 708.55): identische
  Umsatzbuchung, gleicher Tag, gleicher Betrieb.
- **22 Ertragsbuchungen über CHF 0.00** — Reinigungen ohne Preis.
- **Eine Rundungsdifferenz von 2 Rappen** (Heineken 04/2026) — die einzige Verletzung
  von Brutto = Netto + MwSt im ganzen Bestand.
- `beleg_typ='rechnung'` zeigt in 883 von 890 Fällen auf eine **Reinigung**, nicht auf
  eine Rechnung. Jede Auswertung «Buchung zur Rechnung» läuft dadurch ins Leere.
- Der frühere Befund «MwSt-Konten der Alt-Ära unbrauchbar» trifft **nicht mehr zu**:
  Die abgeleitete Umsatzsteuer deckt sich Jahr für Jahr mit Konto 2200 (einzige
  Abweichung 2020: CHF 19.40).

---

## E. Stammdaten und Betrieb

### E1 · 5 Betriebe werden bedient, sind aber nicht als Kunde geführt

| Betrieb | Ort | Status | Reinigungen seit Dez 25 | letzte |
|---|---|---|---|---|
| Valentinos | Chur | **inaktiv** | 4 | 19.03.2026 |
| Panorama | Schlierbach | **geschlossen** | 2 | 24.04.2026 |
| Weiss Kreuz | Preda | aktiv, ohne Heineken-Nr. | 1 | 26.05.2026 |
| Piz Mitgel | Savognin | aktiv | 1 | 15.12.2025 |
| Rätia | Filisur | aktiv | 1 | 15.12.2025 |

Bei Valentinos und Panorama widerspricht der Status der Realität.

### E2 · 66 aktuelle Reinigungen hängen an keiner Anlage

App-erfasst zwischen 05.12.2025 und 27.03.2026. Sie fehlen in jeder anlagenbezogenen
Auswertung. **60 davon wären eindeutig zuordenbar** (der Betrieb hat genau eine aktive
Anlage), 3 mehrdeutig, 3 bei Betrieben ohne Anlage.

### E3 · 6 aktive Anlagen ohne jede Reinigungshistorie

Robinson Club Arosa (4-Wochen-Rhythmus), Bernina Bar Thusis, Eisstadion Davos
(2 Anlagen), Fratelli del Vecchio, Parsennhütte. Ohne Referenzdatum ist keine
Fälligkeit berechenbar. Weitere 12 Anlagen haben ein leeres `letzte_reinigung`, obwohl
echte Reinigungen existieren (Nussbaum 27, Valata 19, Strela 19, Wali 17).

### E4 · 125 von 284 aktiven Anlagen überfällig (44 %) — teils falscher Rhythmus

Spitzenreiter: Sezner (458 Tage), Wali (315), Robinson Club (208), Steakhouse Ochsen
und Strela (je 201), Giodavin (171), Alpina Resort (169).

Ein Teil davon ist **kein echter Rückstand, sondern ein falsch gepflegter Rhythmus**:
Bei 15 Anlagen steht «4-Wochen», real wird alle 3–7 Monate gereinigt (Alpina Resort
218 Tage, Sunset 189, Silvia Kaufmann's Schlagerbar 200, Casa Giovanoli 177).
Solange das nicht stimmt, ist die Überfälligkeits-Liste nur begrenzt brauchbar.

### E5 · Rovanada — vermutlich fehlt eine zweite Anlage

32 Besuche 2019–2024 wurden systematisch doppelt gebucht (gleiche Anlage, gleicher Tag,
unterschiedliche Preise, Suffixe `_01`/`_03`), obwohl nur eine Anlage erfasst ist.
Sehr wahrscheinlich gab es zwei Zapfanlagen, die beim Import auf dieselbe ID fielen.

### E6 · Weitere Stammdaten-Befunde

- **2 aktive Kunden ohne Heineken-Nummer:** FC Perlen (Buchrain), Milez (Rueras) —
  fallen bei jedem Excel-Abgleich durchs Raster.
- **Piaggio Dosch:** aktiver Kunde ganz ohne Ort, PLZ, Telefon und Koordinaten.
- **Tijuana Davos:** Rechnungsweg «Mail», aber keine E-Mail hinterlegt.
- **Alp Lavoz und Alp Nova:** stehen auf «Heineken», haben aber eigene Kundenrechnungen.
- **Rechnungswege ausserhalb der Dokumentation:** `rechnung_post` (3 Betriebe) und
  `jahresrechnung` (1) sind in Gebrauch, aber nirgends beschrieben.
- **27 geschlossene/inaktive Betriebe** sind weiter als «mein Kunde» markiert.
- **194 von 297 aktiven Kunden (65 %) ohne Servicezeit.**
- **146 Reinigungen mit Dauer 0** — Start- und Endzeit identisch, alles aktuelle
  App-Daten. Die Zeiterfassung wird beim Abschluss offenbar nicht wirklich gepflegt.

### E7 · Saison und Ferien

Die heutige Korrektur der 20 Winterfenster wirkt: **0 verdrehte Jahreszahlen** mehr,
keine unplausiblen Fensterlängen. Offen bleibt die Pflege:

- **12 Saisonbetriebe ohne jede Saisonangabe** (Alpina Vals, BARacca Vella, Cuntera
  Medel, Gspan Arosa, Heuberg Fideris, Lenzerhorn, Pellas, Pizzeria Tennishalle,
  Rätia Filisur, Ustria Dalla Posta, Weiss Kreuz Splügen, Weiss Kreuz Preda) — 4 davon
  gelten für die App als «immer geschlossen».
- 39 Winter- und 16 Sommer-Startdaten fehlen, 9 Winter- und 32 Sommer-Enddaten.
- **3 Ferienperioden nie migriert:** Thai-Food Curling Bistro Küssnacht
  (06.07.–11.08.2026), Zum Goldenen Wagen Oberkirch (28.06.–01.09.2026), Rössli Cham
  (Start 29.05.2026, **kein Ende**).
- Alle 39 Ferienperioden tragen `quelle='import'` und kein Bestätigungsdatum — der Weg
  Vorschlag → bestätigte Periode scheint noch nicht verdrahtet.

Sauber: Ruhetage einheitlich, Prüfliste läuft täglich (88 offene Vorschläge, ältester
5 Tage), Fahrzeiten und Kilometerstände ohne Ausreisser.

---

## F. Technik und Sicherheit

### F1 · Zugriffsschutz auf zwei Wartungstabellen gefehlt — behoben

Die beiden Snapshot-Tabellen, die ich gestern und heute als Rückweg für die
Winterfenster- und Golden-Dragon-Korrektur angelegt habe, lagen ohne Zeilenschutz im
öffentlichen Schema und waren über die API lesbar. **Sofort behoben** (Migration
`rls_auf_wartungs_snapshots`); der Rückweg über die Service-Rolle bleibt. Alle anderen
Tabellen hatten den Schutz.

### F2 · Weitere Sicherheitshinweise (nicht dringend)

`google_calendar_events` und `google_calendar_tokens` haben Schutz aktiv, aber keine
Regel — niemand kommt dran, auch die App nicht. 21 Datenbankfunktionen ohne festen
`search_path`. Schutz gegen bekannt geleakte Passwörter abgeschaltet.

### F3 · Deploy hing vier Stunden

Der GitHub-Pages-Build blieb ab 14:21 hängen (GitHub-seitig, Dauer 0). Nach manuellem
Anstossen ist **v0.72.1 live** und bestätigt.

### F4 · Eingangsrechnungen werden nicht genutzt

Alle 23 gescannten Eingangsrechnungen stehen auf «verworfen», die jüngste vom
17.06.2026. Aufwand wird nur über den Spesen-Weg gebucht — zusammen mit B1 erklärt das
den viel zu tiefen Aufwand 2026.

---

## G. Was gesund ist

- **Referenzielle Integrität:** keine verwaisten Reinigungen, Rechnungen, Anlagen oder
  Positionen; keine doppelten Rechnungsnummern, keine doppelte QR-Referenz.
- **Beträge:** Netto + MwSt = Brutto stimmt bei allen 8'500 Reinigungen und allen
  5'145 Rechnungen; MwSt-Satz passt in 100 % der Fälle zum Datum.
- **Bankabstimmung bis 11.03.2026: Differenz null** über 2'668 Transaktionen.
- **Umsatzentwicklung** ohne Bruch, Durchschnittspreis steigt von 77.11 auf 92.50.
- **Zeitraum-Felder** (Geschäftsjahr/Monat/Quartal) stimmen bei allen 16'980 Buchungen.
- **Keine Storno-Ketten**, kein Verweis ins Leere, alle bebuchten Konten existieren.
- **Material und Lager:** keine negativen Bestände.
- **Saisonfenster** nach der heutigen Korrektur durchgehend sauber.

---

## H. Was du entscheiden musst

1. **MwSt-Doppelbuchung** (A1): rückwirkend stornieren ab 01.12.2025 oder per
   Korrekturbuchung zum Stichtag? Hängt daran, ob Q4/2025 und Q1/2026 bereits
   abgerechnet wurden — das steht nirgends in der Datenbank.
2. **Stichtag-Korrektur** (A2) — vor dem nächsten camt-Import. Soll ich das ändern?
3. **Reihenfolge des Nachhol-Abgleichs** (B1/B2): alles am Stück mit Alias-Lernen, oder
   zuerst die grossen Posten und Heineken?
4. **Rohtransaktionen künftig speichern?** (B3) — Migration plus Umbau am Import.
5. **Tresen-/Barrechnungen** (C4): pauschal auf bezahlt setzen oder einzeln abgleichen?
6. **Verjährte Forderungen** (C3): CHF 12'865 abschreiben? Der Status `abgeschrieben`
   existiert und ist bisher ungenutzt.
7. **Forderungen gegen geschlossene Betriebe** (C5): CHF 14'356 wertberichtigen?
8. **Blue Cinema** (C2): 38 Posten gesammelt nachfakturieren oder 2022–2024 abschreiben?
9. **Privatbezüge** CHF 14'000 (April–Juni): Privatkonto, Lohn oder Darlehen?
10. **Debitoren-Sollwert** (D4): Meint CHF 176'228.04 den Kontosaldo 1100 oder die
    offenen Forderungen? Davon hängt ab, ob dort CHF 55'426 fehlen.
11. **Rovanada** (E5): zweite Anlage rückwirkend anlegen?
12. **Falsche Rhythmen** (E4): korrigieren, damit die Überfälligkeits-Liste stimmt?

---

## I. Was ich ohne Rückfrage vorbereiten kann

- Die 60 eindeutig zuordenbaren Reinigungen mit ihrer Anlage verknüpfen (E2).
- Die 3 fehlenden Ferienperioden nachtragen, Rössli-Ende ergänzen (E7).
- Die 3 Jahres-Tippfehler in Zahlungsdaten korrigieren (C7).
- Den Status der 96 versendeten, aber noch auf «offen» stehenden Rechnungen nachziehen.
- Die 5 Betriebe aus E1 auf den richtigen Status bringen.
- Die 12 leeren `letzte_reinigung`-Felder aus der echten Historie füllen (E3).
