# Tourenplanung T1 — UX & Verhalten (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (10.07.2026)
**Herkunft:** Paket 06 (`Prompts/06_Optimierung_App_2026_07_07.txt`), Abschnitt „Tourenplanung".
Erstes von zwei Teil-Paketen (T1 = UX/Verhalten; **T2** = Fälligkeits-Logik & Auto-Termine folgt separat).

## Ziel & Kontext

Die Tourenplanung soll einfacher und planungsfreundlicher werden: leerer Start statt Auto-Befüllung,
Auto-Speicherung, sichtbare Ruhetage/Servicezeiten (mit Ruhetag-Warnung), übersichtliche Filter und
ein leichter zu bedienendes Verschieben.

**Ist-Zustand (verifiziert):**
- `lib/presentation/screens/touren/tourenplanung_screen.dart` (~1250 Zeilen): 2 Tabs — **Tagesplan**
  (Reorder-Liste `_TagesplanListe` mit `onReorder`/`onDismiss`/`onTap`) + **Fällig** (Liste
  `_FaelligEintragKarte` mit „hinzufügen"). Wochen-/Tages-Navigation über `_selectedDate`.
- Beim Tageswechsel: gespeicherter Plan hat Vorrang, **sonst wird aus einem Vorschlag befüllt**
  (`tourVorschlagErweitertProvider` → `tagesplanProvider.notifier.setFromVorschlag`). → nicht leer.
- **Speicherbutton** im `_TagesplanHeader` (`onSpeichern` → `tagesplanSpeichern(datum, tagesplan)` +
  `markGespeichert()`), `gespeichert`-Flag im Notifier.
- Filter über ein **Bottom-Sheet** (`_showFilterPicker`), Providers `selectedRegionenProvider`,
  `selectedFaelligkeitProvider`.
- `tour_providers.dart`: `FaelligkeitsStatus` {ueberfaellig, faellig, baldFaellig, endreinigungFaellig,
  eroeffnungFaellig, nichtFaellig}, `getFaelligkeit(...)`, `faelligkeitFarbe/Label`,
  `isBetriebOffen(b, datum)` (prüft u.a. `b.ruhetage.contains(wochentag)`),
  `class TourEintrag { betriebId, betriebName, betriebOrt, typ, … }`, `betriebMap` beim Bauen.
- `BetriebLocal` hat `ruhetage` (List<String>, z.B. `['Mo','Di']` oder `['keine']`),
  `servicezeitMorgenAb/Bis`, `servicezeitNachmittagAb/Bis` (String? „HH:MM").

## Entscheidungen (mit User geklärt)

- **A Start:** Tagesplan **default leer** (kein Vorschlag-Autofill; gespeicherter Plan wird geladen).
  „Fällig" zeigt **default nur überfällig + fällig**; andere Kategorien per Filter einblendbar.
  Button **„Fällige übernehmen"** fügt alle aktuell gezeigten überfällig+fälligen auf einmal hinzu.
- **B Auto-Speicherung:** Speicherbutton entfällt; bei **jeder Änderung** automatisch (entprellt) speichern.
- **C Ruhetage/Servicezeiten:** auf jeder Karte anzeigen **+ Warnung**, wenn geplanter Tag = Ruhetag.
- **D Filter:** **Inline-Leiste**, Region + Fälligkeit getrennt (kein Sheet mehr).
- **E Drag:** expliziter **grosser Greif-Griff** (≡) pro Karte; Rest der Karte = Tap→Detail.
- Keine DB-Migration. Deploy **v0.29.0**.

## Baustein A — Default leer + „Fällige übernehmen"

- Tageswechsel-Logik: den `setFromVorschlag`-Zweig entfernen. Existiert ein gespeicherter Plan →
  `setFromGespeichert`; sonst **leerer** Plan (`leeren()`), nicht der Vorschlag.
- Default-Fälligkeitsfilter: `selectedFaelligkeitProvider` initial = `{ueberfaellig, faellig}`
  (statt leer/alles). Die „Fällig"-Liste respektiert diesen Filter; andere Kategorien werden erst
  sichtbar, wenn der User sie im Fälligkeits-Filter aktiviert.
- Button **„Fällige übernehmen"** (im Fällig-Tab-Header): fügt alle aktuell **angezeigten** Einträge
  (also die gefilterten überfällig+fälligen, die noch nicht im Plan sind) via `hinzufuegen` in den
  Tagesplan. Einzel-Hinzufügen (`onAdd`) bleibt.

## Baustein B — Auto-Speicherung

- `_TagesplanHeader`: Speicherbutton + „gespeichert?"-Anzeige entfernen (der „Leeren"-Button bleibt).
- Der `tagesplanProvider`-Notifier speichert nach jeder mutierenden Aktion (`hinzufuegen`,
  `entfernen`, `reorder`, `leeren`, Sammel-Übernahme) automatisch via `tagesplanSpeichern(datum, …)` —
  **entprellt** (~500 ms), damit Reorder-Ketten nicht spammen. Der aktuelle Tag kommt aus
  `aktiverTagesplanTagProvider`. `markGespeichert()`/`gespeichert` werden obsolet (entfernen oder
  intern lassen). Nach dem Speichern `gespeicherterTagesplanProvider` **nicht** hart invalidieren,
  um keinen Reload-Flacker auszulösen (der lokale State ist die Quelle).

## Baustein C — Ruhetage + Servicezeiten + Warnung

- Reine Helfer (`lib/core/util/touren_anzeige.dart`, testbar):
  - `istRuhetag(List<String> ruhetage, DateTime tag) → bool` (Wochentag-Kürzel `Mo…So`;
    `['keine']`/leer → false).
  - `servicezeitText(String? morgenAb, morgenBis, nachmittagAb, nachmittagBis) → String`
    (z.B. „08:00–12:00 · 13:30–17:00"; leer wenn nichts gesetzt).
  - `ruhetageText(List<String> ruhetage) → String` (z.B. „Mo, Di"; „keine"/leer → '').
- `TourEintrag` um Anzeige-Felder erweitern: `List<String> ruhetage`, `String? servicezeitText`
  (beim Bauen aus `betriebMap` befüllen). Kein Sync/DB (reines UI-Objekt).
- Karten (`_TagesplanListe`-Karte + `_FaelligEintragKarte`): kleine Zeile Ruhetage + Servicezeiten;
  wenn `istRuhetag(eintrag.ruhetage, aktiverTag)` → **auffällige Warnung** (rotes Icon + Text „Heute
  Ruhetag").

## Baustein D — Filter Inline & getrennt

- `_showFilterPicker`-Sheet entfernen; stattdessen eine **sichtbare Filter-Leiste** unter der
  Datumsnavigation:
  - **Region:** kompakter Multi-Select (Chips oder Dropdown-Chips) aus `regionenProvider`.
  - **Fälligkeit:** Chips je Kategorie (Überfällig/Fällig/Bald/Eröffnung/Endreinigung) mit den
    bestehenden `faelligkeitFarbe`-Farben; Mehrfachauswahl.
  - Beide schreiben weiter in `selectedRegionenProvider` / `selectedFaelligkeitProvider`.
- Die bestehende `passesFilter`-Logik bleibt (nur die Bedien-UI ändert sich).

## Baustein E — Grosser Drag-Griff

- Reorder bleibt (`ReorderableListView` bzw. die bestehende `_TagesplanListe`), aber der Drag wird
  über einen **expliziten breiten Griff** (`ReorderableDragStartListener` um ein grosses ≡-Icon-
  Feld, volle Kartenhöhe, ausreichend Touch-Fläche) ausgelöst statt über einen kleinen Standard-
  Handle. Tap auf den Kartenkörper bleibt = Detail öffnen. `buildDefaultDragHandles: false`.

## Abgrenzung

- **Kein** Fälligkeits-Logik-Umbau (Eröffnung/Endreinigung/Ferien/Saison prüfen) und **keine**
  Auto-Termine — das ist **T2**. T1 nutzt die bestehende Fälligkeitsberechnung unverändert.
- Keine DB-Migration; `tagesplan`-Persistenz-Schema unverändert.

## Tests & Verifikation

- **Unit-Tests** (`touren_anzeige`): `istRuhetag` (Wochentage, `['keine']`, leer);
  `servicezeitText` (beide Blöcke / nur Morgen / leer); `ruhetageText`.
- `flutter analyze` ohne neue Findings; Tests grün.
- **Visueller Browser-Test** (Pflicht): neuer Tag → Plan **leer**; „Fällig" zeigt nur
  überfällig+fällig; „Fällige übernehmen" füllt den Plan; Ändern speichert automatisch (nach Reload
  wieder da, kein Button); Ruhetage/Servicezeiten je Karte + Ruhetag-Warnung an einem Ruhetag;
  Inline-Filter (Region/Fälligkeit) wirken; Verschieben über den grossen Griff klappt flüssig, Tap
  öffnet Detail.

## Deploy

Ein Paket **v0.29.0** nach Deploy-Workflow (CLAUDE.md). Keine Migration.
