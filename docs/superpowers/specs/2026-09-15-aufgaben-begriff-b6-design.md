# Ein Aufgaben-Begriff (B6) — Entwurf

Stand 15.09.2026 · Vorschlag B6 aus `docs/app-analyse-2026-09.md` · baut auf B2 (`2026-09-15-einsaetze-screen-b2-design.md`, v0.105.0) auf.

## 1. Befund

Die App hat drei Oberflächen, die «Aufgaben» heissen, aus zwei Quellen:

| Oberfläche | Quelle | Inhalt | Aktionen |
|---|---|---|---|
| Glocke (überall, unten links), Startkarte, Sheet | `aufgabenProvider` → `AufgabenStand` | sechs Detektoren (Heineken-Rechnung, MWST, Mahnlauf, Saisondaten, fehlende Buchungen, Versandvermerk) + eigene Aufgaben, nur «jetzt sichtbar» (fällig ≤ 7 Tage) | Dorthin, Snooze 1/3/7, Erledigt |
| Kachel «Aufgaben» | Handrechnung in `home_screen.dart:101` | eigene (alle) + offene Störungen + offene Montagen — **nicht** Vorschläge, Termine | — |
| Aufgaben-Screen `/aufgaben` | Aufbau im Widget (`aufgaben_screen.dart`, 573 Zeilen) | eigene (alle, auch künftige) + offene Störungen + offene Montagen + Änderungsvorschläge + Saison-Vorschläge + bestätigte Saison-Termine, gruppiert Überfällig/Heute/Morgen/Datum/Ohne Datum | Dorthin, Erledigt, Einplanen, Bestätigen |

Befund 4 der Analyse: Wer die Kachel öffnet, sieht die fällige Heineken-Rechnung nicht; wer die Glocke öffnet, nicht die offene Störung. Der Kachelzähler stimmt zudem mit keiner der beiden Listen überein. Der Kommentar «Bewusst nicht `aufgabenProvider`» (`aufgaben_screen.dart:20`) war für die Glocke richtig gedacht (nur Fälliges) und für den Screen falsch verallgemeinert (eigene Quelle statt eigener Filter).

Seit B2 liegen offene und geplante Störungen, Montagen und Termine ausserdem in `einsaetzeProvider` — der Aufgaben-Screen rechnet sie ein drittes Mal aus.

## 2. Entscheidungen

1. **Eine Liste, ein Filter (Variante A).** Erinnerungen, eigene Aufgaben, anstehende Einsätze und Vorschläge stehen in **einer** Liste nach Fälligkeit. Glocke, Startkarte, Kachel, Sheet und Screen lesen dieselbe Liste; Glocke/Karte/Kachel/Sheet zeigen den Ausschnitt «jetzt fällig», der Screen alles.
2. **Schwelle für Einsätze: überfällig oder heute.** Fälligkeit eines Einsatzes = geplanter Tag, sonst Meldedatum. Eine gemeldete Störung ohne Termin ist ab dem Folgetag in der Glocke; eine für Donnerstag geplante Montage erst am Donnerstag. Eigene Aufgaben (ab Fälligkeit −7 Tage) und Detektoren (sobald sie anschlagen) behalten ihre Regel.
3. **Ein Eintragstyp, ein Provider (Bauweise 1).** Der Listenaufbau wandert aus dem Screen in eine reine Funktion; die Aktionen folgen aus der Quelle des Eintrags, nicht aus Callbacks im Widget.
4. **Einsätze werden nicht gesnoozt, sondern eingeplant.** Snooze bleibt für Detektoren, eigene Aufgaben und Änderungsvorschläge.
5. **Lieferung als v0.106.0 mit Entfernung der sechs alten Listen** — der Ablauf-Wächter aus B2 verlangt es, und Daniels Klicktest von B2 braucht keine Rückfalltür (15.09.2026).

## 3. Bauteile

### 3.1 `lib/core/util/aufgabe.dart` — der Eintrag und die Regeln

