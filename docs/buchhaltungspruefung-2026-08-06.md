# Buchhaltungs-Gesamtprüfung SBS Projer — 06.08.2026

**Anlass:** Auftrag Daniel («überprüfe die gesamte Buchhaltung unserer App auf Fehler,
da muss alles stimmen, sei kritisch»). **Massstab:** die Recherchen aus
`D:\Projekte\KMU Tool 2\02_Recherche\` (02 Buchhaltung Schweiz, 07 MWST-Abrechnung
Schweiz — MWSTG-Artikel, Formular-Ziffern, Art.-26-Pflichtangaben, KMU-Kontenrahmen,
Sozialversicherungssätze). **Methode:** vier parallele Prüf-Agenten (MWST-Abrechnung,
Code-Audit aller Buchungspfade, Journal-Audit, Rechnungsstellung), deren schwerste
Behauptungen einzeln am Code und an den Daten nachgeprüft wurden. Nur lesend.
Baut auf der Datenprüfung vom 05.08. auf (`datenpruefung-2026-08-05.md`).

---

## Gesamturteil

Das Fundament ist besser als befürchtet: Die Ertragsseite ist vollständig und sauber
nach vereinbarten Entgelten gebucht, die Journal-Identität hält über alle acht Jahre,
die Steuersätze stimmen historisch exakt, die Rechnungen erfüllen Art. 26, der QR-Code
ist zukunftssicher, und bis Q4/2024 deckt sich die Buchhaltung auf 2–6 CHF mit den
ESTV-Zahlungen.

Darauf liegen aber **drei Schichten von Problemen**: (1) zwei überfällige
MWST-Abrechnungen mit heute falscher Datengrundlage, (2) ein seit 2019
fehlerhafter Lohnblock, (3) eine Reihe latenter Code-Fehler (Storno, Rundung,
Idempotenz, Richtung), die noch keinen Schaden angerichtet haben — aber genau bei
den anstehenden Aufräumarbeiten (Nachhol-Import, Korrektur-Storni) zuschlagen
würden, wenn man sie nicht **vorher** behebt. Die Reihenfolge ist deshalb Teil
des Befunds.

---

## A. Gesetzliche Fristen — das Dringendste

### A1 · MWST Q4/2025 und Q1/2026 sind bei der ESTV überfällig — KRITISCH

Die Zahlungshistorie auf Konto 2202 zeigt eine sechs Jahre durchgehaltene
Quartals-Systematik. Eingereicht und bezahlt ist bis **Q3/2025** (Zahlung 3'333.74
am 10.02.2026, «3 / 2025 Definitiv»). Danach: nichts. Fristen 01.03.2026 (Q4/2025)
und 31.05.2026 (Q1/2026) sind verstrichen; Q2/2026 läuft am 31.08.2026 ab.

Rechnerische Zahllasten (bereinigt): Q4/2025 **2'386.13** · Q1/2026 **4'169.59** ·
Q2/2026 **3'202.59**.

### A2 · Eine heute erstellte Abrechnung wäre massiv falsch — zu Daniels Lasten

Formular 0550 für Q1/2026, konkret ausgefüllt:

| | Rohdaten | bereinigt |
|---|---:|---:|
| Ziff. 302 Steuer | 8'857.00 | 4'428.50 |
| Ziff. 479 Vorsteuer | 258.91 | 1'105.48 |
| **Ziff. 500 Zahllast** | **8'598.09** | **3'323.02** |

**Überdeklaration 5'275.07 (+159 %)** — Ursachen: MwSt-Doppelbuchung (B1),
fehlende Franchise-Vorsteuer (B3), Bankstopp. Zudem ergäben die Rohdaten ein
Steuer-Umsatz-Verhältnis von 17.6 %, das es in der Schweiz nicht gibt —
ESTV-Rückfrage garantiert.

### A3 · Abweichung Buchhaltung ↔ eingereichte Zahlen 2025 — UNKLAR

Q1–Q3/2025 wurde je 244–353 CHF **weniger** bezahlt, als die Buchhaltung
ausweist (immer dieselbe Richtung). Die eingereichten Zahlen stammen also nicht
aus diesem Journal. Dazu ein unerklärter Altbestand von **2'847.94** auf Konto
2200 per 31.12.2024 (nach vollständiger Saldierung müsste dort null stehen).
**Nur Daniel weiss, woraus 2025 deklariert wurde.**

---

## B. Die Kernfehler (alle verifiziert)

### B1 · MwSt-Doppelbuchung — 2026 exakt verdoppelt

Präzisiert gegenüber dem 05.08.: **895** Trennbuchungen 3400/2200 (CHF 10'203.18)
plus **79** Vorsteuer-Trennzeilen (CHF 184.26). Konto 2200 trägt 2026
**17'718.54 = 8'859.27 echt + 8'859.27 doppelt**. Excel-Historik 2019–2024 ist
sauber — der Fehler ist ein reiner App-Fehler ab 01.12.2025.

Vier Verursacher-Pfade: `reinigung_buchung_service.dart:125–141`,
`heineken_buchung_service.dart:61–76`, `spesen_import_service.dart:143–173`,
`kreditor_buchung.dart:56–65`.

**Fix-Skizze (Variante A, klar vorzuziehen):** Trennbuchungs-Blöcke ersatzlos
streichen — die `SaldoExpansion` erledigt die Bruttomethode bereits über
`mwst_konto`; Mehrheit der Pfade, alle Vorlagen, die View und die ganze
Excel-Historik arbeiten schon einzeilig. Danach Datenbereinigung: 895 + 79
Zeilen entfernen (Abgrenzung zu legitimen Abrechnungsbuchungen ist sauber
möglich: die haben `soll_konto = 2202`). **Vorher zwingend B2 fixen.**

### B2 · Heineken-Buchung verletzt die Brutto-Invariante — Absturzrisiko

`heineken_buchung_service.dart:31–33` rundet nur das Brutto auf 5 Rappen; netto
und MwSt bleiben roh → drei Buchungen mit `brutto ≠ netto + mwst` (04–06/2026,
±0.01–0.02). `saldo_expansion.dart:19` hat dafür einen `assert` — **im
Debug-Build stürzt jede Bilanz-/ER-Berechnung ab**, im Release entsteht eine
stille Differenz (die bekannten −0.02 der Bilanzidentität 2026). Fix wie im
Reinigungs-Service: `mwstBetrag = round2(brutto − netto)`.

### B3 · Heineken-Franchise 2026 komplett ungebucht

6301 wurde 05/2019–12/2025 lückenlos monatlich gebucht (3'490.01 netto +
282.69 Vorsteuer auf 1170). Ab 01.01.2026: null. Fehlend Jan–Aug: **27'920.08
Aufwand + 2'261.52 Vorsteuer**. Grösster Einzelposten der Ergebnis-Verzerrung
2026 und der grösste Vorsteuerverlust je Quartal (848.07).

### B4 · Lohnblock — drei Fehler seit Jahren (verifiziert)

1. **Verbindlichkeitskonten um eine Position verschoben:** 2270 «AHV» nie
   bebucht; 2271 «BVG» enthält AHV/SVA, 2272 «UVG» enthält BVG, 2273 «KTG»
   enthält UVG/SUVA. Beträge korrekt, Beschriftung systematisch falsch —
   erklärt den «2273 vorzeichenwidrig»-Befund vom 05.08.
2. **AHV-Abzug 8 % vom Nettolohn** statt 6.4 % vom Brutto (Beleg: Netto 3'000 →
   Abzug exakt 240.00; korrekt 226.65). Lohnausweis und AHV-Abrechnung der
   Mitarbeitenden stimmen nicht; dem AN wird zu viel abgezogen.
3. **NBU/UVG seit Dez 2024 mit 0.00 gebucht** (64 Nullbuchungen); reale
   SUVA-Prämien laufen ohne Aufwandwirkung auf 2273 auf → ~1'800 Aufwand 2025
   fehlt. **FAK** erscheint nirgends als Aufwand (5710 leer), steckt aber in
   den SVA-Akonti — zwei Fehler kompensieren sich zufällig auf dem
   Verbindlichkeitskonto.

### B5 · Ergebnis 2026 ist Fiktion

Ausgewiesen +69'637; real ~70'000–80'000 tiefer. Ab März fehlt die
Aufwandseite fast vollständig (Franchise 0, Löhne nur bis 04.03., Miete 500
statt 3'000, Versicherungen/IT/Bankspesen 0) — Folgewirkung des Bankstopps
vom 11.03.2026, der eben nicht nur die Bank betrifft.

### B6 · Storno-Mechanik: dreifach defekt, noch nie scharf geworden

Produktiv gab es **null echte Storni** — zum Glück, denn:
1. Die Gegenbuchung übernimmt `mwst_konto` unverändert bei getauschten
   Soll/Haben (`buchung_repository.dart:234`) → hebt das Original **nicht**
   auf (Rest: Debitor +MwSt, 2200 −2×MwSt, Ertrag +MwSt). Verifiziert.
2. Sie datiert auf **heute** statt aufs Original (`:229`, `:244`) — ein Storno
   einer 2025er-Buchung verfälscht zwei Perioden.
3. Sie erfasst nur **eine Zeile** — die zugehörige Trennbuchung (solange B1
   existiert) und Partner-Zeilen anderer Services bleiben stehen.

Dazu: `getAllSaldi` (speist Kontensaldi-, Audit- und Debitoren-Provider) und
die MWST-Provider filtern `storno_von_id` **nicht** — nach dem ersten echten
Storno zeigen sie −Original statt 0. Und mehrere Guards prüfen
`belegTyp == X && !istStorniert` ohne `stornoVonId == null` — nach einem Storno
gilt der Beleg weiter als gebucht, die Korrektur-Neubuchung wird still
verworfen. **Die Storno-Mechanik muss repariert sein, bevor die
Datenbereinigung aus B1 als Storni läuft.**

### B7 · Drei MWST-Wahrheiten in einer App

- `view_mwst_abrechnung`: filtert `mwst_konto IS NOT NULL` → **immun gegen die
  Doppelbuchung, heute die richtige Zahl** (verifiziert an der View-Definition).
  Aber: beschriftet 1170/1171 vertauscht (1170 trägt Franchise = Betriebsaufwand
  → Ziff. 405, nicht «Investitionen»), liefert keinen Umsatz (Ziff. 200/299) und
  sieht MWST-Rückholungen aus Abschreibungen nicht (die buchen 2200/1100 ohne
  `mwst_konto`).
- `mwstQuartalDetailProvider`: rechnet über SaldoExpansion → **doppelt**, und
  verrechnet zusätzlich die Abrechnungsbuchungen — kann mit der View nie
  übereinstimmen, auch nach dem B1-Fix nicht ohne eigenen Ausschluss.
- `services/auswertung/*`: liest gar nicht aus `buchungen`, sondern aus den
  operativen Tabellen mit Pauschalfaktor — dritte, unabhängige Zahl.

Ziel: **eine** Quelle (die View, ergänzt um Umsatz und Rückholungen,
Ziffern-Zuordnung über `soll_konto` statt `mwst_konto`).

### B8 · Latente Landminen für die anstehenden Aufräumarbeiten

- **camt-Ausgabenbucher ignoriert die Richtung** (`camt_ausgabe_booker.dart`):
  Soll/Haben kommen unverändert aus der Vorlage, `isCredit` fliesst nur in den
  Text — eine Gutschrift würde wie eine Belastung kontiert. Verifiziert.
  **Muss vor dem Nachhol-Import der 324 Bankbewegungen gefixt sein**, ebenso
  wie der bekannte Stichtag-Off-by-One (11.03. inkludiert).
- **DB-Trigger `rechnungen_auto_buchung_erstellt` ist aktiv, aber unerreichbar**
  (feuert auf `entwurf→offen`; `entwurf` ist seit Migration 083 verboten).
  Sollte `entwurf` je zurückkehren, bucht er dieselbe Debitorenbuchung wie der
  Heineken-Service. Trigger + verwaiste Funktion `auto_buchung_zahlung_eingegangen()`
  löschen.
- **Idempotenz-Lücken:** Lohnlauf (13 Zeilen je Lauf, kein Guard, kein
  beleg_typ), Abschreibungen, freie Buchung, Spesen (nur überstimmbare
  Dubletten-Warnung), camt-Verbuchen (Doppeltipp bucht doppelt — `existiertCamtTxKey`
  wird im Import-Tab nie aufgerufen).
- **Hard-Deletes statt Storni** in vier Pfaden (Reinigungskorrektur,
  Heineken-Detail, Lohn, Eingangsrechnung) — verletzt die Unveränderbarkeit
  (GeBüV/OR 958f).
- **Rundungs-Wildwuchs:** vier Verfahren in ≥15 Implementierungen; konkret
  erzeugt der ungerundete Heineken-Zahlungseingang gegen die gerundete
  Debitorenbuchung systematische Rappen-Restsalden auf 1100.
- **Hartcodierte Zuschlagspreise** in `reinigung_buchung_service.dart:36–44`
  (18/18/23/30) statt Preisliste — bei der nächsten Preisänderung weicht der
  gebuchte vom fakturierten Ertrag ab.

### B9 · Kleinere MWST-/Journal-Funde

- **Vorsteuerabzug auf Bussen** (16 Buchungen, 112.97) — unzulässig,
  ESTV-Prüfmuster. Eine davon: «Busse Rückzahlung ???» auf Konto 2202.
- **Verpflegungs-Spesen** (5820, 2026 bereits 2'073.55): Tagesverpflegung des
  Inhabers ist grundsätzlich privat; Vorsteuer auf Alkohol (Radler) heikel;
  bei Restaurantverzehr gälten 8.1 %, nicht 2.6 %. Klärung nötig.
- **Debitorenverlust bei Unterzahlung** bucht brutto auf 3805 ohne
  MwSt-Rückholung — der parallele Abschreibungs-Service macht es richtig;
  zwei Verfahren für denselben Geschäftsfall.
- **Konto 2260 «Privatkonto»:** 19'102.95 Schuld der GmbH an Daniel,
  360 Buchungen, **keine einzige Rückzahlung** in 7 Jahren.
  GmbH-korrekt wäre «Kontokorrent Gesellschafter» (Konto 1190/2260) mit
  echtem Verkehr.
- **Keine transitorischen Abgrenzungen** (Konten 1300/2300 fehlen ganz) —
  Dezember-Vorauszahlungen (Haftpflicht 2026, SUVA 2026) verzerren jedes
  Jahresergebnis um ~2'500–3'000; Steuern der Vorjahre belasten das laufende
  Jahr (2208 Steuerrückstellung nie bebucht).
- **Kein Anlagevermögen, keine Abschreibungen** (1500/1510 leer, 6800 fehlt) —
  klären, ob Fahrzeuge geleast/privat sind.
- **Erfassungsverzug:** 74 % des App-Ära-Volumens > 46 Tage nach Belegdatum
  erfasst; 314 Buchungen ohne jede Beleg-Verknüpfung (davon 217 camt-belegbare
  Zahlungseingänge; echt problematisch: Lohnzahlungen 36'000 ohne Anhang,
  Buchungen mit Zeitstempel statt Beschreibung).
- **Sechs anachronistische Buchungen** (8.1 % im Jahr 2019, CHF 1.40) — in
  abgerechneten Perioden, nicht anfassen.

---

## C. Rechnungsstellung (separater Bericht, weitgehend Entwarnung)

- **Alle 8 Pflichtangaben nach Art. 26 erfüllt** (Kundenrechnung), MWST-Nummer
  mit korrektem «MWST»-Zusatz aus den Geschäftseinstellungen.
- **QR-Code: Typ S seit jeher** — die Frist 30.09.2026 betrifft die App nicht.
  SCOR zu normaler IBAN korrekt, Beträge/Rundung sauber, die ±2-Rappen-
  Positionsdifferenz ist auf dem PDF unsichtbar.
- **Zwei Fixes:** (1) Empfangsschein ohne Referenz-Feld (auch Mahnungs-PDF) —
  Schalterzahler zahlen ohne Referenz → unscharfer camt-Abgleich;
  (2) Heineken-PDF: MWST-Nummer hartcodiert und ohne «MWST»-Zusatz
  (`heineken_pdf_service.dart:19`) — Rückweisungsrisiko im Kreditorenlauf.
- Klein: dupliziertes QR-Payload im Mahnungs-PDF, 120 Alt-Rechnungen ohne
  QR-Referenz (Jan/Feb 2026), Leistungsdatum nur implizit (derzeit bei allen
  552 Rechnungen deckungsgleich — rechtlich sauber).

---

## D. Was gesund ist (belastbar geprüft)

- Ertragsseite vollständig, durchgängig vereinbarte Entgelte, kein Beleg
  erzeugt zweimal Ertrag, kein Loch am Excel/App-Übergang.
- Journal-Identität (Soll = Haben, SaldoExpansion-Semantik) hält 2019–2025
  exakt; 2026er-Abweichung −0.02 restlos durch B2 erklärt.
- Steuersätze über acht Jahre korrekt (nur 0/2.6/7.7/8.1, Wechsel per
  01.01.2024 sauber vollzogen).
- Bis Q4/2024: Buchhaltung ↔ ESTV-Zahlung Differenz 2.32–6.46 je Quartal.
- Spesen-Privatanteil (Tabak → 2260 ohne Vorsteuer) korrekt implementiert.
- Nettolohn-Konto 2002 über alle Jahre exakt auf null; BVG paritätisch 50/50.
- Heineken-Zahlungseingang doppelt-buchungssicher (camt und manueller Klick
  laufen durch denselben Guard).

## E. Saldosteuersatz — Rechenergebnis (kein Entscheid)

Effektiv (bereinigt) vs. SSS Gebäudereinigung 4.6 %: 2025 wäre der SSS um
**1'580** günstiger gewesen, 2026 hochgerechnet um **~970**. Knapp — der
Franchise-Vertrag liefert allein 3'392/Jahr Vorsteuer, die beim SSS verfiele;
eine grössere Investition kippte die Rechnung sofort. Antrag + 3-Jahre-Bindung
+ offene Satz-Einstufung durch die ESTV. **Erst nach der Datenbereinigung
entscheiden** — die heutigen Rohdaten würden den SSS um ~4'700 zu gut aussehen
lassen.

---

## F. Fahrplan (Reihenfolge ist Teil des Befunds)

1. **B2** Heineken-Rundung fixen (3 Zeilen Code + 3 Datenzeilen) — sonst
   crasht Schritt 2 im Debug-Build.
2. **B1** Doppelbuchung: 4 Code-Blöcke streichen (Variante A), dann die
   895 + 79 Trennbuchungen bereinigen. **Vorher B6.1–B6.3 reparieren**, wenn
   die Bereinigung als Storni laufen soll (empfohlen wegen GeBüV) — sonst per
   dokumentierter Migration mit Snapshot.
3. **camt-Vorbereitung:** Stichtag-Off-by-One + B8-Richtungsfehler fixen,
   frische camt-Datei ab 15.07. besorgen, dann Nachhol-Import 12.03.–heute
   (mit Alias-Lernen).
4. **Nachbuchungen:** Franchise Jan–Aug (27'920 + 2'261 VSt — vorher klären,
   ob der Vertrag unverändert läuft), Löhne ab April, Miete/Versicherungen.
5. **MWST Q4/2025 + Q1/2026** aus bereinigten Zahlen erstellen und einreichen;
   Q2/2026 bis 31.08. hinterher. Saldierungen 2200/1170/1171→2202 für sieben
   Quartale nachholen; Altbestand 2'847.94 klären.
6. **Lohnblock** gemäss Daniels Entscheiden (Kontenbezeichnung vs. Umbuchung;
   AHV-Satz korrigieren; NBU klären; FAK ausscheiden).
7. **Härtung:** Idempotenz-Guards, `stornoVonId`-Filter in getAllSaldi/Providern,
   Hard-Deletes → Storni, Rundung vereinheitlichen, Trigger-Leiche löschen,
   MWST-Quelle konsolidieren, PDF-Fixes (Empfangsschein-Referenz, Heineken-
   MWST-Zusatz), Preisliste statt Hartcodierung.

## G. Entscheidungsfragen an Daniel (konsolidiert)

1. ESTV-Registrierung: effektiv (alles deutet darauf) und quartalsweise? Je
   vereinbarte Entgelte?
2. Sind Q4/2025 und Q1/2026 wirklich **nicht eingereicht** (nicht nur
   unbezahlt)?
3. Woraus wurden die 2025er-Deklarationen erstellt (je 244–353 unter der
   Buchhaltung)? Was ist der 2'847.94-Altbestand auf 2200?
4. MwSt-Doppelbuchung: rückwirkend als Storni bereinigen oder Migration?
   (Hängt an Frage 2.)
5. Läuft der Heineken-Franchise-Vertrag 2026 unverändert (3'772.70/Monat)?
6. Lohnblock: Konten umbenennen oder ~1'100 Buchungen umbuchen? AHV-Abzug ab
   wann korrigieren (Lohnausweise!)? NBU 0.00 seit Dez 2024 — gewollt?
   FAK als eigener Aufwand?
7. Verpflegungs-Spesen 5820: Geschäftsessen oder Eigenverpflegung? (Vorsteuer-
   und Lohnausweis-Folge.)
8. 2260: umbenennen in Kontokorrent Gesellschafter, periodische Rückzahlung?
9. Anlagevermögen: Fahrzeuge geleast/privat/als Aufwand gebucht?
10. Transitorische Abgrenzungen ab Abschluss 2026 einführen?
11. Erfassungsrhythmus: feste Wochenroutine oder bewusst quartalsweise?
12. SSS-Frage nach der Bereinigung nochmals rechnen und entscheiden?

## Nachtrag 06.08.2026 (abends): Die echten ESTV-Abrechnungen — drei Fragen beantwortet, ein neuer Fund

Daniel hat den Ordner `00_Rechnungen/02_MWST Abrechnung/` gezeigt: die offiziellen
ESTV-Abrechnungs-PDFs **Q2/2019 bis Q1/2025** (Altportal bis Q1/2022 als
UUID-Dateien, neues Portal ab Q2/2022 als `ABR_*`).

**Damit beantwortet (Fragen G1–G3):**
- **Methode: Effektiv. Periode: quartalsweise.** Offiziell auf jedem Dokument.
  MWST-pflichtig seit 01.05.2019. ESTV-ID 052.0248.5626.
- **Q4/2025 und Q1/2026 sind nicht eingereicht** (keine PDFs, keine Zahlungen) —
  der Überfälligkeits-Befund A1 ist damit hart bestätigt. Q2+Q3/2025 wurden
  bezahlt und sind sehr wahrscheinlich eingereicht (PDFs fehlen nur im Ordner).
- **Einreichungspraxis:** chronisch spät (Q2/2019 am 23.12.2019, Q1/2022 am
  07.10.2022, Q1/2025 am 06.10.2025 — je mit Verzugszins-Valuta). Das erklärt
  die «Einschätzung → definitiv»-Muster in den 2202-Buchungen.

**Der neue Fund — NETTO statt BRUTTO ins neue Portal (WICHTIG):**

Q1/2025 deklariert: Ziff. 200 = 51'017.09. Das ist **exakt der Netto-Ertrag**
des Journals (51'017.09; brutto wäre 55'149.73). Das neue Portal behandelt
Ziff. 200 aber als **Brutto** und rechnet die Steuer mit 8.1/108.1 heraus:
deklarierte Steuer 3'822.74 statt korrekt 4'132.64 (= exakt die gebuchte USt).

→ **Unterdeklaration 309.90 in Q1/2025** — und dasselbe Muster erklärt die
bislang unerklärte Zahlungs-Differenz aller drei 2025er-Quartale
(Q1 244.49 / Q2 260.43 / Q3 352.61 — zusammen **~858 CHF zu wenig
deklarierte Steuer 2025**). Ursache: Das Altportal verlangte zeitweise
Netto-Angaben (Q1/2022: «Alle Umsatzangaben sind netto», dort stimmte die
Deklaration), das neue Portal verlangt Brutto — die Eingabepraxis blieb Netto.

**Konsequenz:** Die ~858 CHF sind echte Steuerschuld gegenüber der ESTV und
gehören per Korrektur-/Jahresabstimmung (Art. 72 MWSTG) bereinigt —
praktischerweise zusammen mit der Nachreichung von Q4/2025. Der
2'847.94-Altbestand auf Konto 2200 (G3) passt zu diesem Muster
(Alt-Differenzen aus Einschätzungen/Netto-Brutto), ist aber noch nicht
einzeln belegt.

**Nebenbeobachtung:** Daniel deklariert Ziff. 400 = Konto 1170 (848.07,
Franchise) und Ziff. 405 = Konto 1171 — dieselbe Zuordnung wie die App-View.
Fachlich gehörte die Franchisegebühr in Ziff. 405; steuerlich neutral
(Total zählt), aber die künftige App-Abrechnung sollte es richtig machen.

## H. Verifikationsvermerk

Von mir persönlich am Code/an den Daten nachgeprüft (nicht nur Agent-Aussage):
Kontenverschiebung 2270–2273 (SQL, Bezeichnungen + letzte Buchungen) ·
AHV 8 %-vom-Netto (Lohnsatz 03.06.2025 vollständig) · `view_mwst_abrechnung`
(View-Definition: Filter, vertauschte Beschriftung, fehlender Umsatz) ·
Storno-`mwst_konto`/-Datum (`buchung_repository.dart:217–247`) ·
camt-Richtungsfehler (`camt_ausgabe_booker.dart:26–45`) · MWST-Nummer in
`geschaeft_einstellungen` · Empfangsschein-Referenz + Heineken-MWST-Zeile
(PDF-Services). Die Formular-0550-Rechnung und die Quartalstabellen stammen aus
dem MWST-Agenten; Stichproben (2200-Jahreswert 2026, Trennbuchungszahl 895)
decken sich mit eigenen Abfragen vom 05./06.08.
