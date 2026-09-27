# Fahrten aus der Kette (Fahrtenerkennung Stufe 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aus den Ereignissen eines Arbeitstags (Arbeitsbeginn, Einsätze, Feierabend) die Fahrten ableiten, je Fahrt Kilometer aus gerouteten Distanzen berechnen, die Tagessumme gegen den Zählerstand prüfen und alles in der Arbeitstag-Auswertung zeigen. Kein GPS-Tracking, kein Steuerbeleg (Entscheid Daniel 27.09.2026).

**Architecture:** Reine Dart-Regeln in `lib/core/util/fahrten_aus_kette.dart` (Halte → Fahrten → Tages-Befund), Datenbeschaffung in `lib/presentation/providers/fahrten_providers.dart` (vier Monatsabfragen + zwei Distanz-Nachschlagewerke), Anzeige in der bestehenden Arbeitstag-Auswertung (Zeile je Tag) plus neuem Detail-Screen. Distanzen: Startort→Betrieb aus `anfahrtszeiten.distanz_km` (liegt vor), Betrieb→Betrieb aus `fahrzeiten.distanz_km` (neu, gefüllt von der Edge Function `fahrzeit-route`), Rückfall Luftlinie × kalibrierter Umwegfaktor.

**Tech Stack:** Flutter Web (CanvasKit — nur `TapKnopf`/InkWell+Container), Riverpod, Supabase (Migration 210, Edge Function Deno), bestehende Helfer `haversineKm`, `minutenAusHhmm`, `startortSchluessel`, `kStartorte`, `wegpunkteFuerTagProvider`, `betriebLookupProvider`.

**Hintergrund:** `docs/analyse-2026-09-26-fahrtenerkennung.md` §5 Stufe 1. Daten (Stand 27.09.): 33 Arbeitstage seit August, 34 Tage mit beiden Zählerständen, 213 Reinigungen seit August alle mit `uhrzeit_start/ende`, 34 von 36 Störungen OHNE `arbeit_von` (Zeit dafür aus dem Wegpunkt-Stempel `quelle='stoerung'`, `referenz_id` = Störung), 802 Anfahrten mit `distanz_km`, 3594 `fahrzeiten` ohne Distanz.

**Regeln (fachlich, verbindlich):**
- Halt = Startort (morgens ab `arbeitsbeginn`, abends ab `arbeitsende`) oder Betrieb (Einsatz). Startort-Schlüssel aus `start_lat/lng` bzw. `end_lat/lng` via `startortSchluessel()`, ohne GPS `'domat_ems'`.
- Einsatz-Zeit: Reinigung `uhrzeit_start/ende`; Störung/Montage `arbeit_von/bis`, sonst Wegpunkt-Stempel (`referenz_id` = Einsatz-Id, oder `betrieb_id` + Tag) als Punkt-Halt (Ankunft = Abfahrt = Stempel); sonst «ohne Zeit» → nicht in den Fahrten, aber als Befund.
- Aufeinanderfolgende Halte am selben Betrieb mit Lücke ≤ 15 min verschmelzen (Ankunft = früheste, Abfahrt = späteste).
- Fahrt = zwei aufeinanderfolgende Halte mit verschiedener Id. Abfahrt = Abfahrt des ersten, Ankunft = Ankunft des zweiten. Ohne `arbeitsende` gibt es keinen Heimweg (Befund «Feierabend fehlt»).
- km je Fahrt: Startort↔Betrieb aus `anfahrtszeiten.distanz_km` (Richtung egal); Betrieb→Betrieb aus `fahrzeiten.distanz_km` (beide Richtungen prüfen wie `FahrzeitRepository.ausMap`); sonst Luftlinie × `umwegFaktor(luftlinieKm)` (aus `fahrzeit.dart`, Faktor 1.45 + 0.75·e^(−km/18)) mit Quelle `luftlinie`.
- Tages-Befund: Zähler-km (`km_stand − km_start`, Regel `tagesKm`) minus Fahrten-km = Differenz. Befund, wenn |Differenz| > max(5 km, 5 % des Zählers). Positive Differenz «unerklärt (privat/Umweg?)», negative «Zähler kleiner als Fahrten — Tippfehler?». Weitere Befunde: Einsätze ohne Zeit, Fahrten ohne Distanz (nur Luftlinie), fehlender Feierabend, fehlende Zählerstände.
- Nichts wird gespeichert; alles ist aus den Ereignissen ableitbar. (Stufe 2 würde `fahrten` persistieren.)

---

### Task 1: Migration 210 + Edge Function `fahrzeit-route` liefert Distanz

**Files:**
- Create: `Datenbank/migrations/210_fahrzeiten_distanz.sql`
- Modify: `supabase/functions/fahrzeit-route/index.ts`

