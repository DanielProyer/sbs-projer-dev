# Büro-Startseite «Was ist offen?» (B3) — Entwurf

Stand 16.09.2026 · Vorschlag B3 aus `docs/app-analyse-2026-09.md` · setzt B6 (eine Aufgabenliste, v0.106.0) voraus.

## 1. Befund

Die Buchhaltungs-Startseite (`buchhaltung_dashboard_screen.dart`, 481 Zeilen) zeigt vier Kennzahlen und darunter **13 Ziele auf einer Ebene** — Kontenplan neben Bankauszug-Import, Jahresrechnungen neben Lohn. Was **heute offen** ist, steht nirgends (Befund 4 der Analyse).

Die Vorarbeit von B6 ändert die Ausgangslage: Von den fünf Zeilen, die B3 oben zeigen will, existieren drei bereits als Detektoren in `aufgaben_detektoren_provider.dart` — Heineken-Rechnung Vormonat, MwSt-Quartal, Mahnungen fällig —, dazu zwei weitere büro-nahe (fehlende Ertragsbuchungen, Versandvermerke). **Neu zu bauen sind nur zwei:** unverbuchte Bank-Transaktionen und Eingangsrechnungen ohne Zahlung.

## 2. Entscheidungen

1. **Eine Quelle.** Die Offen-Liste ist der Büro-Ausschnitt der Aufgabenliste aus B6 — keine zweite Liste, die auseinanderläuft (genau der Fehler, den B6 behoben hat).
2. **Getrennt wird nach Art, nicht nach Ort: Frist oder Vorrat.** Eine **Frist** hat einen Stichtag, verpassen kostet — sie bleibt in der Glocke *und* steht im Büro. Ein **Vorrat** ist ein Stapel ohne Stichtag — er steht nur im Büro und im Aufgaben-Screen. «23 unverbuchte Bank-Buchungen» ist kein Alarm am Berg.
3. **Die vier Kennzahlen bleiben**, rücken aber unter die Offen-Liste. Am PC kosten sie nichts und geben beim Öffnen das Lagebild.
4. **Die 13 Ziele in zwei Gruppen:** Laufend · Abschluss & Berichte.
5. **`_NavTile` wird CanvasKit-sicher** — 13 Navigationsziele aus `ListTile` sind zu viel Risiko für die bestätigte Falle.

## 3. Bauteile

### 3.1 Frist oder Vorrat — `lib/core/util/aufgaben_regeln.dart` und `aufgabe.dart`

`Aufgabe` bekommt ein Feld:

```dart
  /// Ein Stapel ohne Stichtag (Bank-Prüfliste, offene Eingangsrechnungen,
  /// fehlende Buchungen). Steht im Büro und im Aufgaben-Screen, aber nicht
  /// in der Glocke — dort gehören nur Dinge mit Frist hin.
  final bool istVorrat;
```

Vorgabe `false` (= Frist), damit bestehende Detektoren unverändert weiterlaufen. `AufgabenEintrag` (B6) reicht das Feld durch.

Zwei reine Funktionen in `lib/core/util/aufgabe.dart`:

- `jetztFaellig(a, heute)` bekommt eine Zeile dazu: ein Eintrag mit `istVorrat` ist **nie** jetzt fällig. Damit verschwinden Vorräte aus Glocke, Startkarte, Kachelzähler und Sheet — der Aufgaben-Screen zeigt sie weiter (er zeigt alles).
- `bool istBueroAufgabe(AufgabenEintrag a)`: wahr, wenn `a.route` unter `/buchhaltung`, `/rechnungen` oder `/heineken` liegt. **Die Büro-Zugehörigkeit folgt aus dem Ziel, nicht aus einem zweiten Pflegefeld** — ein neuer Detektor, der in die Buchhaltung führt, erscheint dort von selbst; Saisondaten (`/touren`) fällt automatisch heraus.

### 3.2 Einordnung der bestehenden sechs Detektoren

| Detektor | Route | Art | Glocke |
|---|---|---|---|
| Heineken-Rechnung Vormonat | `/heineken` | Frist | ja |
| MwSt-Quartal | `/buchhaltung/mwst` | Frist | ja |
| Mahnlauf | `/buchhaltung/mahnwesen` | Frist | ja |
| Saisondaten | `/touren` | Frist | ja (kein Büro) |
| Fehlende Ertragsbuchungen | `/rechnungen` | **Vorrat** | nein (neu) |
| Versandvermerke | `/rechnungen` | **Vorrat** | nein (neu) |

Die letzten zwei verschwinden aus der Glocke. Sie sind Stapel, keine Termine — und sie stehen künftig dort, wo sie abgearbeitet werden.

### 3.3 Zwei neue Detektoren

