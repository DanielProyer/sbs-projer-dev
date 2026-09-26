# Analyse-Runde 5 «Tagesbetrieb» — v0.144.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Der Alltag draussen wird kürzer und verliert nichts mehr: Start aus Heute/Tourenplan öffnet den richtigen Einsatz und bringt Service-Art und Diktat mit, eine angefangene Reinigung überlebt Tab-Verlust als Entwurf, die Zahlungsart steht vorbelegt im Formular (Dialog nur noch, wenn nötig), die Heute-Karte zeigt nur, was draussen zu tun ist, die Glocke meldet halbe Zustände, die Betriebsseite zeigt Geld und alle Einsätze, versteckte Screens bekommen einen Eingang, und die schwersten Ladevorgänge werden schlanker.

**Quelle:** `docs/analyse-2026-09-25/4-tagesbetrieb.md` §5 (V2, V3, V4, V6, V8, V9, V10), `docs/app-analyse-2026-09-25.md` §4 (T2–T4, T7–T11) und §5 Q6, `1-screens-navigation.md` §4 Nr. 5/12. Nutzung 09.–25.09.: `/reinigungen/neu` 111× am Handy bei 73 Reinigungen (≈ 23 Abbrüche), 82 % der Abschlüsse übernehmen die Zahlungsart-Vorgabe, 36 Saison-Reinigungen mit von Hand umgestellter Service-Art.

**Schon erledigt (Runden 2/4):** Foto sofort hochladen (V1), Formular entrümpelt + TapKnopf (V5), Pausenprüfung nach der Kette (V7), Formular-Bausteine (V11).

**Nicht in dieser Runde (Entscheid Daniel offen):** «Erst geplant»/«Arbeit beginnen» bei Störung/Montage einklappen, falls Störungen nie vorausgeplant werden; Events aus «Mehr» ausblenden; Isar einfrieren. Tourenplan-Datei aufteilen (V12) und serverseitiger Abschluss (V13) bleiben für später bzw. die v2.

**Regeln:** `CLAUDE.md` (CanvasKit: `TapKnopf`/`gefahrRueckfrage`, Ratsche `test/canvaskit_ratsche_test.dart` darf nur sinken; Pagination `.order('id')`; NULL-Falle; `zeigeDatumsauswahl`/`zeigeZeitauswahl`), App `sbs_projer_app/`, `export PATH="$PATH:/c/flutter/bin"`, kein `git stash`, **kein `dart format`**, Commits enden mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Task `flutter test` grün (Stand 2415), `flutter analyze` ≤ 14. UI-Änderungen vor dem Deploy im Browser (Controller). Mahnwesen bleibt im Testmodus.

---

### Task 1: Ein Start-Weg — richtiger Einsatz, Service-Art, Diktat-Notiz (V3, V4, V10) — Opus

**Files:** Create `lib/core/util/einsatz_start.dart` (reine Routenbildung) + `test/einsatz_start_test.dart`; Modify `lib/presentation/widgets/heute_liste.dart` (`_starte` ~Z. 434), `lib/presentation/screens/touren/tourenplanung_screen.dart` (Start im Block-Sheet ~Z. 1860–1910), Betriebsseite (Start-Stelle per grep), `lib/core/config/router.dart` (`/reinigungen/neu` ~Z. 326), `lib/presentation/screens/reinigungen/reinigung_form_screen.dart` (neue Parameter), `lib/presentation/widgets/diktat_sheet.dart` (~Z. 290–320).

- [ ] **Reine Funktion** `String startRoute(TourEintrag e, {String? notiz})` in `einsatz_start.dart`:
  - Reinigung: `/reinigungen/neu?betriebId=…&anlageIds=…` + `&serviceArt=eroeffnungsservice` bzw. `endreinigung`, wenn der Eintrag aus einer Saison-Fälligkeit kommt (Feld am `TourEintrag` lesen — grep `faelligkeit`/`saison` in `core/util/tour*.dart`; Werte der Service-Art aus dem Formular-Dropdown übernehmen) + `&notiz=<uri-kodiert>`, wenn gegeben.
  - Störung/Montage **mit geplantem Einsatz** (`e.id` beginnt mit `s_`/`m_` bzw. es gibt eine Einsatz-ID — Muster in `heute_providers.dart` lesen): `/stoerungen/<id>/bearbeiten` bzw. `/montagen/<id>/bearbeiten` (dort ist «Arbeit beginnen»). Ohne geplanten Einsatz wie bisher `/…/neu?betriebId=…`.
  - Tests: je Fall die erwartete Route (Reinigung mit/ohne Saison, mit Notiz inkl. Umlaut/Leerzeichen kodiert; Störung geplant → bearbeiten; Störung ohne ID → neu; Montage/HeiGenie analog).