```dart
enum AufgabenQuelle { detektor, eigene, einsatz, saisonVorschlag, aenderungsVorschlag, termin }

class AufgabenEintrag {
  final AufgabenQuelle quelle;
  final String key;            // deterministisch, für Snooze/Marker: 'heineken:2026-08', 'eigene:<uuid>', 'einsatz:stoerung:<routeId>', 'saison:<betriebId>:<typ>', 'vorschlaege', 'termin:<id>'
  final String titel;
  final String? untertitel;
  final DateTime? faellig;     // null = ohne Datum
  final bool dringend;
  final String? route;         // «Dorthin» — bei Einsätzen `einsatz.detailRoute`
  final Einsatz? einsatz;      // nur quelle == einsatz
  final String? eigeneId;      // nur quelle == eigene
  final String? terminId;      // nur quelle == termin
  final ({String betriebId, String typ, DateTime datum, String titel, String anlass})? saison; // nur saisonVorschlag: was «Bestätigen» anlegt
  bool get erledigbar => quelle == eigene || quelle == termin || (quelle == detektor && manuellErledigbar);
  bool get snoozebar  => quelle == detektor || quelle == eigene || quelle == aenderungsVorschlag;
  bool get einplanbar => quelle == einsatz && (einsatz!.typ == EinsatzTyp.stoerung || einsatz!.typ == EinsatzTyp.montage);
  bool get bestaetigbar => quelle == saisonVorschlag;
  final bool manuellErledigbar; // aus `Aufgabe` (nur MWST-Detektor)
}
```

`Einsatz` (B2) bekommt das Feld `DateTime? geplantAm` (Störung/Montage aus `geplantAm`; sonst null). Die B2-Adapter setzen es; sonst ändert sich an B2 nichts.

Reine Funktionen, alle mit `heute` als Parameter:

- `DateTime? einsatzFaelligkeit(Einsatz e)` → `e.geplantAm ?? e.datum`.
- `bool jetztFaellig(AufgabenEintrag a, DateTime heute)`:
  - `detektor`, `aenderungsVorschlag` → immer;
  - `eigene` → `eigeneSichtbar(a.faellig, heute)` (bestehend, ≤ 7 Tage);
  - `einsatz`, `saisonVorschlag`, `termin` → `a.faellig != null && faelligTag <= heuteTag`.
- `List<AufgabenEintrag> baueAufgabenListe({required List<Aufgabe> detektoren, required List<Map<String,dynamic>> aufgabenZeilen, required List<Einsatz> anstehend, required List<TourEintrag> saisonVorschlaege, required List<TerminDto> offeneTermine, required int aenderungsVorschlaege, required DateTime heute})`:
  1. Snoozes und Marker aus `aufgabenZeilen` lesen (bestehende Logik aus `aufgabenProvider`).
  2. Detektoren → Einträge (Snooze angewandt); Änderungsvorschläge > 0 → ein Eintrag `vorschlaege` («N Änderungsvorschläge prüfen», Route `/betriebe/vorschlaege`, snoozebar).
  3. Eigene: alle mit `erledigt_am == null`, Snooze angewandt; `dringend` = fällig ≤ heute.
  4. Einsätze → Einträge mit `faellig = einsatzFaelligkeit`, Titel `'${typLabel} ${betriebName}'`, Untertitel Beschreibung · Planungstext (`planungsText`, bestehend), `dringend` = Stufe offen (Störung ohne Termin) oder überfällig.
  5. Saison-Vorschläge: nur solche, die kein bestätigter Termin abdeckt (`terminDecktVorschlagAb`, bestehend); `faellig = zielDatum`.
  6. Termine (Saison, bestätigt) → Einträge mit `faellig = datum`; **alle anderen** offenen Termine sind schon in `anstehend` (Quelle einsatz) — hier nicht doppelt.
  7. Sortierung: fällig aufsteigend, ohne Datum zuletzt; innerhalb eines Tages dringend zuerst, dann Quelle in Enum-Reihenfolge, dann Titel.

Unbekannte Werte werfen nie — ein kaputter Detektor darf die Liste nicht leeren (heutiges try/catch je Detektor bleibt).

### 3.2 Provider — `lib/presentation/providers/aufgaben_providers.dart`

