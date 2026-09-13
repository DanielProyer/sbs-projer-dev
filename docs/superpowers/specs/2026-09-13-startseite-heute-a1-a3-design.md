# Startseite «Heute» + sprechende Zähler + Direktstart (A1–A3) — Design

**Datum:** 13.09.2026 · **Entscheide:** Daniel · **Grundlage:** `docs/app-analyse-2026-09.md` (A1, A2, A3)

## Problem

Die Startseite ist ein Menü, keine Tagesansicht. Die Karte «Keine Einsätze
heute» zählt, was heute **erfasst** wurde, nicht, was heute **ansteht** —
morgens steht dort deshalb immer null. Der tatsächliche Tagesplan liegt zwei
Antippen entfernt hinter der Tourenplanung.

Die Kachelzähler sind Jahrestotale (Betriebe 443, Reinigungen 933, Kontakte
119, Spesen 243). Keine dieser Zahlen verlangt eine Handlung; handlungsrelevant
sind heute nur drei von neunzehn Einstiegen.

Und der häufigste Vorgang hat den längsten Weg: Eine Reinigung anlegen geht
ausschliesslich über Startseite → Reinigungen → + → Betrieb suchen → Formular
— fünf Schritte, davon einer die Suche nach dem Betrieb, in dem man gerade
steht.

## Was die Messung sagt

Die Nutzungsmessung (seit 09.09.2026, Migration 190) stützt die Reihenfolge:

| Route | Aufrufe | Gerät |
|---|---|---|
| `/reinigungen/neu` | 43 | nur Handy |
| `/` | 20 | Handy + PC |
| `/betriebe/:id` | 15 | überwiegend Handy |
| `/reinigungen` | 12 | überwiegend Handy |
| `/touren` | 7 | Handy + PC |

**Vorsicht bei der ersten Zahl:** `/reinigungen/neu` bedient Betriebsauswahl
*und* Formular. Trotz des `didReplace`-Ausschlusses liegen die gemessenen
Aufrufe rund doppelt so hoch wie die Zahl der tatsächlich erfassten
Reinigungen (43 Aufrufe gegenüber gut 20 Vorgängen an denselben drei Tagen).
Die Rangfolge bleibt davon unberührt — die Route führt das Feld auch halbiert
deutlich an.

**Zwei Annahmen aus der Übergabe sind damit widerlegt:**

1. «Die Tourenplanung wurde an keinem Arbeitstag geöffnet» — `/touren` steht
   bei 7 Aufrufen (4 Handy, 3 PC), zuletzt am 13.09.
2. «Es gibt womöglich gar keinen Tagesplan» — in `tagesplaene` liegt für
   **jeden** Arbeitstag ein gespeicherter Plan mit 8–13 Einträgen; der Plan für
   Montag 14.09. stand am Donnerstag um 20:02 mit 10 Stopps bereit.

Punkt 2 ist die Voraussetzung für A1: Die Startseite kann den Tagesplan
anzeigen, ohne dass der Tourenplan-Screen je geöffnet wurde.

## Entscheide

**Kompakte Stopp-Liste, keine Zeitachse** (Variante C von dreien). Die
Zeitachse des Tourenplans hängt an `berechneZeitplanMitIst()` samt
Fahrzeit-Kaskade und steckt in einem 2751-Zeilen-Screen; sie auf die
Startseite zu heben hiesse, sie zu extrahieren oder ein zweites Mal zu
rechnen. Morgens im Auto ist sie ausserdem mehr Information, als die
Entscheidung braucht. Fahrzeiten bleiben dem Tourenplan vorbehalten, der einen
Tipp entfernt ist.

**Alle offenen Stopps, ungekürzt.** Erledigte verschwinden aus der Liste; dass
es sie gab, sagt der Zähler «3 von 10». Die Liste wird im Lauf des Tages
kürzer — morgens steht der ganze Tag da, nachmittags nur noch der Rest. Eine
Kürzung auf die nächsten drei war zwischenzeitlich im Entwurf und wurde
verworfen (Daniel, 13.09.): *«Am Morgen will ich alle offenen Stopps sehen.»*
Genau dann ist die Liste am längsten und am nützlichsten.

