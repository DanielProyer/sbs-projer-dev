# Büro-Startseite «Was ist offen?» (B3) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Die Buchhaltungs-Startseite zeigt zuoberst, was offen ist — den Büro-Ausschnitt der einen Aufgabenliste aus B6 —, und ordnet die 13 Ziele in zwei Gruppen.

**Architektur:** Eine neue Unterscheidung «Frist oder Vorrat» (`istVorrat` auf `Aufgabe`) hält Arbeitsvorräte aus der Glocke, ohne eine zweite Liste zu erzeugen; `istBueroAufgabe` leitet die Büro-Zugehörigkeit aus der Route ab. Zwei neue Detektoren (Bank-Prüfliste, offene Eingangsrechnungen) und ein darstellender Block, der die bestehende `AufgabeZeile` wiederverwendet.

**Tech-Stack:** Flutter · Riverpod · Supabase · `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-16-buero-startseite-b3-design.md`

**Modellwahl:** 1, 2, 3, 4 mechanisch (Sonnet). 5 fasst den 481-Zeilen-Screen an (Sonnet, Review durch Koordinator). 6 Koordinator.

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/core/util/aufgaben_regeln.dart` | `Aufgabe.istVorrat`; `bankPrueflisteAufgabe`, `eingangsrechnungenAufgabe`; zwei bestehende auf Vorrat | Ändern |
| `lib/core/util/aufgabe.dart` | `AufgabenEintrag.istVorrat`, `jetztFaellig`, `istBueroAufgabe` | Ändern |
| `lib/presentation/providers/aufgaben_detektoren_provider.dart` | zwei neue Detektoren (g, h) | Ändern |
| `lib/presentation/widgets/buero_offen_block.dart` | `BueroOffenBlock` (rein) | **Neu** |
| `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` | Offen-Block, zwei Gruppen, `_NavTile` CanvasKit-sicher | Ändern |
| `test/aufgabe_test.dart` | `istVorrat`, `istBueroAufgabe` | Ändern |
| `test/aufgaben_regeln_test.dart` | die zwei neuen Regelfunktionen | Ändern |
| `test/buero_offen_block_test.dart` | Block auf 360 px, Roboto | **Neu** |
| `test/buchhaltung_gruppen_waechter_test.dart` | jedes Ziel in genau einer Gruppe | **Neu** |
| `test/canvaskit_sichere_widgets_test.dart` | zwei Dateien in die Liste | Ändern |

**Version:** v0.108.0 (`pubspec.yaml` Zeile 4 `0.108.0+754`, `kAppVersion`).

**Gilt für alle Aufgaben:** Arbeitsverzeichnis `sbs_projer_app`; in Bash `export PATH="$PATH:/c/flutter/bin"`; `flutter analyze` hat 56 vorbestehende Infos — keine neuen (weniger ist gut, dann die Zahl melden); Kommentare auf Deutsch (Schweiz: «ss» statt «ß»), sie erklären das WARUM; Commit-Nachrichten ohne Umlaute; nie `git stash`; Layout-Tests laden Roboto (Muster `test/kachel_text_test.dart:28-35`); **CanvasKit-Regel:** Navigation und Listenzeilen aus `InkWell`/`GestureDetector` + `Container` + `Row`, **kein `ListTile`, `NavigationBar`, `FilledButton`, `OutlinedButton`** — auf dem produktiven CanvasKit-Web dreimal bestätigt nicht gerendert oder nicht reagiert. Eine Datei mit `library;`-Direktive trägt sie **vor** den Importen (Dart-Regel).

---

### Task 1: Frist oder Vorrat

**Files:**
- Modify: `lib/core/util/aufgaben_regeln.dart` (Klasse `Aufgabe`, Zeilen 11–25)
- Modify: `lib/core/util/aufgabe.dart` (`AufgabenEintrag` ab Zeile 59, `jetztFaellig` Zeile 126, `baueAufgabenListe` ab Zeile 179)
- Modify: `test/aufgabe_test.dart`

Hintergrund: Die Glocke soll Termine zeigen, keine Stapel. «23 unverbuchte Bank-Buchungen» ist kein Alarm am Berg, «MwSt-Quartal fällig» schon. Ein Vorrat bleibt im Aufgaben-Screen und auf der Büro-Startseite sichtbar — er verschwindet nur aus dem Ausschnitt «jetzt fällig», den Glocke, Startkarte, Kachelzähler und Sheet zeigen.

`istBueroAufgabe` leitet die Zugehörigkeit zur Büro-Startseite aus der Route ab statt aus einem zweiten Pflegefeld: Ein neuer Detektor, der in die Buchhaltung führt, erscheint dort von selbst.

- [ ] **Step 1: Die fehlschlagenden Tests schreiben** — in `test/aufgabe_test.dart` zwei neue Gruppen vor der schliessenden `}` von `main()` einfügen:

```dart
  group('istVorrat', () {
    AufgabenEintrag vorrat({DateTime? faellig}) => AufgabenEintrag(
      quelle: AufgabenQuelle.detektor,
      key: 'bank_pruefliste',
      titel: '23 Bank-Buchungen prüfen',
      faellig: faellig,
      route: '/buchhaltung/camt-pruefliste',
      istVorrat: true,
    );

    test('ein Vorrat ist nie jetzt faellig — auch nicht mit Datum heute', () {
      expect(jetztFaellig(vorrat(), heute), isFalse);
      expect(jetztFaellig(vorrat(faellig: heute), heute), isFalse);
    });

    test('ohne das Kennzeichen bleibt ein Detektor jetzt faellig', () {
      final frist = AufgabenEintrag(
        quelle: AufgabenQuelle.detektor,
        key: 'mwst:2026-Q3',
        titel: 'MWST Q3',
        faellig: heute,
        route: '/buchhaltung/mwst',
      );
      expect(frist.istVorrat, isFalse, reason: 'Vorgabe ist Frist');
      expect(jetztFaellig(frist, heute), isTrue);
    });

    test('baueAufgabenListe reicht das Kennzeichen vom Detektor durch', () {
      final liste = baueAufgabenListe(
        detektoren: [
          const Aufgabe(
            key: 'bank_pruefliste',
            titel: '23 Bank-Buchungen prüfen',
            route: '/buchhaltung/camt-pruefliste',
            istVorrat: true,
          ),
          const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf', route: '/buchhaltung/mahnwesen'),
        ],
        aufgabenZeilen: const [],
        anstehend: const [],
        saisonVorschlaege: const [],
        saisonTermine: const [],
        aenderungsVorschlaege: 0,
        heute: heute,
      );
      expect(liste.firstWhere((e) => e.key == 'bank_pruefliste').istVorrat, isTrue);
      expect(liste.firstWhere((e) => e.key == 'mahnlauf').istVorrat, isFalse);
      // Der Vorrat steht in der Liste, aber nicht im Ausschnitt «jetzt».
      expect(liste, hasLength(2));
      expect(liste.where((e) => jetztFaellig(e, heute)), hasLength(1));
    });
  });

  group('istBueroAufgabe', () {
    AufgabenEintrag mitRoute(String? route) => AufgabenEintrag(
      quelle: AufgabenQuelle.detektor,
      key: 'k',
      titel: 't',
      route: route,
    );

    test('Buchhaltung, Rechnungen und Heineken gehoeren ins Buero', () {
      for (final r in [
        '/buchhaltung',
        '/buchhaltung/mwst',
        '/buchhaltung/camt-pruefliste',
        '/rechnungen',
        '/heineken',
      ]) {
        expect(istBueroAufgabe(mitRoute(r)), isTrue, reason: r);
      }
    });

    test('Werkstatt und Ziellose nicht', () {
      for (final r in ['/touren', '/betriebe/abc', '/einsaetze', '/aufgaben']) {
        expect(istBueroAufgabe(mitRoute(r)), isFalse, reason: r);
      }
      expect(istBueroAufgabe(mitRoute(null)), isFalse,
          reason: 'eine eigene Aufgabe ohne Ziel ist keine Buero-Zeile');
    });

    test('ein Praefix darf keinen anderen Namen kapern', () {
      expect(istBueroAufgabe(mitRoute('/rechnungen-alt')), isFalse);
    });
  });
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/aufgabe_test.dart`
Erwartet: FEHLER — `istVorrat` und `istBueroAufgabe` sind nicht definiert.

- [ ] **Step 3: `Aufgabe` erweitern** — in `lib/core/util/aufgaben_regeln.dart`, Klasse `Aufgabe`, nach `final bool manuellErledigbar;`:

```dart
  /// Ein Stapel ohne Stichtag (Bank-Prüfliste, offene Eingangsrechnungen,
  /// fehlende Buchungen). Steht im Büro und im Aufgaben-Screen, aber nicht
  /// in der Glocke — dort gehört nur hin, was eine Frist hat (B3).
  final bool istVorrat;