- [ ] **Migration schreiben** (wird vom Orchestrator per MCP angewendet, NICHT selbst ausführen):

```sql
-- 210: Distanz je Fahrzeit-Paar (Fahrtenerkennung Stufe 1, 27.09.2026).
-- `fahrzeiten` kannte nur Minuten; für «Fahrten aus der Kette» braucht es die
-- Strecke. Gefüllt von der Edge Function fahrzeit-route (OSRM), nachträglich
-- beim ersten Bedarf. Luftlinien-Rückfall rechnet die App selbst und speichert
-- ihn NICHT (er ist kein Messwert).
alter table fahrzeiten
  add column if not exists distanz_km numeric(6,1),
  add column if not exists distanz_quelle text
    check (distanz_quelle in ('osrm', 'google'));
comment on column fahrzeiten.distanz_km is 'Strecke in km (eine Nachkommastelle), Quelle siehe distanz_quelle';
```

- [ ] **Edge Function:** In `index.ts` beim OSRM-Routing zusätzlich `route.distance` (Meter) lesen → `distanz_km = Math.round(distance / 100) / 10`, im Upsert `distanz_km` und `distanz_quelle: 'osrm'` mitschreiben (auch im `update`-Zweig für bestehende Zeilen, wenn `distanz_km` null ist — analog `referenz_minuten`), `cacheLookup` selektiert `minuten, quelle, distanz_km` und liefert sie; die JSON-Antwort bekommt `distanzKm` (nullable). Bestehendes Verhalten (Minuten, Cache, Referenz) unverändert. Lies zuerst die ganze Datei (207 Zeilen).
- [ ] `deno check supabase/functions/fahrzeit-route/index.ts` falls Deno lokal vorhanden ist (sonst überspringen und im Bericht sagen). Deploy macht der Orchestrator.
- [ ] Commit: `feat(fahrzeit-route): Distanz je Paar speichern (Migration 210)`.

### Task 2: Reine Regeln `fahrten_aus_kette.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/fahrten_aus_kette.dart`
- Modify: `sbs_projer_app/lib/core/util/fahrzeit.dart` (Funktion `umwegFaktor(double luftlinieKm)` herausziehen und in `reineFahrzeitMinuten` verwenden — Verhalten identisch)
- Test: `sbs_projer_app/test/fahrten_aus_kette_test.dart`, `sbs_projer_app/test/fahrzeit_test.dart` (falls vorhanden ergänzen)

- [ ] **Typen** (Minuten des Tages als `int`, wie `minutenAusHhmm`):

```dart
enum HaltTyp { startort, betrieb }

class Halt {
  final HaltTyp typ;
  final String id;          // Startort-Schlüssel ('domat_ems'/'chur') oder betriebId
  final String name;
  final double? lat, lng;
  final int? ankunftMin;    // null nur bei Startort morgens
  final int? abfahrtMin;    // null nur bei Startort abends
  final String quelle;      // 'arbeitsbeginn','reinigung','stoerung','montage','wegpunkt','feierabend'
}

class EinsatzHalt {         // Eingabe je Einsatz, vor der Zeit-Auflösung
  final String einsatzId, typ; // 'reinigung' | 'stoerung' | 'montage'
  final String? betriebId, betriebName;
  final double? lat, lng;
  final String? von, bis;   // 'HH:mm' oder null
  final DateTime? stempel;  // Wegpunkt-Zeitpunkt (lokal), wenn keine Zeiten
}

class Fahrt {
  final Halt von, nach;
  final int? abfahrtMin, ankunftMin;
  int? get dauerMin;
  final double? km;
  final String? kmQuelle;   // 'anfahrt', 'route', 'luftlinie'
}

class TagesFahrten {
  final List<Fahrt> fahrten;
  final List<EinsatzHalt> ohneZeit;
  final double kmFahrten;        // Summe aller Fahrten mit km
  final int fahrtenNurLuftlinie; // Anzahl mit kmQuelle 'luftlinie'
  final int? kmZaehler;          // tagesKm(kmStart, kmEnde)
  double? get differenz;         // kmZaehler − kmFahrten, null ohne Zähler
  final List<String> befunde;
}

typedef KmNachschlag = ({double km, String quelle})? Function(Halt von, Halt nach);
```