Damit bricht die Regel vom 31.07.2026, dass die Startseite ohne Scrollen aufs
Pixel 9 passen muss — bewusst entschieden: Die Kacheln rutschen unter die
Liste und sind mit einem Wisch erreichbar.

**Keine Uhrzeit je Stopp.** Der gespeicherte Tagesplan trägt in `ankerZeit`
fast überall `null` und in `dauerMinuten` ebenfalls — die Uhrzeiten im
Tourenplan entstehen erst in `berechneZeitplanMitIst()`, also genau in der
Zeitachse, die hier bewusst nicht läuft. Die Zeile zeigt deshalb die
**Position im Plan** (1., 2., 3.) und die **Servicezeit des Betriebs**
(`07:30–10:30`), und eine feste Uhrzeit nur dort, wo ein Termin-Anker gesetzt
ist. Eine gerechnete Ankunftszeit auf der Startseite anzuzeigen hiesse, die
Zeitachse doch zu bauen — oder eine Zahl zu erfinden.

**Das Bauteil ersetzt `_TagesUebersicht`, es ergänzt sie nicht.** Zwei
Tageskarten mit verschiedenen Wahrheiten nebeneinander wären genau der
Zustand, den Befund 4 der Analyse beschreibt. Tages- und Monatsumsatz aus der
alten Karte wandern in die Kopfzeile der neuen.

**Erledigt wird abgeleitet, nicht gespeichert.** Kein neues Feld, keine
Migration. Ein Reinigungs-Stopp gilt als erledigt, wenn an diesem Tag eine
Reinigung mit `status = 'abgeschlossen'` existiert, deren Anlage im Bündel des
Stopps liegt; Störung und Montage über ihren jeweiligen Erledigt-Status
(`stoerungOffen` / `montageOffen`, die es schon gibt).

**Direktstart für alle drei Einsatzarten**, an drei Einstiegen: Heute-Liste,
Tourenplan-Block, Betriebsseite. Die Anlagen-Detailseite bleibt aussen vor
(Daniel) — sie ist erreichbar, aber nicht der Weg, den jemand sucht.

## Bauteile

### 1. `HeuteListe` (neu, `presentation/widgets/heute_liste.dart`)

Quelle: `gespeicherterTagesplanProvider(heute)` — der Plan, der ohnehin jeden
Abend geschrieben wird. Kein neuer Provider für die Daten, nur einer für die
Ableitung «offen / erledigt».

Aufbau:

- **Kopfzeile:** `Mo, 14.09. · 3 von 10 · 7 offen`, rechts der Monatsumsatz.
- **Je offener Stopp eine Zeile:** Position · Betrieb · Ort, darunter
  Anlagenzahl und Servicezeit; rechts der Start-Pfeil. Bei einem Stopp mit
  Termin-Anker steht dessen Uhrzeit statt der Position.
- **Fusszeile:** «Im Tourenplan öffnen» — für Reihenfolge, Fahrzeiten und
  alles, was die Liste bewusst nicht zeigt.
- **Tippen auf die Zeile** öffnet den Betrieb, **Tippen auf den Pfeil**
  startet den Einsatz.

**Leerzustand:** Liegt für heute kein Plan vor (Wochenende, oder Montag früh
vor der Planung), steht dort eine Zeile «Kein Tagesplan für heute» mit dem
Knopf «Plan erstellen», der in den Tourenplan führt. Kein leerer Kasten, keine
irreführende Null.

**CanvasKit-Regeln** (CLAUDE.md, drei bestätigte Vorfälle): Zeilen aus
`InkWell` + `Container` + `Row`, Start-Pfeil als `TapKnopf`. Kein `ListTile`,
kein `FilledButton`, kein `ExpansionTile`. Ein unsichtbarer Start-Pfeil auf
der meistgenutzten Seite wäre der teuerste Fehler dieser Änderung — und genau
der Fehlertyp, den weder `flutter analyze` noch die Tests fangen.

### 2. Sprechende Zähler (`_KachelGrid` in `home_screen.dart`)