```

und im Konstruktor nach `this.manuellErledigbar = false,`:

```dart
    this.istVorrat = false,
```

- [ ] **Step 4: `AufgabenEintrag` erweitern** — in `lib/core/util/aufgabe.dart`, nach `final bool manuellErledigbar;` (Zeile 79):

```dart
  /// Siehe `Aufgabe.istVorrat` — ein Stapel ohne Stichtag (B3).
  final bool istVorrat;
```

im Konstruktor nach `this.manuellErledigbar = false,` (Zeile 93):

```dart
    this.istVorrat = false,
```

und in `baueAufgabenListe` beim Detektor-Eintrag (nach `manuellErledigbar: a.manuellErledigbar,`, Zeile 185):

```dart
      istVorrat: a.istVorrat,
```

- [ ] **Step 5: `jetztFaellig` und `istBueroAufgabe`** — `jetztFaellig` (Zeile 126) von der Pfeil-Form auf einen Rumpf umstellen:

```dart
bool jetztFaellig(AufgabenEintrag a, DateTime heute) {
  // Ein Vorrat wächst und schrumpft ohne Stichtag — er gehört in den
  // Aufgaben-Screen und ins Büro, nicht in die Glocke (B3).
  if (a.istVorrat) return false;
  return switch (a.quelle) {
    AufgabenQuelle.detektor || AufgabenQuelle.aenderungsVorschlag => true,
    AufgabenQuelle.eigene => eigeneSichtbar(a.faellig, heute),
    AufgabenQuelle.einsatz ||
    AufgabenQuelle.saisonVorschlag ||
    AufgabenQuelle.termin =>
      a.faellig != null && !_tag(a.faellig!).isAfter(_tag(heute)),
  };
}
```

Den bestehenden Doc-Kommentar über `jetztFaellig` behalten und um einen Satz ergänzen: «Vorräte sind nie jetzt fällig (B3).»

Darunter neu:

```dart
/// Wohin die Büro-Startseite schaut. Die Zugehörigkeit folgt aus dem Ziel,
/// nicht aus einem zweiten Pflegefeld: Ein neuer Detektor, der in die
/// Buchhaltung führt, erscheint dort von selbst; Saisondaten (`/touren`)
/// fällt heraus, ohne dass jemand daran denken muss.
const _bueroPraefixe = ['/buchhaltung', '/rechnungen', '/heineken'];