- [ ] Heute, Tourenplan und Betriebsseite rufen nur noch `context.push(startRoute(e))` (Wächter `test/einsatz_start_waechter_test.dart`: `'/stoerungen/neu?betriebId=` und `'/reinigungen/neu?betriebId=` kommen nur noch in `einsatz_start.dart` vor — Ausnahmen namentlich, falls ein Screen ohne `TourEintrag` startet, z. B. «+»-Menüs).
- [ ] Router `/reinigungen/neu`: Query `serviceArt` und `notiz` an `ReinigungFormScreen(serviceArt:, notiz:)` durchreichen; das Formular belegt `_serviceArt` bzw. den Notizen-Controller damit vor (nur bei neuer Reinigung, nur wenn gültiger Wert).
- [ ] Diktat (`diktat_sheet.dart` ~Z. 297–313): beim Reinigungs-Ziel die Notiz über `startRoute(..., notiz: text)` bzw. `&notiz=` mitgeben statt nur als Snackbar; steht der Betrieb im heutigen Tagesplan, dessen Anlagen mitgeben (Provider des Tagesplans lesen).
- [ ] Tests, analyze. **Commit** `feat(heute): ein Start-Weg — geplanten Einsatz oeffnen, Service-Art und Diktat-Notiz mitgeben (V3/V4/V10)`.

### Task 2: Entwurf der laufenden Reinigung (V2/T2) — Opus

**Files:** Create `lib/core/util/reinigung_entwurf.dart` (Modell + JSON, rein) und `lib/services/storage/reinigung_entwurf_speicher.dart` (`shared_preferences`, im pubspec vorhanden) + Tests; Modify `reinigung_form_screen.dart`.

- [ ] Modell `ReinigungEntwurf` (betriebId, anlageIds, datum, uhrzeitStart, serviceArt, serviceTyp, Hähne-Zähler, istKulanz, istBergkunde, notizen, protokollFotoPfad (seit Runde 2 sofort hochgeladen), fotoReinigungId, zahlungsart (nach Task 3), gespeichertAm) mit `toJson/fromJson` (robust gegen fehlende Felder) — rein, getestet.
- [ ] Speicher: ein Entwurf je Betrieb (`Schlüssel entwurf_reinigung_<betriebId>`), `speichern`, `laden`, `loeschen`, `alleOffen()`; Entwürfe älter als 2 Tage beim Laden verwerfen. Jeder Zugriff in try/catch (Privat-Modus, leerer Speicher) — Formular funktioniert ohne.
- [ ] Formular (nur **neue** Reinigung, nicht Bearbeiten): bei jeder Änderung (dort, wo `markiereGeaendert()` aufgerufen wird) den Entwurf gedrosselt (≥ 2 s Abstand) speichern; beim Öffnen mit gleichem `betriebId` und Entwurf von heute oben ein Band «Angefangene Reinigung von 09:12 — Fortsetzen / Verwerfen» (TapKnopf; Verwerfen über `gefahrRueckfrage`); Fortsetzen belegt alle Felder und das Foto (Pfad → «Hochgeladen ✓», Vorschau über signierte URL, falls vorhanden — sonst nur Hinweis). Die vorab erzeugte `_fotoReinigungId` aus dem Entwurf übernehmen (derselbe Ordner). Nach erfolgreichem Abschluss/Speichern Entwurf löschen.
- [ ] Glocke/Aufgabe (Task 4 greift darauf zu): `ReinigungEntwurfSpeicher.alleOffen()` liefert Betrieb + Zeit.
- [ ] Tests (Modell, Ablaufregel 2 Tage), analyze. **Commit** `feat(reinigungen): angefangene Reinigung als Entwurf sichern und fortsetzen (V2)`.

### Task 3: Zahlungsart im Formular, Dialog nur wenn nötig (V6/T3) — Opus

