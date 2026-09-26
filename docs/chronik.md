# SBS Projer App — Chronik

Was wann gebaut wurde, neueste Einträge zuerst. Ausgelagert aus `Projekt.md`
am 22.09.2026; die Abschnitte ab «Laufende Chronik» sind **wörtlich**
übernommen, nichts wurde gekürzt oder umformuliert. Die Einzelheiten zu jeder
Version (Begründung, Prüfung, Rückweg) stehen in `ToDo.md`, ältere im
dortigen Archiv.

- 26.09.2026 — v0.146.0 Restposten-Runde: analyze 0, Datumsauswahl deutsch, CanvasKit-Ratsche 83, Tourenplan-Ladefenster, Altlasten
- 26.09.2026 — v0.145.0 Touren auf einen anderen Tag verschieben (Stopp und ganzer Tag)
- 26.09.2026 — v0.144.0 Analyse-Runde 5: Tagesbetrieb (Start-Weg, Entwurf, Heute-Karte, Betriebs-Akte, Zahlungsart)
- 26.09.2026 — v0.143.0 Analyse-Runde 4: Bausteine & Aufräumen (−3700 Zeilen netto)
- 26.09.2026 — v0.142.0 ZahlungKern: ein Zahlungsweg, atomar (Migration 209)
- 26.09.2026 — v0.141.0 Betriebsferien aus der Tabelle (R7), Kalender-Schlüssel nach Datum
- 26.09.2026 — v0.140.0 Analyse-Runde 2 Teil 1: eine Abschlusskette (R1, T1, T5, T6)
- 25.09.2026 — v0.139.0 Analyse-Runde 1 «Sicherheit der Zahlen» (R2/R3/R4/R6/R11/Q1/Q3/Q5, R9 geklärt)
- 25.09.2026 — Edge Function send-pdf-mail v15: JWT-Pflicht, Header-Schutz; Ferien nachgetragen
- 25.09.2026 — v0.138.0 «Beleg»-Knopf auf Heute (Spesen-Scanner direkt)
- 25.09.2026 — Edge Function send-rechnung-mail v24: JWT-Pflicht, Pfadprüfung
- 25.09.2026 — v0.137.0 Kundenguthaben (Verrechnung mit der nächsten Rechnung)
- 24.09.2026 — v0.136.0 Mahnwesen Teil 3: Hinweis beim Service, bar einkassieren
- 24.09.2026 — v0.135.0 Mahnwesen Teil 2: Mahnfall (Heineken, Betreibung)
- 24.09.2026 — v0.134.1 Mahnlauf-Sperre unverknüpfte Zahlung
- 24.09.2026 — v0.134.0 Mahnwesen Teil 1: Mahnlauf
- 23.09.2026 — v0.133.3 Telefon-Eingabe, Betrieb mit Ort
- 23.09.2026 — v0.133.2 Zeitauswahl überall 24 h
- 23.09.2026 — v0.133.1 Pikett mit KW
- 22.09.2026 — v0.133.0 Suche
- 22.09.2026 — v0.132.0 Rechnungs-Bereich, Event-Karte
- 22.09.2026 — v0.131.0 Navigation «Mehr»
- 17.–22.09.2026 — v0.110.0 bis v0.130.0
- Laufende Chronik 07.07.–17.09.2026
- Ursprünglicher Projektplan (Februar 2026)
- Erledigt-Liste Februar–Juni 2026 (Punkte 1–209)

---

## 26.09.2026 — v0.146.0 Restposten-Runde («mach alles, was du selbständig machen kannst»)

Keine Migration. Fünf Implementer (Opus, teils in Worktrees) und zwei
Reviews. Alles ohne Frist, aber lange aufgelaufen.

- **`flutter analyze` 14 → 0:** `dart:html` → `package:web` + `dart:js_interop`
  (4 Web-Helfer: Download, camt-Datei-Picker, Google-Redirect, PDF-Tab; Weichen
  auf `dart.library.js_interop`), `value` → `initialValue` an 6 Dropdowns (mit
  `ValueKey`, wo der Wert von aussen gesetzt wird; Wächter-Widget-Test hält
  das SDK-Verhalten fest).
- **Datumsauswahl und Material-Texte auf Deutsch:** `flutter_localizations`,
  Delegates + `Locale('de','CH')` (Konstanten in `core/config/lokalisierung.dart`,
  Wächter). Kein stiller Formatwechsel: `Intl.defaultLocale` bleibt ungesetzt,
  alle `NumberFormat` tragen eine Locale, Datumsmuster sind zahlenbasiert
  (vom Reviewer mit 87 Formatierungen vorher/nachher belegt). Bundle +82 KB gzip.
- **CanvasKit-Ratsche 96 → 83:** «Arbeit beginnen» (`TapKnopf` mit `farbe`),
  Abgleich-Vorschau (5), Störungs- und Montage-Formular (7) auf `TapKnopf`.
- **Tourenplan, drei Altlasten mit Datenverlust-Potenzial:** (1) eine Änderung
  im Lade-Fenster nach dem Tag-Tipp wurde unter dem NEUEN Tag gespeichert
  (`_scheduleSave` liest jetzt den Tag, dem der Plan gehört); (2) im Fenster
  ist die Zeitachse jetzt gesperrt («Plan wird geladen…»), Übernehmen und
  Verschieben tun nichts; (3) ein Ladefehler wird nicht mehr als leerer Plan
  behandelt (Fehlerzustand mit «Erneut laden» statt `resetLeer`).
- **Heineken:** Rechnungsdetail hat einen Rückweg (`RueckwegKnopf`, Rückfall
  `/heineken`, auch nach dem Löschen); Service ohne veränderliche
  `static`-Felder (PO-Nummer und Anfahrtspauschale pro Aufruf — im PDF-Dienst
  war es ein echtes Rennen, weil die build-Closure erst bei `save()` läuft;
  Wächter); `regenerierePdf` nimmt die gespeicherte PO-Nummer; Zuweisungen
  setzen das Dropdown bei Speicherfehler zurück.
- **PDF im neuen Tab ohne Popup-Blocker:** Dokumente-Liste öffnet den Tab
  synchron im Tipp und lädt das PDF nach (vorher nach `await` blockiert,
  ohne Rückmeldung).
- **camt-Import:** Abbrechen des Datei-Dialogs endet still (vorher hing der
  Spinner endlos; seit dem Umbau kurz ein roter Text).
- **Pikett:** gespeicherte Feiertagszahl wird beim Bearbeiten nicht mehr
  überschrieben; ISO-Wochenjahr statt Kalenderjahr (29.12.2025 = KW 1/2026).
- **Buchung frei buchen:** Wechsel von einer Vorlage mit Zahlungsweg
  kreditor/debitor stürzte im Debug ab bzw. speicherte `kreditor` still mit.
- **Aufräumen:** 24 aufruferlose Repository-Methoden + `zaehleBelege` entfernt
  (native Isar-Vorlage unangetastet); drei Server-Migrationen ohne lokale
  Datei rekonstruiert (101b, 165b, 166b) — Migrations-Ablage komplett.
- **Daten:** sechs historische Ferien-Slots aus den Altspalten in
  `betrieb_ferien` nachgetragen (Tabelle jetzt vollständig; Altspalten bleiben
  vorerst — 403 Code-Stellen + Isar-Schema, siehe ToDo).
- **Zweiter Review, vor dem Deploy behoben:** Ladekreis ohne Ende nach einem
  Glocken-Sprung in eine zweite Tourenplan-Instanz (`isCurrent`-Prüfung);
  Ladefehler blieb im Provider-Cache und wurde in den Einplanen-Pfaden
  (Aufgaben, Diktat, Störungs-/Montageformular) nicht abgefangen — das Diktat
  meldete «Speichern fehlgeschlagen», obwohl der Einsatz gespeichert war
  (Duplikat-Gefahr); «Frei buchen» wieder ohne Pflicht-Zahlungsweg, neu mit
  «Intern (ohne Geldfluss)»; `_selectedDate`/Wochenleiste rechnen in
  Kalendertagen (ab 25.10.2026 hätte «nächste Woche» auf So 23:00 gezeigt);
  Arbeitstag-Schreiber (Pause, Start, Feierabend) schreiben bei Ladefehler
  nichts mehr (vorher löschte ein Pause-Tipp Beginn/Ende/km); Pikett-Pauschale
  beim Bearbeiten nicht mehr überschrieben.
- Konsolenmeldung «Null check operator» beim Laden von Heute: mit Source-Maps
  nicht reproduzierbar (v0.145/v0.146), Beobachtung geschlossen.
- Browser geprüft (360 px): Datumsauswahl («Fr., 25. Sept.», ABBRECHEN/OK),
  Störungs-, Montage-, Buchungs-, Pikett-, Kontakt-Formular, Heineken-Detail
  per URL (Pfeil → Liste), Startseite. Nicht sichtbar prüfbar: «Arbeit
  beginnen» (keine offene Störung/Montage) und PDF-Tab (Panel fängt keine
  Popups) — beides per Widget-Test bzw. Code-Vergleich abgedeckt.
- TESTZAHL Tests grün, `flutter analyze` 0.

---

## 26.09.2026 — v0.145.0 Touren auf einen anderen Tag verschieben

Plan `docs/superpowers/plans/2026-09-26-touren-verschieben.md`. Keine
Migration. Auftrag Daniel: «ein einfacher Weg, um geplante Touren auf einen
anderen Tag zu verschieben».

- **Einzelner Stopp:** Block-Sheet → «Auf anderen Tag verschieben» →
  Datumsauswahl (ab heute, vorbelegt Folgetag). Hat der Betrieb am Zieltag
  Ruhetag, fragt ein Hinweis nach. Störung, Montage und HeiGenie ziehen ihr
  `geplant_am` mit (`umplanenAufTag`, schreibt NUR das Datum — Zeit und Dauer
  bleiben; Wächter `test/tagesplan_verschieben_waechter_test.dart`).
- **Ganzer Tag:** Kopfzeile ⋮ → «Ganzen Tag verschieben…» → Rückfrage
  «6 Stopps auf Di 17.11. verschieben? Dort stehen schon N Stopps. Ruhetag am
  Zieltag: …». Erledigte Stopps (gleiche Ermittlung wie die Zeitachse, neu
  geteilt in `tagesplan_ist_zeiten.dart`, plus abgeschlossene Einsätze) und
  **abgemachte Saison-Termine bleiben am alten Tag** (Entscheid Daniel
  26.09.: «die sind ja fix abgemacht») und werden in der Rückfrage genannt.
  Arbeitstag-Rahmen bleibt unberührt. Meldung mit «Anzeigen» wechselt den Tag
  im selben Screen.
- **Speichersicher:** erst am Zieltag anhängen (Zieltag frisch aus der DB,
  keine doppelten ids, bestehende Reihenfolge bleibt), dann am alten Tag
  entfernen und sofort speichern; während des Ablaufs ist der Screen
  gesperrt; Teilfehler werden ehrlich gemeldet («am Zieltag angehängt, aber
  hier nicht entfernt»).
- **Nebenbei behoben (alter Fehler):** Ein Tagwechsel innerhalb von 600 ms
  nach einer Plan-Änderung verwarf das ausstehende Speichern — jetzt wird es
  mit dem alten Tag sofort ausgeführt.
- **Kopfzeile auf 360 px:** «Reihenfolge optimieren», «Reinigungen eines
  Tages übernehmen», «Ganzen Tag verschieben…» und «Tagesplan leeren…» liegen
  im ⋮-Menü; sichtbar bleiben Datum, Karte und «Fällige übernehmen».
- Review (Opus) mit Nachbesserungen (Sperre, Sofort-Speichern, Dauer bleibt,
  Termine/abgeschlossene Einsätze ausgeschlossen, ehrliche Meldungen).
- Browser geprüft (360 px, Wegwerf-Plan 16.11.): Menü, Datumsauswahl,
  Rückfrage mit Ruhetag-Hinweis, ganzer Tag verschoben (DB: 0/6), «Anzeigen»,
  Einzel-Stopp per Block-Sheet (5/1). Testtage danach gelöscht.
- 2559 Tests grün, `flutter analyze` 14 (unverändert).

---

## 26.09.2026 — v0.144.0 Analyse-Runde 5: Tagesbetrieb

Plan `docs/superpowers/plans/2026-09-26-runde5-tagesbetrieb.md`. Keine
Migration. Letzte der fünf Runden aus der App-Analyse vom 25.09.

- **Ein Start-Weg** (`einsatz_start.dart`): Tourenplan, Heute-Karte und
  Diktat starten einen Einsatz über dieselbe Funktion; Saison-Art und
  Diktat-Notiz gehen als Query mit ins Reinigungsformular.
- **Entwurf** (`reinigung_entwurf.dart`, `reinigung_entwurf_speicher.dart`):
  Das Reinigungsformular sichert alle 2 s lokal (shared_preferences, je
  Betrieb, 2 Tage gültig). Beim Wiederöffnen erscheint das Band
  «Angefangene Reinigung von 09:12 — Fortsetzen / Verwerfen». Die erste
  Änderung bei offenem Band gilt als «neu beginnen» (alter Entwurf weg).
  Eine Diktat-Notiz wird beim Fortsetzen nicht überschrieben, sondern
  angehängt.
- **Heute-Karte nur Draussen-Aufgaben** (`Aufgabe.draussen`): Entwürfe,
  laufende Arbeit (nur offene Einsätze — abgeschlossene ohne Arbeitsende
  zählen nicht), Arbeitstag ohne Ende, Diktate, Einsätze, Termine. Büro
  (Saison-Zähler, Versandvermerke, Rechnungen) nur in der Glocke.
  Versandvermerk-Abgleich ohne N+1.
- **Betriebsseite als Akte:** Geld-Block (offen, Mahnstufe, letzte Zahlung;
  Tipp → Rechnungsliste mit neuem Filter «Unbezahlt (inkl. gemahnt)» und
  Betriebssuche) und eine Einsätze-Sektion inkl. Montagen (Einsätze-Screen
  `?betrieb=<id>`, alle Jahre).
- **Zahlungsart im Formular:** Zeile «Zahlungsart · …» mit Bottom-Sheet;
  der Abschluss-Dialog kommt nur noch, wenn etwas zu entscheiden ist
  (`abschluss_dialog_regel.dart`).
- **Ladewege:** `countOffene` statt Vollladen, ein Buchungs-Load für die
  Berichte, autoDispose-Listen.
- **Umwege geschlossen:** Vorschläge-Zeile, Google-Termine unter Mehr,
  Lohn-Sätze-Icon, Suche mit Zusatzzielen, Tages-Karte als Route
  `/touren/karte?datum=`; doppelte Einstiege entfernt.
- **Fix Mahnstufe:** `rechnungen.mahnung_stufe` ist 1–3 (erinnert = 1),
  vorher wurde 0–2 geschrieben; `mahnschreiben.stufe` bleibt der Index.
- Review (Opus) → Nachbesserungen `a7904ccc` + Filter «unbezahlt».
- Browser geprüft: Startseite (keine Büro-Aufgaben, keine Falschmeldung
  «Arbeit läuft» für die abgeschlossene Montage), Reinigungsformular
  (Zahlungsart-Zeile), Betriebsseite Blue Cinema (Geld-Block, Anlagen 3,
  Einsätze 44), Rechnungsliste aus dem Geld-Block.
- 2515 Tests grün, `flutter analyze` 14 (unverändert).

---

## 26.09.2026 — v0.143.0 Analyse-Runde 4: Bausteine & Aufräumen

Plan `docs/superpowers/plans/2026-09-26-runde4-bausteine.md`. Keine Migration.
`lib/`: +2211 / −5918 Zeilen. Verhaltensneutral bis auf die unten genannten
Korrekturen.

- **Toter Code weg:** 18 Dateien (u. a. das alte Reinigungsprotokoll-PDF,
  camt-Import-Vorgänger, System-Diagramme, alter Kontakt-Screen) und 42
  Funktionen/Provider/Repository-Methoden ohne Aufrufer; `riverpod_annotation`
  und `riverpod_generator` aus der pubspec; Gast-Redirects auf `/einsaetze`.
- **`flutter analyze` 56 → 14:** `.g.dart` ausgeschlossen, `context.mounted`
  einheitlich, Klammern, Doc-Kommentare. Übrig: 6× `initialValue` (braucht
  Sichtprüfung), 8× `dart:html` (eigener Umbau).
- **Wächter:** `Zahlungsstatus`-Konstante gegen den DB-CHECK (083);
  CanvasKit-Ratsche über alle Screens (Material-Knöpfe dürfen nur weniger
  werden, keine in AppBar-Aktionen); Migrationsnummern (keine neuen Doppel/
  Lücken); eine Datumsauswahl; eine 5-Rappen-Rundung; Firmendaten nur an einer
  Stelle; Formular- und Detail-Bausteine.
- **Bausteine:** `zeigeDatumsauswahl` (29 Aufrufe), `DetailKarte`/`InfoZeile`
  (8 Detailseiten), `BetriebFeld` (5 Formulare), `ArbeitszeitBlock` (Störung,
  Montage), `MaterialSlots` (Störung, Montage, Eigenauftrag).
- **Korrekturen mit Wirkung:** MwSt-Satz wird pro Aufruf aus dem Datum
  bestimmt statt aus einem statischen Feld (vorher konnte der Satz eines
  früheren Aufrufs gelten); Jahresrechnungs-Vorschau rechnet mit dem Satz des
  gewählten Jahres; Ertragsbuchung einer Reinigung nimmt den Satz des
  Reinigungsdatums statt fix 8.1 % aus der Buchungsvorlage (vor 2024 liefen
  Rechnung und Buchung sonst auseinander); Eigenauftrag gab einen Controller
  doppelt frei.
- **Zahlungsdaten fest:** IBAN und Zahlungsempfänger im QR-Zahlteil, in
  Rechnungs-/Mahn-/Kontoauszug-/Heineken-PDF, im Rechnungsdetail und im
  QR-Dialog kommen aus der Konstante in `GeschaeftEinstellungen`, nie aus der
  DB (eine geänderte Einstellung darf kein Geld auf ein fremdes Konto lenken).
  Übrige Firmendaten (Absender, Telefon, MWST-Nr.) aus der DB mit Rückfall.
- Kosmetisch: Telefon im Heineken-PDF und in der Mail-Signatur als
  «076 566 58 06»; Betriebsvorschläge in Eigenauftrag/Eröffnung 400 px breit.
- Browser geprüft: Störung (Betriebssuche, Material-Suche), Montage,
  Eigenauftrag, Rechnungsdetail (IBAN, MwSt 8.1 %).
- Nicht in dieser Runde: Isar einfrieren (offene Frage an Daniel),
  `dart:html`, `initialValue`, «Arbeit beginnen» noch Material-Knopf.
- 2415 Tests grün, `flutter analyze` 14.

---

## 26.09.2026 — v0.142.0 ZahlungKern: ein Zahlungsweg, atomar (Migration 209)

Analyse-Runde 3 (`docs/superpowers/plans/2026-09-26-runde3-zahlungkern.md`).
Migrationen 209 (+ 209b/209d/209e Korrekturen aus den Reviews, 209c View).

- **Ein Zahlungsweg:** `ZahlungKern.erfassen(rechnungen, betrag, datum, weg)`
  plant in Dart (`zahlungKernPlan` aus `differenzPlan`, rein, getestet) und
  schreibt atomar per RPC `zahlung_erfassen`: Sperren (bezahlt/abgeschrieben,
  Status ≠ erwartet, Zahlung im Journal, Zahlungsfelder, Heineken nicht
  freigegeben, **abgeschlossenes Jahr**), Buchungen mit `zahlung_gruppe_id`,
  Rechnungen `bezahlt` nur mit erwartetem Status, Vorher-Stand (Status,
  6 Mahnfelder, Guthaben) in `zahlungsgruppen.vorher`. Umgestellt: Bank
  (Abgleich-Vorschau, Prüfliste), Bar, Guthaben-voll, Heineken Bank + Hand.
  Gelöscht: `CamtAutoBooker.run`, `ZahlungsdifferenzService.verbuchen/
  verbuchenSammel`, Status-Fallback in der Liste, alle drei alten Rückwege.
  Wächter `zahlung_kern_waechter_test.dart`: `'zahlungsstatus': 'bezahlt'`
  steht in keiner Dart-Datei mehr.
