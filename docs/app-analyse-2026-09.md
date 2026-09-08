# App-Analyse 08.09.2026 — Übersicht, Bedienbarkeit, Vereinfachung

Stand v0.99.11. Grundlage: der Code selbst (Routen, Screens, Modelle, Provider), die Startseite und der Dokumente-Bereich im Browser, `ToDo.md`, und die Entscheidungen der letzten Wochen aus `Projekt.md`. Keine Vermutungen — jede Zahl unten ist gemessen; wo ich etwas nicht nachprüfen konnte, steht es dabei.

## 0. Vorbemerkung: Alt-App und v2

Diese App ist produktiv und führend; die v2 entsteht im Heineken-Projekt auf derselben Datenbank. Das entscheidet, was hier sinnvoll ist: **Oberfläche, Wege und Ballast** lassen sich hier mit kleinem Aufwand verbessern und wirken sofort im Alltag. **Datenmodell-Umbauten** (Tabellen zusammenlegen, Modelle bereinigen) gehören in die v2 — hier stehen sie nur als Anforderung, damit sie dort nicht vergessen gehen.

## 1. Was die App heute ist — gemessen

| Mass | Wert |
|---|---|
| Routen | 101 |
| Feature-Ordner unter `screens/` | 24 |
| Dart-Dateien (inkl. generiert) | 643, rund 220'000 Zeilen; die 25 grössten handgeschriebenen allein 15'700 |
| Tests | 138 Dateien, 1'356 Tests |
| Einstiege auf der Startseite | 21 (10 Kacheln, 9 Listeneinträge, Diktieren, Glocke) |
| Einsatz-Typen | 6 — Reinigung (55 Felder), Störung (52), Montage (45), Eigenauftrag (30), Eröffnungsreinigung (12), Pikett (20) — jeder mit eigener Liste, eigenem Detail, eigenem Formular |
| Status-Vokabulare dafür | 4 verschiedene |
| Buchhaltung | gut zwei Dutzend Routen, 13 Menüpunkte auf der Buchhaltungs-Startseite |
| Grösster Feature-Ordner | **Events**: 12 Dateien, 8'731 Zeilen — letzte Änderung 24.08.2026, seit Gampel im eigenen Repo liegt |
| Kontakt-Modelle | 3 (`kontakt`, `betrieb_kontakt`, `event_kontakt`) |
| Formular-Screens | 19 — keines schützt vor Datenverlust beim Zurück-Wischen |
| Offene Punkte in ToDo.md | 128, darunter mehrere «Klicktest Daniel (Handy)», die nie stattfanden |

Die App ist keine Service-App mehr, sondern ein vollständiges ERP für eine Ein-Personen-GmbH: Einsatzplanung, Zeiterfassung mit GPS, Spesen-Scanner, Materialwirtschaft, Rechnungsstellung in zwei Welten (Heineken monatlich, eigene Kunden jährlich/bar), Finanzbuchhaltung mit Bankabgleich, MWST, Lohn, Steuern, Dokumentenablage, Jahresabschluss. Das ist eine Leistung — und der Grund, warum die Übersicht leidet.

## 2. Die fünf Befunde, die am meisten kosten

### Befund 1 — Die Startseite ist ein Menü, keine Tagesansicht

Die Karte «Di, 08.09.2026 · Keine Einsätze heute» zählt, was **heute erfasst** wurde (`datum == heute` über sechs Typen), nicht, was **heute ansteht**. Morgens steht dort deshalb immer «Keine Einsätze». Der tatsächliche Tagesplan liegt zwei Antippen entfernt hinter «Tourenplanung».

Die Kachelzähler sind Jahrestotale: Betriebe 443, Reinigungen 933, Kontakte 119, Spesen 243. Keine dieser Zahlen verlangt eine Handlung. Handlungsrelevant sind nur «97 fällig», «Aufgaben», «4 niedrig» — drei von neunzehn.

