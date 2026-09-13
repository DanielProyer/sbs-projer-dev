# Startseite «Heute» + sprechende Zähler + Direktstart (A1–A3) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`) zur Verfolgung.

**Ziel:** Die Startseite zeigt den heutigen Tagesplan statt eines Menüs, die Kachelzähler zeigen Handlungsbedarf statt Jahrestotale, und ein Einsatz startet dort, wo man gerade steht.

**Architektur:** Drei unabhängige Lieferungen. Die Ableitung «offen / erledigt» wird eine reine Funktion in `core/util/` (testbar ohne Provider-Verdrahtung, Vorbild `besuch_buendelung.dart`); das Widget liest den ohnehin gespeicherten Tagesplan über `gespeicherterTagesplanProvider(heute)`. Keine Migration, kein neues Datenbankfeld, kein neues Modell.

**Tech-Stack:** Flutter · Riverpod · GoRouter · Supabase. Tests mit `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-13-startseite-heute-a1-a3-design.md`

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/core/util/heute_stopps.dart` | Reine Ableitung: Welche Stopps des Tagesplans sind erledigt, welche offen | **Neu** |
| `lib/presentation/providers/heute_providers.dart` | Verdrahtung: Tagesplan + Reinigungen + Störungen/Montagen → Liste offener Stopps | **Neu** |
| `lib/presentation/widgets/heute_liste.dart` | Darstellung der offenen Stopps inkl. Start-Pfeil und Leerzustand | **Neu** |
| `lib/presentation/screens/home_screen.dart` | `_TagesUebersicht` raus, `HeuteListe` rein; Kachelzähler umstellen | Ändern |
| `lib/presentation/providers/kachel_zaehler_providers.dart` | Die sechs neuen, handlungsrelevanten Zähler | **Neu** |
| `lib/core/config/router.dart:247-257` | `/reinigungen/neu` um `anlageIds` erweitern | Ändern |
| `lib/presentation/screens/reinigungen/reinigung_form_screen.dart:48-58` | Konstruktor nimmt `anlageIds` | Ändern |
| `lib/presentation/screens/betriebe/betrieb_detail_screen.dart` | Knopf «Neue Reinigung» im Reinigungs-Abschnitt | Ändern |
| `lib/presentation/screens/touren/tourenplanung_screen.dart` | Menüpunkt «Reinigung beginnen» im Besuchs-Sheet | Ändern |
| `test/heute_stopps_test.dart` | Ableitungslogik | **Neu** |
| `test/heute_liste_test.dart` | Widget: Zeilen, Leerzustand, keine Kürzung bei 13 Stopps | **Neu** |
| `test/kachel_zaehler_test.dart` | Zähler zählen Handlungsbedarf, nicht Jahrestotale | **Neu** |
| `test/reinigung_route_anlagen_test.dart` | `anlageIds` parsen, `anlageId` bleibt gültig | **Neu** |
| `test/canvaskit_sichere_widgets_test.dart` | Neue Regel: Heute-Liste ohne die drei Fallen | Ändern |

**Reihenfolge der Lieferungen:** A2 (Tasks 1–2) → A3 (Tasks 3–6) → A1 (Tasks 7–10). Jede ist einzeln deploybar und einzeln rücknehmbar.

---

# Lieferung 1 — A2: Sprechende Zähler

### Task 1: Zähler-Provider

**Dateien:**
- Erstellen: `lib/presentation/providers/kachel_zaehler_providers.dart`
- Test: `test/kachel_zaehler_test.dart`

Hintergrund: Die Kacheln zeigen heute Jahrestotale (`reinigungCountAktuellesJahrProvider` und Geschwister in `home_screen.dart:94-119`). Die neuen Zähler zählen offene Arbeit. Für «diese Woche» nutzen wir den bestehenden `faelligeAnlagenProvider`, der ein Stichdatum entgegennimmt: Anlagen, die **bis zum kommenden Sonntag** fällig sind.

**Wichtig — Verhältnis zur Tourenplanungs-Kachel:** `faelligeAnlagenProvider(heute).length` ist der bestehende Zähler «97 fällig». Der neue Wochenzähler ist `faelligeAnlagenProvider(sonntag).length` und damit **immer grösser oder gleich** — heute fällig ist eine Teilmenge von diese Woche fällig. Das ist kein Widerspruch, sondern eine Eingrenzung; die beiden Kacheln stehen nebeneinander und müssen so gelesen werden.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```dart
// test/kachel_zaehler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/kachel_zaehler_providers.dart';