bool istBueroAufgabe(AufgabenEintrag a) {
  final r = a.route;
  if (r == null) return false;
  return _bueroPraefixe.any((p) => r == p || r.startsWith('$p/'));
}
```

- [ ] **Step 6: Tests laufen lassen**

Run: `flutter test test/aufgabe_test.dart test/aufgaben_providers_test.dart test/aufgaben_inhalt_test.dart`
Erwartet: BESTANDEN. `flutter analyze` — 56. `dart format` auf die drei geänderten Dateien.

- [ ] **Step 7: Commit**

```bash
git add lib/core/util/aufgaben_regeln.dart lib/core/util/aufgabe.dart test/aufgabe_test.dart
git commit -m "feat: Frist oder Vorrat - Vorraete bleiben aus der Glocke (B3)"
```

---

### Task 2: Die zwei neuen Regeln, und zwei bestehende werden Vorrat

**Files:**
- Modify: `lib/core/util/aufgaben_regeln.dart`
- Modify: `test/aufgaben_regeln_test.dart`

Vorbild ist `mahnlaufAufgabe` (Zeile 95): eine reine Funktion, die bei 0 `null` liefert — so bleibt der Detektor im Provider auf drei Zeilen und die Regel ohne Supabase testbar.

`fehlendeBuchungenAufgabe` und `versandvermerkAufgabe` werden zu Vorräten: Beides sind Stapel, die abgearbeitet werden, keine Termine. Ihr `dringend: true` bleibt — im Büro und im Aufgaben-Screen stehen sie damit weiter rot.

- [ ] **Step 1: Die fehlschlagenden Tests schreiben** — in `test/aufgaben_regeln_test.dart` am Ende von `main()`:

```dart
  group('bankPrueflisteAufgabe', () {
    test('leere Pruefliste ergibt nichts', () {
      expect(bankPrueflisteAufgabe(0), isNull);
    });
    test('Einzahl und Mehrzahl', () {
      expect(bankPrueflisteAufgabe(1)!.titel, '1 Bank-Buchung prüfen');
      expect(bankPrueflisteAufgabe(23)!.titel, '23 Bank-Buchungen prüfen');
    });
    test('ist ein Vorrat und zeigt auf die Pruefliste', () {
      final a = bankPrueflisteAufgabe(5)!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/camt-pruefliste');
      expect(a.key, 'bank_pruefliste');
      expect(a.dringend, isFalse, reason: 'ein Stapel ist nicht dringend');
    });
  });

  group('eingangsrechnungenAufgabe', () {
    test('nichts offen ergibt nichts', () {
      expect(eingangsrechnungenAufgabe(0), isNull);
    });
    test('Einzahl und Mehrzahl', () {
      expect(eingangsrechnungenAufgabe(1)!.titel, '1 Eingangsrechnung offen');
      expect(eingangsrechnungenAufgabe(7)!.titel, '7 Eingangsrechnungen offen');
    });
    test('ist ein Vorrat und zeigt auf die Eingangsrechnungen', () {
      final a = eingangsrechnungenAufgabe(3)!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/eingangsrechnungen');
      expect(a.key, 'eingangsrechnungen_offen');
    });
  });

  group('bestehende Stapel sind Vorraete (B3)', () {
    test('fehlende Buchungen und Versandvermerke', () {
      expect(fehlendeBuchungenAufgabe(2)!.istVorrat, isTrue);
      expect(versandvermerkAufgabe(2)!.istVorrat, isTrue);
      // dringend bleibt: im Buero und im Aufgaben-Screen weiterhin rot.
      expect(fehlendeBuchungenAufgabe(2)!.dringend, isTrue);
    });
    test('Fristen bleiben Fristen', () {
      expect(mahnlaufAufgabe(3)!.istVorrat, isFalse);
      expect(saisondatenAufgabe(3)!.istVorrat, isFalse);
    });
  });
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/aufgaben_regeln_test.dart`
Erwartet: FEHLER — `bankPrueflisteAufgabe` und `eingangsrechnungenAufgabe` sind nicht definiert.

- [ ] **Step 3: Die zwei Regeln ergänzen** — in `lib/core/util/aufgaben_regeln.dart` nach `versandvermerkAufgabe`:

```dart
/// Bank-Buchungen, die der camt-Import nicht selbst zuordnen konnte.
///
/// Ein Stapel, kein Termin: Er wächst mit jedem Auszug und schrumpft beim
/// Durchgehen. Deshalb Vorrat — in der Glocke am Berg wäre er nur Rauschen
/// (B3).
Aufgabe? bankPrueflisteAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'bank_pruefliste',
        titel: anzahl == 1
            ? '1 Bank-Buchung prüfen'
            : '$anzahl Bank-Buchungen prüfen',
        route: '/buchhaltung/camt-pruefliste',
        istVorrat: true,
      );