Die zehn Kacheln wurden bewusst so geschnitten, dass sie aufs Pixel 9 passen (31.07.2026). Das Ziel war richtig, nur der Inhalt ist das Problem: Eine Startseite, die alles zeigt, zeigt nichts.

### Befund 2 — Der häufigste Vorgang hat den längsten Weg

Eine Reinigung anlegen geht ausschliesslich über: **Startseite → Reinigungen → + → Betrieb suchen → Formular.** Fünf Schritte, davon einer die Suche nach dem Betrieb, in dem man gerade steht.

- Der **Tourenplan-Block** bietet «Betriebsseite öffnen», «auf Schätzung zurücksetzen», «War geschlossen», «Aus Plan entfernen» — aber kein «Reinigung beginnen».
- Die **Betriebsseite** listet bestehende Reinigungen, hat aber keinen Knopf für eine neue (für Störungen und Eigenaufträge schon).
- Das **Diktat** — der modernste Einstieg der App: sprechen, KI wertet aus, bestätigen — kann sechs Dinge anlegen: Störung, Montage, Eröffnungs- und Endreinigung (als Termin), Aufgabe, neuen Betrieb. **Keine Reinigung, keine Spesen.** Ausgerechnet die beiden häufigsten Vorgänge.

### Befund 3 — Sechs Einsatz-Typen, vier Status-Sprachen

Für die Arbeit sind Reinigung, Störung, Montage, Eigenauftrag, Eröffnungsreinigung und Pikett dasselbe: ein Einsatz bei einem Betrieb an einem Tag, der Heineken verrechnet wird. Im Code sind es sechs Welten mit vier Vokabularen:

| Typ | Status-Werte, die der Code schreibt | «verrechnet» |
|---|---|---|
| Reinigung | offen · abgeschlossen | eigenes Flag `istAbgerechnet` |
| Störung | offen · in_bearbeitung · behoben | eigenes Flag `abgerechnet` |
| Montage | geplant · in_bearbeitung · abgeschlossen | eigenes Flag `abgerechnet` |
| Eigenauftrag | behoben (einziger Wert) | eigenes Flag `abgerechnet` |

«Fertig» heisst je nach Typ *abgeschlossen* oder *behoben*; «verrechnet» ist nirgends ein Status, sondern überall ein zweites Feld daneben. Die Datenbank erlaubt zusätzlich Werte, die der Code nie schreibt (storniert, nicht_behebbar, abgebrochen, nachbearbeitung_noetig) — und in `anlage_detail_screen.dart` wird eine Störung mit `== 'abgeschlossen'` verglichen, einem Wert, den Störungen nie haben. So etwas fällt in vier Vokabularen nicht auf.

Der Aufgaben-Screen, die Heute-Karte, der Tourenplan und die Heineken-Rechnung bauen die Vereinigung jedes Mal neu — sechs Provider, sechs `where`-Filter, sechs Sonderfälle. Das ist der Grund, warum die «Kette» zwischen Erfassen und Buchen reissen konnte (03./04.09.): Jeder Typ hat seine eigene.

### Befund 4 — Zwei Apps in einer: Werkstatt und Büro

Draussen, einhändig, im Keller: Tourenplan, Reinigung, Störung, Spesen, Material. Drinnen, am PC: Buchhaltung, Rechnungen, Dokumente, Lohn, Steuern, Auswertungen. Beides teilt sich **eine** Startseite, die fürs Handy gebaut ist.

Folge am PC: Die Kacheln werden zu leeren Kästen von 950 × 450 Pixeln — heute im Browser gesehen. Folge am Handy: 13 Buchhaltungs-Türen, von denen man unterwegs keine braucht, liegen gleich neben dem Tourenplan.

Die Buchhaltungs-Startseite zeigt vier Jahres-Kennzahlen (Umsatz, offene Rechnungen, MwSt, Buchungen) und darunter 13 Punkte auf einer Ebene: Kontenplan neben Bankauszug-Import, Jahresrechnungen neben Lohn. Was davon **heute offen** ist — unverbuchte Bank-Transaktionen, Eingangsrechnungen ohne Zahlung, fehlende Heineken-Rechnung vom Vormonat — steht nirgends.