Beide in `aufgaben_detektoren_provider.dart`, beide `istVorrat: true`, beide in try/catch wie die übrigen (ein gefallener Detektor darf die Liste nicht leeren), beide als reine Regelfunktion in `aufgaben_regeln.dart` (`bankPrueflisteAufgabe(int anzahl)`, `eingangsrechnungenAufgabe(int anzahl)`) — dieselbe Bauart wie `mahnlaufAufgabe`, damit sie ohne Supabase testbar sind:

- **Bank-Prüfliste:** «N Bank-Buchungen prüfen», Quelle `camtPrueflisteProvider` (liefert die offenen Einträge), Route `/buchhaltung/camt-pruefliste`, Schlüssel `bank_pruefliste`.
- **Eingangsrechnungen ohne Zahlung:** «N Eingangsrechnungen offen», Quelle `eingangsrechnungenProvider`, gezählt werden die Status `erkannt`, `bestaetigt`, `gebucht` — alles vor `zahlung_vorgemerkt`. Route `/buchhaltung/eingangsrechnungen`, Schlüssel `eingangsrechnungen_offen`.

Beide sind snoozebar (sie sind Detektoren), aber nicht manuell erledigbar — erledigt sind sie, wenn der Stapel leer ist.

### 3.4 Der Offen-Block — `lib/presentation/widgets/buero_offen_block.dart`

`BueroOffenBlock(eintraege, heute, …Aktionen)` — reine Darstellung: Überschrift «Was ist offen?», darunter die Einträge als `AufgabeZeile` (B6, unverändert wiederverwendet), **Fristen zuerst, dann Vorräte**, innerhalb der Gruppe nach Fälligkeit. Leer → «Nichts offen 🎉» in `textSecondary`. Dorthin, Snooze und Erledigt laufen über `AufgabenAktionen` (B6), also ohne neuen Code.

### 3.5 Der Screen

`BuchhaltungDashboardScreen` bekommt zuoberst den Offen-Block (gespeist aus `aufgabenListeProvider`, gefiltert mit `istBueroAufgabe`), darunter unverändert die vier Kennzahl-Karten und die `_BankWaechterCard`, darunter die 13 Ziele in zwei Gruppen mit Zwischenüberschrift:

- **Laufend:** Bankauszug Import · Eingangsrechnungen · Forderungen · Heineken Rechnungen · Lohnbuchhaltung.
- **Abschluss & Berichte:** Kontenplan · Journal · Bilanz & Erfolgsrechnung · Auswertung · MwSt-Abrechnung · Abschlussprüfung · Steuern · Jahresrechnungen.

Abweichung von der Analyse: Sie ordnete Lohn dem Rest zu; ein Lohnlauf ist monatlich und gehört zu «Laufend».

`_NavTile` wird von `ListTile` auf `InkWell` + `Container` + `Row` umgebaut (Vorbild `EinsatzZeile` aus B2) — Aussehen gleich, Bauart CanvasKit-sicher.

## 4. Tests

- `test/aufgabe_test.dart` erweitert: `jetztFaellig` mit `istVorrat` (nie jetzt fällig, egal welche Quelle); `istBueroAufgabe` für die drei Präfixe, für `/touren` (falsch) und für `route == null` (falsch).
- `test/aufgaben_regeln_test.dart` erweitert: `bankPrueflisteAufgabe` und `eingangsrechnungenAufgabe` — 0 ergibt `null`, N>0 ergibt Titel mit Zahl, Route und `istVorrat: true`; Einzahl/Mehrzahl.
- `test/buero_offen_block_test.dart` (Roboto, 360 px und 1400 px): Reihenfolge Fristen vor Vorräten, Leerzustand, Aktionen melden den Eintrag, kein `ListTile`.
- `test/buchhaltung_gruppen_waechter_test.dart`: Jedes der 13 Ziele steht in genau einer Gruppe — der Wächter liest den Screen und vergleicht die Routen gegen die beiden Listen, damit ein neues Ziel nicht heimatlos bleibt.
- `test/canvaskit_sichere_widgets_test.dart`: `buchhaltung_dashboard_screen.dart` und `buero_offen_block.dart` in die Dateiliste.
- Bestehende Tests der Glocke und des Aufgaben-Screens bleiben grün — der Vorrat ändert nur, was `jetztFaellig` liefert.

## 5. Lieferung

v0.108.0. Sichtprüfung im Browser auf 360 px und 1400 px (Wegwerf-Probe wie bei B1/B2/B6): Offen-Block mit Fristen und Vorräten, Leerzustand, die zwei Gruppen, `_NavTile` in neuer Bauart.

Klicktest Daniel: Die Büro-Startseite zeigt oben, was offen ist · Bank-Prüfliste und offene Eingangsrechnungen stehen dort, **nicht** in der Glocke · MwSt und Heineken-Rechnung weiterhin in beiden · Snooze auf einer Büro-Zeile wirkt auch in der Glocke · die 13 Ziele stehen in zwei Gruppen.
