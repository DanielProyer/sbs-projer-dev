# Navigation «Mehr» und Neuordnung der Bereiche — Design

**Datum:** 22.09.2026 · **Stand der App:** v0.130.0 · **Teil 1 von 3**

## Ziel

Möglichst alles soll sich am Smartphone erledigen lassen. Heute ist alles,
was unterhalb der Heute-Liste steht, schlecht erreichbar: die drei Kacheln
(Aufgaben, Spesen, Material) und die «Weitere»-Liste (Kontakte, Events,
Buchhaltung, Dokumente, Pikett, Anlagen, Bergkundenpauschalen,
Einstellungen). Je länger der Tagesplan ist, desto weiter rutschen diese
Einträge nach unten. Das Büro liegt zudem gebündelt hinter «Buchhaltung»,
mit 16 Einträgen und den Rechnungen zwei Stufen tief.

Dieser Teil ordnet die **Navigation** und den **Zuschnitt der Bereiche**
neu. Es wird kein bestehender Screen neu geschrieben.

### Die drei Teile

1. **Navigation und Ordnung** — dieses Dokument.
2. **Suche:** eine Lupe in jeder Kopfzeile, die Betriebe, Personen,
   Rechnungsnummern und Screens findet. Das bekommt ein eigenes Design.
3. **Büro handytauglich:** Die Büro-Screens werden einzeln bei 360 px
   durchgesehen. Priorisiert wird nach der Nutzungsmessung, nachdem Teil 1
   zwei Wochen im Einsatz ist.

## Ausgangslage (Nutzungsmessung 09.–22.09.2026)

| Route | Handy | PC |
|---|---|---|
| `/reinigungen/neu` | 90 | 2 |
| `/` | 40 | 75 |
| `/betriebe/:id` | 39 | 40 |
| `/touren` | 12 | 57 |
| `/betriebe` | 10 | 36 |
| `/buchhaltung` | 2 | 25 |
| `/rechnungen` + `/rechnungen/:id` | 0 | 26 |
| Störungen + Montagen (alle) | 25 | 9 |
| `/spesen` · `/materialien` | 6 · 3 | 0 · 0 |
| `/kontakte`, `/events`, `/dokumente`, `/anlagen`, `/bergkundenpauschalen` | 0–1 | 0–2 |

Am PC wird die Startseite als Menü benutzt (75 Aufrufe), weil die Leiste
dort keinen Weg ins Büro bietet. Kontakte werden nie über die eigene Liste
geöffnet, Betriebe dagegen ständig.

## 1. Leiste, Heute und Mehr

### Untere Leiste

**Heute · Einsätze · Betriebe · Tour · Mehr**

- Die vier bisherigen Ziele bleiben an ihrem Platz, **Mehr** kommt rechts
  dazu (`NavZiel.mehr`, Pfad `/mehr`, Symbol `Icons.apps`).
- Welches Ziel leuchtet: wie bisher für die vier ersten Ziele und die
  Einsatz-Präfixe; `/kontakte` gehört zu **Betriebe**. **Jeder andere Pfad
  leuchtet «Mehr»**, statt dass gar nichts leuchtet (bisher `null`).
- Die Leiste bleibt in Formularen ausgeblendet (`zeigtNavigation`
  unverändert).

### Heute

Von oben nach unten:

1. **Event-Karte**, nur wenn ein Event des laufenden Jahres im Fenster liegt:
   ab `termin_von − 7 Tage` bis `termin_bis` (Ende einschliesslich). Ohne
   `termin_von` erscheint keine Karte. Inhalt: Betriebsname, Zeitraum,
   Antippen öffnet `/events/:id`. Bei mehreren Events eine Karte je Event.
2. Aufgaben-Karte (unverändert)
3. Arbeitstag-Karte (unverändert)
4. Heute-Liste (unverändert)
5. Schwebender Knopf «Diktieren» (unverändert)