### Befund 5 — Ballast, der Platz und Aufmerksamkeit kostet

- **Events** ist der grösste Ordner der App und steht **zuoberst** in der Liste unter den Kacheln. Gampel läuft seit 14.08. im eigenen Repo, das Event-Technik-Zielmodell liegt im Heineken-Projekt; hier wurde seit 24.08. nichts mehr angefasst.
- **Bergkundenpauschalen** als eigener Menüpunkt: Das ist eine berechnete Grösse (180 CHF je Besuch), keine Arbeit, die man erfasst. Sie gehört in die Heineken-Rechnung, nicht ins Hauptmenü.
- **Anlagen** als eigener Menüpunkt: Eine Anlage erreicht man über ihren Betrieb. Eine globale Anlagenliste ist ein Suchwerkzeug, kein Einstieg.
- **Auswertung Arbeitstage** neben Tourenplanung — das ist eine Buchhaltungs-/Lohnsicht.
- **Reinigungs-Modell**: Von 55 Feldern tauchen mindestens 18 im Formular nie auf — die 13 Kontrollpunkte der Heineken-Servicekarte, beide Unterschriften, die vier Ausstattungs-Flags. Sie werden mitgeschleppt, nie gesetzt, nie gelesen.
- **Drei Kontakt-Modelle** plus Google-Kontakte-Sync plus «Kontakt-Zuweisungen» in den Einstellungen.
- **Einstellungen** mischt Stammdaten (Preise, Biersorten, Regionen), Verbindungen (Google Kalender, Google Kontakte) und Wartung (Speicher aufräumen, Dateien löschen).
- **Tourenplan**: 2'751 Zeilen, acht Icon-Knöpfe verteilt auf Titelleiste, Wochen-Navigator und Tagesplan-Kopf — der dichteste Screen der App.

### Befund 6 — Was die Gegenprobe zusätzlich fand

Ein unabhängiger Prüfer hat die Analyse nach dem Schreiben auf Lücken abgeklopft. Acht Punkte, alle mit Datei und Zeile belegt und stichprobenartig nachgemessen:

1. **Kein Formular schützt vor Datenverlust.** Von 19 Formular-Screens hat keines einen «Änderungen verwerfen?»-Schutz (`PopScope`) — auch nicht das Reinigungsformular mit Fotos, Positionen und Zeiten, auch nicht das Montageformular. Auf dem Pixel 9 mit Gesten-Navigation reicht ein Wischer am Rand, und die ganze Erfassung ist weg. Geschützt sind nur die Steuer-Jahresmaske, das Material-Detail und der Dokument-Upload.
2. **Die häufigste Aktion liegt auf dem unsichersten Widget.** «Reinigung abschliessen» ist ein `FilledButton.icon` — genau der Typ, der auf CanvasKit zweimal nicht reagierte. Störung und Montage schliessen über den sicheren `ArbeitBeendenKnopf` ab: drei Widget-Typen für «Arbeit fertig». In `presentation/` stehen 207 `FilledButton`/`OutlinedButton`; das sichere `TapKnopf` nutzen sieben Dateien. Der Wächter-Test prüft nur `ExpansionTile dense`.
3. **Störung oder Montage erledigen braucht vier Sprünge.** Tourenplan → Detail → Stift → Formular → «Arbeit beenden». Die Detailseite hat nur Stift und Papierkorb, keine Status-Aktion. Und der Tourenplan führt bei einer Reinigung auf die Anlagen-Seite, bei Störung und Montage auf den Einsatz — inkonsistent.
4. **Zwei «Aufgaben»-Listen mit verschiedenem Inhalt.** Die Glocke zeigt die automatischen Erinnerungen (Heineken-Rechnung fällig, MWST-Quartal, Mahnlauf, Saisondaten) plus fällige eigene Aufgaben; die Kachel «Aufgaben» zeigt eigene Aufgaben, offene Störungen, Montagen und Eröffnungen — bewusst ohne die Erinnerungen. Wer die Kachel öffnet, sieht die fällige Heineken-Rechnung nicht; wer die Glocke öffnet, nicht die offenen Störungen.
5. **Die Betrieb-Auswahl ist siebenmal gebaut, mit drei Suchlogiken.** Störung und Reinigung finden nach Name, Ort und Betriebsnummer; Montage, Kontakt und Diktat nach Name und Ort; Eigenauftrag und Eröffnungsreinigung nur nach Name — dort liefert «Chur» nichts.
6. **Spesen: ein Zähler ohne Liste.** Die Kachel zeigt 243 Belege und führt direkt in die Kamera; `/spesen` ist ausschliesslich der Scanner. Ein Beleg von letzter Woche ist nur über das Buchungs-Journal auffindbar.
7. **Ein Bereich, fünf Namen.** Kundenrechnungen heissen «Forderungen» (Menü, Titelleiste), `/rechnungen`, `/buchhaltung/mahnwesen` und `/buchhaltung/debitoren` (Weiterleitungen) — daneben «Jahresrechnungen». Der Screen «Heineken Zuweisungen» heisst je nach Einstieg «Kontakt-Zuweisungen», «Zuweisungen» oder ist ein namenloses Zahnrad. «Google-Termine zuordnen» — eine operative Aufgabe — ist nur über die Einstellungen erreichbar.
8. **Rund 25 Lösch-Dialoge, kein «Rückgängig».** Jedes Löschen fragt vorher — ein Extra-Tap bei jedem Vorgang; ein Snackbar mit Undo böte denselben Schutz ohne Unterbrechung (`SnackBarAction` kommt in der App genau einmal vor). Sieben Detailseiten wiederholen dasselbe Stift+Papierkorb-Paar samt je eigener «Nicht gefunden»-Seite (11 Kopien).

