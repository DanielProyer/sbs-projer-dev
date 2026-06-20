# ToDo-Liste - Daniel Projer

**Stand**: 20.06.2026
**Für**: SBS Projer App Entwicklung

---

## 🚧 IN ARBEIT: camt-Forderungsabgleich (TP2) — Branch `feature/camt-forderungsabgleich`
Spec + Plan freigegeben (`docs/superpowers/.../2026-06-20-camt-forderungsabgleich*`). **Task 1/12 erledigt** (Stichtag → 20.06.2026). **Resume bei Task 2** via subagent-driven-development. Details + Resume-Prompt in Memory [[camt-forderungsabgleich-tp2]]. Voll-camt-Datei liegt im Repo-Root (2'623 Gutschriften 2019–19.06.2026).

---

## 🗓️ Tagesabschluss 19.06.2026 — live v0.10.133 (Forderungen-Historie TP1 komplett)
Branch `feature/forderungen-historie-import` → gemergt nach `main` + deployed. Spec/Plan unter `docs/superpowers/`, ETL-Skripte unter `Datenbank/import/`.

1. **Historischer Import (TP1)**: 7'786 Reinigungen (2019–Nov 2025) + 4'438 Kundenrechnungen (Mail/Post/Tresen: bezahlt 3'425 / offen 1'013) + 4'438 Positionen aus Excel importiert. 106 ehemalige Kunden als `status='geschlossen'` neu angelegt + 7 Schreibvarianten als Alias. **Offene Forderungen CHF 105'240.95** — Treue-Gate SOLL=IST grün. Alles `quelle='excel_import'` (reversibel), KEINE Buchungen (Detail über 1100). Die 181 „ABSCHREIBUNG"-Marker bleiben **offen** (real nicht abgeschrieben).
2. **Scans verknüpft**: 7'328 Protokoll-PDFs (`protokoll_foto_pfad`) + 3'404 Zahlbelege (`zahlung_beleg_pfad`) in Bucket `reinigung-fotos` (`import/010/`, `import/020/`).
3. **App-Fix Pagination** (v0.10.132): PostgREST 1000-Cap war Grund für „fehlende" Reinigungen → `reinigung_repository`/`rechnung_repository` paginiert. **Merke: jede grosse Liste paginieren.**
4. **anlage_id nachgezogen**: 7'249 zugeordnet (Excel-Index `_NN` → N-te Anlage), 1'845 ohne (Betrieb ohne Anlage).
5. **Betrieb-Detail**: Reinigungs-Liste aufklappbar (v0.10.133).
6. **Zusatzanlagen-Merge**: 1'308 „Zusätzliche Anlage"-0.00-Dubletten zusammengeführt (9'094→7'786). 2 alleinstehende bewusst behalten (Vieri Bar, Strela — bestätigt korrekt).

**Offen / nächst:**
- [ ] **App-Sichtprüfung Scans**: zeigen Protokoll-/Zahlbeleg-Scans an Reinigungen/Forderungen korrekt an? (Pfad `import/010/x.pdf` im privaten Bucket `reinigung-fotos` → App muss signed URL bauen.)
- [ ] 1100-Plausibilität im Debitoren-Screen gegen die 105'240.95 prüfen.
- [ ] **TP2 — camt-Abgleich-Engine** (Subset-Summe Auto-Match offener Forderungen + Sammelzahlungen + Prüfliste; Anker `rechnungen.einzahlungsbeleg`). Danach TP3 Hub/Mahnwesen auf echten Daten.

---

## 💳 camt-Follow-up (nach TP2)
- [ ] **QR-Referenz-Matching** für selbst generierte Mail/Post-Rechnungen (ab heute): eindeutige QR-Referenz beim Rechnung/QR-Erstellen vergeben + Feld `rechnungen.qr_referenz` + Referenz-First-Matching im camt-Abgleich (`CamtTransaction.strukturierteReferenz` → Rechnung, deterministisch, vor Name+Betrag-Fallback). Daniel 20.06.2026. Eigenes TP nach dem aktuellen camt-Forderungsabgleich (Spec/Plan 2026-06-20).

## 🎨 UI-Follow-up (geplant, NICHT jetzt)
- [ ] **App-weite Vereinheitlichung** von Filtern, Dropdowns etc. — einheitliches Design über die ganze App (Daniel 20.06.2026). Referenz-Stil aktuell: schlichte `DropdownButton` im `Wrap` (Zeitraum-Picker Erfolgsrechnung + Konto-Journal v0.10.136). Eigener grösserer Durchgang.

## 🗓️ Tagesabschluss 18.06.2026 — live v0.10.130 (64 Commits, 5 Features)
Alles gemergt nach `main` + auf gh-pages deployed. Specs/Pläne unter `docs/superpowers/`.
1. **Berichtswesen-Umbau** (v0.10.119, Detail unten): Bilanz & Erfolgsrechnung als 2-Tab-Screen, MwSt eigener Screen, freie Datum-/Zeitraumwahl, PDF + Mail.
2. **ER-/Bilanz-Verfeinerungen** (bis v0.10.127): ER-Zeitraum als Geschäftsjahr- + Quartal-Dropdown (inkl. „Ganzes Jahr"; Quartal bleibt beim Jahreswechsel → schneller Vergleich); Kontenklassen 3–8 mit KMU-Beschreibungen, „Alle Konten" entfernt; ER-PDF: Sonderzeichen-Fix (ASCII statt `−`/Dashes, Umlaute ok), grössere Hauptübersicht (Jahresergebnis-Box), Kontenklassen auf eigener Seite mit Detail-Beschreibung; Bilanz mit Geschäftsjahr-Dropdown (je 31.12.).
3. **Geschäfts-Einstellungen + Settings-Umbau** (v0.10.128): neue Tabelle `geschaeft_einstellungen` (Firma/GF/Kontakt/MWST `CHE-413.083.919`/UID) speist Lohn (AG-Snapshot, AN-Vorbefüllung), **Report-Mail-Empfänger** und **PDF-Firmendaten** (Bilanz/ER-Kopf + Kundenrechnung-Kopf; QR/IBAN unangetastet). Überall Fallback auf die alten Konstanten. **Gast-Account deaktiviert** (Auth-User gelöscht + 26 `*_guest_read`-Policies weg, Migration 097; App-`isGuest`-Code inert belassen — siehe [[gastaccount-read-only-heineken]]).
4. **Lohn-Trennung** (v0.10.129): Lohn-Einstellungen = nur noch variable Sätze (Sozialvers. + BVG); fixe AN-Stammdaten (AHV-Nr./Geburtsdatum) im Geschäft; Lohnbuchhaltung operativ ohne Einstellungs-Links; Lohnausweis unverändert (AN/AG-Snapshot beim Speichern).
5. **MWST-Sätze Historie** (v0.10.130): `mwst_satz` + `satz_reduziert` (7.7/2.5 bis 2023, 8.1/2.6 ab 2024), datumsabhängig; Einstellungen zeigen Historie + „Neuen Satz hinzufügen"; von den Preisen entkoppelt. Buchungs-Normalsatz + Spesen-Pfad (Satz vom Beleg) unverändert.

**Offene Klärpunkte (mit Daniel, unverändert):** B1 Lohnaufwand 5000 ~1–2k/Jahr über Lohnausweis-Brutto; B3 MWST-Zahllast 2023 +1'379. Plus camt-Review-Follow-ups (erst beim Echtlauf ab August relevant).

---

## 📑 Berichtswesen-Umbau (18.06.2026, gemergt + deployed v0.10.119)
„Berichte" → **„Bilanz & Erfolgsrechnung"** (2 Tabs, Route `/buchhaltung/berichte`); **MwSt-Abrechnung** eigener Screen (`/buchhaltung/mwst`). Bilanz frei nach Stichtag, ER frei nach Zeitraum (Presets + Datumswahl). Professionelle Darstellung mit `chf()` (Tausender-Apostroph) + Bilanz-Check. ER-Scroll-Seite: Stufen + aufklappbar Kontenklassen + alle Konten. PDF (Bilanz 2-spaltig, ER 3 Ebenen) via `printing`; Mail-Versand via neue Edge Function `send-pdf-mail` (Inline-PDF). Reine Services getestet (chf/kontenAufstellung/bilanz-erstelle). Spec/Plan: docs/superpowers/.../2026-06-18-berichtswesen-umbau*. 77 Tests grün.
- [x] **Mail-Empfänger Berichte** kommt jetzt aus dem Geschäft (`mail_geschaeft` → `mail_privat` → Fallback) — siehe Geschäfts-Einstellungen unten.

## 🧾 Forderungen-Hub (13.06.2026, gemergt + deployed v0.10.118)
Debitoren/Rechnungen/Mahnwesen vereint: Rechnungsliste = Hub „Forderungen" (`/rechnungen`) mit Mahnfällig-Filter + einklappbarem Debitoren-Kopf (Salden + Sammel-Abschreibung + Delkredere). `ForderungService` (empfohlene Mahn-Aktion, TDD). Mahnwesen-/Debitoren-Screens entfernt (Routen→Redirect), Tiles zu einem „Forderungen". Kritischer Re-Audit: Bilanz geht auf (Diff −0.02 Rundung), keine Strukturfehler.
- [ ] **Hub Follow-up (Minor, toter Code):** `forderungenProvider` ungenutzt; `mahnwesenDashboardProvider` nur noch invalidiert (kein watch mehr). Beide entfernen + invalidate-Aufrufe auf `rechnungenStreamProvider` umbiegen.
- [x] **Buchungsvorlagen aufgeräumt** (Migration 095): camt 20.1→F-bankgeb, 19.1→F-fran-zg umgehängt; deaktiviert 19.1/20.1/A-telekom/A-sachvers/A-sozvers (A-sozvers war falsch: generisch 5700 statt BVG 5720/SUVA 5730 — 30.1/30.2/30.3 behalten); Titel 15.1/24.1 verbessert. Keine aktiven Dubletten mehr. **Technik-Merke:** camt-Booker braucht FIXE Soll/Haben-Vorlagen (nutzt vorlage.sollKonto direkt) → Ausgabe-Vorlagen (A-*) sind als camt-Ziel ungeeignet.

---

## 📥 camt-Auto-Buchung (Rechnungskontrolle)

**Phase 1 + Phase 2 fertig** (Branch `feature/camt-rechnungskontrolle`): Parser-Split, Stichtag 01.07.2026, Klassifizierer, Kundenzahlungs-/Heineken-Matching, Prüfliste, Auto-Booker, Ausgaben-Regelwerk (`camt_regel` + 13 Startregeln + 4 neue Vorlagen 5700/5720/5730/8900), Regel-UI + Dashboard-Einstiege. Spec/Plan unter `docs/superpowers/`. **Produktiv aktiv ab Stichtag 01.07.2026.**

Review-Follow-ups (dokumentiert, nicht kritisch — Daniel kontrolliert ohnehin jede Buchung):
- [ ] Phase-1 I2: Bei Netzfehler nach erfolgter Buchung aber vor Rechnung-Update entsteht ein verwirrender Prüflisten-Eintrag (kein Doppelbuchen). Reihenfolge/Transaktionalität verbessern.
- [ ] Phase-1 M4: `HeinekenBuchungService.createZahlungseingang` bucht mit `DateTime.now()` statt Bank-Buchungsdatum — optionalen `datum`-Parameter ergänzen.
- [ ] Saldo-Parsing-Bug (vorbestehend): `OPBD/CLBD` werden als 0 gelesen (`CdOrPrtry` liegt unter `Tp`). Nicht von der Pipeline genutzt, aber falsch.
- [ ] Phase-2: Regel `'abschluss'` ist breit (Substring) — beobachten; ggf. auf IBAN/spezifischeren Text verengen. Lohn-Regel „daniel proyer" ggf. auf IBAN (CH7909000000870500683) umstellen.
- [ ] M1: Heineken-Klassifizierung per Substring „heineken" — ggf. auf „heineken switzerland" verengen.
- [ ] **Phase 0a Follow-up:** 11 alte camt-referenzierte Vorlagen (15.1, 19.1, 2.1, 20.1, 22.7, 24.1, 25.4, 30.1–30.4) blieben bewusst `ist_aktiv=true` (FK-Schutz). Optional später: camt-Regeln auf die neuen Geschaeftsfaelle (A-sozvers/F-steuer-*/A-telekom/A-sachvers/F-bankgeb/F-fran-zg) umhaengen, dann Alt-Vorlagen deaktivieren. Tauchen aktuell zusaetzlich im manuellen Vorlagen-Dropdown auf.

**Bewusste Design-Entscheidung (NICHT ändern):** Kein DB-Unique-Constraint auf `buchungen(camt_tx_key)` — der Kundenzahlungs-Pfad stempelt denselben `tx_key` absichtlich auf mehrere Buchungen (Sammelzahlung). Dedup läuft korrekt über den In-App-Set (Single-User-App).

**Erster Echtlauf (Anfang August 2026):** Juli-camt hochladen, Ergebnis-Report + Prüfliste durchgehen. Bei neuen wiederkehrenden Empfängern „Regel anlegen" nutzen.

---

## 🔴 VOR DEVELOPMENT-START

### Daten-Vorbereitung

- [ ] **Regionen-Polygone erstellen (GIS)**
  - KML-Dateien für alle 15 Regionen erstellen:
    - Arosa
    - Chur
    - Davos
    - Domleschg
    - Flims/Laax/Falera
    - Lenzerheide
    - Oberland
    - Prättigau
    - Rheintal
    - Rheinwald
    - Innerschweiz
    - Sempach
    - Küssnacht
    - Cham
    - Engadin
  - Format: KML oder GeoJSON
  - Koordinatensystem: WGS84 (EPSG:4326)
  - **Notiz**: Evtl. ergeben sich andere Gebietsaufteilungen beim Erstellen
  - **Wann**: Kann später gemacht werden, nicht kritisch für MVP

---

## 🟡 WÄHREND DEVELOPMENT

### Testing & Feedback

- [ ] **Beta-Testing Phase**
  - App auf echten Geräten testen
  - Real-World-Szenarien durchspielen
  - Offline-Modus testen (Bergkunden ohne Netz)
  - Feedback an Entwickler

### Beleg-Digitalisierung verbessern

- [ ] **Beleg-Foto Ausrichtung/Zuschnitt optimieren**
  - Automatische Ausrichtung (Deskew) des fotografierten Belegs
  - Zuschnitt auf Beleg-Bereich (Crop)
  - Kontrast/Helligkeit optimieren für bessere Lesbarkeit

### Telefon-Kontakte Sync

- [ ] **Bulk-Sync Handy-Kontakte ↔ App-Kontakte**
  - App-Kontakte haben Priorität (alte Telefonbuch-Einträge können ungültig sein)
  - Alle Kategorien: betrieb, heineken, event
  - Telefonbuch-Labels: „SBS Kunden", „SBS Heineken", „SBS Event"
  - Matching über normalisierte Telefonnummer
  - Ergebnisse zur Bestätigung anzeigen bevor Änderungen übernommen werden
  - Basis: bestehende `PhoneContactService` + `flutter_contacts`

### Daten-Migration

- [ ] **Excel-Daten vorbereiten**
  - Aktuelle Excel-Datei sichern
  - Letzte Änderungen eintragen
  - Bereit für Import

### Termin-Erinnerungen — Folge-Tests
- [ ] **Web-Test**: Termin mit Erinnerung (~2 Min Zukunft, „Pünktlich") → Browser-Notification + In-App-Hinweis prüfen
- [ ] **Android-Test** beim nächsten APK-Build: lokale Benachrichtigung feuert (auch bei geschlossener App); Berechtigungen (Benachrichtigung, exakter Alarm) prüfen

### Temporäres aufräumen

- [ ] **Rechnungs-Nachversand-Screen entfernen** (wenn Backlog ab 18.02.2026 abgearbeitet)
  - Datei `rechnungen_nachversand_screen.dart` löschen
  - Route in `router.dart` entfernen
  - Tile in `buchhaltung_dashboard_screen.dart` entfernen
- [ ] **Restliche Mail-Bereiche scharfstellen**: `bestellungScharf` + `mahnwesenScharf` (in `mail_config.dart`) — aktuell noch Test-Empfänger

---

## 🔵 BUCHHALTUNG SCHARFSTELLEN (01.07.2026)

**Strategie (aktuell): VOLL-ÜBERNAHME, nicht Clean-Start.**
Die komplette Historie ist importiert + läuft live: Buchhaltung **lückenlos 27.03.2019 → heute** (2019: 1'456 … 2025: 2'604 … 2026: 1'290 Buchungen, Stand 12.06.2026), Bilanz geht an allen Jahresenden auf (Phase 2b). Die Bilanzkonten-Salden tragen sich fortlaufend weiter → **am 01.07. läuft die Buchhaltung einfach aus den laufenden Salden weiter.**

~~Detailplan `.claude/plans/snuggly-frolicking-pine.md` (Clean-Start: Test-Buchungen löschen + Eröffnungsbilanz)~~ — **überholt durch die Voll-Übernahme.** „Scharfstellung" heißt jetzt nur noch: camt produktiv + restliche Mail-Bereiche scharf + Altjahr-Fachfragen klären.

### Features entwickeln (Mai/Juni)

- [x] ~~**A1: Eröffnungsbilanz-Screen**~~ — **HINFÄLLIG** (Voll-Übernahme: keine Anfangssalden zu seeden, Historie ist durchgehend im System). Konto 9100 nicht nötig.

- [x] **A2: Heineken-Rechnung → automatische Buchung** (KRITISCH) ✅ 29.05.2026
  - Status 'freigegeben' → HeinekenBuchungService.createFromRechnung (Debitoren/Ertrag + MwSt)
  - Status-Workflow: offen → gesendet → freigegeben → bezahlt

- [x] **A3: Zahlungseingang → automatische Buchung** (KRITISCH) ✅ 29.05.2026
  - Status 'bezahlt' → HeinekenBuchungService.createZahlungseingang (Soll Bank / Haben Debitoren)

- [ ] **A4: Wiederkehrende Buchungen** (NICE-TO-HAVE, nicht Blocker)
  - Monatliche Standard-Buchungen mit 1 Klick (Lohn, AHV, Miete, etc.)
  - Konfigurierbare Liste, Duplikat-Check — teilweise via Buchungsvorlagen + camt-Regeln abgedeckt

- [ ] **A5: Monatsabschluss-Checkliste** (NICE-TO-HAVE)
  - Automatisch berechnete Checkliste pro Monat
  - Alle Services gebucht? Heineken-Rechnung? Spesen? Bank-Import?

- [x] **A6: Kontenplan geprüft & ergänzt** ✅ (9100 nicht mehr nötig, da keine Eröffnungsbilanz)
  - Konto 9100 (Eroeffnungsbilanz) hinzufuegen
  - Pruefen ob alle Konten fuer Vollbetrieb vorhanden (Loehne, Sozialversicherungen, etc.)
  - ✅ 4 Lohn-Konten hinzugefuegt: 5710 FAK, 5720 BVG AG, 5730 UVG AG, 5740 KTG AG
  - ✅ 1109 Delkredere + 3805 Debitorenverluste (Migration 089)
  - ✅ 9 fehlende Konten ergaenzt (Migration 091, Titel aus Excel-Kontenrahmen): 2208 Direkte Steuern (Rueckstellung), 2276 KAE-Kontokorrent, 2500 Coronakredit GKB, 5880 Sonstiger Personalaufwand, 6460 Entsorgungsaufwand, 6500 Bueromaterial, 6550 Gruendungskosten, 8510 Haertefallgelder, 8900 Direkte Steuern. Dublette 8500 deaktiviert (0 Buchungen).
  - ✅ 0b-Check: alle Klasse-1/2-Konten mappen in eine Bilanz-Gruppe (Final-Review bestaetigt). Kategorie-Feinnormalisierung auf Excel-Untergruppen optional/spaeter.

## 📊 Phase 0b Auswertungen — FERTIG (13.06.2026, gemergt)

Bilanz-Screen (neu, /buchhaltung/bilanz), Erfolgsrechnung auf KMU-Stufengliederung umgestellt, MWST-Vorschau-Bugfix (Umsatz 3400 statt 3000 → war immer 0). Reine Services BilanzService/ErfolgsrechnungService (TDD), Gliederung = Excel-Sheets. Plan: docs/superpowers/plans/2026-06-13-phase0b-auswertungen.md. 43 Tests gruen.

- [x] **MwSt-Vorschau Vorsteuer-Bug** (`mwstQuartalDetailProvider`) — behoben in Phase 2c (Task 4): Provider rechnet jetzt über `SaldoExpansion` (Umsatzsteuer = −Saldo 2200, Vorsteuer = Saldo 1170+1171), erfasst zugleich Abschreibungs-Rückholungen.
- [ ] **Phase 0c:** Offene-Posten-Sicht (Debitoren 1100 / Kreditoren 2000) — eigener Plan, dann Phase 1 (Excel-Import 2019–2025 + camt-Abgleich).
- [x] **Phase 1 Teil 1** (MWST-korrekte Saldo-Expansion) — gemergt.
- [x] **Phase 1 Teil 2** (Excel-Import 14'552 Zeilen 2019–Nov 2025) — gemergt; Treue-Gate alle Jahre 0 Diff. Skripte: Datenbank/import/.
- [x] **Phase 2a** (Audit-Screen + mechanische Korrekturen) — gemergt: Audit-Screen `/buchhaltung/audit` (4 Kategorien), 8090→8900 (6 Zeilen, rückdatiert), 2500-Restsaldo→0. Migration 093.
- [x] **Phase 2b** (Jahresabschluss-Reconciliation, Modell 2) — gemergt: BilanzService rechnet kumuliertes Ergebnis → EK-Split (Gewinnvortrag + Jahresergebnis), Bilanz geht auf (Differenz 0 an allen Jahresenden); Abschlussbuchungen 2970/2980/9000/9100 storniert (Migration 094). ER unverändert.
- [x] **Phase 2c** (Abschreibungs-Werkzeug) — gemergt: `AbschreibungService` (korrekte 2-Buchungs-Logik 3805 netto + 2200 MWST-Rückholung / 1100, rückdatiert), Mahnwesen-Abschreibung gefixt (GF-1.9 behoben), MWST-Vorschau über SaldoExpansion (erfasst Rückholung + **Vorsteuer-Bug behoben**), Debitoren-Hub `/buchhaltung/debitoren` (Sammel-Abschreibung + Delkredere 5%). Daniel entscheidet selbst, jederzeit. 63 Tests grün.
- [ ] ~~Phase 2c mit Treuhänder~~ — Daniel arbeitet ohne Treuhänder (Memory), entscheidet selbst über Abschreibungs-Beträge im Debitoren-Hub. Analyse (13.06.2026): Offen-Bestand wächst ~15–22k/Jahr; alte Jahrgänge **2019–2022 ≈ 50k = Abschreibungs-Kandidaten** (kaum eintreibbar), 2024–25 eher teilweise eintreibbar. **Treuhänder-Fragen:** (a) Wieviel der alten ~50k definitiv uneinbringlich abschreiben (3805/1100 netto + 2200 MWST-Rückholung) vs. Delkredere 5%? (b) Welche konkreten Kunden? (c) Verlust → Verlustvortrag. Negative Salden 2202 (MWST-Abrechnung)/2273 (KTG)/8900 (Steuern) sind Verrechnungs-/Timing-Konten, KEINE Abschreibung — nur bestätigen.
- [ ] **Kritische Gesamtprüfung (13.06.2026, Report: docs/buchhaltung-kritische-gesamtpruefung-2026-06-13.md):**
  - [ ] **B1 (mit Daniel):** Lohnaufwand 5000 liegt durchgängig ~1–2k/Jahr ÜBER dem Lohnausweis-Brutto — klären (AG-Beiträge/Spesen in 5000? oder überbucht?). Relevant für AHV-/Steuerbasis.
  - [ ] **B3 (mit Daniel):** MWST-Zahllast 2023 App 8'014 vs. deklariert ≈6'635 (+1'379) — Quartals-Timing/Buchung prüfen (andere Jahre decken sich exakt).
  - ✅ Bestätigt: Sozialvers = nur AG-Anteil (BVG-Doppelzähl entkräftet); MWST gesamt plausibel; Franchise konsistent; Corona-Hilfen korrekt; Bilanz geht auf.
- [ ] **Optional Excel-Gegencheck:** Daniel setzt Excel-Bilanz auf 31.12.2024, rechnet neu + speichert → bit-genauer externer Abgleich Kasse/Debitoren/Bank (Excel-Sheets sind sonst gecachte Werte, unzuverlässig).
- [ ] **Phase-1-Vorbereitung (aus 0b-Final-Review):** Jahres-Abschlussbuchungen (Gewinnvortrag→2850/2970) beim Excel-Import zwingend mitnehmen, sonst Bilanz-Differenz. betragBrutto=Bruttomethode (passt). Bei sehr vielen Buchungen ggf. jahresgefilterte DB-Query statt getAll().

### Restliste bis 01.07.2026 (statt Clean-Start-Umstellung)

- [x] ~~Test-Buchungen löschen / Eröffnungsbilanz erfassen / Aktiven=Passiven-Check~~ — **entfällt** (Voll-Übernahme, Daten sind echte Historie, NICHT löschen)
- [ ] **camt-Auto-Buchung produktiv** ab Stichtag 01.07.2026 — bereits gebaut, geht automatisch scharf. Erster Echtlauf Anfang August (Juli-camt).
- [ ] **Restliche Mail-Bereiche scharfstellen**: `bestellungScharf` + `mahnwesenScharf` in `mail_config.dart` (stehen noch auf Test-Empfänger)
- [ ] **2026 auf echte Test-Buchungen durchsehen** — falls aus der Entwicklung vereinzelt Test-Einträge drinstecken (gezielt, NICHT pauschal). Echte Live-Buchungen (Heineken/Reinigung/Spesen/camt) bleiben.
- [ ] **B1 (Fachfrage):** Lohnaufwand 5000 ~1–2k/Jahr über Lohnausweis-Brutto klären (siehe Phase-0b-Block oben)
- [ ] **B3 (Fachfrage):** MWST-Zahllast 2023 +1'379 ggü. deklariert klären (siehe Phase-0b-Block oben)

---

## 🟢 NACH MVP-LAUNCH

### Erweiterungen

- [ ] **Andere Franchise-Partner einladen**
  - Kontakte sammeln
  - Interesse abklären
  - Onboarding planen

- [ ] **Zusätzliche Regionen definieren**
  - Regionen der anderen Partner erfassen
  - KML-Dateien erstellen

### Schulung

- [ ] **Andere Partner schulen**
  - Training-Sessions organisieren
  - Dokumentation teilen
  - Support anbieten

---

## 📝 NOTIZEN

### GIS / Regionen-Polygone

**Warum Polygone?**
- Präzise Abgrenzung der Regionen
- "Liegt Betrieb X in meiner Region?" → Automatische Prüfung
- Bessere Visualisierung auf Karte

**Workflow:**
1. QGIS oder Google Earth Pro öffnen
2. Regionen-Grenzen nachzeichnen
3. Als KML exportieren
4. In App importieren

**Tools:**
- QGIS (Open Source)
- Google Earth Pro (kostenlos)
- Google My Maps (Online)

---

## ✅ ERLEDIGT

- [x] Post-Rechnungen: beim Abschluss Mail mit Rechnung+Protokoll an Daniel (zum Ausdrucken) + versendet_am = Abschlusstag; 3 heutige nachgemailt (02.06.2026)
- [x] Nachversand: Rechnungs-PDF live neu generieren mit aktuellem Fälligkeitsdatum (Versand+30); Rechnungen Jatzmeder + Milez auf unversendet (neue Adresse) (02.06.2026)
- [x] Tourenplanung: Fälligkeitsstufen bald fällig 4W / fällig 5W / überfällig 6W (relativ zum Rhythmus) (02.06.2026)
- [x] Kalender: Saison-/Ferien-Vorschläge synchronisieren (veraltete entfernen) + keine Eröffnungsreinigung nach Endreinigung; 39 veraltete Vorschläge bereinigt (02.06.2026)
- [x] Termin-Erinnerungen (Popup/Alarm): pro Termin aktivierbar + Vorlaufzeit; Android lokale Benachrichtigung, Web Browser-Notification + In-App, kein Push-Server (Migration 086, v0.10.106) (01.06.2026)
- [x] Heineken WE/AG-Nummern für 155 Betriebe aus DBO-Kundenliste ergänzt (Name+Ort-Matching, eindeutige Treffer) (01.06.2026)
- [x] Mail-Versand Reinigung + Montage/HeiGenie scharfgestellt (echte Kunden- bzw. RSL-Empfänger) (30.05.2026)
- [x] Nachversand-Screen: Testmodus-Respekt, Reinigungsprotokoll-Anhang, versendet-Markierung aus DB, Piaggio Dosch ausgeblendet (30.05.2026)
- [x] Mail-Adressen-Bereinigung: Zero-Width-Zeichen entfernen (MailConfig.bereinige + DB-Fix Padelta) + IDN-Punycode in Edge Function v7 (teehütte-klosters.ch) (30.05.2026)
- [x] versendet_am nur bei scharfem Versand (MailConfig.istScharf); DB-Korrektur Mountain Plaza + Padelta (30.05.2026)
- [x] Heineken-Monatsrechnung: Status-Workflow (offen → gesendet → freigegeben → bezahlt) + automatische Buchungen (29.05.2026)
- [x] Buchhaltung: Rechnungs-Nachversand-Screen (PDF on-demand neu signieren, betriebe.email-Fallback, 5-Rappen-Rundung) (29.05.2026)
- [x] Projekt-Review Opus 4.8: Reinigung-/Anfahrtspauschale-Bugfix, Kontakt-Isar-Integration (Native-Build wieder lauffähig), Lint-Cleanup (0 Errors) (29.05.2026)
- [x] Geschäftsabläufe dokumentiert (alle 9 Abschnitte)
- [x] Excel-Daten analysiert
- [x] Regionen-Liste erstellt (11 Regionen)
- [x] Tech-Stack-Entscheidung (Flutter + Supabase)
- [x] Datenmodell entworfen
- [x] Spesen-Scanner mit OCR (Claude Haiku) — Beleg fotografieren → automatische Buchung
- [x] camt.053 Bankimport — XML-Import, Duplikat-Erkennung, Auto-Betrieb-Matching
- [x] Vorsteuer-Buchungen (separate MwSt-Einträge auf Konto 1171)
- [x] TWINT/Karte Zahlungsweg-Erkennung (automatisch aus Beleg)
- [x] Beleg-Viewer (Belege direkt öffnen statt URL anzeigen)
- [x] Termine-Modul (Kalender, CRUD, Betrieb-Zuordnung)
- [x] Störungen UI komplett überarbeitet (Anlagentyp-Filter, Monatsgruppierung, Störungsnummer-Avatar)
- [x] Störungs-Formular: Anlagentyp-Auswahl mit Betrieb-Vorauswahl
- [x] Material-Dropdown öffnet nach oben (Mobile-Tastatur-Fix)
- [x] Uhrzeiten HH:mm statt HH:mm:ss überall
- [x] Betrieb: Saison ohne Datum anzeigen, Mein-Kunde-Logik bei Zapfsystemen
- [x] 5-Rappen-Rundung für alle CHF-Beträge
- [x] Reinigung-Buchung: Automatische Buchung bei Tresen/Mail/Post
- [x] Performance: Shared Betrieb-Provider (8 Screens refactored)
- [x] Performance: Home Screen Sub-ConsumerWidgets (weniger Rebuilds)
- [x] Home Screen: 2x5 Kachel-Grid optimiert für Pixel 9
- [x] Montage: HeiGenie Protokoll-Anzeige full width
- [x] Belegscanner: Rundungsdifferenzen ≤0.05 CHF automatisch mergen
- [x] Buchungsvorlage Parkgebühren Privat/Twint
- [x] Heineken Monatsrechnung: km-Abrechnungen ohne Bereich
- [x] Kontakt-Rolle «Vertreter» für Heineken
- [x] Kontakt-Sync Stufe 1: App-Kontakte aufs Handy pushen (Bulk-Push mit Labels)
- [x] Buchungsvorlagen: 37 Duplikate bereinigt
- [x] Beleg-Erfassung im Buchungsformular (PDF/Foto/Kamera Upload)
- [x] Lohnbuchhaltung komplett (flexible Auszahlungen, Versicherungs-Sätze konfigurierbar, Lohnausweis-PDF)
- [x] Betrieb: WE-Nummer + AG-Nummer Felder (Nummern-Kategorie in Form/Detail)
- [x] Betrieb: Region in Detail-Ansicht anzeigen
- [x] Heineken Monatsraster: PDF-Generierung (Querformat, gruppiert nach Regionen)
- [x] Heineken Monatsraster: Mail-Versand via Edge Function (send-raster-mail)
- [x] Heineken Monatsraster: Storage Bucket + Upload
- [x] Heineken Monatsraster: Jede Region auf eigener Seite
- [x] Heineken Monatsraster: PDF-Cache pro Jahr (Jahreswechsel behält PDF)
- [x] Heineken Monatsraster: Servicezeiten-Bindestrich fix (Sonderzeichen → normaler Bindestrich)
- [x] Heineken Monatsraster: Layout mobilfreundlich (Button + Wrap)
- [x] Betrieb: WE/AG-Nummern mit Zahlentastatur
- [x] Betrieb: Servicezeiten (Morgen/Nachmittag) hinzugefügt
- [x] Service Worker deaktiviert — Webapp sofort aktuell nach Refresh
- [x] 3 neue Regionen: Sempach, Küssnacht, Cham
- [x] Heineken Monatsraster: Cache-Buster auf PDF-Download-URL
- [x] Heineken Monatsraster: PDF Layout-Verbesserungen
- [x] Heineken Raster-Mail: Text mit aktuellem Datum
- [x] Zahlungsdifferenz-Handling bei Rechnungen + Pikett-Formular anpassen
- [x] Heineken Störungsformular: Pikett KW Sonderzeichen-Fix + Km-System
- [x] Pikett-Monatszuordnung nach Montag der KW
- [x] Eröffnung/Endreinigung: Störungsnummer + Art im Formular anzeigen
- [x] Heineken Monatsrechnung: Gratisreinigungen fehlen nach Neuerstellen — Fix
- [x] Heineken PDF: 5 Verbesserungen (Layout, Formatierung)
- [x] Pikett-Dienste Kachel: Gruppierung nach Montag der KW
- [x] DST-Bug in Kalenderwochen-Berechnung behoben (UTC statt lokale Zeit)
- [x] Heineken PDF: Seitenumbruch-Fix + verbrauchtes Material anzeigen
- [x] Material-Formular: Heineken-Beschreibung + Foto-Optimierung
- [x] Material-Foto: Supabase INSERT-Policy erstellt (Upload funktionierte nicht)
- [x] Material-Foto: Crop-Editor (crop_your_image, Rotation, fixCropRect, Dark Theme)
- [x] Material-Foto: Zwei-Datei Upload (HighRes + Preview 400px/60%)
- [x] Material-Foto: Lazy HighRes Loading (Preview auf Detailseite, HighRes on-demand)
- [x] Material-Foto: Lade-Spinner beim Foto-Ändern
- [x] Material-Liste: Subtitle DBO + Kategorie (ohne Einheit), einzeilig
- [x] Material: bestand_niedrig Fix (< statt <=) — Bestand = Mindest kein Warnsignal mehr
- [x] Material: Foto-Spinner beim Ändern bestehender Fotos
- [x] Material: "Auf Optimal auffüllen" Button im Bestand-Dialog
- [x] Material-Liste: Sortierung nach DBO-Nummer
- [x] Material: Stück pro Packung Feld (bei Einheit „Packung")
- [x] Materialbestellung komplett (PDF, Mail, Vormerken, Sektionen, Bestellhistorie, Edge Function)
- [x] Material-Suche: durchsucht auch Beschreibung, Notizen, Lieferant
- [x] Material +/- Buttons in Detailscreen (statt Liste), Bestellliste-Screen entfernt
- [x] Materialbestellung: Dropdown-Auswahl, Reihenfolge/Sortierung verbessert
- [x] Manual-PDF Upload/Anzeige für Material (nur relevante Kategorien)
- [x] Material-Auswahl speichert auch ohne Dropdown-Klick (Montage/Störung/Eigenauftrag)
- [x] Material-Bestand aktualisiert nach Service-Speicherung (Provider-Invalidierung)
- [x] Material-Filter zeigt nur Kategorien mit Einträgen

---

**Zuletzt aktualisiert**: 02.06.2026
