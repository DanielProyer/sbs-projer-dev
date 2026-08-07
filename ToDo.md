# ToDo-Liste — Daniel Projer (SBS Projer App)

**Stand:** 06.08.2026 · **Live:** v0.72.2

---

## 🟢 ERLEDIGT 07.08. (v0.72.10): camt-Antworten Daniel umgesetzt + Zahlernamen-Lernen aus Historie

1. **Sammelzahler bestätigt + erweitert:** Weisse Arena → IKIGAI, Il Pub, Indy Bar, Signina, Legna, Nagens; **Goodfast Hotels AG → Grischa, Golden Dragon, Jodys, Bräma** (alle Davos). `goodfast` neu in `kSammelzahler` (nie auto, +Test).
2. **Stammdaten Davos-Vierergruppe:** Rechnungsadresse aus Grischa (Goodfast Hotels AG, invoice@hotelgrischa.com) auf Golden Dragon/Jodys/Bräma übernommen (mit Objektnamen), **alle 4 auf `rechnung_mail`** (waren rechnung_tresen).
3. **Franchise-Vorlage umgestellt (OK Daniel):** «Heineken-Franchise (Aufwand direkt, VSt 1170)» = 6301/1020, MwSt 8.1 % → der Nachhol-Import bucht die Franchise-Belastungen richtig inkl. 282.69 VSt/Monat; Regel-Match verengt auf `heineken switzerland`.
4. **Zahlernamen aus Zahlungshistorie gelernt** (Auftrag Daniel: letzte 4 Zahlungen, alle gleich → auto): 1'606 Gutschriften ab 2024 aus der Voll-camt gegen bezahlte Rechnungen gematcht (nur eindeutige Datum+Betrag-Paare). **57 Aliase automatisch gesetzt**; 53 Nachfragen (32 nur-eine-Zahlung, 11 verschiedene Namen, 10 Konflikte) → Listen in `docs/camt-zahlernamen-lernen-2026-08-07.md`. ⚠️ Dabei gefunden: Alias «hotel alpenblick weggis ag» liegt auf Alpenblick [Arosa] — vermutlich am 15.07. falsch gelernt. Arbeitstabellen/Rollback: Schema `tmp_zahlername`.

---

## 🟢 ERLEDIGT 07.08. (v0.72.9): camt-Import-Gesamtprüfung — Härtung + Verbesserungsplan

**Vollbericht:** `docs/camt-import-pruefung-2026-08-07.md` (Code-Kartierung des ganzen Subsystems + Datenbestand + Analyse der echten camt-Datei 12.03.–20.06.).

**Sofort behoben (v0.72.9, live):**
1. **Ausgabe-Booker löst Geschäftsfall-Vorlagen auf** (`kontenFuerCamt` via Resolver, Zahlungsweg 'bank') — Phase-0a-Vorlagen (Bussen 6280, Fahrbewilligung 6275) hatten Soll/Haben NULL → Buchung crashte; betroffen genau die 2 offenen Ausgabe-Prüflistenfälle (Flims 40.00, Luzern 20.00).
2. **Offene Prüflisten-Einträge blockieren den Re-Import nicht mehr** (nur erledigt/ignoriert blockiert); Buchung eines Vorschlags räumt den Prüflisten-Eintrag ab → die 2 festgesteckten **Heineken-Gutschriften (7'104.98/5'794.81)** werden beim Nachhol-Import zu buchbaren Vorschlägen (Feb/März-Monatsrechnungen existieren jetzt).
3. **Sammelzahler (Davos Klosters, Weisse Arena) nie auto** — auch nicht via gelerntem Alias (Weisse Arena→IKIGAI wäre scharf gewesen); Treffer bleibt manueller Vorschlag. Zentrale Liste `services/camt/sammelzahler.dart`.
4. **Archiv-Kopie erst nach erfolgreicher Verarbeitung** (vorher blockierte ein Fehlversuch via Duplikatprüfung jeden Retry) + **verständliche Parser-Datumsfehler**.
5. **Dateien-Archiv bereinigt:** 11 Duplikatzeilen weg, 2 saubere Einträge (damit ist auch ToDo-Punkt (10) «8 von 9 Duplikate» erledigt). 976 Tests grün.

**Fragen an Daniel (im Bericht, Abschnitt B):** (1) Zahlt Weisse Arena nur für IKIGAI? (2) Goodfast Hotels AG = welcher Betrieb? (3) **Franchise-Regel umstellen auf 6301 + VSt 1170/8.1 %** statt Kreditor 2000 ohne VSt (sonst verschenkt der Nachhol-Import 282.69 VSt/Monat) — Empfehlung ja, hängt mit Fahrplan-Schritt 4 zusammen.

**Geplant (Bericht Abschnitt C):** Regel-Politur (heineken→heineken switzerland, Prio-Feld im Dialog, 11 Alt-Vorlagen), RechnungMatcher-Grenzen sichtbar machen (take(20)/max 4 scheitern stumm), IBAN-Norm + Bereichs-Keywords vereinheitlichen, toten Code raus (`camt_import_service.dart`, `run()`, tote Felder), Tests für HeinekenMatcher/verbuche(), Dateien-Löschen im UI.

---

## 🟢 ERLEDIGT 07.08. (v0.72.8): Fahrplan Schritt 3 (Code-Teil) — die beiden camt-Fixes