/// Eingangsrechnungen, die erfasst, aber noch nicht zur Zahlung vorgemerkt
/// sind — alles vor `zahlung_vorgemerkt`. Ebenfalls ein Stapel (B3).
Aufgabe? eingangsrechnungenAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'eingangsrechnungen_offen',
        titel: anzahl == 1
            ? '1 Eingangsrechnung offen'
            : '$anzahl Eingangsrechnungen offen',
        route: '/buchhaltung/eingangsrechnungen',
        istVorrat: true,
      );
```

- [ ] **Step 4: Die zwei bestehenden auf Vorrat setzen** — in `fehlendeBuchungenAufgabe` und `versandvermerkAufgabe` jeweils `istVorrat: true,` nach `dringend: true,` ergänzen und den Doc-Kommentar beider um einen Satz erweitern:

```dart
/// Seit B3 ein Vorrat: Der Stapel gehört ins Büro und in den
/// Aufgaben-Screen, nicht in die Glocke.
```

- [ ] **Step 5: Tests laufen lassen**

Run: `flutter test test/aufgaben_regeln_test.dart test/aufgabe_test.dart`
Erwartet: BESTANDEN. `flutter analyze` — 56. `dart format`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/util/aufgaben_regeln.dart test/aufgaben_regeln_test.dart
git commit -m "feat: Bank-Pruefliste und offene Eingangsrechnungen als Vorrat (B3)"
```

---

### Task 3: Die zwei neuen Detektoren

**Files:**
- Modify: `lib/presentation/providers/aufgaben_detektoren_provider.dart`

Kein eigener Unit-Test: Der Provider spricht mit Supabase; die Regeln dahinter sind in Task 2 getestet. Vorbild ist Detektor c) (Mahnlauf, Zeilen 81–104) — jeder Detektor steht in seinem eigenen try/catch, damit ein gefallener nicht die ganze Liste leert.

- [ ] **Step 1: Detektor g) ergänzen** — nach dem try/catch von f) (Versandvermerk), vor `final offene = ...`:

```dart
  // g) Bank-Prüfliste — camt-Buchungen, die der Import nicht zuordnen
  //    konnte. Derselbe Provider wie der Prüflisten-Screen, damit beide nie
  //    auseinanderlaufen.
  try {
    final offen = await ref.watch(camtPrueflisteProvider.future);
    final a = bankPrueflisteAufgabe(offen.length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Bank-Prüfliste-Detektor: $e');
  }

  // h) Eingangsrechnungen, die noch nicht zur Zahlung vorgemerkt sind.
  try {
    final alle = await ref.watch(eingangsrechnungenProvider.future);
    const offeneStati = {'erkannt', 'bestaetigt', 'gebucht'};
    final anzahl = alle.where((e) => offeneStati.contains(e.status)).length;
    final a = eingangsrechnungenAufgabe(anzahl);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Eingangsrechnungs-Detektor: $e');
  }
```

Importe ergänzen: `package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart` und `package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart`.