- `aufgabenDetektorenProvider` (`FutureProvider<List<Aufgabe>>`): der heutige Detektor-Block aus `aufgabenProvider` **unverändert** in eine eigene Datei `aufgaben_detektoren_provider.dart` verschoben — ohne Snooze (den wendet die Liste an), ohne eigene Aufgaben.
- `anstehendeEinsaetzeProvider` (`Provider<List<Einsatz>>`, in `einsatz_providers.dart`): Störungen, Montagen, Eigenaufträge aus den Speicher-Providern über die B2-Adapter, plus offene Termine (ohne Saison-Typen — die laufen als `termin`), gefiltert auf Stufe offen/geplant/inArbeit. Ohne Jahresgrenze, ohne Buchungsabfrage (`hatBuchung` ist für Offenes belanglos). Reinigungen (jahresweise vom Server, «offen» = Entwurf), Saison-Belege und Pikett sind nie Aufgaben.
- `aufgabenListeProvider` (`FutureProvider<List<AufgabenEintrag>>`): ruft `baueAufgabenListe` mit den Quellen oben, `AufgabenRepository.alleZeilen()`, `autoTermineProvider(heuteTag)`, `offeneTermineProvider`, `offeneVorschlaegeAnzahlProvider`. Ohne Login → leer.
- `aufgabenJetztProvider` (`Provider<List<AufgabenEintrag>>`): `jetztFaellig`-Ausschnitt der Liste (leer, solange die Liste lädt).
- `aufgabenBadgeProvider` (`Provider<int>`): `aufgabenJetztProvider.length`.

### 3.3 Zeile — `lib/presentation/widgets/aufgabe_zeile.dart`

`AufgabeZeile(eintrag, heute, onDorthin, onSnooze(tage), onErledigt, onEinplanen, onBestaetigen)` — `InkWell` + `Container` + `Row` (CanvasKit-Regel), Vorbild `EinsatzZeile`. Links Icon je Quelle/Typ (Einsatz: `einsatzTypIcon`/`einsatzTypFarbe` aus B2; Detektor/eigene: Punkt rot/orange wie heute; Saison-Vorschlag: `cleaning_services_outlined`; Termin: `cleaning_services`; Änderungsvorschlag: `fact_check_outlined`), dann Titel (eine Zeile, Ellipsis) und Untertitel (bis zwei Zeilen), rechts die Knöpfe als `IconButton` — nur die, die der Eintrag hat: Dorthin (`arrow_forward`), Snooze (`snooze`, `PopupMenuButton` 1/3/7), Erledigt (`check_circle_outline`), Einplanen (`event`), Bestätigen (`event_available`). Fälligkeit steht im Untertitel als «Do 17.09.» oder «überfällig seit 3 Tagen», nicht als eigene Spalte — auf 360 px ist rechts kein Platz neben drei Knöpfen.

### 3.4 Oberflächen

- **Glocke** (`aufgaben_glocke.dart`): Badge = `aufgabenBadgeProvider`. Sonst unverändert.
- **Startkarte** (`_AufgabenKarte` in `home_screen.dart`): liest `aufgabenJetztProvider`; drei Titel, rot wenn eines dringend; Tipp öffnet das Sheet. Unverändert im Aussehen.
- **Kachel «Aufgaben»**: `count = aufgabenBadgeProvider` — die Handrechnung (`aufgabenCount`, Zeilen 100–107) fällt weg.
- **Sheet** (`aufgaben_sheet.dart`): Zeilen aus `AufgabeZeile` über `aufgabenJetztProvider`; Kopf «Aufgaben», Knöpfe «Neue Aufgabe» (bestehend) und «Alle anzeigen» → `Navigator.pop`, dann `router.push('/aufgaben')`; Leerzustand «Alles erledigt 🎉» bleibt. Kein `ListTile` mehr.
- **Screen** (`aufgaben_screen.dart`): `AufgabenInhalt` (reine Darstellung: `eintraege`, `heute`, Aktions-Callbacks) + `AufgabenScreen` (angebunden). Gruppen Überfällig/Heute/Morgen/Datum/Ohne Datum wie heute; FAB «Neue Aufgabe» bleibt (`AufgabenRepository.eigeneAnlegen`). Der Aufbau der Einträge ist weg — nur Darstellung und Aktionen.

### 3.5 Aktionen — `lib/presentation/widgets/aufgaben_aktionen.dart`

Eine Klasse `AufgabenAktionen(ref)` mit je einer Methode, damit Sheet und Screen dieselben Abläufe nutzen:

- `dorthin(context, a)`: `Navigator.pop` falls im Sheet, dann `router.push(a.route!)`.
- `snooze(a, tage)`: `AufgabenRepository.snooze(a.key, tage)`.
- `erledigt(a)`: eigene → `eigeneErledigen(eigeneId)`; termin → `TerminRepository.erledigen(terminId)`; Detektor → `markerSetzen(key)`.
- `einplanen(context, a)`: der heutige Ablauf aus `aufgaben_screen.dart` (Zeilen 127–260: `zeigeEinplanenSheet` → `einsatzUmplanen` mit `StoerungRepository.einplanen`/`MontageRepository.einplanen` und `geplanterEinsatzEintrag`) zieht **unverändert** hierher um; das Rohmodell (`StoerungLocal`/`MontageLocal`) wird beim Aufruf über `routeId` aus `stoerungenProvider`/`montagenProvider` nachgeschlagen, der Betrieb aus `betriebLookupProvider`. Die Kommentare zum Geisterblock (02.08.2026) ziehen mit.
- `bestaetigen(a)`: `TerminRepository.anlegen(betriebId, typ, datum, titel, anlass)` aus `a.saison`.
- Jede Aktion endet mit `ref.invalidate(aufgabenListeProvider)` (und den betroffenen Quell-Providern wie heute: `stoerungenStreamProvider`, `montagenStreamProvider`, `offeneTermineProvider`). Fehler → SnackBar «Fehler: …» wie heute.

### 3.6 Was wegfällt

`AufgabenStand`, `EigeneAufgabe`, `aufgabenProvider`, `offeneEigeneAufgabenProvider`, `_Eintrag`, `_EintragKarte`, `_zeile` im Sheet, `aufgabenCount` in `home_screen.dart`. `aufgaben_regeln.dart` (Detektoren, `Aufgabe`, `eigeneSichtbar`, `snoozeAktiv`) bleibt.

### 3.7 Alte Listen entfernen (B2-Zyklus abgeschlossen)

Sechs Dateien (`reinigungen_list_screen.dart`, `stoerungen_list_screen.dart`, `montagen_list_screen.dart`, `eigenauftrag_list_screen.dart`, `eroeffnungsreinigung_list_screen.dart`, `pikett_dienste_list_screen.dart`) und ihre sechs Routen in `router.dart` samt Importen. Geprüft 15.09.2026: nichts anderes verlinkt oder importiert sie, kein Test rendert sie. Die Ratsche sinkt von 23 auf **20** (drei Treffer lagen in den Listen). `alte_listen_ablauf_test.dart` wird damit grün bei 0.106.0; der Test bleibt als Beleg.

## 4. Tests

- `test/aufgabe_test.dart`: `jetztFaellig` je Quelle (Grenzen heute/morgen/gestern, ohne Datum), `einsatzFaelligkeit`, `baueAufgabenListe` (Sortierung mit Ohne-Datum zuletzt, Snooze und Marker, Doppelanzeige-Abgleich Saison, Störung ohne Termin ist dringend, Termine nicht doppelt).
- `test/einsatz_test.dart`: `geplantAm` in den Adaptern.
- `test/aufgaben_providers_test.dart`: `aufgabenListeProvider` mit überschriebenen Quellen; Badge = Anzahl jetzt fällig.
- `test/aufgabe_zeile_test.dart` (Roboto, 360 px): Knöpfe je Quelle, Titel nicht gekürzt bei drei Knöpfen, kein `ListTile`.
- `test/aufgaben_inhalt_test.dart`: Gruppen, Leerzustand, Aktionen melden den Eintrag.
- `test/aufgaben_eine_quelle_waechter_test.dart`: `home_screen.dart`, `aufgaben_glocke.dart`, `aufgaben_sheet.dart`, `aufgaben_screen.dart` lesen `aufgabenBadgeProvider`/`aufgabenJetztProvider`/`aufgabenListeProvider` und nichts von `stoerungenProvider`/`montagenProvider` zum Zählen (Kommentare ausgeblendet).
- `test/canvaskit_sichere_widgets_test.dart`: `aufgabe_zeile.dart` und `aufgaben_sheet.dart` in der Dateiliste.
- Bestehende Tests der Detektoren (`aufgaben_regeln_test` o. ä.) bleiben unverändert grün.

## 5. Lieferung

v0.106.0. Sichtprüfung im Browser (Probe wie bei B2): Screen mit allen sechs Quellen auf 360 und 1400 px, Sheet, Glocke-Badge = Kachelzähler. Klicktest Daniel: Glocke zeigt die offene Störung von gestern und die MWST-Erinnerung in derselben Liste; Kachelzähler = Badge; Einplanen aus dem Sheet legt den Einsatz in den Tagesplan; alte Kachel-Routen sind weg.