- **Stichtag-Off-by-One behoben:** `CamtStichtag.istAutomatisierbar` nutzt `isAfter` statt `!isBefore` — der 11.03.2026 (letzter Excel-Banktag, SVA 5'962.20 + Kehricht 153.00 bereits gebucht) wird nicht mehr eingeschlossen; camt beginnt am 12.03. Schaden war keiner entstanden (bis heute 0 camt-TX gebucht). Import-Tab-Hinweistext angepasst; Tests auf Soll-Verhalten umgestellt (TDD, inkl. `camt_parser_test`).
- **Ausgabe-Booker richtungsbewusst (B8):** Neue reine Funktion `ausgabeBuchungsFelder` (3 Tests): Belastung = Konten wie Vorlage mit MwSt-Split über `mwst_konto`; **Gutschrift** (z. B. Prämien-Rückerstattung auf einer Ausgabe-Regel) = **Konten getauscht** (Bank im Soll), brutto **ohne** MwSt-Split (der Vorsteuer-Split ist in einer Zeile nicht invertierbar — SaldoExpansion wählt den Zweig nach Konto-Klasse) + Notiz «GUTSCHRIFT auf Ausgabe-Regel — MwSt manuell prüfen».
- 972 Tests grün, live v0.72.8. **Damit ist der Nachhol-Import entminte Zone — es fehlt nur noch die frische GKB-camt-Datei (Daniel: E-Banking, Export ab 15.07.2026 bis heute; ab 21.06. fehlen Rohdaten, Überlappung ist dank txKey-Dedup unkritisch).**

---

## 🟢 ERLEDIGT 07.08. (v0.72.7): Fahrplan Schritt 2b — MwSt-Doppelbuchung behoben (B1)

- **Code-Fix (v0.72.7, live):** Alle 4 Trennbuchungs-Blöcke ersatzlos gestrichen — `reinigung_buchung_service` (MwSt 3400/2200), `heineken_buchung_service` (MwSt 3400/2200), `spesen_import_service` (Vorsteuer 1171/Aufwand), `kreditor_buchung.zeile2` (rein, Test zuerst angepasst). Die Bruttomethode läuft allein über `mwst_konto` + SaldoExpansion — wie bei allen Vorlagen und der Excel-Historik. 969 Tests grün.
- **Datenbereinigung (Entscheid Daniel: Migration mit Snapshot):** **977 Zeilen gelöscht** — 898 USt-Trennbuchungen 3400/2200 (CHF 10'219.98, davon 3 erst nach dem Bericht entstanden: der Fehler lief bis zum Deploy weiter) + 79 Spesen-Vorsteuer-Zeilen (CHF 184.26). Snapshot: `snapshot_mwst_trennbuchungen.geloescht` (Rollback = INSERT zurück), Skript `Datenbank/wartung/bereinigung_mwst_trennbuchungen_2026_08_07.sql`. Beleg-Verknüpfungen der Spesen-Zeilen via CASCADE mit; Dateien werden Waisen («Speicher aufräumen»).
- **Wirkung:** Ertrag 3400 **+10'219.98**, MwSt-Schuld 2200 **−10'219.98**, Vorsteuer 1171 −184.26, Aufwand +184.26. **Verifiziert:** 0 Muster-Reste, 0 Invarianten-Verletzungen, `view_mwst_abrechnung` unverändert (die View war immun — sie bleibt die massgebende MWST-Zahl). Kontensaldi/Bilanz/ER zeigen jetzt dieselben Werte wie die View.
- **Nächster Fahrplan-Schritt (3):** camt vorbereiten — Stichtag-Off-by-One (`camt_stichtag.dart`) + Richtungsfehler `camt_ausgabe_booker` fixen, frische GKB-Datei ab 15.07. besorgen, dann Nachhol-Import.

---

## 🟢 ERLEDIGT 07.08. (v0.72.6): Fahrplan Schritt 2a — Storno-Mechanik repariert (B6.1–B6.3)

- **Neue reine Logik** `services/buchhaltung/storno_logik.dart` (TDD, 7 Tests): Gegenbuchung datiert **aufs Original** (Datum + Geschäftsjahr aus dem Original-Datum, nicht «heute»), trägt **kein `mwst_konto`** mehr (Ausschluss-Modell: storniertes Original UND Gegenbuchung zählen in keiner Auswertung — wie Bilanz/ER seit v0.16.15); `stornieren()` nimmt **zugehörige MwSt-Trennbuchungen desselben Belegs/Tages mit** (Zahlungen nie); Gegenbuchungen selbst sind nicht stornierbar.
- **Ausschluss-Filter nachgezogen:** `getAllSaldi` (Kontensaldi/Audit/Debitoren) und `mwstQuartalDetailProvider` überspringen jetzt auch Gegenbuchungen (`zaehltFuerSaldo`); **5 Idempotenz-Guards** (Heineken Haupt+Zahlung, Zahlungsdifferenz 2×, Eingangsrechnung Stufe 1) prüfen `stornoVonId == null` — nach einem Storno kann der Beleg wieder gebucht werden.
- **Migration 166:** `view_mwst_abrechnung` schliesst `storno_von_id IS NOT NULL` aus (Härtung; App setzt mwst_konto bei Gegenbuchungen eh auf NULL). Verifiziert: 0 Gegenbuchungen im Bestand → alle View-/Saldo-Zahlen unverändert; 969 Tests grün.
- **Damit ist der Storni-Weg für die B1-Bereinigung frei.** Offen: Entscheid G4 (Storni vs. dokumentierte Migration) + B1-Code-Fix (4 Trennbuchungs-Blöcke streichen).

---

## 🟢 ERLEDIGT 07.08. (v0.72.5): Buchhaltungs-Fahrplan Schritt 1 — Heineken-Rundung (B2)

- **Code:** `heineken_buchung_service.dart` rundet das Brutto nicht mehr auf 5 Rappen — Heineken wird ungerundet fakturiert (Regel 15.07.). Neue reine Funktion `heinekenBuchungsBetraege` (`core/util/heineken_buchung_betraege.dart`, TDD, 3 Tests): Netto/Brutto exakt aus der Rechnung, MwSt = brutto − netto → Invariante `brutto = netto + mwst` gilt konstruktiv. 962 Tests grün, live v0.72.5.
- **Daten:** Die 3 betroffenen Hauptbuchungen 04–06/2026 aufs Rechnungsbrutto gesetzt (6288.60→6288.62 · 6198.25→6198.24 · 6594.95→6594.96); Skript inkl. Rollback-Werten: `Datenbank/wartung/korrektur_heineken_brutto_2026_08_07.sql`. **Verifiziert: 0 Invarianten-Verletzungen in der ganzen DB.** Damit ist auch der Debug-Assert-Crash weg und die −0.02-Bilanzdifferenz 2026 erklärt/behoben.
- **Nebeneffekt:** Buchungs-Brutto = Rechnungs-Brutto = Zahlungsbetrag → Heineken-Zahlungseingänge gleichen 1100 künftig rappengenau aus (B8-Rundungspunkt für Heineken miterledigt).
- **Nächster Schritt (2):** Storno-Mechanik reparieren (B6.1–B6.3), dann MwSt-Doppelbuchung (B1: 4 Code-Blöcke + 895+79 Zeilen bereinigen).

---

## 🟢 ERLEDIGT 07.08.: Original-Monatsrechnungen (Heineken) in den Storage geladen — 83 PDFs

**Befund (aus Projekt Heineken):** Die 83 historischen Heineken-Monatsrechnungen (05/2019–03/2026) wurden am 14.07.2026 als Daten-Backfill per SQL-Batch angelegt; ihre Storage-PDFs waren nur die 3-seitige Übersicht+Detail (~130–175 KB) — die Formularseiten (Rapporte) entstanden damals ausserhalb der App (Heineken-Excel-Vorlagen, von Hand angehängt) und fehlten komplett. Die App-Rechnungen ab 04/2026 waren korrekt.

**Erledigt:** Originale von der Festplatte (`00_Buchhaltung/Monatsrechnungen Heineken 2019-2026/`) in den Bucket `rechnung-pdfs` geladen. Ab 08/2023 lag das versendete Kombi-PDF vor (1:1 übernommen); 05/2019–07/2023 aus `00_Rechnung.pdf` + Einzel-Formularen in Kategorien-Reihenfolge (01_Störung…06_Gratisreinigung) zusammengeführt. **Verifiziert:** 83/83 DB-Bruttobetrag im PDF-Text gefunden, 3 Stichproben-Hashes nach Roundtrip identisch, Live-Rechnungen 04–06/2026 unangetastet. Upload über temporäre, token-geschützte Edge Function `temp-pdf-import` — danach durch 410-Stub ersetzt (kann in der Supabase-Konsole gelöscht werden).

> ✅ **Sperre eingebaut (v0.72.4, live 07.08.):** «PDF neu generieren» ist für Monatsrechnungen vor 04/2026 gesperrt (`darfHeinekenPdfNeuGenerieren` in `core/util/heineken_pdf_regenerierbar.dart`, +3 Tests). Menüpunkt zeigt ein Schloss, Tap erklärt die Sperre im Dialog. Hintergrund: Neu-Generieren würde das Original durch die 3-Seiten-Fassung ohne Formulare ersetzen (Excel-Backfill trägt die Formularfelder nicht). Quelle der Originale bleibt die Festplatte.

---

## 🟢 ERLEDIGT 07.08. (v0.72.3): Sicherheitsbefunde aus Projekt Heineken — Buckets privat

1. **Öffentliche Buckets geschlossen:** `material-fotos` (public seit 17.02.) und `raster-pdfs` (public seit 10.05. — enthielt den Serviceraster mit allen Kundennamen) auf privat gestellt (Migration `buckets_material_fotos_raster_pdfs_privat`). Vorher verifiziert: material-fotos nutzt nur signierte URLs + Owner-Policies; raster-pdfs hat authenticated-Policies, die Mail-Function lädt per Service-Role. Einzige `getPublicUrl`-Stelle der App (Raster-Download) auf `createSignedUrl` umgestellt. Praxistest: anonymer Abruf → HTTP 400. **Kein Bucket mehr public.**
2. **«Fehlende Sicherung Material»:** Die Material-/Lager-Tabellen selbst waren alle mit RLS+Policy gesichert — der Befund war der public material-fotos-Bucket (Punkt 1). Kein weiterer Handlungsbedarf.
3. Nebenbei geklärt: Versionsanzeige-Verwirrung (Browser 0.72.1 / App 0.71.0) = veraltete `kAppVersion` im 0.72.1-Bundle; v0.72.2 (Fix + Test) hing seit 06.08. in der GitHub-Actions-Störung, am 07.08. nachgeschoben; v0.72.3 direkt hinterher.

---

## 🔴 NEU 06.08.2026: Buchhaltungs-Gesamtprüfung — Vollbericht `docs/buchhaltungspruefung-2026-08-06.md`

Auftrag Daniel («gesamte Buchhaltung prüfen, muss alles stimmen»), Massstab = Recherchen aus `D:\Projekte\KMU Tool 2\02_Recherche\` (02 Buchhaltung, 07 MWST). Vier Opus-Agenten (MWST-Abrechnung, Code-Audit 20 Buchungspfade, Journal-Audit, Rechnungsstellung), schwerste Befunde einzeln verifiziert.

**✅ ePortal-Check 07.08. (Screenshot Daniel):** Q4/2025 Status «Eingereicht» — hart bestätigt. Offen nur noch **Q1/2026 + Q2/2026, beide «Zu erledigen» mit Frist Ende August** (Q1: 31.08.2026, Frist verlängert — Verzugszins-Valuta bleibt 30.05.; Q2: 30.08.2026). Zeitfenster passt zum Fahrplan: Schritte 2–4 bis ~20.08., dann Q1+Q2 zusammen einreichen + Berichtigung.

**✅ Berichtigung 2025 FINAL (07.08. abends, aus den Portal-PDFs Q2–Q4/2025): CHF 1'508.62** — Netto-statt-Brutto in allen vier Quartalen mathematisch belegt (deklarierte Steuer = Ziff. 200 × 8.1/108.1); Zerlegung: 1'200.79 zu wenig Steuer + 307.83 zu viel Vorsteuer. Vorlage mit Deklarations-Tabelle: `docs/mwst-q4-2025-nachreichung.md`. ⚠️ Prüfpunkt Daniel: deklarierte VSt lag 307.83 über dem Journal — falls es dafür Belege gibt (Excel-Hauptbuch), wird die Berichtigung kleiner.

**Das Dringendste (Stand 06.08. spätabends, korrigiert):** ~~Q4/2025 überfällig~~ — **Q4/2025 wohl bereits eingereicht+bezahlt** (camt-Zahlung 18.05.2026, 1'735.04, Referenz K8QT0042025; lag im toten Winkel des Bankstopps). **Q1/2026 bleibt überfällig**, Q2/2026-Frist **31.08.2026**. Rest-Korrektur 2025 via Berichtigungsabrechnung: **1'508.62** (Jahres-Soll 11'404.27 − bezahlt 9'895.65) — rappengenau nach Daniels ePortal-Check am 07.08. (Q4/Q2/Q3-PDFs laden; Erinnerung 19:00 eingerichtet). Vorlage: `docs/mwst-q4-2025-nachreichung.md`. Eine heute erstellte Q1/2026-Abrechnung wäre **+159 % zu hoch** (Doppelbuchung + fehlende Vorsteuer) — erst Fahrplan-Schritte 1–4.

**Neue Kernbefunde (alle verifiziert):** Lohn-Verbindlichkeitskonten seit 2019 um eine Position verschoben (2271=AHV, 2272=BVG, 2273=UVG, 2270 leer); AHV-Abzug 8 % vom Netto statt 6.4 % vom Brutto; NBU seit Dez 2024 = 0.00; FAK nie als Aufwand; Heineken-Franchise 2026 komplett ungebucht (27'920 + 2'261 VSt); Storno-Mechanik dreifach defekt (mwst_konto, Datum=heute, nur 1 Zeile) — latent, vor Bereinigung reparieren; Heineken-Rundung verletzt brutto=netto+mwst (Debug-assert!); camt-Ausgabenbucher ignoriert Buchungsrichtung (vor Nachhol-Import fixen!); drei widersprüchliche MWST-Auswertungen (View ist die richtige); Idempotenz-Lücken (Lohnlauf!), Hard-Deletes, Rundungs-Wildwuchs, Trigger-Leiche. **Rechnungsstellung dagegen weitgehend sauber** (Art. 26 erfüllt, QR Typ S — Frist 30.09.2026 unkritisch; 2 kleine PDF-Fixes). SSS 4.6 % wäre ~1'000–1'600/Jahr günstiger — erst nach Bereinigung entscheiden.

**Fahrplan mit Reihenfolge** (Rundung → Doppelbuchung → camt-Fixes → Nachhol-Import → Nachbuchungen → MWST einreichen → Lohnblock → Härtung) und **12 Entscheidungsfragen** im Bericht, Abschnitt F/G.

---

## 🔴 NEU 05.08.2026: Datenprüfung — Vollbericht `docs/datenpruefung-2026-08-05.md`

Sechs Bereiche geprüft (Stammdaten, Anlagen/Reinigungen, Rechnungen, Buchhaltung, Bankauszug, Saison/Touren), nur lesend. Die schwersten Funde am Code und an den Buchungen gegengeprüft. **Übersicht als Artifact veröffentlicht.**

**Zwei Fehler laufen heute noch weiter — zuerst anfassen:**

1. **MwSt doppelt gebucht — CHF 10'172.28, 890 Buchungen seit 01.12.2025, jede neue Rechnung betroffen.** Die Hauptbuchung setzt `mwst_konto=2200` (→ `saldo_expansion.dart` teilt bereits auf), zusätzlich erzeugt `reinigung_buchung_service.dart:125-141` bzw. `heineken_buchung_service.dart:60-75` eine zweite MwSt-Buchung 3400/2200. Folge: Ertrag 10'172.28 zu tief, MwSt-Schuld ebenso zu hoch (2025: 1'343.91 · 2026: 8'828.37). Bilanz + Erfolgsrechnung betroffen. **Entscheid Daniel:** rückwirkend stornieren oder Korrekturbuchung — hängt daran, ob Q4/2025 + Q1/2026 schon abgerechnet sind.
2. **camt-Stichtag Off-by-One — Risiko CHF 6'283.85.** `camt_stichtag.dart:6` `!isBefore(stichtag)` schliesst den 11.03.2026 EIN, der ist aber schon aus Excel gebucht (Beleg: SVA 5'962.20 + Kehricht 153.00 = exakt die camt-Belastung 6'115.20). Fix `isAfter(stichtag)`. **Vor dem nächsten Import.**

**Geldseite steht still:** Konto 1020 seit 11.03.2026 ohne jede Buchung (147 Tage), ≥ CHF 99'470 unverbucht; keine Zahlungszuordnung mehr seit 11.03.; Franchisegebühr Heineken 2026 CHF 0.00 (Vorjahr 45'272.40), Löhne seit 04.03. gestoppt → Ergebnis 2026 erheblich zu hoch. **Gute Nachricht:** Bankabstimmung bis 11.03. exakt null Differenz über 2'668 Transaktionen.

**Forderungen:** CHF 173'123 offen. Davon **342 Live-Rechnungen (CHF 34'478) nie zugestellt** — 85 per Mail, Ø 146 Tage alt (Calanda Chur, Stadtcafé Sursee, Posthotel Valbella). Mahnwesen komplett ungenutzt, 140 Rechnungen (CHF 12'865) nach Art. 128 OR verjährt.

**Blue Cinema: Verdacht widerlegt** — die Zentrale ist längst erfasst; Ursache ist, dass keine der 38 Rechnungen je versendet wurde. Der ToDo-Eintrag weiter unten ist damit erledigt/umgedeutet.

**Behoben während der Prüfung:** RLS auf den beiden Wartungs-Snapshots (waren über die API lesbar), Migration `rls_auf_wartungs_snapshots`.

Vollständige Liste inkl. Stammdaten-Befunden (5 Betriebe bedient aber nicht als Kunde geführt, 66 Reinigungen ohne Anlage, 125 überfällige Anlagen teils wegen falschem Rhythmus, Rovanada fehlende 2. Anlage) und 10 Entscheidungsfragen: siehe Bericht.

---

## 🟢 ERLEDIGT 30.07.: Live-Tagesplan v0.56.0 — heutiger Plan zeigt gemessene Ist-Zeiten

**Wunsch Daniel:** «kannst du mit den Daten (Stempel bei allen Ereignissen) den Tourenplan (vom aktuellen Tag) interaktiv halten … alle erledigten Arbeiten/Wege direkt mit den gemessenen Zeiten darstellen und die Tour entsprechend anpassen»

- **`berechneZeitplanMitIst`** (`zeitplan.dart`, +8 Tests): Erledigte Blöcke laufen mit ihren gemessenen Zeiten in Ist-Reihenfolge; Lücken zwischen Ist-Ereignissen = gemessene Fahrt; ab 3 min zwischen letztem Ist-Ende und jetzt entsteht ein **frei-Fenster**; der Rest-Plan rechnet ab max(jetzt, letztes Ist-Ende) weiter.
- **Erledigt-Erkennung** (nur heute): Reinigungs-Besuch = heute abgeschlossene Reinigung desselben Betriebs (echte uhrzeit_start/ende); Störung/Montage = Wegpunkt-Stempel (Ende = Stempelzeit, Start = Stempel minus geplante Dauer — Annahme, siehe OFFEN).
- **UI:** erledigte Blöcke grün mit Haken + «X min gemessen», gemessene Fahrten grün, gelbe FreiZeile, **rote Jetzt-Linie** zwischen Ist und Plan; Minutentakt-Timer rückt Linie + Rest-Plan vor und holt frische Wegpunkte. Andere Tage unverändert.
- 702 Tests grün, deployed (main `0af6e98`, gh-pages `aa835c2`).

---

## 🟢 ERLEDIGT 30.07.: Arbeitstag am Startbildschirm + Wegpunkte + Excel-Zeiten-Nachtrag (v0.55.1–v0.55.4)

- **Arbeitstag-Karte auf dem Startbildschirm** (Migrationen 153/154): «Jetzt starten» erfasst Zeit + **km-Stand + GPS** (Start variiert: Domat/Ems oder Chur), «Feierabend» erfasst Ende + End-km + End-GPS → Tages-km ohne Privatfahrten. Startort-Fallback (Via Rezia 8) in Geschäftseinstellungen.
- **Wegpunkte** (Migration 155): Zeit+GPS+Kontext-Stempel bei Reinigungs-Abschluss, Störung, Montage, Arbeitsbeginn, Feierabend — ereignisbasiert statt 5-min-GPS (Web-App drosselt Hintergrund-Tabs, Bildschirm aus = kein JS). Datengrundlage für spätere Routen-Optimierung.
- **Fahrzeit-Lern-Guard:** Liegt ein Störungs-/Montage-Stempel zwischen zwei Reinigungen, wird die Lücke NICHT als Fahrzeit gelernt (im Zweifel nicht lernen).
- **Zeitauswahl überall 24h** ohne AM/PM (`zeit_auswahl.dart`, alle 5 showTimePicker-Stellen).
- **Excel-Zeiten-Nachtrag** (Sheet Reinigung, Spalten Dauer/Zeit Beginn/Zeit Ende): **7'636 Reinigungen mit echten Uhrzeiten** (vorher 895); 842 im Excel ohne Zeit («-»), 145 ohne Match. fahrzeiten-Beobachtungen komplett neu: **3'045 Paare** aus 5'616 Übergängen (vorher 216, teils durch nacherfasste 1-Minüter vergiftet). Heuristik-Faktor 2.2 → **2.5** (Median 2.53 über 2'434 Paare). Rollback: `Datenbank/wartung/zeiten_nachtrag_2026_07_30_rollback.sql`.

---

## 🟢 ERLEDIGT 28.07. (abends): Zusatzanlagen zusammengeführt — 198 Doppel-Reinigungen entfernt

**Gemeldet von Daniel:** Lindemann's Over Time, 31.07.2025 — die App zeigt zwei Reinigungen, es war aber **eine Reinigung an zwei Anlagen**. Im Excel bekommt jede weitere Anlage eine eigene Zeile mit Rechnungsart „Zusätzliche Anlage" und Total 0.00.

**Ursache — wieder der Import vom 19.06.2026:** 222 dieser Zusatzzeilen wurden als eigenständige Reinigung angelegt (die übrigen 1'307 korrekterweise nicht) und bekamen über den Preis-Trigger sogar einen Betrag — **220 Stück mit zusammen CHF 16'571.63**, obwohl im Excel 0.00 steht.

**Bereinigung** (`zusatzanlagen_zusammenfuehren_2026_07_28.sql`): Die Anlage der Zusatzzeile wandert in `anlage_ids` der Hauptreinigung (so bildet die App mehrere Anlagen ab), danach wird die Zusatzzeile gelöscht. Preis-Trigger dabei ausgesetzt, damit die korrigierten Beträge stehen bleiben.

| | |
|---|---|
| Zusatzzeilen entfernt | **198** |
| dabei beseitigter Scheinumsatz | **CHF 14'789.84** |
| Hauptreinigungen um Anlagen ergänzt | **158** |
| Kontrollfall Lindemann's 31.07. | eine Reinigung, 152.40, Anlagen „Try Out + Overtime EG" ✓ |

**Die 24 Restfälle — von Daniel geklärt und erledigt** (`zusatzanlagen_rest_2026_07_28.sql`):

> Regel Daniel: *„Wenn im Excel Zusatzanlage steht, ist das massgebend für die Rechnung — die Reinigung soll aber bei beiden Anlagen/Betrieben ersichtlich sein."* Hintergrund: zwei Betriebe in einem Haus, früher zwei Rechnungen, auf Kundenwunsch zusammengelegt.

- **Blue Cinema Chur (5×)**: Die Hauptanlage `_01` war ausser Betrieb, die Rechnung hängt an `_02` (Rechnung Mail, 184.85) — die `_03`-Zusatzanlage wurde dorthin zusammengeführt und entfernt.
- **18 Zeilen auf Preis 0.00 gesetzt** und bewusst behalten, damit die Reinigung beim Betrieb sichtbar bleibt: *Vieri Bar Cham* (8×), *Strela Davos* (4×), *Frosch Sportclub* (2×), *Rössli Cham* (1×) und *Robinson Club Arosa* (3× vom 26.02.2025 — eigene Arbeitstage, Hauptreinigung war am 24.02.).
- **1 Ausnahme**: *Jamies Chur* 17.06.2019 behält 215.40 — dort existiert eine echte Rechnung, die Excel-Zeile ist einer der vier bekannten Doppeleinträge.

**Kontrolle nach allen Bereinigungen:** Netto stimmt weiterhin bei allen Reinigungen mit dem Excel (0 Abweichungen), keine verwaisten Datensätze, Debitoren 176'228.04 und 1'434 offene Rechnungen unverändert.

Rückgängig: `rollback_zusatzanlagen_2026_07_28.sql` (Snapshots `snapshot_zusatzanlagen.geloescht`, `.haupt_vorher`, `.rest_vorher`).

---

## 🟢 ERLEDIGT 28.07. (abends): Reinigungspreise korrigiert — Hahn-Zuschläge fehlten seit dem Import

**Gemeldet von Daniel:** Lindemann's Over Time, Reinigung 21.11.2025 zeigt CHF 74.60, das Protokoll aber 113.50 — der Betrieb hat 7 Hähne, nie weniger als 3.

**Ursache — nicht die Arbeiten von heute:** Der Historik-Import vom **19.06.2026** hat die Hahn-Spalten des Excel nie übernommen. Alle 7'786 importierten Reinigungen 2019–2025 standen auf `anzahl_haehne = 0` und `preis_zusatz_haehne = 0.00`. Für 2019–2024 wurde der Betrag trotzdem aus dem Excel übernommen und war korrekt; für **2025 wurde er aus dem Grundtarif neu gerechnet** — dort fehlten die Zuschläge (858 Reinigungen, CHF 8'542.37 zu niedrig). Beleg gegen eine Verursachung durch die heutigen Arbeiten: `updated_at` stand auf 19.06., und 786 der 858 wurden heute überhaupt nicht angefasst.

**Korrektur** (`korrektur_reinigungspreise_2026_07_28.sql`): Brutto **und** Netto direkt aus dem Excel (Spalten „Total mit/ohne MwSt"), Hahn-Mengen aus „Zusätzlicher Hahn / …Fremd / …2ter Standort", MwSt **7.7 % bis 31.12.2023 und 8.1 % ab 01.01.2024** (Hinweis Daniel). Der Trigger `reinigung_preis_berechnung` rechnet daraus den Preis konsistent neu.

| | |
|---|---|
| Beträge korrigiert | **627** |
| Hahn-Mengen gesetzt | **3'291** (5'637 eigene, 437 fremde, 464 anderer Standort) |
| Stimmt jetzt mit Excel | **7'084 von 7'116** |
| Kontrollfall Lindemann's 21.11. | 69.00 + 36.00 = 105.00 netto + 8.50 = **113.50** ✓ |

**Rechnungen und Buchhaltung unberührt:** 4'438 von 4'439 Rechnungen mit Reinigungsbezug tragen exakt den Excel-Betrag (der eine Ausreisser ist der bekannte Jamies-Doppeleintrag im Excel), keine neue Position, keine neue Buchung, Bank 3'322.26 und Debitoren 176'228.04 unverändert.

**Restfälle abgearbeitet — Netto stimmt jetzt bei ALLEN 7'116 Reinigungen mit dem Excel überein:**

- **3 Reinigungen mit zwei Grundtarifen** (Holländer Landquart 2×, Sarain 1×: Orion 92 + Fremd 92 bzw. Bier 69 + Fremd 92): Excel-Betrag hart gesetzt, dafür den Preis-Trigger kurz ausgesetzt (CHF 273.50). Künftig schreibt Daniel dafür **zwei Rechnungen** — kam zuletzt nur bei Surselva Chur (Wein + Bier) vor, dort ist Wein stillgelegt.
- **29 Bruttodifferenzen, zusammen CHF 2.60** — bewusst **nicht** angeglichen: Dort rundet die App korrekt auf 5 Rappen (146.00 netto → 157.85), das Excel weicht um Rappen ab oder ist fehlerhaft (69.00 netto → 77.60 statt 74.60).
- **Orion-Grundtarif** war kein Fehler: In der Preisliste stehen bereits 92.00; die betroffenen Reinigungen tragen den richtigen `service_typ`.

**Wichtig zum Preis-Trigger** (`reinigung_preis_berechnung`): Er rechnet Netto/MwSt/Brutto bei **jedem** Update neu aus Preisliste + `service_typ` + Hahn-Mengen. Eigene Beträge werden immer überschrieben — Korrekturen müssen daher über die Mengen laufen, nicht über die Beträge.

**Zur Preisliste:** Es existiert nur **eine** Preisliste, gültig ab 01.01.2025 (Bier 69 / Orion 92 / Fremd 92, Zuschläge 18/18/23/30, MwSt 8.1) — und die **doppelt** (identische Werte, unkritisch). Für Reinigungen vor 2025 findet der Trigger keine gültige Liste und rechnet gar nicht; deshalb blieben die Beträge 2019–2024 unverändert korrekt.

**Historische Preislisten werden NICHT nachgetragen** (Entscheid Daniel 28.07.2026: „wenn die Reinigungen jetzt stimmen, brauchen wir die alten Preise nicht"). Das ist gefahrlos, weil der Trigger ohne gültige Liste unverändert zurückgibt — eine Altreinigung behält ihren Betrag auch beim Speichern.

> ⚠️ **Daraus folgt eine Regel:** Das `gueltig_ab` der bestehenden Preisliste **niemals nach hinten verschieben** (z. B. auf 2019). Sonst würde jede nachträglich gespeicherte Altreinigung mit den heutigen Tarifen und 8.1 % neu gerechnet — die eben korrigierten Beträge wären wieder falsch. Neue Tarife immer als **zusätzliche** Liste mit eigenem `gueltig_ab` anlegen.

Rückgängig: `rollback_reinigungspreise_2026_07_28.sql` (Snapshot `snapshot_reinigungspreise`).

---

## 🟢 ERLEDIGT 28.07.: Schlussprüfung aller Datenarbeiten — gegen Excel und intern

**Gegen das Excel (Sheet Reinigung, 10'080 Zeilen):**

| Prüfung | Ergebnis |
|---|---|
| Excel ↔ DB über `extern_id` | 7'786 in der DB, **0 ohne Excel-Entsprechung** |
| Excel-Zeilen ohne DB-Reinigung | 1'307 — ausnahmslos „Zusätzliche Anlage" (Positionen, korrekt nie importiert) |
| Betriebszuordnung über `heineken_nr` | **6'509 bestätigt, 0 falsch** |
| Die 147 Zahlungen | 147/147 im Excel gefunden, **147/147 Datum identisch**, 0 fälschlich als Abschreibung |

**Buchhaltung unverändert:** Bank 3'322.26 · Debitoren 176'228.04 · Kasse 18'697.78 · 16'867 aktive Buchungen · 0 camt-Buchungen · 1'434 offen / 3'655 bezahlt.

**Konsistenz — neun Prüfungen, alle null:** keine verwaisten Reinigungen/Rechnungen/Anlagen/Störungen/Montagen/Positionen, keine Reinigung an fremder Anlage, keine doppelte QR-Referenz, kein Betrieb mit gleichem Name + Ort.

**Zwei Stammdatenfehler dabei gefunden und behoben** (`normalisierung_heineken_nr_2026_07_28.sql`):
1. `heineken_nr` ohne führende Null bei Piz Piz (`105`→`0105`) und Vereina (`511`→`0511`) — dadurch stieg die Bestätigungsquote um 35 Reinigungen.
2. Nummer **0723 war doppelt vergeben**: Sie gehört laut Excel zu Panorama [Schlierbach]; *Silvia Kaufmann's Schlagerbar [Oberkirch]* trug sie fälschlich und läuft korrekt unter **0725**.

**Bekannt und bewusst unangetastet:** Das Excel selbst hat vier doppelte Reinigungs-IDs (Lindemann's Over Time 03.11.2020, Jamies 17.06.2019, Frosch 14.01. und 18.02.2026) — Entscheid Daniel: keine Anpassung nötig.

---

## 🟢 ERLEDIGT 28.07.: Excel-Zahlungen zugeordnet — 147 Rechnungen auf bezahlt

Vor dem echten camt-Abgleich mussten die im Excel erfassten Einzahlungen in die App. Die Zuordnung stammt **nicht** aus einer Betragsrechnung, sondern direkt aus der Quelle: Sheet `Reinigung`, Spalte **Einzahlungsdatum** + **Einzahlungsbeleg** (Extraktor `Datenbank/import/extract_einzahlungen_reinigung.py`, Tabelle `import.einzahlung_excel`).

Befund für die 1'313 offenen Rechnungen bis 11.03.2026:

| Gruppe | Anzahl | Betrag | Aktion |
|---|---|---|---|
| laut Excel ebenfalls offen | 966 | — | zu Recht offen, nichts getan |
| im Excel als ABSCHREIBUNG markiert | 47 | — | **Daniel schreibt selbst in der App ab** |
| laut Excel bezahlt (App-Rechnungen) | **147** | **14'958.45** | auf bezahlt gesetzt, Datum aus Excel |

Alle 147 Zahlungen liegen zwischen 04.12.2025 und 11.03.2026 — nichts nach dem Stichtag, alles danach läuft über camt. Gegenprobe: 145 der 147 Zahlungsbelege existieren als Buchung; die zwei Abweichungen sind ein Rappen-Dreher in der Belegnummer (Stadtcafé) und eine Sammelzahlung über zwei Betriebe (Bolgen Plaza + Waldhuus, 272.45 unter Kürzel 0089). Bank 3'322.26 und Debitoren 176'228.04 unverändert — es entstanden keine Buchungen. Offene Rechnungen 1'581 → 1'434.

Rückgängig: `Datenbank/wartung/rollback_excel_zuordnung_2026_07_28.sql` (Snapshot `snapshot_excel_zuordnung`).

**Verworfen:** Ein erster Ansatz über Betragsbilanzen je Betrieb hätte 150 Rechnungen geschlossen — davon rund 100 zu Unrecht, weil er aus Betragsdifferenzen Zahlungen konstruierte, die es nie gab.

**Hintergrund Versandlücke:** Rechnungen der Art *Mail* und *Post* wurden über längere Zeiträume gar nicht gestellt, erst ab 31.12.2025 wieder regelmässig (inkl. Nachversand aus der App). Diese Altforderungen schreibt Daniel ab — eigener Fehler, kein Mahnfall.

---

## 🟢 ERLEDIGT 28.07.: Mischbetriebe entwirrt — 490 Reinigungen + 309 Rechnungen umgehängt

Beim Historik-Import waren gleichnamige Betriebe zu **einem** Datensatz verschmolzen (Match nur über den Namen statt Name + Ort). Die Historie hängt jetzt am richtigen Haus — zugeordnet über die Excel-Betriebsnummer (Stelle 4 der `extern_id`), Zuordnung von Daniel bestätigt.

**Umgehängt an bestehende Betriebe:** Alpina Schiers (0195) · Seven Alpina Klosters (0147) · Alte Post Davos (0092) · Calanda Chur (0026) · Hotel Central am See Weggis (0751) · Krone Igis (0137) · Obertor Parpan (0189) · Surselva Chur (0045, 108 Reinigungen!) · Café Restaurant Mühle Nottwil (0721) · Türmli Sempach (0732) · Villaggio Root (0749)

**Neu angelegt (Status geschlossen, Häuser bestehen nicht mehr):** Alpina Gitzihöll Triesenberg · Alte Post Maladers · Bistro Bahnhöfli Schiers · Bahnhöfli Küblis · Krone Cham · Rheinkrone Chur · Gasthaus Löwen Grossdietwil · Gasthaus Löwen Sins · Restaurant Eisenbahn Zell · Grill-Haus Hayoz Gettnau

**Sonderfälle:** *Bahnhöfli Haldenstein = Chur* (Fusion, nur Ortswechsel) — bleibt zusammen. *Stau Davos* war eine einmalige Reinigung an einer Fremdanlage, behält genau diesen einen Vorgang. *Alpina Breil/Brigels* (Heigenie, kein Kunde) ist leer, aber **nicht gelöscht** — dort hängen noch eine Störung und eine Montage vom 05.05.2026; auf `inaktiv` + kein Kunde gesetzt, die vier Bergkundenpauschalen gingen an Gitzihöll.

Skript `Datenbank/wartung/entwirren_mischbetriebe_2026_07_28.sql`, Rückgängig via `rollback_mischbetriebe_2026_07_28.sql` (Snapshot `snapshot_mischbetriebe`).

**Anlagenbezug nachgetragen (280 Reinigungen):** Die Excel-ID trägt den Anlagenindex an letzter Stelle (`2024_09_26_0195_01`). Eine Stichprobe über 93 bestehende Zuordnungen zeigte, dass der Index in 92 Fällen der Reihenfolge entspricht, in der die Anlagen angelegt wurden — danach zugeordnet. Keine einzige Reinigung zeigt mehr auf eine Anlage eines fremden Betriebs.

**Teil 2 (ebenfalls 28.07. erledigt): 16 Betriebe mit toter Fremdhistorie** — 218 Reinigungen und 147 Rechnungen umgehängt, 18 weitere erloschene Häuser als geschlossene Betriebe angelegt (Arena Klosters · Arena Bar 2 Flims · Mühle Davos · Edelweiss Chur/Triesenberg · Sport Klosters · Weisses Kreuz Cazis · Kulm Arosa · Kurhaus Lenzerheide · Merz Wiesental Chur · Parsenn Conters · Posthotel Churwalden · Rössli Steinhausen · Sonne Krummenau/Thusis/Klosters · Sonnenhalde Davos · Waldhaus Flims). Zwei Objekte gingen an bestehende Betriebe: Gemsli Mels (25×) und Rätia Filisur (2×).

**Halli Galli getrennt (Korrektur nach Daniels Hinweis):** *Halli Galli [Arosa]* ist der alte Standort (2019–08.2022, 16 Reinigungen, geschlossen, `heineken_nr` 0011), *Halli Galli + Los Bar [Arosa]* der heutige Betrieb ab 10.2022 (33 Reinigungen, 0616). *Arena Bar 2 [Flims]* bleibt eigener Betrieb, obwohl am selben Ort wie Arena Flims — im Excel getrennte Objekte.

### Kontrolle über `betriebe.heineken_nr` — drei Fehlzuordnungen gefunden und behoben

`betriebe.heineken_nr` trägt die **Excel-Betriebsnummer** und liefert damit eine unabhängige Prüfung jeder Zuordnung. Von den bestehenden Betrieben wurden 13 exakt bestätigt, **drei waren falsch** — dort hatte ich einen Betrieb neu angelegt, obwohl er unter anderem Namen längst existierte:

| Nr | falsch (neu angelegt) | richtig |
|---|---|---|
| 0146 | Sport [Klosters-Serneus] | **Hotel Sport [Klosters]** — 35 Reinigungen 2019–2026 |
| 0727 | Grill-Haus Hayoz [Gettnau] | **Blue Sushi Garden [Gettnau]** |
| 0730 | Gasthaus Löwen [Grossdietwil] | **Gasthof Löwen [Grossdietwil]** |

Die drei Duplikate sind entfernt, alle 27 neu angelegten Betriebe tragen jetzt ihre `heineken_nr`. Skript: `korrektur_heineken_nr_2026_07_28.sql`.

**Merke:** `saisonpause` ist **kein** gültiger Betriebsstatus — der CHECK erlaubt nur `aktiv`, `inaktiv`, `geschlossen`. Die Saison wird über die Saisondaten abgebildet.

---

## 🟢 ERLEDIGT 28.07.: 8 Betriebs-Dubletten aufgelöst (alter Excel-Name ↔ heutiger Name)

Die `heineken_nr`-Prüfung über alle 7'788 Historik-Reinigungen fand 127 Reinigungen, deren Betrieb eine andere Nummer trägt als die Excel-Zeile. Das sind **keine** Fehler des Entwirrens, sondern Betriebe, die **doppelt** in der App stehen: einmal unter dem alten Excel-Namen (dort hängt die Historie), einmal unter dem heutigen Namen (dort steht die Nummer).

| Nr | Historie hängt an | trägt die Nummer |
|---|---|---|
| 0113 | Center da sport e cultura [Disentis/Muster] · 48× | Center Fontauna [Disentis] |
| 0372 | WG Giovadin [Davos] · 20× | Giodavin [Davos Platz] |
| ~~0407~~ | ~~Traube [Dietwil] · 19×~~ | **✅ erledigt** — Daniel: zwei verschiedene Betriebe; die 19 Reinigungen 2021–2025 an **Traube [Mels]** umgehängt (hat jetzt 21, Zeitraum 08.2021–04.2026). Traube [Dietwil] (`heineken_nr` 0756) behält seine eine eigene Reinigung vom 24.04.2026. |
| 0183 | Gipfelbar Setz Nair [Obersaxen] · 12× | Sezner [Obersaxen Meierhof] |
| 0161 | Crap Sogn Gion [Laax] · 7× | Capalari [Laax] |
| 0082 | Vaillant Arena [Davos] · 2× | Eisstadion Davos [Davos] |
| 0788 | Tapas Bar [Bad Ragaz] · 1× | Paloma Vino & Tapas [Bad Ragaz] |

**Daniel bestätigt: alle sechs sind derselbe Betrieb unter anderem Namen** → zusammengeführt (Skript `zusammenfuehren_dubletten_2026_07_28.sql`). Umgehängt wurden **alle** Verweise, nicht nur Reinigungen (auch Störungen, Montagen, Rechnungen, Adressen); die Altdatensätze sind gelöscht.

| Nr | jetzt am Betrieb | Reinigungen | Zeitraum |
|---|---|---|---|
| 0113 | Center Fontauna [Disentis] | 54 | 07.2019–07.2026 |
| 0372 | Giodavin [Davos Platz] | 20 | 11.2019–11.2025 |
| 0183 | Sezner [Obersaxen Meierhof] | 12 | 02.2020–04.2025 |
| 0161 | Capalari [Laax] | 7 | 12.2019–06.2021 |
| 0082 | Eisstadion Davos | 3 | 10.2023–09.2025 |
| 0788 | Paloma Vino & Tapas [Bad Ragaz] | 3 | 10.2025–03.2026 |

**Schlusskontrolle über alle 7'786 Historik-Reinigungen:** 6'472 per `heineken_nr` bestätigt, **0 falsch zugeordnet**, 1'314 an Betrieben ohne hinterlegte Nummer (die erloschenen Häuser). Keine einzige Reinigung zeigt auf eine Anlage eines fremden Betriebs. Betriebe gesamt: 428.

Rückgängig: `rollback_dubletten_2026_07_28.sql` (Snapshot `snapshot_dubletten`; Störungen/Montagen müssten dort von Hand nachgezogen werden).

Skript `entwirren_mischbetriebe_teil2_2026_07_28.sql`, Rückgängig via `rollback_mischbetriebe_teil2_2026_07_28.sql`.

---

## 🟢 ERLEDIGT 28.07.: QR-Referenzen für 363 offene Rechnungen nachgetragen

**Warum der camt-Auto-Match bisher kaum griff:** Der deterministische SCOR-Abgleich ist als *Stufe 1* im Forderungsabgleich implementiert (vor Alias und Betragsvergleich) — aber bei den Rechnungen stand keine Referenz. Vor 2026: 1 von 4'591. Q1 2026: **0 von 275**. Q2: 12 von 192. Q3: **63 von 63**. Ab den Juli-Rechnungen greift er also voll.

**Rückwirkend hilft Nachtragen nichts** — auf dem versendeten Einzahlungsschein stand keine Referenz, also liefert die Bank auch keine. Wohl aber vorwärts: Jede künftige **Mahnung** und jeder **Nachversand** trägt sie jetzt, und solche Zahlungen matchen automatisch.

Bildungsregel wie im Repository (SCOR aus den Ziffern der Rechnungsnummer), nur für App-Nummern (`2026-04-0125`) — Historik-Nummern (`011_2019_05_02_0042_00006785`) ergäben eine 27-stellige Referenz, SCOR erlaubt höchstens 25 Zeichen. Alle 363 sind Mod-97-gültig und eindeutig, keine Kollision mit dem Bestand.

**Zur Kenntnis:** Die bereits vorhandenen 76 Referenzen stammen aus einem anderen Weg — dem QR-Zettel bei der Reinigung, gebildet aus *Reinigungsdatum + Betriebsnummer* (Rechnung 2026-07-1286 → `RF93 20260629 0030`), nicht aus der Rechnungsnummer.

Skripte: `Datenbank/wartung/anlagen_und_qr_nachtrag_2026_07_28.sql`, Rückgängig via `rollback_anlagen_und_qr_2026_07_28.sql`.

---

## 🔴 ERLEDIGT-VORLÄUFER (Analyse): 16 Betriebe mit vermischten Excel-Objekten

Beim Historik-Import sind gleichnamige Betriebe zu **einem** Datensatz verschmolzen — unterschieden werden müssten sie über Name **+ Ort**. Folge: Rechnungen und Zahlungen mehrerer Häuser hängen am selben Betrieb, was den camt-Abgleich verfälscht.

| DB-Betrieb | tatsächliche Excel-Objekte |
|---|---|
| Alpina [Breil/Brigels] | Alpina Klosters-Serneus (0147), Alpina Schiers (0195), Alpina Gitzihöll Triesenberg (0506) |
| Sonne [Neuenkirch] | Klosters (0153), Thusis (0211), Sonnenhalde Davos (0226), Krummenau (0503), Neuenkirch (0733) |
| Stau [Davos Platz] | Restaurant Türmli Sempach (0732), Villaggio Restaurant Root (0749) |
| Arena Bar [Flims Dorf] | Arena Flims (0242), Arena Bar 2 Flims (0371), Arena Klosters (0468) |
| Bahnhöfli [Chur] | Bahnhöfli Haldenstein (0136), Bistro Bahnhöfli Schiers (0612) |
| Kulm [Davos] | Kulm Arosa (0005), Kulm Davos (0109) |
| Kreuz [Inwil] | Weisses Kreuz Cazis (0022), Restaurant Kreuz Inwil (0748) |
| Frosch Sportclub [Davos Platz] | Sport Klosters (0146), Frosch Davos (0670) |
| Merz [Domat/Ems] | Merz Wiesental Chur (0042), Merz Domat/Ems (0116) |
| Rätia [Ilanz] | Rätia Ilanz (0138), Rätia Filisur (0285) |
| Waldhaus [Valbella] | Waldhaus Valbella (0214), Waldhaus Flims (0235) |
| Surselva, Central, Kurhaus Omstal, Löwen, Rössli | je zwei Objekte (teils echter Nummernwechsel) |

Die Zuordnung der 147 ist davon **nicht** betroffen — die 12 Fälle bei Mischbetrieben hatten je genau einen Excel-Treffer mit passendem Betrag.

---

## 🔴 OFFEN: Blue Cinema Chur — 37 offene Rechnungen, eine Zahlung

12/2022 bis 05/2026, rund CHF 7'500 offen, dazu genau **eine** Zahlung (05.02.2026, 184.85). Vermutlich laufen die Zahlungen über eine Zentrale unter anderem Namen und wurden im Excel nie diesem Objekt zugeordnet. Vor dem camt-Abgleich klären.

---

## 🟢 ERLEDIGT 28.07.: Spesen-Belege produktiv erfasst — 40 Belege, CHF 2'198.87
Alle offenen Spesenbelege 09.06.–27.07.2026 gescannt und gebucht (**keine Testdaten, bleiben stehen**). 110 Buchungszeilen, Vorsteuer CHF 146.98.

**Doppelbuchung gefunden und entfernt:** Der Beleg «Landi TopShop Chur (AGROLA)» vom 30.06. lag zweimal drin (2× CHF 7.69 + 2× Vorsteuer 0.58) — beide Sätze aus derselben Bilddatei im Abstand von 230 ms, also ein Doppeltipp auf «Buchen». Ursache in **v0.54.9** behoben: Der Knopf blieb während der Dubletten-Prüfung (DB-Abfrage) aktiv, der Riegel greift jetzt vor dem ersten `await`. Die zwei überzähligen Buchungen sind gelöscht; die beiden Bilddateien bleiben als Waisen liegen und verschwinden beim nächsten «Speicher aufräumen».

| Konto | Zeilen | Brutto |
|---|---|---|
| 6200 Fahrzeuge (Diesel) | 12 | 918.26 |
| 4004 Material/Werkzeug | 8 | 821.05 |
| 5820 Spesen (Verpflegung) | 35 | 401.45 |
| 6460 Entsorgung | 2 | 65.80 |

Zahlungswege: privat CHF 1'775.81 (47 Zeilen), Kasse CHF 430.75 (10). Keine Privatbezüge/2260 — es wurden keine Tabakwaren erfasst.

**Geprüft und sauber:** jede MwSt-Buchung hat ihre Vorsteuer-Gegenbuchung, jede Buchung einen Beleg, keine Nullbeträge, keine Zukunftsdaten, nur zulässige MwSt-Sätze, Bar-Rundung bei allen Kassenbelegen auf 5 Rappen aufgehend.

**Zwei ähnliche Paare (11.06. Landi Oberkirch, 21.07. Coop Domat-Ems) von Daniel gegen die Papierbelege geprüft: jeweils zwei verschiedene Belege, keine Dubletten.** Damit sind alle 40 Belege bestätigt.

**Ausrichtung der Belege:** v0.54.4 lässt die Drehung neu vom gelesenen Text bestimmen (`bild_drehung` aus der KI) statt vom EXIF-Tag der Kamera — das ist bei flach von oben fotografierten Belegen unzuverlässig. Bildverarbeitung selbst wurde per Test entlastet (Drehrichtung korrekt, kein EXIF-Rest, `beleg_drehrichtung_test.dart`). Die zuletzt gescannten Belege kamen alle sauber ausgerichtet. **3 quer liegende Belege** (2 davon gebucht) bleiben so — Entscheid Daniel: werden ohnehin nicht mehr angeschaut. Nachträgliches Drehen gibt es nicht.

---

## 🟢 ERLEDIGT 28.07.: Spesen-Beleg-Testlauf abgeschlossen + aufgeräumt
Daniel: «bin mit dem Testen durch, wurde alles richtig erkannt, super». Erkennung sitzt (v0.53.9 Kategorien Material/Berufskleider/Parkgebühren/Entsorgung, v0.53.10 Tabakwaren als Privatbezug 2260).
**Aufgeräumt:** 66 Testbuchungen (CHF 1'664.89) + 66 Beleg-Verknüpfungen gelöscht; die beiden Heineken-Buchungen der Juni-Rechnung blieben unberührt. Storage liess sich weder per SQL (Schutz-Trigger `storage.protect_delete`) noch per Supabase-CLI (`storage rm` meldet Erfolg, löscht nichts) aufräumen → **neue App-Funktion v0.53.11**. **Am 28.07. ausgeführt:** 215 von 217 Waisen (77.7 MB) gelöscht; verbleiben 2 Dateien aus der nachträglich entfernten Doppelbuchung, die beim nächsten Durchlauf mitgehen. Bucket jetzt 3'565 Dateien / 1'105 MB, alle einer Buchung zugeordnet.

---

## 🟢 NEU v0.53.11 — Einstellungen → «Speicher aufräumen»
Findet Beleg-Dateien im Storage, zu denen keine Buchung mehr existiert (entstehen beim Löschen von Buchungen). Migration 151: RPC `verwaiste_belege()` (SECURITY DEFINER, nur eigener Ordner, nur Dateien älter als 1 h → laufende Uploads sind geschützt). Löschen erfolgt über die Storage-API der App in 50er-Blöcken, mit Sicherheitsabfrage inkl. Anzahl und Grösse. **Bitte visuell prüfen** (lokal nicht testbar, Login nötig).

---

## 🟢 NEU v0.54.0 — Spesen-Scanner: Korrektur-Schritt, Beleg drehen, Dubletten-Warnung, Bar-Rundung
Alle vier Punkte umgesetzt (Entscheide Daniel 28.07.). **Bitte testen:**
1. **Korrektur-Schritt:** Geschäft, Datum (Kalender), Total sowie jede Position (Beschreibung, Betrag, MwSt-Satz, Konto) editierbar; Positionen löschen und neu hinzufügen. Weicht die Positionssumme vom Total ab, erscheint eine rote Zeile mit der Differenz — **buchen bleibt möglich** (Gutschein/Rabatt sind echte Fälle). Gebucht werden immer die Positionen.
2. **Beleg drehen:** Vorschau oben im Prüf-Schritt, Drehen links/rechts in 90°-Schritten. Wirkt auf die Datei, die im Storage landet; die erkannten Werte bleiben stehen (kein erneuter KI-Durchlauf).
3. **Dubletten-Warnung:** Vor dem Buchen Abgleich mit den Spesen-Buchungen desselben Datums (gleiches Geschäft + gleiche Summe, 5 Rappen Toleranz) → Dialog «Beleg schon gebucht?» mit «Abbrechen»/«Trotzdem buchen». Keine Sperre; schlägt die Prüfung technisch fehl, wird normal gebucht.
4. **Bar-Rundung korrigiert:** Nur noch das **Beleg-Total** wird auf 5 Rappen gerundet, die Differenz erhält die grösste Position (`verteileBarRundung`, TDD). Vorher wurde jede Position einzeln gerundet → Summe lief vom bezahlten Betrag weg (Coop Pronto bar: 106.55 statt 106.53).

Neue Dateien: `core/util/beleg_korrektur.dart` (Rundung/Differenz/Dubletten, 16 Tests), `services/spesen/beleg_bild_service.dart` (Drehen via `image`-Paket). 514 Tests grün. **Visueller Test steht aus** — Scanner braucht Kamera + Login, lokal nicht prüfbar.

5. *Kein Handlungsbedarf, geprüft 28.07.:* Kleine Rundungsposition mit falschem MwSt-Satz (z. B. 0.02 @ 2.6% auf einem reinen 8.1%-Diesel-Beleg) ist harmlos — die MWST-Abrechnung summiert `mwst_betrag` je `mwst_konto` ([004_views.sql:86](Datenbank/migrations/004_views.sql:86)), der `mwst_satz` geht auf der Vorsteuerseite gar nicht ein. Entgangene Vorsteuer: 0.0015 CHF. Gilt genauso für den umgekehrten Fall (Plastiksack 0.05 @ 8.1% auf einem sonst 2.6%-Beleg — dort ist der Satz sogar korrekt, die MwSt wird nur durch den Kleinbetrag zu 0.00). Auch kumuliert vernachlässigbar (~0.08 CHF/Quartal; ESTV-Abrechnung wird auf ganze Franken gerundet).

**Historie:** Vor v0.54.0 gab es keinerlei Dublettenprüfung — weder im Scanner noch im Import-Service noch in der DB (`buchungen` hat ausser dem PK keinen Unique-Index). Deshalb lag der Coop-Pronto-Beleg vom 18.07. im Testlauf 3× in den Daten.

**Testlauf-Aufräumen (danach):** Buchungen ab 26.07.2026 00:00 mit `notizen LIKE 'Spesen-Scanner Import%'` + Beleg-Verknüpfungen + Storage-Dateien löschen (vor dem Test existierten an diesem Tag keine Buchungen).

---

## 🟢 ERLEDIGT 26.07.: Juni-Monatsrechnung — Rapport-System-Fix + PDF neu generiert («passt jetzt»)
Der Störungsrapport kreuzte das falsche System an (Bug seit Bestehen der Rapporte, gefixt v0.53.2): Die B/D/K/H/O-Kreuze kamen aus den **Störungsbereichen** (1=Zapfhahn…5=Gas) statt aus `anlage_typ` — z. B. «Zapfkopf/Tank»→fälschlich Heigenie (Centro Trun), «Kühler»→David (Clubhotel), «Gas»→Orion (Stadtcafé). Die **Juni-Rechnung 2026-07-1316 ging am 22.07. mit falschen Rapporten raus.** Vorgehen: Heineken-Rechnung Juni öffnen → Menü → **«PDF neu generieren»** → PDF prüfen (Kreuze jetzt korrekt) → korrigiert nachsenden. Ältere Monate bei Bedarf gleich (Menüpunkt funktioniert für jede Monatsrechnung). Einzelrapport-Druck aus dem Störungs-Detail ist ebenfalls gefixt.

---

## 🟢 ABNAHME BESTANDEN 26.07. («passt») — Aufgaben-Erinnerungen v0.53.0
Paket AE-1..AE-6 live (Spec/Plan `docs/superpowers/…/2026-07-22-aufgaben-erinnerungen*`). Dashboard-Karte + Glocke unten links, bleiben sichtbar bis erledigt. **Checkliste:**
1. App laden (v0.53.0): Dashboard zeigt zuoberst «X Aufgaben offen» — erwartet: MWST Q2 2026 (Frist 31.08.), evtl. Mahnlauf, Saisondaten 15; Glocke unten links auf JEDER Seite.
2. Sheet öffnen (Karte oder Glocke): «Dorthin»-Links (MWST, Mahnwesen, Tourenplan) prüfen.
3. Snooze 1 Tag auf eine Aufgabe → verschwindet, Badge sinkt, morgen wieder da.
4. Eigene Aufgabe anlegen (Titel + Datum) → erscheint; abhaken → weg.
5. MWST-Screen: «Als abgerechnet markieren» → Aufgabe weg; «Markierung zurücknehmen» → wieder da.
6. Heineken-Erinnerung erscheint automatisch ab 01.08. («Monatsrechnung Juli erstellen»), verschwindet mit Erstellen/Versand.

**Bekannte Rest-MINORs (kosmetisch, aus Final-Review):** MWST-Screen-Button zeigt bei gesnooztem Quartal «Markierung zurücknehmen» (Klick = harmloser No-op); leerer Titel im Neue-Aufgabe-Dialog schliesst kommentarlos ohne Speichern.

---

## 🟢 ABNAHME BESTANDEN 22.07. («funktioniert») — Google-Kontakte-Sync + Contact Picker
**Nachfix v0.52.1:** Picker-Übernahme normalisiert Telefonnummern jetzt ins App-Format («079 123 45 67» → «+41 79 123 45 67», `telefonAusPicker`, TDD). **Migration 149 angewendet:** `kontakte.phone_contact_id`/`phone_last_synced_at` endgültig gedroppt. Ursprüngliche Checkliste (Referenz):
Paket GK-1..GK-8 live (Spec/Plan `docs/superpowers/…/2026-07-21-google-kontakte-sync*`). **Checkliste (Pixel 9, Browser):**
1. App neu laden (v0.52.0 im Forderungen-Titel) → Einstellungen → neue Karte **«Google Kontakte»** → **«Google-Verbindung erneuern»** → Google-Consent inkl. Kontakte-Freigabe bestätigen.
2. **«Jetzt syncen»** → SnackBar mit Zählern; danach in der Google-Kontakte-App prüfen: Label **«SBS App»** mit ~104 Kontakten + operativen Betrieben, Stichprobe Name/Firma/Nummer.
3. Kontakt in der App ändern → nach ~1 Min. in Google nachschauen (Auto-Sync, entprellt 5 s nach Speichern).
4. Test: Kontakt löschen → verschwindet in Google; Betrieb auf inaktiv → verschwindet; wieder aktiv → kommt zurück.
5. **Anruf-Test:** Betriebs-/Kontaktnummer anrufen lassen → Name erscheint auf dem Pixel.
6. Kontakt-Formular (auch Betrieb-Kontakt): Button **«Aus Handy-Kontakten»** (nur Chrome/Android sichtbar) → Felder vorbefüllt.

**Hinweise:** Alter nativer Handy-Sync (flutter_contacts) komplett entfernt (Entscheid Daniel 22.07., war im Web immer inaktiv). Migration 149 (Drop `kontakte.phone_contact_id/phone_last_synced_at`) folgt nach bestätigter Abnahme — Spalten sind aktuell noch da (harmlos). Visueller Check der neuen Einstellungs-Karte war lokal nur als Boot-Smoke möglich (CanvasKit-Preview-Limit) — bitte bei Schritt 1 auf Darstellung achten. Subagenten-Reviews liefen wegen Dispatcher-Ausfall teils als Selbst-Review (GK-1 extern reviewt; Churn-Bug in vergleichsKey beim Final-Selbst-Review gefunden + gefixt).

---

## 🟢 (GELÖST 16.07. — siehe „Ursache der 38 — GELÖST" oben) Archiv: Warum fehlten 38 Rechnungen?
**Historie der Fehlersuche, als Referenz behalten.** Hat mit der Rundung NICHTS zu tun (das war ein zweiter, eigener Fehler).

**Symptom:** 38 abgeschlossene Tresen-Reinigungen (26.06.–13.07., CHF 3'656.05) bekamen beim Abschluss keine Rechnung. Nur bei Tresen aufgefallen, weil dort Protokoll + QR direkt aus der Reinigung kommen und ohne Rechnung funktionieren — bei `rechnung_mail`/`rechnung_post` merkte Daniel es sofort und holte es manuell nach (deshalb sahen diese Kategorien „sauber" aus, waren es aber nicht).

**Was BEWIESEN ausgeschlossen ist:**
- **Sequenz-Kollision** (meine Diagnose vom 14.07. in `fbca510` — FALSCH): Zwischen 26.06. und 30.06. stieg `rechnungsnummer_seq` um genau 1, obwohl 8 Fälle ausfielen → es wurde gar kein Insert versucht. Die „verbrannten" Nummern 645→1002 stammen vom Excel-Import am 13.06.
- **Referenz-Kollision:** Keine der 38 Wunsch-Referenzen war belegt (geprüft).
- **`kIsWeb`/Android:** Daniel schliesst im Browser ab.
- **Cache/Service Worker:** Fehler trat auch im Inkognito auf.

**Beste verbliebene Spur:** Die Ausfälle beginnen exakt am **26.06.** — einen Tag nach dem SCOR-Deploy. Am 25.06. war zwischen **15:40 (v0.13.0 „TP-C QR-Referenz")** und **16:10 (v0.13.2 „QR-Referenz-Kollisions-Fix")** eine Fassung live, die bei Kollision eine `PostgrestException` warf statt es erneut zu versuchen (`d3f4fa1` zeigt den Diff). Damals stand die Buchung im SELBEN try-Block → beides fiel aus, was zum Befund passt (die 38 hatten weder Rechnung noch Buchung; letztere kam erst per Nachtrag am 14.07.).
**Widerspruch dazu:** Ein fehlgeschlagener Insert hätte eine Sequenznummer verbrannt — hat er nicht. Also passt auch diese Spur noch nicht lückenlos.

**WARUM es unsichtbar blieb — GEFUNDEN (15.07. abends):** Der Block hatte einen komplett stummen catch:
```dart
} catch (e) { debugPrint('Rechnungs-/Buchungserstellung fehlgeschlagen: $e'); }
```
Rechnung UND Buchung standen darin, `createFromReinigung` machte `rethrow` → beides fiel gemeinsam und spurlos aus. Seit `fbca510` (14.07.) gibt es eine rote SnackBar und getrennte try-Blöcke — eine SnackBar, die nach 12 Sek. verschwindet, hätte die 38 Fälle aber nicht verhindert. Deshalb die zugesagte Warnung (siehe unten).

**Weiter eingegrenzt (15.07. abends):**
- **Nicht Betriebs-inhärent:** 36 der 37 betroffenen Betriebe bekamen VOR dem 26.06. problemlos automatische Rechnungen.
- **Saubere Trennung ab 26.06.:** 37 Betriebe danach NIE wieder automatisch erfolgreich, 5 Betriebe durchgehend erfolgreich — **kein einziger gemischt**. Also kein Zufalls-/Netzwerkfehler, sondern ein deterministisches Merkmal.
- **Nicht der SCOR-Code:** `scor_referenz.dart` seit 26.06. unverändert; die Suffix-Retry-Schleife war am 26.06. bereits drin (Fix `d3f4fa1` kam am 25.06. um 16:09, also VOR dem ersten Ausfall). Damit ist auch die „kaputte Zwischenversion 15:40–16:10"-Spur entwertet.
- **Derselbe Code funktioniert heute:** Der Nachtrag hat alle 38 über `createFromReinigung` fehlerfrei verarbeitet.
- **Kein Insert wurde versucht** (Sequenz unberührt) → Abbruch vor dem Insert, ODER gar keine Ausnahme: `if (betrieb != null)` umschloss den ganzen Block, `betrieb == null` überspringt alles lautlos.
- **Nicht `betriebe.updated_at`:** trennt die Gruppen nicht.
- **Neue Spur:** Am 26.06. um 06:10 ging **v0.16.3 „Eingangsrechnungen (Scan→KI→Kreditoren-Buchung, TP-0..2)"** live — der Morgen des ersten Ausfalltags.

### Stand der Jagd (15.07. spätabends) — statische Analyse ERSCHÖPFT

**Der Fehler ist vermutlich NOCH AKTIV.** `fbca510` (14.07.) hat nur die try/catch-Struktur umgebaut — Betrieb-Laden und Bedingung sind unverändert, es wurde nichts repariert. Am 14.07. gab es schlicht **keine** Tresen-Reinigung, und seither gibt es genau **einen** Datenpunkt: Postresidenz am 15.07. (erfolgreich — wie Spescha/Hemingway damals auch). Bei 38:3 löst die nächste Tresen-Reinigung ihn mit hoher Wahrscheinlichkeit wieder aus.

**Weiter ausgeschlossen (15.07. spätabends):**
- **Kein anderer Abschluss-Weg:** `r.status='abgeschlossen'` wird NUR in `reinigung_form_screen.dart:427` gesetzt, an derselben `abschliessen`-Bedingung wie der Rechnungsblock.
- **Keine Datenunterschiede:** 38 Ausfälle vs. 3 Treffer sind in ALLEN Feldern identisch (preisliste_id, anlage_id, anlage_ids, service_art, service_typ, Unterschrift, Foto, Checkliste, hahn_temperaturen, ist_synced).
- **Nicht tageweise:** Am 30.06. fielen Lenzerhorn (07:51) und Grotto (09:31) aus, **Spescha (10:20) gelang** (Rechnung 336 ms später), Cafe Bar (12:12) fiel wieder aus. Gleicher Tag, gleicher Code → keine kaputte Sitzung, kein kaputter Deploy-Stand.
- **Alle Reinigungen gleich erfasst:** `uhrzeit_ende` = Minute von `created_at` → alle in einem Zug erfasst UND abgeschlossen, kein Draft-vs-Sofort-Unterschied.
- **Die drei Schritte vor dem Insert können NICHT werfen:** `_loadMwst` behält bei fehlender Preisliste den Default (kein `!`), `_buildPositionen` ist null-geguarded, der Nummernbau nutzt `?? '0000'`.

**Damit bleibt GENAU EIN Zweig übrig:**
```dart
final betrieb = _betrieb ?? await BetriebRepository.getByServerId(r.betriebId);
if (betrieb != null) { … }   // null -> weder Rechnung noch Buchung, lautlos
```
Das erklärt jede Beobachtung: kein Insert (Sequenz unberührt), keine Ausnahme, keine Meldung, und dass Rechnung UND Buchung gemeinsam fehlten. Warum `betrieb` null sein sollte (dreifach geladen: Provider synchron in `initState`, in `_loadReinigung`, async in `_loadPreisData`) ist offen.

**v0.48.4 macht diesen Zweig laut** (30 Sek. rote SnackBar + `debugPrint` mit `betriebId`, `_betrieb`, `widget.betriebId`).

### REPRODUKTION VERSUCHT — BEIDE MALE FEHLGESCHLAGEN (15.07. spätabends)
Zwei echte Test-Reinigungen bei Betrieben, die am 13.07. noch ausfielen. **Beide liefen sauber durch**, danach exakt auf Baseline zurückgerollt (Sequenz per `setval` auf 1290).

| Test | Betrieb | Ergebnis |
|---|---|---|
| Desktop-Browser | Espresso Bar Landquart | Rechnung 2026-07-1291 + 2 Buchungen ✅ |
| **Handy + sofortige Bildschirmsperre** | Hotel Chur | Rechnung 2026-07-1292 + 2 Buchungen ✅ |

**Damit ist der Fehler heute unter keiner Bedingung reproduzierbar** — nicht am Rechner, nicht am Handy, nicht mit eingefrorenem Tab. Er hängt nicht an Daten, Betrieb, Gerät oder Ablauf. Zwischen dem 13. und 15.07. hat ihn etwas behoben; was, ist unbekannt.

### Ehrliche Bilanz: SECHS Hypothesen, alle widerlegt
1. Sequenz-Kollision (Diagnose 14.07., `fbca510`) — Sequenz stieg um 1 bei 6 Ausfällen.
2. Referenz-Kollision — keine der 38 Wunsch-Referenzen war belegt.
3. `kIsWeb`/Android — Daniel schliesst im Browser ab.
4. Service Worker / Cache — Fehler trat auch im Inkognito auf; Hash lokal == gh-pages == live.
5. Stummer catch als Ursache — war nur der Stand vom 26.06.; die rote Meldung kam im Ausfallfenster dazu, Daniel sah nie eine.
6. Eingefrorener Tab beim Handy-Einstecken — Test widerlegt.

**Konsequenz:** Statt der siebten Hypothese → **Erkennung gebaut** (Warnung, siehe unten). Der Fehler kostete 3 Wochen und CHF 3'656, weil ihn niemand SAH — nicht, weil er unauffindbar war.

**Falls er wiederkommt:** Die Warnung zeigt es am nächsten Tag. Zusätzlich meldet sich seit v0.48.4 der `betrieb == null`-Zweig laut (30 Sek. rote SnackBar + `debugPrint` mit `betriebId`) — der einzige Zweig, der ohne Ausnahme und ohne Spur aussteigen kann. Dann: **Meldung fotografieren**, das entscheidet die Frage in einer Minute.

---

## 🟢 ERLEDIGT 31.07. (Nachtpaket 2): v0.58.0 — Aufgaben-Screen, Events in Liste, Anfahrtszeiten

- **Aufgaben-Screen** (`/aufgaben`, neue Kachel statt Events): alle anstehenden Arbeiten chronologisch (Überfällig/Heute/Morgen/Datum) — eigene Aufgaben inkl. künftiger, offene Störungen, geplante Montagen, anstehende Eröffnungs-/Endreinigungen; FAB legt Aufgaben mit Datum an, Haken erledigt. **Events** jetzt unten in der Liste zuoberst (oberhalb Buchhaltung).
- **Anfahrtszeiten-Grundlage** (Migration 156 `anfahrtszeiten`): 804 OSRM-Standardzeiten (ohne Verkehr) von Via Rezia 8 Domat/Ems + Giacomettistrasse 89 Chur zu allen 402 Betrieben mit GPS — **kostenlos** (Google hätte ~3 USD gekostet, wäre aber auch im Freikontingent gewesen). Ø 48 min, max 200 min.
- **Erinnerung angelegt:** «Openair Lumnezia: Montage in der App generieren», fällig Mo 03.08. (Glocke + Aufgaben-Screen).

## 🟢 ERLEDIGT 30.07.: v0.62.0 — OpenStreetMap als dritter Kartenhintergrund (Standard)
Drei Knöpfe statt zwei: **OSM** (neu Standard), swisstopo-Landeskarte, Luftbild. OSM zeigt in Ortschaften mehr von dem, was bei der Anfahrt zählt — Restaurants, Parkplätze, Einbahnen. Die Quellenangabe folgt jetzt dem gewählten Dienst («© OpenStreetMap» / «© swisstopo»); vorher stand dort fest swisstopo, was mit OSM-Kacheln falsch gewesen wäre. **Ausnahme Event-Stände-Karte:** bleibt auf Luftbild — Stände liegen auf Wiesen und Plätzen ohne Strassennetz.

## 🟢 ERLEDIGT 30.07.: v0.61.0 — Störungen/Pausen verderben die Lernkurve nicht mehr
**Gemeldet von Daniel:** Zwischen Migros Golfpark und Restaurant Linden lagen eine Störung + 25 min Pause; nach Türmli eine Störung in Silvias Schlagerbar (Termin 16:00, also Wartezeit, ~45 min Dauer). Frage: «wie berücksichtigen wir solche Fälle ohne grossen Mehraufwand an Eingaben?»

**Ausmass geprüft:** 652 von 2'882 beobachteten Fahrzeiten (**23 %**) lagen mehr als doppelt so hoch wie die tatsächliche Route — im Schnitt **43 min zu viel**. Die beiden heutigen Fälle entgingen dem nur zufällig, weil sie über der 120-Minuten-Grenze lagen.

**Lösung — kostet keine einzige zusätzliche Eingabe:**
- Migration 158: `fahrzeiten.referenz_minuten` — ein von Beobachtungen **nie überschriebener** Routing-Massstab je Betriebspaar. 2'882 Werte per OSRM-Matrix geholt (64 Anfragen statt 3'124 Einzelabrufen).
- `lueckePlausibel()` (+7 Tests): Gelernt wird nur im Fenster **0,5×–2× der Route + 10 min Toleranz**. Im Zweifel nicht lernen — ein fehlender Lernschritt kostet nichts, ein falscher verdirbt die Planung für Monate.
- `fahrzeit-route` schreibt den Referenzwert beim Routen mit, auch für Paare mit bestehender Beobachtung.
- **652 verdorbene Altwerte** auf `referenz_minuten + 5` zurückgesetzt; Original in `import.fahrzeiten_vor_bereinigung_2026_07_30`, Rollback unter `Datenbank/wartung/`.

**Beantwortete Fragen (30.07.):**
- *Täglich Routing-Werte holen?* Ja — genau das ist die Referenz für den Filter. Nicht «täglich alle», sondern einmal je Betriebspaar beim ersten Auftauchen im Plan (passiert automatisch, kostenlos).
- *Google Maps als Kartenhintergrund?* **Nicht möglich** — Googles Nutzungsbedingungen verbieten die Anzeige ihrer Kacheln in Fremd-Bibliotheken (unser flutter_map). Erlaubt wäre nur ein separates Google-Widget ohne swisstopo-Umschalter. Alternative bei Bedarf: OpenStreetMap als dritter Layer (frei, mehr Details in Ortschaften). Für die Navigation bleibt der Google-Maps-Button im Betriebs-Detail.
- *Bergkunden-Erfassung (Konvention ab jetzt):* **Reinigungs-Startzeit = Abfahrt der Bahn** (Standort Talstation), **Ende = zurück beim Auto oder beim nächsten Kunden**. Bei mehreren Bergkunden nacheinander läuft die Zeit durch und wird auf die Betriebe aufgeteilt. Braucht keine neue Funktion — die Besuchsdauer-Statistik lernt die längeren Zeiten automatisch.

## 🟢 ERLEDIGT 30.07.: Google-Anfahrtszeiten geholt — beide Quellen vollständig
Routes API aktiviert **und** Key freigegeben (Daniel) → Voll-Lauf der Edge-Function `anfahrt-google`: **786 Google-Werte** geschrieben, keine Fehler. Stand jetzt je Startort: 402 OSRM-Werte, 393 Google-Werte.

**Die 9 Betriebe ohne Google-Route sind alle Davoser Bergbetriebe** (Weissfluhjoch, Weissfluhgipfel, Jatzhütte, Jschalp, Fuxägufer, Clavadeleralp, Chalet Güggel, Chalet Bolgen, Höhenweg) — dorthin gibt es keine durchgehende Autoroute. Für sie greift automatisch der OSRM-Wert (die Spalte `minuten` ist `coalesce(google, osrm)`).

**Qualitätsvergleich der beiden Quellen** (786 Paare): mittlere Abweichung **4,3 min**, 655 Paare (83 %) liegen innerhalb 5 Minuten. Die 20 Ausreisser über 20 min sind durchwegs Bergbetriebe, wo Google deutlich schneller rechnet (Hörnlihütte 60 statt 113 min) — dort routet Google bis zur Talstation, OSRM schleppt sich über Alpwege. **Wichtig:** Bei Bergbetrieben ist der Wert die reine Autofahrt, die Bergbahn kommt obendrauf; die echte Tür-zu-Tür-Zeit lernt die App über die beobachteten Fahrten.

## 🟢 ERLEDIGT 31.07.: v0.60.1 — Anfahrtszeiten für neue Betriebe automatisch
Legst du einen Betrieb an (typisch mit «aus Google übernehmen»), berechnet die App direkt nach dem Speichern die Anfahrtszeiten ab **Domat/Ems und Chur** und legt sie in `anfahrtszeiten` ab — nur wenn Koordinaten vorliegen und sich die Position geändert hat. Die Edge-Function `anfahrt-google` kann jetzt einen Einzelbetrieb rechnen und hat **OSRM als kostenlosen Rückfall**; Google-Werte kommen automatisch dazu, sobald die Routes API freigeschaltet ist. End-zu-End geprüft am Sunset Seehotel Eich: 121 min ab Domat/Ems (165.6 km), 115 min ab Chur (158.4 km).

## 🟢 ERLEDIGT 31.07.: v0.60.0 — Störungen/Montagen wirklich planbar (Grundsatzfund)
**Gemeldet von Daniel:** «ich kann nirgendwo geplant oder offen definieren, das haben wir mal gelöscht»

**Befund:** Beide Formulare schrieben den Status **hart** auf erledigt (`s.status = 'behoben'` / `m.status = 'abgeschlossen'`) — eine Auswahl gab es nicht. In der DB stehen darum **alle 1'106 Störungen auf «behoben»** und **alle 809 Montagen auf «abgeschlossen»**; der Tourenplan sucht «offen»/«geplant» und fand deshalb **nie** einen Eintrag. Die Aussage der letzten Tage, Störungen/Montagen seien über den Fällig-Tab planbar, war damit theoretisch.

**Behoben:** Beide Formulare haben oben einen Schalter **«Erst geplant»** (Standard aus = Rapport wie bisher). Eingeschaltet → Status «offen»/«geplant» → der Eintrag erscheint im Fällig-Tab, im Aufgaben-Screen und im Zähler. Beim Bearbeiten ist der Schalter aus dem Status vorbelegt; umlegen schliesst den Einsatz ab. **Wichtig:** Der Wegpunkt-Stempel wird nur bei *erledigten* Einsätzen gesetzt — ein geplanter war noch nirgends und würde die Fahrzeit-Lernkurve verfälschen. Neue Helfer `stoerungOffen`/`montageOffen` ersetzen die an sechs Stellen duplizierte Statusabfrage und lassen «in_bearbeitung» konsequent mitlaufen.

**Ausserdem — Tagesplan nach Feierabend:** Solange nichts erledigt ist, schob der Live-Modus den ganzen Rest-Plan hinter «jetzt»; abends stand der Plan damit ab 20:00 und wirkte unbrauchbar. Ein Tag mit erfasstem **Arbeitsende** gilt jetzt als abgeschlossen → statische Ist-Ansicht wie bei einem vergangenen Tag, Minutentakt-Timer aus.

## 🟢 ERLEDIGT 31.07.: v0.59.0 — Servicezeiten am Block, Grund der Schliessung, Anker-Warnung
- **Servicezeiten stehen jetzt am Block** («🕐 08:00–12:00 · nachmittags kein Service · Ruhetag Mo, Di»), bei Konflikt orange. Ohne erfasste Zeiten bleibt die Zeile weg.
- **Warnung nennt den Grund:** Ruhetag/Ferien/Zwischensaison wurden schon alle erkannt (`istOffenerTag`), aber pauschal als «Betrieb geschlossen» gemeldet. Neu: «Ruhetag», «Betriebsferien bis 16.08.», «Zwischensaison», «Betrieb inaktiv» (`schliessungsGrund`, 10 Tests inkl. Deckungsgleichheit mit `istOffenerTag`).
- **Anker geprüft:** Berechnung war korrekt (Anker = «frühestens ab» → Wartezeit). Lücke: Liegt der Anker VOR der geplanten Ankunft, kann er den Block nicht nach vorne ziehen — der Termin wäre still verpasst worden. Neu warnt der Block: «Termin 08:00 verpasst — Reihenfolge anpassen».

## 🟢 ERLEDIGT 31.07.: v0.58.1 — Anfahrtszeit-Bug (Eich 346 → 117 min)
**Gemeldet von Daniel:** «warum zeigt der Tagesplan von morgen 346 min Anfahrt zu Sonne Seehotel Eich?»

**Ursache:** Die Fahrzeit-Heuristik (Luftlinie × 2.5 ÷ 45 km/h) war an kurzen Bündner Bergstrecken kalibriert. Über 100 km lag ihr Median-Fehler bei **249 min** — auf der Autobahn gelten weder Umwegfaktor 2.5 noch 45 km/h.

**Behoben:** Umwegfaktor (2.20 → 1.45) und Schnitt (32 → 78 km/h) laufen jetzt exponentiell mit der Distanz, kalibriert an den 804 echten Routen. Median-Fehler über alle: **7 min statt 35**; Gegenprobe an 2'807 beobachteten Tür-zu-Tür-Fahrten: 7 statt 12 min. Der Rüst-/Parkierzuschlag ist neu additiv (5 min) statt im Faktor versteckt — er skalierte sonst mit der Distanz. Anfahrt/Heimweg nehmen ausserdem primär die **gerechneten Werte** aus `anfahrtszeiten`; welcher Startort gilt, entscheidet die GPS-Position des Arbeitsbeginns (nächster der beiden, max. 5 km).

## 🔴 OFFEN: Ausbau Aufgaben (Folgepaket)
- **Aufgaben ↔ Kalender + Tourenplanung verknüpfen:** Aufgaben-Einträge in den Tagesplan des jeweiligen Tages übernehmen können; Sync mit Google Kalender (Teil des geplanten Kalender-Pakets G1–G4); Störungen mit PLAN-Datum (heute nur Meldedatum).
- **Echte Zeiterfassung Störung/Montage — braucht Entscheid Daniel:** Der Live-Tagesplan schätzt weiterhin (Ende = Wegpunkt-Stempel, Start = Stempel − Plandauer). Befund 30.07.: Die Felder `uhrzeit_start/ende` existieren bei beiden Tabellen und `dauer_minuten` ist eine **GENERATED**-Spalte (`ende − start`). Bei Störungen ist `uhrzeit_start` aber der **Störungseingang** (Anruf, 107 Altwerte) — trägt man dort ein Ende ein, wird die «Dauer» zur Reaktionszeit statt zur Arbeitszeit. Sauber wären eigene Felder «Arbeit von/bis» (Migration) ODER die Umdeutung des Eingangs-Felds. **Frage an Daniel:** Wie soll der Störungseingang künftig festgehalten werden?

## 🟢 ERLEDIGT 30.07.: v0.64.0 — echte Strassenroute in der Tages-Karte

**Gemeldet von Daniel:** «wolltest du nicht routen in der karte darstellen» — zu Recht: Die Tages-Karte verband die Besuche mit **Luftlinien**, quer über Berge und Seen.

- Neuer `TagesrouteService` holt bei OSRM den tatsächlich gefahrenen Verlauf (GeoJSON) und zeichnet ihn als Linie über die Kacheln.
- Die Karte ist **sofort** mit der Luftlinie da und schärft nach, sobald die Antwort eintrifft. Antwortet OSRM nicht (kein Netz, keine Autoroute — etwa Davoser Bergbetriebe), bleibt die Luftlinie stehen, dünner und blasser gezeichnet, damit der Unterschied sichtbar ist.
- Kein neuer Dienst, keine Kosten: derselbe freie OSRM-Server, der schon die Fahrzeit-Referenzen liefert.
- 9 Tests für die Auswertung der OSRM-Antwort (ohne Netz), 784 Tests grün.

## 🟢 ERLEDIGT 30.07.: v0.63.0 — Routen-Optimierung, Arbeitstag-Auswertung, Pause-Knopf
- **Routen-Optimierung** (`routen_optimierung.dart`, 18 Tests): Zauberstab-Knopf im Tagesplan ordnet die Besuche nach kürzester Gesamtfahrzeit (Nächster-Nachbar + 2-opt, deterministisch). **Einträge mit Termin-Anker bleiben stehen.** Das Verfahren prüft auch die bestehende Reihenfolge und nimmt die bessere — es kann nie verschlechtern. Meldet die Ersparnis in Minuten oder «bereits optimal».
- **Auswertung Arbeitstage** (neuer Screen unter «Buchhaltung», 22 Tests): Kennzahlen je Monat — Arbeitstage, Besuche, Total/Ø km, Total/Ø Arbeitszeit, Ø Besuche/Tag, Ø km und Minuten je Besuch — plus Liste der Einzeltage. Jede Kennzahl hat ihren eigenen Nenner, ein Tag mit nur km zieht den Zeit-Schnitt also nicht nach unten.
- **Pause-Knopf** in der Arbeitstag-Karte (Migration 159): wechselt zwischen «Pause» und «Pause aus», Tagessumme in `pause_minuten`, laufende Pause übersteht einen App-Neustart; Wegpunkt-Stempel `pause_start`/`pause_ende`. Damit landet eine Pause weder in der Arbeitszeit noch in der gelernten Fahrzeit.
- **Hinweis zur Auswertung:** Aktuell ist **kein einziger Tag vollständig erfasst** (30.07. hat Feierabend + km, aber keinen Arbeitsbeginn — den hatte ich als Fehleingabe 19:29 gelöscht; 31.07. hat nur den vorausgeplanten Beginn 05:20). Die Kennzahlen füllen sich, sobald Beginn UND Ende UND beide km-Stände eines Tages da sind.

---

## 🟢 ERLEDIGT 31.07. (Nachtpaket): v0.57.0 — tatsächliche Tagesdaten, Tages-Karte, GPS robuster

- **Vergangene Tage = tatsächliche Reinigungen:** Der Tagesplan-Tab zeigt für vergangene Tage die abgeschlossenen Reinigungen des Tages (Zeitachse readonly, Tap öffnet die Reinigung, Ist-Matching exakt je Reinigung) — gespeicherte Pläne sind Geschichte. Auch die **Plan-Übernahme** lädt jetzt die echten Reinigungen des Quelltags (ohne Störungen/Montagen), nicht mehr den damaligen Plan.
- **Tages-Karte** (map-Icon im Tagesplan-Header, heute + Vergangenheit): nummerierte Besuchs-Marker (Betriebs-GPS) + Wegpunkt-Stempel (Störung/Montage/Arbeitsbeginn/Feierabend auf echter GPS-Position) auf swisstopo-Karte/Luftbild, zeitlich als Linie verbunden. Aussagekräftig ab 31.07. (erst seit dann gibt es Wegpunkte + Arbeitstag-GPS). Marker-Tap zeigt Zeit + Name.
- **GPS robuster** (Openair-Befund: Stand-Erfassungen brauchten mehrere Anläufe): bis zu 3 Messungen mit höchster Genauigkeit, die genaueste gewinnt, ab 25 m sofort fertig; Timeout fällt auf die beste bisherige Messung zurück. Gilt überall (Arbeitstag, Wegpunkte, Event-Stände, Karten). Grenze: Web-App = Browser-Geolocation (fused Location), kein Roh-GNSS.
- **DB bereinigt:** 16 Test-Tagespläne gelöscht, Einträge 30./31.07. geleert (Arbeitstag-Rahmen 30.07. mit Feierabend 18:23 + km + GPS erhalten), 02:00-Testbeginn vom 31.07. entfernt.

---

## 🟢 ERLEDIGT 31.07.: v0.56.1/v0.56.2 — Ist-Zeiten für vergangene Tage, Sunset-Fix, Arbeitstag-Schutz

- **v0.56.1:** Vergangene Tage im Tagesplan zeigen die GEMESSENEN Zeiten der abgeschlossenen Reinigungen (Fall «Plan vom 17.07. — Zeiten stimmen nicht»); ohne erfassten Arbeitsbeginn startet die Achse beim ersten gemessenen Ereignis.
- **v0.56.2:** (1) Block-Sheet verlinkt die **Betriebsseite**. (2) **Sunset-Fall** gelöst: Plan-Übernahme von Datum und «Fällige übernehmen» ergänzen jetzt die heute fälligen Geschwister-Anlagen des Betriebs (`ergaenzeFaelligeAnlagen`, Bulk über `buendleInPlan`). (3) **Arbeitstag-Fehleingaben-Schutz**: «Jetzt starten» fragt nach, wenn der Tag läuft oder schon abgeschlossen ist; das Arbeitstag-Sheet hat alle 4 Felder (Beginn/km Start/Ende/km Abend, leer = löschen); `arbeitsbeginn` ist nullbar — vorher schrieb jeder Feierabend ohne Start den 06:00-Standard als erfassten Beginn.
- **DB bereinigt:** versehentlicher Arbeitsbeginn 19:29 vom 30.07. gelöscht (Beginn + Startposition + Wegpunkt); Feierabend 18:23 und km 77'912→78'290 (378 km) blieben stehen.

---

## 🟢 ERLEDIGT 31.07.: Betriebsferien & Öffnungszeiten aktuell halten — gebaut, noch NICHT deployed

**Stand: alles committet und gepusht, 871 Tests grün, analyze auf Baseline 54. Der App-Deploy fehlt bewusst** — die drei neuen Oberflächen (War-geschlossen-Sheet, Ferienfrage-Sheet, Prüfliste) sind noch nicht visuell geprüft, und die Projektregel verlangt das vor dem Livegang. Server-seitig läuft dagegen schon alles.

**In der App (auf main, wartet auf Deploy):**
- **«War geschlossen»** im Tagesplan-Block (heutige + vergangene Tage): Grund erfassen → Betriebsferien (Datumsbereich, `quelle='vor_ort'`), Ruhetag (Wochentag) oder «niemand da» (nur Notiz). Immer ein Wegpunkt `quelle='vergeblich'` mit Zeit + GPS + Notiz. **Keine** automatische Neuplanung (Entscheid Daniel) — Besuch bleibt fällig.
- ~~Ferienfrage beim Reinigungs-Abschluss~~ **WIEDER ENTFERNT 05.08.2026 (v0.72.1, Entscheid Daniel):** «stört im Moment mehr, als es nützt — ein Klick mehr bei der Reinigung». Sheet + Logik + Tests gelöscht; die DB-Felder (`ferien_bestaetigt_am`, `ferien_frage_ruht_bis`) und die Tabelle `betrieb_ferien` bleiben. Ferien/Saisonpausen laufen weiterhin über Betriebs-Formular + täglichen Google/Website-Abgleich mit Prüfliste; ggf. künftig ein neuer Erfassungsweg (Ideen offen, siehe «Betriebsdaten aktuell halten»).
- **Graues Vorjahres-Band** am Block: «Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen». Rein informativ, optisch klar von der roten Warnung getrennt, schweigt sobald für das Jahr eine Aussage vorliegt.
- **Prüfliste** `/betriebe/vorschlaege` (Zeile im Aufgaben-Screen): alter → neuer Wert, Quelle, Datum; «Alle übernehmen, bei denen Google und Website übereinstimmen»; **Saison ist von der Sammelübernahme ausgenommen** und orange hervorgehoben.

**Datenmodell (Migrationen 160–162, alle angewendet):** Tabelle `betrieb_ferien` (39 Altperioden übernommen, Quelle + Bestätigungsdatum je Zeile), Pflegefelder auf `betriebe` (`ferien_bestaetigt_am`, `ferien_frage_ruht_bis`, `ruhetage_bestaetigt_am`, `oeffnungszeiten_geprueft_am`, `google_place_id`), Tabelle `betrieb_vorschlaege`, Wegpunkt-Quelle `vergeblich` + `wegpunkte.notiz`. Die alten fünf Ferien-Spaltenpaare stehen als Rückweg noch da.

**Wichtige Regel im Code:** `BetriebLocal.ferienPerioden` ist `null` = noch nicht geladen (dann greifen die alten Spalten) vs. leere Liste = geladen, keine Ferien (dann schweigen die alten Spalten). Ohne diese Trennung käme eine gelöschte Ferienperiode über den Altbestand zurück.

**Server (läuft bereits):** Edge-Functions `betrieb-google-abgleich` (Places: `regularOpeningHours`, `currentOpeningHours`, `businessStatus`, speichert `google_place_id`) und `betriebsdaten-abgleich` (Orchestrator, fragt je Betrieb **beide** Quellen); `parse-oeffnungszeiten` liest neu auch Ferien und Saison und läuft auf Haiku. **pg_cron-Job `betriebsdaten-abgleich`, täglich 03:20 UTC, 10 Betriebe** → ganzer Bestand in ~4 Wochen.

**Zwei Funde aus dem ersten Testlauf, sofort behoben:** (1) Eine Website hatte noch eine Ferienmeldung von **November 2024** stehen — abgelaufene Zeiträume werden jetzt verworfen. (2) Ein Saison-Vorschlag entstand für einen ganzjährig offenen Betrieb — Saison gibt es jetzt nur noch bei `ist_saisonbetrieb`. Testlauf danach an 3 Betrieben: 6 plausible Vorschläge, 0 Fehler (Ruhetage Mo/Di von beiden Quellen bestätigt, Öffnungszeiten Google vs. Website 22:30 vs. 23:00 → korrekt zwei getrennte Vorschläge, Saison nur beim Berggasthaus Arflina).

**Noch offen:**
- **App-Deploy** (Version bumpen, Build, gh-pages) nach visueller Prüfung der drei neuen Oberflächen.
- ~~20 Winterfenster mit verdrehten Jahreszahlen~~ **ERLEDIGT 04.08.2026** (Freigabe Daniel): Alle 20 Winterfenster «Start Ende 2026, Ende April 2026» auf Ende **April 2027** angehoben (Regel `jahreszahlenRichten()`: bis < von → bis + 1 Jahr; verhindert die «ewige Saison» im Wrap-Zweig von `_imFenster()`). Starts unverändert, Sommerfenster waren sauber, Kontrolle 0/0/20. Skript `Datenbank/wartung/winterfenster_jahreszahlen_2026_08_04.sql`, Rückweg `rollback_winterfenster_2026_08_04.sql` (Snapshot `snapshot_winterfenster_2026_08_04`).
- **Rössli:** Ferienbeginn 29.05.2026 ohne Enddatum (wandert nicht in die neue Tabelle, war auch bisher wirkungslos) — Ende nachtragen.

<details><summary>Ursprüngliche Planung (31.07.)</summary>

## Planung: Betriebsferien & geänderte Öffnungszeiten aktuell halten

**Anlass Daniel:** «Heute ist es mir wieder passiert, dass ich einen Kunden hatte, der plötzlich Betriebsferien hatte und den ich nicht machen konnte.»

**Befund Datenlage (31.07., 294 aktive Betriebe):**
| | |
|---|---|
| mit mindestens einer Ferienperiode | **36** |
| ausdrücklich «keine Betriebsferien» | 14 |
| **ohne jede Aussage zu Ferien** | **244 (83 %)** |
| erfasste Perioden gesamt | 40 (39 davon mit Start 2026) |
| brauchbare Öffnungszeiten (jsonb mit Inhalt) | 209 |
| Ruhetage erfasst | 214 · Servicezeiten: 102 |
| Telefon / E-Mail vorhanden | 278 / 198 |

Die Logik ist **nicht** das Problem: `touren_saison.dart` warnt sauber mit Grund («Betriebsferien bis …», Ruhetag, Zwischensaison), der Fälligkeits-Anker rechnet ab Wiedereröffnung. Es fehlen schlicht die Daten — und es gibt keinen Ort, an dem eine vergebliche Fahrt festgehalten wird, also lernt das System aus dem Schaden nichts.

**Zwei technische Randbedingungen:**
- `betriebe` hat **keine** `google_place_id`; die Edge-Function `betrieb-google-lookup` holt nur `regularOpeningHours` — weder `businessStatus` (vorübergehend geschlossen) noch `currentOpeningHours` (enthält Sonderzeiten der nächsten 7 Tage).
- `updated_at` taugt nicht als Pflegesignal (alle 294 Betriebe wurden in den letzten 90 Tagen durch Massen-Updates berührt) — es braucht ein eigenes Feld «Ferien bestätigt am».

**Entscheid Daniel 31.07.:** Gebaut werden **A** («War geschlossen»-Knopf, aber **keine** automatische Neuplanung — Daniel plant selbst), **B** (Ferienfrage beim Reinigungs-Abschluss — bevorzugt gegenüber einem Vortages-Check), **D** (Vorjahres-Hinweis) und **F** (Website-Auswertung um Ferien erweitern) — dazu ein **regelmässiger Abgleich über Google und Website**. Kein Vortages-Check-Screen. Fremdquellen nur für **Ruhetage und Öffnungszeiten**, keine Servicezeiten.

**Spec:** `docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md` · **Plan:** `docs/superpowers/plans/2026-07-31-betriebsdaten-aktuell-halten.md` (11 Tasks, wartet auf Startfreigabe).

**Nachtrag Daniel 31.07. — Saisonpausen mitnehmen (umgesetzt):** Von 92 aktiven Saisonbetrieben haben **89 eine Website**; Bergrestaurants schreiben ihre Saison fast immer aufs Netz. Unvollständig: 32 Sommer-, 41 Winterangaben, 12 ganz ohne Daten. Google kennt **kein** Saisonfeld — das läuft nur über die Website. Die Extraktion liefert **nur Tag und Monat**, das Jahr setzt die App (`saison_jahr.dart`, Task 6b), weil Winterfenster über den Jahreswechsel laufen; dieselbe Logik repariert die **20 Winterfenster mit verdrehten Jahreszahlen** (Robinson Club Arosa: 01.12.2026–01.04.2026). **Saison-Vorschläge nie per Sammelübernahme** — ein zu spät angesetzter Saisonstart nimmt einen Betrieb still für Monate aus der Fällig-Liste (`faelligkeitsAnker` zählt ab Wiedereröffnung). Kern: eigene Tabelle `betrieb_ferien` statt fünf fester Spaltenpaare (sonst verdrängen neue Ferien die Historie, aus der der Vorjahres-Hinweis stammt), Vorschlagstabelle statt stiller Übernahme, täglicher `pg_cron`-Lauf über je 10 Betriebe.

</details>

## 🟢 ERLEDIGT 31.07.: Einsatzplanung Etappe 1 — Störungen und Montagen sind planbar

**Das war Daniels Kritik:** «die Planung von Störungen und Montagen gefällt mir noch nicht». Etappe 1 behebt sie vollständig (Sprache und Kalender folgen als Etappe 2/3).

- **Migration 163:** `geplant_am`, `geplant_zeit`, `geplant_dauer_min`, `arbeit_von`, `arbeit_bis` an beiden Tabellen, `gemeldet_am` bei Störungen. Die 109 alten «Störungseingang»-Zeiten sind nach `gemeldet_am` umgezogen (gesichert in `import.stoerung_uhrzeit_start_vor_163`). Die 219 verwaisten Termin-Vorschläge wurden gelöscht — Bedingung Daniels («nur wenn wir keine Daten verlieren») vorher geprüft: 0 Notizen, 0 Uhrzeiten, 0 abweichende Status, alles aus Saisondaten neu berechenbar; Kopie in `import.termine_vor_loeschung_2026_07_31`.
- **Drei Zeitbegriffe getrennt:** gemeldet (Anruf) · geplant (Termin oder ganztägig) · gearbeitet (Ist-Zeit). Beim Abschliessen wandert `datum` auf den Tag der tatsächlichen Arbeit — sonst würde eine im Juli gemeldete, im August erledigte Störung im falschen Monat abgerechnet.
- **Sichtbarkeitsregel** (`einsatz_faellig.dart`, 12 Tests): Ein Einsatz verschwindet nur, wenn er für einen **späteren** Tag geplant ist. Ungeplante bleiben immer sichtbar (sie sind das, was einzuplanen ist), verpasste Termine ebenfalls (verpasst ≠ erledigt).
- **«Einplanen»-Sheet:** Tag (heute/morgen/Datum), Umschalter **ganztägig ↔ fixer Termin**, Dauer in 15-Minuten-Schritten. Erreichbar aus der Fällig-Liste **und aus dem Aufgaben-Screen**, wo es bisher ausser Navigation keine Aktion gab.
- **Rückschreiben:** Anker-Zeit oder Dauer im Block-Sheet zu ändern schreibt an den Einsatz zurück — bisher lebte die Uhrzeit nur am Tagesplan-Eintrag und ging beim Entfernen des Blocks verloren.
- **Dauer-Vorgaben** (`einsatz_dauer.dart`, 11 Tests) statt pauschal 60 min: je Störungsbereich gestaffelt (Grundzeit 20 min + Aufschläge, gedeckelt bei 180), je Montage-Typ (Neumontage 120, Demontage 75, Anlass 240, Spesen/Aufwandsentschädigung 0 = kein Kundenbesuch). Bewusst feste Werte — es gibt **keine einzige** erfasste Arbeitszeit, aus der man Mediane bilden könnte; ersetzbar, sobald Ist-Zeiten vorliegen.
- **Abrechnung unangetastet** (Vorgabe Daniel): `dauer_stunden` bei Montagen bleibt frei editierbar, weil dort bewusst auch Anfahrtsanteile für die Heineken-Abrechnung hineingerechnet werden. Die gemessene Zeit überschreibt sie **nie**, sondern erscheint höchstens als Hinweis mit «übernehmen»-Knopf. Als Kommentar im Code festgehalten.

## 🟢 ERLEDIGT 31.07.: Etappe 3 — geplante Einsätze im Google-Kalender (v0.68.0 live)

**Warum über Google:** Eine Web-App stellt bei geschlossenem Tab **nichts** zu. Der Kalender ist der einzige Kanal, der Daniel zuverlässig erreicht. Merksatz: **Die App plant, Google erinnert.**

- Neuer Kalender-Typ `einsatz` für geplante Störungen und Montagen, `entity_id` als `stoerung:<id>` / `montage:<id>`, eigene Farbe (6).
- **Mit Uhrzeit** → echter Termin (Europe/Zurich, Ende = Start + geplante Dauer, Vorgabe 60 min), Erinnerung **60 min UND 1440 min** vorher — 24 h allein ist bei einem festen Termin gleichzeitig zu früh und zu spät. **Ohne Uhrzeit** → Ganztages-Eintrag mit Erinnerung 24 h vorher.
- **Rücknahme automatisch:** Sobald ein Einsatz erledigt oder das Plandatum entfernt ist, liefert der Ereignis-Bau `null` → Eintrag wird gelöscht. `reconcile` räumt beim stündlichen Abgleich auf.
- Push sitzt in `einplanen()` der Repositories (deckt alle Aufrufer ab), fire-and-forget — ein fehlender Kalenderzugang blockiert das Einplanen nie.
- **Migration 164:** `google_calendar_events.entity_type` erlaubte `einsatz` nicht. Ohne die Erweiterung wäre der Google-Termin angelegt, die Zuordnungszeile aber an der CHECK-Regel gescheitert — **bei jedem Abgleich neue Duplikate**. Vom Agenten gemeldet statt umgangen, vor dem Deploy behoben.

## 🟢 ERLEDIGT 31.07.: Etappe 2 — Diktierfunktion live (v0.69.0)

**Wunsch Daniel:** «Diktierfeld auf die Startseite als Button, relativ prominent, da ich das häufig brauche und meistens im Auto benutze» — er bekommt Anrufe während der Fahrt und zwischendurch bei der Arbeit.

- **Knopf:** schwebender Knopf mit Mikrofon-Symbol, unten mittig (Daumenbereich, einhändig). Bewusst **kein** Banner über den Kacheln — der Startbildschirm wurde am 31.07. gerade erst so eingerichtet, dass alle Kacheln ohne Scrollen aufs Pixel 9 passen; ein Balken hätte das sofort gesprengt. Keine Kollision mit der Aufgaben-Glocke (links, 96 px höher).
- **Sheet:** grosses Textfeld mit Autofokus — Tastatur und damit das Gboard-Mikrofon sind sofort da. **Wir bauen keine Spracherkennung**, die kommt vom Betriebssystem.
- **Einsätze:** Art, Betrieb, Datum, Zeit, Dauer, Beschreibung als Bestätigungsformular. **Datum im Diktat → wird gleich eingeplant; ohne Datum → offener Eintrag.** Betriebs-Kandidaten als Chips, wenn die Zuordnung nicht eindeutig ist.
- **Neue Betriebe per Sprache:** «Neuer Betrieb Restaurant Adler in Chur, Heigenie, mein Kunde» → Name, Ort, Anlagentyp, Kundenstatus aus dem Satz; Adresse/Telefon/Website/Koordinaten über den bestehenden Google-Lookup, **Vorschau vor dem Speichern**. Kombi-Satz («…und morgen 10 Uhr Störung dort») → erst Betrieb, Einsatz-Teil in die Beschreibung.
- **Offline (Kernanforderung):** Schlägt die Auswertung fehl, wird der Rohtext **sofort** lokal abgelegt, bevor irgendetwas anderes passiert — «Kein Netz, Diktat gespeichert». Im Sheet erscheint «N Diktate warten» mit Wiederholen und Löschen je Eintrag. Jeder Entwurf ist ein eigener Eintrag, ein defekter reisst die Liste nicht mit.

**⚠️ Weiterhin nicht verifiziert:** Ob die Auswertung die Sätze inhaltlich richtig versteht. Die Funktion verlangt eine angemeldete Sitzung, in `.env` liegen keine Testzugangsdaten. **Daniels erstes Diktat ist der erste echte Test.**

<details><summary>Vorheriger Stand (Verstehen steht, Oberfläche fehlte)</summary>

**Fertig:** `parse-einsatz` (Edge-Function, deployed) versteht diktierte Sätze — relative Daten («morgen», «nächsten Dienstag», «am 15. August» → nächstes Vorkommen, notfalls Folgejahr), Uhrzeiten («halb drei» → 14:30), Art, Dauer, Beschreibung; setzt `betrieb_id` nur bei Eindeutigkeit, sonst Kandidaten + Rückfrage; Haiku, temperature 0. Dazu die **Betriebs-Erkennung** `einsatz_betrieb_match.dart` (14 Tests) — läuft **ohne Netz**, nutzt Umlaut-Faltung, Tippfehler-Toleranz und filtert Gattungswörter («Störung im Hotel» kapert keinen Betrieb); bei Mehrdeutigkeit bewusst mehrere Kandidaten.

**⚠️ NICHT verifiziert:** Der inhaltliche Test der Funktion steht aus — sie verlangt eine angemeldete Sitzung, und in `sbs_projer_app/.env` liegen keine Testzugangsdaten. Bestätigt ist nur: deployed, erreichbar, weist unangemeldete Aufrufe korrekt ab (401). **Erster echter Test = Daniels erstes Diktat.**

**Offen war:** die Oberfläche. Beide Fragen sind beantwortet — Knopf prominent auf der Startseite (Daniel), Einsatz mit Datum wird gleich eingeplant (meine Entscheidung mangels Antwort, von Daniel nicht widersprochen).

</details>

## 🟢 ERLEDIGT 31.07.: Etappe 4 — Eröffnungs-/Endreinigungen als Termine (v0.70.0 live)

**Leitgedanke:** *Berechnet bleibt berechnet, bestätigt wird gespeichert.* Die Saison-Logik rechnet die Vorschläge weiter (passt sich an, wenn Saisondaten sich ändern); erst beim Annehmen entsteht ein Termin in `termine` — mit Kalender-Erinnerung 24 h vorher.

- **Aufgaben-Screen:** Knopf «Termin bestätigen» bei berechneten Vorschlägen, bestätigte Termine als eigener Block mit «Erledigt».
- **Keine Doppelanzeige:** `termin_abgleich.dart` (7 Tests) blendet einen Vorschlag aus, wenn ein bestätigter Termin für denselben Betrieb, denselben Typ und ein Datum **±7 Tage** existiert — Saisondaten verschieben sich leicht, sonst stünde der Vorschlag neben dem Termin.
- **Kalender:** Ganztages-Eintrag, eigene Farbe (9), Titel `SBS · Eröffnungsreinigung: {Betrieb}`. Erledigt/abgesagt/gelöscht → Eintrag verschwindet beim nächsten Abgleich. Keine Migration nötig, `termin` war im entity_type-CHECK schon erlaubt.
- **Bugfix nebenbei:** Das Diktier-Sheet legte bei «Eröffnungsreinigung» einen **Abrechnungseintrag** (`eroeffnungsreinigungen`) statt eines Termins an — jetzt korrigiert.

**Damit sind alle vier Etappen der Einsatzplanung live.** 923 Tests grün.

**Spec:** `docs/superpowers/specs/2026-07-31-einsatzplanung-sprache-design.md` · **Plan Etappe 1:** `docs/superpowers/plans/2026-07-31-einsatzplanung-etappe1.md` (7 Tasks)

**Warum die Planung heute nicht funktioniert (Zahlen):** 1'108 Störungen — **alle** «behoben»; 810 Montagen — **alle** «abgeschlossen»; 109 Störungen mit Startzeit, **0 mit Endzeit**; Montagen: **0** Startzeiten. Der Schalter «Erst geplant» wurde seit v0.60.0 **nie** benutzt. Vier Ursachen: (a) **kein Plandatum** — `datum` ist im Code als Meldedatum kommentiert, «gemeldet» und «geplant für» fallen zusammen; (b) offene Einsätze erscheinen an **jedem** Tag (`faelligeEintraegeProvider` filtert Störungen/Montagen bewusst nicht nach Datum); (c) die Uhrzeit lebt als `ankerZeit` nur am **Tagesplan-Eintrag** und geht verloren, wenn man den Block entfernt; (d) `uhrzeit_ende`/`dauer_minuten` existieren in beiden Modellen, werden aber von **keinem** Formular geschrieben.

**Entwarnung:** `dauer_minuten` ist überall GENERATED (Ende − Start). Abgerechnet wird davon unabhängig — Montagen über `dauer_stunden`+`stundensatz`, Störungen über Pauschalen. **Eine gemessene Arbeitszeit ändert keine Rechnung.**

**Lösung:** drei getrennte Zeitbegriffe — **gemeldet** (`gemeldet_am`), **geplant** (`geplant_am`/`geplant_zeit`/`geplant_dauer_min`), **gearbeitet** (`arbeit_von`/`arbeit_bis`). Fällig-Liste zeigt nur noch, was für den Tag geplant ist oder gar kein Plandatum hat; «Einplanen» schreibt an den Einsatz und in den Tagesplan, Anker-Änderungen schreiben zurück.

**Spracheingabe — Entscheid aus der Recherche:** **Keine eigene Spracherkennung.** Web Speech API schickt Audio an Google-Server (offline nutzlos, dokumentierte Chromium-Fehler bei Dauer-Erkennung auf Android), Audio-Upload zu Whisper/Deepgram hat dasselbe Offline-Problem und kostet pro Minute. Stattdessen: **Gboard-Mikrofon in ein normales Textfeld** (Betriebssystem-Ebene, null Code, kostenlos, teils on-device) + Edge-Function `parse-einsatz` (Claude, Muster von `parse-beleg`) fürs **Verstehen**. Ohne Netz bleibt der Rohtext als Entwurf liegen und wird später ausgewertet.

**Erinnerungen — die harte Grenze:** Eine Web-App stellt bei geschlossenem Tab **nichts** zu. `flutter_local_notifications` steht in pubspec, wird aber nirgends verwendet. Was Daniel erreicht, ist der **Google-Kalender** (E-Mail + Popup, 24 h vorher) — der Sync existiert bereits für Pikett, Events und Saison-Reinigungen. Also: **Die App plant, Google erinnert.**

**Fund:** Die Tabelle `termine` existiert mit **219 Zeilen** (135 Endreinigungen, 84 Eröffnungsreinigungen, alle Status `vorgeschlagen`, zuletzt 11.07.2026, keine mit aktiver Erinnerung) — im Flutter-Code gibt es dazu **keinen einzigen Zugriff**. Verwaist aus einem früheren Anlauf, aber mit passendem Zuschnitt inkl. Erinnerungsfeldern → in Etappe 4 wiederbeleben.

**Etappen:** 1 Fundament (behebt die Kritik allein) · 2 Spracheingabe · 3 Kalender+Erinnerungen · 4 Eröffnungs-/Endreinigungen.

**Vier Entscheide von Daniel offen** (Abschnitt 8 der Spec): Reaktionszeit messen? · die 219 alten Termin-Vorschläge löschen? · Kalendereintrag für jeden geplanten Einsatz oder nur mit Uhrzeit? · Arbeitszeit per «Beginn»-Knopf oder hinterher eintippen?

## 🔴 OFFEN (Wunsch Daniel 31.07.): Arbeitstag sauber erfassen — Zeiterfassung

- **Zeiterfassung für Störungen und Montagen**, damit der ganze Arbeitstag lückenlos erfasst ist. Bekannte Hürde (Befund 30.07.): `dauer_minuten` ist bei beiden Tabellen eine GENERATED-Spalte aus `uhrzeit_ende − uhrzeit_start`, aber `uhrzeit_start` bei Störungen ist der **Störungseingang** (Anruf, 107 Altwerte) — trägt man dort ein Ende ein, misst man die Reaktionszeit statt der Arbeitszeit. Zwei Wege: eigene Felder «Arbeit von/bis» (Migration) ODER Umdeutung des Eingangsfelds mit separatem Meldezeitpunkt. **Entscheid Daniel steht aus.**
- **Planung von Störungen/Montagen gefällt noch nicht** (O-Ton 31.07.) → **GEPLANT, Spec + Plan liegen vor**, siehe eigener Abschnitt unten.

**Langfrist-Entscheid Daniel:** Eine **Version 2 der App wird eine reine Android-App** (kein Web mehr). Erst dort sind Dinge möglich, die der Browser prinzipiell verbietet — allen voran echte Fahrterkennung im Hintergrund (Android Activity Recognition, «IN_VEHICLE») und zuverlässiges GPS bei ausgeschaltetem Bildschirm. Bis dahin gilt: alles, was Hintergrund-Tracking bräuchte, wird ereignisbasiert nachgerechnet statt live gemessen.

## 🟢 ERLEDIGT 04.08. (v0.72.0): Eröffnungs-/Endreinigung am Schliessungstag auswählbar

**Gemeldet Daniel 04.08.2026:** «warum erscheint Löwen Grossdietwil nicht zur Auswahl im Tourenplan, ich habe dort am Donnerstag einen Termin für die Eröffnung (letzter Tag der Betriebsferien)»

**Befund:** `Gasthof Löwen`, Grossdietwil (id `1c4a9f7f-cf76-44f7-8e8f-a58ded45e58c`), Betriebsferien 18.07.–06.08.2026 → Donnerstag 06.08. = letzter Ferientag. Drei Lücken: (1) `istOffenerTag()` führt Ferien-Betriebe als geschlossen — richtig für normale Reinigungen, falsch für Saison-Reinigungen; (2) die Auto-Vorschläge (`autoTermineProvider`) zielten via `naechsterOffenerTag()` nie auf einen Schliessungstag; (3) bestätigte Termine aus `termine` erschienen im Tourenplan gar nicht (nur im Aufgaben-Screen). Löwen fiel zusätzlich durch die 21-Tage-Schwelle (Ferien nur 20 Tage → keine Saison-Automatik).

**Gebaut (v0.72.0):**
- **`darfTrotzSchliessungGeplantWerden({art, betrieb, tag})`** + `saisonPlanungsHinweis(...)` in `touren_saison.dart` (rein, 20 Tests): Eröffnung erlaubt am **letzten** Schliessungstag (morgen offen), Endreinigung am **ersten** (gestern offen); mitten in der Schliessung, inaktiv/geschlossen → nein; Ruhetage zählen nicht.
- **`autoTermineProvider`**: Eröffnungs-Vorschlag erscheint zusätzlich am letzten Schliessungstag, Endreinigungs-Vorschlag am ersten (zielDatum = der Tag selbst).
- **Bestätigte Termine im Tourenplan**: neue Sektion «Saison-Termine» (vorher «Automatische Termine») zeigt Eröffnungs-/Endreinigungs-Termine aus `termine` am Termin-Tag — auch an Schliessungstagen; `uhrzeit_von` wird zum Zeitachsen-Anker. Abgleich ±7 Tage verdrängt den Auto-Vorschlag (gleiche Regel wie Aufgaben-Screen). Reine Funktion `saisonTermineFuerTag` (11 Tests, `test/termin_tourenplan_test.dart`).
- **Tagesplan-Block**: statt rotem «Betriebsferien»-Warnband ein graues Infoband «Letzter Ferientag — Eröffnung» / «Erster Ferientag/Schliessungstag — Endreinigung» (2 Widget-Tests).
- **Für Donnerstag angelegt:** Termin `eroeffnungsreinigung` Gasthof Löwen, 06.08.2026 (id `61555540-8807-472a-98b9-363f7812c647`) — direkt in DB, daher **ohne Google-Kalender-Push** (der läuft erst beim nächsten App-seitigen Termin-Ereignis mit).
- ⚠️ Visueller Browser-Check vor Deploy war nicht möglich (Browser-Pane ohne Anzeige, Login) — kompensiert durch Widget-Tests; **Live-Check Daniel am Handy offen**: Tourenplan Donnerstag 06.08. muss Löwen in «Saison-Termine» zeigen.

## 🔴 OFFEN: Nächste Schritte
- **Tourenplan v0.55.x/v0.56.0 — Live-Check Daniel am Handy:** (1) Zeitleiste prüfen (Blöcke/Fahrzeiten/Anker/Warnbänder), (2) **Arbeitstag-Karte auf dem Startbildschirm**: morgens «Jetzt starten» mit km-Stand → GPS-Abfrage erlauben; abends «Feierabend» mit End-km, (3) **Live-Modus am heutigen Tag**: nach einer abgeschlossenen Reinigung muss der Block grün mit «X min gemessen» erscheinen, rote Jetzt-Linie wandert im Minutentakt, gelbe frei-Fenster ab 3 min Leerlauf. End-zu-End-Test Edge-Function `fahrzeit-route` passiert automatisch beim ersten Plan mit unbekanntem Betriebspaar.
- **Kontakte-Übertragung Daniel (geplant 30.07.):** Alle Telefon-Kontakte in die App erfassen → syncen → in Google kontrollieren → erst DANN die alten Handy-Kontakte löschen (Reihenfolge wichtig; Sync löscht nur eigene «SBS App»-Karten, manuelle bleiben).
- **Auswertungen Arbeitstag/km (späteres Paket, Entscheid Daniel 29.07.):** km pro Tour, Stundenauslastung, Anfahrtskosten je Kunde — Daten werden seit v0.55.x erfasst (tagesplaene: arbeitsbeginn/arbeitsende, km_start/km_stand, Start-/End-GPS; `wegpunkte`-Tabelle für spätere Routen-Optimierung), Auswertung bewusst nicht gebaut.
- **Störung/Montage-Ist-Zeiten sind eine Annahme:** Im Live-Tagesplan gilt Ende = Wegpunkt-Stempel (Speichern-Zeitpunkt), Start = Stempel minus geplante Dauer. Falls das in der Praxis stört: echte Zeiterfassung (Beginn/Ende) für Störungen/Montagen nachrüsten.
- **Muloin-Fix (v0.51.2, 21.07.):** Eröffnungs-Hinweis erschien fälschlich, obwohl die Endreinigung (30.06.) schon IN den Ferien (26.06.–27.07.) lag. Regel jetzt wörtlich umgesetzt: jede Pausen-Reinigung — auch die Endreinigung selbst — unterdrückt Hinweis UND Auto-Termin; Uhr zählt ab Wiedereröffnung (Muloin: fällig 25.08.). Gilt auch für Winterbetriebe (kein Hinweis mehr vor Saisonstart, wenn die Endreinigung in der Pause lag — Entscheid Daniel 21.07.). Live-Check durch Daniel offen.
- **Live-Check Tourenplan v0.51.0 durch Daniel:** Fällig-Liste muss jetzt die Saison-Kunden zeigen (Stand 17.07. spätabends: 8 überfällig inkl. Tgantieni, 1 fällig Mountain Plaza, 2 bald fällig Waldhuus/Jschalp; 5 korrekt noch nicht fällig, weil erst kürzlich geöffnet — Soll = Saisonstart + Rhythmus).
- ~~Furt, Wangs~~ **ERLEDIGT 20.07.:** Anlage war demontiert (korrekt erfasst), nur der Betrieb stand noch auf aktiv → jetzt `inaktiv` mit Grund „Anlage demontiert" (inaktiv_seit 20.07., Demontage-Datum unbekannt). Falls Daniel das echte Demontage-Datum kennt: im Betriebs-Formular nachziehen.
- ~~Detailfrage Warnleiste~~ **ERLEDIGT 20.07. (v0.51.1):** Saisonpause-Betriebe werden jetzt auch gemeldet (Entscheid Daniel; operativ = aktiv+saisonpause, nur inaktiv/geschlossen aussen vor).
- **Warnleiste „Saisondaten fehlen" zeigt aktuell 15 Betriebe** — überwiegend Winter-Betriebe (Davos/Laax/Lenzerheide: Fuxägufer, Piz Piz, Frosch, Bolgenschanze, Il Pub, Indy Bar, Snake Bar, Acla Grischuna, Clubhotel, Dischma, Hotel Sport Klosters, Kartitscha, Obertor Parpan/Ilanz, Gemsli Mels), deren Endreinigung im Frühjahr war und deren **nächster Winterstart noch nicht eingetragen** ist. Daniel pflegt die Saisondaten nach, sobald bekannt — die Uhr startet dann automatisch; bis dahin erinnert die Leiste.

- **Saisondaten pflegen (nach dem Fix v0.54.18):** Die Tourenplanung liest ein leeres Datum jetzt als „offen" — fehlendes Ende = Saison läuft weiter, fehlender Start = hat schon begonnen (Entscheid Daniel 29.07.2026). Damit sind 35 still unsichtbare Betriebe wieder da. Sauber wird die Planung aber erst mit gepflegten Daten: **33 Betriebe** haben unvollständige Sommer-, **39** unvollständige Winterangaben. Betriebe ganz ohne Daten (z. B. Lenzerhorn, Weiss Kreuz Splügen, BARacca Vella) gelten dadurch als ganzjährig offen — falls das nicht stimmt, Saison eintragen.
- **Winterbetriebe mit Jahreswechsel-Saison:** 20 Betriebe haben ein Fenster wie 01.12.–01.04. Das versteht die App seit v0.54.18. ~~Bei einigen stehen beide Daten im selben Jahr~~ **Jahreszahlen am 04.08.2026 gerichtet** (alle 20 auf Ende im Folgejahr, siehe Eintrag im Ferien-Paket) — beim nächsten Saisonwechsel die Jahreszahlen weiterhin mitziehen.

---

## 🟢 Fälligkeit ab Saisonstart (live v0.51.0 · 17.07.2026) — Tgantieni-Fall behoben
Spec `docs/superpowers/specs/2026-07-17-faelligkeit-saisonstart-design.md`, Plan `docs/superpowers/plans/2026-07-17-faelligkeit-saisonstart.md`. Subagenten-getrieben (4 Tasks + Reviews), 442 Tests grün, keine DB-Änderung.

**Befund:** 17 Saison-Kunden waren bis 78 Tage wieder offen, ohne je im Tourenplan zu erscheinen. Drei Zahnräder: `eroeffnungFaellig` blieb nach Endreinigung FÜR IMMER (Saison-Prüfung kehrte früh zurück, Uhr lief nie an), der Standard-Filter zeigte nur überfällig+fällig, der Auto-Termin nur exakt am Eröffnungstag.

**Regel (Daniel):** Uhr-Anker = Wiedereröffnung, wenn der Betrieb nach der letzten Reinigung zu war (Saisonpause/Ferien; Ruhetage zählen nicht) — gilt für Endreinigung am Schluss UND Eröffnungsreinigung vor dem Start. Danach normale Stufen ab Anker + Rhythmus.

- Neu `faelligkeitsAnker()` in `touren_saison.dart` (7 Tests); `getFaelligkeit` nutzt den Anker für JEDE Service-Art (ersetzt den harten „Endreinigung+28"-Block), 7 Szenario-Tests (Tgantieni-Timeline).
- Eröffnungs-Hinweis nur noch im Fenster 7 Tage vor Start; entfällt automatisch nach einer Pausen-Reinigung (Service-Art-Wechsel).
- **Warnleiste „Saisondaten fehlen"** im Tourenplan (Endreinigung ohne gepflegten Saisonstart/Ferien-Ende → Uhr kann nicht starten), Muster der Rechnungs-Warnung, stumm bei 0.
- Standard-Filter zeigt jetzt auch Eröffnung/Endreinigung.
- Bekannte Grenze (Review, unkritisch): Bei Monats-Rhythmen kann das Soll 1–2 Tage später liegen als der Kalender-Trigger der DB (feste 60/90-Tage vs. Kalendermonate) — nie früher.

---
- **158 Mail-Betriebe ohne Rechnungsadresse-E-Mail** (Stand 16.07. nach Bereinigung; deren Rechnung geht bis zur Erfassung sichtbar an den Test-Empfänger). **Erledigt:** Die 14 Kandidaten mit `betriebe.email` sind abgearbeitet — 8 hat Daniel selbst erfasst (inkl. der Sonderfälle Blue Cinema/Swisscom, Clubhotel/Mountain Hotels, Piaggio Dosch), Concordia war schon versorgt, **5 Nicht-Kunden auf `heineken` umgestellt** (Alpensonne Arosa, Alpina Brigels, FC Schluein, Little Coffee, Sneki Bar — standen fälschlich auf `rechnung_mail`, hätten als Dialog-Vorbelegung eine Rechnung an Nicht-Kunden vorgeschlagen). Die 158 restlichen erfasst Daniel laufend beim Abschluss (der neue Dialog bietet Warnung + Feld).
- ~~Live-Test v0.50.0~~ **ERLEDIGT 17.07. im Echtbetrieb:** 10 Reinigungen (7 Tresen/Mail → Rechnung+Debitor, 1 Bar → Kasse, 1 Heineken → korrekt nichts, 2 Mail), alle mit fixierter `zahlungsart` auf der Reinigung, alle Beträge auf 5 Rappen, DB-verifiziert. Keine Fehler beobachtet, Warnung leer. Kein Test-Rollback nötig (echte Daten).

---

## 🟢 Zahlungsart pro Reinigung (live v0.50.0 · 16.07.2026) — Ursache der 38 BEHOBEN
Spec `docs/superpowers/specs/2026-07-16-zahlungsart-pro-reinigung-design.md`, Plan `docs/superpowers/plans/2026-07-16-zahlungsart-pro-reinigung.md`. Subagenten-getrieben (8 Tasks, je Spec- + Qualitäts-Review, Final-Review vor Deploy), 428 Tests grün, Migration 144 auf Prod.

- **Kern:** `reinigungen.zahlungsart` wird beim Abschluss fixiert und ist via `resolveZahlungsart()` ALLEIN massgebend für Buchung, Rechnung, Versand, Detail-Recovery, PDF-Fusszeile und Detail-Anzeige. Betriebs-Wert = nur noch Default/Fallback für Altbestand (NULL).
- **Abschluss-Dialog:** Betrieb wird FRISCH geladen (der Cache-Fall der 4 vom 13.07.); Checkbox „Auch als Standard übernehmen" (default AUS — der stille Rückschreib-Effekt ist weg); Klartext-Zeile, was der Abschluss auslöst (rot bei Mail ohne E-Mail); Rechnungs-E-Mail direkt erfassbar (legt Rechnungsadresse vorbefüllt an — Versand läuft NUR über `betrieb_rechnungsadressen.email`, `betriebe.email` ist Info).
- **QR-Tab** trägt bei Rechnungsarten dieselbe SCOR-Referenz wie die Rechnung (byte-identisch gegen Live-DB verifiziert: RF32202606260476) → spontane Direktzahlung camt-zuordenbar. Bar bleibt referenzlos.
- **Warnung:** Entscheidung als getestete reine Funktion `warnungsGrund()` — Kasse-Buchung (1000) = bar erledigt (die 10 Fehlalarme weg), NEU auch „ohne Buchung"-Check (fängt die Durchfall-Klasse selbst). Live-Verify: 0 Treffer.
- **Suchlauf 1:** 0 verlorene Reinigungen seit 01.12.2025 — nichts offen.
- **Review-Funde gefixt:** Doppeltap-Guard im Abschluss (Critical — hätte Doppelrechnung erzeugt), Retry behält User-Wahl, E-Mail-Speicherfehler sichtbar, Label im Korrektur-Service, Perf (Betrieb-Fetch ~856→~280), 2 Display-Lecks (Detail + Protokoll-PDF zeigten Betriebs- statt fixierter Art).
- **Rest-Grenze (bewusst):** Wählt man im Dialog absichtlich `heineken` für einen Nicht-Heineken-Betrieb, greift nur die Klartext-Warnung im Dialog (Warnung flaggt heineken nicht — by design, Spec Abschnitt 4).

---

## 🟢 Ursache der 38 fehlenden Rechnungen — GELÖST (16.07.2026, Hinweis Daniel)
Nach 6 widerlegten Hypothesen brachte Daniels Hinweis („ich habe einige Änderungen an der Zahlungsart vorgenommen") die Lösung: **34 der 38** Reinigungen passierten, als die Betriebe noch `rechnungsstellung='heineken'` hatten (Serie erst am **10.07.** auf Tresen umgestellt) — `heineken` fiel in Buchungs- UND Rechnungs-Service lautlos durch (`return null`: keine Rechnung, keine Buchung, keine Ausnahme, keine Sequenznummer). **Die restlichen 4** (13.07.: Surselva 2×, Hotel Chur, Espresso Bar) nutzten den veralteten Formular-Cache statt des frischen DB-Werts (Betriebe waren schon Tresen). Erklärt auch, warum die Reproduktion am 15.07. scheiterte: dieselben Betriebe, aber NACH der Umstellung mit frischem Cache. Behoben durch v0.50.0 (Zahlungsart pro Reinigung, frischer Betrieb im Dialog).

---
- **10 Reinigungen ohne Rechnung entscheiden (~CHF 1'011)** — die neue Warnung zeigt sie beim ersten Öffnen. Sartons Valbella (3×), Dieschen (2×), Rössli Cham (2×), Seerestaurant Immensee (2×), Central Bad Ragaz. Leistungen Dez 2025 – Apr 2026, alle Tresen, **alle im April nacherfasst** (`created_at` 22.–27.04. bei Leistungsdatum Monate davor) → eigenes Muster, nichts mit den 38 zu tun. **Daniel entscheidet, ob noch verrechnet wird** — nichts angefasst.
- **camt-Test fortsetzen:** 🟡 Manuell (v. a. Davos Klosters → Routing über `heineken_nr`, 0151 = Armando Klosters), ⚪ Nicht zugeordnet, Übriges (Buchung müsste seit Migration 140 gehen).
- ~~Backups aufräumen~~ **ERLEDIGT 21.07. (Migration 147):** Alle 11 `_bak_*`-Tabellen gelöscht (OK Daniel). Anlass war die Supabase-Sicherheitsmail vom 20.07. („Table publicly accessible"): Die Backups hatten kein RLS und waren via API mit dem Anon-Key lesbar — erst mit Migration 145 abgedichtet, dann gelöscht. Zusätzlich Migration 146: alle 8 Views auf `security_invoker` (vorher umgingen sie RLS; anon konnte z. B. `view_offene_rechnungen` komplett lesen — jetzt verifiziert 0 Zeilen für anon, eingeloggt unverändert). **Merkregel:** Nach `CREATE TABLE _bak_... AS` immer sofort `ENABLE ROW LEVEL SECURITY`. Offen (nur WARN-Stufe, unkritisch): 21 Funktionen ohne fixen `search_path`, 3 Extensions im public-Schema, Listing-Policy `raster-pdfs`, HaveIBeenPwned-Schutz aus.
- **`kAppVersion` in `core/app_version.dart` bei jedem Version-Bump mitziehen** (manuell, Duplikat zu `pubspec.yaml` Zeile 4). Steht jetzt im Forderungen-Titel — wenn er nicht zur erwarteten Version passt, läuft alter Code.

---

## 🟢 Warnung „Reinigungen ohne Rechnung" (live v0.49.0 · 15.07.2026)
Die Antwort auf einen Fehler, den wir nicht finden konnten — und deshalb die einzige, die trägt: Sie fragt **nicht nach dem Warum**, sondern zeigt, **dass** eine Rechnung fehlt. Wirkt bei jeder Ursache, auch bei einer, die nie verstanden wird. Hätte aus drei Wochen und CHF 3'656 einen Tag und eine Reinigung gemacht.

- `services/rechnung/reinigungen_ohne_rechnung.dart` + `reinigungenOhneRechnungProvider`, rote Leiste in den Forderungen, antippen → Liste.
- **Stumm, solange nichts fehlt** — eine Warnung, die immer leuchtet, wird ignoriert. Deshalb Stichtag **01.12.2025** + `quelle != 'excel_import'`: die 1519 Excel-Zeilen sind über den Voll-Import abgedeckt und hätten sie dauerhaft auf Alarm gestellt.
- **Meldet, repariert nicht** (Vorgabe Daniel): Nachholen über das Rechnungs-Menü im Reinigungs-Detail.
- Positionen werden gezielt in 200er-Blöcken abgefragt (`inFilter`) — **nie** `select()` über die ganze Tabelle (1000-Zeilen-Limit, siehe unten).
- **Version im Forderungen-Titel** (`Forderungen · v0.49.0`) — dass stundenlang nicht feststellbar war, welcher Code im Browser läuft, hat am 15.07. drei Fehldiagnosen verursacht.
- Temporärer Nachtrag (Service + Menüpunkt + Dialog) wieder entfernt, wie zugesagt.

---

## 🟢 38 fehlende Tresen-Rechnungen nachgetragen (15.07.2026, CHF 3'656.05)
Ausgelöst durch Daniels Frage, warum die Reinigung Alpenblick Arosa (26.06.) nicht in den Forderungen steht. Alle 38 sind erledigt: 0 krumm, 0 Abweichung zur Reinigung, Summe 3'656.05 = 3'656.05, `versendet_am` = Reinigungsdatum (bei Tresen wird die Rechnung vor Ort abgegeben), QR-Referenz identisch mit der, die sie am Reinigungstag bekommen hätten (hängt nur an Datum + Betriebnummer). PDF stichprobenweise geprüft: 138.35. Keine Doppelbuchung (`createFromReinigung` bucht nicht).

**Zwei eigene Fehler, beide vom Trockenlauf gefangen — nicht von Tests oder Analyse:**
1. **v0.48.0 zeigte 45 statt 38.** Die bereits verrechneten Reinigungen wurden mit EINEM `select()` über `rechnungs_positionen` geladen → PostgREST liefert max. 1000 Zeilen, bei 4971 blieben 3971 unsichtbar und galten als unverrechnet. 7 Reinigungen mit bestehender Rechnung standen auf der Liste → ein Klick hätte 7 **Doppelrechnungen** erzeugt. Gefixt: gezielte Abfrage per `inFilter` + Einzelcheck unmittelbar vor jedem Anlegen.
2. **30 von 38 Rechnungen krumm** (74.59 statt 74.60) — siehe nächster Abschnitt.

---

## 🟢 Rundung: Der Rechnungsbetrag kommt vom TRIGGER, nicht von der App (Migration 143 · 15.07.2026)
**Der teuerste Irrtum des Tages.** `update_rechnung_summen()` auf `rechnungs_positionen` summiert `betrag_brutto` bei JEDEM Positions-Insert aus den Positionen und überschreibt damit den App-Wert (App schrieb 138.35, Trigger machte 138.37 daraus).

Deshalb waren **Migration 139** (Reinigungs-Trigger, 14.07.) und der **Dart-Fix in `rechnung_service`** (v0.48.2) beide wirkungslos — sie sassen auf der falschen Ebene. Mein Backfill vom 14.07. hat nur Symptome beseitigt; der Nachtrag reproduzierte den Fehler prompt.

**Vier falsche Diagnosen, bis der Trigger gefunden war:** Sequenz-Kollision, Referenz-Kollision, `kIsWeb`, Service-Worker/Cache. Beweislage, die keinen Sinn ergab: `vorschauBrutto` zeigte 138.35, der Insert schrieb 138.35 (RETURNING), Hash lokal == gh-pages == live — und die DB hatte 138.37. Auflösung: Ich hatte nur Trigger auf `rechnungen` geprüft, nie auf `rechnungs_positionen`.

**Regel (Daniel):** Kundenrechnungen IMMER auf 5 Rappen, **nur `heineken_monat` ungerundet**. Migration 143 setzt das im Trigger um (MwSt aus dem gerundeten Brutto abgeleitet → Netto + MwSt = Brutto exakt). Die 38 wurden dadurch in der DB selbst korrigiert, ohne neuen Lauf.

**Die Dart-Rundung bleibt nötig:** Das PDF entsteht aus dem Rechnungs-Objekt VOR dem Trigger. Beide Seiten runden jetzt gleich, sonst laufen PDF und Datenbank auseinander. Zentral in `core/util/rundung.dart` (9 Tests) statt wie bisher 5× dupliziert — und die alten Kopien rundeten ausgerechnet erst bei der **Anzeige** (`rechnungen_list_screen:853`, `rechnung_detail_screen:269`): gespeichert 74.59, angezeigt 74.60. Genau deshalb war der Fehler monatelang unsichtbar.

**Lehre fürs Nächste:** Bei falschen Werten in der DB zuerst fragen, WER den Wert schreibt — App, Trigger auf der Zieltabelle, oder Trigger auf einer abhängigen Tabelle. Und: Sichtbarkeit (Versionsanzeige, Betragsvorschau) hätte die Frage in Minuten statt Stunden beantwortet.

---

## 🟢 Material abgeholt → Bestände in einem Klick (live v0.47.0 · 15.07.2026 — Live-Test durch Daniel ausstehend)
Spec `docs/superpowers/specs/2026-07-15-material-abgeholt-bestand-design.md`, Plan `docs/superpowers/plans/2026-07-15-material-abgeholt.md`. Subagenten-getrieben, 400 Tests grün, 0 Analyze-Fehler.

- **Neue Bestellungen-Liste** `/materialien/bestellungen` (AppBar-Icon 🧾 auf `/materialien`). Schliesst die Lücke, dass gesendete Bestellungen + ihre PDFs bisher **gar nicht mehr auffindbar** waren (`getAll()`/`getById()` waren toter Code). Status-Badge, PDF öffnen, aufklappbar mit „bestellt X · erhalten Y".
- **„Material abgeholt"** (nur bei Status `gesendet`) → Kontroll-Dialog: nach Kategorie gruppiert wie die Bestellung, Checkbox links (default an), Menge vorbefüllt + korrigierbar, Freitext-Positionen ohne `lager_id` ausgegraut → **„Bestände buchen"**. Stimmt alles: einfach bestätigen.
- **„Buchung rückgängig"** (bei `abgeholt`) → Bestände zurück, Status wieder `gesendet`.
- **Restmengen** brauchen keine Extra-Mechanik: der Artikel bleibt unter Mindestbestand und steht via Generated Column `bestand_niedrig` automatisch wieder auf der nächsten Bestellliste. Teillieferungs-Verfolgung bewusst NICHT gebaut (YAGNI).
- **Migration 141:** Status `abgeholt`, `abgeholt_am`, `menge_erhalten numeric(10,2)` + zwei **atomare RPCs** (`material_bestellung_abholen`/`_rueckgaengig`, SECURITY INVOKER, relatives `bestand_aktuell + delta`).

**Wichtigster Fund im Review:** Der Status-Guard war zuerst ein nacktes `SELECT` → TOCTOU-Race: zwei gleichzeitige Aufrufe (Doppeltap) hätten beide passiert und die Bestände **doppelt gezählt** (lautlos, Rückgängig nimmt nur die Hälfte). Gefixt mit `FOR UPDATE` auf der Bestellzeile. Zusätzlich geschlossen: stille Null-Buchung bei falschen `p_mengen`-Keys, stiller 0-Zeilen-Update bei nicht zugreifbarer `lager_id`, ungeschützter Positions-Ladefehler (Netz weg im Heineken-Lager), und „angehakt aber nicht gebucht" bei Komma-Eingabe (Gboard liefert `1,5`).

**Bekannte Grenzen (bewusst):** `digitsOnly` im Mengenfeld → keine Dezimalmengen (deckt sich mit dem bestehenden Bestell-Screen); `GREATEST(0,…)` beim Rückgängig klemmt lautlos bei 0; `p_mengen=NULL` würde den Key-Guard umgehen (vom Dart-Client aus unmöglich, da `abholPayload` immer eine Map liefert).

**Offen:** Live-Test durch Daniel (siehe Plan, Task 7 Step 9).

---

## 🟢 camt-Test 15.07. zurückgerollt — Gelerntes BLEIBT (Abend 15.07.2026)
Rollback ausgeführt und verifiziert: camt-Buchungen 0, Rechnungs-Status auf Baseline (bezahlt 3508), camt-Dateien 12, Prüfliste 4 mit zurückgesetztem Status.
**Bewusst erhalten (Entscheid Daniel):** 4 gelernte Zahlernamen (`betriebe.zahler_aliase`) UND 16 camt-Regeln (14 Baseline + 2 neue) — beides ist Wissen, das jeden weiteren Import einfacher macht. Die 38 nachgetragenen Rechnungen hat das Rollback nicht angefasst (Versanddatum intakt).
Runbook: `scratchpad/ROLLBACK_camt_20260715.md`.

**Neu an der Prüfliste (v0.47.2):** „Regel anlegen" befüllt die IBAN vor (Migration 142: `camt_pruefliste.partei_iban` + `beleg_ref` — der Parser las sie, die Tabelle speicherte sie nie) und **bucht die Zahlung mit** („Speichern & buchen"). Das ist nötig, nicht bequem: `bereitsVerarbeitet` enthält ALLE Prüflisten-txKeys unabhängig vom Status → die Transaktion ist dauerhaft blockiert, eine neue Regel hätte sie NIE erfasst; bloss ausblenden = Zahlung still nie gebucht. Ausserdem: IBAN-Vergleich normalisiert (`RegelMatcher.normIban`) — eine gruppiert eingetippte IBAN („CH04 3000 …") hätte vorher nie gematcht.
**Zu wissen:** Sind Name UND IBAN gesetzt, gilt **oder**, nicht und — die Regel feuert schon beim Namens-Treffer.

---

## 🟢 camt-Abgleich Verbesserungs-Paket (LIVE v0.46.26 · 14.07.2026 — Test-Daten zurückgerollt, Re-Test morgen)
Ganztägige Iteration am camt-Kundenzahlungs-Abgleich (v0.46.21 → v0.46.26), TDD (28 camt-Tests grün). **Test-Buchungen abends komplett zurückgerollt** (8 Buchungen gelöscht, 7 Rechnungen auf Baseline, 6 gelernte Aliase + 9 camt_dateien + 1 Prüflisten-Eintrag entfernt) — DB sauber am Baseline, bereit für Re-Test.

**Umgesetzt & live:**
1. **Matcher-Härtung:** Auto NUR bei QR/SCOR-Referenz + exaktem Namen + gelerntem Alias; alle unscharfen Namens-Treffer → manuell (kein Fehl-Auto wie „Edelweiss Davos AG" → Vals; kein Alias-Festschreiben).
2. **Zahlungseingänge nach Datum absteigend** (Manuell-Dialog + ⚪-Liste).
3. **Vermerk-Parser** (`vermerk_parser.dart`, TDD): erkennt (a) Rechnungsnummer `YYYY-MM-NNNN` (Bindestriche, direkter Forderungs-Match), (b) **Betriebnummer** `NNNN_yyyy_MM_dd` (Davos Klosters, z. B. `0151_2026_04_04` = Heineken-Nr 0151 = Armando) → Routing über `matchByNummer` inkl. **`heineken_nr`**, Datum wählt Forderung vor. Nur Vorauswahl, kein Auto.
4. **Mehr Zahlungs-Infos** (Einzahler/Adresse/Bemerkung) + **PDF-Link** zur erfassten Rechnung (Manuell/⚪) bzw. Beleg (Übriges/Kreditor).
5. **Nicht-zugeordnet gruppiert** nach Einzahler (Ausnahme Davos Klosters/Weisse Arena einzeln); Gruppen-Kopf tippbar → **Mehrfach-Zahlungen + Suche**-Dialog.
6. **Migration 139** (Rundungs-Trigger 5-Rappen, Backfill Live-Periode) + **Migration 140** (`beleg_typ='camt053'` erlaubt → Übriges-Buchung ohne PostgrestException).

**Offen / morgen (Re-Test):**
- Prüfen: routen die 3 „Davos Klosters"-Zahlungen jetzt via `heineken_nr` zum richtigen Betrieb? Falls welche in „Nicht zugeordnet" bleiben → **genaue Bemerkung** an Claude (drittes Format).
- Optional: Davos Klosters/Weisse Arena auch als tippbare Gruppe (Mehrfach-Dialog) statt einzeln — 1-Zeiler, auf Wunsch.
- Reparaturplan Buchhaltung (Excel-Zahlungen/camt-Import) via `/buchhaltungsplan` — nach abgeschlossenem camt-Test.

---

## 🟢 Karten-Hintergrund + Handy-Standort (live v0.26.1–v0.26.4 · 10.07.2026)
- [x] ✓ Umschalter **Luftbild ↔ Strassenkarte** (swisstopo) in Betriebe- + Event-Karte (kostenlos/legal, kein Google-Tile-ToS-Verstoss).
- [x] ✓ **Handy-Standort** als blauer Punkt + weiss/blauer „Mein Standort"-Zentrier-Button; Filter „Inaktive/geschl." entfernt (inaktive/geschlossene auf der Karte generell ausgeblendet).

---

## 🟢 Betrieb-Lifecycle & Auto-„mein Kunde" (live v0.26.0 · 10.07.2026)
- [x] ✓ **Auto-„mein Kunde"**: reine Funktion `istMeinKundeVorschlag(status, zapfsysteme)` — inaktiv/geschlossen → false, sonst Konventionell/Orion → true. Greift im Formular bei Status-/Zapfsystem-Wechsel (manueller Override bleibt).
- [x] ✓ **Bereinigung (Migration 127)**: Clavadeleralp & Weissfluhjoch (Saisonbetriebe, fälschlich inaktiv) → aktiv; AMERON, Valentinos + 104 geschlossene → mein Kunde=false. Saisonbetriebe geschützt.
- [x] ✓ **Dauerhafte Schliessung**: Status „geschlossen" im Formular + Schliessungsgrund (Umnutzung/Abbruch/Konkurs/Sonstiges) + -datum; im Detail angezeigt.
- [x] ✓ **Sichtbarkeit**: Betriebe-Liste default nur aktive; Karte nur aktive/saisonpause + Filter-Chip „Inaktive/geschl.".
- [x] ✓ Qualität: subagent-getrieben, neue TDD-Suite (7 Tests), **263 Tests grün**, Web-Build sauber.
- [x] ✓ **Live geprüft** (10.07.2026): Formular-Auto-„mein Kunde" + Override, Schliessungsfelder, Liste/Karte-Sichtbarkeit — alles funktioniert.

---

## 🟢 Öffnungszeiten von Website (live v0.35.0 · 11.07.2026)
- [x] ✓ **AI-Website-Fallback für Öffnungszeiten:** Google Places hat für viele kleine Betriebe keine Öffnungszeiten (verifiziert: Pagigerstübli → Adresse/Tel/Website/Koordinaten ja, aber keine `regularOpeningHours`). Neuer Button **„Öffnungszeiten von Website"** im Betrieb-Formular → Edge-Function `parse-oeffnungszeiten` liest Startseite + Kontakt-/Öffnungszeiten-Unterseiten, Claude extrahiert Öffnungszeiten + Ruhetage ins App-Format → derselbe Bestätigungs-Dialog wie bei Google (Häkchen). Reine Funktion `oeffnungszeitenAusWebsiteJson` (TDD, 3 Tests). Smoke-Test Pagigerstübli: Mi–Sa 09–22, So 09–21, Ruhetage Mo+Di (Konfidenz 1). **🟡 Offen:** an weiteren Betrieben mit Öffnungszeiten-Seite durchprobieren; ggf. Prompt nachschärfen bei Mittagspausen/Sonderzeiten.

---

## 🟢 Betrieb-Paket (live v0.25.0 · 10.07.2026)
- [x] ✓ **B — kundenabhängige Felder:** Rechnungsstellung + Zahlernamen erscheinen im Formular und Detail nur bei „mein Kunde".
- [x] ✓ **A — Google-Datenübernahme:** Button „Aus Google übernehmen" im Betrieb-Formular → Bestätigungs-Dialog (alle Häkchen default an) → übernimmt Adresse/Telefon/Website/Koordinaten/Öffnungszeiten. Edge-Function `betrieb-google-lookup` deployed (Key server-seitig).
- [x] ✓ **C — Betriebe-Karte:** Umschalter Liste↔Karte, Marker farbig nach Fälligkeit (schlimmste Anlage), Filter (meine Kunden/Region/nur fällige), Legende, Popup „Öffnen"/„Route", Zähler „X ohne Standort" → Formular.
- [x] ✓ **D — Route:** „Route in Google Maps"-Button im Betrieb-Detail und im Karten-Popup.
- [x] ✓ Qualität: subagent-getrieben, 3 neue TDD-Suites, **256 Tests grün**, Web-Build sauber.
- [x] ✓ **Google-API-Key gesetzt** (10.07.2026): `GOOGLE_PLACES_KEY` als Supabase-Secret hinterlegt, Edge-Function per echtem Testbetrieb verifiziert (Adresse/Telefon/Website/Koordinaten/Öffnungszeiten kommen zurück). Baustein A produktiv.

---

## 🟢 Events-Modul scharfgestellt + Testdaten weg (v0.23.1 · 10.07.2026)
- [x] ✓ **Testdaten gelöscht:** Event „Openair Val Lumnezia 2026" (+2 Kontakt-Zuordnungen, 3 Stände, 5 Anlagen, 5 Einsätze, 5 Aufwand-Zeilen) per Cascade entfernt; 2 Test-Lager-Abbuchungen zurückgebucht. Globale Kontakte bleiben.
- [x] ✓ **Abschluss-Mail scharfgestellt:** `eventScharf = true` in `mail_config.dart` — Abschlussbericht geht jetzt an die echten Empfänger (Eventverantwortlicher/RSL). **Events-Modul E1–E5 + Feinschliff produktiv.**

---

## 🟢 Events-Feinschliff 2 (live v0.23.0 · 10.07.2026)
- [x] ✓ **Einsatz-Formular:** Stand-Auswahl ganz oben; **ein** Material-Feld (Autocomplete mit Freitext-Option oben + Lager-Artikeln), Menge nur bei Lager-Artikel. Verwendetes Material (Lager oder Freitext) wird immer gespeichert.
- [x] ✓ **PDF:** verwendetes Material der Pikett-Einsätze inkl. Menge in der Einsatz-Tabelle.
- [x] ✓ **Stand-Kontakt:** bei „Kontakt zuordnen" mit Rolle „Stand" ist der konkrete **Stand auswählbar** (Migration 125: `event_kontakte.stand_id`); die Stand-Karte zeigt den zugeordneten Kontakt (Name · Tel) direkt an.
- [x] ✓ Qualität: subagent-getrieben (3 + Verifikation), finaler Review **APPROVED**, 244 Tests grün.
---

## 🟢 Events-Feinschliff (live v0.22.0 · 10.07.2026)
- [x] ✓ **„Montage generieren"** vom Zeit-Tab ins **3-Punkte-Menü** oben rechts verschoben (Zeit-Tab zeigt nur noch Total-Chip).
- [x] ✓ **PDF-Vorschau vor Versand** im Abschluss-Sheet (Button „PDF-Vorschau", `Printing.layoutPdf`).
- [x] ✓ **Professionelleres Abschluss-PDF** (dunkle Sektions-Header, Zusammenfassungs-Box, Zebra-Tabellen mit dunkler Kopfzeile, Fußzeile mit Datum + Seitenzahl).
- [x] ✓ **Material↔Lager im Pikett-Einsatz** (Migration 124: `event_einsaetze.material_id` + `material_menge`): Lager-Artikel per Autocomplete + Menge; Bestand (`bestand_aktuell`) wird **beim Anlegen** abgebucht (keine Storno-Automatik bei Bearbeiten/Löschen). Freitext-Material bleibt.
- [x] ✓ Qualität: subagent-getrieben (5 + Verifikation), finaler Review **APPROVED**, 244 Tests grün, visuell geprüft (Menü, Vorschau-Button).
---

## 🟢 Events-Modul — Phase E5 (live v0.21.0 · 10.07.2026) — Events-Modul E1–E5 KOMPLETT
Spec `docs/superpowers/specs/2026-07-10-events-e5-design.md`. **Abschluss-Mail** nach dem Event:
- [x] ✓ **Abschlussbericht als PDF** (ohne CHF): Zusammenfassung (Stände/Anlagen-in-Betrieb/Einsätze/Total-Std), Stände mit Anlagen + Inbetriebnahme, Zeit & Aufwand gruppiert nach Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen), Pikett-Einsatzliste. Sonderzeichen (`✓`/`–`/`—`) auf ASCII sanitisiert (Helvetica-Font).
- [x] ✓ **Empfänger-Sheet** (Menüpunkt „Abschluss-Mail senden" im 3-Punkte-Menü): Eventverantwortlicher (`event_heineken`) + RSL automatisch vorgeschlagen, mit E-Mail vorangehakt, ohne E-Mail ausgegraut; weitere Kontakte + freie Mail-Adresse; Versand kommasepariert in einem Aufruf (`send-pdf-mail`).
- [x] ✓ **Scharfstellung:** neuer MailConfig-Bereich `event` (`eventScharf=false`) → Testmodus geht an dich (dani.proyer@gmail.com), Sheet zeigt Hinweis. Keine DB-Migration.
- [x] ✓ Qualität: subagent-getrieben (6 Tasks), finaler Branch-Review **APPROVED**, 244 Tests grün (7 neue). Visueller Web-Test: Menü → Sheet mit RSL-Vorschlag (beat.joerg@heineken.com vorangehakt) + Testmodus-Hinweis, PDF fehlerfrei gebaut.

---

## 🟢 Events-Modul — Phase E4 (live v0.20.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e4-design.md`. Event-Detail jetzt mit **5 Tabs** (Kontakte | Stände | Einsätze | **Zeit** | Dokumente):
- [x] ✓ **Zeit-/Spesenerfassung** (neue Sync-Vertikale `event_aufwand`, Migration 123): Zeilen mit Datum + Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen) + Notiz + Stunden. Neuer Tab „Zeit" mit Total-Stunden-Chip, Erfassungs-Formular, Bearbeiten/Löschen. Spesen werden als zusätzliche Stunden verrechnet (kein CHF-Feld).
- [x] ✓ **Auto-Montage-Generierung**: Button „Montage generieren" aggregiert die Zeit-Zeilen **pro Eventtag** (≤5 Slots, >5 Tage → 4 Tage + „Weitere Tage") und öffnet das bestehende Montage-Formular **vorbefüllt** (Typ Anlass, Betrieb = Veranstaltungs-Betrieb, Startdatum, Slots, Stundensatz aus Preisliste). Du prüfst + speicherst → normaler Heineken-Abrechnungsfluss. Pikettdienst ist ein eigener Zeitblock; die E3-Einsätze bleiben reine Doku (nicht separat verrechnet).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks + Migration), finaler Branch-Review **APPROVED**, 237 Tests grün (5 neue: DTO + 4 Aggregation). Visueller Web-Test: 5 Tabs, Zeit erfassen/Total, „Montage generieren" → Formular korrekt vorbefüllt (Fr 10.7. 16h · Fr 24.7. 8.5h → 24.50h × 80 = 1960 CHF).
- [x] ✓ **UI (v0.20.1):** Event-Tabs füllen die Breite gleichmäßig (kein Scrollen mehr auf dem Handy / Pixel 9), kompaktere Label-Abstände.
- [x] ✓ **GPS-Fix (v0.20.2):** „Standort erfassen" warf im Web `MissingPluginException` — Ursache war ein veralteter Web-Plugin-Registrant ohne `geolocator_web` (Build-Cache). Fix: `flutter clean` + Neubau (Registrant enthält geolocator wieder). Zusätzlich `ACCESS_FINE/COARSE_LOCATION` in `AndroidManifest.xml` ergänzt (für native Builds).