`camtPrueflisteProvider` ist `FutureProvider.autoDispose<List<CamtPrueflisteEintrag>>` (`camt_pruefliste_providers.dart:5`), `eingangsrechnungenProvider` ist `FutureProvider<List<Eingangsrechnung>>` (`eingangsrechnung_providers.dart:11`) und lädt alle Stati ausser `verworfen`; `Eingangsrechnung.status` ist `String?`.

- [ ] **Step 2: Prüfen**

Run: `flutter analyze`
Erwartet: 56, keine neuen. Meldet der Analyzer, dass `camtPrueflisteProvider` wegen `autoDispose` nicht aus einem nicht-autoDispose-Provider gelesen werden darf, melde das — der Ausweg wäre, im Detektor `CamtPrueflisteRepository.getOffen()` direkt aufzurufen statt den Provider zu lesen; nimm dann diesen Weg und sag es im Report.

Run: `flutter test test/aufgaben_providers_test.dart`
Erwartet: BESTANDEN. Schlägt der Test fehl, weil die neuen Provider im `ProviderContainer` nicht überschrieben sind: ergänze in der Hilfsfunktion `basis(...)` des Tests zwei Überschreibungen

```dart
    camtPrueflisteProvider.overrideWith((ref) async => const []),
    eingangsrechnungenProvider.overrideWith((ref) async => const []),
```

mit den passenden Importen — der Test überschreibt ohnehin schon `aufgabenDetektorenProvider`, insofern sollte er unberührt bleiben; melde, ob es nötig war.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/aufgaben_detektoren_provider.dart test/aufgaben_providers_test.dart
git commit -m "feat: zwei Buero-Detektoren - Bank-Pruefliste und offene Eingangsrechnungen (B3)"
```

---

### Task 4: Der Offen-Block

**Files:**
- Create: `lib/presentation/widgets/buero_offen_block.dart`
- Test: `test/buero_offen_block_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart`

Der Block ist reine Darstellung und verwendet `AufgabeZeile` (B6) unverändert — Dorthin, Snooze und Erledigt laufen damit ohne eine Zeile neuen Aktionscode.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/buero_offen_block_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/buero_offen_block.dart';

final heute = DateTime(2026, 9, 16, 9);

AufgabenEintrag e(
  String titel, {
  bool vorrat = false,
  DateTime? faellig,
  String route = '/buchhaltung',
}) => AufgabenEintrag(
  quelle: AufgabenQuelle.detektor,
  key: titel,
  titel: titel,
  faellig: faellig,
  route: route,
  istVorrat: vorrat,
);

Widget rahmen(List<AufgabenEintrag> liste, {ValueChanged<AufgabenEintrag>? onDorthin}) =>
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            BueroOffenBlock(
              eintraege: liste,
              heute: heute,
              onDorthin: onDorthin ?? (_) {},
              onSnooze: (_, _) {},
              onErledigt: (_) {},
            ),
          ],
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Ueberschrift und Eintraege', (tester) async {
    await tester.pumpWidget(rahmen([e('MWST Q3 2026 einreichen', faellig: heute)]));
    expect(find.text('Was ist offen?'), findsOneWidget);
    expect(find.text('MWST Q3 2026 einreichen'), findsOneWidget);
  });

  testWidgets('Fristen stehen vor Vorraeten', (tester) async {
    await tester.pumpWidget(rahmen([
      e('23 Bank-Buchungen prüfen', vorrat: true),
      e('MWST Q3 2026 einreichen', faellig: heute),
      e('7 Eingangsrechnungen offen', vorrat: true),
      e('Heineken-Rechnung August erstellen', faellig: heute),
    ]));
    final y = <String, double>{
      for (final t in [
        'MWST Q3 2026 einreichen',
        'Heineken-Rechnung August erstellen',
        '23 Bank-Buchungen prüfen',
        '7 Eingangsrechnungen offen',
      ])
        t: tester.getTopLeft(find.text(t)).dy,
    };
    expect(y['MWST Q3 2026 einreichen']! < y['23 Bank-Buchungen prüfen']!, isTrue);
    expect(y['Heineken-Rechnung August erstellen']! < y['23 Bank-Buchungen prüfen']!, isTrue);
  });

  testWidgets('Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(const []));
    expect(find.text('Nichts offen 🎉'), findsOneWidget);
  });

  testWidgets('Tipp meldet den Eintrag', (tester) async {
    AufgabenEintrag? getippt;
    await tester.pumpWidget(rahmen(
      [e('MWST Q3 2026 einreichen', faellig: heute)],
      onDorthin: (a) => getippt = a,
    ));
    await tester.tap(find.text('MWST Q3 2026 einreichen'));
    expect(getippt?.key, 'MWST Q3 2026 einreichen');
  });

  testWidgets('kein ListTile, auch auf 360 px kein Ueberlauf', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(rahmen([
      e('7 Mail-Rechnungen ohne Versandvermerk — Postausgang prüfen', vorrat: true),
    ]));
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/buero_offen_block_test.dart`
Erwartet: FEHLER — `buero_offen_block.dart` fehlt.