## 3. Vorschläge — nach Wirkung pro Aufwand

### A — klein, sofort, täglich spürbar (je ½ bis 1 Tag)

**A1 · «Heute» statt Menü.** Startseite = Arbeitstag-Karte + der Tagesplan von heute (dieselbe Zeitachse wie im Tourenplan, nur der heutige Tag) + fällige Aufgaben. Die Kacheln rutschen darunter. Morgens sieht Daniel, wohin er fährt, ohne zu tippen.

**A2 · Zähler, die etwas bedeuten.** Reinigungen → «fällig diese Woche»; Störungen → «offen»; Montagen → «geplant»; Eigenaufträge → «offen»; Rechnungen → «überfällig»; Betriebe, Kontakte, Spesen → kein Zähler. Eine Zahl auf einer Kachel soll heissen: hier wartet etwas.

**A3 · «Reinigung beginnen» dort, wo man steht.** Im Tourenplan-Block und auf der Betriebsseite, mit Betrieb und Anlage vorbelegt. Aus fünf Schritten wird einer. Gleiches für Störung im Tourenplan-Block.

**A4 · Diktat für Reinigung und Spesen.** «Alpenblick gereinigt, zwei Hähne, Wasser gewechselt» und «Tanken 84.50 Coop Chur» — dann ist das Mikrofon der eine Erfassungsweg für alles, was draussen passiert. Die Auswertung (`parse-einsatz`) kennt die Betriebe schon.

**A5 · Breite begrenzen am PC.** Inhalt auf 720 px zentrieren — eine Zeile pro Screen (`ConstrainedBox` im Scaffold-Body). Die leeren Kästen verschwinden.

**A6 · Ballast aus dem Hauptmenü.** Events und Bergkundenpauschalen unter «Mehr»; Anlagen nur noch über Betrieb (die Liste bleibt als Suchwerkzeug erreichbar); Auswertung Arbeitstage in die Buchhaltung. Nichts wird gelöscht, nur der Menüplatz wird frei.

**A7 · «Änderungen verwerfen?» in allen 19 Formularen.** ✅ **Erledigt in v0.99.12 (08.09.2026).** Ein gemeinsames Formular-Gerüst mit `PopScope` — einmal gebaut, überall gleich. Ein halber Tag, und die grösste Datenverlust-Falle der App ist zu.