- **Rückgängig:** ein Knopf «Zahlung rückgängig» → `zahlung_zuruecknehmen`:
  ganze Gruppe (Sammelzahlung), Mahnfelder und Guthaben wiederhergestellt,
  Sperre bei Storno und bei abgeschlossenem Jahr; Altzahlungen ohne Gruppe je
  Rechnung (Rückfall auf höchste Mahnstufe aus den Datumsfeldern, Heineken →
  freigegeben).
- **Entscheide (von Daniel am 26.09.2026 bestätigt):** Minderzahlung
  erlassen = 3805 netto + 2200 MWST-Anteil (beleg_typ `abschreibung`, zählt
  in Ziff. 235 — View 209c rechnet das Netto aus der 3805-Zeile);
  Mehrzahlung ≤ CHF 5.00 → 8000, darüber → 2030 Kundenguthaben, beim
  Zuordnen wählbar (`MehrzahlungWahl` in Prüfliste + drei Vorschau-Dialogen);
  `zahlung_betrag` = zugeordneter Betrag je Rechnung; Bankbetrag rappengenau
  (94.03 auf 94.05 → 0.02 Verlust, 1020 stimmt mit dem Auszug).
- **Aufräumen:** Debitoren-Header (Sammel-Abschreibung ohne Beleg) entfernt;
  Delkredere-Knopf in der Abschlussprüfung mit Rückfrage; Einzelabschreibung
  mit `abschreibSperre` + `updateWennStatus` (auch Mahnfall-Vorprüfung);
  neue Regel «Status und Mahnstufe widersprüchlich».
- **Reviews fanden:** `geschaeftsjahr_abgeschlossen` zählte 2026 als
  abgeschlossen (JA2025-Buchungen liegen im Folgejahr → Regel wie
  `nachbuchGrenze`, 209b); Jahressperre fehlte beim Erfassen (209d); View
  Ziff. 235 nahm das Rechnungsnetto (209c); Gruppensuche übersah reine
  3805-Zeilen (209e); Bankbetrag wurde auf 5 Rappen gerundet.
- **Probe auf der Produktion (reversibel):** Rössli 2026-09-1459 —
  Altzahlung zurückgenommen (offen, Zeile weg, Bank-Schlüssel frei), per
  Kern neu erfasst (Gruppe), Gruppe zurückgenommen, erneut erfasst;
  Endzustand = Ausgangszustand. 2026-04-0186 (Zahlung 31.12.2025): rote
  Meldung «abgeschlossenes Geschäftsjahr 2025», nichts geändert.
- Verhaltensänderung: Barzahlung mehrerer Rechnungen ist «alle oder keine»
  (eine Gruppe). Heineken-Detail hat weiterhin keinen Rückweg.
- `flutter analyze` 56.

---

## 26.09.2026 — v0.141.0 Betriebsferien aus der Tabelle (R7), Kalender-Schlüssel nach Datum

Runde 2 Teil 2. Migration 208, Edge Function `google-calendar-sync` neu deployed.

- **Befund (Erkundung 26.09.):** Das Betriebsformular schrieb die fünf
  Altspalten `ferien*_start/ende`, Tourenplan/Vorjahreshinweis lasen die
  Tabelle `betrieb_ferien` — und entgegen der Analyse lasen auch **Detail und
  Heineken-Raster noch die Altspalten** (Laden über `getById`/`getAll` statt
  `betriebeProvider`). Ein UI zum Pflegen der Tabelle gab es nicht.
- **Neu:** Widget `BetriebFerienListe` (widgets/) — Liste (künftige zuerst),
  «+ Ferien» mit Von/Bis-Dialog, Löschen mit `gefahrRueckfrage`; schreibt
  direkt in `betrieb_ferien` (Quelle `kunde`). Formular, Detail (lesend) und
  Raster nutzen die Tabelle; das Formular schreibt die Altspalten nicht mehr
  (sie frieren auf dem Stand 31.07. ein — Entfernen siehe ToDo). Schalter
  «Keine Betriebsferien» wirkt jetzt überall (`wirksameFerienSlots`), vorher
  ignorierte ihn der Tourenplan. Wächter `ferien_quelle_waechter_test.dart`.
- **Kalender-Schlüssel (Review):** Eröffnungs-/Endreinigungen im Google-
  Kalender hiessen `ferienN_…` nach Listenindex — mit pflegbaren Perioden
  wären Einträge doppelt oder verwaist entstanden. Neu `ferien_<von>_…`
  (`ferienSlotKey`), die App schickt `alle_ferien_keys`, die Edge Function
  räumt veraltete Zuordnungen samt Kalendereintrag weg
  (`ferien_keys.ts`, 64 Deno-Tests). Migration 208 schreibt die 9
  bestehenden Zuordnungen um.
- Browser geprüft (Surselva): Detail zeigt Tabelle; Formular: Periode
  anlegen → Liste → löschen mit Rückfrage; DB danach unverändert.
- 2347 Tests grün, `flutter analyze` 56.

---

## 26.09.2026 — v0.140.0 Analyse-Runde 2 Teil 1: eine Abschlusskette (R1, T1, T5, T6)

Plan `docs/superpowers/plans/2026-09-26-runde2-eine-kette.md`. Keine Migration.

- **Eine Kette:** `ReinigungAbschlussService.abschliessen(r, betrieb)`
  (services/rechnung) bündelt Rechnung + Versand (`erstelleUndSende`),
  Ertragsbuchung, Nachholen (14 Tage, 20 s), Bergkundenpauschale (idempotent
  pro Reinigung **und** pro Betrieb+Tag) und Kulanz-Merker. Formular und
  Reinigungs-Detail rufen nur noch diesen Service und zeigen seine Meldungen
  (Info/Warnung/Fehler). Das Formular schrumpfte von 2913 auf ~2470 Zeilen.
  Wächter `abschlusskette_waechter_test.dart`.
- **Versandvermerk (aus dem Review):** Nach einem Mail-/Post-Fehler fragt
  `erstelleUndSende` den Server (`istVersandVermerkt`); nur bei belegtem
  Versand gilt «nicht erneut senden», bei «unklar» setzt der Client keinen
  Vermerk mehr; scheitert der Client-Vermerk selbst, ebenfalls Nachfrage statt
  roter Kettenfehler. Eigene `VersandFehler`-Ausnahme mit genauem Text.
  Wächter `versand_vermerk_hinweis_waechter_test.dart`.
- **R1 Korrektur statt Löschen:** Bearbeiten einer abgeschlossenen Reinigung
  fasst Rechnung/Buchung nur an, wenn sich Mengen/Typ/Kulanz/Bergkunde/Datum/
  Zahlungsart/Anlagen geändert haben (`preisrelevantGeaendert`, Anlagen als
  Menge — 5782 Altfälle ohne `anlage_ids`), und nur ohne Sperre
  (`korrekturSperre`: bezahlt, Jahresrechnung, Mahnfall, gemahnt, versendet/
  übergeben, abgeschlossenes Jahr). Sperre → Band im Formular + Dialog
  «Änderung nicht möglich», nichts gespeichert; Detail-Löschen ebenso gesperrt.
  Ohne Sperre: Ertragsbuchung **storniert** (nie mehr `deleteByBeleg`),
  Rechnung entfernt, neu angelegt; Fehler sichtbar mit Phase («Buchung
  storniert, Rechnung NICHT entfernt»). Gespeicherte Preise werden im Edit-Pfad
  nicht mehr stillschweigend neu gerechnet. Duplikat-Check der Ertragsbuchung
  und `belegIdsMitBuchung` ignorieren stornierte Zeilen. Nebenbefund behoben:
  `wurdeGeradeAbgeschlossen` war wegen Objekt-Identität immer false
  (Fahrzeit-Lernen/Pausenprüfung liefen beim Abschluss einer gespeicherten
  Reinigung nie).
- **T1 Protokollfoto:** Web lädt das Foto sofort nach der Aufnahme hoch
  (Fortschrittsbalken, «Hochgeladen ✓»), Fehler als rotes Band mit «Erneut
  versuchen»; Speichern wartet (max. 30 s) und versucht es nochmals, dann rote
  Snackbar statt stillem `debugPrint`. Neue Aufgabe «Reinigung ohne
  Protokollfoto» (Vorrat, ab 26.09.2026, ohne Heineken-Monteur, NULL-Falle
  beachtet).
- **T5:** Pausen-Prüfung (GPS + Sheet) läuft erst nach der Kette.
- **T6:** Formular entrümpelt — «Wasser im Kühler gewechselt» weg (0 von 405),
  «Ende» nur beim Bearbeiten, HeiGenie nur noch als Altwert sichtbar,
  HeiGenie-Mail entfernt; 10 Material-Buttons → `TapKnopf` (Abschliessen,
  Speichern, Dialog, Foto, PDF, QR); `TapKnopf` zentriert Inhalt, min. 48 px.
- Browser geprüft (Sunset, versendet): Band, Sperr-Dialog, DB unverändert,
  Detail-Löschen gesperrt; neues Formular ohne Ende-Feld, Knöpfe TapKnopf.
- Hinweis Android-Vorlage: Kette und Kulanz-Merker laufen nur auf Web (vorher
  lief nur der Merker auch nativ).
- 2337 Tests grün, `flutter analyze` 56 (unverändert).

---

## 25.09.2026 — v0.139.0 Analyse-Runde 1 «Sicherheit der Zahlen»

Erste Runde aus `docs/app-analyse-2026-09-25.md` (§6). Migration 207.

- **R2 `istZahlbar`** (`core/util/rechnung_status.dart`): Bankabgleich und
  Zuordnen-Dialog nehmen jetzt auch gemahnte Rechnungen (`erinnert`,
  `mahnung_1/2`) und Jahresrechnungen; Heineken-Monatsrechnungen nur ab
  `freigegeben` (`heinekenZahlbar`). Wächter `zahlbar_waechter_test.dart`.
- **R3 Heineken:** Detail bucht **erst** 1100/3400, **dann** setzt es
  `freigegeben` (`HeinekenBuchungService.freigeben`, Doppeltipp gesperrt);
  Bankmatcher setzt eine nur `gesendet`e Rechnung nicht mehr auf `bezahlt`
  (`HeinekenZahlungGesperrt`, Sperrgrund im Abgleich sichtbar). Monatsregel
  «freigegeben ohne Ertragsbuchung» + Band «Ertragsbuchung nachholen» im
  Detail. **Migration 207:** Unique-Teilindex «eine aktive Ertragsbuchung je
  Rechnungsbeleg» (vorher 0 Duplikate geprüft).
- **R4 Versand:** Mail-Rückfall hebt den Status nur noch von `offen` auf
  `gesendet` (`hebeStatusNachVersand`, 4 Stellen), bezahlt/gemahnt bleibt.
  Wächter `versand_status_waechter_test.dart`.
- **R6 Rückfragen:** «Tagesplan leeren» und «Google trennen» fragen über
  `gefahrRueckfrage()` nach (im Browser geprüft: Dialog, roter TapKnopf,
  Abbrechen).
- **R11 / Q3 Edge Functions:** alle Functions prüfen den Benutzer selbst
  (`ermittleUserId`), `parse-oeffnungszeiten` mit URL-Filter (SSRF),
  `betriebsdaten-abgleich` nur mit `x-cron-secret` (Vault, Migration 206,
  `limit` ≤ 200), `anfahrt-google` seitenweise, `google-calendar-sync` nur
  eigene Zeilen, `send-raster-mail` ins Repo geholt (v15, siehe unten);
  `config.toml` vollständig, `_waechter_test.ts` (61 Deno-Tests) prüft
  getUser-Aufruf, Ordner je `invoke`-Name und verify_jwt.
- **Q1 Gefahr-Wächter** geschärft (`X.icon(`, `Colors.red`, ungefärbte
  Lösch-Knöpfe); 21 Bestätigungen auf `TapKnopf(gefahr: true)`, Ausnahmeliste
  leer.
- **Q5 Prüfregeln:** «Debitoren 1100 = offene Rechnungen − Guthaben»
  (Jahreskunden ohne Rechnung berücksichtigt, Toleranz 0.50) und
  «Kundenguthaben 2030 = Guthaben je Betrieb» in der Abschlussprüfung.