- [ ] **Step 3: Umsetzung** — `lib/presentation/widgets/buero_offen_block.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';

/// «Was ist offen?» — der Büro-Ausschnitt der einen Aufgabenliste (B3).
///
/// WARUM hier keine eigene Liste: Die Buchhaltungs-Startseite zeigte vier
/// Jahres-Kennzahlen und 13 Ziele, aber nirgends, was heute offen ist
/// (Befund 4 der App-Analyse 09/2026). Die Zeilen dafür gibt es längst — als
/// Detektoren der Aufgabenliste aus B6. Eine zweite Liste wäre genau der
/// Fehler, den B6 behoben hat.
///
/// Fristen zuerst, dann Vorräte: Ein Stichtag drängt, ein Stapel wartet.
class BueroOffenBlock extends StatelessWidget {
  final List<AufgabenEintrag> eintraege;
  final DateTime heute;
  final ValueChanged<AufgabenEintrag> onDorthin;
  final void Function(AufgabenEintrag, int tage) onSnooze;
  final ValueChanged<AufgabenEintrag> onErledigt;

  const BueroOffenBlock({
    super.key,
    required this.eintraege,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
  });

  @override
  Widget build(BuildContext context) {
    final sortiert = [...eintraege]..sort((a, b) {
      final art = (a.istVorrat ? 1 : 0) - (b.istVorrat ? 1 : 0);
      if (art != 0) return art;
      if (a.faellig == null && b.faellig == null) return a.titel.compareTo(b.titel);
      if (a.faellig == null) return 1;
      if (b.faellig == null) return -1;
      return a.faellig!.compareTo(b.faellig!);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Was ist offen?',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (sortiert.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nichts offen 🎉',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          for (final a in sortiert)
            AufgabeZeile(
              eintrag: a,
              heute: heute,
              onDorthin: () => onDorthin(a),
              onSnooze: (t) => onSnooze(a, t),
              onErledigt: () => onErledigt(a),
              onEinplanen: () {},
              onBestaetigen: () {},
            ),
      ],
    );
  }
}
```

`onEinplanen` und `onBestaetigen` bleiben leer: Beide Knöpfe erscheinen nur bei Einsätzen und Saison-Vorschlägen, und die sind nie Büro-Zeilen (`istBueroAufgabe` greift nur bei `/buchhaltung`, `/rechnungen`, `/heineken`).

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/buero_offen_block_test.dart`
Erwartet: BESTANDEN, 5 Tests.

- [ ] **Step 5: CanvasKit-Wächter erweitern**

In `test/canvaskit_sichere_widgets_test.dart` die Dateiliste im Test «Listenzeilen ohne CanvasKit-tote Widgets» um `'lib/presentation/widgets/buero_offen_block.dart'` ergänzen (`buchhaltung_dashboard_screen.dart` folgt in Task 5, wenn sein `ListTile` weg ist).

Run: `flutter test test/canvaskit_sichere_widgets_test.dart`
Erwartet: BESTANDEN.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/buero_offen_block.dart test/buero_offen_block_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: Offen-Block fuer die Buero-Startseite, Fristen vor Vorraeten (B3)"
```

---

### Task 5: Der Screen

**Files:**
- Modify: `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
- Create: `test/buchhaltung_gruppen_waechter_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart`

Drei Änderungen am Screen: der Offen-Block zuoberst, die 13 Ziele in zwei Gruppen, und `_NavTile` von `ListTile` auf eine CanvasKit-sichere Bauart.

- [ ] **Step 1: Offen-Block einbauen** — im `ListView` (ab Zeile ~57), **vor** der camt-Wochenerinnerung, als erstes Kind:

```dart
          // «Was ist offen?» — der Büro-Ausschnitt der einen Aufgabenliste
          // (B3). Fristen und Vorräte zusammen, ganz oben: Die Seite
          // beantwortet damit zuerst die Frage, mit der man sie öffnet.
          Builder(builder: (_) {
            final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
            final aktionen = AufgabenAktionen(ref);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BueroOffenBlock(
                eintraege: liste.where(istBueroAufgabe).toList(),
                heute: DateTime.now(),
                onDorthin: (a) => aktionen.dorthin(context, a),
                onSnooze: (a, t) => aktionen.snooze(context, a, t),
                onErledigt: (a) => aktionen.erledigt(context, a),
              ),
            );
          }),