**Entfernt** werden `_KachelGrid`, `_WeitereSection` und das
Abmelden-Symbol in der Kopfzeile. Das Abmelden sass neben der
Sync-Anzeige; ein Fehltipp meldete unterwegs ab. Es zieht in die
Einstellungen um. «Sync erzwingen» (nur nativ) zieht ebenfalls in die
Einstellungen.

### Mehr

Eine Seite in drei Gruppen, auf dem Pixel 9 ohne Scrollen:

| Gruppe | Einträge |
|---|---|
| **Unterwegs** (4 Kacheln) | Spesen · Material (Zähler «N niedrig») · Aufgaben (Zähler = Glocken-Badge) · Events |
| **Büro** (6 Zeilen) | Rechnungen · Bank und Zahlungen · Buchhaltung · Lohn · Abschlüsse und Steuern · Dokumente |
| **Einrichtung** (3 Zeilen) | Auswertungen · Stammdaten · Einstellungen |

**Zähler an den Büro-Zeilen:** Sie kommen aus den bestehenden
Aufgaben-Detektoren (`aufgabenListeProvider`), nicht aus neuer Logik. Jeder
Detektor trägt ein Ziel-Bereich-Feld. Zu welchem Bereich ein Detektor
gehört, entscheidet sein Sprungziel (Präfix-Zuordnung, siehe Abschnitt 3).
Ein Bereich ohne offene Einträge zeigt keinen Zähler.

## 2. Die Bereiche

### Rechnungen (neu)

Umschalter oben (`BereichReiter`): **Kunden · Heineken · Pro Betrieb ·
Jahresrechnungen**

| Reiter | Screen (bestehend) | Route |
|---|---|---|
| Kunden | Forderungen (offene Posten, Debitoren, alle Rechnungen) | `/rechnungen` |
| Heineken | Heineken-Monatsrechnungen | `/heineken` |
| Pro Betrieb | Offen pro Betrieb | `/rechnungen/pro-betrieb` |
| Jahresrechnungen | Sammelrechnungen erstellen | `/jahresrechnung` |

- Das Mahnwesen (`/buchhaltung/mahnwesen`) bleibt über die Kunden-Seite
  erreichbar, wie heute.
- Die **Bergkundenpauschalen** stehen als eigene Zeile oben im
  Heineken-Reiter (Route `/bergkundenpauschalen` bleibt).

### Aufteilung der heutigen Buchhaltung

| Bereich | Route | Einträge |
|---|---|---|
| **Bank und Zahlungen** | `/bank` (neu) | Bankauszug Import · Eingangsrechnungen |
| **Buchhaltung** | `/buchhaltung` (verkleinert) | Kennzahlen oben · Kontenplan · Journal · Bilanz und Erfolgsrechnung |
| **Lohn** | `/buchhaltung/lohn` (bestehend, direkt) | Lohnlauf · Lohnausweis |
| **Abschlüsse und Steuern** | `/abschluesse` (neu) | Monatsabschluss · MwSt-Abrechnung · Abschlussprüfung · Steuern |

- Der Block **«Was ist offen?»** (`BueroOffenBlock`) entfällt in der
  Buchhaltung. Seine Einträge stehen in der Glocke und als Zähler auf Mehr.
- Die Kennzahl-Kachel «Offene Rechnungen» in der Buchhaltung führt nach
  `/rechnungen`.

### Betriebe | Personen

- Die Betriebe-Liste bekommt oben den Umschalter **Betriebe | Personen**.
- «Personen» ist die bestehende Kontaktliste mit einem Filter nach
  `kategorie` (Betrieb · Heineken · Event · Alle, Vorgabe Alle).
- `/kontakte` bleibt die Route der Personen-Ansicht; in der Leiste leuchtet
  «Betriebe».

### Stammdaten (neu, `/stammdaten`)

