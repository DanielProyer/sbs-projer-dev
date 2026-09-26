# Touren auf einen anderen Tag verschieben — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein geplanter Stopp oder ein ganzer Tagesplan lässt sich mit zwei Tipps auf einen anderen Tag verschieben (Daniel, 26.09.2026: «einfacher Weg um geplante Touren zu verschieben auf einen anderen Tag»).

**Architecture:** Reine Regel-Funktionen in `lib/core/util/tagesplan_verschieben.dart` (welche Einträge, Rückfrage-Text, Ruhetags-Warnung) + ein Helfer `eintraegeInTagesplanAnhaengen` in `tour_providers.dart` (ein Speichern für den Zieltag). Zwei Einstiege in `tourenplanung_screen.dart`: Block-Sheet «Auf anderen Tag verschieben» und Kopfzeilen-Menü «Ganzen Tag verschieben». Störung/Montage ziehen ihr `geplant_am` mit (Repository `einplanen`).

**Tech Stack:** Flutter Web (CanvasKit — nur `TapKnopf`/`GestureDetector`, Menü als `PopupMenuButton` wie in `anlage_detail_screen.dart`), Riverpod, Supabase `tagesplaene`. Datumsauswahl über `zeigeDatumsauswahl`, Rückfrage über `gefahrRueckfrage` (nur bei Ganzer-Tag) bzw. normaler Dialog.

**Verhaltensregeln (Entscheide, ohne Rückfrage an Daniel — Standardannahmen):**
- Erledigte Stopps (heute schon abgeschlossene Reinigung des Betriebs bzw. Störung/Montage mit Wegpunkt-Stempel) werden beim Tag-Verschieben **nicht** mitgenommen; im Block-Sheet ist die Aktion für erledigte und für `hist_`-Einträge ausgeblendet.
- Zieltag: nur Datumsauswahl (keine Schnellwahl), `erstes` = heute, `letztes` = heute + 365 Tage, `initial` = Plantag + 1. Zieltag == Plantag → nichts tun.
- Zieltag-Plan: Einträge werden **ans Ende** angehängt; ein Eintrag, dessen `id` dort schon steht, wird nicht doppelt aufgenommen (der Zieleintrag bleibt). `ankerZeit`/`dauerMinuten`/`anlageIds` bleiben erhalten, `uebernommen` bleibt, `istAutoTermin` wird über `alsPlanEintrag()` abgelegt.
- Arbeitstag-Rahmen (Beginn/Ende/km) des alten Tages bleibt unberührt.
- Rückfrage beim ganzen Tag: «5 Stopps auf Di 29.09. verschieben?» + Zeile «Dort stehen schon 3 Stopps.» (wenn > 0) + Zeile «Ruhetag am Zieltag: Rössli, Pöstli» (wenn `istRuhetag(e.ruhetage, ziel)` für Einträge zutrifft) + «2 erledigte Stopps bleiben hier.» (wenn > 0). Bestätigen-Knopf «Verschieben» — kein Gefahr-Rot (nicht destruktiv, umkehrbar), also `showDialog` mit `TapKnopf(text: 'Verschieben')` und `TapKnopf(text: 'Abbrechen', primaer: false)`.
- Einzelner Stopp: keine Rückfrage, aber bei Ruhetag am Zieltag ein Hinweis-Dialog «Rössli hat am Di Ruhetag. Trotzdem verschieben?» (Verschieben / Abbrechen).
- Danach SnackBar «5 Stopps auf Di 29.09. verschoben» mit Action «Anzeigen» → `context.push('/touren?datum=YYYY-MM-DD')`.
- Störung/Montage (`id` beginnt mit `s_`/`m_`): zusätzlich `StoerungRepository.einplanen`/`MontageRepository.einplanen(id: id.substring(2), tag: ziel, zeit: e.ankerZeit, dauerMin: e.dauerMinuten ?? kDauerDefaultMinuten)` + Stream invalidieren (Muster `_einsatzEinplanungZurueckschreiben`). Heigenie-Typ (`TourEintragTyp.heigenie`, falls vorhanden) wie Reinigung behandeln (nur Plan).