- [ ] **Funktionen** (alle rein, ohne Flutter/Supabase):
  - `List<Halt> halteAusKette({required String? arbeitsbeginn, required String? arbeitsende, required String startortMorgen, required String startortAbend, required List<EinsatzHalt> einsaetze, required DateTime datum, int verschmelzenBisMin = 15})` → sortiert nach Ankunft; Einsätze ohne Zeit werden ausgelassen (siehe `einsaetzeOhneZeit`); Startorte aus `kStartorte`-Koordinaten (die Funktion nimmt eine Map `startorte` als Parameter, damit sie testbar bleibt).
  - `List<EinsatzHalt> einsaetzeOhneZeit(List<EinsatzHalt>)`.
  - `List<Fahrt> fahrtenAusHalten(List<Halt> halte, KmNachschlag km)`.
  - `TagesFahrten tagesFahrten({required List<Halt> halte, required List<EinsatzHalt> ohneZeit, required KmNachschlag km, int? kmStart, int? kmEnde, required bool feierabendErfasst})` mit den Befunden aus den Regeln oben (Texte deutsch, mit Zahlen: «Zähler 148 km, Fahrten 132 km — 16 km unerklärt (privat oder Umweg?)», «Fahrten 152 km liegen über dem Zähler 148 km — Zählerstand prüfen», «2 Einsätze ohne Zeit — nicht in den Fahrten», «3 von 7 Fahrten nur als Luftlinie geschätzt», «Kein Feierabend erfasst — Heimweg fehlt», «Zählerstand fehlt — keine Kontrolle möglich»).
  - `double luftlinieStreckeKm(double luftlinieKm)` = `luftlinieKm * umwegFaktor(luftlinieKm)`.
  - `String kmText(double km)` → «12.3 km» (eine Nachkommastelle, Punkt wie im Rest der App — prüfe `chf_format`/bestehende km-Anzeigen und halte dich daran).
- [ ] **Tests zuerst** (mindestens): Sortierung; Verschmelzen ≤ 15 min am selben Betrieb, nicht > 15 min, nicht bei anderem Betrieb; Reinigung mit Zeiten; Störung ohne Zeiten mit Stempel → Punkt-Halt; Störung ohne alles → `ohneZeit`; Fahrt von Startort zur ersten Reinigung; Heimweg nur mit `arbeitsende`; km über Nachschlag, Rückfall Luftlinie mit Quelle; Befunde: Differenz +16 bei Zähler 148 (Befund), +3 bei 148 (kein Befund), −4 (Befund «prüfen»), ohne Zähler; `umwegFaktor` liefert dieselben Minuten wie vorher (Vergleich `reineFahrzeitMinuten` an drei Distanzen mit den bisherigen Werten, z. B. 104 km ≈ 117 min).
- [ ] Implementieren, `flutter test`, Commit: `feat(fahrten): Regeln Fahrten aus der Kette (Halte, Fahrten, Tages-Befund)`.

### Task 3: Daten laden — Provider und Repository-Abfragen

**Files:**
- Create: `sbs_projer_app/lib/presentation/providers/fahrten_providers.dart`
- Modify: `sbs_projer_app/lib/data/repositories/reinigung_repository.dart` (Monatsabfrage mit Zeiten), `stoerung_repository.dart`, `montage_repository.dart` (Monatsabfrage `id, betrieb_id, datum, arbeit_von, arbeit_bis`), `wegpunkt_repository.dart` (Monatsabfrage), `fahrzeit_repository.dart` (`ladeAlle` liefert zusätzlich `distanzKm`, `distanzQuelle`; `routeAnfordern` liest `distanzKm`), `tour_providers.dart` (`anfahrtszeitenProvider` unverändert lassen; NEU `anfahrtsDistanzenProvider`: `startort, betrieb_id, distanz_km`)
- Test: `sbs_projer_app/test/fahrten_providers_test.dart` (reine Zusammenbau-Funktion), Pagination-Wächter bleibt grün