```

Importe ergänzen: `core/util/aufgabe.dart`, `presentation/providers/aufgaben_providers.dart`, `presentation/widgets/aufgaben_aktionen.dart`, `presentation/widgets/buero_offen_block.dart`. Der Screen ist bereits ein `ConsumerWidget` mit `ref` im `build` — prüfe das mit `grep -n "class BuchhaltungDashboardScreen" -A 4` und melde, falls nicht.

- [ ] **Step 2: Die 13 Ziele gruppieren** — die Überschrift «Bereiche» (Zeile ~139) durch zwei Gruppen ersetzen. Die Ziele bleiben unverändert, nur Reihenfolge und Überschriften ändern sich. Reihenfolge **Laufend**: Bankauszug Import (`/buchhaltung/camt-import`), Eingangsrechnungen (`/buchhaltung/eingangsrechnungen`), Forderungen (`/rechnungen`), Heineken Rechnungen (`/heineken`), Lohnbuchhaltung (`/buchhaltung/lohn`). Danach **Abschluss & Berichte**: Kontenplan (`/buchhaltung/konten`), Journal (`/buchhaltung/buchungen`), Bilanz & Erfolgsrechnung (`/buchhaltung/berichte`), Auswertung (`/buchhaltung/auswertung`), MwSt-Abrechnung (`/buchhaltung/mwst`), Abschlussprüfung (`/buchhaltung/audit`), Steuern (`/buchhaltung/steuern`), Jahresrechnungen (`/jahresrechnung`).

Die Gruppenüberschrift in derselben Form wie das bisherige «Bereiche»:

```dart
          Text(
            'Laufend',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
```

und vor der zweiten Gruppe zusätzlich `const SizedBox(height: 16),` mit dem Text `'Abschluss & Berichte'`.

- [ ] **Step 3: `_NavTile` CanvasKit-sicher** — die Klasse (ab Zeile 373) ersetzen:

```dart
/// Ein Ziel der Büro-Startseite.
///
/// CanvasKit: `InkWell` + `Container` + `Row` statt `ListTile` — es sind 13
/// Navigationsziele, und Material-Komfort-Widgets haben auf dem produktiven
/// CanvasKit-Web dreimal nicht gerendert oder nicht reagiert (CLAUDE.md).
/// Das Aussehen bleibt: Kreis-Symbol, Titel, Untertitel, Pfeil.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Den Gruppen-Wächter schreiben** — `test/buchhaltung_gruppen_waechter_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jedes Ziel der Büro-Startseite steht in genau einer Gruppe (B3).
///
/// WARUM: Die 13 Ziele lagen auf einer Ebene — Kontenplan neben
/// Bankauszug-Import, Jahresrechnungen neben Lohn (Befund 4 der App-Analyse
/// 09/2026). Seit B3 gibt es «Laufend» und «Abschluss & Berichte». Ein neues
/// Ziel, das jemand einfach ans Ende hängt, landet sonst stumm in der
/// falschen Gruppe.
void main() {
  final quelle = File(
    'lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart',
  ).readAsStringSync();

  const laufend = [
    '/buchhaltung/camt-import',
    '/buchhaltung/eingangsrechnungen',
    '/rechnungen',
    '/heineken',
    '/buchhaltung/lohn',
  ];
  const abschluss = [
    '/buchhaltung/konten',
    '/buchhaltung/buchungen',
    '/buchhaltung/berichte',
    '/buchhaltung/auswertung',
    '/buchhaltung/mwst',
    '/buchhaltung/audit',
    '/buchhaltung/steuern',
    '/jahresrechnung',
  ];

  test('beide Gruppenueberschriften stehen im Screen', () {
    expect(quelle.contains("'Laufend'"), isTrue);
    expect(quelle.contains("'Abschluss & Berichte'"), isTrue);
    expect(quelle.contains("'Bereiche'"), isFalse,
        reason: 'die alte Sammelueberschrift ist ersetzt');
  });

  test('jedes _NavTile-Ziel gehoert zu genau einer Gruppe', () {
    // Nur die Ziele der Navigations-Kacheln, nicht jeder push im Screen:
    // `_NavTile`-Bloecke tragen ihren push im selben Abschnitt.
    final ziele = <String>[];
    for (final block in quelle.split('_NavTile(').skip(1)) {
      final treffer =
          RegExp(r"context\.push\('([^']+)'\)").firstMatch(block);
      if (treffer != null) ziele.add(treffer.group(1)!);
    }
    expect(ziele, hasLength(13), reason: 'gefunden: $ziele');

    final beide = laufend.toSet().intersection(abschluss.toSet());
    expect(beide, isEmpty, reason: 'in beiden Gruppen: $beide');

    final heimatlos =
        ziele.where((z) => !laufend.contains(z) && !abschluss.contains(z));
    expect(heimatlos, isEmpty,
        reason: 'Ziele ohne Gruppe (Liste im Test ergaenzen): $heimatlos');
  });

  test('die Reihenfolge im Screen folgt den Gruppen', () {
    // Ueber die Reihenfolge der Kacheln selbst pruefen, nicht ueber
    // `indexOf` in der ganzen Datei: `/rechnungen` kommt im Screen auch
    // ausserhalb der Kacheln vor, und `indexOf` faende das erste Vorkommen.
    final ziele = <String>[];
    for (final block in quelle.split('_NavTile(').skip(1)) {
      final treffer =
          RegExp(r"context\.push\('([^']+)'\)").firstMatch(block);
      if (treffer != null) ziele.add(treffer.group(1)!);
    }
    expect(ziele.take(laufend.length), orderedEquals(laufend));
    expect(ziele.skip(laufend.length), orderedEquals(abschluss));

    final iLaufend = quelle.indexOf("'Laufend'");
    final iAbschluss = quelle.indexOf("'Abschluss & Berichte'");
    expect(iLaufend, lessThan(iAbschluss),
        reason: 'Laufend steht vor Abschluss & Berichte');
  });
}
```

- [ ] **Step 5: CanvasKit-Wächter und Tests**

In `test/canvaskit_sichere_widgets_test.dart` zusätzlich `'lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart'` in die Dateiliste aufnehmen. Schlägt der Wächter danach an, weil der Screen an einer **anderen** Stelle noch ein `ListTile` nutzt (z. B. in der Buchungs-Vorschau um Zeile 268): baue auch diese Stelle auf `InkWell` + `Container` + `Row` um — melde im Report, welche Stellen es betraf.

Run: `flutter test test/buchhaltung_gruppen_waechter_test.dart test/canvaskit_sichere_widgets_test.dart`
Erwartet: BESTANDEN.

Run: `flutter analyze` → 56. Dann `flutter test` komplett → grün.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart test/buchhaltung_gruppen_waechter_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: Buero-Startseite zeigt oben was offen ist, 13 Ziele in zwei Gruppen (B3)"
```

---

### Task 6: Sichtprüfung, Version, Auslieferung, Doku

Macht der Koordinator selbst.

- [ ] **Step 1: Volle Suite und Analyse**

Run: `flutter analyze && flutter test`
Erwartet: 56 Befunde oder weniger, alle Tests grün.

- [ ] **Step 2: Sichtprüfung im Browser**

Wegwerf-Datei `lib/heute_probe.dart` (wie bei B1/B2/B6), gebaut mit `flutter build web -t lib/heute_probe.dart --base-href "/"` und über `.claude/launch.json` («flutter-web») geöffnet. Sie zeigt auf 360 px und 1400 px:

1. `BueroOffenBlock` mit zwei Fristen und drei Vorräten — Reihenfolge, Farben, Knöpfe je Zeile.
2. Denselben Block leer («Nichts offen 🎉»).
3. Drei `_NavTile` in neuer Bauart mit Gruppenüberschrift — Aussehen wie vorher (Kreis, Titel, Untertitel, Pfeil).

Danach löschen, nie committen.

- [ ] **Step 3: Version und Auslieferung**

`pubspec.yaml` Zeile 4 auf `0.108.0+754`, `kAppVersion` auf `'0.108.0'`; `flutter test test/app_version_test.dart`. Dann nach `CLAUDE.md`: Build mit `--base-href "/sbs-projer-dev/" --pwa-strategy=none`, `main.dart.js` in `flutter_bootstrap.js` cache-busten, `flutter_service_worker.js` löschen, `404.html` mitliefern, auf `gh-pages` ausliefern, Live-`version.json` prüfen.

- [ ] **Step 4: Doku**

- `ToDo.md`: B3 erledigt, mit der Unterscheidung Frist/Vorrat und dem Hinweis, dass fehlende Ertragsbuchungen und Versandvermerke aus der Glocke verschwunden sind.
- `docs/app-analyse-2026-09.md`: B3 ✅ mit der Abweichung (Lohn gehört zu «Laufend»).
- Memory `app_analyse_2026_09.md` und `MEMORY.md` nachziehen.

**Klicktest Daniel:** Die Büro-Startseite zeigt oben, was offen ist · Bank-Prüfliste und offene Eingangsrechnungen stehen dort, **nicht** in der Glocke · MwSt und Heineken-Rechnung weiterhin in beiden · Snooze auf einer Büro-Zeile wirkt auch in der Glocke · die 13 Ziele stehen in zwei Gruppen · alle 13 Ziele lassen sich antippen (neue `_NavTile`-Bauart).

---

## Nach der Auslieferung

- [ ] Klicktest Daniel (Task 6).
- [ ] Zusammen mit der B1-Nachschau in zwei Wochen: Wird `/buchhaltung` am PC häufiger geöffnet, und werden die Prüflisten-Stapel kleiner? Das zeigt, ob der Offen-Block trägt.