- **R9 geklärt:** −13'776.86 = fehlende Ertragsbuchung Heineken Juli 2026
  (10'102.16, am 25.09. über den neuen Knopf nachgebucht) + Excel-Altbestand
  −3'674.70 (Entscheid Daniel offen, ToDo).
- 2301 Tests grün, `flutter analyze` 56 (unverändert).

---

## 25.09.2026 — Edge Function send-pdf-mail v15: JWT-Pflicht, Header-Schutz; Ferien nachgetragen

- **send-pdf-mail** (Berichte, Anlagen-Steckbrief, Event-Abschluss) lief ohne
  jede Auth-Prüfung — offenes Mail-Relay über Daniels Gmail (Analyse 5,
  25.09.). Neu wie send-rechnung-mail v24: `verify_jwt = true`, eigene
  Token-Prüfung, kein CR/LF in `to`/`subject` (Header-Injection), Dateiname
  bereinigt, PDF-Grösse gedeckelt. Geprüft: ohne Token 401, mit Token 200
  (Test-Mail an Daniel), Bcc-Injection 400.
- **Ferien-Lücke** (Analyse 6): Das Betriebsformular schreibt nur die alten
  Spalten `ferien*_start/ende`, Tourenplan und Heineken-Raster lesen seit
  Migration 160 nur `betrieb_ferien`. Drei künftige Perioden nachgetragen
  (Surselva Disentis 11.10.–04.11., Posta Veglia Flond 02.–23.11., Edelweiss
  Vals 01.–26.12.). Reparatur des Formulars offen (ToDo).

---

## 25.09.2026 — v0.138.0 «Beleg»-Knopf auf Heute (Spesen-Scanner direkt)

- Neben «Diktieren» ein zweiter schwebender Knopf **«Beleg»** (Kamera) →
  `/spesen`; der Scanner öffnet sofort die Kamera, die KI erkennt Tanken
  (6200), Material (4004), Essen usw. und den Zahlungsweg wie bisher.
  Entscheid Daniel: nur Bar-/Karten-Belege, Lieferantenrechnungen weiterhin
  über Eingangsrechnungen (PDF). Suche findet den Scanner neu auch unter
  beleg/quittung/tanken/benzin/material/scanner. Zwei FABs mit eigenen
  `heroTag`s. Geprüft im Browser (360 px). 2234 Tests.

---

## 25.09.2026 — Edge Function send-rechnung-mail v24: JWT-Pflicht, Pfadprüfung

- Befund 23.09.: Function lief ohne JWT-Prüfung, `userId` und alle
  Storage-Pfade kamen ungeprüft aus dem Body — offener Mailversand über
  Daniels Gmail und Lesezugriff auf fremde Pfade möglich.
- Neu: `verify_jwt = true` (config.toml + Deploy), `ermittleUserId` prüft das
  Token selbst, Body-`userId` muss dazu passen; `istUuid`, `pdfDateinameErlaubt`,
  `protokollPfadErlaubt` in `pfad_pruefung.ts` (20 Deno-Tests). Test-Modus
  ebenfalls nur mit Token. Ohne Token/nur Anon-Key: 401 (curl-geprüft).

---

## 25.09.2026 — v0.137.0 Kundenguthaben (Verrechnung mit der nächsten Rechnung)

Plan `docs/superpowers/plans/2026-09-25-kundenguthaben.md`, Migration 205
(`rechnungen.guthaben_verrechnet`). Entscheid Daniel: schlanke Variante.

- **Guthaben** = Saldo Konto 2030 je Betrieb (Überzahlung 1020/2030 mit
  `beleg_id` = überzahlte Rechnung) minus bereits reservierte Abzüge auf
  offenen Rechnungen (keine Doppelverrechnung).
- **Nächste Kundenrechnung/Jahresrechnung:** Abzug wird gesetzt; PDF zeigt
  «abzüglich Kundenguthaben» und «Zu zahlen», QR-Schein und Mail nennen den
  reduzierten Betrag. Deckt das Guthaben alles, wird sofort verrechnet und die
  Rechnung ist bezahlt (PDF ohne Zahlteil).
- **Zahlungseingang** (Bank oder bar): Verrechnung 2030 an 1100 statt Verlust
  3805; Regel: Zahlung < Brutto − 0.05 → verrechnen (Zwischenbeträge = Mehr-
  zahlung 8000), voller Betrag → Guthaben bleibt. «Zahlung rückgängig» stellt
  den Abzug wieder her. Abschreibung: nur «zu zahlen», MWST anteilig.
- **Mahnlauf:** solche Rechnungen in eigener Sektion «Mit Guthaben verrechnet —
  manuell prüfen»; Kontoauszug mit Zeile «Verrechnung Guthaben».
- Geprüft im Browser (360 px): Rechnungsdetail mit Guthaben-Zeilen, Mahnlauf-
  Sektion; Testwert danach zurückgesetzt. 2234 Tests.

---

## 24.09.2026 — v0.136.0 Mahnwesen Teil 3: Hinweis beim Service, bar einkassieren

Plan `docs/superpowers/plans/2026-09-24-mahnwesen-teil3.md`. Entscheid Daniel:
kein TWINT (Geschäftskonto hat keines) — vor Ort nur bar (Kasse 1000), sonst
QR-Rechnung per E-Banking.

- **Band** in Reinigung, Störung und Montage: orange «N Rechnungen gemahnt,
  CHF … offen (1. Mahnung vom …)», rot bei Mahnfall «— nur gegen Barzahlung».
  Nur Hinweis, blockiert das Formular nie.
- **Sheet:** offene Rechnungen (ab 2026) mit Häkchen, «QR zeigen» (Rechnungs-
  PDF), «Bar einkassieren» → Soll 1000 / Haben 1100 je Rechnung (5 Rappen),
  Rechnung bezahlt gegen den DB-Stand, Vorher-Stand in der Buchungsnotiz.
  Teilfehler melden «X von Y kassiert». Nach Kassieren eines ganzen Mahnfalls
  Hinweis «Mahnfall abschliessen». Glocke während Sheet/Dialog ausgeblendet.
- **Rechnungsdetail:** «Barzahlung rückgängig» (nur laufendes Jahr, stellt den
  Mahnstand wieder her); «Kassenbuchung entfernen» für einen halben Zustand.
- Geprüft im Browser (360 px): Band, Sheet, Kassieren 94.05 (Buchung
  1000/1100 in der DB), Rückgängig (Mahnstand zurück, Buchung weg); Test-
  Rechnung danach zurückgesetzt. 2150 Tests.

---

## 24.09.2026 — v0.135.0 Mahnwesen Teil 2: Mahnfall (Heineken, Betreibung)

Plan `docs/superpowers/plans/2026-09-24-mahnwesen-teil2.md`, Migration 204.

- **Mahnfall** (`mahnfaelle`, Screen `/rechnungen/mahnfall/:id`): Ist die
  Frist der letzten Mahnung + 5 Tage vorbei, zeigt der Mahnlauf die Sektion
  «Heineken einschalten». «Mahnfall eröffnen» prüft frisch (Bank-, Zahlungs-,
  Gutschrift-Sperre) und schickt Heineken (Zuweisung «Mahnwesen» = Markus
  Scherrer) eine Mail mit Kontoauszug je Jahr und Rechnungskopien.
- **Vier Ergebnisse:** vermittelt (Frist +20 Tage), Heineken übernimmt (nur
  erfasst + dringende Aufgabe «mit Daniel prüfen», keine Buchung), Konkurs
  (Einzelabschreibung, Hinweis Konkursamt), Betreibung.
- **Betreibung:** Datenblatt für EasyGov (Schuldner aus Rechnungsadresse,
  Rechtsform, Betreibungsamt), Forderung je Rechnung «nebst 5 % Zins seit
  Erinnerung», Kostenvorschuss nach GebV SchKG Art. 16, Schritte mit Datum,
  Fortsetzungsfenster (SchKG 88), bei Rechtsvorschlag Protokoll-Links.
- **Sicherungen:** Fall-Rechnungen sind im Mahnlauf und bei «Jetzt mahnen»
  eingefroren (auch nach Übernahme/Rückzug); Abschreiben bricht bei gebuchter
  Zahlung ab, bucht zuerst und nie doppelt; Status-Updates nur gegen den
  DB-Stand. Glocke: Heineken 20 Tage ohne Ergebnis, Frist abgelaufen,
  Fortsetzung möglich, Verwirkung, Übernahme verbuchen.
- Testmodus bleibt: Heineken-Mail «TEST an: …» an Daniel (Wächter erweitert).
- Geprüft im Browser (360 px): Test-Fall Hemingway eröffnet, Mail nur an
  Daniel, Betreibung mit Datenblatt/Zins/Kostenvorschuss 20.00/Protokoll-Links;
  danach Fall gelöscht und Rechnungen zurückgesetzt. 2115 Tests.

---

## 24.09.2026 — v0.134.1 Mahnlauf-Sperre unverknüpfte Zahlung

- **Neue Sperre:** Eine Kundenzahlung ab 01.01.2026 ohne Verknüpfung zu einer
  Rechnung (Buchung 1020/1100 ohne `beleg_id`) sperrt den Betrieb (Kürzel in
  der Belegnummer) oder, wenn nicht zuordenbar, den ganzen Mahnlauf.
  Heineken-Zahlungen zählen nicht. `unverknuepfteZahlungenAuswerten` in
  `mahnregeln.dart`, 10 Tests (2046 grün).
- **Datenarbeit dazu:** 3181 Excel-Zahlungen (2019–03/2026) per `beleg_id`
  mit ihrer Rechnung verknüpft (Rückweg `import.excel_link_plan`), Triel
  3.00 abgeschrieben, Blockhuus zugeordnet — Einzelheiten in ToDo.md.

---

## 24.09.2026 — v0.134.0 Mahnwesen Teil 1: Mahnlauf

Spec `docs/superpowers/specs/2026-09-23-mahnwesen-design.md`, Plan
`docs/superpowers/plans/2026-09-23-mahnwesen-teil1.md`, Recherche
`docs/buchhaltung/mahnwesen-recherche-2026-09-23.md`. Migrationen 200–203.

- **Mahnlauf-Seite** (Rechnungen → Kunden → Karte «Mahnlauf», Glocke):
  Stufen Zahlungserinnerung / 1. / 2. Mahnung, nur Rechnungen ab 01.01.2026,
  zugestellt (Mail oder Tresen-Übergabe). Ein Schreiben je Betrieb mit einem
  QR-Einzahlungsschein je Rechnung; bei mehreren Rechnungen zusätzlich der
  Kontoauszug des laufenden Jahres. Kanal Mail oder Druck-PDF.
- **Kein Mahnen bezahlter Rechnungen:** Bank-Sperre (Auszug älter als 2 Tage
  oder Lücke in der Auszugskette), Gutschrift-Sperre (offene Gutschrift in
  der Prüfliste, deren Betrag/Name passt), frische Prüfung aus der DB direkt
  vor dem Erstellen, optimistische Sperre beim Hochstufen.
- **Protokoll** `mahnschreiben` mit Vorher/Nachher, **Zurücknehmen** nur für
  das jüngste Schreiben und nur, wenn sich seither nichts geändert hat.
  Mahnverlauf im Rechnungsdetail, «Jetzt mahnen» für eine einzelne Rechnung.
- **Testmodus:** Mails nur an Daniel (Betreff «TEST an: …»), PDFs mit MUSTER.
- Edge Function `send-rechnung-mail` v23: Zusatz-PDFs mit strenger
  Pfadprüfung. Alte Eskalationslogik (forderung_service) entfernt.
- **Bussenkonten:** 6280 Verkehrsbussen, neu 6281 Übrige Bussen;
  Steuerbussen aus dem camt-Import gehen auf 6281 statt 8900 (Migration 203).
- **Datenkorrektur 24.09.:** 30 Rechnungen waren laut Excel (Spalte
  Einzahlung) bezahlt, standen aber auf «offen» — der erste Mahnlauf hätte
  8 Betriebe zu Unrecht gemahnt. Auf bezahlt gesetzt; Ursache siehe ToDo.
- Geprüft: Test-Mahnung Hemingway (5 Rechnungen) kam nur bei Daniel an mit
  allen Anhängen; Zurücknehmen stellte alle 5 wieder auf «offen». 2036 Tests.

---

## 23.09.2026 — v0.133.3 Telefon-Eingabe, Betrieb mit Ort

- **Telefonfeld:** Der Cursor sprang nach jeder Taste ans Ende, und «079…»
  wurde als «07 91 …» gruppiert. Neuer `TelefonEingabeFormatter`
  (`lib/core/util/telefon.dart`) hält den Cursor hinter derselben Ziffer,
  gruppiert «079 123 45 67» und «+41 79 123 45 67» richtig, und eine
  eingefügte/übernommene Nummer steht sofort als «+41 79 123 45 67» da.
  Beim Speichern immer kanonisch (`formatiereTelefon`). Ersetzt drei Kopien
  des alten Formatierers (Personen, Betrieb, Betriebskontakt); Handy-Import
  und Diktat nutzen dieselbe Funktion.
- **Betrieb mit Ort** («Rössli, Cham») bei Personen: Liste, Betriebsfeld im
  Formular, Suche (Personen und Rechnungen) — gleichnamige Betriebe
  (`betriebMitOrt`, `betriebAnzeigeMapProvider`). 1918 Tests grün.
- Browser-Sichtprüfung entfiel (nicht angemeldet); Klicktest am Handy.

---

## 23.09.2026 — v0.133.2 Zeitauswahl überall 24 h

- Die Saison-Abmachung (Termin für Eröffnungs-/Endreinigung) rief den
  Flutter-Zeitdialog direkt auf und zeigte je nach Gerät AM/PM. Jetzt über
  `zeigeZeitauswahl` wie alle anderen Zeitfelder (Wunsch Daniel).
- Neuer Wächter `test/zeitauswahl_waechter_test.dart`: `showTimePicker(`
  ausserhalb von `zeit_auswahl.dart` bricht den Test ab — gilt auch für
  künftige Zeitfelder. 1910 Tests grün.

---

## 23.09.2026 — v0.133.1 Pikett mit KW

- Pikett-Dienste heissen in der Einsätze-Liste «Pikettdienst KW 38» statt nur
  «Pikettdienst» (Wunsch Daniel).
- Die Suche findet «pikett» (auch «bereitschaft») und öffnet die Einsätze,
  gefiltert auf Pikett. Seit v0.131.0 hatte es keinen eigenen Eintrag mehr.
- `kalenderwoche()` liegt jetzt einmal in `lib/core/util/kalenderwoche.dart`;
  Tourenplan-Wochenleiste, Einsätze und Pikett-Detail nutzen dieselbe
  ISO-Rechnung. 1908 Tests grün.

---

## 22.09.2026 — v0.133.0 Suche

Teil 2 der Bedienungs-Vereinfachung (Spec
`docs/superpowers/specs/2026-09-22-suche-design.md`, Plan
`docs/superpowers/plans/2026-09-22-suche.md`).

- **Suchseite `/suche`**, erreichbar über die Lupe auf Heute und das Feld
  oben auf Mehr. Findet Betriebe (Name, Ort, Nummer, mit Status-Punkt),
  Personen (Name, Telefon in jeder Schreibweise, Betrieb; Anruf direkt aus
  dem Treffer), Rechnungen (Nummer oder Teil davon, Betrieb; ohne
  Heineken-Monatsrechnungen) und Bereiche der App (auch über Stichwörter
  wie «mwst», «preise», «lohnausweis»).
- Umlaute, Akzente und mehrere Wörter egal («pub cham»); höchstens 5 je
  Gruppe, «alle N anzeigen» öffnet die Liste mit vorbefülltem Suchfeld.
  Die drei Listen suchen seither mit derselben Regel (`trifftSuche`).
- «Zuletzt geöffnet» (lokal im Browser, letzte 5).
- Regeln als reines Dart (`lib/core/util/suche.dart`), Normalisierung
  vorberechnet: rund 1,5 ms je Tastendruck. 1905 Tests grün.

---

## 22.09.2026 — v0.132.0 Rechnungs-Bereich, Event-Karte

Teil B des Navigations-Plans.

- **Rechnungen mit vier Reitern**: Kunden · Heineken · Pro Betrieb · Jährlich
  (Umschalter `BereichReiter`, wechselt die Route statt Screens
  einzubetten). Zurück-Pfeil in allen vier, auch nach einem Reiterwechsel.
- **Bergkundenpauschalen** stehen oben im Heineken-Reiter — dort werden sie
  verrechnet. Die Übergangsgruppe in der Buchhaltung ist weg; dort stehen nur
  noch Kontenplan, Journal, Bilanz und Erfolgsrechnung.
- **Event-Karte auf Heute**: ab 7 Tagen vor Beginn bis und mit dem letzten
  Tag (`eventImFenster`, in UTC-Kalendertagen). 1870 Tests grün.

---

## 22.09.2026 — v0.131.0 Navigation «Mehr»

Teil 1 der Bedienungs-Vereinfachung (Spec
`docs/superpowers/specs/2026-09-22-navigation-mehr-design.md`, Plan
`docs/superpowers/plans/2026-09-22-navigation-mehr.md`), umgesetzt mit
Subagenten und je einem Review.

- **Leiste mit fünftem Ziel «Mehr»**: Heute · Einsätze · Betriebe · Tour · Mehr.
  Jede Seite ausserhalb der ersten vier lässt «Mehr» leuchten.
- **Heute ist nur noch der Tag**: Aufgaben-Karte, Arbeitstag, Heute-Liste,
  Diktieren. Kacheln, «Weitere»-Liste und Abmelde-Symbol sind weg.
- **Mehr-Seite** in drei Gruppen (Unterwegs · Büro · Einrichtung) mit Zählern
  aus derselben Quelle wie die Glocke.
- **Bereiche als Daten** (`lib/core/config/bereiche.dart`), neue Seiten
  Bank und Zahlungen, Abschlüsse und Steuern, Auswertungen, Stammdaten.
  Buchhaltung verkleinert, Einstellungen nur noch Technik + Abmelden.
- **Betriebe | Personen**: Kontakte als Reiter der Betriebe.
- **Fix Leiste**: hört auf den Router-Delegate. Vorher stand sie auf dem
  Anmeldebildschirm und fehlte nach dem Anmelden — go_router meldet
  Weiterleitungen dem `routeInformationProvider` ohne `notifyListeners()`
  (seit v0.107.0 so).
- **Wächter**: jeder Listen-Screen erreichbar (erkennt Weiterleitungs-Aliase),
  Leuchten der Leiste, CanvasKit-Verbote um `TabBar`/`NavigationBar`/
  `ElevatedButton` erweitert. 1859 Tests grün.

---

## 17.–22.09.2026 — v0.110.0 bis v0.130.0

*Nachgetragen am 22.09.2026 aus `ToDo.md` und der Commit-Historie. Diese
Lücke war der eigentliche Rückstand von `Projekt.md`, nicht «seit Juni».*

**Rechnungen und Forderungen pro Betrieb**
- **v0.110.0** (17.09.): Rechnungsadresse und Mail per Knopf aus den
  Betriebsdaten holen.
- **v0.126.0–v0.128.0** (21.09.): Offene Rechnungen pro Betrieb, je Jahr, mit
  Zustellweg · alle Rechnungen pro Betrieb und Kontoauszug je Jahr · Zustellweg
  im Kontoauszug-PDF · QR-Einzahlungsschein im Kontoauszug.
- **v0.129.0** (21.09.): Reinigungsprotokolle (die abfotografierten
  Papierprotokolle) als PDF, einzeln und als Jahresbündel.
- **v0.130.0** (22.09.): Wächter vor der Heineken-Freigabe. Die App rechnet die
  acht Positionen aus den Quelldaten neu und legt Abweichungen vor, bevor
  Debitor und Ertrag gebucht werden. Anlass: August-Rechnung, Position
  Störungen 250.00 zu hoch. Die August-Rechnung ist danach freigegeben
  (13'966.09 brutto).

**Abschluss 2026 und MWST**
- **v0.116.0** (19.09., Migration 194): Abschluss-Schritt «Jahrgang abschreiben»
  mit MWST-Rückholung, als eine DB-Transaktion mit Rücknahme. Politik: ein
  Jahrgang wird im Jahr seiner Verjährung abgeschrieben (2020+2021 im
  Abschluss 2026). Migration 195 trug `versendet_am` für 515 Excel-Rechnungen
  nach.
- **v0.118.0** (20.09., Migration 196): Ziff. 235 zählt auch
  Einzelabschreibungen.
- **v0.119.0** (20.09.): Abschreibung datiert auf den Entscheidtag, nicht aufs
  Rechnungsdatum.

**Saison und Tourenplan**
- **v0.117.0** (20.09.): Warnung für Saisonbetriebe, die still aus dem
  Tourenplan fallen (25 Fälle).
- **v0.120.0** (20.09.): Servicezeiten-Durchsicht zeigt nur noch eigene
  Reinigungskunden; alle 229 sind geprüft.
- **v0.121.0** (20.09.): «Saisondaten nachtragen» als ein Schritt für beide
  Saison-Warnungen, mit Vorschlag «ein Jahr weiter».
- **v0.122.0** (20.09., Migration 197): Schalter «Keine Herbstpause».
- **v0.123.0** (20.09.): Service-Termin von Hand setzen, mit Google Kalender.
- **v0.124.0** (20.09., Migration 198): Aufgaben mit Datum gehen in den Google
  Kalender.
- **v0.125.0** (20.09., Migration 199): Saisondaten und Abmachung direkt bei
  der Reinigung erfassen.

**Bedienung und Robustheit**
- **v0.111.0** (17.09., Migration 193): Kulanz als Vorwahl am Betrieb statt
  Freitext-Hinweis; Migration 192b nachgereicht.
- **v0.112.0** (18.09.): Hauptmenü nach den gemessenen Nutzungszahlen
  aufgeräumt (A6).
- **v0.113.0** (19.09.): Wochenwechsel und Tageswahl in einer Zeile; die
  Kalenderwoche war falsch berechnet (B5).
- **v0.114.0** (19.09.): Alle unumkehrbaren Bestätigungen über
  `TapKnopf(gefahr: true)`, 26 Stellen, mit Wächter-Test (B7).
- **v0.115.0** (19.09.): Alle 163 rohen Ausnahmen aus Snackbars entfernt.

**Daten**
- Betriebstrennung Rössli Cham → «4eri Bar» (20.09.).
- Alpina: Ort von Churwalden auf Parpan berichtigt (20.09.).

Stand 22.09.2026: 1842 Tests grün (17.09.: 1657), Migrationen bis 199
eingespielt, Edge Functions `send-rechnung-mail` v22 und `parse-einsatz` v9.

---

## Laufende Chronik 07.07.–17.09.2026

*Bis 22.09.2026 der Kopf von `Projekt.md`, wörtlich übernommen.*

**Version**: 0.109.2 · Edge Function `send-rechnung-mail` v22 (**DIE APP IST AUF VIER WEGE ZUSAMMENGEZOGEN — UND DIE MELDUNGEN SAGEN ENDLICH DIE WAHRHEIT** [v0.100.1–v0.109.2, 13.–17.09.2026, Migrationen 191+192]: Aus der App-Analyse wurden die Stufen A und B abgearbeitet. **Ein Einsätze-Screen für alle Typen** (B2, v0.105.0): Sieben Quellen fliessen in eine Liste mit Typ-, Status-, Zeitraum- und Betriebsfilter, eine abgeleitete Lage ersetzt vier Status-Vokabulare, sechs alte Listen-Screens sind ersatzlos gelöscht. **Ein Aufgaben-Begriff** (B6, v0.106.0): Glocke, Startkarte, Kachel und Sheet lesen dieselbe `aufgabenListeProvider`-Liste, mit einer Fälligkeitsregel und einer Aktionsleiste. **Untere Navigationsleiste** (B1, v0.107.0): vier Ziele, CanvasKit-sicher aus GestureDetector gebaut, nie auf einem Formular; sieben doppelte Kacheln fielen weg, Material rückte als vierte Kachel nach. **Büro-Startseite zeigt, was offen ist** (B3, v0.108.0): 13 Ziele in zwei Gruppen, und die Trennung **Frist oder Vorrat** hält Vorräte aus der Glocke. **Monatsabschluss als geführte Checkliste** (B4, v0.109.0): zehn Regeln in vier Gruppen (Einsätze, Heineken, Bank, Lohn), Ampel mit Ist/Soll und Sprungziel, Detektor auf der Büro-Startseite, bewusst **ohne** Monats-Status in der DB. Dazu A4 (Diktat erkennt Reinigungen), A5/A8 (Plan- und Ist-Arbeitsbeginn getrennt, Erledigt-Knopf) und A9 (eine Suchregel für alle Betriebs-Auswahlfelder). **Die Feldfehler des Zeitraums waren alle Meldungs-Fehler:** Der Reinigungsabschluss schaltete den serverseitigen Versandvermerk gar nicht ein (v0.100.1); im Funkloch am Berghaus scheiterte der Nachlauf an 200 UUIDs in einem GET-Parameter und schrieb die rohe PostgREST-URL auf den Bildschirm (v0.106.1, Blockgrösse 50 + `kurzeFehlermeldung`); Kulanz-Reinigungen zählten vollen Preis (v0.106.2, Migration 192). Und am 17.09. meldete die App «MAIL-VERSAND FEHLGESCHLAGEN», während die Mail beim Kunden lag — seit `EdgeRuntime.waitUntil` überlebt der Versandvermerk den Verbindungsabbruch, die Antwort ans Handy nicht. Die App **fragt jetzt im catch den Server** und sagt «laut Server versendet — nicht erneut senden», statt zum Doppelversand aufzufordern (v0.109.1). Ein Tag später fiel auf, dass zwei der neuen Meldungen auf Wege zeigten, die es nicht gibt — Nachbuchen sitzt in der Rechnungsliste, die HeiGenie-Mail lässt sich überhaupt nicht nachholen (v0.109.2). **Neue Wächter:** `rohe_ausnahme_ratsche_test.dart` (rohe Ausnahmen in Snackbars: im Rechnungs-/Mailpfad verboten, sonst Ratsche ab 163), `in_filter_block_test.dart`, Statusvergleich-Ratsche. 1657 Tests grün.)

> Zuvor (v0.100.0, 13.09.2026): **DIE STARTSEITE IST EINE TAGESANSICHT** [v0.100.0, 13.09.2026]: Die Startseite zeigt die offenen Stopps des heutigen Tagesplans statt eines Menüs mit Jahreszahlen — Betrieb, Ort, Anlagenzahl, Servicezeit, je Zeile ein Start-Pfeil, der den Einsatz direkt öffnet. Erledigte verschwinden, die Kopfzeile zählt «3 von 10». Ungekürzt, weil morgens der ganze offene Tag dastehen soll. Datenquelle ist der ohnehin jeden Abend gespeicherte Tagesplan — die Annahme aus der Übergabe vom 11.09., es gebe womöglich gar keinen, war falsch: In `tagesplaene` liegt für **jeden** Arbeitstag einer mit 8–13 Einträgen, und `/touren` wurde entgegen der ersten Messung sehr wohl geöffnet. **Kachelzähler zeigen offene Arbeit** statt Jahrestotale (Reinigungen «diese Woche», Störungen «offen», Montagen «geplant», Eigenaufträge «offen»; Betriebe, Kontakte, Spesen, Eröffnungen gar keine Zahl). **Der Einsatz startet, wo man steht** — Heute-Liste, Tourenplan-Block, Betriebsseite, für alle drei Einsatzarten, bei gebündelten Betrieben mit allen Anlagen vorbelegt. Umgesetzt subagenten-getrieben nach Spec und Plan; die Reviews kippten drei Dinge, die keine Testsuite gefunden hätte: einen Test, der seinen eigenen Nachbau prüfte statt des Widgets, einen inneren Scrollbereich, der die Entscheidung «alle offenen Stopps» unterlaufen hätte, und einen Wächter-Test, der auf sein eigenes Kommentar-Zitat angeschlagen wäre. 1414 Tests grün.)

> Zuvor (v0.99.5–v0.99.18): **DOKUMENTEN-ABLAGE + LOHN + FORMULAR-SCHUTZ + NUTZUNGSMESSUNG + ABSCHLUSSKETTE REPARIERT** [v0.99.5–v0.99.18, 14 Deploys]: Der Ordner `00_Rechnungen` ist **vollständig erschlossen** — aus rund 700 Handy-Fotos und Portal-PDFs wurden **252 benannte Dokumente im Dokumente-Modul** (Versicherungen 141, Steuern 84, Verträge 21, Behörden 4, Bank 2). Die Fotostapel liessen sich maschinell zerlegen, weil Daniel Trennblätter einlegt; wo keine liegen (SUVA), trennt die Kombination aus Logo und Adressblock, und die Grenzen stehen zur Sicherheit explizit im Katalog. Neue Kategorien **AHV**, **Gründung**, **Franchise**, **Fahrzeug** plus die Typen Verfügung, Statuten, Urkunde, Protokoll; der Upload-Dialog zeigt jetzt auch ausserhalb der Steuern ein Dropdown. Die **Ablage ist seit v0.99.9/v0.99.10 nach Absendern gegliedert**: Pensionskasse, AHV/SVA, Unfall/SUVA, Krankentaggeld und Haftpflicht sind eigene Bereiche statt Kategorien unter «Versicherungen» — je eigener Ansprechpartner, eigene Belegarten, eigene Fristen; 141 Dokumente umgezogen, Migrationen 188+189, Wächter-Tests über die Bereichs-Konfiguration. **Lohn**: Der BVG-Beitrag stand seit Januar auf 562.95 statt 744.65 (belegt durch den Pensionskassenausweis) — 6 Läufe und 54 Buchungen rückwirkend korrigiert, Nettolöhne unangetastet, Lohnsumme 51'151.45 → 52'316.05. **17. Abschlussregel** «Sozialversicherung nicht gegen Kreditor» als Wächter über die auf 2270/2271/2272 umgestellten Kreditor-Regeln. **Franchisevertrag Heineken ausgewertet** (`docs/franchisevertrag-heineken-2019.md`): Garantie über 37'500 Zusatzaufträge im Jahr wird deutlich übererfüllt, aber **unsere Unterschrift fehlt auf dem Vertrag**. **Der Befund des Tages**: Fünf Stellen führen fünf verschiedene Lohnsummen — SVA 30'734, SUVA 121'000, BVG 100'000, Krankentaggeld 80'000, Haftpflicht 100'000 — tatsächlich sind es 59'000–70'700. Daraus folgen bei der SVA Mahnungen, Bussen und Verzugszinsen, bei der SUVA 3'138.65 unnötige Vorauszahlungen in vier Jahren.)

> Zuletzt (09.–11.09.2026): **FORMULAR-SCHUTZ, NUTZUNGSMESSUNG UND DIE REPARIERTE ABSCHLUSSKETTE** (v0.99.12–v0.99.18, 7 Deploys, Migration 190, Edge Function v22).
>
> **App-Analyse** (`docs/app-analyse-2026-09.md`, auch als Seite publiziert): 101 Routen, 24 Feature-Bereiche, sechs Einsatz-Typen mit vier Status-Vokabularen. Sechs Befunde, Vorschläge in drei Stufen. Nach dem Schreiben haben 12 Prüfer die messbaren Behauptungen im Code zu widerlegen versucht — 3 Korrekturen, 8 Zusatzbefunde.
>
> **A7 umgesetzt (v0.99.12/13):** Alle **19 Formulare** fragen jetzt nach, bevor ungespeicherte Änderungen verloren gehen — vorher tat das keines, und ein Wischer am Rand des Pixel 9 kostete eine ganze Reinigung mit Fotos und Positionen. 101 `markiereGeaendert()`-Stellen, 20 `geaendertZuruecksetzen()`, Wächter-Test. Ein 360-px-Test zeigte 42 px Überlauf im Dialog — Knöpfe stehen jetzt untereinander, `TapKnopf` lässt seinen Text umbrechen.
>
> **Nutzungsmessung (v0.99.14/15, Migration 190):** Ein NavigatorObserver zählt das Routen-Muster (`/betriebe/:id`, nie die konkrete ID), getrennt nach Handy und PC. Auswertung unter **Einstellungen → Nutzung der App**. Erste Zahlen: 09.–11.09. zusammen rund 170 Aufrufe, Handy/PC etwa 2:1 — und die **Tourenplanung wurde an keinem Arbeitstag geöffnet**.
>
> **Der eigentliche Fund der Woche — die Abschlusskette war doppelt blind:**
> 1. **NULL-Falle (v0.99.18):** Beide Frühwarnungen filterten mit `.neq('quelle','excel_import')`. `quelle` ist bei JEDER in der App erfassten Reinigung NULL (211 von 211 gemessen), und `NULL <> 'x'` ergibt in SQL nicht «wahr». Beide Suchen lieferten seit dem 04.09. **ausnahmslos leere Listen** — der automatische Nachlauf fand nie etwas, und die Warnung, die genau das melden sollte, schwieg aus demselben Grund.
> 2. **Nachbuchen unerreichbar (v0.99.17):** Der Knopf steckte im Dialog der Warnung «ohne Rechnung». Fehlte nur die Buchung, erschien diese Warnung gar nicht. Neu: eigene Warnkarte + Aufgaben-Detektor.
> 3. **Fehler verschluckt (v0.99.16):** Der Nachlauf meldete Fehlschläge nur ins Debug-Protokoll.
> 4. **Versandvermerk (Function v22, 11.09.):** Steckt Daniel das Handy direkt nach dem Abschliessen weg, friert der Tab ein und der Request bricht ab — der Gmail-Aufruf ist durch, der Vermerk danach nicht. Rechnung beim Kunden, Status «offen», **Gefahr Doppelversand**. Belegt: Hugos 27.08., Signina 07.09., Stadtcafé + Sonne Seehotel 11.09. Behoben mit `EdgeRuntime.waitUntil`.
>
> **Daten bereinigt:** 3 Versandvermerke nach Gmail-Abgleich korrigiert, 2 Ertragsbuchungen nachgeholt (252.95). Stand 11.09. abends: **keine fehlende Buchung, kein fehlender Versandvermerk** an den letzten drei Arbeitstagen. 1382 Tests grün, Analyse unverändert (56).
>
> Zuletzt (08.09.2026 abends): **DOKUMENTEN-ABLAGE + LOHN-KORREKTUR + FRANCHISEVERTRAG** (v0.99.5–v0.99.8). **Post-Eingang** ausgewertet: die vier ESTV-Korrekturabrechnungen 2025 sind da (Total 1'507.23, deckt sich mit der Einreichung vom 01.09.), dazu SVA Q3, die AXA-Beitragsrechnung und die SUVA-Prämienverfügung 2027. **Ablage**: `00_Rechnungen` komplett erschlossen, 252 Dokumente in der App. **Lohn**: BVG rückwirkend auf 744.65 korrigiert. **Kreditor-Regeln** für SVA/SUVA/PK auf die Verbindlichkeitskonten umgestellt, abgesichert durch die 17. Abschlussregel. **Rückläufer-Meldung der Heineken-Session geprüft**: von drei angeblich unzustellbaren Rechnungen waren zwei binnen Minuten neu versendet worden — nur Dischma (74.60) kam nie an, Daniel schreibt sie ab. **Offen für Daniel**: AXA morgen (8'935.80 statt 4'467.90 zahlen), GKB Zins-/Kapitalausweis 2025 für die Steuererklärung, und die eine Lohnsumme an alle fünf Stellen melden. 1343 Tests grün, Analyse unverändert.
> Detaillierter aktueller Stand & offene Punkte: **`ToDo.md`** (Projekt-Root) + Memory.
> Zuletzt (08.09.2026): **BETRIEBSDATEN-WERKZEUGE + BUCHHALTUNGS-KORREKTUREN** (v0.97.1–v0.99.4, 6 Deploys, Migrationen 186+187). **Servicezeiten-Durchsicht** neu unter Betriebe → Uhr-Symbol: ein Betrieb pro Karte mit Öffnungszeiten, Vorschlag aus der Besuchshistorie, «kein Service»-Schalter je Block und aufklappbarer Besuchsliste [Spanne + häufigste Stunde]; wischen nach rechts übernimmt, nach links kommt der Betrieb in der nächsten Runde wieder. **Saison-Historie** hält abgelaufene Saisonfenster fest, damit sich die kommende abschätzen lässt. **Zwei Bugs gefunden und behoben**: Der Kalender-Dialog schlug beim Speichern eines Betriebs Termine vor, die Monate zurücklagen [`betriebReinigungen()` hatte keinen Bezug zu heute — die bestehenden Tests wären davon selbst rot geworden, `heute` ist jetzt injizierbar]; die MWST-Saldierungen vom 01.09. trugen ein falsches Geschäftsjahr [Befund kam aus der Heineken-Session, deren v2-Nachzug daran abbrach — bei uns war nur die Buchungsliste falsch sortiert, Bilanz/ER/MWST-Abrechnung waren unberührt]. **Stammdaten nach Feldansagen**: Pizzeria Fortuna Sedrun → **Pizzeria Badus** [Wirtewechsel, wieder aktiv]; Weissfluhjoch Davos, Anlage «Küche» → **demontiert** [fällt aus Planung und Abrechnung]; Bellevue Flims Dorf → `ist_mein_kunde = false`. **Gelernt**: `ist_mein_kunde` heisst «konventionelle Anlage, die Daniel reinigt» — Heigenie/David gehören Heineken, ebenso zählen ein vom Monteur mitgereinigter Buffetanstich und ein anderes FN-Gebiet als false. Ich hatte daraus zwei Betriebe falsch umgestellt und musste sie zurückdrehen; das Flag lässt sich **nicht** aus den Daten ableiten. **1330 Tests grün**, Analyse unverändert (56 vorbestehende Infos).
> Zuletzt (02.09.2026): **ENTFLECHTUNG VORHABEN ① KOMPLETT — Kontakte-Umzug dani.proyer@ → sbs.projer@** (reine Doku-/Koordinations-Session, kein Deploy, App bleibt v0.95.0): Alle drei Entscheide Daniels auf Messbasis (Heineken-Session mass rein lesend: 5 Geschäftsgruppen = 408 Personen; Gruppenlose = 316, zu ~98 % geschäftlich — «ohne Gruppe» war KEIN Privat-Signal; «SBS Event»/«SIM»/«Importiert» leer). Umzug per Vollexport-CSV → Import → Privat-Kopien-Löschung über 7 Labels; **Endstand verifiziert: sbs.projer@ = 723 Geschäftskontakte (jeder einzelne erklärt, kein Privater), dani.proyer@ = 46 Private, alle unter Label «Privat»**. Ausnahmen sauber behandelt (Tino Hassler bleibt privat, Steven mit getrennten Nummern in beiden Konten, Beat-Jörg-Merge geprüft korrekt). **Lehre: Googles «Alle auswählen» markiert nur die geladene Seite** — erster Lösch-Durchgang erwischte 405 von 766, nur die Nachmessung fand es (Ablauf + Zahlen: `Datenbank/kontakte-umzug-anleitung.md`). Nächste Schritte: Vorhaben ② (GCP «Heineken Plattform», Client-IDs ändern sich!) und ③ (Kalender); Daniels Kontakte-Durchsicht (33 Namensdoppel, 75 geteilte Nummern) separat. **Nächste Session (Ansage Daniel): Jahresschluss + Steuererklärung der GmbH.**
> Zuletzt (08.08.2026, Tag+Abend): **Pagination-Fix, Lohnblock und Buchhaltungs-Analysen** (v0.73.2–v0.74.0). **🔴 v0.74.0 kritisch**: `BuchungRepository.getAll()` lädt 16'449 Buchungen seitenweise und sortierte nur nach `datum` — bei 1'874 mehrfach belegten Tagen ist die Reihenfolge zwischen zwei Requests undefiniert, Zeilen erschienen doppelt oder fielen durch. **Die Bilanz zeigte damit bei jedem Neuladen andere Werte** (Bank 15'057.97 statt 15'816.07). `.order('id')` in 9 Abfragen + `test/pagination_stabil_test.dart` als Wächter (fand prompt 2 weitere Stellen). ⚠️ Alle vorher aus der App abgelesenen Bilanz-/ER-Zahlen waren potenziell zu tief — die DB-Werte waren immer korrekt. **Lohnblock komplett**: Nachhol-Lohnläufe April–Juli gebucht (Netto = echte Auszahlungen, NBU 0 = Firmenübernahme, Konto 2002 = 0.00 exakt), 2026er-Excel-Blöcke Jan+März auf das App-Modell umgestellt, **Salden-Umgliederung 2270–2273** (die Alt-Ära buchte um eine Position verschoben), UVG-Aufwand-Nachholung belegt via SUVA/AXA, FAK-Satz auf 1.50 % korrigiert, **Lohnausweis 2025 erstellt** (amtliches Formular-11-Layout, dreisprachig, Ziff. 1–15) und in der App verfügbar. **PDF-Sonderzeichen endgültig gelöst** (v0.73.7): statt zum vierten Mal Zeichen zu ersetzen, Roboto-Unicode eingebettet — neue Factory `pdfDokument()` in allen 17 Services, Wächter-Test gegen nacktes `pw.Document()`. camt-Nacharbeiten v0.73.2/3/4 (Schaltereinzahlungs-Platzhalter, Vermerk-Parser für alle Rechnungsnummern inkl. umbrochener, Archiv idempotent). **Analysen**: Kassenbestand geklärt (DB 11'084.28 korrekt, Excel-Bilanz 4'629 zu tief wegen Hauptbuch-Lücke), Lohnabgleich 2019–2026, **MWST-Saldierung fehlt seit Q1/2025** (darum 2200 = 27'728.42 und 2202 = −10'350.80 — bezahlt, aber nie verrechnet; wahrer offener Stand 10'617.27), **SVA-Originalbelege vollständig ausgewertet** (67 Dokumente): ab 2020 wurde der Nettolohn statt des aufgerechneten Bruttolohns deklariert (2019 hatte Daniel es noch per Nachtrag korrigiert) → ~55'900 nicht deklarierte Lohnsumme 2020–2024, **Entscheid Daniel: belassen**, ab 2026 korrekt. Nebenbefund: Akonto-Grundlage seit 04/2021 auf 30'734 eingefroren → jährliche Nachzahlungen, Verzugszinsen, 2023 sogar 300.— Bussen. Details `ToDo.md`, `docs/lohnabgleich-2019-2026.md`, `docs/kassenabgleich-2026-08-08.md`.
> Zuletzt (07./08.08.2026 abends/nachts): **NACHHOL-IMPORT KOMPLETT — Fahrplan Schritt 4 abgeschlossen** (v0.72.11–v0.73.1): Daniel arbeitete den frischen GKB-Export (12.03.–06.08., 364 Einträge) durch den Bestätigungs-Flow; ~373 camt-Buchungen, **Bank 1020 = E-Banking auf den Rappen** (Skript-Abgleich jeder Transaktion; 14'952.97 + 2 offene Schaltereinzahlungen 212.95 = Schlusssaldo 15'165.92), alle 28 Belastungen gebucht (inkl. Franchise 6301 mit VSt). In der Feedback-Schleife entstanden: Auto-Match-Volldetails, Betriebsnummer-Routing NUR über `heineken_nr` (185 Hausnummer-Schein-Kollisionen raus; DKB/WA schreiben ab Mai Rechnungsnummern in den Vermerk), **hartes Sammelzahler-Prinzip** (nie über Name/Alias/Betrag routen — das Betrags-Routing v0.72.13 warf Zahlungen in fremde Betriebe [Waldhuus] und flog gleichentags wieder raus), Paar-Badges (nummerierte Farbpunkte = exakt die gebuchte Paarung via `paareMitBetrag`), «Später klären»-Parkliste + Prüflisten-«Zuordnen», **«Zahlung rückgängig (Bankabgleich)»** im Rechnungs-Detail (Praxistest: 5 Allegra-Fehlgriffe sauber zurück), Rollback-Snapshot `snapshot_camt_abgleich` + Wartungs-Skript. **3 Buchungsfehler entdeckt+behoben**: Doppel-Tausch Bareinzahlung (2× Automaten-Einzahlung 8'050 verkehrt, v0.72.17), Sammelzahlung mit erlassener Differenz überbuchte Bank um 12.20 (v0.72.18), Heineken zahlt teils 1 Rp. unter Brutto (Verlust-Zeile). Heineken **Feb+März-Zahlungseingänge (12'899.79) nachgebucht** (Backfill-Rechnungen standen auf bezahlt ohne Buchung). 8 neue Zahler-Aliase (Schlegmul→Central, A la Nina→Jschalp, Mahalo→Montana Bar, Bergbahnen Disentis→Milez, RhB→Stiva Raetica, GG Althof→Brunnen Valendas, SV→Spiga, Ott-Ruf→Chleina Pub); Allegra Vinum = DREI Betriebe (Franziskaner/Fondue Beizli/**La Meridiana**, letztere beide 94.05!). Chleina-Pub-Doppelzahlung 74.60 als a.o. Ertrag, **Ausgleich per Kulanz** → neues Feature **Service-Hinweis** (Migration, oranges Band im Abschluss-Dialog). Neu ausserdem: **Kontoauszug-PDF pro Betrieb** (Summen-Kacheln, laufender Saldo, Briefkopf; Sonderzeichen-Sanitizer v0.73.1 — eingebaute PDF-Schrift kennt ’ – — nicht) und **Forderungen-Screen-Umbau** (Offene-Karte zuoberst, Debitoren darunter, Trennlinie «ALLE RECHNUNGEN», 3 Filter nebeneinander inkl. «Alle Jahre»). Offen: 2 Schaltereinzahlungen zuordnen, Prüfpunkt WA-Mehrzahlung 126.50, dann Fahrplan 5–7 (**MWST Q1+Q2 Frist Ende August**). Details `ToDo.md`.
> Zuletzt (07.08.2026): **Buchhaltungs-Fahrplan Schritte 1–3 + camt-Gesamtprüfung + Heineken-Originale** (v0.72.4–v0.72.10): **Heineken-Monatsrechnungen** — die 83 historischen PDFs (05/2019–03/2026) im Storage waren 3-Seiten-Skelette aus dem Daten-Backfill vom 14.07.; die versendeten **Original-PDFs mit den Heineken-Formularen** (aus `00_Buchhaltung/Monatsrechnungen Heineken 2019-2026/`, ab 08/2023 Kombi-Datei, davor aus Einzel-PDFs zusammengeführt) wurden über eine temporäre token-geschützte Edge Function hochgeladen (83/83 Brutto-verifiziert, Hashes geprüft; Function danach stillgelegt) + **Sperre «PDF neu generieren»** für Monate vor 04/2026 (v0.72.4). **Fahrplan Schritt 1 (B2)**: Heineken-Buchung ohne 5-Rappen-Rundung (`heinekenBuchungsBetraege`), 3 Buchungen korrigiert, Invariante brutto=netto+mwst DB-weit sauber (v0.72.5). **Schritt 2 (B6+B1)**: Storno-Mechanik repariert (Gegenbuchung datiert aufs Original, ohne mwst_konto, Trennbuchungen mitstorniert; Ausschluss-Filter in getAllSaldi/MWST-Provider/5 Guards; Migration 166 MWST-View; v0.72.6) — dann die 4 Trennbuchungs-Codepfade gestrichen und **977 MwSt-/VSt-Trennbuchungen per Snapshot-Migration bereinigt** (Ertrag +10'219.98, 2200 −10'219.98; `snapshot_mwst_trennbuchungen`; v0.72.7). **Schritt 3 (Code)**: camt-Stichtag exklusiv (11.03. war Excel-gebucht) + Ausgabe-Booker richtungsbewusst (v0.72.8). **MWST geklärt**: ePortal-Check + Portal-PDFs Q2–Q4/2025 → Q4/2025 ist eingereicht, Netto-statt-Brutto in allen 4 Quartalen belegt, **Berichtigung 2025 = 1'508.62 rappengenau** (Vorlage `docs/mwst-q4-2025-nachreichung.md`); Q1+Q2/2026 Frist Ende August, Erinnerung Di 11.08. 19:00. **camt-Import-Gesamtprüfung** (`docs/camt-import-pruefung-2026-08-07.md`): Geschäftsfall-Vorlagen-Crash im Ausgabe-Booker gefixt, offene Prüflisten-Fälle re-importierbar (Heineken-Gutschriften 7'104.98/5'794.81 werden buchbar), Sammelzahler (Davos Klosters/Weisse Arena/**Goodfast**) nie auto, Archiv erst nach Verarbeitung, Dateien-Duplikate bereinigt (v0.72.9/10). **Zahlernamen-Lernen**: 1'606 Historik-Gutschriften gegen bezahlte Rechnungen gematcht → 57 Aliase automatisch; Internet-Recherche (3 Agenten, Zefix/Impressen) klärte die 53 offenen Fälle → +55 Aliase, 2 Korrekturen (Alpenblick-Arosa, Lenzerhorn=Zwei-Betriebe-Zahler), AlpinTrend-Gruppe erklärt 5 Zahler; **Endstand 123 Betriebe / 135 Aliase** (`docs/camt-zahlernamen-lernen-2026-08-07.md`). Stammdaten: Goodfast-Vierergruppe (Grischa/Golden Dragon/Jodys/Bräma) auf Rechnung Mail mit Grischa-Adresse; Franchise-Vorlage neu 6301+VSt 1170. Offen: frischer GKB-camt-Export (Daniel) → Nachhol-Import, dann Fahrplan Schritte 4–7. Details `ToDo.md`.
> Zuletzt (01.–07.08.2026 früh): **Betriebsdaten aktuell halten + Einsatzplanung mit Sprache + Prüfberichte** (v0.65.0–v0.72.3): **v0.65.0 Ferien-Paket** (Migrationen 160/161): eigene `betrieb_ferien`-Vertikale, Google-+Website-Abgleich als Edge Functions mit täglichem pg_cron-Lauf und Prüfliste für Änderungsvorschläge, «War geschlossen»-Knopf (Ferien/Ruhetag/Leerfahrt), graues Vorjahres-Band im Tourenplan; Ferienfrage beim Abschluss in v0.72.1 wieder entfernt (Entscheid Daniel). **v0.66.0**: vergessene Pause wird erkannt. **v0.67.0–v0.70.x Einsatzplanung** (Migrationen 163/164): Störungen/Montagen echt planbar (Plan-/Arbeitszeitfelder, Dauer-Vorgaben, Sichtbarkeitsregel), geplante Einsätze im Google-Kalender mit Erinnerung, **Diktier-Knopf** auf der Startseite (Edge Function `parse-einsatz`, erkennt auch neue Betriebe), Eröffnungs-/Endreinigungen als bestätigte Termine. **v0.71.0** (Migration 165): Tresen-Übergabe und Mailversand getrennt (`uebergeben_am`/`versendet_am`). **v0.72.0**: Saison-Reinigungen am Schliessungstag planbar (Fall Löwen Grossdietwil) + bestätigte Termine im Tourenplan; Datenpflege (20 Winterfenster-Jahreszahlen, 12 fehlende Anlagen, Golden-Dragon-Anlage). **v0.72.2**: Arbeitstag-Auswertung lädt Besuche monatsweise; `kAppVersion`-Test gegen Auseinanderlaufen. Beleg-Scan liest Beträge aus der MwSt-Tabelle. **Datenprüfung 05.08.** (`docs/datenpruefung-2026-08-05.md`): MwSt-Doppelbuchung + camt-Stichtag-Off-by-One entdeckt, Geldseite still seit 11.03., Forderungen 173'123. **Buchhaltungs-Gesamtprüfung 06.08.** (`docs/buchhaltungspruefung-2026-08-06.md`, 4 Agenten): Fahrplan mit 7 Schritten + 12 Entscheidungsfragen; Nachtrag: Netto-statt-Brutto-Deklarationsfehler 2025. **v0.72.3**: Buckets `material-fotos`/`raster-pdfs` privat (Sicherheitsbefund Projekt Heineken). Details `ToDo.md`.
> Zuletzt (30.07.2026): **Live-Tagesplan + Arbeitstag am Startbildschirm + Datenreparatur Zeiten** (v0.55.1–v0.56.0, 702 Tests): **v0.56.0 Live-Modus** — der heutige Tagesplan zeigt Erledigtes mit den **gemessenen** Zeiten (grüne Blöcke «X min gemessen», gemessene Fahrten, gelbe frei-Fenster ab 3 min, rote Jetzt-Linie), Rest-Plan rechnet ab jetzt weiter, Minutentakt-Timer; Ist-Quellen: abgeschlossene Reinigungen (uhrzeit_start/ende) + **Wegpunkt-Stempel** für Störung/Montage (`berechneZeitplanMitIst` in `zeitplan.dart`). **Wegpunkte** (Migration 155, `wegpunkt_repository.dart`): Zeit+GPS+Kontext bei Reinigungs-Abschluss, Störung, Montage, Arbeitsbeginn, Feierabend — ereignisbasiert statt Dauer-GPS (Web-App drosselt Hintergrund); dazu **Fahrzeit-Lern-Guard**: liegt ein Störungs-/Montage-Stempel zwischen zwei Reinigungen, wird die Lücke nicht als Fahrzeit gelernt. **Arbeitstag-Karte auf dem Startbildschirm** (Migrationen 153/154): «Jetzt starten» mit km-Stand + GPS-Position (Daniel startet von Domat/Ems ODER Chur), «Feierabend» mit End-km + End-GPS → Tages-km ohne Privatfahrten; Startort-Fallback Via Rezia 8 in Geschäftseinstellungen. **Zeitauswahl überall 24h** ohne AM/PM (`zeit_auswahl.dart`, alle 5 Stellen). **Excel-Zeiten-Nachtrag** (Sheet Reinigung, Spalten Dauer/Zeit Beginn/Ende): 7'636 Reinigungen haben jetzt echte Uhrzeiten (vorher 895; 842 im Excel ohne Zeit, 145 ohne Match), fahrzeiten-Beobachtungen komplett neu aufgebaut — **3'045 Paare** aus 5'616 Übergängen (vorher 216, teils durch 1-Minüter vergiftet), Heuristik-Faktor 2.2→**2.5** (Median 2.53). Rollback-Skripte unter `Datenbank/wartung/`. Ausserdem neue globale Arbeitsregel: Modell/Aufwand je Aufgabe vorschlagen. Details `ToDo.md`.
> Zuletzt (29.07.2026): **Tourenplan als Tageszeitplan v0.55.0** (Spec+Plan `docs/superpowers/…2026-07-29-tourenplan-zeitachse…`, 9 Tasks subagent-getrieben mit je 2-stufigem Review; 691 Tests): Tagesplan-Tab rendert die geordnete Liste auf einer **Zeitleiste ab 06:00** — Besuchs-Blöcke in Dauer-Höhe, Fahrzeit-Verbinder, gelbe Wartezeit bei **Termin-Ankern**, Anfahrt/Heimweg ab Startort (neu in Geschäftseinstellungen). **Besuchs-Blöcke** bündeln alle heute fälligen Anlagen eines Betriebs (Chip «n von m», Sheet mit Anlagen-Auswahl/Dauer/Anker); Dauer = **Median je (Betrieb, Anlagenzahl)** (`besuch_dauer.dart`, Kurve 28/33/54/86 min), manuell übersteuerbar. **Fahrzeiten lernende Kaskade** (`fahrzeiten`-Tabelle, Migration 152): 216 beobachtete Paare aus historischen Reinigungs-Uhrzeiten (Backfill), Edge-Function `fahrzeit-route` (OSRM, gecached), Heuristik Luftlinie×**2.2** (kalibriert an 180 Paaren — inkl. Parkieren/Umladen); Nachführung beim Abschliessen einer Reinigung. Warnungen Ruhetag/Ferien + Servicezeit (Ankunft–Ende), **Plan-Übernahme von beliebigem Datum** (nicht Fällige grau «übernommen»), Arbeitsbeginn/-ende + km-Stand am Tagesplan erfasst (Auswertung = späteres Paket). Dazu Fällig-Liste: «Betrieb - Ort» eine Grösse, «zuletzt dd.MM.yyyy» unterm Badge. Review-Fixes u.a.: Backfill-Join (Ketten am selben Betrieb), Chip-Sichtbarkeit bei kurzen Blöcken, Alle-Filter-Kontamination der Bündelung. Vormittags ausserdem v0.54.17–20: Tourenfilter einzeilig (Saison zusammengefasst, «Alle»), Saisonprüfung repariert (35 unsichtbare Betriebe), Servicezeiten/Ruhetage-Fixes, Google-Fehler verständlich, Kontakte-Sync eine Karte je Betrieb «Ort - Betrieb (Person)» + Heineken-/Event-Schema, batchUpdate gegen Timeout. Details `ToDo.md`.
> Zuletzt (28.07.2026): **Spesen-Scanner produktiv + Buchhaltung aufgeräumt** — drei Blöcke. **(1) Spesen-Scanner v0.53.9–v0.54.9**: Kategorien nachgeschärft (Baumaterial → 4004), **Tabakwaren als Privatbezug 2260** (nicht gebucht bei Zahlungsweg privat), Korrektur-Schritt vor dem Buchen (Positionen bearbeiten/löschen/hinzufügen), Beleg drehen direkt nach der Aufnahme, Dubletten-Warnung, Bar-Rundung nur aufs Total (`beleg_korrektur.dart`, 20 Tests), Ausrichtung per KI (`bild_drehung`) statt EXIF, Doppeltipp-Riegel vor dem ersten `await` (Ursache einer Doppelbuchung), eine Konfidenz-Schwelle 0.85. **40 Belege produktiv erfasst** (09.06.–27.07., CHF 2'198.87, geprüft). Dazu «Speicher aufräumen» in den Einstellungen (RPC `verwaiste_belege`, Migration 151) — 215 Waisen gelöscht; Versionsanzeige auf der Startseite; Spesen-Zähler auf der Kachel. **(2) camt-Abgleich v0.54.10–v0.54.14**: Manuell-Fälle ohne Zahlung verschwinden, Mehrfachzuordnung derselben Forderung verhindert (frische DB-Prüfung), Minderzahlung rot und richtig benannt (Fall Sartons), Warnung wenn die Rechnung jünger ist als die Zahlung (Fall Marsöl), **Zahlungen paarweise zu Forderungen** (neueste zu neuester, `zahlung_paarung.dart`) — jede Rechnung trägt Datum und camt-Schlüssel *ihrer* Zahlung. 560 Tests grün. **(3) Buchhaltungs-Datenarbeit (keine App-Änderung)**: Excel-Delta-Import (220 Zahlungseingänge, Bank per 11.03. exakt 3'322.26 = E-Banking), **147 Rechnungen aus der Excel-Quelle** (Sheet Reinigung, Spalte Einzahlungsdatum) auf bezahlt gesetzt — ein erster Ansatz über Betragsbilanzen hätte ~100 falsch geschlossen; **Mischbetriebe entwirrt** (708 Reinigungen + 456 Rechnungen an den richtigen Betrieb, 28 erloschene Häuser als geschlossene Betriebe angelegt, 9 Duplikate/Dubletten beseitigt), 464 Anlagenbezüge und 363 QR-Referenzen nachgetragen, `heineken_nr` normalisiert. Schlussprüfung gegen das Excel: 6'509 Reinigungen bestätigt, **0 falsch**; Bank/Debitoren/Kasse unverändert. Alle Eingriffe einzeln rückgängig machbar (`Datenbank/wartung/rollback_*.sql`). **Abends nach Daniels Stichprobe zwei weitere Import-Fehler vom 19.06. gefunden und behoben:** (a) die **Hahn-Zuschläge** fehlten bei allen 7'786 importierten Reinigungen — für 2025 war der Betrag dadurch nur der Grundtarif (858 Stück, CHF 8'542 zu niedrig; Fall Lindemann's 21.11.2025: 74.60 statt 113.50), korrigiert über die Excel-Mengen inkl. MwSt-Wechsel 7.7→8.1 % per 01.01.2024 — **Netto stimmt jetzt bei allen 7'116 mit dem Excel**; (b) **222 „Zusätzliche Anlage"-Zeilen** waren als eigene Reinigung angelegt und hatten über den Preis-Trigger CHF 16'572 Scheinumsatz erhalten — 203 mit der Hauptreinigung zusammengeführt (Anlage wandert in `anlage_ids`), 18 auf 0.00 gesetzt (werden beim anderen Betrieb verrechnet). Rechnungen und Buchhaltung blieben unberührt. **v0.54.15/16:** camt-Abgleich nur noch mit Forderungen bis ein Jahr zurück (`abgleich_fenster.dart`), ältere im Zuordnungs-Dialog zuschaltbar. Details `ToDo.md`.
> Zuletzt (26.07.2026 abends): **Heineken-Fixes + Event-PDF** (v0.53.1–v0.53.3, alle von Daniel bestätigt): **v0.53.1** Monatsrechnungs-PDF öffnet immer mit frischer Signed-URL (gespeicherte lief nach 1 h ab → «PDF lässt sich nicht mehr öffnen»). **v0.53.2** Störungsrapport kreuzte das falsche System an — die B/D/K/H/O-Kreuze kamen aus den Störungs-BEREICHEN (1=Zapfhahn…5=Gas) statt aus `anlage_typ` (Centro Trun/Clubhotel/Stadtcafé); dazu Menüpunkt «PDF neu generieren» im Monatsrechnungs-Detail — Juni-Rechnung korrigiert regeneriert. **v0.53.3** Event-Abschluss-PDF: Vorschau im neuen Tab (Blob-URL statt Druckdialog, neuer Helfer `pdf_tab_oeffner`), Kategorien als unteilbare Blöcke (kein Umbruch mitten in Pikett-Einsätzen; >20 Zeilen bleiben teilbar). Details `ToDo.md`.
> Zuvor (22.–26.07.2026): **Google-Kontakte-Sync + Aufgaben-Erinnerungen** (v0.52.0–v0.53.0, beide Abnahmen bestanden): **Kontakte-Sync** — App-Kontakte + operative Betriebe landen via People API im Google-Adressbuch (Label «SBS App», `clientData.sbs_id`-Schutzregel, Reconcile-Edge-Function `google-contacts-sync`, entprellter Auto-Sync nach Kontakt-/Betrieb-Speichern, Contact Picker in beiden Formularen mit +41-Nummern-Normalisierung v0.52.1) → Anrufer-Erkennung auf dem Pixel; alter nativer flutter_contacts-Sync komplett entfernt (Migrationen 148/149). Dazu v0.52.2 (Standard-Checkbox im Abschluss-Dialog nur bei Abweichung) und v0.52.3 (Bald-fällig default sichtbar — Planungsdatum wirkt im Tourenplan, 32 unsichtbare Anlagen). **Aufgaben-Erinnerungen v0.53.0** — Dashboard-Karte + globale Glocke bis erledigt: 4 frische Detektoren (Heineken-Monatsrechnung zweistufig, MWST alle offenen der letzten 4 Quartale mit Fristen, Mahnlauf via ForderungService, Saisondaten) + eigene Aufgaben, Snooze 1/3/7, MWST-Marker im Screen (Migration 150, 22 Detektor-Tests, subagenten-getrieben mit 3 substanziellen Review-Fixes). Details `ToDo.md`.
> Zuvor (21.07.2026): **Muloin-Fix + DB-Sicherheit** (v0.51.2, Migrationen 145–147): Eröffnungs-Hinweis feuerte fälschlich, wenn die Endreinigung selbst in der Pause lag (Muloin: 30.06. in den Ferien 26.06.–27.07.) — Regel jetzt wörtlich: jede Pausen-Reinigung unterdrückt Hinweis + Auto-Termin, Uhr ab Wiedereröffnung (Muloin fällig 25.08.); TDD, 447 Tests grün, deployed. Danach Supabase-Sicherheitsmail abgearbeitet: **145** RLS auf den 11 `_bak_*`-Tabellen (waren via Anon-Key lesbar!), **146** alle 8 Views auf `security_invoker` (umgingen RLS; anon sah z. B. offene Rechnungen — verifiziert jetzt 0 Zeilen, eingeloggt unverändert), **147** alle Backup-Tabellen gelöscht (OK Daniel). Security-Advisor ohne ERROR. Zudem 100 Betriebe ohne Region gesichtet (2 aktive Events, 97 geschlossene Alt-Daten). Details `ToDo.md`.
> Zuvor (17.–20.07.2026): **Fälligkeit ab Saisonstart** (v0.51.0/v0.51.1): Tgantieni-Fall — 17 Saison-Kunden waren bis 78 Tage wieder offen, ohne im Tourenplan zu erscheinen (ewiges `eroeffnungFaellig` + Filter-Default + Auto-Termin nur am Eröffnungstag). Regel Daniel: **Uhr-Anker = Wiedereröffnung** (`faelligkeitsAnker`, TDD), Eröffnungs-Hinweis nur noch 7 Tage vor Start, **Warnleiste „Saisondaten fehlen"** im Tourenplan (zeigt aktuell 15 Winter-Betriebe ohne eingetragenen nächsten Winterstart), Filter-Default inkl. Eröffnung/Endreinigung, Saisonpause-Betriebe mitgemeldet. Furt Wangs nachgetragen (Anlage demontiert → Betrieb inaktiv). Details `ToDo.md`.
> Zuvor (15.–17.07.2026): **Zahlungsart pro Reinigung** (v0.50.0) — **Ursache der 38 fehlenden Rechnungen GELÖST** (Hinweis Daniel: Zahlungsart-Umstellungen; 34× Betrieb war noch `heineken`, 4× veralteter Formular-Cache): `reinigungen.zahlungsart` wird beim Abschluss fixiert (Migration 144) und ist via `resolveZahlungsart` allein massgebend für Buchung/Rechnung/Versand; Abschluss-Dialog mit frischem Betrieb, Standard-Checkbox, Klartext, Rechnungs-E-Mail-Erfassung (Versand NUR via Rechnungsadresse); QR-Tab mit SCOR-Referenz; Warnung „Reinigungen ohne Rechnung" (v0.49.0) mit Kasse-Ausschluss + ohne-Buchung-Check; **Migration 143** (Rechnungsbetrag kommt vom Positions-Trigger → dort 5-Rappen-Rundung, heineken_monat ungerundet); 38 Rechnungen (CHF 3'656.05) nachfakturiert; Tresen-Rechnung im Detail nacherstellbar (v0.49.1); Versionsanzeige `kAppVersion` im Forderungen-Titel. Live-Test 17.07. im Echtbetrieb bestanden (10/10 DB-verifiziert). Details `ToDo.md`.
> Zuvor (15.07.2026): **Material abgeholt → Bestände in einem Klick** (v0.47.0): neue **Bestellungen-Liste** `/materialien/bestellungen` (schliesst die Lücke, dass gesendete Bestellungen + PDFs bisher unauffindbar waren) mit „Material abgeholt" → Kontroll-Dialog (nach Kategorie gruppiert, Mengen vorbefüllt/korrigierbar, Freitext-Positionen ausgegraut) → Bestände buchen, plus „Buchung rückgängig". **Migration 141**: Status `abgeholt`, `abgeholt_am`, `menge_erhalten` + zwei **atomare RPCs** (relatives `bestand_aktuell + delta`, `FOR UPDATE`-Guard gegen Doppelbuchung). Restmengen laufen über `bestand_niedrig` automatisch auf die nächste Bestellliste — keine Teillieferungs-Verfolgung. Subagenten-getrieben, 400 Tests grün. Live-Test durch Daniel offen. Details `ToDo.md`.
> Zuvor (14.07.2026): **camt-Kundenzahlungs-Abgleich überarbeitet** (v0.46.21–v0.46.26): Matcher-Härtung (Auto nur bei Referenz/exaktem Namen/gelerntem Alias, unscharf → manuell), Vermerk-Parser (Rechnungsnummer + Davos-Klosters-Betriebnummer via `heineken_nr`, nur Vorauswahl), mehr Zahlungs-Infos + PDF-/Beleg-Links, „Nicht zugeordnet" nach Einzahler gruppiert + Mehrfach-Zuordnungs-Dialog. **Migration 139** (Preis-Trigger auf 5-Rappen-Rundung + Backfill Live-Periode) + **Migration 140** (`beleg_typ='camt053'`). camt-Test-Buchungen am Abend vollständig zurückgerollt (Baseline). Re-Test morgen. Details `ToDo.md`.
> Zuletzt (10.07.2026): **Events-Modul Phase E5** (v0.21.0) — **Events-Modul E1–E5 komplett**: **Abschluss-Mail** nach dem Event. Menüpunkt „Abschluss-Mail senden" → **PDF-Abschlussbericht** (ohne CHF: Zusammenfassung, Stände/Inbetriebnahme, Zeit & Aufwand nach Kategorie, Pikett-Einsätze) + **Empfänger-Sheet** (Eventverantwortlicher + RSL automatisch vorgeschlagen, freie Mail hinzufügbar, kommaseparierter Versand via `send-pdf-mail`). MailConfig-Bereich `event` (`eventScharf=false` → Testmodus). Keine DB-Migration. Scharfstellen (`eventScharf=true`) nach Handy-Testversand.
> Zuvor (10.07.2026): **Events-Modul Phase E4** (v0.20.0): Event-Detail auf **5 Tabs** (Kontakte | Stände | Einsätze | **Zeit** | Dokumente). **Zeit-/Spesenerfassung** (neue Sync-Vertikale `event_aufwand`, Migration 123): Zeilen mit Datum/Kategorie (Anfahrt/Inbetriebnahme/Pikett/Spesen)/Notiz/Stunden, Total-Chip. **Auto-Montage-Generierung**: „Montage generieren" aggregiert pro Eventtag (≤5 Slots) und öffnet das Montage-Formular (Typ Anlass, Veranstaltungs-Betrieb) vorbefüllt → normaler Heineken-Abrechnungsfluss. Spesen als zusätzliche Stunden. Nächste Phase E5 (Abschluss-Mail Einsatzliste + Zeiten/Spesen als PDF).
> Zuvor (10.07.2026): **Events-Modul Phase E3** (v0.19.0): Event-Detail auf **4 Tabs** (Kontakte | Stände | Einsätze | Dokumente). **Inbetriebnahme pro Anlage** (Live-Checkbox + Fortschritt-Chip, id-basierter Stand-Save). **GPS-Standort pro Stand** (geolocator). **Karten-Umschalter im Stände-Tab** mit swisstopo-Luftbild (flutter_map, kein API-Key), Marker pro Stand. **Pikett-Einsätze** (neuer Tab, minimales Formular; Migration 122 `event_einsaetze` + Stand-lat/lng + Anlage-in_betrieb). Nächste Phase E4 (Abschluss-Mail Einsatzliste als PDF).
> Zuvor (10.07.2026): **Events-Modul Phase E2** (v0.18.0): Event-Detail auf 3 Tabs (Kontakte | Stände | Dokumente). **Stände** mit Schankanlagen (OT/Hollandbuffet/Ausschankwagen), dynamisches Stand-Formular, Vorjahres-Übernahme. **Dokument-Ablage** (PDF-Upload in Storage-Bucket `event-dokumente`, ansehen/löschen; Migration 120).
> **Events-Modul Phase E1** (v0.17.0): neue Dashboard-Kachel «Events» mit Event-Jahren (Migration 119: `events` + `event_kontakte`), Kontaktliste pro Event-Jahr mit Rollen (Eventverantwortlicher/RSL/OK/Bau/Stand/…), Vorjahres-Übernahme, WhatsApp-/Anruf-Buttons; Abrechnung bleibt bei Montage «Anlass». Phasen E2–E4 (Lageplan/Stände, GPS-Karte + Einsätze, Abschluss-Mail) geplant — siehe ToDo.md. Zudem build_runner-Fix (null-aware Elements ersetzt, Lint deaktiviert).
> 07.07.2026: **App-Optimierung Paket 06 – P1 Quick-Wins** (v0.16.20): Eigenaufträge-Filter entfernt, Störungen-Filter auf Anlagentyp + Km-Abrechnung, Reinigung-UI (Chip „Protokoll", Service-Art, kompakte Zeiterfassung), Kontakt-Rolle „Stardrinks" (Migration 117), **Betriebsferien 3 → 5 Slots** (Migration 118, dynamisches Formular, zentraler Ferien-Util + Bugfix „nur Ferien 1 geprüft"). P2–P9 aus Paket 06 offen (siehe ToDo.md).
> Juni 2026: Buchhaltung-Voll-Migration 2019–2025, camt-Import, Forderungs-Hub, **Eingangsrechnungen TP-0…7 komplett** (Scan→KI/QR→Lernen→Kreditoren-Buchung→GKB-Zahlungsfile pain.001→camt-Kreditor-Abschluss→Reversibilität→Datenhygiene). **Eingangsrechnung-Kategorien** (15 KI-inhaltsbasierte Kategorien, löst Bussen-Erkennung kanton-unabhängig, v0.16.18). **camt-Screens in „Bankauszug Import" zusammengeführt** (4 Tabs Import·Prüfliste·Regeln·Dateien, Dashboard auf eine Kachel reduziert, v0.16.19). Alter camt-Abgleich-Screen entfernt (v0.16.17).

---

## Ursprünglicher Projektplan (Februar 2026)

*Planungsstand aus der Projektphase, wörtlich übernommen. Phasen, Schätzungen
und «ausstehend»-Vermerke sind historisch — der heutige Stand steht in
`Projekt.md`.*

#### Aktueller Stand: **Phase 4 - Polish & Testing** 📅

| Phase | Status | Fortschritt | Fertig am |
|-------|--------|-------------|-----------|
| **Phase 0: Planung & Analyse** | ✅ Abgeschlossen | 100% | 12.02.2026 |
| **Phase 1: Setup & Grundlagen** | ✅ Abgeschlossen | 100% | 20.02.2026 |
| **Phase 2: Core Features (MVP)** | ✅ Abgeschlossen | 100% | 14.03.2026 |
| **Phase 3: Administration** | ✅ Abgeschlossen | 100% | 15.03.2026 |
| **Phase 3b: Buchhaltung-Erweiterung** | ✅ Abgeschlossen | 100% | 31.03.2026 |
| **Phase 4: Polish & Testing** | 🔄 In Arbeit | 30% | - |
| **Phase 5: Deployment & Launch** | 🔄 Vorgezogen | 20% | - |

---

### ✅ ERLEDIGTE ARBEITSPAKETE

#### 1. Geschäftsanalyse & Dokumentation

##### ✅ Geschäftsbeschreibung
- **Datei**: `Prompts/02_Geschäftsbeschreibung.md`
- **Status**: Komplett ausgefüllt
- **Inhalt**:
  - Firmendetails (One-man operation, Heineken-Franchise)
  - 250 Kunden, 4-Wochen-Rhythmus
  - Budget: 200 CHF/Monat max
  - Ziel: 80% Zeitersparnis bei Administration

##### ✅ Excel-Analyse
- **Datei**: `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- **Status**: Vollständige Analyse von 37 Excel-Sheets
- **Key Findings**:
  - 4,144 Reinigungen (Hauptgeschäft)
  - 1,029 Störungen
  - 1,203 Montagen
  - Komplettes ERP-System in Excel

##### ✅ Heineken Monatsrechnungen
- **Datei**: `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- **Status**: 3 Monate analysiert (Okt-Dez 2025)
- **Key Findings**:
  - 8 Abrechnungskategorien
  - Q4 2025: 20,593 CHF an Heineken
  - 5 Störungsbereiche identifiziert

##### ✅ Reinigungsprotokolle
- **Datei**: `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- **Status**: 4 PDFs analysiert
- **Key Findings**:
  - 17-Punkt-Checkliste dokumentiert
  - Zeitersparnis: 25 Min → 4 Min pro Service
  - Potenzial: 1,450 Stunden/Jahr sparen

##### ✅ Störungsbereiche
- **Datei**: `Datenanalyse/04_Störungsbereiche_Analyse.md`
- **Status**: Heineken-Diagramm analysiert
- **Key Findings**:
  - 5 technische Bereiche mit unterschiedlichen Preisen
  - Bereich 3 (Kühlsystem) = 40% aller Störungen

##### ✅ Preisliste Heineken
- **Datei**: `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- **Status**: Offizielle Preisliste analysiert
- **Key Findings**:
  - Alle Preise excl. MWST (8.1%)
  - Bergkunden vs. Normalkunden-Unterscheidung

##### ✅ Preissystem Final
- **Datei**: `Datenanalyse/06_Preissystem_Final.md`
- **Status**: Alle Preisregeln geklärt
- **Key Findings**:
  - Pikett = 160 CHF (2 Tage)
  - Bergkunden zahlen ~2.4× mehr
  - Ersatzteile immer kostenlos für Kunden

##### ✅ Geschäftsabläufe
- **Datei**: `Prompts/03_Geschäftsabläufe.md`
- **Status**: Vollständig dokumentiert (9 Abschnitte)
- **Inhalt**:
  1. Tourenplanung (Tour von vor 1 Monat)
  2. Service-Durchführung beim Kunden
  3. Fahrt zwischen Kunden
  4. Ende des Tages/Woche
  5. Störungen (flexibel dazwischengeschoben)
  6. Montagen
  7. Pikett-Dienst (1 Wochenende/Monat)
  8. Eröffnungen/Endreinigungen
  9. Top 5 Zeitfresser/Frustrationen

**Wichtigste Erkenntnisse:**
- Betrieb → Anlage (1:n) ist KRITISCH
- Offline-Fähigkeit MUSS funktionieren
- Administration = größter Zeitfresser (5-10h/Woche)
- Materialverwaltung im Auto = kritisches Feature
- Zeitersparnis-Potenzial: 6-8 Stunden/Woche

---

#### 2. Technische Architektur

##### ✅ Tech-Stack-Analyse
- **Datei**: `Architektur/01_Tech_Stack_Analyse.md`
- **Status**: 4 Optionen verglichen, Entscheidung getroffen
- **Entscheidung**: **Flutter + Supabase** (56/60 Punkte)
- **Begründung**:
  - Beste Offline-Fähigkeit
  - Eine Codebase (Web + iOS + Android)
  - PostgreSQL perfekt für Betrieb→Anlage
  - Kosten: 0-23 CHF/Monat (weit unter Budget)
  - Multi-Tenant-ready

##### ✅ Datenmodell (Finalisiert & Live)
- **Datei**: `Architektur/02_Datenmodell.md`
- **Status**: Finalisiert und in Supabase ausgeführt (17.02.2026)
- **Inhalt**:
  - 24 Tabellen live in Supabase
  - 24 RLS Policies aktiv
  - 20 Trigger/Functions aktiv
  - 7 Views erstellt
  - Seed-Daten: 11 Regionen, 20 Kategorien, 43 Konten, 74 Buchungsvorlagen, 883 Artikel
- **DB-Zugriff**: Direkter Zugriff via Python (`Datenbank/db_query.py`)

---

### 📋 OFFENE ARBEITSPAKETE

#### Phase 1: Setup & Grundlagen (Woche 1-2)

| Aufgabe | Status | Priorität | Abhängigkeiten |
|---------|--------|-----------|----------------|
| ✅ Supabase Account | Vorhanden | - | - |
| ✅ GitHub Account | Vorhanden | - | - |
| ✅ Datenmodell finalisieren | Abgeschlossen | 🔴 Hoch | 12.02.2026 |
| ✅ Supabase Projekt Setup | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Migration Scripts ausführen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ DB-Direktzugriff (Python) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Flutter Projekt initialisieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Packages installieren (25+) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Projekt-Struktur aufsetzen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Supabase Client konfigurieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Isar DB einrichten (13 Collections) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Sync-Service (komplett, 12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ ConnectivityService (Online/Offline) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ 12 Mapper + 4 Repositories + 3 Providers | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| 🔄 Authentication (Login ✅, Provider ausstehend) | Teilweise | 🔴 Hoch | 17.02.2026 |
| ✅ Navigation (GoRouter, 16 Routes + Auth-Guard) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Design System / Theme (Material 3, AppColors) | Abgeschlossen | 🟡 Mittel | 20.02.2026 |

#### Phase 2: Core Features (MVP) (Woche 3-8)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Datenmodell in Code (24 DTOs + 13 Isar) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Offline-Sync-Logik (12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Authentication (Supabase Auth) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Betriebe CRUD (Liste, Detail, Form, Providers) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Betrieb MVP (Kontakte, Rechnungsadresse, Form-Erweiterungen) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Anlagen CRUD (Liste, Detail, Form, Providers, Bierleitungen) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Anlagen MVP (Dropdown-Fixes, Bierleitung CRUD, Gas-Validierung) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Reinigungen CRUD (Liste, Detail, Form, Providers, Service-Flow) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Störungen CRUD (Liste, Detail, Form, Providers, Störungsnummer) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Web-Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Android APK (Emulator getestet) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Isar Extension Bug Fix + Repository Refactoring | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Tourenplanung (Basis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Service-Protokoll (Unterschriften, Fotos, Preis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Unterschriften-Funktion | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Foto-Upload | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Preis-Kalkulator | Abgeschlossen | 🟡 Mittel | 11.03.2026 |
| ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |

#### Phase 3: Administration (Woche 9-12)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Kundenrechnung-Generierung (PDF + QR-Einzahlungsschein) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Materialverwaltung (CRUD, Bestellliste, Material-Picker) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Störungs-Management (Entkopplung, Vereinfachung, MwSt-Entfernung) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Montage-Management (CRUD, Betrieb-Autocomplete, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Pikett-Dienste (CRUD, Pauschale 80 CHF) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eigenaufträge (CRUD, 30 CHF Pauschale, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eröffnungsreinigungen (CRUD, Bergkunde auto-detect, Preise aus DB) | Abgeschlossen | 🔴 Hoch | 14.03.2026 |
| ✅ Betrieb-Verbesserungen (Ferien, Ruhetage, Saison→Datum) | Abgeschlossen | 🟡 Mittel | 14.03.2026 |
| ✅ Heineken Monatsrechnung (8 Kategorien, Combined PDF) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Heineken PDF-Formulare (6 Rapport-Typen als Beilagen) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Mahnwesen (Überfällige Rechnungen, Mahnstufen 0-3) | Abgeschlossen | 🟡 Mittel | 15.03.2026 |
| ✅ Buchhaltung komplett (Dashboard, Kontenplan, Journal, Buchungen, Berichte) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |

#### Phase 3b: Buchhaltung-Erweiterung (KW 13-14)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Spesen-Scanner OCR (Claude Haiku, Edge Function, Kamera-direkt) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Vorsteuer-Buchungen (separate MwSt auf Konto 1171) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Mischkauf-Handling (Essen + Benzin auf einem Beleg) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ TWINT/Karte Zahlungsweg-Erkennung (auto aus Beleg) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |
| ✅ camt.053 Bankimport (XML-Parser, Duplikat-Erkennung) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Beleg-Viewer (url_launcher, Signed URL) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |
| ✅ Provider-Invalidation (Kontenplan/Journal live-update) | Abgeschlossen | 🔴 Hoch | 31.03.2026 |
| ✅ Termine CRUD (Kalender, Betrieb-Zuordnung) | Abgeschlossen | 🟡 Mittel | 31.03.2026 |

#### Phase 4: Polish & Testing (Woche 13-16)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 🔄 UI/UX Verbesserungen | In Arbeit | 🟡 Mittel | 5 Tage |
| 📅 Offline-Sync Testing | Ausstehend | 🔴 Hoch | 3 Tage |
| 📅 Performance-Optimierung | Ausstehend | 🟡 Mittel | 3 Tage |
| 🔄 Beta-Testing mit Daniel | In Arbeit | 🔴 Hoch | 5 Tage |
| 🔄 Bug-Fixes | In Arbeit | 🔴 Hoch | 5 Tage |

#### Phase 5: Deployment & Launch (Woche 17-18)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 📅 App Store Submission (iOS) | Ausstehend | 🔴 Hoch | 2 Tage |
| 📅 Google Play Submission (Android) | Ausstehend | 🔴 Hoch | 2 Tage |
| ✅ Web Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| 📅 Dokumentation (Benutzerhandbuch) | Ausstehend | 🟡 Mittel | 2 Tage |
| 📅 Training für Daniel | Ausstehend | 🔴 Hoch | 1 Tag |
| 📅 Excel-Daten-Migration | Ausstehend | 🟡 Mittel | 2 Tage |

---

### 🎯 MVP FEATURES (Must-Have für Launch)

| Feature | Beschreibung | Status |
|---------|--------------|--------|
| **Betriebe & Anlagen** | CRUD, Suche, Filter | ✅ Erledigt |
| **Tourenplanung** | Tour von vor 1 Monat, Drag & Drop | ✅ Erledigt |
| **Service-Protokoll** | 17-Punkt-Checkliste + PDF | ✅ Erledigt |
| **Unterschriften** | Digital auf Smartphone | ✅ Erledigt |
| **Fotos** | Probleme dokumentieren | ✅ Erledigt |
| **Offline-Sync** | Funktioniert ohne Internet | ✅ Erledigt |
| **Rechnungen** | PDF mit QR-Einzahlungsschein | ✅ Erledigt |
| **Materialverwaltung** | Bestand tracken, Bestellliste | ✅ Erledigt |
| **Störungen** | Mit Störungsnummer, flexibel | ✅ Erledigt |
| **Montagen** | Zeiterfassung, 80 CHF/h | ✅ Erledigt |
| **Pikett** | Pauschale 80 CHF, Datum | ✅ Erledigt |
| **Eigenaufträge** | 30 CHF Pauschale, Material | ✅ Erledigt |
| **Eröffnungsreinigungen** | Bergkunde auto-detect, 60/135 CHF | ✅ Erledigt |
| **Spesen-Scanner (OCR)** | Beleg fotografieren → automatische Buchung | ✅ Erledigt |
| **Bankimport (camt.053)** | XML-Import, Duplikat-Erkennung | ✅ Erledigt |
| **Vorsteuer-Buchungen** | Separate MwSt-Einträge auf Konto 1171 | ✅ Erledigt |
| **Termine** | Kalender, CRUD, Betrieb-Zuordnung | ✅ Erledigt |

**Geschätzte MVP-Entwicklungszeit**: 12-16 Wochen

---

### 🔮 POST-MVP FEATURES (Nice-to-Have)

| Feature | Beschreibung | Priorität |
|---------|--------------|-----------|
| **Mahnwesen** | Automatische Mahnungen | 🟡 Mittel |
| **Internet-Abgleich** | Google Business API für Öffnungszeiten | 🟢 Niedrig |
| **GPS-Tracking** | Automatische Fahrzeiten | 🟢 Niedrig |
| **Routenoptimierung** | Optimale Reihenfolge vorschlagen | 🟡 Mittel |
| **Statistiken** | Dashboard mit KPIs | 🟡 Mittel |
| **Multi-User** | Für Franchise-Partner | 🟡 Mittel |
| **Push-Notifications** | Erinnerungen, Pikett-Benachrichtigungen | 🟢 Niedrig |

---

### 📁 DOKUMENTE-ÜBERSICHT

#### Projektbeschreibung
- `Prompts/01_Projektansatz.md` - Initialer Projektansatz
- `Prompts/02_Geschäftsbeschreibung.md` - Ausgefüllte Geschäftsbeschreibung
- `Prompts/03_Geschäftsabläufe.md` - Detaillierte Workflow-Dokumentation

#### Datenanalyse
- `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- `Datenanalyse/04_Störungsbereiche_Analyse.md`
- `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- `Datenanalyse/06_Preissystem_Final.md`

#### Architektur
- `Architektur/01_Tech_Stack_Analyse.md` - Tech-Stack-Entscheidung
- `Architektur/02_Datenmodell.md` - PostgreSQL-Schema (In Review)
- `Architektur/03_Roadmap.md` - Detaillierter Zeitplan

#### Projekt-Management
- `00_Projekt_Uebersicht.md` - **Diese Datei** (Dashboard)

---

### 💰 BUDGET-ÜBERSICHT

#### Entwicklungskosten
- **Self-Development**: 0 CHF (Daniel entwickelt mit Claude)

#### Betriebskosten (Monatlich)

| Jahr | Monat | Details |
|------|-------|---------|
| **Ab 20.02.2026** | **23 CHF** | Supabase Pro (25 USD ≈ 23 CHF) |

#### Einmalige Kosten

| Posten | Kosten | Wann |
|--------|--------|------|
| Apple Developer Account | 99 USD (~90 CHF) | Jahr 1 |
| Google Play Developer | 25 USD (~23 CHF) | Jahr 1 (einmalig) |
| **Total einmalig** | **~113 CHF** | |

**→ Weit unter Budget von 200 CHF/Monat!**

---

### 📊 ZEITERSPARNIS-POTENZIAL

#### Aktueller Zeitaufwand (pro Woche)

| Aufgabe | Aktuell | Mit App | Ersparnis |
|---------|---------|---------|-----------|
| Protokolle digitalisieren | 2-3h | 0h | 2-3h |
| Rechnungen erstellen | 2-3h | 0.5h | 1.5-2.5h |
| Excel-Eingabe | 1-2h | 0h | 1-2h |
| Materialnachbestellung | 0.5h | 0.1h | 0.4h |
| Papierkram pro Service (21 Min × 40 Services/Woche) | 14h | 2.7h | 11.3h |
| **TOTAL pro Woche** | **19.5-20.5h** | **3.3h** | **16.2-17.2h** |

**Jährliche Zeitersparnis**: ~840 Stunden = **105 Arbeitstage!**

**ROI**: Bei 80 CHF/h Stundensatz = **67,200 CHF/Jahr gespart**

---

---

## Erledigt-Liste Februar–Juni 2026 (Punkte 1–209)

*Wörtlich übernommen, inklusive der Juni-Abschnitte «Temporär aktiv» und
«Nächste Schritte», die heute überholt sind.*

### Erledigt am 17.02.2026
1. ✅ Supabase DB komplett live (24 Tabellen, alle Seeds)
2. ✅ Direkter DB-Zugriff via Python eingerichtet
3. ✅ Flutter 3.41.1 + Android Studio installiert
4. ✅ Flutter Projekt erstellt (`sbs_projer_app`)
5. ✅ 25+ Packages installiert & konfiguriert
6. ✅ Projekt-Struktur (Clean Architecture) aufgesetzt
7. ✅ Supabase Client konfiguriert & getestet
8. ✅ Login Screen – funktioniert mit Supabase Auth
9. ✅ GoRouter mit Auth-Guard
10. ✅ Isar Core-Collections (Betrieb, Anlage, Region, Reinigung)
11. ✅ Supabase DTOs (Betrieb, Anlage, Region)

### Erledigt am 20.02.2026
12. ✅ Alle 24 Supabase DTOs erstellt (fromJson/toJson)
13. ✅ Alle 12 Isar Local-Models + SyncMetaLocal (13 Collections total)
14. ✅ `@Index()` auf serverId + isSynced für alle 12 Local-Models
15. ✅ 12 Mapper-Klassen (Local ↔ DTO Konvertierung)
16. ✅ ConnectivityService (Online/Offline-Erkennung, Stream)
17. ✅ SyncService (~580 Zeilen, Push/Pull für alle 12 Entitäten)
    - Push: isSynced=false → Supabase upsert
    - Pull: Incremental (updated_at > lastPullAt), Bierleitung: Full-Pull
    - Konflikt: Last Write Wins (Timestamp-Vergleich)
    - Auto-Sync bei Connectivity-Change
    - Tier-basierte Sync-Reihenfolge (FK-Abhängigkeiten)
18. ✅ 4 Core-Repositories (Region, Betrieb, Anlage, Reinigung)
19. ✅ 3 Riverpod Providers (Connectivity, Sync, Betrieb)
20. ✅ Login-Integration (SyncService startet nach Login)
21. ✅ `flutter analyze` – 0 eigene Issues
22. ✅ Design System (AppColors, AppTheme.light, Material 3)
23. ✅ Dashboard / Home Screen (Kacheln mit Live-Counts, Sync-Banner, Menü)
24. ✅ Betriebe CRUD (Liste mit Suche/Filter, Detail mit Sektionen, Form)
25. ✅ Betrieb-Provider (Stream, List, Count)
26. ✅ Anlagen CRUD (Liste, Detail mit Bierleitungen, Form)
27. ✅ Anlagen-Provider (Stream, List, Count, byBetrieb Family)
28. ✅ BierleitungRepository (CRUD + watchByAnlage)
29. ✅ Betrieb-Detail mit Anlagen-Sektion (Stream, "Neue Anlage"-Button)
30. ✅ GoRouter: 12 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen)
31. ✅ Supabase auf Pro-Plan upgraded
32. ✅ Reinigungen CRUD (Liste mit Suche/Status-Filter, Detail mit Checkliste+Progress-Ring, Form mit Service-Flow)
33. ✅ Reinigung-Provider (Stream, List, Count, byAnlage, byBetrieb)
34. ✅ Reinigungen in Anlage-Detail (Sektion mit Stream, "Neue Reinigung"-Button)
35. ✅ Service-Flow: 4 Anlagen-Checks + 12 Service-Punkte + Zeiterfassung + Abschliessen
36. ✅ Störungen CRUD (Liste mit Suche/Status-Filter, Detail mit Bereich 1-5/Preis/Material, Form mit Pikett/Bergkunde)
37. ✅ Störung-Provider (Stream, List, Count, byAnlage, byBetrieb)
38. ✅ Störungen in Anlage-Detail (Sektion mit Stream, "Neue Störung"-Button)
39. ✅ Störungsnummer-Generator (STR-YYYYMM-NNN)
40. ✅ GoRouter: 16 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen, 4× Störungen)
41. ✅ Navigation: context.go() → context.push() (27 Stellen, Back-Buttons überall)
42. ✅ Windows Desktop Build (Visual Studio C++, Developer Mode)

### Erledigt am 07.03.2026
43. ✅ Web-Deployment auf GitHub Pages (Conditional Exports, kIsWeb-Branching)
44. ✅ Alle 6 Repositories mit Web-Support (Supabase direkt auf Web, Isar auf Native)
45. ✅ `routeId` Getter auf allen Local Models (Web: serverId, Native: id)
46. ✅ String-basierte IDs im Router und allen 12 Screens
47. ✅ Web-Stubs für Isar Models (`*_local_web.dart`)
48. ✅ Web-Shortcuts für Connectivity/Sync Provider
49. ✅ Android APK Build + Emulator-Test (Sync funktioniert)
50. ✅ Isar Extension Bug behoben (Extensions funktionieren nicht auf `dynamic`)
51. ✅ IsarService mit typed Query Methods (alle Isar-Queries zentral gewrappt)
52. ✅ 6 Repositories auf `IsarService.xxxMethod()` Pattern refactored
53. ✅ Web-Build + Native-Build beide fehlerfrei (`flutter analyze`)
54. ✅ Betrieb-Formular erweitert (Heineken-Nr → Betrieb Nr, Rechnungsstellung-Dropdown, Saison-Details, Region-Dropdown)
55. ✅ DB Migration 008 (betrieb_nr, rechnungsstellung Enum, saison_start/ende)
56. ✅ BetriebKontakt CRUD komplett (Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
57. ✅ BetriebRechnungsadresse CRUD komplett (Isar Model, Mapper, Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
58. ✅ 8 Repositories (+ BetriebKontakt, BetriebRechnungsadresse)
59. ✅ 19 Routes im GoRouter (+ Kontakt-Create/Edit, Rechnungsadresse)
60. ✅ Betrieb MVP abgeschlossen
61. ✅ Anlage-Formular: Vorkühler-Dropdown korrigiert ('nass'/'trocken' → DB-Werte 'Fasskühler'/'Kühlzelle'/'Buffet')
62. ✅ Anlage-Formular: Durchlaufkühler Freitext → Dropdown (9 DB-Optionen)
63. ✅ Anlage-Formular: Säulen-Typ Freitext → Dropdown (14 DB-Optionen)
64. ✅ Anlage-Formular: Gas-Typ 1/2 Freitext → Dropdown (3 DB-Optionen) + Cross-Validierung
65. ✅ Anlage-Formular: Reinigung-Rhythmus korrigiert (8 korrekte DB-Optionen)
66. ✅ Anlage-Formular: Status 'stillgelegt' hinzugefügt
67. ✅ Anlage-Detail: Vorkühler-Label Fix
68. ✅ Bierleitung CRUD komplett (Form-Screen, Auto-Nummer, Add/Edit/Delete im Detail)
69. ✅ 21 Routes im GoRouter (+ Bierleitung-Create/Edit)
70. ✅ Anlagen MVP abgeschlossen
71. ✅ Gast-User in Supabase erstellt (`gast@sbsprojer.ch`)
72. ✅ DB Migration 009: RLS SELECT-Policies für Gast auf 9 Tabellen
73. ✅ SupabaseService erweitert: `isGuest`, `dataUserId` (Gast sieht Daniels Live-Daten)
74. ✅ 8 Repositories: `_userId` → `SupabaseService.dataUserId`
75. ✅ GoRouter: Redirect-Guard für Form-Routes (Gast kann keine `/neu`/`/bearbeiten`-URLs aufrufen)
76. ✅ 5 UI-Screens: Create/Edit/Delete-Buttons für Gast ausgeblendet (3-Schicht-Sicherheit: DB + Router + UI)
77. ✅ Web-Build + Deploy auf GitHub Pages mit Gastzugang

### Erledigt am 11.03.2026
78. ✅ Auth Provider (authStateProvider, isAuthenticatedProvider, currentUserProvider)
79. ✅ Passwort vergessen (Dialog mit Reset-Link, redirectTo Web-App)
80. ✅ Reaktiver Auth-Guard (GoRouter refreshListenable, automatischer Redirect)
81. ✅ Session-Refresh beim App-Start (bei Fehler automatisch signOut)
82. ✅ Passwort-Recovery-Dialog (Neues Passwort setzen nach Reset-Link)
83. ✅ Tourenplanung Basis (Kalender-Wochenansicht, Tour-Vorschlag ±2 Tage, Drag & Drop, Filter, Dashboard-Kachel)
84. ✅ Unterschriften (Signature-Widget, Techniker + Kunde, Base64-PNG)
85. ✅ Fotos (image_picker, Supabase Storage, Max 4/Anlage, Grid + Vollbild)
86. ✅ Preis-Kalkulator (Reinigung + Störung, Live-Preview, Preisliste aus DB)
87. ✅ Betriebe-Filter erweitert (Meine Kunden, Region Multi-Select, Status Default Aktiv)
88. ✅ Bierleitung-Delete Refresh-Fix + Hahn-Typ Dropdown
89. ✅ BackButton-Fix (context.pop statt Navigator.maybePop)
90. ✅ Löschen-Funktion für Betriebe, Anlagen, Reinigungen & Störungen (Cascade)
91. ✅ Checkliste-Notizen pro Punkt (Migration 013)

### Erledigt am 12.03.2026
92. ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220/Vers.04, Supabase Storage, Printing)
93. ✅ Kundenrechnung komplett:
    - RechnungRepository + RechnungsPositionRepository (Supabase-only)
    - RechnungService (Auto-Erstellung bei Reinigung-Abschluss)
    - RechnungPdfService (A4-PDF mit Swiss QR-Einzahlungsschein)
    - RechnungPdfStorage (Bucket: rechnung-pdfs)
    - Rechnungen-Liste + Detail-Screen (Suche, Status-Filter, PDF-Druck)
    - Rechnung-Providers (Stream, Count, offene, byBetrieb)
    - Dashboard-Kachel ("X offen")
    - Routes: /rechnungen, /rechnungen/:id

### Erledigt am 12.03.2026 (Abend)
94. ✅ Materialverwaltung komplett:
    - 4 Repositories (Lager, MaterialKategorie, MaterialArtikel, MaterialVerbrauch)
    - Material-Providers (materialienStream, materialCount, niedrigCount)
    - Materialien-Liste (Suche, Kategorie-Filter, Bestand-Filter niedrig)
    - Material-Detail (Bestand-Visualisierung, Info, Verbrauchshistorie, Quick-Bestand-Anpassung)
    - Material-Formular (Kategorie, Einheit, Bestand aktuell/mindest/optimal, Lieferant, Heineken-Artikel-Picker)
    - Bestellliste (niedrige Bestände, Fehlmenge, Zwischenablage-Export)
    - Dashboard-Kachel "Material" mit "X niedrig" Badge
    - Material-Picker in Störungs-Formular (5 progressive Slots)
    - Störung-Detail: Lager-Namen statt UUIDs
    - 5 Routes (/materialien, /bestellliste, /neu, /:id, /:id/bearbeiten)

### Erledigt am 13.03.2026
95. ✅ Montage CRUD komplett (Liste, Detail, Form, Router, Home, Betrieb-Detail Section, Sync)
96. ✅ Montage vereinfacht (Beschreibung als Pflichtfeld, Datum, Uhrzeit, Betrieb-Autocomplete, Material 3 Slots)
97. ✅ Betrieb: Ruhetage + Ferien-Management für alle Betriebe (DB Migration 014)
98. ✅ Pikett-Dienste CRUD komplett (Liste, Detail, Form, Router, Home, Sync, Pauschale 80 CHF)
99. ✅ Störungen von Anlage entkoppelt (DB Migration 016, anlage_id optional, betrieb_id direkt)
100. ✅ Störungs-Formular vereinfacht (Betrieb-Autocomplete, MwSt entfernt, Preis-Keys fix)
101. ✅ Störungen-Section auf Betrieb-Detail + Autocomplete im Form
102. ✅ Eigenauftrag CRUD komplett (Migration 017, Model, Local, Mapper, IsarService, Repository, Providers, 3 Screens, Router, Home, Betrieb-Detail Section, Sync)
103. ✅ Eigenauftrag: Lösung + Notizen Felder entfernt (nicht benötigt)

### Erledigt am 14.03.2026
104. ✅ Saison-Felder von Monat (int) zu Datum umgestellt (DB Migration 018, DatePicker statt Dropdown)
105. ✅ Eröffnungsreinigung CRUD komplett:
    - DB Migration 019 (eroeffnungsreinigungen Tabelle + RLS)
    - DTO, Isar Local Model, Web-Stub, Conditional Export, Mapper
    - IsarService Methoden + Web-Stubs (8 Methoden)
    - Repository + Providers
    - 3 Screens (Liste, Detail, Form)
    - Betrieb-Autocomplete → automatische Bergkunde-Erkennung
    - Preis automatisch aus Preistabelle (Normal 60 CHF, Bergkunde 135 CHF)
    - Eröffnungsreinigungen-Section auf Betrieb-Detail
    - Router (4 Routes) + Home Tile + Sync

### Erledigt am 15.03.2026
106. ✅ Heineken Monatsrechnung komplett:
    - HeinekenRechnungService (8 Kategorien aggregieren, Supabase-Queries)
    - HeinekenPdfService (Übersicht + Detail im Heineken-Format)
    - HeinekenMonatsDaten Model (Summen + Raw Data)
    - 3 Screens: Liste, Generierung (Monats-Picker + Vorschau), Detail
    - Heineken Providers + Router + Home-Kachel
107. ✅ 6 Heineken Rapport-PDFs:
    - HeinekenRapportService: F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale
    - buildXPage() + generateX() Pattern für Wiederverwendung
108. ✅ Rapport-PDFs an Monatsrechnung angehängt:
    - Combined PDF: Hauptrechnung + alle Rapport-Beilagen in einem Dokument
    - _addRapportPages() mit 6 Sektionen
109. ✅ Buchhaltung komplett:
    - 3 Repositories: KontoRepository, BuchungRepository, BuchungsVorlageRepository
    - 4 Provider-Dateien (Konten, Buchungen, Vorlagen, Buchhaltung-Aggregate)
    - BuchungService (Buchung aus Vorlage, Kontosaldo-Berechnung)
    - 7 Screens: Dashboard, Kontenplan, Journal, Buchung-Detail, Buchung-Formular, Berichte, Mahnwesen
    - Berichte: Erfolgsrechnung (monatlich/jährlich) + MwSt-Abrechnung (quartalsweise) aus DB-Views
    - Mahnwesen: Überfällige Rechnungen, Mahnstufen 0-3
    - 7 neue Routes unter /buchhaltung/*
    - Home-Kachel "Buchhaltung"

### Erledigt am 18.03.2026
110. ✅ Rechnungsadresse: Betrieb-Feld unter Firma verschoben, auto-gefüllt (non-editable)
111. ✅ Hahn-Typ "Higenie" zu Bierleitung-Dropdown hinzugefügt
112. ✅ Durchlaufkühler "Orion" + "V100" zu Anlagen-Dropdown hinzugefügt (+ DB Migrationen 028, 029)
113. ✅ Säulen-Typ "Cola Säule" zu Anlagen-Dropdown hinzugefügt (+ DB Migration 030)
114. ✅ Tourenplanung Fällig-Tab komplett überarbeitet:
    - Fälligkeit dynamisch berechnet aus letzteReinigung + reinigungRhythmus
    - Neue Anlagen (nie gereinigt) erscheinen als "überfällig"
    - auf-Abruf/Selbstreiniger ausgeschlossen
    - Ruhetag-Check entfernt (alle aktiven Betriebe unabhängig vom Wochentag)
    - Letzte Reinigung als separate Zeile angezeigt ("Noch nie gereinigt" in rot)
115. ✅ Viewport Meta-Tag in web/index.html hinzugefügt
116. ✅ Kontakt-Formular: Handykontakte importieren + auf Handy speichern (PhoneContactService)

### Erledigt am 31.03.2026
117. ✅ camt.053 Bankimport komplett:
    - XML-Parser (UTF-8, Hierarchie-Fix)
    - Web File Picker (dart:html statt file_picker)
    - Duplikat-Erkennung (Referenz-basiert)
    - Auto-Betrieb-Matching
118. ✅ Spesen-Scanner mit OCR komplett:
    - Supabase Edge Function `parse-beleg` (Claude Haiku 4.5 API)
    - BelegScanResult Model (Geschäft, Datum, Positionen, Konfidenz, Zahlungsmethode)
    - BelegScanService (Base64-Encode → Edge Function → JSON-Parse)
    - SpesenImportService (Aufwand-Buchung + Vorsteuer-Buchung pro Position)
    - SpesenScannerScreen (Kamera-direkt, OCR-Ergebnis, Zahlungsweg, Buchen)
    - Mischkauf-Handling (Essen 2.6% + Benzin 8.1% als separate Buchungen)
    - TWINT/Karte/Bar-Erkennung (automatische Zahlungsweg-Vorauswahl)
    - Konten-Mapping: Essen→5820, Benzin→6200, Bar→1000, Bank→1020, Privat→2260, Vorsteuer→1171
119. ✅ Vorsteuer-Buchungen:
    - Separate Buchung pro Position: Soll 1171 (Vorsteuer) / Haben Zahlungskonto
    - MwSt-Betrag als eigene Buchungszeile im Journal
120. ✅ Beleg-Viewer:
    - Belege in Buchungs-Detail direkt öffnen (url_launcher, Signed URL)
    - Beleg-Quelle "Spesen-Scanner" Label
121. ✅ Provider-Invalidation:
    - SpesenScannerScreen → ConsumerStatefulWidget (ref.invalidate)
    - kontoSaldiProvider watched buchungenStreamProvider (live-update Kontenplan)
122. ✅ Termine CRUD komplett:
    - DB Migration 037, Model, Local, Mapper, Repository, Providers
    - IsarService + Web-Stubs, Sync, Router, Screens
123. ✅ DB-Migrationen 031-038 (Gas-Typ, Durchlaufkühler, Biersorten, Bierleitung aktiv, Termine, Beleg-Quelle)

### Erledigt am 21.04.2026
124. ✅ Störungsliste: Anlagentyp-Icons → Anfangsbuchstaben → Störungsnummer im Avatar (Format 001)
125. ✅ Störungsliste: 2-Zeilen-Subtitle (Ort·Datum / Anlagentyp·Bereich·Preis)
126. ✅ Störungsliste: Anlagentyp-Filter (PopupMenuButton mit Chip-Anzeige)
127. ✅ Störungsliste: Monatsgruppierung mit Preissummen (Header pro Monat + Gesamtsumme)
128. ✅ Störungs-Formular: Anlagentyp-Auswahl (FilterChips, Betrieb-Vorauswahl aus Zapfsystemen)
129. ✅ Störungs-Formular: "Heineken-Nr" → "Störungsnummer" umbenannt
130. ✅ Störungs-Formular: Notizen-Feld entfernt (Beschreibung reicht)
131. ✅ Störungs-Formular: Material-Dropdown öffnet nach oben (Tastatur-Fix für Mobile)
132. ✅ Störungs-Detail: Anlagentyp-Icon + Label, Icon build statt warning
133. ✅ Uhrzeiten überall HH:mm statt HH:mm:ss (Störung, Reinigung, PDF-Rapport)
134. ✅ Betrieb-Formular: "Mein Kunde" auto-false wenn nur David/Heigenie
135. ✅ Betrieb-Detail: Saison anzeigen auch ohne Datumswerte
136. ✅ 5-Rappen-Rundung für alle CHF-Beträge + zahlungsweg CHECK Constraint
137. ✅ Reinigung-Buchung: Automatische Buchung mit korrekter MwSt bei Tresen/Mail/Post
138. ✅ camt.053 Import: XML-Parser Hierarchie + Web File Picker Fix

### Erledigt am 07.05.2026
139. ✅ Performance: Shared Betrieb-Provider (betriebNameMap, betriebOrtMap, betriebRegionIdMap) — 8 Screens refactored
140. ✅ Performance: Home Screen in Sub-ConsumerWidgets aufgeteilt (_SyncIndicator, _KachelGrid, _WeitereSection, _TagesUebersicht)
141. ✅ Performance: TagesUebersicht-Logik in eigenen Provider extrahiert
142. ✅ Home Screen: 2x5 Kachel-Grid (Betriebe, Reinigungen, Störungen, Montagen, Eigenaufträge, Eröffnungen, Kontakte, Termine, Tourenplanung, Spesen) — optimiert für Pixel 9
143. ✅ Montage-Formular: HeiGenie Service Protokoll-Anzeige wie bei Reinigungen (full width statt 200px)
144. ✅ Belegscanner: Rundungsdifferenzen (≤0.05 CHF) werden in grösste Position gemergt
145. ✅ Buchungsvorlage Parkgebühren Privat/Twint (GF 5.2, Soll 6270, Haben 2260, 0% MwSt)
146. ✅ Heineken Monatsrechnung: Kilometerabrechnungen zeigen keinen Bereich mehr (statt "Konventionell")
147. ✅ Kontakt-Rolle «Vertreter» für Heineken hinzugefügt

### Erledigt am 08.05.2026
148. ✅ Kontakt-Sync Stufe 1: App-Kontakte aufs Handy pushen (Bulk-Push mit Labels „SBS Kunden"/„SBS Heineken"/„SBS Event")
149. ✅ Buchungsvorlagen: 37 Duplikate bereinigt (GF-Nummern dedupliziert)
150. ✅ Beleg-Erfassung im Buchungsformular (PDF/Foto/Kamera Upload, BelegUploadWidget)
151. ✅ Lohnbuchhaltung komplett:
    - DB Migration 076 (lohn_einstellungen + lohn_abrechnungen + 4 neue Konten: 5710 FAK, 5720 BVG AG, 5730 UVG AG, 5740 KTG AG)
    - LohnEinstellungen Model (Versicherungs-Sätze pro User/Jahr, Lohnausweis-Daten)
    - LohnAbrechnung Model (flexible Auszahlungen, Datum-basiert, mehrere pro Monat möglich)
    - LohnRepository (berechnen mit 5-Rappen-Rundung, buchen mit 7-11 Buchungen via beleg_id, stornieren)
    - LohnlaufScreen (Jahresübersicht, Neuer Lohnlauf mit Live-Berechnung, Detail, Storno)
    - LohnEinstellungenScreen (Sozialversicherungs-Sätze, BVG-Fixbeträge, Lohnausweis-Daten)
    - LohnausweisPdfService (Schweizer Lohnausweis Formular 11 als PDF)
    - Buchhaltung-Dashboard: NavTile „Lohnbuchhaltung"

### Erledigt am 09.-10.05.2026
152. ✅ Betrieb: Servicezeiten (Morgen/Nachmittag) für Betriebe hinzugefügt
153. ✅ Betrieb: WE-Nummer + AG-Nummer Felder (Nummern-Kategorie in Form/Detail, Zahlentastatur)
154. ✅ Betrieb: Region in Detail-Ansicht anzeigen
155. ✅ Heineken Monatsraster komplett:
    - RasterPdfService (Querformat A4, gruppiert nach Regionen, jede Region auf eigener Seite)
    - HeinekenRasterScreen (Datensammlung: Betriebe, Anlagen, Bierleitungen, Reinigungen, Kontakte)
    - Rotpunkt-Logik (kleinstes Reinigungsintervall > 6 Wochen)
    - Bierleitungen-Zählung über alle Anlagen
    - Bemerkungen: Servicezeiten + Kontakt-Telefon
    - Zahlung: BZ/RG/HS aus Rechnungsstellung
    - Monatswerte: Tag, (E) bei Eröffnung/Endreinigung, F=Ferien, A=Inaktiv, G=Geschlossen
    - PDF-Cache pro Jahr (Jahreswechsel behält generiertes PDF)
    - Mail-Versand via Edge Function (send-raster-mail, Storage Bucket raster-pdfs)
    - Mobilfreundliches Layout (Button + Wrap)
156. ✅ Service Worker deaktiviert (--pwa-strategy=none):
    - Webapp nach Deploy sofort aktuell nach einfachem Refresh
    - Kein Löschen von Browserdaten mehr nötig
    - Deploy-Workflow in CLAUDE.md aktualisiert
157. ✅ 3 neue Regionen: Sempach, Küssnacht, Cham (DB: 15 Regionen total)

### Erledigt am 10.–11.05.2026
158. ✅ Heineken Monatsraster: Cache-Buster auf PDF-Download-URL
159. ✅ Heineken Monatsraster: PDF Layout-Verbesserungen
160. ✅ Heineken Raster-Mail: Text mit aktuellem Datum
161. ✅ Zahlungsdifferenz-Handling bei Rechnungen + Pikett-Formular anpassen
162. ✅ Heineken Störungsformular: Pikett KW Sonderzeichen-Fix + Km-System
163. ✅ Pikett-Monatszuordnung: nach Montag der KW (statt Pikett-Datum)
164. ✅ Eröffnung/Endreinigung: Störungsnummer + Art im Formular anzeigen
165. ✅ Heineken Monatsrechnung: Gratisreinigungen fehlen nach Neuerstellen — Fix
166. ✅ Heineken PDF: 5 Verbesserungen (Layout, Formatierung)
167. ✅ Pikett-Dienste Kachel: Gruppierung nach Montag der KW
168. ✅ DST-Bug in Kalenderwochen-Berechnung behoben (UTC statt lokale Zeit)
169. ✅ Heineken PDF: Seitenumbruch-Fix + verbrauchtes Material anzeigen
170. ✅ Material-Formular: Heineken-Beschreibung + Foto-Optimierung
171. ✅ Material-Foto komplett überarbeitet:
    - Supabase Storage INSERT-Policy erstellt (Fotos konnten vorher nicht hochgeladen werden)
    - Foto-Crop-Editor (crop_your_image, fixCropRect, Rotation, Dark Theme)
    - Zwei-Datei Upload (HighRes + Preview 400px/60% JPEG)
    - Lazy HighRes Loading (Preview auf Detailseite, HighRes on-demand)
    - PopScope gegen Browser-Back-Verwechslung
    - Lade-Spinner beim Foto-Ändern
172. ✅ Material-Liste: Subtitle neu DBO-Nummer + Kategorie (ohne Einheit), einzeilig

### Erledigt am 14.05.2026
173. ✅ Material: bestand_niedrig Fix (< statt <=) — Bestand = Mindest zeigt kein Warnsignal mehr
174. ✅ Material: Foto-Spinner Fix — Spinner wird jetzt beim Ändern bestehender Fotos angezeigt
175. ✅ Material: "Auf Optimal auffüllen" Button im Bestand-Anpassen-Dialog
176. ✅ Material-Liste: Sortierung nach DBO-Nummer (Artikel ohne DBO am Ende, alphabetisch)
177. ✅ Material: Stück pro Packung Feld (bei Einheit „Packung" erscheint zusätzliches Eingabefeld)
178. ✅ Materialbestellung komplett:
    - MaterialBestellungScreen (Empfänger aus Heineken Kontaktzuweisung, Auto-Niedrig-Toggle)
    - Drei Sektionen: Verbrauchsmaterial, Reinigungsmaterial, Weitere Artikel
    - Checkbox + editierbare Mengen pro Artikel
    - Artikel vormerken (Bookmark-Icon in Material-Detail + Liste)
    - BestellungPdfService (PDF mit Heineken-Green Branding, DBO/Artikel/Menge/Einheit Tabelle)
    - MaterialBestellungRepository (CRUD, Bestell-Nr MB-001, PDF-Upload, signierte URLs)
    - DB: material_bestellungen + material_bestellpositionen Tabellen mit RLS
    - Storage: bestellung-pdfs Bucket mit RLS-Policies
    - Edge Function send-rechnung-mail erweitert (bestellungId + Materialbestellung.pdf Anhang)
    - MailConfig: bestellung-Bereich für Test-/Scharfmodus
    - Bestellhistorie in DB gespeichert (Status: entwurf → gesendet)
    - vorgemerkt-Flag auf Lager-Tabelle + Toggle in Detail/Liste

### Erledigt am 15.–16.05.2026
179. ✅ Material-Suche: durchsucht jetzt auch Beschreibung, Notizen und Lieferant
180. ✅ Material-Liste: +1/-1 Buttons für Bestand direkt in der Liste (später in Detail verschoben)
181. ✅ Materialbestellung: Dropdown-Auswahl, je 2 Positionen pro Kategorie
182. ✅ Materialbestellung: Reihenfolge Reinigung → Verbrauch → Vorgemerkte → Niedrig-Switch
183. ✅ Materialbestellung-PDF: Reinigungsmaterial vor Verbrauchsmaterial, DBO-Sortierung
184. ✅ Material UI: Minus-Button, Löschen im Formular, Titel mehrzeilig
185. ✅ Manual-PDF Upload/Anzeige für Material-Artikel (Anleitungen für Thermostaten etc.)
186. ✅ Manual-PDF: nur für relevante Kategorien (Elektronik, Thermostat, Pumpe, Fasskühler, Bierkühler, Säule)
187. ✅ +/- Buttons: von Materialliste in Detailscreen verschoben, Bestellliste-Screen entfernt
188. ✅ +/- Buttons: aktualisieren Materialliste sofort (Provider-Invalidierung)
189. ✅ Material-Auswahl: speichert jetzt auch ohne Dropdown-Klick (Text-Matching Fallback in Montage/Störung/Eigenauftrag)
190. ✅ Material-Bestand: aktualisiert sich nach Service-Speicherung (materialienStreamProvider invalidiert in 3 Formularen)
191. ✅ Material-Filter: zeigt nur Kategorien mit tatsächlichen Einträgen

### Erledigt am 19.–29.05.2026
192. ✅ Heineken-Monatsrechnung: Status-Workflow gefixt (offen → gesendet → freigegeben → bezahlt) + HeiGenie-Mail-Bedingung
193. ✅ Heineken-Rechnung: alle Status-Buttons immer im Body sichtbar
194. ✅ Buchhaltung: Rechnungs-Nachversand-Screen
     - Rechnungsadresse-Join via betriebe genestet (PostgREST-Fix)
     - betrag_brutto als String → double.tryParse, 5-Rappen-Rundung in Anzeige
     - 2 separate Queries + defensive .toString()-Casts (Type-Error-Fix)
     - PDF-Link on-demand neu signieren (gecachte URL läuft nach 1h ab)
     - betriebe.email als Fallback-Empfänger, versendet_am aus DB ignoriert
195. ✅ CLAUDE.md: DB-MCP-Zugriff dokumentiert, Deploy ohne git stash, Zahlungsstatus-Section
196. ✅ Projekt-Review mit Opus 4.8 (v0.10.97+379):
     - Bugfix: Reinigung-Zahlungsstatus 'versendet' → 'gesendet' (PostgrestException nach Migration 083)
     - Bugfix: Heineken Anfahrtspauschale-Fallback reaktiviert (_toDoubleN statt _toDouble lieferte stets 0)
     - Kontakt-Entity voll in Isar integriert (8 IsarService-Methoden, KontaktLocal.routeId, Schema) → Native-Build kompiliert wieder
     - Dead Code in PDF-Services entfernt, ~30 Lints bereinigt (initialValue, null-aware-Elements, debugPrint), barcode als direkte Dependency
     - flutter analyze: 0 Errors (vorher 11 versteckte Compile-Fehler), nur noch akzeptierte Infos + generierter Isar-Code

### Erledigt am 30.05.2026 (Mail-Versand scharfstellen + Bereinigung)
197. ✅ Reinigungsrechnungen scharfgestellt (`reinigungScharf=true`):
     - Beim Service-Abschluss echte Kunden-Email statt `null` ermitteln (betrieb_rechnungsadressen.email → Fallback betriebe.email)
     - Fehlt eine Kundenadresse → Versand an Daniel + orange Warnung
198. ✅ Montage scharfgestellt (`montageScharf=true`): HeiGenie-Service-Protokoll-Mail geht an echten RSL-Kontakt (mit PDF) statt Test-Empfänger
199. ✅ Nachversand-Screen erweitert:
     - Respektiert jetzt MailConfig (Testmodus) statt direktem Versand
     - Reinigungsprotokoll wird angehängt (Pfad über rechnungs_positionen → reinigungen.protokoll_foto_pfad)
     - Banner spiegelt tatsächlichen Modus (TESTMODUS/SCHARF)
     - versendet-Markierung aus DB (`versendet_am`) statt nur Session-State → bleibt nach Reload erhalten
     - Piaggio Dosch (2026-05-0615) aus Liste ausgeblendet (manuell versendet, Ausschlussliste statt versandart-Änderung)
200. ✅ Mail-Adressen-Bereinigung (Fix "Invalid To header" / Gmail 400):
     - `MailConfig.bereinige()`: entfernt Zero-Width-Spaces (U+200B–U+200D), BOM, NBSP + trim; `empfaenger()` gibt immer bereinigt zurück
     - DB-Korrektur: Padelta-Email (chur@padelta.ch) hatte 2× U+200B
     - Edge Function `send-rechnung-mail` v7: `encodeEmailDomain()` kodiert IDN-/Umlaut-Domains via Punycode (z.B. teehütte-klosters.ch → xn--…)
201. ✅ `versendet_am` nur bei scharfem Versand setzen:
     - `MailConfig.istScharf(bereich)`; Nachversand + Service-Abschluss markieren im Testmodus nicht mehr als versendet
     - DB-Korrektur: Mountain Plaza (2026-05-0636) + Padelta (2026-05-0596) versendet_am zurückgesetzt (waren Testmodus/fehlgeschlagen)

### Erledigt am 31.05.–01.06.2026 (Heineken WE/AG + Termin-Erinnerungen)
202. ✅ Heineken WE-/AG-Nummern aus Kundenliste (DBO-Export) zugeordnet:
     - 205 eindeutige Outlets gegen 285 Betriebe gematcht (Name + Ort-Abgleich, pg_trgm)
     - 155 Betriebe mit WE/AG ergänzt (vorher 10) — nur eindeutige Treffer automatisch
     - Mehrdeutige/ortsabweichende Fälle bewusst ausgelassen + dem User vorgelegt
     - 3 Spezialfälle manuell bestätigt (Cuntera/Curaglia, Bernina→Pizzeria, Bolgen Plaza)
     - Reine DB-Änderung (keine Code-/App-Änderung)
203. ✅ Termin-Erinnerungen (Popup/Alarm) — neues Feature (v0.10.106):
     - DB-Migration 086: `erinnerung_aktiv` (bool) + `erinnerung_vorlauf_minuten` (int)
     - Pro Termin aktivierbar (Standard aus) + frei wählbare Vorlaufzeit (0 Min–1 Woche)
     - `ReminderService` (Conditional Export): Android = `flutter_local_notifications`
       (echte System-Benachrichtigung, auch bei geschlossener App); Web = Timer-Scheduler
       + Browser-Notification + In-App-Hinweis (kein Push-Server)
     - Zeitpunkt-Berechnung mit Unit-Tests (mit Uhrzeit / 08:00-Bezug ohne Uhrzeit)
     - UI: Toggle + Vorlauf-Dropdown im Termin-Formular, Glocken-Icon im Kalender
     - Anbindung an Termin-save/delete + rescheduleAll beim App-Start
     - Design-Spec + Plan: `docs/superpowers/specs|plans/2026-05-31-termin-erinnerungen*`
     - OFFEN: Android-Funktion mangels Gerät nur via analyze/Build verifiziert (echter Test beim APK-Build)

### Erledigt am 02.06.2026 (Nachversand-PDF, Tourenplanung, Kalender-Saisonlogik)
204. ✅ Nachversand: Rechnungs-PDF wird live neu generiert (Fällig = Versanddatum + 30 Tage,
     Rechnungsdatum bleibt); DB unberührt (Rechnungskontrolle erst ab 01.07. in App).
     `Rechnung.copyWith()` ergänzt (v0.10.107)
205. ✅ Tourenplanung: neue Fälligkeitsstufen relativ zum Rhythmus — bald fällig ab Soll
     (4W), fällig ab Soll+1W (5W), überfällig ab Soll+2W (6W) (v0.10.108)
206. ✅ Kalender: Saison-/Ferien-Vorschläge werden synchronisiert statt nur hinzugefügt —
     veraltete 'vorgeschlagene' Auto-Termine entfernt, neue erstellt; automatisch beim
     Betrieb-Speichern + Button. Bestätigte/manuelle Termine bleiben (v0.10.109)
207. ✅ Kalender: keine Eröffnungsreinigung am Saisonstart, wenn letzte Reinigung eine
     Endreinigung war (service_art='endreinigung' → Anlagen sauber eingelagert). Tour-
     Fälligkeit war bereits korrekt (Saisonstart+4W). 39 veraltete Eröffnungs-Vorschläge
     einmalig bereinigt (v0.10.110)

### Erledigt am 02.06.2026 (Post-Rechnungen)
208. ✅ Bei Rechnungsart "Per Post" wird beim Reinigungs-Abschluss die Rechnung (+ Protokoll)
     per Mail an Daniel (dani.proyer@gmail.com) gesendet — zum Ausdrucken/Postversand.
     Bisher wurde nur bei "Per E-Mail" gemailt (v0.10.111)
209. ✅ Post-Rechnung: versendet_am + zahlungsstatus='gesendet' beim Abschluss (Versandtag =
     Abschlusstag, Zahlungsfrist läuft ab Service). 3 heutige Post-Rechnungen (Spiga,
     Franziskaner, Fondue Beizli) nachträglich gemailt + Versanddatum gesetzt (v0.10.112)

### Erledigt am 01.06.2026 (Datenkorrekturen)
- ✅ Rechnungen Jatzmeder + Milez auf unversendet gesetzt (neue Rechnungsadresse/Mail in Betrieben erfasst; PDF wird beim Nachversand mit aktueller Adresse generiert)

### Temporär aktiv (Stand 02.06.2026)
- **Rechnungs-Nachversand-Screen** bleibt bis zur vollständigen Abarbeitung des Backlogs (ab 18.02.2026), dann entfernen (Datei + Route + Dashboard-Tile).
- **Mail-Scharfstellung:** reinigung ✅ / heineken ✅ / montage ✅ / heigenie ✅ — bestellung & mahnwesen noch im Testmodus.

### Nächste Schritte (Phase 4: Polish & Testing)
1. ☐ Buchhaltung scharfstellen bis 01.07.2026 (Eröffnungsbilanz, Heineken-Buchungen, Zahlungseingänge)
2. ☐ Heineken Monatsrechnung testen (wenn mehr Aufträge erfasst sind)
3. ☐ Heineken Rapport-PDFs Layout-Fehler beheben
4. ☐ Materialbestellung testen (scharfstellen wenn bereit)
   - Edge Function send-rechnung-mail redeployen (bestellungId-Support)
   - MailConfig bestellungScharf auf true setzen
5. ☐ UI/UX Verbesserungen (alle Screens durchgehen)
6. ☐ Beta-Testing mit Daniel (reale Umgebung)
7. ☐ Bug-Fixes
8. ☐ App Store Submissions (iOS + Android)
9. ☐ Performance: Lazy Route Loading, Image Compression, Pagination, select() Columns


---


**Zuletzt aktualisiert**: 02.06.2026 – Nachversand-PDF live; Tourenplanung-Fälligkeitsstufen 4/5/6 Wochen; Kalender Saison-/Ferien-Vorschläge synchronisieren + keine Eröffnungsreinigung nach Endreinigung; Post-Rechnungen werden zum Ausdrucken an Daniel gemailt (versendet_am = Abschlusstag). App-Version 0.10.112+394.
