# Anstiche & Leitungen am Event — Design

**Datum:** 14.08.2026
**Anlass:** Openair Gampel 17.–23.08.2026
**Status:** freigegeben durch Daniel (14.08.2026)

## Ziel und Abgrenzung

Am Openair Gampel werden die Zapfstellen nicht aus Fässern am Stand gespiesen,
sondern aus zentralen Anstichen: Orion-Tanks (500 l / 1000 l) und
Mehrfachanstichen (bis zu 4 Tanks an einer Leitung, alle in einem Kühlzelt).
Von dort laufen Leitungen an die Stände — an einem Orion-Tank bis zu 12 Stück.
Für die Begleitkühlung der Leitungen stehen Durchlaufkühler dazwischen, durch
einen Kühler laufen mehrere Leitungen.

Die App bildet diese Struktur heute nicht ab. Am Stand steht nur eine Liste
`typ + anzahl` (`event_stand_anlagen`) mit einem Inbetriebnahme-Haken; woher
das Bier kommt, steht nirgends.

**Was dieses Vorhaben ist:** ein Erfassungswerkzeug für Gampel 2026 in
SBS Projer DEV.

**Was es nicht ist:** das endgültige Modell. Daniel dokumentiert die Anlage
während des Events im Detail; die saubere Umsetzung erfolgt danach im
**Projekt Heineken** (`D:\Projekte\Heineken`). Alles, was hier gebaut wird,
muss deshalb zwei Bedingungen erfüllen: bis Montag nutzbar sein, und Daten so
normalisiert ablegen, dass sie sich später übernehmen lassen — statt aus
Freitext-Notizen rekonstruiert werden zu müssen.

## Fachliche Regeln (Auskunft Daniel, 14.08.2026)

1. Eine Bierquelle kann **einen oder mehrere Stände** speisen — beides kommt
   vor. Die Quelle gehört deshalb ans Event, nicht an einen Stand.
2. Die **Leitung ist die Einheit**, nicht das Gerät und nicht die Gerätegruppe.
3. Leitungen sind **physisch angeschrieben** — dieselbe Nummer steht am Anstich
   und am Zapfhahn. Die Nummern laufen **pro Anstich** (Tank A: 1–12,
   Tank B: 1–8), nicht eventweit fortlaufend.
4. Ein Oberthekengerät hat **2 Hähne**, jeder Hahn trägt die Nummer seiner
   Leitung. Damit ist der Hahn über die Nummer eindeutig identifiziert — es
   braucht **keine** Aufteilung der Gerätezeilen in Einzelgeräte.
5. Ein **Durchlaufkühler nimmt mehrere Leitungen** auf; er ist ein eigenes
   Gerät, kein Attribut der Leitung.
6. Grössenordnung Gampel: rund **10 Quellen und 40 Leitungen** — Erfassung am
   Handy ist zumutbar, sofern die Leitungen nicht einzeln getippt werden müssen.

## Zweck im Alltag

Alle vier Zwecke sind gefordert (Daniel, 14.08.):

- **Störungssuche im Pikett:** «Leitung 7 zieht nicht» → welcher Anstich,
  welcher Kühler, welcher Stand; und wer hängt sonst noch an der Quelle.
- **Aufbau- und Materialplanung:** wie viele Tanks, Leitungen und Kühler wohin.
- **Inbetriebnahme abhaken:** Quelle für Quelle, Leitung für Leitung.
- **Dokumentation fürs Folgejahr:** damit der Aufbau 2027 nicht bei null beginnt.

## Datenmodell

Zwei neue Tabellen, **Migration 172**.

### `event_geraete`

Ein Eintrag je Anstich **und** je Durchlaufkühler. Beide liegen bewusst in
einer Tabelle: es sind Geräte, an denen Leitungen hängen, und bei beiden
werden Standort und Inbetriebnahme geführt. Eine Tabelle weniger ohne
semantischen Verlust.

| Spalte | Typ | Bemerkung |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid | wie überall |
| `event_id` | uuid | → `events` |
| `typ` | text | `orion_1000` \| `orion_500` \| `mehrfachanstich` \| `durchlaufkuehler` (CHECK) |
| `bezeichnung` | text | «Anstich A», «Kühlzelt Nord» |
| `anzahl_tanks` | int | nur `mehrfachanstich`, 1–4; sonst NULL |
| `standort_notiz` | text | frei, z. B. «Kühlzelt hinter Bühne» |
| `latitude` / `longitude` | double | optional, gleiche Mechanik wie `event_staende` |
| `position_quelle` / `position_genauigkeit` | text | analog `event_staende` |
| `in_betrieb` | bool | Default false |
| `in_betrieb_am` | timestamptz | |
| `sortierung` | int | |
| `notizen` | text | |

### `event_leitungen`

| Spalte | Typ | Bemerkung |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid | |
| `event_id` | uuid | → `events` (redundant zur Quelle, erspart Joins beim Laden) |
| `nummer` | text | die angeschriebene Nummer; eindeutig **je Quelle** |
| `quelle_id` | uuid | → `event_geraete` (Anstich) |
| `kuehler_id` | uuid NULL | → `event_geraete` (Durchlaufkühler) |
| `stand_id` | uuid NULL | → `event_staende` |
| `stand_anlage_id` | uuid NULL | → `event_stand_anlagen`, welche Gerätezeile am Stand |
| `in_betrieb` | bool | Default false |
| `in_betrieb_am` | timestamptz | |
| `sortierung` | int | |
| `notiz` | text | |