---

### Task 1: Regel-Funktionen (rein, getestet)

**Files:**
- Create: `sbs_projer_app/lib/core/util/tagesplan_verschieben.dart`
- Test: `sbs_projer_app/test/tagesplan_verschieben_test.dart`

- [ ] Schreibe Tests (TDD) für:

```dart
/// Welche Einträge beim Tag-Verschieben mitgehen: nicht erledigt, keine hist_.
List<TourEintrag> verschiebbareEintraege(
  List<TourEintrag> plan, Set<String> erledigteIds);

/// Einträge des Zieltags nach dem Anhängen: bestehende zuerst, neue ans Ende,
/// keine doppelte id (bestehender Eintrag gewinnt).
List<TourEintrag> planNachAnhaengen(
  List<TourEintrag> ziel, List<TourEintrag> neu);

/// Betriebsnamen (ohne Doppel, Reihenfolge des Plans), die am Zieltag Ruhetag haben.
List<String> ruhetagBetriebe(List<TourEintrag> eintraege, DateTime ziel);

/// Text für die Rückfrage beim ganzen Tag (siehe Verhaltensregeln).
String verschiebenRueckfrageText({
  required int anzahl, required DateTime ziel, required int schonDort,
  required List<String> ruhetag, required int erledigt});

/// «5 Stopps auf Di 29.09. verschoben» / «1 Stopp auf …».
String verschobenText(int anzahl, DateTime ziel);
```

  Datum formatiert wie im Header: `DateFormat('EE, d. MMM', 'de_CH')` → nutze in Tests `initializeDateFormatting('de_CH')` (siehe bestehende Tests, z. B. grep `initializeDateFormatting` in `test/`). Falls das in reinen Tests Umstände macht: eigene Kurzformat-Funktion `kurzTag(DateTime)` = `'${wochentagKuerzel} ${d.d}.${MM}.'` (Mo/Di/Mi/Do/Fr/Sa/So) ohne intl — bevorzugt, weil deterministisch.
- [ ] Implementieren, Tests grün, commit `feat(touren): Regeln fürs Verschieben von Tagesplan-Einträgen`.

### Task 2: Erledigt-Ermittlung teilen + Helfer im Provider

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` (~Z. 1415–1475, `istZeiten`)

- [ ] In `tour_providers.dart` ergänzen:

```dart
/// Hängt [neu] an den gespeicherten Plan von [tag] an (ein Speichern), ohne
/// doppelte ids. Läuft der Screen gerade auf [tag], über den Notifier.
/// Liefert die Zahl der bereits dort stehenden Einträge (für die Rückfrage
/// vorher separat via [gespeicherterTagesplanProvider] lesen).
Future<void> eintraegeInTagesplanAnhaengen(
  WidgetRef ref, DateTime tag, List<TourEintrag> neu) async { … }
