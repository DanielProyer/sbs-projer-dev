# Analyse 3 — Buchhaltungs- und Rechnungsabläufe (Stand v0.138.0, 25.09.2026)

Nur gelesen: Code, dazu zwei lesende DB-Abfragen. Pfade relativ zu `sbs_projer_app/lib/`.

## 0. Kurzfazit — die fünf wichtigsten Befunde

| # | Befund | Schwere |
|---|---|---|
| A | **Gemahnte Rechnungen lassen sich nicht über die Bank bezahlen.** Der Bankabgleich und der Prüflisten-Dialog «Zuordnen» nehmen nur Rechnungen mit dem Status `offen`/`gesendet` (`camt_import_tab.dart:475-480`, `kundenzahlung_zuordnen_dialog.dart:33-41`). Nach dem ersten Mahnlauf (Status `erinnert`/`mahnung_1`/`mahnung_2`) landet die Zahlung als «unbekannte Gutschrift». Einen anderen Weg in der App gibt es nicht, ausser bar. Dasselbe gilt für **alle** `jahresrechnung`en (Filter `rechnungstyp == 'kundenrechnung'`). Heute gibt es in der DB noch keine gemahnte Rechnung und keine Jahresrechnung, der Fehler hat also noch nicht zugeschlagen. | kritisch, sobald gemahnt wird |
| B | **Eine abgeschlossene Reinigung zu bearbeiten löscht die Rechnung und legt sie neu an** (`reinigung_form_screen.dart:806-829` → `reinigung_korrektur_service.dart:15-35`). Das passiert bei *jeder* Änderung im Web, auch bei einer blossen Notiz. Es gibt keine Prüfung auf bezahlt, gemahnt, versendet, Mahnfall, abgeschlossenes Jahr oder eingereichtes MWST-Quartal. Die Folgen: Die Rechnung bekommt eine neue Nummer (aus der Sequenz), Zahlungsbuchungen bleiben mit `beleg_id` auf eine gelöschte Rechnung zurück (keine FK), und die neue Rechnung steht auf `offen` und landet damit im Mahnlauf. Wird die Reinigung nachträglich auf Kulanz gestellt, wird **nicht** aufgeräumt. | kritisch |
| C | **Die Heineken-Freigabe kann übersprungen werden, dann fehlt der Ertrag.** Der Heineken-Matcher nimmt jede Rechnung mit Status `!= 'bezahlt'` (`heineken_matcher.dart`, `camt_import_tab.dart:491-496`). Eine `gesendet`e Monatsrechnung wird per Bank auf `bezahlt` gesetzt, die Buchung 1100/3400 aus der Freigabe entsteht nie, und 1100 läuft ins Minus. `HeinekenFreigegebenRegel` (`monats_regeln.dart:213`) prüft nur den Status und zeigt deshalb grün. Im Detailscreen wird zudem zuerst der Status gesetzt und erst danach gebucht (`heineken_rechnung_detail_screen.dart:334-395`); scheitert die Buchung, steht «freigegeben» ohne Ertrag da. | hoch |
| D | **1100 stimmt nicht mit den offenen Rechnungen überein, und keine Regel meldet es.** DB heute: Saldo 1100 = 117'416.58, offene Rechnungen (Kunden 117'227.35 + Heineken freigegeben 13'966.09) = 131'193.44, also **Differenz −13'776.86**. `debitorenUebersichtProvider` weist die Differenz als «historischer Aggregat» aus (`buchhaltung_providers.dart:255-284`). Der Debitoren-Header bietet dafür sogar eine «Historische Sammel-Abschreibung» an (`debitoren_header.dart:37-41, 91-175`): ohne Beleg, Datum vorbelegt auf **31.12.2024** (abgeschlossenes Jahr), MWST nach Satz des Datums, `FilledButton`. | hoch |
| E | **Es gibt fünf Wege, eine Zahlung zu buchen, mit unterschiedlichen Schutzmassnahmen.** Nur der Barweg prüft gegen den DB-Stand (`updateWennStatus` + `nurOhneZahlung`), merkt sich die Mahnstufe und sperrt das Vorjahr. Der Bankweg setzt den Status ohne Prüfung, verliert beim Rückgängigmachen die Mahnstufe und darf auch im abgeschlossenen Jahr löschen. | mittel bis hoch |