**Files:** `reinigung_form_screen.dart` (`_showAbschlussDialog` ~Z. 1377, `_abschlussDialogFlow` ~Z. 1399–1670), Create `lib/core/util/abschluss_dialog_regel.dart` + Test.

- [ ] **Reine Regel** `AbschlussDialogGrund? abschlussDialogNoetig({required String gewaehlt, required String? vorgabeBetrieb, required String? kundenEmail, required String? serviceHinweis})` → Gründe: `mailOhneAdresse` (gewählt = rechnung_mail und keine Kunden-E-Mail), `serviceHinweis` (Betrieb hat Hinweis, der beim Abschluss erscheinen soll — heutige Anzeige im Dialog lesen), `abweichung` (gewählt ≠ Vorgabe → Frage «als Vorgabe speichern?»). `null` = direkt abschliessen. Tests für alle Kombinationen.
- [ ] Formular: kompakte Zeile «Zahlungsart: <Klartext> ›» direkt unter der Betrieb-Karte (InkWell → Auswahl-Sheet mit den 6 Arten, bestehende Klartexte `zahlungsartKlartext`), vorbelegt wie heute im Dialog (`resolveZahlungsart` mit frisch geladenem Betrieb). Änderung markiert das Formular.
- [ ] «Reinigung abschliessen»: Betrieb frisch laden + Kunden-E-Mail laden (wie heute), Regel fragen; bei `null` direkt `_save(abschliessen: true)`; sonst den **bestehenden** Dialog zeigen, aber nur mit dem nötigen Teil (E-Mail-Feld bei `mailOhneAdresse`, Hinweis, Checkbox «als Vorgabe» bei `abweichung`) — keine zweite Zahlungsart-Auswahl mehr im Dialog. Doppeltipp-Sperre wie bisher.
- [ ] Kulanz/Heineken-Monteur: Zeile ausblenden, Verhalten wie bisher.
- [ ] Tests, analyze, Wächter `test/zahlungsart_formular_waechter_test.dart` (Formular enthält `abschlussDialogNoetig(`). **Commit** `feat(reinigungen): Zahlungsart im Formular, Abschluss-Dialog nur wenn noetig (V6)`.

### Task 4: Heute-Karte nur für draussen, Glocke ergänzt (V8, V9/T7, T8) — Opus

**Files:** `lib/core/util/aufgaben_regeln.dart` (Klasse `Aufgabe`), `lib/core/util/aufgabe.dart`, `lib/presentation/providers/aufgaben_detektoren_provider.dart`, die Heute-Seite (grep `AufgabenKarte`/Aufgaben-Widget auf der Startseite), Tests `test/aufgaben_regeln_test.dart`, `test/aufgaben_inhalt_test.dart`.

- [ ] `Aufgabe` bekommt `final bool draussen;` (default false). `true` für: Einsätze (Störung/Montage/Eigenauftrag/Termin heute/überfällig), Saison-Vorschläge/-Termine am Tag, eigene Aufgaben, Entwürfe (neu), laufende Arbeit (neu). `false` (Büro): Heineken, MWST, Mahnlauf, Eskalation, Mahnfälle, Änderungsvorschläge, alle Vorräte.
- [ ] **Saison-Zähler** («Saisondaten fehlen», «Saison-Lücke») → `istVorrat: true` (Band im Formular und Tourenplan-Warnung bleiben die richtigen Orte).
- [ ] Heute-Karte zeigt nur `draussen`; die Glocke zeigt weiterhin alles mit Frist; Büro-Startseite (B3) unverändert alles.
- [ ] **Neue Detektoren (draussen):** (a) angefangene Reinigungen aus `ReinigungEntwurfSpeicher.alleOffen()` (Task 2) «Reinigung <Betrieb> angefangen (09:12)» → Route `startRoute`/`/reinigungen/neu?betriebId=`; (b) laufende Arbeit von gestern: Störung/Montage mit `arbeit_von` gesetzt, `arbeit_bis` leer, Datum < heute (**NULL-Falle**: `isFilter('arbeit_bis', null)`, kein `.neq`) → Route bearbeiten; (c) Arbeitstag gestern ohne Ende/km (Tabelle des Arbeitstags per grep `arbeitstag` finden; nur wenn Felder existieren); (d) Diktat-Entwürfe in der Warteschlange (Speicherort in `diktat_sheet.dart` ~Z. 137 lesen; nur wenn lokal abfragbar).
- [ ] **Versandvermerk-Detektor N+1** (~Z. 116–150): die bis zu 500 Einzelabfragen durch **eine** Abfrage ersetzen (Reinigungen `zahlungsart = rechnung_mail` im 60-Tage-Fenster mit `betrieb_id, datum` laden, in Dart gegen die Rechnungen matchen), Pagination `.order('id')`.
- [ ] Tests (Einordnung je Aufgabe, neue Regeln), analyze, `aufgaben_eine_quelle_waechter` grün. **Commit** `feat(aufgaben): Heute-Karte nur fuer draussen, Glocke meldet angefangene/laufende Arbeit, Versandvermerk ohne N+1 (V8/V9)`.