```
  Muster wie `einsatzInTagesplanAufnehmen`, aber ein einziger `tagesplanSpeichern`-Aufruf und `planNachAnhaengen` aus Task 1.
- [ ] Die Ist-Zeiten-Berechnung (`istZeiten`) in der Zeitachse in eine Funktion des Screens/States auslagern, sodass die Menge der erledigten ids (`istZeiten.keys`) auch dem Tag-Verschieben zur Verfügung steht. Am einfachsten: `_TagesplanZeitachseState` berechnet sie bereits — ziehe die Berechnung in eine top-level Funktion `Map<String, ({int von, int bis})> ermittleIstZeiten({required List<TourEintrag> eintraege, required DateTime datum, required bool erledigtePruefen, required List<ReinigungLocal> reinigungen, required List<WegpunktTag> wegpunkte, required int Function(TourEintrag) dauerFuer})` in `tourenplanung_screen.dart` (oder eigene Datei `lib/core/util/tagesplan_ist_zeiten.dart` wenn ohne Provider-Import möglich) und rufe sie an beiden Stellen auf. Verhalten der Zeitachse darf sich nicht ändern.
- [ ] `flutter test`, commit `refactor(touren): Ist-Zeiten-Ermittlung geteilt, Plan-Anhängen als Helfer`.

### Task 3: Block-Sheet «Auf anderen Tag verschieben»

**Files:**
- Modify: `tourenplanung_screen.dart` `_BlockSheet` (vor «Aus Plan entfernen», ~Z. 2076)

- [ ] `_SheetAktion(icon: Icons.event_repeat, text: 'Auf anderen Tag verschieben', onTap: …)` — ausgeblendet, wenn `eintragId.startsWith('hist_')` oder der Eintrag erledigt ist (das Sheet kennt die erledigten ids nicht — übergib `erledigt: bool` beim Öffnen des Sheets aus der Zeitachse, `istZeiten.containsKey(eintrag.id)`).
- [ ] Ablauf: `Navigator.pop`, `zeigeDatumsauswahl` (Regeln oben), `== datum` → return; Ruhetag → Hinweis-Dialog; dann: bei `s_`/`m_` Repository `einplanen` (await) + Invalidierung; `ref.read(tagesplanProvider.notifier).entfernen(id)`; `eintraegeInTagesplanAnhaengen(ref, ziel, [eintrag.alsPlanEintrag()])`; SnackBar mit «Anzeigen». Achte auf `context.mounted` nach jedem await. Beim Anhängen `geplantAm: ziel` im Eintrag setzen, wenn Störung/Montage (copyWith vorhanden? sonst neuen `TourEintrag` bauen — prüfe, ob `TourEintrag` ein `copyWith` hat; wenn nicht, ergänze eines nur mit den nötigen Feldern).
- [ ] Commit `feat(touren): Stopp auf anderen Tag verschieben (Block-Sheet)`.

### Task 4: Kopfzeile «Ganzen Tag verschieben»

**Files:**
- Modify: `tourenplanung_screen.dart` `_TagesplanHeader` (~Z. 1029) + State (`_tagesplanLeeren` daneben, ~Z. 881)

- [ ] Kopfzeile muss auf 360 px passen: den roten `clear_all`-IconButton durch einen `PopupMenuButton<String>(icon: Icon(Icons.more_vert, size: 20), …)` ersetzen mit zwei Einträgen: «Ganzen Tag verschieben…» (`Icons.event_repeat`) und «Tagesplan leeren…» (rot, `Icons.clear_all`). Neuer Callback `onTagVerschieben` im Header.
- [ ] State-Methode `_ganzenTagVerschieben()`: `plan = ref.read(tagesplanProvider)`; erledigte ids über die geteilte Funktion aus Task 2 (gleiche Eingaben wie die Zeitachse: `reinigungenProvider`, `wegpunkteFuerTagProvider(_selectedDate)`, Dauer-Funktion); `verschiebbar = verschiebbareEintraege(plan, erledigt)`; leer → SnackBar «Nichts zu verschieben». Datumsauswahl; `schonDort = (await ref.read(gespeicherterTagesplanProvider(ziel).future))?.eintraege.length ?? 0`; Rückfrage-Dialog (Text aus Task 1, Knöpfe `TapKnopf`); dann: Störungen/Montagen `einplanen` (await alle, `Future.wait`), `eintraegeInTagesplanAnhaengen(ref, ziel, verschiebbar.map(alsPlanEintrag + geplantAm))`, danach jeden verschobenen Eintrag per `notifier.entfernen(id)` aus dem aktuellen Tag; Streams invalidieren; SnackBar mit «Anzeigen».
- [ ] Reihenfolge wichtig: **erst** am Zieltag anhängen, **dann** hier entfernen — bricht das Speichern ab, ist nichts verloren.
- [ ] Commit `feat(touren): ganzen Tagesplan auf anderen Tag verschieben`.

### Task 5: Wächter & Abschluss

- [ ] `test/canvaskit_ratsche_test.dart` muss grün bleiben (kein FilledButton/OutlinedButton neu). `test/gefahr_knopf_waechter_test.dart` grün.
- [ ] `flutter analyze` (14 bekannte Hinweise), `flutter test` alle grün.
- [ ] Bericht mit Status.