void main() {
  group('kommenderSonntag', () {
    test('Samstag → der morgige Sonntag', () {
      expect(
        kommenderSonntag(DateTime(2026, 9, 12)),
        DateTime(2026, 9, 13),
      );
    });

    test('Sonntag → derselbe Tag, nicht eine Woche weiter', () {
      expect(
        kommenderSonntag(DateTime(2026, 9, 13)),
        DateTime(2026, 9, 13),
      );
    });

    test('Montag → der Sonntag am Ende derselben Woche', () {
      expect(
        kommenderSonntag(DateTime(2026, 9, 14)),
        DateTime(2026, 9, 20),
      );
    });

    test('schneidet die Uhrzeit ab', () {
      expect(
        kommenderSonntag(DateTime(2026, 9, 14, 17, 42)),
        DateTime(2026, 9, 20),
      );
    });
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag prüfen**

Ausführen: `flutter test test/kachel_zaehler_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: kachel_zaehler_providers.dart`

- [ ] **Schritt 3: Minimale Umsetzung**

```dart
// lib/presentation/providers/kachel_zaehler_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart'
    show stoerungOffen, montageOffen;
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Der Sonntag, der die Woche von [tag] abschliesst. Fällt [tag] selbst auf
/// einen Sonntag, ist es dieser Tag — nicht der Sonntag darauf.
DateTime kommenderSonntag(DateTime tag) {
  final ohneZeit = DateTime(tag.year, tag.month, tag.day);
  final bisSonntag = DateTime.sunday - ohneZeit.weekday; // Mo=1 … So=7
  return ohneZeit.add(Duration(days: bisSonntag));
}

/// Anlagen, die bis zum Ende dieser Woche fällig werden.
///
/// Obermenge des Tourenplan-Zählers (`faelligeAnlagenCountProvider`, der auf
/// heute steht) — «heute fällig» ist in «diese Woche fällig» enthalten.
final reinigungenDieseWocheProvider = Provider<int>((ref) {
  final sonntag = kommenderSonntag(DateTime.now());
  return ref.watch(faelligeAnlagenProvider(sonntag)).length;
});

final offeneStoerungenCountProvider = Provider<int>((ref) {
  return ref.watch(stoerungenProvider).where((s) => stoerungOffen(s.status)).length;
});

final geplanteMontagenCountProvider = Provider<int>((ref) {
  return ref.watch(montagenProvider).where((m) => montageOffen(m.status)).length;
});
```

Die Zähler für Eigenaufträge und Eröffnungen folgen in Schritt 5 — zuerst muss der Datumshelfer grün sein.

- [ ] **Schritt 4: Test laufen lassen, Erfolg prüfen**

Ausführen: `flutter test test/kachel_zaehler_test.dart`
Erwartet: BESTANDEN, 4 Tests.

- [ ] **Schritt 5: Zähler für Eigenaufträge und Eröffnungen ergänzen**

Prüfe zuerst die tatsächlichen Statuswerte:

```bash
grep -n "status" lib/data/local/eigenauftrag_local.dart | head -5
grep -n "eigenauftraegeProvider\|eroeffnungsreinigungenProvider" lib/presentation/providers/eigenauftrag_providers.dart lib/presentation/providers/eroeffnungsreinigung_providers.dart
```

Laut Analyse schreibt der Code bei Eigenaufträgen nur den Wert `behoben`; ein Eigenauftrag ohne diesen Wert gilt als offen. Ergänze:

```dart
/// Eigenaufträge, die noch nicht auf `behoben` stehen. Der Code schreibt bei
/// diesem Typ nur diesen einen Statuswert (App-Analyse 08.09.2026, Befund 3)
/// — alles andere ist offen.
final offeneEigenauftraegeCountProvider = Provider<int>((ref) {
  return ref.watch(eigenauftraegeProvider).where((e) => e.status != 'behoben').length;
});

/// Eröffnungsreinigungen, die noch anstehen.
final anstehendeEroeffnungenCountProvider = Provider<int>((ref) {
  return ref
      .watch(eroeffnungsreinigungenProvider)
      .where((e) => e.status != 'abgeschlossen')
      .length;
});
```

Passe die Feld- und Providernamen an das an, was `grep` gezeigt hat. Stimmt ein Statuswert nicht mit der Annahme überein, korrigiere den Code — **nicht** den Kommentar.

- [ ] **Schritt 6: Analyse und volle Testsuite**

Ausführen: `flutter analyze`
Erwartet: keine neuen Befunde (56 vorbestehende Infos sind der Normalzustand).

Ausführen: `flutter test`
Erwartet: alle bestanden.

- [ ] **Schritt 7: Commit**

```bash
git add lib/presentation/providers/kachel_zaehler_providers.dart test/kachel_zaehler_test.dart
git commit -m "feat: Zaehler-Provider fuer handlungsrelevante Kachelzahlen (A2)"
```

---

### Task 2: Kacheln auf die neuen Zähler umstellen

**Dateien:**
- Ändern: `lib/presentation/screens/home_screen.dart:92-205` (`_KachelGrid`)

- [ ] **Schritt 1: Zähler-Quellen austauschen**

In `_KachelGrid.build` die alten Jahres-Zähler durch die neuen ersetzen. Vorher (Auszug):

```dart
final reinigungCount = ref.watch(reinigungCountAktuellesJahrProvider);
final stoerungCount = ref.watch(stoerungCountAktuellesJahrProvider);
```

Nachher:

```dart
final reinigungenDieseWoche = ref.watch(reinigungenDieseWocheProvider);
final offeneStoerungen = ref.watch(offeneStoerungenCountProvider);
final geplanteMontagen = ref.watch(geplanteMontagenCountProvider);
final offeneEigenauftraege = ref.watch(offeneEigenauftraegeCountProvider);
```

Import ergänzen:

```dart
import 'package:sbs_projer_app/presentation/providers/kachel_zaehler_providers.dart';
```

- [ ] **Schritt 2: Kacheln anpassen**

Betriebe, Kontakte und Spesen verlieren ihre Zahl (`count: null`), die übrigen bekommen einen sprechenden Text:

```dart
_DashboardTile(
  icon: Icons.store,
  label: 'Betriebe',
  count: null,
  color: AppColors.primary,
  onTap: () => context.push('/betriebe'),
),
_DashboardTile(
  icon: Icons.cleaning_services,
  label: 'Reinigungen',
  count: reinigungenDieseWoche > 0 ? '$reinigungenDieseWoche diese Woche' : null,
  color: AppColors.success,
  onTap: () => context.push('/reinigungen'),
),
_DashboardTile(
  icon: Icons.warning_amber,
  label: 'Störungen',
  count: offeneStoerungen > 0 ? '$offeneStoerungen offen' : null,
  color: AppColors.warning,
  onTap: () => context.push('/stoerungen'),
),
_DashboardTile(
  icon: Icons.build,
  label: 'Montagen',
  count: geplanteMontagen > 0 ? '$geplanteMontagen geplant' : null,
  color: AppColors.info,
  onTap: () => context.push('/montagen'),
),
_DashboardTile(
  icon: Icons.build_circle_outlined,
  label: 'Eigenaufträge',
  count: offeneEigenauftraege > 0 ? '$offeneEigenauftraege offen' : null,
  color: const Color(0xFF7C3AED),
  onTap: () => context.push('/eigenauftraege'),
),
_DashboardTile(
  icon: Icons.cleaning_services_outlined,
  label: 'Eröffnungen',
  count: null,
  color: AppColors.primary,
  onTap: () => context.push('/eroeffnungsreinigungen'),
),
```

Kontakte und Spesen ebenfalls auf `count: null`. Aufgaben und Tourenplanung bleiben unverändert.

**Eröffnungen ohne Zähler** (entschieden 13.09.2026 während Task 1): `EroeffnungsreinigungLocal` hat kein Status-Feld — der Typ ist ein nachträglich erfasster Beleg, kein Auftrag mit Lebenszyklus. Die anstehende Arbeit steckt in `FaelligkeitsStatus.eroeffnungFaellig` und zählt bereits beim Reinigungs- und Tourenplan-Zähler mit. Es gibt deshalb keinen `anstehendeEroeffnungenCountProvider`; ihn hier zu erwarten wäre ein Kompilierfehler.

- [ ] **Schritt 3: Ungenutzte Provider-Importe entfernen**

Ausführen: `flutter analyze`
Erwartet: Meldungen über nicht mehr genutzte Importe oder Variablen — diese entfernen, bis `flutter analyze` wieder sauber ist. Die alten Provider selbst (`reinigungCountAktuellesJahrProvider` etc.) **bleiben bestehen**; sie werden an anderen Stellen genutzt. Prüfe das vor dem Löschen:

```bash
grep -rn "reinigungCountAktuellesJahrProvider" --include=*.dart lib/ test/
```

- [ ] **Schritt 4: Prüfen, wie die Kachel den längeren Text verträgt**

«12 diese Woche» ist deutlich länger als «933». Die Kacheln stehen im Seitenverhältnis 2.1 auf zwei Spalten (Pixel 9, 360 px logische Breite).

Ausführen: `flutter test test/`
Dann im Browser (siehe Task 10, Schritt 3) auf 360 px Breite nachsehen, ob der Text umbricht oder überläuft. Läuft er über, in `_DashboardTile` den Zähler-`Text` mit `maxLines: 1` und `overflow: TextOverflow.ellipsis` versehen — **nicht** die Schrift verkleinern (11 px ist die Untergrenze für Lesbarkeit im Keller).

- [ ] **Schritt 5: Commit**

```bash
git add lib/presentation/screens/home_screen.dart
git commit -m "feat: Kachelzaehler zeigen offene Arbeit statt Jahrestotale (A2)"
```

- [ ] **Schritt 6: Version bumpen und ausliefern**

`pubspec.yaml` Zeile 4 und `lib/core/app_version.dart` (`kAppVersion`) gemeinsam erhöhen — `test/app_version_test.dart` bricht sonst ab. Dann nach dem Deploy-Ablauf in `CLAUDE.md` bauen und auf `gh-pages` ausliefern.

---

# Lieferung 2 — A3: Direktstart

### Task 3: Route `/reinigungen/neu` um gebündelte Anlagen erweitern

**Dateien:**
- Ändern: `lib/core/config/router.dart:247-257`
- Ändern: `lib/presentation/screens/reinigungen/reinigung_form_screen.dart:48-58`
- Test: `test/reinigung_route_anlagen_test.dart`

Hintergrund: Die Route nimmt heute genau ein `anlageId`. Ein Besuchs-Block bündelt aber mehrere Anlagen (Blue Cinema 3, Marsöl 2) — `TourEintrag.anlageIds` ist dafür das fachlich führende Feld, `anlageId` nur die Kompatibilitäts-Ansicht darauf (`tour_providers.dart:363-368`).

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```dart
// test/reinigung_route_anlagen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/router.dart';

void main() {
  group('anlageIdsAusQuery', () {
    test('mehrere IDs kommagetrennt', () {
      expect(
        anlageIdsAusQuery({'anlageIds': 'a1,a2,a3'}),
        ['a1', 'a2', 'a3'],
      );
    });

    test('einzelnes anlageId bleibt gültig', () {
      expect(anlageIdsAusQuery({'anlageId': 'a1'}), ['a1']);
    });

    test('anlageIds hat Vorrang vor anlageId', () {
      expect(
        anlageIdsAusQuery({'anlageId': 'a1', 'anlageIds': 'a1,a2'}),
        ['a1', 'a2'],
      );
    });

    test('ohne Angabe leer', () {
      expect(anlageIdsAusQuery({}), isEmpty);
    });

    test('leere Segmente fallen weg', () {
      expect(anlageIdsAusQuery({'anlageIds': 'a1,,a2,'}), ['a1', 'a2']);
    });
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag prüfen**

Ausführen: `flutter test test/reinigung_route_anlagen_test.dart`
Erwartet: FEHLER — `anlageIdsAusQuery` ist nicht definiert.

- [ ] **Schritt 3: Helfer und Route umsetzen**

In `lib/core/config/router.dart` oberhalb der Routen-Definitionen:

```dart
/// Liest die Anlagen-Auswahl aus den Query-Parametern einer Formular-Route.
///
/// `anlageIds=a,b,c` ist der Weg für gebündelte Besuche (ein Betrieb, mehrere
/// Anlagen am selben Tag); das ältere `anlageId=a` bleibt gültig, damit die
/// Betriebsauswahl und bestehende Links unverändert funktionieren.
List<String> anlageIdsAusQuery(Map<String, String> query) {
  final mehrere = query['anlageIds'];
  if (mehrere != null && mehrere.isNotEmpty) {
    return mehrere.split(',').where((s) => s.isNotEmpty).toList();
  }
  final einzeln = query['anlageId'];
  if (einzeln != null && einzeln.isNotEmpty) return [einzeln];
  return const [];
}
```

Die Route anpassen:

```dart
GoRoute(
  path: '/reinigungen/neu',
  builder: (context, state) {
    final betriebId = state.uri.queryParameters['betriebId'];
    if (betriebId == null) {
      return const ReinigungBetriebAuswahlScreen();
    }
    final anlageIds = anlageIdsAusQuery(state.uri.queryParameters);
    return ReinigungFormScreen(
      betriebId: betriebId,
      anlageId: anlageIds.isNotEmpty ? anlageIds.first : null,
      anlageIds: anlageIds,
    );
  },
),
```

- [ ] **Schritt 4: Formular nimmt die Liste entgegen**

In `reinigung_form_screen.dart` den Konstruktor erweitern:

```dart
class ReinigungFormScreen extends ConsumerStatefulWidget {
  final String? reinigungId; // null = neu
  final String? anlageId; // für neue Reinigung (erste Anlage)
  final List<String> anlageIds; // für neue Reinigung (gebündelter Besuch)
  final String? betriebId; // für neue Reinigung

  const ReinigungFormScreen({
    super.key,
    this.reinigungId,
    this.anlageId,
    this.anlageIds = const [],
    this.betriebId,
  });
```

Dann die Stelle finden, an der `_selectedAnlageIds` für eine **neue** Reinigung vorbelegt wird:

```bash
grep -n "_selectedAnlageIds" lib/presentation/screens/reinigungen/reinigung_form_screen.dart | head -20
```

Dort die übergebene Liste bevorzugen, wenn sie mehr als einen Eintrag hat — die bestehende Einzel-Vorbelegung über `widget.anlageId` bleibt als Fall daneben. Achte darauf, die Vorbelegung **nur bei `_isEdit == false`** greifen zu lassen; beim Bearbeiten kommen die Anlagen aus dem Datensatz.

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `flutter test test/reinigung_route_anlagen_test.dart`
Erwartet: BESTANDEN, 5 Tests.

Ausführen: `flutter test`
Erwartet: alle bestanden.

- [ ] **Schritt 6: Commit**

```bash
git add lib/core/config/router.dart lib/presentation/screens/reinigungen/reinigung_form_screen.dart test/reinigung_route_anlagen_test.dart
git commit -m "feat: /reinigungen/neu nimmt gebuendelte Anlagen (anlageIds) (A3)"
```

---

### Task 4: Knopf «Neue Reinigung» auf der Betriebsseite

**Dateien:**
- Ändern: `lib/presentation/screens/betriebe/betrieb_detail_screen.dart`

Vorbild ist der bestehende Knopf im Störungs-Abschnitt (`betrieb_detail_screen.dart:908-918`): ein `TextButton.icon` im Kopf des Abschnitts, hinter `if (!SupabaseService.isGuest)`.

- [ ] **Schritt 1: Den Reinigungs-Abschnitt finden**

```bash
grep -n "Reinigungen (" lib/presentation/screens/betriebe/betrieb_detail_screen.dart
```

- [ ] **Schritt 2: Knopf einsetzen**

Im Kopf des Reinigungs-Abschnitts, nach dem `Spacer()`, analog zum Störungs-Knopf:

```dart
if (!SupabaseService.isGuest)
  TextButton.icon(
    icon: const Icon(Icons.add, size: 18),
    label: const Text('Neue Reinigung'),
    onPressed: () => context.push(
      '/reinigungen/neu?betriebId=${betrieb.serverId}',
    ),
  ),
```

Ohne `anlageIds`: Auf der Betriebsseite ist nicht entschieden, welche Anlagen gemeint sind — das Formular zeigt sie zur Auswahl. Das ist gewollt und der Unterschied zum Tourenplan, wo der Besuchs-Block die Bündelung schon kennt.

- [ ] **Schritt 3: Analyse und Tests**

Ausführen: `flutter analyze && flutter test`
Erwartet: keine neuen Befunde, alle Tests bestanden.

- [ ] **Schritt 4: Commit**

```bash
git add lib/presentation/screens/betriebe/betrieb_detail_screen.dart
git commit -m "feat: Neue Reinigung direkt von der Betriebsseite (A3)"
```

---

### Task 5: «Reinigung beginnen» im Tourenplan-Block

**Dateien:**
- Ändern: `lib/presentation/screens/touren/tourenplanung_screen.dart`

Der Besuchs-Block öffnet ein Sheet mit Anlagen-Auswahl, Dauer und den Aktionen «Betriebsseite öffnen», «Auf Schätzung zurücksetzen», «War geschlossen», «Aus Plan entfernen». Dort fehlt der Einstieg in die Arbeit selbst.

- [ ] **Schritt 1: Die Aktionsliste im Sheet finden**

```bash
grep -n "Betriebsseite öffnen\|Aus Plan entfernen" lib/presentation/screens/touren/tourenplanung_screen.dart
```

- [ ] **Schritt 2: Aktion einsetzen**

Als **erste** Aktion der Liste — sie ist die häufigste. Der Eintrag kennt Betrieb und gebündelte Anlagen bereits:

```dart
if (eintrag.typ == TourEintragTyp.reinigung && eintrag.betriebId != null)
  _SheetAktion(
    icon: Icons.play_arrow,
    text: 'Reinigung beginnen',
    onTap: () {
      final ids = eintrag.anlageIds.isNotEmpty
          ? eintrag.anlageIds
          : [if (eintrag.anlageId != null) eintrag.anlageId!];
      Navigator.of(context).pop();
      context.push(
        '/reinigungen/neu?betriebId=${eintrag.betriebId}'
        '&anlageIds=${ids.join(',')}',
      );
    },
  ),
```

`_SheetAktion` ist am 13.09. geprüft und liegt in `tourenplanung_screen.dart:2124` — es nimmt `icon`, `text`, `onTap` und optional `farbe` und baut selbst schon `GestureDetector` + `Container`. Baue **kein** neues Widget und nutze **keinen** `FilledButton`/`OutlinedButton`.

- [ ] **Schritt 3: Störung und Montage gleichziehen**

Für `TourEintragTyp.stoerung` und `.montage` dasselbe Muster mit den bestehenden Routen — beide nehmen `betriebId` und `anlageId` bereits entgegen (`router.dart:279-284` und `307-312`), es braucht dort keine Änderung:

```dart
if (eintrag.typ == TourEintragTyp.stoerung && eintrag.betriebId != null)
  _SheetAktion(
    icon: Icons.play_arrow,
    text: 'Störung erfassen',
    onTap: () {
      Navigator.of(context).pop();
      context.push(
        '/stoerungen/neu?betriebId=${eintrag.betriebId}'
        '${eintrag.anlageId != null ? '&anlageId=${eintrag.anlageId}' : ''}',
      );
    },
  ),
```

Für Montage analog mit `/montagen/neu` und dem Text «Montage erfassen».

- [ ] **Schritt 4: Analyse und Tests**

Ausführen: `flutter analyze && flutter test`
Erwartet: keine neuen Befunde, alle Tests bestanden.

- [ ] **Schritt 5: Commit**

```bash
git add lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat: Einsatz direkt aus dem Tourenplan-Block starten (A3)"
```

---

### Task 6: Lieferung 2 ausliefern und am Handy prüfen

- [ ] **Schritt 1: Version bumpen**

`pubspec.yaml` Zeile 4 **und** `kAppVersion` in `lib/core/app_version.dart` gemeinsam erhöhen.

- [ ] **Schritt 2: Bauen und ausliefern**

Nach dem Ablauf in `CLAUDE.md`: Build mit `--pwa-strategy=none`, Cache-Bust von `main.dart.js`, `404.html` mitliefern, auf `gh-pages` ausliefern.

- [ ] **Schritt 3: Klicktest durch Daniel**

Drei Wege, jeder einmal am Handy:
1. Betriebsseite → «Neue Reinigung» → Formular öffnet mit richtigem Betrieb, Anlagen zur Auswahl.
2. Tourenplan → Besuchs-Block antippen → «Reinigung beginnen» → Formular öffnet mit Betrieb **und** allen gebündelten Anlagen vorausgewählt (Blue Cinema: drei).
3. Tourenplan → Störungs-Eintrag → «Störung erfassen» → Formular öffnet vorbelegt.

**Nicht ohne diesen Test weitermachen.** Der Start-Pfeil ist der Kern von A3; bleibt er auf CanvasKit stumm, merkt es sonst niemand bis zum nächsten Arbeitstag.

---

# Lieferung 3 — A1: Die Heute-Liste

### Task 7: Ableitung «offen / erledigt»

**Dateien:**
- Erstellen: `lib/core/util/heute_stopps.dart`
- Test: `test/heute_stopps_test.dart`

Reine Funktionen ohne Provider-Verdrahtung, damit sie ohne Supabase testbar sind — Vorbild `lib/core/util/besuch_buendelung.dart` und `test/besuch_buendelung_test.dart`.

Entscheidung aus dem Spec: Ein Reinigungs-Stopp gilt erst als erledigt, wenn **alle** seine Anlagen gereinigt sind. Bei einem halb erledigten Besuch verschwände sonst der Rest aus der Liste — genau der Fehlertyp «Kette bricht ab», der am 03./04.09. Ertragsbuchungen gekostet hat.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```dart
// test/heute_stopps_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/heute_stopps.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag reinigung(String id, {List<String> anlageIds = const []}) =>
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: id,
      betriebId: 'b1',
      anlageId: anlageIds.isNotEmpty ? anlageIds.first : null,
      betriebName: 'Testbetrieb',
      beschreibung: '',
      anlageIds: anlageIds,
    );

TourEintrag stoerung(String id) => TourEintrag(
      typ: TourEintragTyp.stoerung,
      id: id,
      betriebId: 'b1',
      betriebName: 'Testbetrieb',
      beschreibung: 'Defekt',
    );

void main() {
  group('offeneStopps', () {
    test('ohne erledigte bleibt der ganze Plan stehen', () {
      final plan = [reinigung('r1', anlageIds: ['a1']), stoerung('s1')];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {},
        erledigteEinsatzIds: const {},
      );

      expect(offen.map((e) => e.id), ['r1', 's1']);
    });

    test('Reinigung mit gereinigter Anlage fällt raus', () {
      final plan = [reinigung('r1', anlageIds: ['a1'])];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {},
      );

      expect(offen, isEmpty);
    });

    test('gebündelter Besuch bleibt offen, solange eine Anlage fehlt', () {
      final plan = [reinigung('r1', anlageIds: ['a1', 'a2', 'a3'])];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a1', 'a2'},
        erledigteEinsatzIds: const {},
      );

      expect(offen.map((e) => e.id), ['r1'],
          reason: 'a3 fehlt noch — der Besuch darf nicht verschwinden');
    });

    test('gebündelter Besuch fällt erst raus, wenn alle Anlagen erledigt sind', () {
      final plan = [reinigung('r1', anlageIds: ['a1', 'a2'])];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a1', 'a2'},
        erledigteEinsatzIds: const {},
      );

      expect(offen, isEmpty);
    });

    test('Störung fällt über die Einsatz-Id raus', () {
      final plan = [stoerung('s1'), stoerung('s2')];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {},
        erledigteEinsatzIds: const {'s1'},
      );

      expect(offen.map((e) => e.id), ['s2']);
    });

    test('Reinigung ohne Anlagen gilt nie als erledigt', () {
      final plan = [reinigung('r1')];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {},
      );

      expect(offen.map((e) => e.id), ['r1'],
          reason: 'ohne Anlagenbezug lässt sich nichts abgleichen');
    });

    test('Reihenfolge des Plans bleibt erhalten', () {
      final plan = [
        reinigung('r1', anlageIds: ['a1']),
        reinigung('r2', anlageIds: ['a2']),
        reinigung('r3', anlageIds: ['a3']),
      ];

      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a2'},
        erledigteEinsatzIds: const {},
      );

      expect(offen.map((e) => e.id), ['r1', 'r3']);
    });
  });

  group('erledigtZaehler', () {
    test('zählt erledigte gegen die Gesamtzahl', () {
      final plan = [
        reinigung('r1', anlageIds: ['a1']),
        reinigung('r2', anlageIds: ['a2']),
        stoerung('s1'),
      ];

      final zaehler = erledigtZaehler(
        plan: plan,
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {'s1'},
      );

      expect(zaehler.erledigt, 2);
      expect(zaehler.gesamt, 3);
    });
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag prüfen**

Ausführen: `flutter test test/heute_stopps_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: heute_stopps.dart`

- [ ] **Schritt 3: Minimale Umsetzung**

```dart
// lib/core/util/heute_stopps.dart
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Gilt der Stopp [e] als erledigt?
///
/// Reinigungen über ihre Anlagen: erledigt ist ein Besuch erst, wenn **alle**
/// gebündelten Anlagen an diesem Tag gereinigt wurden. Wäre schon eine genug,
/// verschwände ein halb erledigter Besuch aus der Liste und die restlichen
/// Anlagen mit ihm — derselbe Fehlertyp, der am 03./04.09.2026 zwei
/// Ertragsbuchungen gekostet hat.
///
/// Störungen und Montagen über ihre Einsatz-Id, weil sie ihren Status am
/// Einsatz selbst tragen.
bool stoppErledigt(
  TourEintrag e, {
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) {
  if (e.typ == TourEintragTyp.reinigung) {
    final anlagen = e.anlageIds.isNotEmpty
        ? e.anlageIds
        : [if (e.anlageId != null) e.anlageId!];
    // Ohne Anlagenbezug lässt sich nichts abgleichen — dann lieber stehen
    // lassen als fälschlich abhaken.
    if (anlagen.isEmpty) return false;
    return anlagen.every(gereinigteAnlageIds.contains);
  }
  return erledigteEinsatzIds.contains(e.id);
}

/// Die offenen Stopps des Tages, in der Reihenfolge des Plans.
List<TourEintrag> offeneStopps({
  required List<TourEintrag> plan,
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) => [
      for (final e in plan)
        if (!stoppErledigt(
          e,
          gereinigteAnlageIds: gereinigteAnlageIds,
          erledigteEinsatzIds: erledigteEinsatzIds,
        ))
          e,
    ];

/// Zähler für die Kopfzeile: «3 von 10».
({int erledigt, int gesamt}) erledigtZaehler({
  required List<TourEintrag> plan,
  required Set<String> gereinigteAnlageIds,
  required Set<String> erledigteEinsatzIds,
}) {
  final offen = offeneStopps(
    plan: plan,
    gereinigteAnlageIds: gereinigteAnlageIds,
    erledigteEinsatzIds: erledigteEinsatzIds,
  ).length;
  return (erledigt: plan.length - offen, gesamt: plan.length);
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg prüfen**

Ausführen: `flutter test test/heute_stopps_test.dart`
Erwartet: BESTANDEN, 9 Tests.

- [ ] **Schritt 5: Commit**

```bash
git add lib/core/util/heute_stopps.dart test/heute_stopps_test.dart
git commit -m "feat: Ableitung offener Tages-Stopps (A1)"
```

---

### Task 8: Provider für die Heute-Liste

**Dateien:**
- Erstellen: `lib/presentation/providers/heute_providers.dart`

Verdrahtet die reine Funktion aus Task 7 mit dem gespeicherten Tagesplan und den Einsatz-Daten.

- [ ] **Schritt 1: Die Mengen zusammenstellen**

```dart
// lib/presentation/providers/heute_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/heute_stopps.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart'
    show stoerungOffen, montageOffen;
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Anlagen, die heute bereits gereinigt wurden (Reinigung abgeschlossen).
final gereinigteAnlagenHeuteProvider = Provider<Set<String>>((ref) {
  final heute = DateTime.now();
  final ids = <String>{};
  for (final r in ref.watch(reinigungenProvider)) {
    if (r.status != 'abgeschlossen') continue;
    if (r.datum.year != heute.year ||
        r.datum.month != heute.month ||
        r.datum.day != heute.day) {
      continue;
    }
    ids.addAll(r.anlageIds);
    if (r.anlageId != null) ids.add(r.anlageId!);
  }
  return ids;
});
```

Prüfe die Feldnamen am lokalen Modell, bevor du das übernimmst:

```bash
grep -n "anlageId\|anlageIds\|datum\|status" lib/data/local/reinigung_local.dart | head -20
```

Trägt `ReinigungLocal` die gebündelten Anlagen anders (z. B. als JSON-String), wandle sie hier um — die Menge muss dieselben Kennungen enthalten wie `TourEintrag.anlageIds` (dort sind es `routeId`-Werte, siehe `tourenplanung_screen.dart:1917`).

- [ ] **Schritt 2: Erledigte Einsätze und die offene Liste**

```dart
/// Störungen und Montagen, die nicht mehr offen sind — als TourEintrag-Ids.
///
/// Die Ids im Tagesplan sind präfixiert (`r_`, `s_`, `m_`), siehe
/// `tourEintragToJson`. Deshalb wird hier auf dieselbe Weise gebildet, was
/// dort steht, statt die rohe Datensatz-Id zu vergleichen.
final erledigteEinsatzIdsProvider = Provider<Set<String>>((ref) {
  final ids = <String>{};
  for (final s in ref.watch(stoerungenProvider)) {
    if (!stoerungOffen(s.status)) ids.add('s_${s.serverId ?? s.routeId}');
  }
  for (final m in ref.watch(montagenProvider)) {
    if (!montageOffen(m.status)) ids.add('m_${m.serverId ?? m.routeId}');
  }
  return ids;
});
```

**Prüfe das Präfix-Schema, bevor du weitergehst** — es muss exakt dem entsprechen, was beim Speichern in den Plan geschrieben wird:

```bash
grep -n "'r_\|'s_\|'m_\|id: 'r_" lib/presentation/providers/tour_providers.dart | head -10
```

Stimmt das Schema nicht, passe die Bildung hier an — die Ids müssen zusammenpassen, sonst gilt nie etwas als erledigt und die Liste wird nie kürzer. Ein Test dagegen gehört in `test/heute_stopps_test.dart`: ein Plan mit einer Störung, deren Id nach diesem Schema gebildet ist.

```dart
/// Der heutige Tagesplan, auf die offenen Stopps eingedampft.
final heuteOffeneStoppsProvider = Provider<AsyncValue<List<TourEintrag>>>((ref) {
  final plan = ref.watch(gespeicherterTagesplanProvider(tagHeute()));
  return plan.whenData(
    (p) => offeneStopps(
      plan: p?.eintraege ?? const [],
      gereinigteAnlageIds: ref.watch(gereinigteAnlagenHeuteProvider),
      erledigteEinsatzIds: ref.watch(erledigteEinsatzIdsProvider),
    ),
  );
});

/// Zähler für die Kopfzeile — `null`, solange der Plan lädt oder fehlt.
final heuteZaehlerProvider = Provider<({int erledigt, int gesamt})?>((ref) {
  final plan = ref.watch(gespeicherterTagesplanProvider(tagHeute())).valueOrNull;
  if (plan == null) return null;
  return erledigtZaehler(
    plan: plan.eintraege,
    gereinigteAnlageIds: ref.watch(gereinigteAnlagenHeuteProvider),
    erledigteEinsatzIds: ref.watch(erledigteEinsatzIdsProvider),
  );
});

DateTime tagHeute() {
  final j = DateTime.now();
  return DateTime(j.year, j.month, j.day);
}
```

- [ ] **Schritt 3: Analyse**

Ausführen: `flutter analyze`
Erwartet: keine neuen Befunde.

- [ ] **Schritt 4: Commit**

```bash
git add lib/presentation/providers/heute_providers.dart
git commit -m "feat: Provider fuer die Heute-Liste (A1)"
```

---

### Task 9: Das Widget `HeuteListe`

**Dateien:**
- Erstellen: `lib/presentation/widgets/heute_liste.dart`
- Test: `test/heute_liste_test.dart`

**CanvasKit-Regeln** (CLAUDE.md, drei bestätigte Vorfälle): Zeilen aus `InkWell` + `Container` + `Row`. Kein `ListTile`, kein `FilledButton`, kein `OutlinedButton`, kein `ExpansionTile`. Der Start-Pfeil ist ein `GestureDetector` mit `behavior: HitTestBehavior.opaque` um ein `Container`+`Icon` — oder ein `TapKnopf` (`lib/presentation/widgets/tap_knopf.dart`), wenn er Text tragen soll.

- [ ] **Schritt 1: Den fehlschlagenden Widget-Test schreiben**

```dart
// test/heute_liste_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/heute_liste.dart';

TourEintrag stopp(String name, {String? ort, List<String> anlagen = const ['a1']}) =>
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r_$name',
      betriebId: 'b_$name',
      anlageId: anlagen.first,
      anlageIds: anlagen,
      betriebName: name,
      betriebOrt: ort,
      beschreibung: '',
    );

Widget rahmen(Widget kind) => MaterialApp(home: Scaffold(body: kind));

void main() {
  testWidgets('zeigt Betrieb und Ort je Stopp', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda', ort: 'Chur')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Calanda'), findsOneWidget);
    expect(find.textContaining('Chur'), findsOneWidget);
  });

  testWidgets('zeigt alle 13 Stopps — keine Kuerzung', (tester) async {
    final viele = [for (var i = 1; i <= 13; i++) stopp('Betrieb $i')];

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: viele,
      erledigt: 0,
      gesamt: 13,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Betrieb 1'), findsOneWidget);
    expect(find.text('Betrieb 13'), findsOneWidget);
  });

  testWidgets('Kopfzeile zeigt den Fortschritt', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 3,
      gesamt: 4,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('3 von 4'), findsOneWidget);
  });

  testWidgets('ohne Plan erscheint der Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 0,
      gesamt: 0,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsOneWidget);
    expect(find.text('Plan erstellen'), findsOneWidget);
  });

  testWidgets('alles erledigt ist nicht derselbe Zustand wie kein Plan', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 9,
      gesamt: 9,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsNothing);
    expect(find.textContaining('Alles erledigt'), findsOneWidget);
  });

  testWidgets('Start-Pfeil meldet den Stopp', (tester) async {
    TourEintrag? gestartet;

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (e) => gestartet = e,
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    await tester.tap(find.byKey(const Key('heute_start_r_Calanda')));
    await tester.pump();

    expect(gestartet?.betriebName, 'Calanda');
  });

  testWidgets('kein ListTile und kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag prüfen**

Ausführen: `flutter test test/heute_liste_test.dart`
Erwartet: FEHLER — `HeuteListeInhalt` ist nicht definiert.

- [ ] **Schritt 3: Widget umsetzen**

Zwei Klassen in einer Datei: `HeuteListeInhalt` nimmt fertige Daten entgegen (testbar ohne Riverpod), `HeuteListe` verdrahtet sie mit den Providern aus Task 8.

```dart
// lib/presentation/widgets/heute_liste.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/heute_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

const _wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

/// Darstellung ohne Datenanbindung — so ist sie ohne Supabase testbar.
class HeuteListeInhalt extends StatelessWidget {
  final List<TourEintrag> stopps;
  final int erledigt;
  final int gesamt;
  final void Function(TourEintrag) onStart;
  final void Function(TourEintrag) onOeffnen;
  final VoidCallback onTourenplan;
  final DateTime? heute;

  const HeuteListeInhalt({
    super.key,
    required this.stopps,
    required this.erledigt,
    required this.gesamt,
    required this.onStart,
    required this.onOeffnen,
    required this.onTourenplan,
    this.heute,
  });

  @override
  Widget build(BuildContext context) {
    final tag = heute ?? DateTime.now();
    final datumStr =
        '${_wochentage[tag.weekday - 1].substring(0, 2)}, '
        '${tag.day.toString().padLeft(2, '0')}.'
        '${tag.month.toString().padLeft(2, '0')}.';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  datumStr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (gesamt > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$erledigt von $gesamt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (gesamt == 0)
              _Leerzustand(onTourenplan: onTourenplan)
            else if (stopps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Alles erledigt für heute',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              )
            else
              for (var i = 0; i < stopps.length; i++)
                _StoppZeile(
                  eintrag: stopps[i],
                  position: i + 1,
                  onStart: () => onStart(stopps[i]),
                  onOeffnen: () => onOeffnen(stopps[i]),
                ),
            if (gesamt > 0)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTourenplan,
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Im Tourenplan öffnen',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Die Zeile selbst — `InkWell` + `Container` + `Row`, der Start-Pfeil als eigener `GestureDetector` mit `Key`, damit der Test ihn findet:

```dart
class _StoppZeile extends StatelessWidget {
  final TourEintrag eintrag;
  final int position;
  final VoidCallback onStart;
  final VoidCallback onOeffnen;

  const _StoppZeile({
    required this.eintrag,
    required this.position,
    required this.onStart,
    required this.onOeffnen,
  });

  @override
  Widget build(BuildContext context) {
    // Uhrzeit nur, wo ein Termin-Anker gesetzt ist. Eine gerechnete
    // Ankunftszeit gibt es hier bewusst nicht — die entsteht erst in der
    // Zeitachse des Tourenplans (Spec 13.09.2026).
    final marke = eintrag.ankerZeit ?? '$position.';
    final untertitel = [
      if (eintrag.betriebOrt != null && eintrag.betriebOrt!.isNotEmpty)
        eintrag.betriebOrt!,
      if (eintrag.anlageIds.length > 1) '${eintrag.anlageIds.length} Anlagen',
      if (eintrag.servicezeit != null) eintrag.servicezeit!,
    ].join(' · ');

    return InkWell(
      onTap: onOeffnen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                marke,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eintrag.betriebName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (untertitel.isNotEmpty)
                    Text(
                      untertitel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              key: Key('heute_start_${eintrag.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Leerzustand extends StatelessWidget {
  final VoidCallback onTourenplan;
  const _Leerzustand({required this.onTourenplan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Kein Tagesplan für heute',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTourenplan,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'Plan erstellen',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
```

Zuletzt die angebundene Fassung:

```dart
/// Angebundene Fassung für den Startbildschirm.
class HeuteListe extends ConsumerWidget {
  const HeuteListe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offen = ref.watch(heuteOffeneStoppsProvider);
    final zaehler = ref.watch(heuteZaehlerProvider);

    return offen.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stopps) => HeuteListeInhalt(
        stopps: stopps,
        erledigt: zaehler?.erledigt ?? 0,
        gesamt: zaehler?.gesamt ?? 0,
        onStart: (e) => _starte(context, e),
        onOeffnen: (e) {
          if (e.betriebId != null) context.push('/betriebe/${e.betriebId}');
        },
        onTourenplan: () => context.push('/touren'),
      ),
    );
  }

  void _starte(BuildContext context, TourEintrag e) {
    if (e.betriebId == null) return;
    switch (e.typ) {
      case TourEintragTyp.reinigung:
        final ids = e.anlageIds.isNotEmpty
            ? e.anlageIds
            : [if (e.anlageId != null) e.anlageId!];
        context.push(
          '/reinigungen/neu?betriebId=${e.betriebId}&anlageIds=${ids.join(',')}',
        );
      case TourEintragTyp.stoerung:
        context.push('/stoerungen/neu?betriebId=${e.betriebId}');
      case TourEintragTyp.montage:
      case TourEintragTyp.heigenie:
        context.push('/montagen/neu?betriebId=${e.betriebId}');
    }
  }
}
```

- [ ] **Schritt 4: Tests laufen lassen**

Ausführen: `flutter test test/heute_liste_test.dart`
Erwartet: BESTANDEN, 7 Tests.

- [ ] **Schritt 5: Commit**

```bash
git add lib/presentation/widgets/heute_liste.dart test/heute_liste_test.dart
git commit -m "feat: HeuteListe-Widget mit Start-Pfeil und Leerzustand (A1)"
```

---

### Task 10: Startseite umbauen und den Wächter erweitern

**Dateien:**
- Ändern: `lib/presentation/screens/home_screen.dart:63-87` (Body) und `359-465` (`_TagesUebersicht`)
- Ändern: `test/canvaskit_sichere_widgets_test.dart`

- [ ] **Schritt 1: Den Monatsumsatz retten**

`_TagesUebersicht` zeigt heute den Monatsumsatz (`data.monatsUmsatzCHF`) und den Tagesumsatz. Bevor die Klasse verschwindet, muss der Monatsumsatz in die Kopfzeile der `HeuteListeInhalt`. Ergänze dort einen Parameter **mit Vorgabewert** — ohne ihn wäre er verpflichtend und die sieben Tests aus Task 9 brächen:

```dart
final double monatsUmsatzCHF;   // im Konstruktor: this.monatsUmsatzCHF = 0
```

und in der Kopfzeile, rechtsbündig nach dem Fortschritt:

```dart
const Spacer(),
if (monatsUmsatzCHF > 0)
  Text(
    '${monatsUmsatzCHF.toStringAsFixed(0)} CHF / Monat',
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  ),
```

In `HeuteListe` aus `tagesUebersichtProvider` speisen. Ergänze im Widget-Test einen Fall dafür.

- [ ] **Schritt 2: Body der Startseite umstellen**

```dart
body: ListView(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
  children: [
    const _AufgabenKarte(),
    const ArbeitstagKarte(),
    const HeuteListe(),
    const SizedBox(height: 8),
    const _KachelGrid(),
    const SizedBox(height: 16),
    const _WeitereSection(),
  ],
),
```

`_TagesUebersicht` und `_CountChip` löschen, wenn sie nirgends sonst genutzt werden:

```bash
grep -rn "_TagesUebersicht\|_CountChip" --include=*.dart lib/ test/
```

Den Kommentar zur Pixel-9-Regel bei `_KachelGrid` (`home_screen.dart:120-122`) anpassen — die Regel gilt nicht mehr:

```dart
// Flachere Kacheln (2.1) + enge Abstände: seit der Heute-Liste (13.09.2026)
// scrollt die Startseite bewusst; die Kacheln liegen einen Wisch tiefer.
// Vorher mussten alle zehn zusammen mit Arbeitstag und Übersicht ohne
// Scrollen aufs Pixel 9 passen (Daniel 31.07.2026).
```

- [ ] **Schritt 3: Am Browser prüfen**

Ausführen: `flutter run -d edge`
Prüfen bei 360 px Breite (Pixel 9):
1. Die Liste zeigt die offenen Stopps von heute.
2. Der Start-Pfeil ist **sichtbar** und **reagiert** — das ist die CanvasKit-Falle.
3. Die Kacheln sind mit einem Wisch erreichbar.
4. Die Kachelzähler brechen nicht um.

Fehlt heute ein Plan (Wochenende), erscheint der Leerzustand — auch das einmal ansehen.

- [ ] **Schritt 4: Den Wächter-Test erweitern**

In `test/canvaskit_sichere_widgets_test.dart` einen zweiten Test ergänzen:

```dart
  test('Heute-Liste ohne CanvasKit-tote Widgets', () {
    final datei = File('lib/presentation/widgets/heute_liste.dart');
    expect(datei.existsSync(), isTrue,
        reason: 'heute_liste.dart fehlt — Pfad im Waechter anpassen');
    final text = datei.readAsStringSync();

    for (final verboten in ['ListTile(', 'FilledButton', 'OutlinedButton', 'ExpansionTile(']) {
      expect(
        text.contains(verboten),
        isFalse,
        reason:
            '$verboten in der Heute-Liste. Die Liste steht auf der '
            'meistgenutzten Seite der App; rendert der Start-Pfeil auf '
            'CanvasKit nicht, merkt es niemand bis zum naechsten '
            'Arbeitstag. GestureDetector + Container + Row verwenden '
            '(CLAUDE.md, drei bestaetigte Vorfaelle).',
      );
    }
  });
```

- [ ] **Schritt 5: Volle Suite**

Ausführen: `flutter analyze`
Erwartet: keine neuen Befunde.

Ausführen: `flutter test`
Erwartet: alle bestanden (vorher 1382 plus die hier neu hinzugekommenen).

- [ ] **Schritt 6: Commit**

```bash
git add lib/presentation/screens/home_screen.dart lib/presentation/widgets/heute_liste.dart test/
git commit -m "feat: Startseite zeigt den heutigen Tagesplan statt Jahreszahlen (A1)"
```

- [ ] **Schritt 7: Ausliefern und am Handy prüfen**

Version in `pubspec.yaml` **und** `kAppVersion` bumpen, bauen, ausliefern. Dann durch Daniel am Handy:
1. Morgens: Stehen alle offenen Stopps da?
2. Nach einer Reinigung: Verschwindet der Stopp, und zählt die Kopfzeile hoch?
3. Ein gebündelter Betrieb (Blue Cinema, drei Anlagen): Bleibt der Stopp stehen, solange nicht alle drei erfasst sind?
4. Start-Pfeil: Öffnet er das Formular mit Betrieb und Anlagen?

---

## Nach der Auslieferung

- [ ] `ToDo.md`: A1–A3 als erledigt vermerken; den Satz «Tourenplanung wurde an keinem Arbeitstag geöffnet» streichen (widerlegt, siehe Spec).
- [ ] `Projekt.md`: Versionszeile und Kurzbeschreibung nachziehen.
- [ ] `docs/app-analyse-2026-09.md`: A1, A2, A3 als erledigt markieren — wie es bei A7 schon steht.
- [ ] In zwei bis drei Wochen die Nutzungsmessung erneut ansehen: Verschiebt sich der Einstieg von `/reinigungen` auf `/` und den Direktstart? Das ist die Probe, ob A3 wirkt. Damit werden auch A6 und B2 entscheidbar.
