# Buchhaltungsplan — Voll-Übernahme in die App

> **Abruf:** `/buchhaltungsplan` (oder „Buchhaltungsplan ausführen"). Der Command liest diese Datei, prüft den aktuellen DB-Stand und geht mit Daniel Schritt für Schritt durch.
>
> **Grundregel:** Buchhaltung ist sensibel — **keine schreibende Buchung ohne ausdrückliche Freigabe von Daniel**. Claude bereitet vor, zeigt Zahlen, fragt, bucht erst nach „ja". Erst Analyse/Vorschlag, dann Ausführung.

**Erstellt:** 14.07.2026 (nach 5-Agenten-Vollcheck). **Detailbefunde:** Memory `buchhaltung_vollcheck_2026_07.md` · Kurz-Aktionsliste: `ToDo.md` → „Buchhaltung-Vollcheck 14.07.2026".

**Aktueller Stand (07.08.2026 spätabends):** ✅ Phase 1 komplett (28.07.). ✅ Phase 0 erledigt: frischer GKB-Export 12.03.–06.08.2026 gezogen und importiert. 🟢 **Phase 2 zu ~99 % durch (Nachhol-Import 07.08. abends, v0.72.13–17):** 370 camt-Buchungen, ALLE 28 Belastungen verbucht, Bank 1020 läuft wieder durchgehend bis 06.08. (DB-Saldo 1'990.79). **Bank-Abstimmung TX-genau verifiziert (Skript `tx_diff`): DB-Saldo 14'878.37 + die 3 letzten offenen Gutschriften 287.55 = exakt der E-Banking-Schlusssaldo 15'165.92 per 06.08.** Offen nur noch: Ott-Ruf 74.60 (= Chleina Pub) · Schaltereinzahlung 74.60 (05.05.) · Schaltereinzahlung 138.35 (09.06.). Heineken Feb+März-Zahlungseingänge nachgebucht (Rechnungen standen backfill-bedingt schon auf bezahlt, ohne Buchung). Unterwegs gefunden+gefixt: Doppel-Tausch-Bug Bareinzahlung (2× Automaten-Einzahlung 8'050 verkehrt → DB korrigiert, Code v0.72.17); Allegra-Fehlgriff (5 Buchungen) rückgängig gemacht und neu zugeordnet. Rollback-Netz: Snapshot `snapshot_camt_abgleich` + `Datenbank/wartung/rollback_camt_abgleich_2026_08_07.sql` + App-Button «Zahlung rückgängig (Bankabgleich)».

> **⚠️ Seit 06.08.2026 gilt zusätzlich der Fahrplan der Buchhaltungs-Gesamtprüfung** (`docs/buchhaltungspruefung-2026-08-06.md`, Abschnitt F — 7 Schritte mit fester Reihenfolge). Er schiebt sich VOR Phase 2 dieses Plans: Erst Rundung/Doppelbuchung/camt-Codefixes (Schritte 1–3), dann deckt Schritt 3–5 die Phasen 2–3 ab. Stand: **Schritt 1 (B2 Heineken-Rundung) ✅ erledigt 07.08.2026** (v0.72.5 + 3 Datenzeilen, `Datenbank/wartung/korrektur_heineken_brutto_2026_08_07.sql`); Schritte 2–7 offen.

---

## Ziel

Buchhaltung ab dem Übergang lückenlos in der App führen. Die **Ertragsseite** ist bereits vollständig (Live-Buchungen ab Dez 2025, CHF 0 fehlt). Zu reparieren ist die **Geldseite**: Zahlungseingänge, Bankbewegungen ab 12.03.2026 (camt), Debitoren-Ausgleich, MwSt-/EK-Aufsetzpunkt.

**Stichtage (wichtig, korrigiert 14.07.2026):**
- **Excel-Journal** liefert bis **11.03.2026** (letzter Banktag) — davor ist alles importiert und journalgetreu.
- **camt** übernimmt die Bankseite **ab 12.03.2026** (technischer Code-Stichtag `11.03.2026` hardcoded in `camt_stichtag.dart`; TX ≤ 11.03. werden übersprungen). Der „01.07.2026" war nur organisatorisch, existiert nirgends technisch.

---

## Ausgangslage (Ist-Stand 14.07.2026)

**✅ Stimmt:** Excel-Import 2019–Nov 2025 journalgetreu (ER-Jahre ±0.12 CHF). Live-Ertrag ab Dez 2025 komplett (843 Reinigungen abgedeckt, CHF 0 fehlt). Keine Excel↔Live-Doppelbuchung. Live-Buchungen strukturell sauber.

**🔴 Fehlt (Geldseite):**
| | Lücke | Betrag |
|---|---|---|
| a | 220 Zahlungseingänge Dez 2025–11.03.2026 (Excel) fehlen in DB → Bank-DB −51'869.44 statt real **+3'322.26** | 55'191.70 |
| b | 270 camt-TX 12.03.–20.06. importiert aber **0 gebucht**; ab 21.06. keine Rohdaten | 51'776 ein / 47'694 aus |
| c | 0 Zahlungsbuchungen überhaupt; 532 Live-Rechnungen nie „bezahlt"; Debitoren 1100 um 44'222 zu hoch | — |
| d | MwSt-Altsalden 2200/1171/1170 unbrauchbar (Excel buchte MwSt nur im Hauptbuch, nie im Journal → nie importiert) | ~83'430 |
| e | Gewinnvortrag fehlt (13 Abschlussbuchungen als storniert importiert) | 35'319.11 |

---

## PHASE 0 — Vorbedingungen (Daniel, VOR der Umsetzung)

- [ ] **0.1** Andere Aufgaben zuerst erledigen (nicht Teil dieses Plans).
- [ ] **0.2** camt-Export nochmal **testen** (Probelauf).
- [ ] **0.3** Test-camt-Daten danach **wieder löschen** — sauberer Ausgangszustand vor dem Echtlauf. Betrifft: `camt_dateien` (aktuell 9 Duplikat-Archivzeilen desselben Exports), `camt_pruefliste` (3 offene), evtl. Test-Buchungen mit `camt_tx_key`. Prozedur: Memory `buchhaltung_loeschen.md`. **Claude macht das erst auf Ansage + zeigt vorher genau, was gelöscht wird.**
- [ ] **0.4** Frischen GKB-**camt.053-Export 12.03.2026 → heute** ziehen (ein durchgehender Export, deckt die ganze Bank-Periode ab). Diesen liest Daniel beim Echtlauf in der App ein.

➡️ Erst wenn 0.2–0.4 erledigt sind, startet Phase 1.

---

## PHASE 1 — Bank an das Excel-Ende anschliessen (mechanisch, Claude nach Freigabe)

- [x] **1.1** ✅ 28.07.2026: `020_2025_12_05_XXX_00007460` (74.60) = **Blockhuus Davos (0080)**, Zahler Gehri Gastronomie GmbH (Alias + Rechnungsadresse beim Betrieb erfasst).
- [x] **1.2** ✅ 28.07.2026: **Delta-Import der 220 Zahlungseingänge** ausgeführt (217× 1020/1100 + 3× 1020/1000 = CHF 55'191.70, `notizen = 'Excel-Delta-Import Zahlungseingaenge 28.07.2026'`).
- [x] **1.3** ✅ Verifiziert: Bank 1020 per 11.03.2026 = **+3'322.26** exakt (= E-Banking-Stand); Debitoren 176'228.04, Kasse 18'697.78 — alle drei Salden treffen die Prognose.

---

## PHASE 2 — camt einlesen & verbuchen (Daniel lädt in App, App/Claude verbucht)

- [ ] **2.1** Frische camt-Datei (aus 0.4) in der App importieren („Bankauszug Import"-Screen). Vor-Stichtag-TX (≤ 11.03.) werden automatisch übersprungen.
- [ ] **2.2** **Bestätigungs-Flow durchgehen** (bucht nichts automatisch):
  - Kundenzahlungen (Gutschriften) gegen die offenen Rechnungen matchen (Referenz → Alias → unscharf).
  - Ausgaben (Lohn, Kreditoren, AXA/AHV/ESTV/Gemeinden) über Regeln bestätigen.
  - **Heineken-Gutschriften 7'104.98 (30.03.) + 5'794.81 (30.04.)** → matchen jetzt exakt auf die am 14.07. erstellten **Feb + März-Monatsrechnungen** (die 2 „freigegeben"-Rechnungen; Prüfliste-Altfälle lösen sich damit auf).
- [ ] **2.3** **Verifikation:** Bank 1020 läuft durchgehend bis zum Enddatum des Exports; Soll-Wert per 19.06. = 7'403.97 (camt CLBD). DB-Ergebnis 2026 wird realistisch (Aufwand ab März nicht mehr fehlend).

---

## PHASE 3 — Debitoren bereinigen (Daniel entscheidet Vorgehen)

- [ ] **3.1** **532 Live-Rechnungen ab Dez 2025** (54'571.83) sind nie auf „bezahlt" gesetzt. Davon 414 Tresen-Reinigungen (typisch sofort bar/bezahlt). Vorgehen wählen: (a) via camt-Abgleich matchen wo Zahlung im Auszug, (b) Tresen-/Barzahler pauschal abhaken, (c) Rest offen lassen. → macht die Offene-Posten-Liste belastbar.

---

## PHASE 4 — Aufsetz-Entscheidungen (nur Daniel — fachlich)

- [ ] **4.1 MwSt-Aufsetzpunkt:** 2200/1171/1170-Salden für die Alt-Ära sind unbrauchbar (Alt-Ertrag steht brutto, ~83'430 MwSt-Anteil 2019–2025). **Empfehlung:** Aufsetzkorrektur per 31.12.2025 mit den Excel-Bilanzwerten (2200 = 17'223.38 geschuldet, 1171 = 1'148.11, 1170 = 3'654.08). Alternativ: Konten für Alt-Ära als „nicht bilanzfähig" markieren. → Entscheidung Daniel.
- [ ] **4.2 EK / Gewinnvortrag:** 13 Jahresabschluss-Buchungen (9000/9100/2970/2980) wurden als storniert importiert → Gewinnvortrag 35'319.11 fehlt, Bilanzgleichung geht nie auf. Optionen: entstornieren/nachbuchen ODER bewusst als reine Verkehrszahlen-Buchhaltung ohne EK-Abschluss dokumentieren. → Entscheidung Daniel.

---

## PHASE 5 — Prozesse ab Stichtag scharf (damit ab jetzt nichts mehr fehlt)

- [ ] **5.1 Heineken Juni-2026-Monatsrechnung** erstellen (überfällig; wartet: mind. 402.14 Reinigungen + 1'620 Pauschalen + Störungen/Montagen).
- [ ] **5.2 Eingangsrechnungs-Scan produktiv nutzen** — 23 Scans stehen alle auf „verworfen", Aufwand seit 08.06. nirgends erfasst. Kreditoren-Flow scharf schalten.
- [ ] **5.3 Lohnlauf ab Juli via App** (`lohn_abrechnungen` leer, bisher nur Excel).
- [ ] **5.4** `mahnwesenScharf` in `mail_config.dart` scharfstellen (wenn Mahnwesen genutzt wird).

---

## PHASE 6 — Aufräumen & Hygiene (klein, unkritisch)

- [ ] **6.1 Excel einfrieren:** Journal offiziell per 11.03.2026 (Bank) markieren; die 90 Zeilen ohne „Gebucht=X" (seit 20.06. in DB) im Excel abhaken oder Datei archivieren (sonst Doppelimport-Risiko).
- [ ] **6.2** 8 von 9 `camt_dateien`-Duplikat-Archivzeilen löschen.
- [ ] **6.3** 14 Ertrags-Belegvarianten Excel↔App (1'510.30, Rundung/Datum/Preis) einzeln entscheiden.
- [ ] **6.4** Kassenbestand physisch prüfen (DB 1000 = 23'477.48, ungewöhnlich hoch).
- [ ] **6.5** `abgerechnet`-Flags: 42 Bergkundenpauschalen + 22 Heineken-Reinigungen (Dez–Mai, verifiziert enthalten) auf `true` setzen.
- [ ] **6.6 Code:** beleg_id-Doppelsemantik dokumentieren (815× reinigungen.id vs. 6× rechnungen.id bei `beleg_typ='rechnung'`); Forderungs-Abgleich-Filter um Mahnstatus erweitern; Heineken 04/2026 Netto/Brutto 2-Rappen (netto als brutto−mwst ableiten).

---

## Reihenfolge-Logik (warum so)

1. **Erst Excel-Zahlungen (Phase 1)**, dann camt (Phase 2) — sonst startet camt auf einem um 55k falschen Bank-Anfangssaldo.
2. **Erst Bank vollständig**, dann Debitoren-Status (Phase 3) — der camt-Abgleich liefert die Zahlungsnachweise.
3. **Aufsetz-Entscheidungen (Phase 4)** können parallel laufen, sind aber reine Daniel-Fachentscheide.
4. **Prozesse scharf (Phase 5)** stellt sicher, dass ab jetzt kein neues Loch entsteht.
5. **Hygiene (Phase 6)** zum Schluss.