---

## 1. Alle Wege, wie eine Kundenrechnung «bezahlt» wird

| Weg | Datei:Zeile | Buchungen | Gesetzte Rechnungsfelder | Doppelbuchungs-Schutz | Rückweg |
|---|---|---|---|---|---|
| **Bank auto / Vorschau** (Auto-Treffer, «Alle verbuchen») | `abgleich_vorschau.dart:493, 545` → `forderungs_abgleich_service.dart:252-323` → `zahlungsdifferenz_service.dart:62-171` | 1020/1100 je Rechnung (zu zahlen bzw. Brutto, Verlust von hinten gekürzt), 2030/1100 Verrechnung, **eine** Differenzzeile 3805/1100 bzw. 1020/8000 auf der *letzten* Rechnung, jeweils mit `camt_tx_key` | `bezahlt`, `zahlung_eingegangen_am` = Datum der gepaarten Gutschrift, `zahlung_betrag` = `plan.gezahltFuer` (zu zahlen **oder** Brutto, **nicht** der tatsächlich gezahlte Betrag), ggf. `guthaben_verrechnet` = 0 | frisch geladen, aber **nur** `bezahlt` wird geprüft (nicht `abgeschrieben`); je Rechnung `_hatZahlung` (überspringt still); Status-Update **ohne** `updateWennStatus` | `zahlungRueckgaengig` (`:332-360`) |
| **Bank manuell** (Manuell-Fall, ⚪-Pool, Mehrfach-Gutschrift) | `abgleich_vorschau.dart:869, 1150, 1716` | wie oben; bei mehreren Gutschriften Paarung `paareMitBetrag` | wie oben | wie oben | wie oben |
| **Prüfliste → «Kundenzahlung zuordnen»** | `kundenzahlung_zuordnen_dialog.dart:209` | wie oben | wie oben | wie oben; Pool nur `offen`/`gesendet` | wie oben |
| **Bank auto (alt)** | `camt_auto_booker.dart:32-168` (`run`) | wie oben | wie oben | — | **toter Code**: kein Aufrufer |
| **Einzelzahlung** | `zahlungsdifferenz_service.dart:177-271` (`verbuchen`) | 1020/1100 + Differenz | — | `_hatZahlung` | **toter Code**: weder in `lib` noch in `test` aufgerufen |
| **Barzahlung vor Ort** | `mahn_hinweis_band.dart:199` → `barzahlung_service.dart:192-293` | 1000/1100 (zu zahlen, 5 Rp), 2030/1100 | `bezahlt`, `zahlung_eingegangen_am` = heute, `zahlung_betrag` = zu zahlen; Vorher-Stand (7 Mahnfelder) als JSON in `buchungen.notizen` | **vollständig**: `kassierSperre` (Status, Zahlung im Journal, Zahlungsfelder), `updateWennStatus(erwarteterStatus, nurOhneZahlung)`, Rollback durch Löschen | `rueckgaengig` (`:302-353`): Mahnstand zurück, Vorjahres-Sperre, Sperre bei weiterer Zahlung; `kassenbuchungEntfernen` (`:373`) für den halben Zustand |
| **Guthaben deckt alles** (beim Anlegen) | `rechnung_service.dart:83-101`, `jahresrechnung_service.dart:196` | 2030/1100 | `bezahlt`, `zahlung_betrag` = **0**, Eingang = Rechnungsdatum | keiner (frisch angelegt); `update` ohne Prüfung | keiner |
| **Heineken bezahlt (Bank)** | `camt_auto_booker.dart:260-287` | 1020/1100 Brutto | `bezahlt`, Datum Bank, `zahlung_betrag` = Brutto | `hatZahlung`, danach `update` ohne Prüfung; **keine Prüfung auf Freigabe** (Befund C) | keiner (`zahlungRueckgaengig` im Detail ist für `heineken_monat` ausgeblendet) |
| **Heineken bezahlt (von Hand)** | `heineken_rechnung_detail_screen.dart:334-395` | 1020/1100 Brutto | `bezahlt`, Eingang = **heute** (nicht Bankdatum), **kein** `zahlung_betrag` | **Status vor der Buchung** | Löschen der ganzen Rechnung (`:430-443`, Buchungen hart gelöscht) |
| **Einzelabschreibung** (Liste, nur ab `mahnung_2`) | `rechnungen_list_screen.dart:895-935` → `mahnwesen_service.dart:28-60` | ggf. 2030/1100, 3805/1100 netto + 2200/1100 MWST, Datum **heute** | `abgeschrieben` (`update` ohne Prüfung) | `abschreibungSchonGebucht`; **keine** Prüfung auf Zahlung im Journal (`zahlungGebucht`) | **keiner** |
| **Mahnfall: Konkurs / abgeschrieben** | `mahnfall_service.dart:393-399, 476-478, 562-579` | wie Einzelabschreibung | `abgeschrieben` | prüft `zahlungGebucht` vorab für alle Rechnungen | keiner |
| **Mahnfall: Heineken übernimmt** | `mahnfall_service.dart:385-392` | **keine** (nur Glocke «Übernahme verbuchen») | Rechnung bleibt z. B. auf `mahnung_2` | — | — |
| **Jahrgang abschreiben** | SQL `abschreibung_jahrgang_buchen` (Migration 194), Vorschau `jahrgang_abschreibung.dart` | 3805/1100 netto + 2200/1100, Datum **31.12. des Geschäftsjahres**, volles Brutto | `abgeschrieben`, Vorher-Status in `abschreibung_positionen` | Transaktion; prüft nur die Rechnungsfelder (`zahlung_*`), **nicht** das Journal; Guthaben-Rechnungen ausgeschlossen | `abschreibung_lauf_zuruecknehmen` (sauber) |
| **Debitoren-Header «Sammel-Abschreibung»** | `debitoren_header.dart:91-175` | 3805/1100 + 2200/1100 ohne `beleg_id` | — | keiner | keiner |
| **Status von Hand** | `rechnungen_list_screen.dart:939-985` | — | beliebig | — | **toter Code** (alle Zweige kehren vorher zurück) |