**Nächste Phase:** **E5** Abschluss-Mail (Einsatzliste + Zeiten/Spesen als PDF an Eventverantwortlichen + RSL, MailConfig-Bereich `event`, erst Test dann scharf) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E3 (live v0.19.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e3-design.md`. Event-Detail jetzt mit **4 Tabs** (Kontakte | Stände | Einsätze | Dokumente):
- [x] ✓ **Inbetriebnahme pro Anlage**: Live-Checkbox „in Betrieb" je Schankanlage in der Stand-Karte + Fortschritt-Chip („3/8 in Betrieb" / „✓ komplett"). Stand-Formular speichert Anlagen jetzt **id-basiert** (behält `in_betrieb`/`in_betrieb_am` beim Bearbeiten statt löschen+neu).
- [x] ✓ **GPS-Standort pro Stand** (`geolocator`): Button „Standort erfassen" an der Stand-Karte, einmaliger `getCurrentPosition` (LocationAccuracy.high), Web + native.
- [x] ✓ **Karten-Umschalter im Stände-Tab** (Liste ↔ Karte): `flutter_map` mit **swisstopo-Luftbild** (SWISSIMAGE WMTS, kein API-Key), Marker pro Stand mit GPS, Tap → Stand. Repaint-Nudge (onMapReady move) gegen CanvasKit-Grau-Kacheln.
- [x] ✓ **Einsätze-Tab** (Pikett): minimales Formular (Beschreibung*, Material-Freitext, optionaler Stand, Zeitpunkt=jetzt/editierbar), Liste neueste zuerst, bearbeiten/löschen. Volle Sync-Vertikale `event_einsaetze` (Migration 122). Grundlage für E4-Abschluss-Mail.
- [x] ✓ Qualität: subagent-getrieben (12 Tasks), finaler Branch-Review **APPROVED** (kritischer id-basierter Stand-Save geprüft), 232 Tests grün. Visueller Web-Test: Karte rendert swisstopo sofort, Marker bei Vella; Einsatz anlegen→DB→Liste→löschen; 4 Tabs + FAB-Index korrekt.
- [ ] **🟡 Testdaten aufräumen:** Stand **Signina Bar** hat für den Karten-Test gesetzte GPS-Koordinaten (46.7355 / 9.1378, Vella) — vor Ort neu erfassen/überschreiben.

**Nächste Phase:** **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E2 (live v0.18.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-10-events-e2-design.md`. Event-Detail jetzt mit **3 Tabs** (Kontakte | Stände | Dokumente):
- [x] ✓ **Stände** pro Event-Jahr mit **Schankanlagen** (Typen: Oberthekengerät/OT, Hollandbuffet, Ausschankwagen, Sonstige) — dynamische Anlagen-Zeilen im Stand-Formular, Zusammenfassung „7× OT · 1× Hollandbuffet". Vorjahres-Übernahme (Checkbox im Event-Formular + Menü im Tab, Merge case-insensitive über Stand-Namen).
- [x] ✓ **Dokument-Ablage** pro Event-Jahr: PDF hochladen (Lageplan, Verteilung …) in privaten Storage-Bucket `event-dokumente`, ansehen (signed URL, PDF-Viewer), löschen. Migration 120 (3 Tabellen + Bucket + RLS).
- [x] ✓ Qualität: subagent-getrieben (10 Tasks), finaler Branch-Review **APPROVED** (kritischer Tab-Umbau: Kontakte-Tab unverändert; serverId→Anlagen-Kette + Native-Delete W1 sauber), 228 Tests grün (4 neue). Visueller Web-Test: Tabs, Stand+Anlagen anlegen, Dokumente-Tab bestätigt.

**Nächste Phasen:** **E3** Inbetriebnahme-Checkliste + GPS-Standorte der Stände + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (Stand + Beschreibung + 1 Material) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`) · *optional* Verteilung-PDF-KI-Import.

---

## 🟢 Events-Modul — Phase E1 (live v0.17.0 · 10.07.2026)
Spec `docs/superpowers/specs/2026-07-09-events-e1-design.md`, Plan + Ablauf-Kontext `Prompts/07_Events_Ablauf.txt`. Neues Modul: Dashboard-Kachel **Events** → Event-Jahre («Albani Fest 2026»):
- [x] ✓ **Event-Jahr-Entität** (`events`, Migration 119): referenziert Veranstaltungs-Betrieb (zapfsysteme `Veranstaltungen`), Jahr + Termin, Status abgeleitet (kommend «in X Tagen»/laufend/vorbei/Termin offen). Abrechnung bleibt unverändert bei Montage «Anlass».
- [x] ✓ **Kontaktliste pro Event-Jahr** (`event_kontakte`): Rolle auf der Zuordnung (Eventverantwortlicher, RSL, OK, Bau, Stand, Monteur, Stardrinks, Sonstige), Bemerkung, Gruppierung; Kontakte bleiben globale Personen. **Vorjahres-Übernahme** (Checkbox beim Anlegen + Menü, Merge ohne Duplikate).
- [x] ✓ **WhatsApp + Anruf** direkt aus der Liste (wa.me mit CH-Normalisierung, getestet: +41 79 885 20 88 → wa.me/41798852088).
- [x] ✓ Qualität: subagent-getrieben (9 Tasks, je Spec-+Qualitäts-Review), finaler Branch-Review APPROVED, 224 Tests grün (15 neue), visueller Web-Test komplett (Anlegen, Zuordnen, Übernahme, Löschen). Review-Fixes W1+W2 umgesetzt (Native-Delete serverseitig; `KontaktRepository.save` generiert jetzt Client-UUID).
- [ ] **🟡 Bekanntes Verhalten (Multi-Device, W3):** Legen zwei Geräte offline dasselbe Event-Jahr an, scheitert der zweite Push am UNIQUE-Constraint dauerhaft still (`isSynced=false` bleibt). Bei Ein-Personen-Nutzung akzeptabel; fixen falls je zweites Gerät aktiv schreibt.

**Nächste Phasen:** **E2** Lageplan-PDF + Stände + Anlagen pro Stand (Beispieldateien in `00_Event/`, nicht versioniert) · **E3** Inbetriebnahme + GPS-Standorte + Karten-Tab (flutter_map + swisstopo-Luftbild, kein API-Key) + Pikett-Einsätze (1 Material-Slot) · **E4** Abschluss-Mail (Einsatzliste als PDF an Eventverantwortlichen + RSL + optional, MailConfig-Bereich `event`).

---

## 🟢 App-Optimierung — Paket 06 (P1 Quick-Wins, live v0.16.20 · 07.07.2026)
Optimierungspaket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Spec/Plan in `docs/superpowers`. P1 = 7 Quick-Wins:
- [x] ✓ **Eigenaufträge:** Status-Filter entfernt.
- [x] ✓ **Störungen:** Filter-Sheet nur noch **Anlagentyp + Km-Abrechnung** (Status raus, auf Wunsch), Badge-Zähler, Anlagentyp-Chips kapitalisiert.
  - [x] ✓ *(v0.45.3 · 11.07.2026)* Dritter Filter **Störungsbereich** (Zapfhahn/Leitung/Kühler/Zapfkopf/Gas, mit Nummer „1 - Zapfhahn") ergänzt; die drei Dropdowns (Typ · Art · Bereich) jetzt als **gleich breite, zentrierte Spalten** (`Expanded`+`isExpanded`, Ellipsis) — Pixel-9-optimiert, kein Überlauf. Isoliert am Web-Build (390px, Worst-Case) verifiziert.
  - [x] ✓ *(v0.46.6 · 12.07.2026)* **Perf Reinigungen laden:** `ReinigungRepository._pagedByUser` lädt die ~8621 Zeilen (Web) nicht mehr in 9 **sequenziellen** 1000er-Seiten, sondern erste Seite + Folgeseiten in **parallelen Wellen** (`Future.wait`, Batch 8) → statt 9 Round-Trips nur noch ~2 Wellen. `.order('id')`-Tiebreaker macht Seitengrenzen deterministisch. Kleine Abfragen (Anlage/Betrieb) bleiben 1 Request. **🟡 Offen:** falls noch zu langsam → Spaltenreduktion oder Zwei-Stufen-Laden (aktuelles Jahr sofort, Historie lazy) als Folgeschritt.
  - [x] ✓ *(v0.46.5 · 12.07.2026)* **Betriebe Regionenfilter — Kategorie „Keine Region":** neue Filter-Option (Sentinel `__keine_region__`) zeigt Betriebe ohne zugewiesene Region (aktuell 109 gesamt, davon 5 operativ). Gilt für Liste + Karte (`_regionPasst`-Helfer). In der Liste greift zusätzlich der Status-Filter.
  - [x] ✓ *(v0.46.4 · 12.07.2026)* **Bugfix Tourenplan Reihenfolge:** Plan-Reihenfolge entsprach nicht der Eingabe. Ursache: Tagesplan wurde gefiltert angezeigt, das Drag-Reorder operiert aber auf dem vollen State mit den **gefilterten Indizes** → Reorder traf falsche Einträge. Fix: Tagesplan zeigt den **vollständigen Plan ungefiltert** in exakt der Eingabe-/manuellen Reihenfolge; Filter (Region+Fälligkeit) gelten nur noch für die „Fällig"-Liste.
  - [x] ✓ *(v0.46.3 · 12.07.2026)* **Bugfix Tourenplan „gespeichert aber leer":** geladene Einträge wurden ausgeblendet, weil (a) `faelligkeit` beim Speichern nicht mit-serialisiert wurde (→ null) und (b) der Tagesplan denselben **Fälligkeitsfilter** (Standard überfällig+fällig) wie die Fällig-Liste anwandte. Fix: `faelligkeit`/`datum`/`zielDatum` mit-serialisieren **+** Tagesplan nur noch nach **Region** filtern (der Fälligkeitsfilter triagiert nur die Fällig-Liste). committete Einträge bleiben immer sichtbar.
  - [x] ✓ *(v0.46.2 · 12.07.2026)* **Bugfix Tourenplan Auto-Save:** Tagespläne wurden teils nicht gespeichert. Ursachen (client-seitig; DB war ok, gestern noch Saves): (1) **Lade-Race** — Einträge vor Rückkehr des async Tages-Fetch wurden von dessen `resetLeer`/`setFromGespeichert` überschrieben + Save abgebrochen; (2) **veralteter Cache** — `gespeicherterTagesplanProvider` nach Save nie invalidiert; (3) **verschluckte Fehler** (fire-and-forget). Fix: Notifier beansprucht den aktiven Tag sofort (`_datum`, Race-Guard im Screen), invalidiert den Cache nach Save, loggt Fehler. Regressionstest (2) grün.
  - [x] ✓ *(v0.46.1 · 11.07.2026)* **Betriebe (Liste):** die drei Filter **Kunden · Status · Zapfsysteme** als gleich breite Spalten nebeneinander (`Expanded`+`isExpanded`); dafür `AppFilterMultiDropdown` um `isExpanded` erweitert (füllt Spalte, Pfeil rechts, Ellipsis). Karte-Ansicht bleibt Kunden + „Nur fällige". Multi-Menü-Öffnen im neuen Pfad verifiziert.
  - [x] ✓ *(v0.46.0 · 11.07.2026)* **App-weiter dezenter Filter-Rahmen:** neues `FilterChrome` (weiße Füllung + graue Umrandung `AppColors.filterBorder`) zentral in `AppFilterDropdown`/`AppFilterMultiDropdown`/`AppJahrMonatLeiste` → deckt 28 Filter über die geteilten Bausteine ab. Zusätzlich 10 Einzelfall-Filter umgestellt (Auswertung, Buchungen-Liste, Bericht-Datumspicker, Heineken-Raster, Lohnlauf, MwSt-Abrechnung inkl. Weißtext-Fix). Abdeckung per **Audit-Workflow** (6 Agenten) verifiziert; visuell am 390px-Web-Build geprüft. SegmentedButtons/Suchfelder/Formularfelder bewusst ausgenommen (haben eigenes Chrome).
- [x] ✓ **Reinigung:** Chip „Protokoll" statt „Foto"; **Service-Art** (Klartext) statt rohem `serviceTyp`; Zeiterfassung **kompakt einzeilig** (Datum/Start/Ende) in **Formular UND Detail-Übersicht**.
- [x] ✓ **Kontakte:** Heineken-Rolle **„Stardrinks"** (Migration 117).
- [x] ✓ **Betriebsferien:** 3 → **5 Slots** (Migration 118); Formular dynamisch (nur belegte Zeilen + „Weitere Ferien"); Detail zeigt Ferien 1–5; zentraler `betrieb_ferien.dart`-Util + **Bugfix** (`isBetriebOffen`/`_isBetriebAktiv` prüften bisher nur Ferien 1) → Touren/Termine/Heineken-Raster umgestellt; 8 neue Unit-Tests.
- [x] ✓ **Visueller Check Betriebsferien (Handy)** — erledigt (User bestätigt 12.07.2026).

Vorgehen: subagent-getrieben (Phase A 5 Tasks parallel, Phase B 5 Ferien-Tasks sequenziell), je Task Spec- + Qualitäts-Review, finaler Branch-Review **APPROVED** (Web-Sync der neuen Ferien-Felder verifiziert), 210 Tests grün. **Migrationen 117 + 118 sind produktiv angewendet.**

**Aus Paket 06 inzwischen erledigt:** Betriebe (Ferien-Zeile + Google-Übernahme v0.25), Reinigung (Service-Art/Zeiterfassung/Protokoll-Chip), Störungen/Eigenaufträge-Filter, Kontakte (Stardrinks + Event-Struktur), **Events-Feature komplett** (E1–E5: Kontakte/Telefonliste, Einsätze+Material, Abschluss-Mail an RSL/Eventverantwortlichen).

**🔴 Aus Paket 06 noch offen (echte Restpunkte):**
- [x] ✓ **Anlagen-Screen + Steckbrief-PDF** (live v0.27.0 · 10.07.2026): Dashboard-Kachel „Anlagen" + Kennzahlen-Kopf (aktiv/nach Typ/überfällig) im vorhandenen `/anlagen`-Screen; **Steckbrief-PDF pro Anlage** (Grunddaten + Fotos aus `anlagen_fotos` + Bierleitungen) mit **Teilen** + **Mail an RSL** (neue Heineken-Zuweisung `rsl`, MailConfig-Bereich `anlage`). Subagent-getrieben, 271 Tests grün. **✓ Scharf** (11.07.2026, User bestätigt „Steckbrief ist schon scharf"; funktioniert). Niederdruck im PDF jetzt mit 1 Kommastelle (v0.43.1).
- [x] ✓ **Reinigung QR-Firmenkonto-Link** (live v0.28.0 · 10.07.2026): Button „QR-Zahlung" im Reinigungs-Formular → Dialog mit Swiss-QR aufs Firmenkonto (Schweizerkreuz), Betrag aus `preisBrutto` vorbefüllt+editierbar. Reine Funktion `swissQrPayload` (TDD) — Rechnungs-QR nutzt sie byte-identisch. **✓ Scan-Test mit Banking-App erledigt** (User bestätigt 12.07.2026).
- [x] ✓ **Tourenplanung T1 — UX & Verhalten** (live v0.29.0 · 10.07.2026): Tagesplan startet **default leer** (Fällig-Liste default überfällig/fällig, andere Kategorien per Filter; Button „Fällige übernehmen"); **Auto-Speicherung** (Speicherbutton entfällt, entprellt); **Ruhetage + Servicezeiten** auf jeder Karte + **Ruhetag-Warnung**; **Inline-Filter** Region + Fälligkeit getrennt (kein Sheet); **grosser Drag-Griff**. Reine Helfer `touren_anzeige.dart` (16 Unit-Tests). **🟡 Offen:** visueller Live-Check `/touren` (Preview-Harness konnte canvaskit nicht rendern).
- [x] ✓ **Tourenplanung T2 — Fälligkeits-Logik & Auto-Termine** (live v0.30.0 · 10.07.2026): Endreinigung/Eröffnung aus Saison-/Ferien-Übergängen des Betriebs abgeleitet (`touren_saison.dart`, kanonischer „offen"-Begriff, 16 Unit-Tests); Endreinigung nur bei Saisonende / Ferien ≥ 21 Tage; Vorlauf 7 Tage; Sektion „Automatische Termine" im Tagesplan-Tab (letzter offener Tag vor Schliessung / erster nach Öffnung, Ruhetage/Ferien übersprungen) mit +übernehmen/alle übernehmen. **🟡 Offen:** visueller Live-Check `/touren` (Saisonübergänge).
- [ ] **Termine — komplette Überarbeitung = Google-Kalender-Hybrid** (Recherche+Entscheidungen in `docs/superpowers/specs/2026-07-10-google-kalender-recherche.md`). Teil-Pakete:
  - [x] ✓ **G1 — Verbindung & Datenmodell** (live v0.31.1 · 11.07.2026, **verbunden verifiziert** mit dani.proyer@gmail.com, Refresh-Token gespeichert): OAuth serverseitig (Edge Functions `google-oauth-exchange`/`google-calendar-disconnect`, PKCE, Token nur in `google_calendar_tokens` RLS-gesperrt, Status-Tabelle), Einstellungen „Google Kalender verbinden/trennen", `Termin`-Mehrfach-Erinnerungen (jsonb + Reminder-Editor, 16 Tests). Fix unterwegs: `index.html`-Cache-Buster erhält jetzt OAuth-`?code/?state`. **🟡 Offen:** realer Erinnerungs-Empfang wird mit G2 getestet (sobald Events geschrieben werden).
  - [x] ✓ **G2 — Push App→Google** (live v0.32.0 · 11.07.2026): Mapping-Tabelle `google_calendar_events`, Edge Function `google-calendar-sync` (Access-Token-Refresh, push + reconcile, Waisen löschen), Sofort-Push nach Speichern/Löschen (Termin nur `status=geplant`, Pikett/Event), Ziel = **Haupt-Kalender** (Präfix „SBS · ", Termin grün / Pikett rot / Event gelb), Erinnerungen (Termin aus Array, Pikett/Event email+popup 1 Tag), Button „Jetzt abgleichen" in Einstellungen. **Abweichung:** kein pg_cron (bräuchte service_role-Key/Secret) — reconcile per Button; Auto-Cron optional dokumentiert. **🟡 Offen:** Live-Test (Termin/Pikett/Event → Google, ändern/löschen, Erinnerungs-Empfang Pixel 9).
  - [x] ✓ **K1 — App-Kalender abgelöst → Google Kalender** (live v0.33.0 · 11.07.2026): Entscheidung des Users — Google Kalender wird **der eine Kalender** (App-Kalender-Design überzeugte nicht). Komplettes **Termin-Modul entfernt** (Screens/Formular/Repo/Provider/Mapper/DTO/Locals/Web-Stubs/Export + `ReminderService`/`ReminderTime`/`erinnerung_util` + 3 Routen + Sync-Tier + Isar-Methoden + Schema), Dashboard-Kachel „Termine" → **„Google Kalender"** (öffnet calendar.google.com). Pikett & Events bleiben Geschäftsobjekte und pushen weiter (G2). Neu: beim **Speichern eines Betriebs mit Saison/Ferien** kommt ein **Bestätigungs-Dialog** (Eröffnung/Endreinigung, Häkchen default an) → nach Bestätigung landen die Reinigungen im Google Kalender (grün, Erinnerung E-Mail+Popup 1 Tag vorher). Reine Funktion `betriebReinigungen` (7 TDD-Tests), Edge-Function-Aktion `sync_reinigungen` (entity_type `betrieb_reinigung`, Migration 132 entity_id→text), reconcile lässt Reinigungen unangetastet. 311 Tests grün, analyze/Web-Build sauber. **🟡 Offen (Live-Test, User):** Betrieb mit Saison/Ferien speichern → Dialog erscheint → in Google eintragen → Termine + Erinnerung prüfen; Betrieb ohne Google-Verbindung → kein Dialog; Dashboard-Kachel öffnet Google Kalender.
  - **K2 — Bestehende Google-Termine den Betrieben zuordnen & taggen.** Spec `docs/superpowers/specs/2026-07-11-google-kalender-k2-design.md`. Zweistufig (User-Entscheid: konservativ, Farbe+Erinnerung+Tag, Zukunft+jüngste Vergangenheit, Lavendel colorId 1):
    - [x] ✓ **K2a — Kalibrier-Scan** (live v0.34.0 · 11.07.2026): read-only Edge-Aktion `scan_manual` (`events.list`, paginiert, `singleEvents`, überspringt SBS-getaggte) + reine Matching-Funktion `google_termin_match.dart` (Name + **harte Ort-Bestätigung**, Umlaut-/Slash-/Davos-Normalisierung, Tippfehler-Toleranz, nur genau-1-Treffer = eindeutig; 12 TDD-Tests aus echten Kollisionen Alpina×4/Calanda/Bernina-Bar). Neuer Screen (Einstellungen → „Bestehende Termine zuordnen"): Zeitraum (Default heute…+2 Jahre), Scan-Button, Statistik-Chips, Bucket-Liste. **Ändert nichts in Google.**
    - [x] ✓ **Matching v2** (v0.36.0, nach Live-Test kalibriert): Anker-Token statt Vollname (Gattungswörter Gasthof/Pizzeria/Openair toleriert), kompakte Orte (BadRagaz↔Bad Ragaz), Unique-Name-ohne-Ort (matcht auch wenn Ort im Titel fehlt/abweicht, sofern Name global eindeutig — z.B. Pagigerstübli, Fasan, Openair Val Lumnezia), Bernina/Bernina Bar via Vollname-Tiebreak getrennt; **Privat ausgeblendet** (Geburtstag/Ferien), **Pikett erkannt** (eigener Chip). 23 TDD-Tests (echte Fälle). **Daten-Hinweis:** einige Betriebe haben abweichende Orte ggü. Kalender (Pagigerstübli=Arosa, Fasan=Seewis Dorf) — matcht trotzdem, ggf. Ort in Stammdaten prüfen.
    - **🟡 Offen (User):** erneut scannen + Buckets prüfen → dann K2b.
    - [x] ✓ **K2b — Taggen + Rückgängig** (live v0.37.0 · 11.07.2026): Migration 133 (`entity_type` `betrieb_manuell`) + 134 (`original_color_id`/`original_reminders`). Edge-Aktionen `apply_tags` (**nur PATCH**: colorId 1 Lavendel + Erinnerung email+popup 1440 + `extendedProperties`-Tag; Titel/Notizen/Datum NIE) + `untag_manual` (**voll reversibel** — Original-Farbe/-Erinnerung werden beim Taggen gesichert und beim Untag exakt wiederhergestellt). Häkchen-Freigabe-UI: eindeutige vorangehakt, mehrdeutige mit Betrieb-Dropdown, kein-Treffer/Pikett ausgegraut; „X Termine taggen" + „Tags entfernen"; getaggte verschwinden aus der Liste. **Adversarial verifiziert** (4-Lens-Workflow): Titel/Notiz-Sicherheit + Client-Logik sauber; die anfänglich gefundene Reversibilitäts-Lücke (Original nicht gesichert), PATCH-vor-Mapping-Waisen und colorId:null-Kopplung wurden vor Deploy gefixt (Rollback bei DB-Fehler, colorId-Retry-Netz). **🟡 Offen (User-Live-Test):** eindeutige taggen → Lavendel+Erinnerung in Google prüfen; „Tags entfernen" → Ursprungszustand zurück; Spezialfall colorId:null (Termin ohne Original-Farbe) beim Untag beobachten.
    - [x] ✓ **Feinschliff (v0.37.1):** Fuzzy-Anker-Fix (Token „crusch"~„grusch" machte Ustria Crusch Alva zum Geister-Kandidat → „Grüsch - Fasan" jetzt eindeutig; Unique-Name-ohne-Ort zählt nur EXAKTE Anker); mehrdeutige Einträge (z.B. „Davos - Seehof und Chesa") per **FilterChips mehrfach wählbar** → beide Betriebe taggbar (betrieb_id kommasepariert in extendedProperties).

---

## 🔴 OFFEN — relevant

### Auswertung Umsatz/Arbeiten (Buchhaltung) — NEU 11.07.2026
Spec `docs/superpowers/specs/2026-07-11-buchhaltung-auswertung-design.md`. App-Pendant zum Excel-Blatt „Auswertung" (`00_SBS_Projer_70`).
- [x] ✓ **Phase 1 (live v0.45.2 · 11.07.2026, User bestätigt „klappt"):** Neuer Screen `/buchhaltung/auswertung` — Umsatz/Arbeiten nach Jahr+Monat, 3 Modi (Jahr / Jahre / **Monatsvergleich über Jahre**), Charts (`fl_chart`, grün dezent), **netto/brutto umschaltbar**, professionelle Tabelle (Monat·Anzahl·Kunde·Heineken·Total, Zeile aufklappbar → Kategorien). Rein **live** aus App-Daten (Reinigung volle Historie 2019+, übrige Kategorien + Heineken-Split ab Dez 2025). Kunde/Heineken-Split via `betrieb.rechnungsstellung=='heineken'`. Reines Aggregat TDD (9 Tests), adversariale Review (5 Low-Funde gefixt). **Render-Bug** (Charts+Tabelle unsichtbar) per Browser-Reproduktion isoliert: KPI-`Row(crossAxisAlignment.stretch)` in `ListView` → unendliche Höhe → blockierte Folge-Kinder (Release verschluckt Assert) → Fix `IntrinsicHeight` (v0.45.2). **🟡 Offen (User):** Live-Zahlen gegen Excel abgleichen (v.a. ein 2026-Monat wo alle Daten da sind).
- [x] ✓ **Phase 2a — Werkstatt-Aufträge backfilled (12.07.2026):** Störung/Montage/Eigenauftrag/Eröffnung+Endreinigung/Pikett aus Excel `00_SBS_Projer_70` für **2019 → 30.11.2025** als echte App-Datensätze importiert = **2'035 Datensätze** (Störung 999, Montage 712, EE 124, Eigenauftrag 108, Pikett 92). Spec/Plan in docs/superpowers (2026-07-12-historie-backfill-werkstattauftraege). Migration 135 (`extern_id`/`quelle` + partielle Unique-Indizes), Import-Skript `Datenbank/import/extract_werkstatt.py` (idempotent, `ON CONFLICT DO NOTHING`, Datumsgrenze <01.12.2025 → null Überlappung, Betrieb-Mapping via `match_betriebe.py`, Waisen→betrieb_id=null). **Abnahme: alle 5 Kategorien × 2019–2024 = 30/30 exakt gegen Excel-„Auswertung"** (Anzahl + Netto). Kanarienvogel-Import fing 2 Bugs: nicht-eindeutige Excel-IDs (deterministischer `#n`-Suffix) + `stoerungsnummer` NOT-NULL (Fallback/Spalte). Idempotenz + Live-Daten-Unberührtheit verifiziert. **KEINE Buchungen** — reine operative Auftrags-Datensätze; die Auswertung liest sie. **🟡 Offen (User):** App-Auswertung am Handy sichten (Modus „Jahre" → Heineken-Spalte 2019–2025 gefüllt).
- [x] ✓ **Bugfix Pagination (v0.46.7 · 12.07.2026):** Nach dem Backfill hatte **stoerungen 1095 Zeilen** → `StoerungRepository.getAll()` (Web) lud ohne Pagination → **PostgREST-1000-Deckel** → Liste UND App-Auswertung verloren still ~95 Störungen (vom User bemerkt). Fix: alle 5 Werkstatt-Repos (stoerung/montage/eigenauftrag/ee/pikett) paginieren jetzt (erste Seite + Folgeseiten parallel, `.order(datum/-_start).order(id)`), analog reinigung_repository. montagen (802) war der nächste Kandidat.
- [ ] **Phase 2b (Folgeschritt):** **BK-Pauschale** nacherfassen (kein Einzel-Beleg im Excel — Quelle klären: Bergkunde-Betriebe × Reinigungen o. per Jahr).
- [ ] **Phase 2c (Folgeschritt):** historische **Heineken-Monatsrechnungen** generieren & gegen die realen PDF-Rechnungen (seit 2019) abgleichen. *Erst hier entstehen ggf. echte Buchungen.*

### Buchhaltung-Aufräumen
- [x] ✓ **camt-Screens in „Bankauszug Import" integriert** (v0.16.19): Prüfliste, Regeln, Dateien sind jetzt Tabs im Import-Screen (4 Tabs unter einem Host `CamtBankauszugScreen`), Dashboard von 4 camt-Kacheln auf **eine** reduziert. Alte Routen als Redirects (`?tab=`), FAB nur im Regeln-Tab, „Zur Prüfliste" = Tab-Wechsel. Subagent-getrieben (3 Implementer) + adversariale Review (3 Lenses, 0 Bugs — Extraktion zeilengenau treu gegen Originale). Widget-Test (4 Tabs, FAB-Gate). Spec/Plan in docs/superpowers.
- [ ] **🟡 Visueller Check camt-Tabs (bei Gelegenheit):** kurz im Browser durchklicken — v.a. der **Import-Tab** (hatte historisch Render-Eigenheiten: GestureDetector statt Material-Buttons), Tab-Wechsel, FAB nur bei „Regeln", Download im Dateien-Tab, „Regel anlegen" aus der Prüfliste, Direktaufruf alter URLs landet im richtigen Tab.

### Eingangsrechnungen (TP-0..7 ✓ + Kategorien, live v0.16.18) — Scan→KI/QR→Lernen→Buchung→GKB-File→camt-Abschluss→Reversibilität→Datenhygiene→Kategorien
- [ ] **🟡 Kategorien ausführlich testen (bei Gelegenheit):** Grundfunktion bestätigt (Daniel, 29.06. — funktioniert). Noch im Alltag durchprobieren: (a) **Busse** beliebiger Kanton → `busse`/6280; (b) **Info-Doc** → erscheint in „Rechnungen", nach „Nur ablegen" in „Ablage"; (c) Umschalter + Kategorie-Filter; (d) Detail Kategorie ändern → Konto-Vorschlag. **Falls die KI eine Kategorie falsch trifft → Beleg an Claude, Prompt nachschärfen.**
- [x] ✓ **Eingangsrechnung-Kategorien** (v0.16.18): 15 inhaltsbasierte Kategorien (KI klassifiziert aus dem Inhalt → löst Bussen-Erkennung kanton-unabhängig). Tabelle `eingangsrechnung_kategorie` (code→Konto-Default), Spalte `kategorie`, KI-Output (Whitelist-normalisiert), `schlageKontoVor` (Regel > Kategorie-Default > leer, MwSt-gekoppelt), UI: Dropdown in Upload+Detail (Konto-Update bei Wechsel) + Liste „Rechnungen | Ablage"-Umschalter + Kategorie-Filter + Label. Subagent-getrieben (3 Implementer) + adversariale Review (6 Bugs gefixt: Vorsteuer/MwSt, Whitelist, Dropdown-Crash-Guard, Ablage-Sicht, Detail-Konto, Upload-Dropdown). Spec/Plan in docs/superpowers. *Minor offen:* Kategorie-Filter erreicht künftig deaktivierte Kategorien nicht (Designentscheidung).
- [x] ✓ **GKB-Zahlungsfile Test-Upload BESTANDEN** (29.06.): `pain.001.001.09`-File testweise im GKB-E-Banking hochgeladen → **akzeptiert**. Das `.ch.03`-Profil ist damit real bestätigt, das File ist bankfähig.
- [x] ✓ **TP-5/6 End-to-End validiert** (29.06., synthetisches camt): voller Round-Trip mit echter Heineken-Rechnung + synthetischem camt.053 getestet — Belastung → Referenz-Match (QRR) → Stufe-2-Buchung (2000→1020) → Status `bezahlt` → „Zahlung rückgängig" → wieder offen + re-importierbar → Re-Match erscheint. Alles korrekt (per SQL geprüft), Test-Daten aufgeräumt. **Empirisch offen bleibt nur:** ob die GKB im camt bei DBIT die QRR/SCOR-Referenz zurückspielt (sonst greift Fallback IBAN+Betrag) — zeigt sich erst am echten GKB-Auszug.
- [x] ✓ **UX-Cleanup Dashboard** (v0.16.17): alten `camt-Abgleich`-Screen entfernt (Screen + Route + Links + redundante Kachel). Alles läuft über den vereinten „Bankauszug Import" (camt-import = Kundenzahlungen + Kreditoren + Ausgaben).
- [x] ✓ **Storno-Saldo-Fix** (v0.16.15): Bilanz + Erfolgsrechnung überspringen jetzt auch Storno-Gegenbuchungen (`stornoVonId != null`) → ein Storno nettet korrekt auf 0 statt −Original. Geprüft: aktuell 0 Gegenbuchungen (die 13 „stornierten" sind Jahresgewinn-Abschlüsse, kein echter Storno) → keine Änderung bestehender Salden; greift beim ersten echten Storno (z.B. TP-6 Path-B).
- [x] ✓ **TP-7 Datenhygiene** (29.06.2026, Migration 115): 28 inaktive Vorlagen-Duplikate gelöscht (waren ohnehin aus Dropdowns gefiltert); Konten-Altlasten bereinigt — 8090/8500/2850 gelöscht (Platzhalter/Duplikate, 0 Buchungen), 9000/9100 von „FEHLER…"-Namen auf „Gewinn-/Verlustübertrag (Abschluss)" umbenannt. Reine DB-Daten, kein Deploy. *(Hinweis Buchhaltung: Jahresergebnis liegt im Standard auf EINEM Konto 2980; 9000/9100 sind eigentlich Abschlusskonten Erfolgsrechnung/Bilanz — Daniel nutzt sie bewusst als Gewinn-/Verlustübertrag, unkritisch da App das Ergebnis aus den Erfolgskonten rechnet.)*
- [x] ✓ **Cleanup (v0.16.16, 29.06.):** toter Code entfernt (`forderungenProvider`/`mahnwesenDashboardProvider`/`getMahnwesenDashboard`, Invalidierung läuft über `rechnungenStreamProvider`); TP-6 `resetNachBuchungStorno` Fallback via `beleg_id` (verwaiste Zahlungs-Buchung wird freigegeben). **Offen (niedrige Prio):** volle Atomarität der Stufe-2-Rücknahme via DB-RPC/Transaktion — heute self-healing per Retry.
- [x] ✓ AXA-Personenversicherung Seed-Regel: **5730 (Unfall/UVG-Zusatz) von Daniel bestätigt** (29.06.) — bleibt korrekt, nichts zu ändern.
- [x] ✓ **Sicherheit: `verify_jwt=true` für `parse-rechnung` + `parse-beleg`** (11.07.2026): via `supabase/config.toml` (`[functions.*] verify_jwt = true`) + Redeploy. Smoke-Test bestätigt: Aufruf **ohne** Auth → `401 UNAUTHORIZED_NO_AUTH_HEADER`, mit gültigem JWT → erreicht die Funktion (App unverändert). Schützt Claude-/API-Credits gegen offene Endpoint-Aufrufe. **Zusätzlich `auth.getUser()`-Self-Guard** in beiden Functions (11.07.2026): anon-Key-Aufruf → `401 unauthorized`, nur echte eingeloggte User lösen Claude aus. Verifiziert: App sendet User-JWT via `functions.invoke` (wie google-calendar-sync, dessen Guard im K2-Scan funktionierte) → Dokument-Scannen unverändert.
- [x] ✗ **DB-UNIQUE-Index verworfen** (statt umgesetzt): würde den bewussten Sammel-/Teilzahlungs-Pfad brechen (mehrere 'zahlung'-Buchungen je Beleg bzw. gleicher tx_key — Memory-Merksatz). App-seitige Idempotenz-Guards sind hier das richtige Mittel. *Optional offen:* 5-Rappen-/Spesen-Toleranz beim Kreditor-Betragsmatch (heute exakt = sicher).

### Scharfstellung / Live-Betrieb (Buchhaltung 01.07.2026)
Strategie: **Voll-Übernahme** (kein Clean-Start) — Historie lückenlos 27.03.2019→heute im System, Bilanz geht an allen Jahresenden auf, Salden laufen weiter. „Scharfstellen" = nur noch:
- [ ] **Mail-Bereiche scharfstellen:** `mahnwesenScharf` in `mail_config.dart` (steht noch auf Test-Empfänger; `bestellungScharf` seit 14.07. scharf).
- [ ] **camt-Auto-Buchung produktiv** — ⚠️ Korrektur 14.07.: technischer Code-Stichtag ist **11.03.2026** (hardcoded `camt_stichtag.dart`, exakt Excel-Bankende), NICHT 01.07.; „01.07." war nur organisatorisch. Bestätigungs-Flow gebaut, aber **0 von 270 TX gebucht**.
- [ ] **2026 gezielt** auf vereinzelte Test-Buchungen durchsehen (NICHT pauschal; echte Live-Buchungen bleiben).

### Buchhaltung-Vollcheck 14.07.2026 (5-Agenten-Audit App↔Excel↔camt) — Reparaturplan Voll-Übernahme
Befunde komplett in Memory `buchhaltung_vollcheck_2026_07.md`. Positiv: Import 2019–Nov 2025 journalgetreu (ER-Jahre ±0.12 CHF), Live-Ertragsseite ab Dez 2025 vollständig (CHF 0 fehlt), keine Excel↔Live-Doppelbuchung. Kritisch ist die **Geldseite**:
- [x] ✓ **(1) Delta-Import 220 Zahlungseingänge ERLEDIGT 28.07.2026** — 220 Zeilen / CHF 55'191.70 gebucht (217× 1020/1100 + 3× 1020/1000). **Alle drei Salden treffen die Prognose exakt:** Bank per 11.03. **3'322.26** (= E-Banking-Stand, von Daniel geprüft; vorher −51'869.44), Debitoren 225'774.69 → **176'228.04**, Kasse 24'342.83 → **18'697.78**. Skript `extract_journal_zahlungen.py` (Selftest gegen Audit-Zahlen), SQL in `out/journal_zahlungen.sql`, Buchungen tragen `notizen = 'Excel-Delta-Import Zahlungseingaenge 28.07.2026'`.
  - **Analyse 28.07. bestätigt die Zahlen exakt** (Excel unverändert): 220 Zeilen / CHF 55'191.70, davon Dez 63 · Jan 56 · Feb 73 · Mär 28. Aufteilung: 213× Zahlungseingang Reinigung (21'646.25), 4× Heineken (27'900.40), 3× Kasse→Bank (5'645.05). **Ursache belegt:** `extract_journal_nachtrag.py` schloss ab 28.11.2025 alle `Zahlungseingang*`-Geschäftsfälle aus mit der Annahme „kommen via camt" — camt beginnt aber erst am 11.03. und ist bis heute nicht verbucht. Letzter Zahlungseingang in der DB: 28.11.2025, danach 0. Keine der 220 Belegnummern existiert in der DB → Idempotenz gesichert.
  - ✓ **Unklare Zeile gelöst (28.07.):** `020_2025_12_05_XXX_00007460` (74.60) = **Blockhuus Davos (0080)**, Rechnung vom 17.11.2025; Zahler laut Bankauszug **Gehri Gastronomie GmbH**. Beim Betrieb erfasst: Zahler-Alias + Rechnungsadresse (Landwasserstrasse 49, 7277 Davos Glaris). Beim Import Kürzel `XXX` → `0080` setzen.
  - Skript-Anpassungen nötig: Filter umdrehen (nur `Zahlungseingang*`), Excel-Pfad korrigieren — Datei liegt unter `D:\01_SBS_Projer_GmbH\00_SBS_Projer_70.xlsm`, das Skript sucht in `..\..\00_Buchhaltung\`.
- [ ] **(2) Frischer GKB-camt-Export ab 20.06.2026** ziehen + importieren — ab 21.06. fehlen sogar Rohdaten (24-Tage-Loch, der 01.07. liegt mittendrin). Dedup via txKey, überlappend ok.
- [ ] **(3) Die 270 camt-TX (12.03.–20.06.) im Bestätigungs-Flow verbuchen** (Credits 51'775.75 / Debits 47'694.04): Kundenzahlungen-Abgleich gegen 1'526 offene Rechnungen, Ausgaben-Regeln bestätigen. Prüfliste: die 2 Heineken-Gutschriften (7'104.98 + 5'794.81) matchen jetzt EXAKT auf die heute erstellten Feb+März-Monatsrechnungen.
- [ ] **(4) Zahlungsstatus-Pflege**: 532 Live-Rechnungen ab Dez 2025 (54'571.83) nie auf bezahlt gesetzt (414 Tresen = längst bezahlt) — via camt-Abgleich bzw. Tresen pauschal abhaken (Entscheidung Daniel).
- [ ] **(5) MwSt-Aufsetzpunkt** (Entscheidung Daniel): 2200/1171/1170-DB-Salden sind für die Alt-Ära unbrauchbar (Excel buchte MwSt nur im Hauptbuch-Sheet, nie im Journal → nie importiert; Alt-Ertrag steht brutto, ~83'430 MwSt-Anteil 2019–2025). Empfehlung: Aufsetzkorrektur per 31.12.2025 mit Excel-Bilanzwerten (2200: 17'223.38 / 1171: 1'148.11 / 1170: 3'654.08).
- [ ] **(6) EK/Gewinnvortrag** (Entscheidung Daniel): 13 Jahresabschluss-Buchungen (9000/9100/2970/2980) wurden als storniert importiert → Gewinnvortrag 35'319.11 fehlt, Bilanzgleichung geht nie auf. Entstornieren/nachbuchen ODER dokumentiert als reine Verkehrszahlen-Buchhaltung lassen.
- [ ] **(7) Prozesse ab Stichtag scharf**: Heineken **Juni-Rechnung überfällig** (wartet: mind. 402.14 Reinigungen + 1'620 Pauschalen); Eingangsrechnungs-Scan produktiv nutzen (23 Scans alle „verworfen", Aufwand seit 08.06. NIRGENDS erfasst); Lohnlauf ab Juli via App (`lohn_abrechnungen` leer, bisher nur Excel).
- [ ] **(8) Excel einfrieren**: Journal offiziell per 11.03.2026 (Bank) / faktisch tot seit 08.06.; die 90 Zeilen ohne „Gebucht=X" sind seit 20.06. in der DB → X nachtragen oder Datei archivieren (sonst Doppelimport-Risiko).
- [ ] **(9) Klärungen klein**: 14 Ertrags-Belegvarianten Excel↔App (1'510.30, Rundung/Datum/Preis — Liste beim Audit); Kassenbestand real prüfen (DB 1000 = 23'477.48, ungewöhnlich hoch); `abgerechnet`-Flags 42 Pauschalen + 22 Heineken-Reinigungen Dez–Mai auf true (kosmetisch, verifiziert enthalten).
- [ ] **(10) Hygiene/Code**: 8 von 9 camt_dateien-Duplikat-Archivzeilen löschen; Forderungs-Abgleich-Filter um Mahnstatus erweitern (aktuell nur offen/gesendet); beleg_id-Doppelsemantik dokumentieren (815× reinigungen.id vs. 6× rechnungen.id bei beleg_typ='rechnung'); Heineken 04/2026 Netto/Brutto-2-Rappen (netto als brutto−mwst ableiten).

### Buchhaltung — Fachfragen / Sichtprüfung (Daniel)
- [ ] **B1:** Lohnaufwand 5000 liegt ~1–2k/Jahr über Lohnausweis-Brutto — klären (AG-Beiträge/Spesen drin? oder überbucht?). Relevant für AHV-/Steuerbasis.
- [ ] **B3:** MWST-Zahllast 2023 App 8'014 vs. deklariert ≈6'635 (+1'379) — Quartals-Timing/Buchung prüfen (andere Jahre decken sich exakt).
- [ ] **Abschreibungen Alt-Forderungen:** 2019–2022 ≈50k Kandidaten (kaum eintreibbar) — wieviel/welche Kunden definitiv abschreiben (Debitoren-Hub: 3805/1100 netto + 2200 MWST-Rückholung) vs. Delkredere 5%? Daniel entscheidet selbst. (Negative Salden 2202/2273/8900 = Timing-Konten, KEINE Abschreibung.)
- [ ] **1100-Plausibilität** im Debitoren-Screen gegen die offenen CHF 105'240.95 prüfen.
- [ ] **App-Sichtprüfung Scans:** zeigen Protokoll-/Zahlbeleg-Scans an Reinigungen/Forderungen korrekt? (Bucket `reinigung-fotos`, `import/010,020/` → signed URL).
- [ ] **Optional Excel-Gegencheck:** Excel-Bilanz auf 31.12.2024 neu rechnen → bit-genauer Abgleich Kasse/Debitoren/Bank.
- [ ] **Phase 0c:** Offene-Posten-Sicht (Debitoren 1100 / Kreditoren 2000).

### camt / Code-Politur (klein, unkritisch)
- [ ] Import: statische Überschrift „Kundenzahlungen" bleibt nach „Alle verbuchen" stehen.
- [x] ✓ Import-Archiv-Dateiname: echter `picked.name` wird jetzt mitgeführt (Fallback `camt.xml`). (11.07.2026)
- [ ] `verbuche` nicht in echte DB-Transaktion geklammert (durch Idempotenz-Guard abgesichert).
- [ ] camt I2: Netzfehler nach Buchung vor Rechnung-Update → verwirrender Prüflisten-Eintrag (kein Doppelbuchen) — Transaktionalität verbessern.
- [ ] camt-Regeln beobachten/verengen: `'abschluss'` (Substring breit); Lohn „daniel proyer" ggf. → IBAN `CH7909000000870500683`; Heineken „heineken" → „heineken switzerland".
- [x] ✓ Saldo-Parsing-Bug gefixt (11.07.2026): `OPBD/CLBD` werden jetzt über `Bal>Tp>CdOrPrtry>Cd` gelesen (vorher immer 0). Feld weiterhin ungenutzt, aber korrekt; 2 Tests ergänzt.
- [ ] Phase 0a Follow-up: 11 alte camt-Vorlagen `ist_aktiv=true` (FK-Schutz) — optional Regeln auf neue Geschäftsfälle umhängen, dann Alt-Vorlagen deaktivieren (tauchen sonst im manuellen Dropdown auf).
- [x] ✓ Hub: toter Code `forderungenProvider` / `mahnwesenDashboardProvider` bereits entfernt (Grep 11.07.2026: keine Vorkommen mehr).
- [x] ✓ **App-weite UI-Vereinheitlichung** (Filter/Dropdowns) KOMPLETT (v0.38–v0.44 · 11.07.2026): einheitliche Filter-Bausteine (`widgets/filter/`: `AppFilterBar`/`AppFilterDropdown`/`AppFilterMultiDropdown`/`AppMultiToggleChips`/`AppJahrMonatLeiste`), **Region-Filter oben rechts (AppBar)** auf allen betrieb-bezogenen Listen (Touren/Betriebe/Anlagen/Reinigungen/Störungen), kompakte (Mehrfach-)Dropdowns statt Chip-Reihen/Sheets/AppBar-Popups, **Zombie-Schutz** überall, **Betrieb-Status-Semantik** (operativ=aktiv+saisonpause via `istBetriebOperativ`), gemeinsames **`AppJahrMonatLeiste`** (8 Screens, −285 Zeilen). Prio 1–5 alle deployed, je adversarial gereviewt (mehrere echte Bugs vorab gefixt). Zusätzlich: **Anlagen-Typ-Filter** (Warmanstich/Kaltanstich/Buffetanstich/Orion), **Steckbrief-Niederdruck** mit 1 Kommastelle, Reinigung-Betrieb-Auswahl nur meine Kunden (operativ).

---

## 🟢 BACKLOG (kein Zeitdruck)
- [ ] **GIS Regionen-Polygone** für 15 Regionen (KML/GeoJSON, WGS84/EPSG:4326). Tools: QGIS / Google Earth Pro / My Maps.
- [ ] **Franchise: geteilte zentrale Regionen (ferne Zukunft).** Heute sind Regionen pro Nutzer (`regionen.user_id` + RLS `user_isolation`), erfassbar über Einstellungen → Regionen (v0.46.20). Sobald mehrere Franchisenehmer sich Regionen **teilen** (N:M Franchisenehmer↔Region, User-Wunsch 14.07.2026): `regionen` zu **zentral gepflegtem, geteiltem Katalog** umbauen — Ownership weg von `user_id`, **Admin-Rolle** schreibt, Franchisenehmer wählen nur aus (`RegionenScreen._kannBearbeiten=false` für Nicht-Admins). Umsetzung bleibt lokal in `RegionRepository` + RLS; `betriebe.region_id`-FK stabil halten (bestehende 14 Regionen in Katalog migrieren, IDs behalten). Zuordnung Franchisenehmer→genutzte Regionen via Verknüpfungstabelle. Erst angehen, wenn 2. Franchisenehmer real ansteht (YAGNI).
- [ ] **Beta-Testing-Phase** (echte Geräte, Real-World, Offline-Modus Bergkunden).
- [ ] **Beleg-Foto** Ausrichtung/Zuschnitt optimieren (Deskew, Crop, Kontrast).
- [ ] **Bulk-Sync Handy-Kontakte ↔ App** (App-Kontakte priorisiert, Matching über normalisierte Nr., Bestätigung vor Übernahme).
- [ ] **Termin-Erinnerungen Folge-Tests:** Web (Browser-Notification + In-App), Android-APK (lokale Benachrichtigung bei geschlossener App, Berechtigungen).
- [ ] **A4 Wiederkehrende Buchungen** / **A5 Monatsabschluss-Checkliste** (nice-to-have; A4 teilweise via Vorlagen + camt-Regeln abgedeckt).
- [ ] **Nach MVP:** Franchise-Partner einladen · zusätzliche Regionen definieren · Partner schulen.

---

## 📌 Merksätze / Design-Entscheidungen (NICHT ändern)
- **Kein DB-Unique-Constraint auf `buchungen(camt_tx_key)`:** der Kundenzahlungs-Pfad stempelt denselben `tx_key` absichtlich auf mehrere Buchungen (Sammelzahlung). Dedup läuft über den In-App-Set (Single-User).
- **App ist alleinige Buchungsquelle** (DB-Trigger `rechnungen_auto_buchung_zahlung` abgeschaltet, Migration 102). „Rechnung gestellt"-Trigger `…_erstellt` bleibt aktiv.
- **Alle Rechnungstypen werden NUR über den camt-Abgleich als bezahlt gebucht** (echtes Bankdatum, `camt_tx_key`/reversibel, gegen echte Bankbewegung). Kein manuelles „Als bezahlt markieren" mehr: Kundenrechnung-Detail-Button + Hub-Sammelzahlung (v0.15.2/0.15.3) und Heineken-Bezahlt-Schritt (v0.15.4) entfernt. Jahresrechnung nutzt denselben Rechnungs-Detail/Hub → automatisch abgedeckt. Heineken: offen→gesendet→freigegeben bleibt manuell, **bezahlt nur via camt** (Button nur noch Anzeige „Zahlung über Bankabgleich").
- **Jede grosse Liste paginieren** (PostgREST deckelt bei 1000).
- **Reversibilität:** alle camt-Buchungen tragen `camt_tx_key` → „mach die camt-Buchungen rückgängig".
- **QR-Bill:** SCOR (RF…) wegen normaler IBAN (keine QR-IBAN); QR-Code braucht zwingend das Schweizerkreuz.
- Historie (`quelle='excel_import'`/Reinigungen/Forderungen) ist echte Daten — **NICHT löschen**.

---

## ✅ Erledigt (Chronik, neueste zuerst)
- **v0.15.2–0.15.4** (25.06) **Manuelles Bezahlt-Markieren komplett entfernt** — Kundenrechnung-Detail-Button (v0.15.2) + Hub-Sammelzahlung (v0.15.3) + Heineken-Bezahlt-Schritt (v0.15.4). Bezahlt läuft für ALLE Rechnungstypen nur noch über den camt-Abgleich (echtes Datum, reversibel). Jahresrechnung automatisch abgedeckt (gleicher Screen). ~530 Zeilen weniger.
- **v0.15.1** (25.06) **Rechnungsadresse-Modell vereinfacht:** Adresse wird nur noch **beim Betrieb** gepflegt (Link „Adresse beim Betrieb bearbeiten" im Rechnungs-Detail → bestehendes Betrieb-Formular). Rechnung hat nur noch **„Rechnung erneut senden"** (Bestätigung → PDF neu mit aktueller Betriebsadresse + **Fällig bis = heute+30** persistiert → Mail an Kunde). Per-Rechnung-Adress-Dialog (v0.15.0) entfernt. Snapshot-Feld `rechnungen.rechnungsadresse` (Migration 105) bleibt technisch bestehen (Resolver Override→Betrieb), wird aber nicht mehr gesetzt.
- **v0.15.0** (25.06) Rechnungsadresse-Dialog im Detail + Neu-Versand (durch v0.15.1 zu „Adresse beim Betrieb" umgebaut). „Neue Buchung"-Kachel entfernt (v0.14.1) + Adress-Button-CanvasKit-Fix (v0.14.2).
- **v0.14.0** (25.06) **Pro-Rechnung Rechnungsadresse** (Override/Snapshot, Migration 105 `rechnungen.rechnungsadresse` jsonb): „Adresse anpassen" im Rechnungs-Detail ändert nur diese eine Rechnung (Betrieb/andere Rechnungen unberührt); PDF/Mahnung nutzen den Override via reinem Resolver `effektiveRechnungsadresse`; „Zurücksetzen" auf Betriebsadresse.
- **v0.13.3** (25.06) Temporären Rechnungs-Nachversand-Screen entfernt (Backlog abgearbeitet).
- **v0.13.2** (25.06) QR-Referenz-Kollision robust (Suffix-Retry statt PostgrestException).
- **v0.13.1** (25.06) Schweizerkreuz im QR-Code (Rechnung+Mahnung) — QR war ohne ungültig.
- **v0.13.0** (25.06) **TP-C QR-Referenz (SCOR)**: Migration 104, Util `scor_referenz.dart`, Vergabe in `RechnungRepository.create`, SCOR in Rechnungs-/Mahnungs-PDF, Matching-Stufe 1. Plan: `docs/superpowers/plans/2026-06-25-camt-qr-referenz-scor.md`.
- **v0.12.x** (25.06) **TP-B Zahler→Betrieb-Lernen**: Aliase am Betrieb (`betriebe.zahler_aliase`, Migration 103), Matching-Stufe 2, Auto-Treffer-Lern-Schalter. Plan: `docs/superpowers/plans/2026-06-25-camt-zahler-betrieb-lernen.md`.
- **v0.11.x** (20.06) **TP-A Import+Abgleich vereint** (Stichtag 11.03, `AbgleichVorschau` geteilt), Bestätigungs-Modus, Doppelbuchung-Fix (Migration 102), Reversibilität, Lohn/Miete-Trennung.
- **v0.10.138** (20.06) camt-Forderungsabgleich **TP2** (Engine `ForderungsAbgleichService`, Archiv `camt_dateien` Migration 101, ⚪-Bucket, existsZeitraum-Dialog).
- **v0.10.133** (19.06) Forderungen-Historie **TP1** (7'786 Reinigungen + 4'438 Rechnungen, offen CHF 105'240.95, Scans verknüpft, Pagination-Fix).
- **v0.10.130** (18.06) Berichtswesen-Umbau, Geschäfts-Einstellungen (`geschaeft_einstellungen`), Lohn-Trennung, MWST-Sätze-Historie, Gast-Account deaktiviert.
- **v0.10.118** (13.06) Forderungen-Hub; Buchhaltung Phase 0b/1/2 (Excel-Voll-Import 14'552 Zeilen 2019–Nov 2025, Bilanz geht auf, Audit/Abschreibungs-Werkzeug, MWST-Bugfixes).
- **Datenkorrektur** (25.06) Phantom-Zahlung 17.05. (4 Rechnungen 2026-05-0611–0614) bereinigt.
- **Früher:** Heineken-Monatsraster + Auto-Buchung, Lohnbuchhaltung, Spesen-OCR, camt.053-Import, Material-Modul, Termine/Kalender, Störungen/Pikett, Kontakt-Sync u.v.m. → siehe git-History + Memory.

---

*Detaillierte Technik-Kontexte: Memory-Index + `docs/superpowers/` (Specs/Pläne) + git-History.*