**A8 · «Erledigt» auf den Detailseiten von Störung und Montage.** Dazu führt der Tourenplan-Tap auf den Einsatz statt auf die Anlage. Aus vier Sprüngen werden zwei.

**A9 · Ein Betrieb-Wähler für alle Formulare.** Das Vollbild aus der Reinigung, mit Suche nach Name, Ort und Betriebsnummer. Sieben Kopien werden eine — und «Chur» findet überall.

### B — mittel (2 bis 4 Tage): Struktur, die bleibt

**B1 · Untere Navigationsleiste mit vier Zielen: Heute · Betriebe · Einsätze · Büro.** Von jedem Screen aus erreichbar, einhändig. Heute gibt es keine globale Navigation; jeder Weg ist push und pop, aus der Eingangsrechnung zurück zur Startseite sind es drei Mal «zurück». CanvasKit-sicher bauen (InkWell + Container, nicht `NavigationBar` — dreimal bestätigte Falle).

**B2 · Ein «Einsätze»-Screen für alle sechs Typen.** Typ als Chip-Filter, Betrieb, Datum, Status. **Ein** Status-Vokabular: geplant → in Arbeit → erledigt → verrechnet. Die Tabellen bleiben (das ist v2), nur die Werte werden per Migration abgebildet und die Listen zusammengeführt. Der Aufgaben-Screen wird damit zu einem Filter dieses Screens statt eines eigenen Aggregats.

**B3 · Büro-Startseite = «Was ist offen?»** Oben: unverbuchte Bank-Transaktionen, Eingangsrechnungen ohne Zahlung, Heineken-Rechnung Vormonat fehlt, Mahnungen fällig, MwSt-Quartal fällig — jede Zeile antippbar. Darunter die 13 Punkte in zwei Gruppen: **Laufend** (Bankauszug, Eingangsrechnungen, Forderungen, Heineken-Rechnung) und **Abschluss & Berichte** (der Rest).

**B4 · Monatsabschluss als geführte Checkliste.** Dieselbe Idee wie die Abschlussprüfung (17 Regeln, jährlich), nur monatlich: alle Einsätze des Monats erledigt? Bergkundenpauschalen berechnet? Heineken-Rechnung erzeugt → gesendet → freigegeben? Bank importiert, Prüfliste leer? Genau der Fehlertyp «Kette bricht ab», der am 03./04.09. Ertragsbuchungen kostete, wird damit sichtbar, bevor er teuer wird.

**B5 · Tourenplan entlasten.** Titelleiste auf zwei Knöpfe (Heute, Aktualisieren) plus Überlauf-Menü; Wochen-Navigator und Tages-Chips zu einer Zeile; die Zeitachse bekommt den Platz.

**B6 · Ein Aufgaben-Begriff.** Glocke und Kachel speisen sich aus derselben Quelle; Erinnerungen und offene Einsätze stehen in einer Liste, nach Fälligkeit sortiert. Was heute «bewusst getrennt» ist, war für die Glocke richtig gedacht und für die Kachel falsch.

**B7 · Ein «Arbeit beenden»-Widget für alle Typen** plus ein Wächter-Test, der `FilledButton` in kritischen Aktionen abbricht. Die Regel aus CLAUDE.md wird damit erzwungen statt erinnert.

Dazu, ohne eigene Nummer: eine Spesen-Liste hinter dem Zähler; ein Name für Forderungen/Rechnungen/Mahnwesen; Undo-Snackbar statt Lösch-Dialog; ein gemeinsames Detail-Gerüst statt elf «Nicht gefunden»-Kopien.

### C — gross, gehört in die v2 (hier nur als Anforderung)