### Task 5: Betriebsseite als Akte (T10) — Opus

**Files:** `lib/presentation/screens/betriebe/betrieb_detail_screen.dart` (Einsatz-Sektionen ~Z. 1280–1830 laut Bericht, per grep bestätigen), `lib/core/util/einsatz.dart` (`EinsatzZeile`, Filter), Create `lib/presentation/widgets/betrieb/betrieb_geld_block.dart` + Tests.

- [ ] **Geld-Block** oben (nach Adresse/Kontakt): offener Saldo (Summe «zu zahlen» der offenen Kunden-/Jahresrechnungen, `istZahlbar`), höchste Mahnstufe, Kundenguthaben (2030, `GuthabenRepository.offenesGuthaben`), Anzahl offene Rechnungen → Tap öffnet `/rechnungen?betrieb=<id>` bzw. die vorhandene Rechnungsliste je Betrieb (Route per grep). Reine Funktion `betriebGeldStand(rechnungen, guthaben)` getestet. Nur Web; Ladefehler zeigt «nicht geladen», nie eine falsche Null.
- [ ] **Eine «Einsätze»-Sektion** statt der getrennten Reinigung-/Störung-/Eigenauftrag-Listen: alle Typen inkl. **Montage** (fehlte), Eröffnung, Pikett soweit betriebsbezogen, neueste zuerst, 10 Einträge + «alle anzeigen» → `/einsaetze?betrieb=<id>` (Filter in `einsatz.dart`/Einsätze-Screen ergänzen, falls nicht vorhanden), «+»-Typwahl wie auf Einsätze. Mit `EinsatzZeile`.
- [ ] Anlagenseite: gleiche Sektion gefiltert auf die Anlage, wenn ohne grossen Umbau möglich (sonst ToDo-Notiz).
- [ ] Tests, analyze. **Commit** `feat(betriebe): Betriebsseite als Akte — Geld-Block und eine Einsaetze-Sektion inkl. Montagen (T10)`.

### Task 6: Umwege schliessen (T11) — Sonnet

**Files:** `lib/core/navigation/bereiche.dart` (Mehr-Einträge, per grep), `lib/presentation/screens/betriebe/betriebe_list_screen.dart`, `lib/presentation/screens/buchhaltung/lohnlauf_screen.dart`, Suche (`kSuchZusatzZiele`, grep), `lib/core/config/router.dart`, `tourenplanung_screen.dart` (~Z. 346 Tages-Karte).

- [ ] Betriebe-Liste: Zeile «Änderungsvorschläge (<n>)» oben, nur wenn n > 0 → bestehende Route.
- [ ] «Google-Termine zuordnen» als Eintrag in Mehr → Unterwegs (Route existiert).
- [ ] Lohnlauf: Link «Sätze» → `/buchhaltung/lohn/einstellungen` (Route per grep bestätigen).
- [ ] Suche: Bergkundenpauschalen und Anlagen als Zusatzziele.
- [ ] Tages-Karte als echte Route `/touren/karte` (gezählt, verlinkbar); der bisherige `Navigator.push` im Tourenplan nutzt die Route.
- [ ] Doppel-Einstiege: Karte «Pro Betrieb» in der Rechnungsliste entfernen, wenn der Reiter denselben Screen öffnet (prüfen).
- [ ] Tests (bestehende Navigations-/Suche-Tests anpassen), analyze. **Commit** `feat(navigation): Umwege geschlossen — Vorschlaege, Google-Termine, Lohn-Saetze, Suche, Tages-Karte als Route (T11)`.