| Kachel | heute | neu | Quelle |
|---|---|---|---|
| Betriebe | 443 | — | entfällt |
| Reinigungen | 933 | `N diese Woche` | fällige Anlagen mit Fälligkeitsdatum bis zum kommenden Sonntag |
| Störungen | Jahrestotal | `N offen` | `stoerungOffen` |
| Montagen | Jahrestotal | `N geplant` | `montageOffen` |
| Eigenaufträge | Jahrestotal | `N offen` | offener Status |
| Eröffnungen | Jahrestotal | `N anstehend` | anstehende Eröffnungen |
| Kontakte | 119 | — | entfällt |
| Spesen | 243 | — | entfällt |
| Aufgaben | offene | unverändert | — |
| Tourenplanung | `97 fällig` | unverändert | — |

Kacheln ohne Zahl behalten Symbol und Namen. Eine Zahl auf einer Kachel heisst
ab dann: hier wartet Arbeit.

### 3. Direktstart (Router + drei Einstiege)

Die Route `/reinigungen/neu?betriebId=…&anlageId=…` **existiert bereits** und
überspringt die Betriebsauswahl; sie wird heute nur von der Auswahlseite
selbst benutzt. Zu tun ist zweierlei:

1. **Route um gebündelte Anlagen erweitern:** `anlageIds=a,b,c` zusätzlich zum
   bestehenden `anlageId`. Ohne das startet Blue Cinema mit drei Anlagen nur
   mit einer vorausgewählten, und der Rest muss von Hand angehakt werden.
   `anlageId` bleibt gültig (Rückwärtskompatibilität der Auswahlseite).
2. **Drei Einstiege setzen:** Start-Pfeil in der Heute-Liste; Menüpunkt im
   Tourenplan-Block neben «Betriebsseite öffnen»; Knopf auf der Betriebsseite,
   typoffen für alle drei Arten, passend zu den dort vorhandenen Knöpfen für
   Störung und Eigenauftrag.

Für Störung und Montage gilt dasselbe Muster mit ihren eigenen Routen.

## Abgrenzung

- **Keine Zeitachse auf der Startseite** — bleibt im Tourenplan.
- **Keine Fahrzeiten in der Heute-Liste** — dieselbe Begründung.
- **Keine Migration, kein neues Feld.** Erledigt wird abgeleitet.
- **Keine Änderung am Tagesplan-Modell.** Die Liste liest, sie schreibt nicht.
- **A4–A9 und B/C bleiben aussen vor.** Jeder Schritt einzeln lieferbar.

## Tests

- `HeuteListe`: offene/erledigte Ableitung je Einsatzart, Leerzustand ohne
  Plan, Bündel mit mehreren Anlagen, und ein Plan mit 13 Stopps (der grösste
  gemessene Tag) — alle 13 müssen in der Liste stehen, keine Kürzung.
- Router: `anlageIds` mit einer, mehreren und ohne Anlage; `anlageId` weiterhin
  gültig.
- Zähler: je Kachel eine Prüfung, dass die neue Zahl die handlungsrelevante
  Menge zählt und nicht das Jahrestotal.
- **Wächter:** Die Heute-Liste darf keine der drei CanvasKit-Fallen enthalten
  (`ListTile`, `FilledButton`/`OutlinedButton`, `ExpansionTile`) —
  Erweiterung von `test/canvaskit_sichere_widgets_test.dart` auf die neue
  Datei.

## Lieferung

Drei einzeln lieferbare Deploys, jeder für sich am Handy prüfbar:

1. **A2** (kleinster Schnitt, keine neue Datei) — sprechende Zähler.
2. **A3** — Route erweitern, drei Einstiege setzen.
3. **A1** — Heute-Liste, ersetzt `_TagesUebersicht`.

Vor jedem Deploy: `pubspec.yaml` **und** `kAppVersion` bumpen, Build mit
`--pwa-strategy=none`, Cache-Bust, `404.html` mitliefern. Nach A1 und A3 ein
Klicktest am Handy, bevor der nächste Schritt kommt — Screen-Änderungen werden
in dieser App visuell geprüft, nicht nur über `flutter analyze` und Tests.