- [ ] **Monatsabfragen** (je eine Query, Web-Pfad; native Isar-Pfad analog über `IsarService`, wenn vorhanden, sonst wie andere Monatsabfragen): Tagesplaene des Monats liefert `arbeitstageProvider` schon (erweitere die Auswahl um `start_lat, start_lng, end_lat, end_lng` — Typ `ArbeitstagRohdaten` entsprechend), Reinigungen abgeschlossen im Monat (`datum, betrieb_id, uhrzeit_start, uhrzeit_ende`), Störungen und Montagen im Monat (`id, betrieb_id, datum, arbeit_von, arbeit_bis`), Wegpunkte im Monat (`zeitpunkt, quelle, betrieb_id, referenz_id`). Alle mit `.order('datum')`/`.order('zeitpunkt')` und `.order('id')` als letztem Schlüssel (CLAUDE.md-Regel), ohne `.neq()` auf nullbaren Spalten.
- [ ] **Reine Zusammenbau-Funktion** `Map<DateTime, TagesFahrten> monatsFahrtenBauen({...})` in `fahrten_providers.dart` oder besser in `lib/core/util/fahrten_aus_kette.dart` (testbar): baut je Tag `EinsatzHalt`-Liste (Betriebsname/Koordinaten aus einer `Map<String, ({String name, double? lat, double? lng})>`), Startorte via `startortSchluessel` (Rückfall `'domat_ems'`), km-Nachschlag aus `anfahrten` (`Map<String startort, Map<String betriebId, double km>>`) und `fahrzeiten` (`Map<'von>nach', double>` beide Richtungen), Luftlinie-Rückfall.
- [ ] **Provider** `monatsFahrtenProvider = FutureProvider.family<Map<DateTime, TagesFahrten>, AuswertungsMonat>` (autoDispose), der die vier Monatsabfragen, `betriebLookupProvider`, `anfahrtsDistanzenProvider` und `FahrzeitRepository.ladeAlle()` zusammenführt. `tagesFahrtenProvider(datum)` = `monatsFahrtenProvider(monat)[datum]`.
- [ ] **Fehlende Betrieb→Betrieb-Distanzen nachholen:** Nach dem Bau sammelt der Provider die Paare mit Quelle `luftlinie`, deren beide Betriebe Koordinaten haben, und ruft für höchstens **10 Paare je Ladevorgang** `FahrzeitRepository.routeAnfordern` auf (fire-and-forget, `unawaited`, Fehler still); bei ≥ 1 Erfolg `ref.invalidate` des Monats-Providers nach Abschluss (Muster `tourenplanung_screen.dart:2236`). Ein Wächter-Kommentar erklärt die 10 (OSRM-Demo-Server, keine Massenabfragen).
- [ ] Tests: Zusammenbau an einem Beispieltag (2 Reinigungen, 1 Störung mit Stempel, Feierabend) → 4 Fahrten, km-Quellen korrekt, Befund-Text. Commit: `feat(fahrten): Monats-Provider Fahrten aus der Kette, Distanzen aus anfahrtszeiten/fahrzeiten`.

### Task 4: Anzeige — Auswertungszeile und Detail-Screen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/auswertungen/arbeitstag_auswertung_screen.dart` (`_TagesZeile` ~Z. 417: zweite Textzeile ergänzen «Fahrten 132 km · Δ −16» — Δ rot bei Befund, grau sonst; Zeile antippbar → Detail; `_Kennzahlen` optional um «Fahrten-km Monat» ergänzen, wenn es ohne Umbau passt)
- Create: `sbs_projer_app/lib/presentation/screens/auswertungen/tages_fahrten_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart` (Route `/auswertungen/arbeitstage/:datum/fahrten`), Erreichbarkeits-/Routen-Wächtertests (grep `touren/karte` in `test/`, dort analog eintragen)

- [ ] **Detail-Screen** `TagesFahrtenScreen(datum)`: AppBar «Fahrten · Mo 28.09.» mit `RueckwegKnopf(fallback: '/auswertungen/arbeitstage')`; Kopfkarte (`DetailKarte`/`InfoZeile` aus `widgets/detail/`): Fahrten-km, Zähler-km, Differenz (farbig), Anzahl Fahrten; Befunde als Liste mit Warn-Icon; dann je Fahrt eine Karte: «07:41 → 08:28 · 47 min», «Peppino → Holländer», «12.3 km» mit Quellen-Hinweis («gerouted» / «Anfahrt» / «≈ Luftlinie»); zuletzt «Einsätze ohne Zeit» (Name, Typ). Lade-/Fehlerzustand mit `TapKnopf('Erneut laden')`. 360 px: keine horizontale Scrollung, kein Material-Button (CanvasKit-Ratsche darf nicht steigen).
- [ ] **Auswertungszeile**: `InkWell` um die Card, `context.push('/auswertungen/arbeitstage/${datumStr}/fahrten')`; Text «Fahrten 132 km · Δ −16 km» nur, wenn `TagesFahrten` für den Tag vorliegt; solange der Provider lädt, nichts anzeigen (kein «0 km»).
- [ ] `flutter analyze` 0, `flutter test` grün (Ratsche, Routen-Wächter, Gefahr-Knopf). Commit: `feat(auswertung): Fahrten je Tag mit Zähler-Kontrolle, Detail-Screen`.

### Task 5: Abschluss (Orchestrator)

- [ ] Migration 210 per MCP `apply_migration` anwenden; Edge Function deployen: `npx supabase functions deploy fahrzeit-route --project-ref pltbaqqwpnmdajwgnhpd`; Probe: ein Paar routen, `distanz_km` gefüllt.
- [ ] Review (Opus), Nachbesserungen.
- [ ] Browser (360 px): Auswertung September, Zeile mit Fahrten-km, Detail-Screen für den 25.09. (6 Einträge im Plan, Zähler vorhanden?), Befunde lesbar.
- [ ] Version 0.147.0+800, Chronik, ToDo (Klicktest, offene Punkte: Startseite-Zeile nach Feierabend, Fahrzeit-Lernen mit km), Projekt.md (neues Modul), Memory `fahrtenerkennung.md`; Commit, Push, Deploy, Live-Version prüfen.