- **C1** Ein Einsatz-Modell mit Typ statt sechs Tabellen. Gemeinsame Felder sind heute schon identisch: Betrieb, Anlage, Datum, Referenz-Nr., Preisliste, Abrechnungsmonat, abgerechnet, Bergkunde, Notizen.
- **C2** Ein Kontakt-Modell mit Rollen (Betrieb, Event, privat) statt drei.
- **C3** Reinigung auf die Felder reduzieren, die das Formular schreibt. Die Servicekarte ist ein PDF, kein Datenmodell.
- **C4** Einstellungen in Stammdaten / Verbindungen / Wartung.
- **C5** Navigation mit `context.go` an den Haupteinstiegen, damit die Adresszeile die Route zeigt (heute 139 × `context.push` gegen 5 × `context.go`; die URL bleibt beim Navigieren stehen).

## 4. Was ich nicht vorschlage

- **Keine Neuentwicklung hier.** Die v2 existiert; jeder grosse Umbau in der Alt-App wäre doppelt.
- **Keine Tabellen zusammenlegen** in der Alt-App — Migrationen auf produktiven Daten für etwas, das die v2 ohnehin neu schneidet.
- **Nichts entfernen, was verrechnet wird.** Bergkundenpauschalen bleiben Logik; sie verlieren nur den Menüplatz.
- **Kein Redesign der Optik.** Das Material-3-Grün ist in Ordnung; das Problem sind Wege und Dichte, nicht Farben.

## 5. Zuerst messen: ein Nutzungszähler

Bevor irgendetwas fliegt, sollte eine Zahl da sein: **Welche Route wird wie oft geöffnet?** Ein Zähler im Router (Route → Aufrufe, lokal gespeichert, vier Wochen), dann eine Liste. Das sind 30 Zeilen Code und macht aus «ich glaube, Anlagen braucht niemand» eine Tatsache. Alles in A6 und B2 wird damit entscheidbar statt Geschmackssache.

## 6. Reihenfolge, wenn alles gilt

1. **Zuerst, noch diese Woche:** A7 — der Datenverlust-Schutz. Er kostet einen halben Tag und beendet die eine Falle, die jeden Tag zuschlagen kann.
2. **Diese Woche:** Nutzungszähler, dann A1, A2, A3, A8, A5, A6 — kleine Deploys, jeder für sich prüfbar am Handy.
3. **Nächste zwei Wochen:** B1 (Navigationsleiste), B2 (Einsätze + Status), B6 (ein Aufgaben-Begriff). B2 ist der grösste Hebel für Übersicht und der beste Vorlauf für die v2.
4. **Danach nach Bedarf:** A4 (Diktat), A9 (Betrieb-Wähler), B3/B4 (Büro), B5 (Tourenplan), B7 (Widget + Wächter).
5. **C** ins v2-Backlog, mit Verweis auf dieses Dokument.

Jeder Schritt ist einzeln lieferbar und einzeln rücknehmbar. Keiner setzt einen anderen voraus — ausser B2, das A2 sinnvoll macht.

## 7. Prüfung

Nach dem Schreiben haben elf unabhängige Prüfer 22 messbare Behauptungen dieses Dokuments im Code zu widerlegen versucht. 19 hielten stand, drei wurden korrigiert und sind oben eingearbeitet: die Status-Werte (*abgerechnet* ist überall ein Flag, kein Status), die Diktat-Arten (sechs statt vier) und die Zahl der `push`-Aufrufe (139 statt 144). Ein zwölfter Prüfer suchte nach Lücken und fand acht — sie stehen als Befund 6 und in den Vorschlägen A7–A9 und B6–B7; die vier gewichtigen habe ich selbst nachgemessen.

Ein Punkt, der nicht im Dokument stand, kam dabei ans Licht: Die Heineken-Monatsrechnung grenzt ihre sieben Quellen **ausschliesslich über den Datumsbereich** ab. `abgerechnet` wird erst nach dem Erstellen gesetzt und nirgends als Filter gelesen. Wer eine Monatsrechnung neu erzeugt, bekommt alles im Datumsbereich — auch nachträglich Erfasstes; einen Zähler «noch nicht verrechnet» gibt es nicht. Genau den bräuchte die Checkliste aus B4.