### Task 7: Ladeverhalten (Q6) — Opus

**Files:** `lib/presentation/providers/buchhaltung_providers.dart`, Dashboard-/Heute-Provider (grep), `lib/data/repositories/rechnung_repository.dart`, `reinigung_repository.dart`.

- [ ] **Dashboard/Kennzahl «offene Rechnungen»:** `RechnungRepository.countOffene()` (in Runde 4 als tot gelöscht — neu, mit `count: CountOption.exact` über `istZahlbar`-Status und `rechnungstyp in (kundenrechnung, jahresrechnung)`) statt aller 5'278 Zeilen.
- [ ] **Bilanz / Erfolgsrechnung / ER-Konten** aus **einem** `buchungenStreamProvider.future` statt 3× `BuchungRepository.getAll()` (D11); das «Watch als Neuberechnen-Signal» durch einen schlanken Versionszähler-Provider ersetzen, wo nur das Signal gebraucht wird.
- [ ] **Heute:** wird für «heute gereinigte Anlagen» die ganze Reinigungstabelle (8'695) geladen? → gezielte Abfrage nur für heute (bzw. die letzten N Tage, die der Provider wirklich braucht) — vorher lesen, welche Felder/Zeiträume die Heute-Provider nutzen; Verhalten gleich.
- [ ] `autoDispose` für grosse Family-Provider, die nur auf einem Screen gebraucht werden (Liste im Commit); nicht für Provider, die zwischen Screens geteilt werden.
- [ ] Messung vorher/nachher im Commit (Anzahl geladener Zeilen je Screen, aus Code abgeleitet). Tests, analyze. **Commit** `perf: schlankere Ladewege — countOffene, ein Buchungs-Load fuer Berichte, Heute gezielt (Q6)`.

### Task 8: Browser-Prüfung, Release v0.144.0 — Controller

- [ ] Lokaler Build; prüfen: Heute → Start einer Reinigung (Service-Art bei Saison-Eintrag vorbelegt), Diktat → Reinigung (Notiz steht drin), Reinigungsformular: Zahlungsart-Zeile, Abschluss ohne Dialog bei Vorgabe (nur ansehen bis vor dem Abschluss — **nichts abschliessen**, oder Kulanz-Testreinigung wie in Runde 2 und danach löschen), Entwurf: Formular füllen → Tab neu laden → Band «fortsetzen» → verwerfen; Heute-Karte ohne Büro-Aufgaben, Glocke vollständig; Betriebsseite (Geld-Block, Einsätze inkl. Montage); Betriebe-Liste, Mehr, Suche; Buchhaltung → Berichte laden (Ladezeit subjektiv, Konsole). 360 px für Formular und Heute.
- [ ] Version `0.144.0+797`; Chronik, ToDo (Stand, Klicktests, offene Entscheide: Planung einklappen?, Events?, Isar?), Projekt.md, Analyse §6 Runde 5 ✅ (alle fünf Runden erledigt), Memory.
- [ ] Commit, Push, Deploy, Live-Version prüfen.

---

## Reihenfolge und Parallelität (Controller)

1 → (2 ∥ 4 ∥ 5) → 3 → 6 → 7 → Review → 8. Task 2 und 3 ändern beide das Reinigungsformular (nacheinander); Task 4 liest Task 2s Speicher (Schnittstelle vorab festgelegt: `ReinigungEntwurfSpeicher.alleOffen()` → `List<({String betriebId, DateTime gespeichertAm})>`); Task 1 und 6 ändern beide `router.dart`/Tourenplan (nacheinander). Parallel laufende Agenten committen nur ihre eigenen Dateien.

## Selbstprüfung

- Abdeckung: T2 (2), T3 (3), T4 (1), T7 (4), T8 (4), T9 (1), T10 (5), T11 (6), Q6 (7), V3 (1). Offen mit Grund: Planung einklappen, Events (T12), Isar, V12, V13.
- Namen: `startRoute`, `ReinigungEntwurf`, `ReinigungEntwurfSpeicher.alleOffen`, `abschlussDialogNoetig`/`AbschlussDialogGrund`, `Aufgabe.draussen`, `betriebGeldStand`, `countOffene`.