Firma (Geschäftsdaten) · MWST-Sätze · Preise · Biersorten · Regionen ·
Heineken-Zuweisungen · Lohnsätze · Anlagen (`/anlagen`)

Die Abschnitte werden aus `einstellungen_screen.dart` herausgelöst. Die
Unterseiten (`/einstellungen/preise/…`, `/einstellungen/biersorten`,
`/einstellungen/regionen`, `/heineken/zuweisungen`,
`/buchhaltung/lohn/einstellungen`) behalten ihre Routen.

### Einstellungen (verkleinert, `/einstellungen`)

Google Kalender · Google Kontakte · Speicher aufräumen · Sync erzwingen (nur
nativ) · Abmelden · Version

### Auswertungen (neu, `/auswertungen`)

Umsatz und Arbeiten (`/buchhaltung/auswertung`) · Arbeitstage
(`/auswertungen/arbeitstage`) · Nutzung der App (`/auswertungen/nutzung`)

### Unverändert

Einsätze, Tour, Material, Spesen, Aufgaben, Events, Dokumente. **Steuern und
Dokumente** werden in diesem Teil nicht zusammengelegt; das entscheidet sich
in Teil 3.

## 3. Bauweise

### Baustein 1: Bereichs-Liste als Daten

`lib/core/config/bereiche.dart` beschreibt jeden Bereich als Daten:

```dart
class BereichEintrag {
  final String titel;
  final String? untertitel;
  final IconData icon;
  final String ziel;              // Route
  final ZaehlerQuelle? zaehler;   // optional: niedrig, aufgaben, bereich
}

class Bereich {
  final String id;                // 'mehr', 'bank', 'abschluesse', …
  final String titel;
  final List<BereichGruppe> gruppen;
}
```

Die Mehr-Seite und alle neuen Bereichsseiten zeichnen sich aus diesen
Daten. Umhängen heisst: eine Zeile verschieben.

**Zuordnung eines Pfads zu einem Büro-Bereich** (für Zähler und später für
die Suche): eine reine Funktion `bereichFuerPfad(String pfad) → String?` über
Präfixe, z. B. `/heineken` → `rechnungen`, `/buchhaltung/mwst` →
`abschluesse`, `/buchhaltung/camt-import` → `bank`.

### Baustein 2: `BereichSeite`

Eine gruppierte Liste (Gruppenkopf + Zeilen, optional Kachel-Raster für eine
Gruppe) für Mehr, Bank und Zahlungen, Buchhaltung (unter den Kennzahlen),
Abschlüsse und Steuern, Stammdaten, Einstellungen und Auswertungen. Gebaut
aus `InkWell` + `Container` + `Row`/`Column` — kein `ListTile` als tragendes
Element, keine Material-Knöpfe (CanvasKit-Regel, `CLAUDE.md`).

### Baustein 3: `BereichReiter`

Ein Umschalter unter der AppBar (Rechnungen, Betriebe/Personen). Er ist
**kein** `TabBar` und bettet keine fremden Screens ein: Jeder Reiter bleibt
der bestehende Screen unter seiner bestehenden Route. Der Umschalter wechselt
nur per `context.go` zwischen den Routen und zeigt den aktiven Reiter aus dem
aktuellen Pfad. Folgen: keine doppelten Kopfzeilen, die Zurück-Geste bleibt
intakt, Links aus Mails und Aufgaben zeigen direkt auf den richtigen Reiter.

Gebaut aus `GestureDetector`/`InkWell` + `Container`; die Reiter teilen sich
die Breite, Beschriftung höchstens eine Zeile mit Ellipse (360 px).

### Routen

| | Routen |
|---|---|
| Neu | `/mehr`, `/bank`, `/abschluesse`, `/stammdaten`, `/auswertungen` |
| Verkleinert | `/buchhaltung`, `/einstellungen` |
| Unverändert erreichbar | alle bisherigen Routen, auch `/kontakte`, `/anlagen`, `/bergkundenpauschalen`, `/buchhaltung/*` |