### Abweichungen zwischen den Wegen

| Thema | Unterschied |
|---|---|
| `zahlung_betrag` | Bank: `gezahltFuer` = zu zahlen *oder* Brutto (bei Mehr- oder Minderzahlung **nicht** der tatsächliche Betrag). Bar: zu zahlen. Guthaben voll: 0. Heineken Bank: Brutto. Heineken von Hand: gar nicht gesetzt. Das Feld bedeutet also je nach Weg etwas anderes. Der Kontoauszug (`kontoauszug_pdf_service.dart:137`) und der Mahnlauf-Provider (`:327`) lesen es trotzdem als «bezahlt». |
| Status-Update | nur Bar und Mahnlauf nutzen `updateWennStatus`; Bank, Heineken, Abschreibung und Guthaben nutzen ein ungeschütztes `update`. |
| Doppelbuchungs-Schutz | Bank prüft nur `bezahlt` (fehlt: `abgeschrieben`, Zahlung im Journal ohne Status). Bar prüft alle drei. SQL-Jahrgang prüft das Journal nicht. |
| Rückweg | Bar stellt die Mahnstufe wieder her. Die Bank setzt pauschal `gesendet`/`offen` (`:354`), `mahnung_stufe`/`erinnerung_am`/`mahn_frist_bis` bleiben stehen → **widersprüchlicher Datensatz** (Status `gesendet`, Stufe 2). |
| Löschen oder Storno | Alle Rückwege löschen **hart** (`BuchungRepository.delete`). Das Journal kennt `stornieren` (`buchung_detail_screen.dart:235`), aber nur von Hand. Bar sperrt das Vorjahr, `zahlungRueckgaengig` **nicht**, kann also Bank 1020 eines abgeschlossenen Jahres verändern. |
| Sammelzahlung zurücknehmen | Wird eine einzelne Rechnung aus einer Sammelzahlung zurückgenommen, bleiben die Buchungen der anderen Rechnungen und die Differenzzeile (hängt an der *letzten* Rechnung) stehen. Die Gutschrift gilt über ihren `camt_tx_key` weiter als verarbeitet (`getAlleCamtTxKeys`) und wird deshalb **nicht** wieder angeboten, obwohl der Dialog das verspricht (`rechnung_detail_screen.dart:268-271`). |
| Minderzahlung / MWST | Eine erlassene Differenz geht als **Brutto** auf 3805 ohne MWST-Korrektur (`zahlungsdifferenz_service.dart:130-146`). Eine Abschreibung holt die MWST dagegen über 2200 zurück. Beides ist eine Entgeltsminderung, wird aber verschieden behandelt. |
| Überzahlung | automatisch immer 1020/**8000**. Eine Überzahlung als Kundenguthaben (1020/**2030**) entsteht nur über eine Buchung von Hand, obwohl v0.137.0 genau das voraussetzt. |
| Datum | Einzelabschreibung: heute. Jahrgang: 31.12. Sammel-Header: frei wählbar, vorbelegt 2024. Heineken von Hand: heute statt Bankdatum. |

### Vorschlag: eine gemeinsame Zahlungs-Kernfunktion

```
ZahlungKern.erfassen(
  rechnungen, betrag, datum,
  weg: bank|kasse|verrechnung, txKeys: {...},
  differenz: verlust(3805+MWST) | mehrertrag(8000) | guthaben(2030))
ZahlungKern.zuruecknehmen(rechnungId)   // ganze Zahlungsgruppe
```
- **Eine** Sperrfunktion (heute `kassierSperre`), verallgemeinert: Status erledigt, Zahlung im Journal, `zahlung_*` gesetzt, Abschluss- oder Jahresgrenze.
- `differenzPlan` bleibt die reine Planfunktion. `zahlung_betrag` = **tatsächlich zugeordneter Betrag** (Bank- plus Differenzanteil), einheitlich für alle Wege.
- Schreibt `zahlung_gruppe_id` (neu) und den Vorher-Stand (`MahnlaufService.vorherStand`) in die Buchung. Der Rückweg nimmt die **ganze Gruppe** zurück und stellt die Mahnfelder wieder her.
- Status nur über `updateWennStatus(..., nurOhneZahlung)`.
- Umsetzung am besten als **DB-Funktion (RPC) in einer Transaktion** wie `abschreibung_jahrgang_buchen`: Das beseitigt die halben Zustände, die heute Löschen als Rollback und die Regel «DebitorenStatus» nötig machen.
- Aufrufer: alle 5 `verbuche`-Stellen, Prüfliste, Bar, Heineken (Bank und von Hand), Guthaben voll. Tot und zu löschen: `CamtAutoBooker.run`, `ZahlungsdifferenzService.verbuchen`, Fallback in `rechnungen_list_screen.dart:939-985`.

---

## 2. Statusmodell der Rechnung

### Wo der Status geschrieben wird

| Stelle | schreibt | Prüfung auf Vorstand? |
|---|---|---|
| `rechnung_service.dart:166`, `jahresrechnung_service.dart:192`, `heineken_rechnung_service.dart:163` | `offen` (Anlage) | – |
| `rechnung_service.dart:91` | `bezahlt` (Guthaben voll) | nein |
| `reinigung_rechnung_versand.dart:189, 235` und die **Kopie** in `reinigung_form_screen.dart:1038, 1125` | `gesendet` + `versendet_am` | **nein**: Auch ein Neuversand aus dem Reinigungsdetail (`reinigung_detail_screen.dart:468`, `warVorhanden`) setzt `bezahlt`/`erinnert`/`mahnung_x` auf `gesendet` zurück. Nur der Server hebt ausschliesslich `offen` auf `gesendet`, die Rückfall-Zeile im Client überschreibt das. |
| `heineken_rechnung_detail_screen.dart:186` | `gesendet` | nein |
| `heineken_rechnung_detail_screen.dart:335` | `freigegeben` / `bezahlt` | nein, Status vor Buchung |
| `camt_auto_booker.dart:90, 116, 277`, `forderungs_abgleich_service.dart:318` | `bezahlt` | nein |
| `forderungs_abgleich_service.dart:354` | `gesendet`/`offen` (Rücknahme) | nein, Mahnfelder bleiben stehen |
| `barzahlung_service.dart:260, 336, 318` | `bezahlt` / Vorher-Stand | ja |
| `mahnlauf_service.dart:606` (+ Rücknahme 402/447/540) | `erinnert`/`mahnung_1`/`mahnung_2` | ja |
| `mahnwesen_service.dart:51` | `abgeschrieben` | nein |
| SQL 194 | `abgeschrieben` / Vorher-Status | ja |
| `rechnungen_list_screen.dart:963` | beliebig | toter Code |

### Redundanz und Widersprüche

| Feld | Befund |
|---|---|
| `zahlungsstatus` mischt **drei Dimensionen**: Zahlung (offen/bezahlt/abgeschrieben), Zustellung (gesendet) und Mahnstufe (erinnert/mahnung_1/2), dazu bei Heineken die Freigabe. | Deshalb vergisst jeder Filter einen Wert (Befund A: `offen`/`gesendet` im Abgleich; `rechnungen_list_screen.dart:80-95`: `gesendet` hat keinen Folgestatus; `rechnungNichtVersendet` prüft nur `offen`). |
| `gesendet` ≙ `versendet_am != null` | redundant; `uebergeben_am` (Tresen) setzt **keinen** Status. |
| `erinnert`/`mahnung_1`/`mahnung_2` ≙ `mahnung_stufe` 1/2/3 | doppelt geführt; nach `zahlungRueckgaengig` weichen die beiden ab. |
| `letzte_mahnung_am` ≙ max(`erinnerung_am`, `mahnung_1_am`, `mahnung_2_am`) | abgeleitet. |
| `mahn_frist_bis` | nur der Mahnlauf setzt es. Beim Neuversand (`rechnung_detail_screen.dart:766`) ändert sich `faelligkeitsdatum`, die Mahnfrist aber nicht; `versendet_am` wird überschrieben (Erstversanddatum geht verloren). |
| `guthaben_verrechnet` | nötig. Wird beim Bankweg auf 0 gesetzt und der alte Wert in der Buchungsnotiz gesichert (verteilter Zustand). |
| `zahlung_eingegangen_am` + `zahlung_betrag` | verschieden befüllt (siehe 1.). Sie dienen als Sperrfelder (`mahnregeln.dart:65-66`, `kassierSperre`, SQL 194), obwohl die Wahrheit im Journal steht. |

**Vorschlag (Zielbild):** `zahlungsstatus` ∈ {`offen`, `bezahlt`, `abgeschrieben`} (bei Heineken zusätzlich `freigegeben_am`); Zustellung aus `versendet_am`/`uebergeben_am`, Mahnstufe aus `mahnung_stufe`. Die heutigen Werte als **abgeleiteter Anzeige-Status** (eine Funktion `anzeigeStatus(r)`). Zwischenschritt ohne Migration: eine zentrale Funktion `istOffen(r)` / `istZahlbar(r)` (= nicht bezahlt/abgeschrieben) für alle Pools und Filter, dazu ein Wächter-Test gegen `zahlungsstatus == 'offen' || == 'gesendet'`.

---

## 3. Abschluss und Prüfungen

### Überschneidungen

| Thema | Umsetzungen | Vorschlag |
|---|---|---|
| Reinigung ohne Ertragsbuchung | `ReinigungenOhneBuchungRegel` (Jahr), `ErtragsbuchungenRegel` (Monat, via `einsatz_lage`), `BuchungNachholService.finde/fuerAbschluss` | eine Erkennungsfunktion (`BuchungNachholService`), beide Regeln lesen daraus |
| camt-Kette / Deckung | `BankWaechter.luecke` + `pruefeAnschluss` (Import), `CamtKetteRegel` (Jahr), `BankAbgedecktRegel` (Monat, tageweise) | eine Deckungsfunktion |
| 1020 = camt-Saldo | `BankWaechter.pruefeSchluss`, `BankCamtRegel` | zusammenlegen |
| Soll-Saldo auf Verbindlichkeiten | `BankWaechter.verbindlichkeitsWarnungen`, `NegativeSaldenRegel`, `LohnkontenRegel`, `Mwst2202Regel` | wird bereits über `_andernortsGeprueft` entdoppelt; Wächter und Regel zusammenlegen |
| Verjährung | `DebitorenVerjaehrtRegel` (Stichtag − 5 Jahre, taggenau) vs. `jahrgang_abschreibung.dart` (Jahrgang ≤ Jahr − 5) | dieselbe Grenze verwenden (sonst ist z. B. der 31.12.2021 einmal verjährt, einmal nicht) |
| Delkredere | `DelkredereRegel` (Audit) + Knopf im Debitoren-Header (bucht **ohne Rückfrage** mit Datum heute) | Knopf nur noch in der Abschlussprüfung, mit Bestätigung |
| Status-Konsistenz | `DebitorenStatusRegel` (offen mit Zahlung) + Mahnlauf-Sperre I-3 + v0.134.1 | ok, aber nur eine Richtung (siehe unten) |

### Fehlende Prüfungen

| Prüfung | Warum | Aufwand |
|---|---|---|
| **1100 = Σ offene Rechnungen** (Kunden + Jahres + Heineken ab `freigegeben`) mit Liste der Abweichungen je Rechnung (Σ Buchungen mit `beleg_id` gegen Brutto) | heute −13'776.86 unerklärt, als «historischer Aggregat» versteckt | M |
| **Umgekehrte Richtung:** Rechnung `bezahlt`/`abgeschrieben`, aber Saldo der Rechnung ≠ 0 (keine oder zu kleine Zahlung/Abschreibung im Journal) | Heineken von Hand, Guthaben voll mit Fehlschlag, Status zurückgesetzt | S |
| **Heineken: Status ≥ freigegeben ⇒ Buchung 1100/3400 vorhanden** | Befund C | S |
| **Zahlungsbuchungen mit verwaister `beleg_id`** (Rechnung gelöscht) | Befund B; heute 0 Fälle | S |
| **Status und Mahnstufe widerspruchsfrei** (`gesendet`/`offen` mit `mahnung_stufe > 0`) | Rücknahme über die Bank | S |
| **2030:** Buchungen ohne auflösbaren Betrieb (Schlüssel `''` in `offenesGuthabenJeBetrieb`), negatives Guthaben je Betrieb, reserviert > Saldo | Guthaben entsteht nur von Hand, Fehlzuordnung wahrscheinlich; Saldo heute 30.00 | S |
| **Kasse 1000 gegen Belege:** Kassenbuchungen ohne Beleg (Bar-Reinigungen 1000/3400, Barzahlungen, Spesen) und Kassensturz-Datum | `KasseRegel` prüft nur Vorzeichen und Maximum | M |
| **Ertrag ≠ Rechnung:** Brutto der Ertragsbuchung (Reinigung, `reinigung_buchung_service.dart:127-129`, Satz aus der **Vorlage**) gegen Brutto der Rechnung (`rechnung_service.dart:145-147`, Satz aus der **Preisliste**); bei Jahresrechnungen Rundung je Reinigung gegen Rundung aufs Total | zwei getrennte Rechenwege → 1100 driftet um Rappen oder bei einem Satzwechsel | S |

---

## 4. Screens der Buchhaltung

| Screen / Route | Zweck | überlappt mit |
|---|---|---|
| `/buchhaltung` Dashboard | 4 Kennzahlen + Menü + letzte Buchungen | Auswertung (Umsatz), Rechnungen (Anzahl offen), MWST |
| `/buchhaltung/konten` Kontenplan | Saldo je Konto → Journal gefiltert (= «Kontoauszug») | Bilanz |
| `/buchhaltung/buchungen` Journal (+`?konto=`) | alle Buchungen, Storno | Dashboard «letzte Buchungen» |
| `/buchhaltung/berichte` Bilanz + ER (Tabs) | per Datum, PDF/Mail | Kontenplan-Saldi |
| `/buchhaltung/auswertung` | Umsatz nach Jahr/Monat (Grafik) | Dashboard-Kennzahl, ER |
| `/buchhaltung/monatsabschluss` | 10 Monatsregeln | Audit (siehe 3.) |
| `/buchhaltung/audit` Abschlussprüfung | 17 Jahresregeln | Monatsabschluss, Bank-Wächter, Debitoren-Header |
| `/buchhaltung/abschreibung` | Jahrgang abschreiben | Debitoren-Header (Sammel), Einzelabschreibung |
| `/buchhaltung/mwst`, `/steuern` | MWST, Steuern | – |
| `/buchhaltung/camt-import` (4 Tabs: Import+Abgleich-Vorschau, Prüfliste, Regeln, Dateien) | Bank | Prüfliste-Dialog «Zuordnen» doppelt zur Abgleich-Vorschau |
| `/rechnungen` Liste (+ Debitoren-Header, Statusfilter, Mahnfällig) | alle Rechnungen | Offen pro Betrieb, Mahnlauf |
| `/rechnungen/pro-betrieb` | offene je Betrieb, Kontoauszug-PDF | Mahnlauf (auch je Betrieb), Listenfilter «offen» |
| `/rechnungen/mahnlauf`, `/mahnfall/:id` | Mahnwesen | – |
| `/heineken/...` | Heineken-Monatsrechnungen, eigener Statusfluss | Rechnungsliste (gleiche Tabelle, getrennter Workflow) |

### Was zusammenfallen kann

1. **Debitoren-Header** (Rechnungsliste) **auflösen**. Die Kennzahl «1100 gegen offene Rechnungen» wird Regel und Zeile im Audit (Befund D). «Sammel-Abschreibung» **entfernen**: Seit der Voll-Übernahme ist jede Forderung eine Rechnung, eine Restdifferenz ist ein Fehler und kein Abschreibungsposten. Delkredere nur noch im Audit.
2. **Kundenzahlung zuordnen** (Prüfliste) und **Abgleich-Vorschau**: *ein* Zuordnen-Widget mit *einem* Rechnungspool (`istZahlbar`) und der Kernfunktion. Die Abgleich-Vorschau hat heute allein 5 Aufrufstellen mit leicht unterschiedlichen Parametern (`abgleich_vorschau.dart:493/545/869/1150/1716`, 1911 Zeilen).
3. **Monatsabschluss und Audit**: eine Prüfseite mit Umschalter Monat/Jahr und gemeinsamen Erkennungsfunktionen (siehe 3.). Der Bank-Wächter liefert nur noch den Befund beim Import.
4. **Offen pro Betrieb** als Gruppierungs-Schalter der Rechnungsliste (oder als Tab im Mahnlauf); der Kontoauszug-PDF bleibt als Aktion.
5. **Dashboard-Kennzahlen** und **Auswertung**: Die Kennzahlen verlinken auf die Auswertung statt eigene Zahlen zu rechnen.
6. Versandlogik aus `reinigung_form_screen.dart:~1000-1180` in `ReinigungRechnungVersand` zusammenführen (Kopie heute doppelt gepflegt).

---

## 5. Priorisierte Vorschläge

| Prio | Massnahme | Befund | Aufwand |
|---|---|---|---|
| **1** | Rechnungspool im Bankabgleich und im Prüflisten-Dialog: alle nicht erledigten Kunden- **und Jahresrechnungen** (`istZahlbar`), Wächter-Test gegen `== 'offen' \|\| == 'gesendet'` | A | S (½ Tag) |
| **2** | Korrektur einer abgeschlossenen Reinigung: nur wenn sich Betrag oder Zahlungsart ändern **und** die Rechnung unbezahlt, ungemahnt und unversendet ist sowie im offenen Jahr/Quartal liegt; sonst Hinweis «Gutschrift/Korrektur von Hand». Kein Löschen, sondern Rechnung und Positionen **aktualisieren** (Nummer bleibt). Kulanz-Wechsel beachten. | B | M (1–2 Tage) |
| **3** | Heineken: Status erst **nach** erfolgreicher Buchung; der Matcher nimmt nur `freigegeben`; die Monatsregel prüft die Buchung statt des Status | C | S |
| **4** | Versand-Rückfall: `zahlungsstatus` nur setzen, wenn `offen` (`updateWennStatus`), an allen 4 Stellen; Kopie im Formular entfernen | 2. | S |
| **5** | Regeln «1100 = offene Rechnungen» (mit Liste der Abweichungen) + «bezahlt/abgeschrieben, aber Saldo ≠ 0» + «Status/Mahnstufe widerspruchsfrei» + «verwaiste beleg_id»; dann die Differenz −13'776.86 klären | D, 3. | M |
| **6** | Debitoren-Header: Sammel-Abschreibung entfernen, Delkredere nur noch im Audit mit Bestätigung (`TapKnopf`) | D | S |
| **7** | `zahlungRueckgaengig`: Jahres-/Abschluss-Sperre, Mahnfelder aus dem Vorher-Stand wiederherstellen, Sammelzahlung als Gruppe zurücknehmen; Bestätigung über `TapKnopf(gefahr)` statt `FilledButton` (`rechnung_detail_screen.dart:278`) | E | S–M |
| **8** | **ZahlungKern** als DB-Funktion in einer Transaktion (Abschnitt 1), alle Wege darauf umstellen, tote Pfade löschen (`CamtAutoBooker.run`, `ZahlungsdifferenzService.verbuchen`, Status-Fallback in der Liste) | E | L (3–5 Tage, Opus/Fable-Plan) |
| **9** | Differenz-Wahl beim Zuordnen: Mehrzahlung → 8000 **oder** Guthaben 2030; Minderzahlung → 3805 mit MWST-Korrektur (wie Abschreibung) | 1. | M |
| **10** | Einzelabschreibung: Sperre `zahlungGebucht` in `MahnwesenService.abschreiben` selbst (nicht nur im Mahnfall), Status via `updateWennStatus`, Rücknahme-Weg analog Jahrgang; SQL 194 zusätzlich gegen das Journal prüfen | 1. | M |
| **11** | Statusmodell entflechten (Abschnitt 2): zuerst `anzeigeStatus()`/`istZahlbar()` zentral, später Migration | 2. | M, danach L |
| **12** | Prüfseiten zusammenlegen (Monat/Jahr), Erkennungsfunktionen entdoppeln, Offen-pro-Betrieb in die Liste | 3., 4. | M |

### DB-Zahlen (lesend, 25.09.2026)
- Offen: 1'084 Kundenrechnungen `offen` (112'423.15), 43 `gesendet` (4'804.20), 1 Heineken `freigegeben` (13'966.09); **0** gemahnte, **0** Jahresrechnungen.
- Saldo 1100 = 117'416.58; Saldo 2030 = 30.00; verwaiste Zahlungs-`beleg_id` = 0.
- Offene Kundenrechnungen 2020+2021 = 15'374.70 (Kandidaten Jahrgang 2026).