`nummer` ist Text, nicht Integer: die Beschriftung vor Ort kann «7a» oder
«B3» lauten, und ein Zahlentyp erzwingt eine Sortierung, die der Realität
nicht folgen muss. Eindeutigkeit wird über einen Unique-Index auf
`(quelle_id, nummer)` erzwungen.

`stand_id` und `stand_anlage_id` sind nullable: Beim Erzeugen der Leitungen
steht das Ziel noch nicht fest, es wird beim Anschliessen gesetzt.

RLS-Policies und `updated_at`-Trigger analog zu `event_staende`.

## Bedienung

### Neuer Tab «Technik» im Event-Detail

Sechster Tab neben Kontakte | Stände | Einsätze | Zeit | Dokumente. Enthält:

- **Liste der Anstiche** (Orion / Mehrfachanstich), je als Karte mit
  Bezeichnung, Typ, Standort-Notiz, Inbetriebnahme-Haken und Zähler
  «n Leitungen, davon m angeschlossen».
- **Aufgeklappt:** die Leitungen des Anstichs, je Zeile
  `7 → Stand 12 · OT · über Kühler Nord ✓`. Tippen öffnet die Bearbeitung
  (Ziel-Stand, Ziel-Gerätezeile, Kühler, Haken).
- **Liste der Durchlaufkühler** darunter, je mit den durchlaufenden Leitungen.
- **«Leitungen erzeugen»** am Anstich: Nummernbereich eingeben (z. B. 1–12),
  die Zeilen entstehen auf einen Schlag ohne Ziel. Das Ziel wird danach je
  Zeile gesetzt. Ohne diese Massenanlage ist die Erfassung am Handy nicht
  zumutbar.
- **Nummernsuche:** Eingabefeld oben; «7» springt zur Leitung mit Quelle,
  Kühler und Ziel. Da die Nummern nur je Anstich eindeutig sind, werden bei
  Mehrdeutigkeit alle Treffer mit ihrem Anstich gezeigt.

### Gegenrichtung am Stand

Im Stände-Tab zeigt die Stand-Zeile zusätzlich «Leitungen 7, 8, 9 ← Anstich A».
Das ist die Ansicht, die im Pikett zuerst gebraucht wird: Der Anruf nennt den
Stand, nicht die Leitung.

### CanvasKit-Regeln

Alle Karten und Listenzeilen aus `GestureDetector`/`InkWell` + `Container` +
`Row`/`Column`, kein `ExpansionTile` (verboten mit `dense: true`, siehe
`test/canvaskit_sichere_widgets_test.dart`). Vorbild: `_StandCard` und der
eigene Kopf aus v0.84.0. Analyse und Tests fangen diese Klasse Fehler nicht —
vor dem Deploy visuell prüfen.

## Nicht-Ziele

Bewusst nicht gebaut, weil es ins Heineken-Projekt gehört:

- Leitungslängen und daraus abgeleitete Materiallisten
- Leitungen und Anstiche als Linien/Marker auf dem georeferenzierten Lageplan
- Aufteilung von `event_stand_anlagen` in Einzelgeräte
- Erweiterung des Event-Abschluss-PDF um die Technik
- Google-Kalender- oder Rechnungs-Anbindung

## Umsetzung

Zwei Entities durch die Checkliste in `CLAUDE.md` («Neue Entity hinzufügen»),
also je: DTO, Isar-Local-Model, Conditional Export, Web-Stub, Mapper,
IsarService-Queries, Repository mit `kIsWeb`-Branching, Provider. Dazu
Migration 172, der Technik-Tab und die Stand-Zeile.

Sync: Reihenfolge Event → Stand → Gerät → Leitung (FK-Abhängigkeiten), analog
zur bestehenden Event-Vertikale.

## Tests

- Reine Funktion `leitungsNummernBereich(von, bis)` für die Massenanlage:
  Grenzen, umgekehrte Eingabe, Kollision mit bestehenden Nummern.
- Reine Funktion `leitungenJeStand(...)` für die Gegenrichtung am Stand.
- Suche: Nummer mehrdeutig über zwei Anstiche → beide Treffer.
- Mapper-Roundtrip beider Entities (Alt-Key-Toleranz wie bei
  `BetriebRechnungsadresseMapper`).
- Wächter: `pagination_stabil_test.dart` greift automatisch, sobald eine
  `.range()`-Abfrage dazukommt — `.order('id')` nicht vergessen.

## Risiken

- **Zeit:** Gampel beginnt am 17.08. Fällt der Technik-Tab nicht rechtzeitig
  fertig, ist die Migration allein wertlos. Deshalb ist die Reihenfolge:
  Migration + Entities + Technik-Tab zuerst, die Stand-Gegenrichtung und die
  Nummernsuche danach — beides ist Komfort, nicht Voraussetzung.
- **Gampel hat aktuell 0 Stände erfasst, und es gibt kein Gampel 2025**
  (geprüft 14.08.: nur der Jahrgang 2026 existiert, ohne Stände). «Aus Vorjahr
  übernehmen» fällt damit aus — die Stände müssen von Hand angelegt werden,
  bevor ein Leitungsziel gesetzt werden kann. Das ist Voraussetzung für den
  Nutzen des ganzen Vorhabens und sollte vor dem Aufbau passieren.
  Konsequenz für die Umsetzung: Das Leitungs-Ziel muss auch **ohne** Stand
  gesetzt werden können (`stand_id` nullable), damit die Erfassung nicht
  blockiert, wenn ein Stand vor Ort noch fehlt.