`404.html` und der Versions-Redirect brauchen keine Änderung: Die neuen
Routen sind gewöhnliche Hash-Routen.

## 4. Absicherung

**Wächter-Tests (neu):**

- **Erreichbarkeit:** Jede Listen- oder Bereichsroute im Router ist entweder
  ein Eintrag in `bereiche.dart`, ein Reiter eines `BereichReiter`, eines der
  fünf Leisten-Ziele, oder ein Detail/Formular (`/:id`, `/neu`,
  `/bearbeiten`, …). Eine kurze, begründete Ausnahmeliste ist erlaubt. Anlass:
  Die Bestellungen-Liste war bis v0.47.0 unauffindbar.
- **Leuchten:** `aktivesZiel` liefert für jeden Pfad genau ein Ziel; alles
  ausser den vier ersten Zielen, den Einsatz-Präfixen und `/kontakte` ergibt
  `NavZiel.mehr`.
- **CanvasKit:** `bereich_seite.dart`, `bereich_reiter.dart` und die
  Mehr-Seite enthalten weder `FilledButton`/`OutlinedButton`/`ElevatedButton`
  noch `TabBar`/`NavigationBar`.
- **Event-Fenster:** reine Funktion `eventImFenster(event, heute)` mit Tests
  für: 8 Tage vorher (nein), 7 Tage vorher (ja), letzter Tag (ja), Tag danach
  (nein), ohne `termin_von` (nein), ohne `termin_bis` (nur der Starttag gilt
  als Ende). Datumsvergleich in UTC-Tagen (Sommerzeit-Regel).

**Angepasst, nicht gelöscht:** `navigation_ziele_test.dart`,
`haupt_navigation_test.dart`, `formular_ohne_navigation_waechter_test.dart`,
`kachel_text_test.dart`, `aufgaben_eine_quelle_waechter_test.dart`,
`heute_liste_test.dart`.

**Vor jedem Deploy:** `flutter analyze` (Grundrauschen 56 unverändert),
alle Tests grün, Sichtprüfung im Browser bei 360 × 800 mit Screenshot — die
Leiste, Mehr, jede neue Bereichsseite und beide Umschalter.

## 5. Auslieferung

| Version | Inhalt |
|---|---|
| **v0.131.0** | Leiste mit Mehr · Mehr-Seite · Heute nur der Tag · Abmelden und Sync in den Einstellungen · Bereichsseiten Bank und Zahlungen, Abschlüsse und Steuern, Stammdaten, Auswertungen · Buchhaltung und Einstellungen verkleinert · `BereichReiter` mit Betriebe/Personen (sonst wären die Kontakte ab hier unerreichbar) · Bereichs-Liste, `BereichSeite`, Wächter Erreichbarkeit und Leuchten |
| **v0.132.0** | Rechnungen mit Reitern und Bergkundenpauschalen · Event-Karte auf Heute · Wächter Event-Fenster |

Zwischen den beiden Schritten ist v0.131.0 im Alltag im Einsatz. Die Zeile
«Rechnungen» auf Mehr führt bis v0.132.0 auf die bestehende
Forderungen-Seite (`/rechnungen`); Heineken, Jahresrechnungen und
Bergkundenpauschalen bleiben bis dahin in der verkleinerten Buchhaltung
stehen, damit nichts unerreichbar wird.

**Nachher:** Nach zwei Wochen Nutzungsmessung auswerten — wird Mehr
angenommen, welche Büro-Screens öffnest du am Handy? Das ist die Grundlage
für Teil 3.

## Nicht in diesem Teil

- Suche (Teil 2)
- Umbau einzelner Büro-Screens für 360 px (Teil 3)
- Zusammenlegen von Steuern und Dokumenten
- Änderungen an der PC-Darstellung über die bestehende Breitenbegrenzung
  (`InhaltsBreite`) hinaus
