# Navigation «Mehr» und Neuordnung der Bereiche — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fünftes Leisten-Ziel «Mehr» mit thematisch gruppierten Bereichen, Heute nur noch als Tagesansicht, Büro in eigene Bereiche aufgeteilt — ausgeliefert als v0.131.0 und v0.132.0.

**Architecture:** Welche Bereiche welche Einträge haben, steht als Daten in `lib/core/config/bereiche.dart`. Ein Widget `BereichGruppenListe` zeichnet daraus Kacheln und Zeilen, `BereichScreen` rahmt es als Seite. Ein `BereichReiter` (Umschalter unter der AppBar) wechselt per `context.go` zwischen bestehenden Routen, statt Screens einzubetten. Wächter-Tests halten Erreichbarkeit, Leuchten der Leiste und CanvasKit-Regel fest.

**Tech Stack:** Flutter (CanvasKit-Web), Riverpod, GoRouter, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-22-navigation-mehr-design.md`

---

## Vorab für den Ausführenden

- Arbeitsverzeichnis für alle Befehle: `sbs_projer_app/`. In Git Bash zuerst
  `export PATH="$PATH:/c/flutter/bin"`.
- Tests: `flutter test test/<datei>.dart`; alle: `flutter test`.
- `flutter analyze` steht vorher bei **56 Infos** — das ist das Grundrauschen
  und muss nach jedem Task gleich bleiben (keine neuen Warnungen).
- **CanvasKit-Regel (CLAUDE.md):** In neuen Widgets keine `FilledButton`,
  `OutlinedButton`, `ElevatedButton`, `ListTile`, `ExpansionTile`, `TabBar`,
  `NavigationBar`. Bauen aus `InkWell`/`GestureDetector` + `Container` +
  `Row`/`Column`, Knöpfe über `TapKnopf`.
- Kommentare auf Deutsch, im Stil der Umgebung: **warum**, nicht was.
- **Nie `git stash`.** Jeder Task endet mit einem Commit auf `main`.
- Commit-Nachrichten enden mit
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Dateien

| Datei | Aufgabe |
|---|---|
| `lib/core/util/navigation_ziele.dart` | ändern: `NavZiel.mehr`, `aktivesZiel` nie mehr `null` |
| `lib/core/config/bereiche.dart` | **neu**: Datenmodell, alle Bereiche, `bereichFuerPfad`, `zaehleJeBereich` |
| `lib/presentation/providers/bereich_zaehler_provider.dart` | **neu**: Zähler je Eintrag aus bestehenden Providern |
| `lib/presentation/widgets/dashboard_tile.dart` | **neu**: `DashboardTile` aus `home_screen.dart` herausgelöst |
| `lib/presentation/widgets/bereich_gruppen_liste.dart` | **neu**: Gruppen als Kacheln/Zeilen |
| `lib/presentation/screens/bereich_screen.dart` | **neu**: Seite um eine `BereichGruppenListe` |
| `lib/presentation/widgets/bank_waechter_karte.dart` | **neu**: `_BankWaechterCard` aus dem Dashboard herausgelöst |
| `lib/presentation/widgets/camt_erinnerung_karte.dart` | **neu**: Wochen-Erinnerung aus dem Dashboard herausgelöst |
| `lib/presentation/widgets/bereich_reiter.dart` | **neu**: Umschalter unter der AppBar |
| `lib/presentation/screens/einstellungen/stammdaten_screen.dart` | **neu**: Stammdaten-Teile aus den Einstellungen |
| `lib/presentation/screens/einstellungen/einstellungen_screen.dart` | ändern: nur noch Technik + Abmelden/Sync/Version |
| `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` | ändern: verkleinert |
| `lib/presentation/screens/home_screen.dart` | ändern: nur der Tag (+ Event-Karte in Task 14) |
| `lib/core/util/event_fenster.dart` | **neu** (Task 14): `eventImFenster` |
| `lib/presentation/widgets/event_karte.dart` | **neu** (Task 14) |
| `lib/core/config/router.dart` | ändern: neue Routen |
| Tests | siehe Tasks |

---

# Teil A — v0.131.0

## Task 1: Leisten-Ziel «Mehr»

**Files:**
- Modify: `lib/core/util/navigation_ziele.dart`
- Test: `test/navigation_ziele_test.dart`

- [ ] **Step 1: Tests anpassen (sie schlagen danach fehl)**

In `test/navigation_ziele_test.dart` den Test `'vier Ziele mit Pfad und Beschriftung'` ersetzen durch:

```dart
    test('fuenf Ziele mit Pfad und Beschriftung', () {
      expect(NavZiel.values, [
        NavZiel.heute,
        NavZiel.einsaetze,
        NavZiel.betriebe,
        NavZiel.tour,
        NavZiel.mehr,
      ]);
      expect(navPfad(NavZiel.heute), '/');
      expect(navPfad(NavZiel.einsaetze), '/einsaetze');
      expect(navPfad(NavZiel.betriebe), '/betriebe');
      expect(navPfad(NavZiel.tour), '/touren');
      expect(navPfad(NavZiel.mehr), '/mehr');
      expect(navLabel(NavZiel.heute), 'Heute');
      expect(navLabel(NavZiel.einsaetze), 'Einsätze');
      expect(navLabel(NavZiel.betriebe), 'Betriebe');
      expect(navLabel(NavZiel.tour), 'Tour');
      expect(navLabel(NavZiel.mehr), 'Mehr');
    });
```

Den Test `'Fremdes hebt nichts hervor — die Leiste bleibt trotzdem'` ersetzen durch:

```dart
    test('alles uebrige leuchtet «Mehr»', () {
      for (final p in [
        '/mehr',
        '/buchhaltung',
        '/buchhaltung/mwst',
        '/rechnungen/abc',
        '/heineken',
        '/aufgaben',
        '/stammdaten',
        '/einstellungen',
      ]) {
        expect(aktivesZiel(p), NavZiel.mehr, reason: p);
      }
      expect(zeigtNavigation('/buchhaltung'), isTrue);
    });

    test('Personen gehoeren zu den Betrieben', () {
      expect(aktivesZiel('/kontakte'), NavZiel.betriebe);
      expect(aktivesZiel('/kontakte/abc/bearbeiten'), NavZiel.betriebe);
    });
```

Und im Test `'ein Praefix darf keinen anderen Namen kapern'` die Erwartung ändern:

```dart
      expect(aktivesZiel('/betriebe-alt'), NavZiel.mehr);
```

- [ ] **Step 2: Test laufen lassen**

Run: `flutter test test/navigation_ziele_test.dart`
Expected: FAIL — `NavZiel.mehr` existiert nicht (Compile-Fehler).

- [ ] **Step 3: Implementieren**

In `lib/core/util/navigation_ziele.dart`:

Den Bibliotheks-Kommentar oben um einen Absatz ergänzen (nach «…über «Weitere» auf der Startseite erreichbar.»):

```dart
///
/// Seit v0.131.0 fünftes Ziel «Mehr»: Alles unterhalb der Heute-Liste war
/// schlecht erreichbar, je länger der Tagesplan, desto tiefer. «Mehr» ist
/// von jeder Seite aus einen Tipp entfernt, und jede Seite ausserhalb der
/// ersten vier Ziele lässt es leuchten — vorher leuchtete dort nichts.
```

Enum und die drei `switch`-Funktionen:

```dart
enum NavZiel { heute, einsaetze, betriebe, tour, mehr }

String navPfad(NavZiel z) => switch (z) {
  NavZiel.heute => '/',
  NavZiel.einsaetze => '/einsaetze',
  NavZiel.betriebe => '/betriebe',
  NavZiel.tour => '/touren',
  NavZiel.mehr => '/mehr',
};

String navLabel(NavZiel z) => switch (z) {
  NavZiel.heute => 'Heute',
  NavZiel.einsaetze => 'Einsätze',
  NavZiel.betriebe => 'Betriebe',
  NavZiel.tour => 'Tour',
  NavZiel.mehr => 'Mehr',
};

IconData navIcon(NavZiel z) => switch (z) {
  NavZiel.heute => Icons.today,
  NavZiel.einsaetze => Icons.assignment,
  NavZiel.betriebe => Icons.store,
  NavZiel.tour => Icons.route,
  NavZiel.mehr => Icons.apps,
};
```

Nach `_einsatzPraefixe` einfügen:

```dart
/// Die Personen sind seit v0.131.0 ein Reiter der Betriebe-Liste — das
/// Leuchten bleibt deshalb bei «Betriebe».
const _betriebPraefixe = ['/kontakte'];
```

`aktivesZiel` ersetzen (Rückgabetyp jetzt **nicht** nullbar):

```dart
/// Welches Ziel ist hervorgehoben? Immer genau eines: Was zu keinem der
/// ersten vier gehört, gehört zu «Mehr».
NavZiel aktivesZiel(String pfad) {
  final p = _ohneSchraegstrich(pfad);
  if (p == '/') return NavZiel.heute;
  for (final z in [NavZiel.einsaetze, NavZiel.betriebe, NavZiel.tour]) {
    if (_unter(p, navPfad(z))) return z;
  }
  for (final e in _einsatzPraefixe) {
    if (_unter(p, e)) return NavZiel.einsaetze;
  }
  for (final b in _betriebPraefixe) {
    if (_unter(p, b)) return NavZiel.betriebe;
  }
  return NavZiel.mehr;
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/navigation_ziele_test.dart`
Expected: PASS

- [ ] **Step 5: Leisten-Widget-Test auf fünf Ziele**

In `test/haupt_navigation_test.dart` jede Liste `['Heute', 'Einsätze', 'Betriebe', 'Tour']` ersetzen durch `['Heute', 'Einsätze', 'Betriebe', 'Tour', 'Mehr']` und den Testnamen `'zeigt alle vier Ziele'` in `'zeigt alle fuenf Ziele'` ändern. Im Test `'Tippen meldet das Ziel'` am Ende ergänzen:

```dart
    await tester.tap(find.text('Mehr'));
    expect(gewaehlt, NavZiel.mehr);
```

`lib/presentation/widgets/haupt_navigation.dart` braucht keine Änderung — es iteriert über `NavZiel.values`.

Run: `flutter test test/haupt_navigation_test.dart test/navigation_ziele_test.dart test/formular_ohne_navigation_waechter_test.dart`
Expected: PASS (der 360-px-Test beweist, dass fünf Beschriftungen passen).

- [ ] **Step 6: Analyse**

Run: `flutter analyze`
Expected: 56 issues. Meldet es an einer Aufrufstelle von `aktivesZiel` «unnecessary null comparison», dort den Null-Vergleich entfernen.

- [ ] **Step 7: Commit**

```bash
git add lib/core/util/navigation_ziele.dart test/navigation_ziele_test.dart test/haupt_navigation_test.dart
git commit -m "feat(nav): fuenftes Leisten-Ziel Mehr, jede Seite leuchtet ein Ziel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: Bereiche als Daten

**Files:**
- Create: `lib/core/config/bereiche.dart`
- Test: `test/bereiche_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/bereiche_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';

void main() {
  group('bereichFuerPfad', () {
    test('Rechnungen', () {
      for (final p in [
        '/rechnungen',
        '/rechnungen/abc',
        '/rechnungen/pro-betrieb',
        '/heineken',
        '/heineken/abc',
        '/jahresrechnung',
        '/bergkundenpauschalen',
        '/buchhaltung/mahnwesen',
        '/buchhaltung/debitoren',
      ]) {
        expect(bereichFuerPfad(p), 'rechnungen', reason: p);
      }
    });

    test('Bank und Zahlungen', () {
      for (final p in [
        '/bank',
        '/buchhaltung/camt-import',
        '/buchhaltung/camt-pruefliste',
        '/buchhaltung/eingangsrechnungen',
        '/buchhaltung/eingangsrechnungen/abc',
      ]) {
        expect(bereichFuerPfad(p), 'bank', reason: p);
      }
    });

    test('Abschluesse und Steuern', () {
      for (final p in [
        '/abschluesse',
        '/buchhaltung/mwst',
        '/buchhaltung/monatsabschluss',
        '/buchhaltung/audit',
        '/buchhaltung/abschreibung',
        '/buchhaltung/steuern',
        '/buchhaltung/steuern/2025',
      ]) {
        expect(bereichFuerPfad(p), 'abschluesse', reason: p);
      }
    });

    test('Lohn vor Buchhaltung, Rest der Buchhaltung bleibt Buchhaltung', () {
      expect(bereichFuerPfad('/buchhaltung/lohn'), 'lohn');
      expect(bereichFuerPfad('/buchhaltung/lohn/einstellungen'), 'lohn');
      expect(bereichFuerPfad('/buchhaltung'), 'buchhaltung');
      expect(bereichFuerPfad('/buchhaltung/konten'), 'buchhaltung');
      expect(bereichFuerPfad('/buchhaltung/buchungen/abc'), 'buchhaltung');
    });

    test('Dokumente; ausserhalb des Bueros nichts', () {
      expect(bereichFuerPfad('/dokumente'), 'dokumente');
      expect(bereichFuerPfad('/touren'), isNull);
      expect(bereichFuerPfad('/betriebe/abc'), isNull);
      expect(bereichFuerPfad('/'), isNull);
      // Kein Namens-Kapern: /heinekenfest ist nicht /heineken.
      expect(bereichFuerPfad('/heinekenfest'), isNull);
    });
  });

  group('zaehleJeBereich', () {
    test('zaehlt Routen je Buero-Bereich, ignoriert null und Fremdes', () {
      final n = zaehleJeBereich([
        '/heineken',
        '/rechnungen',
        '/buchhaltung/mwst',
        '/buchhaltung/camt-pruefliste',
        '/touren',
        null,
      ]);
      expect(n, {'rechnungen': 2, 'abschluesse': 1, 'bank': 1});
    });
  });

  group('Bereichs-Liste', () {
    test('Mehr hat die drei Gruppen in der richtigen Reihenfolge', () {
      expect(kBereichMehr.gruppen.map((g) => g.titel).toList(), [
        'Unterwegs',
        'Büro',
        'Einrichtung',
      ]);
      expect(kBereichMehr.gruppen.first.alsKacheln, isTrue);
      expect(
        kBereichMehr.gruppen.first.eintraege.map((e) => e.titel).toList(),
        ['Spesen', 'Material', 'Aufgaben', 'Events'],
      );
      expect(
        kBereichMehr.gruppen[1].eintraege.map((e) => e.ziel).toList(),
        [
          '/rechnungen',
          '/bank',
          '/buchhaltung',
          '/buchhaltung/lohn',
          '/abschluesse',
          '/dokumente',
        ],
      );
      expect(
        kBereichMehr.gruppen[2].eintraege.map((e) => e.ziel).toList(),
        ['/auswertungen', '/stammdaten', '/einstellungen'],
      );
    });

    test('kein Ziel steht in zwei Bereichsseiten ausser Mehr', () {
      // Mehr verweist absichtlich auf die Bereichsseiten; innerhalb der
      // Bereichsseiten gehoert jedes Ziel an genau einen Ort (vorher B3-
      // Waechter der Buchhaltungs-Gruppen).
      final gesehen = <String, String>{};
      for (final b in kAlleBereiche.where((b) => b.id != 'mehr')) {
        for (final e in b.alleEintraege) {
          expect(
            gesehen.containsKey(e.ziel),
            isFalse,
            reason: '${e.ziel} in ${gesehen[e.ziel]} und ${b.id}',
          );
          gesehen[e.ziel] = b.id;
        }
      }
    });

    test('Bereichs-IDs sind eindeutig', () {
      final ids = kAlleBereiche.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen**

Run: `flutter test test/bereiche_test.dart`
Expected: FAIL — Datei `bereiche.dart` fehlt.

- [ ] **Step 3: Implementieren**

`lib/core/config/bereiche.dart`:

```dart
/// Welche Bereiche die App hat und was darin steht — als Daten (v0.131.0).
///
/// WARUM als Daten: Die Einträge der Startseite, der Buchhaltung und der
/// Einstellungen waren über drei Screens verstreut, und jedes Umhängen hiess
/// Screen-Code anfassen. Hier steht die Ordnung einmal; die Mehr-Seite und
/// alle Bereichsseiten zeichnen sich daraus, und die Wächter-Tests prüfen
/// gegen dieselbe Liste, ob jeder Screen erreichbar ist.
library;

import 'package:flutter/material.dart';

/// Woher der Zähler eines Eintrags kommt. Es gibt bewusst keine neue
/// Zähl-Logik: Alles stammt aus Providern, die es schon gibt.
enum ZaehlerQuelle {
  /// «N niedrig» — Materialbestand unter Mindestmenge.
  materialNiedrig,

  /// Dieselbe Zahl wie die Glocke.
  aufgaben,

  /// Offene Aufgaben, deren Sprungziel in diesen Büro-Bereich führt.
  bereich,
}

class BereichEintrag {
  final String titel;
  final String? untertitel;
  final IconData icon;

  /// Route, die beim Antippen per `context.push` geöffnet wird.
  final String ziel;
  final ZaehlerQuelle? zaehler;

  const BereichEintrag({
    required this.titel,
    this.untertitel,
    required this.icon,
    required this.ziel,
    this.zaehler,
  });
}

class BereichGruppe {
  final String? titel;

  /// Kacheln im 2er-Raster statt Zeilen — nur für wenige, oft genutzte Ziele.
  final bool alsKacheln;
  final List<BereichEintrag> eintraege;

  const BereichGruppe({
    this.titel,
    this.alsKacheln = false,
    required this.eintraege,
  });
}

class Bereich {
  final String id;
  final String titel;
  final List<BereichGruppe> gruppen;

  const Bereich({required this.id, required this.titel, required this.gruppen});

  Iterable<BereichEintrag> get alleEintraege =>
      gruppen.expand((g) => g.eintraege);
}

// ---------------------------------------------------------------------------
// Pfad → Büro-Bereich
// ---------------------------------------------------------------------------

/// Reihenfolge ist Vorrang: Spezielles vor Allgemeinem, `/buchhaltung`
/// zuletzt als Sammelbecken. Ein Präfix auf `-` gilt als Wortanfang
/// (`/buchhaltung/camt-` fängt camt-import, camt-pruefliste, …).
const _bereichPraefixe = <(String, String)>[
  ('/rechnungen', 'rechnungen'),
  ('/heineken', 'rechnungen'),
  ('/jahresrechnung', 'rechnungen'),
  ('/bergkundenpauschalen', 'rechnungen'),
  ('/buchhaltung/mahnwesen', 'rechnungen'),
  ('/buchhaltung/debitoren', 'rechnungen'),
  ('/bank', 'bank'),
  ('/buchhaltung/camt-', 'bank'),
  ('/buchhaltung/eingangsrechnungen', 'bank'),
  ('/buchhaltung/lohn', 'lohn'),
  ('/abschluesse', 'abschluesse'),
  ('/buchhaltung/mwst', 'abschluesse'),
  ('/buchhaltung/monatsabschluss', 'abschluesse'),
  ('/buchhaltung/audit', 'abschluesse'),
  ('/buchhaltung/abschreibung', 'abschluesse'),
  ('/buchhaltung/steuern', 'abschluesse'),
  ('/dokumente', 'dokumente'),
  ('/buchhaltung', 'buchhaltung'),
];

/// Zu welchem Büro-Bereich gehört [pfad]? `null` ausserhalb des Büros.
String? bereichFuerPfad(String pfad) {
  for (final (praefix, id) in _bereichPraefixe) {
    final trifft = praefix.endsWith('-')
        ? pfad.startsWith(praefix)
        : pfad == praefix || pfad.startsWith('$praefix/');
    if (trifft) return id;
  }
  return null;
}

/// Wie viele der [routen] führen in welchen Büro-Bereich?
Map<String, int> zaehleJeBereich(Iterable<String?> routen) {
  final n = <String, int>{};
  for (final r in routen) {
    if (r == null) continue;
    final id = bereichFuerPfad(r);
    if (id != null) n[id] = (n[id] ?? 0) + 1;
  }
  return n;
}

// ---------------------------------------------------------------------------
// Die Bereiche
// ---------------------------------------------------------------------------

const kBereichMehr = Bereich(
  id: 'mehr',
  titel: 'Mehr',
  gruppen: [
    BereichGruppe(
      titel: 'Unterwegs',
      alsKacheln: true,
      eintraege: [
        BereichEintrag(
          titel: 'Spesen',
          icon: Icons.receipt_long,
          ziel: '/spesen',
        ),
        BereichEintrag(
          titel: 'Material',
          icon: Icons.inventory_2,
          ziel: '/materialien',
          zaehler: ZaehlerQuelle.materialNiedrig,
        ),
        BereichEintrag(
          titel: 'Aufgaben',
          icon: Icons.task_alt,
          ziel: '/aufgaben',
          zaehler: ZaehlerQuelle.aufgaben,
        ),
        BereichEintrag(
          titel: 'Events',
          icon: Icons.festival,
          ziel: '/events',
        ),
      ],
    ),
    BereichGruppe(
      titel: 'Büro',
      eintraege: [
        BereichEintrag(
          titel: 'Rechnungen',
          untertitel: 'Kunden, Heineken, pro Betrieb',
          icon: Icons.request_quote,
          ziel: '/rechnungen',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Bank und Zahlungen',
          untertitel: 'Bankauszug, Eingangsrechnungen',
          icon: Icons.account_balance,
          ziel: '/bank',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Buchhaltung',
          untertitel: 'Konten, Journal, Bilanz',
          icon: Icons.menu_book,
          ziel: '/buchhaltung',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Lohn',
          untertitel: 'Lohnlauf, Lohnausweis',
          icon: Icons.payments,
          ziel: '/buchhaltung/lohn',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Abschlüsse und Steuern',
          untertitel: 'Monat, MWST, Jahr, Steuern',
          icon: Icons.fact_check,
          ziel: '/abschluesse',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Dokumente',
          icon: Icons.folder_open,
          ziel: '/dokumente',
          zaehler: ZaehlerQuelle.bereich,
        ),
      ],
    ),
    BereichGruppe(
      titel: 'Einrichtung',
      eintraege: [
        BereichEintrag(
          titel: 'Auswertungen',
          untertitel: 'Umsatz, Arbeitstage, Nutzung',
          icon: Icons.insights,
          ziel: '/auswertungen',
        ),
        BereichEintrag(
          titel: 'Stammdaten',
          untertitel: 'Firma, Preise, Regionen, Anlagen',
          icon: Icons.dataset,
          ziel: '/stammdaten',
        ),
        BereichEintrag(
          titel: 'Einstellungen',
          untertitel: 'Google, Speicher, Abmelden',
          icon: Icons.settings,
          ziel: '/einstellungen',
        ),
      ],
    ),
  ],
);

const kBereichBank = Bereich(
  id: 'bank',
  titel: 'Bank und Zahlungen',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Bankauszug Import',
          untertitel: 'Import, Prüfliste, Regeln und Dateien',
          icon: Icons.account_balance,
          ziel: '/buchhaltung/camt-import',
        ),
        BereichEintrag(
          titel: 'Eingangsrechnungen',
          untertitel: 'Lieferantenrechnungen erfassen und buchen',
          icon: Icons.mark_email_read,
          ziel: '/buchhaltung/eingangsrechnungen',
        ),
      ],
    ),
  ],
);

const kBereichAbschluesse = Bereich(
  id: 'abschluesse',
  titel: 'Abschlüsse und Steuern',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Monatsabschluss',
          untertitel: 'Zehn Punkte je Monat: Einsätze, Heineken, Bank, Lohn',
          icon: Icons.event_available,
          ziel: '/buchhaltung/monatsabschluss',
        ),
        BereichEintrag(
          titel: 'MwSt-Abrechnung',
          untertitel: 'Quartals-Abrechnung ESTV',
          icon: Icons.account_balance,
          ziel: '/buchhaltung/mwst',
        ),
        BereichEintrag(
          titel: 'Abschlussprüfung',
          untertitel: 'Jahres-Check, Jahrgang abschreiben',
          icon: Icons.fact_check,
          ziel: '/buchhaltung/audit',
        ),
        BereichEintrag(
          titel: 'Steuern',
          untertitel: 'Veranlagungen, Zahlungen, Unterlagen',
          icon: Icons.gavel,
          ziel: '/buchhaltung/steuern',
        ),
      ],
    ),
  ],
);

const kBereichAuswertungen = Bereich(
  id: 'auswertungen',
  titel: 'Auswertungen',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Umsatz und Arbeiten',
          untertitel: 'Nach Jahr und Monat',
          icon: Icons.insights,
          ziel: '/buchhaltung/auswertung',
        ),
        BereichEintrag(
          titel: 'Arbeitstage',
          untertitel: 'Arbeitszeit, Fahrten und Einsätze pro Tag',
          icon: Icons.query_stats,
          ziel: '/auswertungen/arbeitstage',
        ),
        BereichEintrag(
          titel: 'Nutzung der App',
          untertitel: 'Welcher Bereich wird wie oft geöffnet',
          icon: Icons.bar_chart,
          ziel: '/auswertungen/nutzung',
        ),
      ],
    ),
  ],
);

/// Die Einträge unter den Kennzahlen der Buchhaltung.
///
/// Die Gruppe «Rechnungen» ist ein Übergang: Heineken, Jahresrechnungen,
/// Bergkundenpauschalen und Mahnwesen ziehen mit v0.132.0 in den
/// Rechnungs-Bereich (Reiter). Bis dahin stünden sie sonst nirgends.
const kBereichBuchhaltung = Bereich(
  id: 'buchhaltung',
  titel: 'Buchhaltung',
  gruppen: [
    BereichGruppe(
      titel: 'Bücher',
      eintraege: [
        BereichEintrag(
          titel: 'Kontenplan',
          untertitel: 'Konten nach Schweizer KMU-Standard',
          icon: Icons.account_tree,
          ziel: '/buchhaltung/konten',
        ),
        BereichEintrag(
          titel: 'Journal',
          untertitel: 'Alle Buchungen anzeigen',
          icon: Icons.menu_book,
          ziel: '/buchhaltung/buchungen',
        ),
        BereichEintrag(
          titel: 'Bilanz und Erfolgsrechnung',
          untertitel: 'Per Datum',
          icon: Icons.assessment,
          ziel: '/buchhaltung/berichte',
        ),
      ],
    ),
    BereichGruppe(
      titel: 'Rechnungen',
      eintraege: [
        BereichEintrag(
          titel: 'Heineken Rechnungen',
          untertitel: 'Monatsrechnungen erstellen',
          icon: Icons.receipt_long_outlined,
          ziel: '/heineken',
        ),
        BereichEintrag(
          titel: 'Jahresrechnungen',
          untertitel: 'Sammelrechnungen pro Betrieb',
          icon: Icons.calendar_month,
          ziel: '/jahresrechnung',
        ),
        BereichEintrag(
          titel: 'Bergkundenpauschalen',
          icon: Icons.landscape,
          ziel: '/bergkundenpauschalen',
        ),
        BereichEintrag(
          titel: 'Mahnwesen',
          untertitel: 'Überfällige Rechnungen, Mahnstufen',
          icon: Icons.notification_important,
          ziel: '/buchhaltung/mahnwesen',
        ),
      ],
    ),
  ],
);

const kAlleBereiche = [
  kBereichMehr,
  kBereichBank,
  kBereichAbschluesse,
  kBereichAuswertungen,
  kBereichBuchhaltung,
];
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/bereiche_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/bereiche.dart test/bereiche_test.dart
git commit -m "feat(nav): Bereiche als Daten mit Pfad-Zuordnung

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: `DashboardTile` herauslösen und Zähler-Provider

**Files:**
- Create: `lib/presentation/widgets/dashboard_tile.dart`
- Create: `lib/presentation/providers/bereich_zaehler_provider.dart`
- Modify: `lib/presentation/screens/home_screen.dart` (Klasse `DashboardTile`, Zeilen 283–378, entfernen)
- Modify: `test/kachel_text_test.dart` (Import)

- [ ] **Step 1: `DashboardTile` verschieben**

Die Klasse `DashboardTile` aus `home_screen.dart` (Zeilen 283–378, mitsamt ihren Kommentaren) **unverändert** nach `lib/presentation/widgets/dashboard_tile.dart` verschieben. Kopf der neuen Datei:

```dart
import 'package:flutter/material.dart';

/// Kachel mit Symbol, optionalem Zähler und Beschriftung — bis v0.130.0 auf
/// der Startseite, seit v0.131.0 in der Gruppe «Unterwegs» der Mehr-Seite.
```

In `home_screen.dart` oben `import 'package:sbs_projer_app/presentation/widgets/dashboard_tile.dart';` ergänzen (bis Task 7 nutzt `_KachelGrid` sie noch).

In `test/kachel_text_test.dart` den Import `package:sbs_projer_app/presentation/screens/home_screen.dart` ersetzen durch `package:sbs_projer_app/presentation/widgets/dashboard_tile.dart`. Den Quelltext-Test am Ende (`'die Startseite zeigt nur noch die drei Kacheln ohne Leisten-Ziel'`) bis Task 7 so lassen — er liest `home_screen.dart` als Datei und bleibt grün.

- [ ] **Step 2: Zähler-Provider schreiben**

`lib/presentation/providers/bereich_zaehler_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';

/// Zählertext je Bereichs-Eintrag, `null` = kein Zähler.
///
/// Dieselben Quellen wie Glocke und frühere Kacheln (B6): kein Eintrag
/// rechnet selbst aus Einsatz-Providern — sonst zeigen zwei Stellen zwei
/// Zahlen für dasselbe.
final bereichZaehlerProvider = Provider<String? Function(BereichEintrag)>((
  ref,
) {
  final niedrig = ref.watch(niedrigCountProvider);
  final badge = ref.watch(aufgabenBadgeProvider);
  final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
  final jeBereich = zaehleJeBereich(liste.map((a) => a.route));

  return (e) {
    switch (e.zaehler) {
      case null:
        return null;
      case ZaehlerQuelle.materialNiedrig:
        return niedrig > 0 ? '$niedrig niedrig' : null;
      case ZaehlerQuelle.aufgaben:
        return badge > 0 ? '$badge' : null;
      case ZaehlerQuelle.bereich:
        final id = bereichFuerPfad(e.ziel);
        final n = id == null ? 0 : (jeBereich[id] ?? 0);
        return n > 0 ? '$n offen' : null;
    }
  };
});
```

- [ ] **Step 3: Tests und Analyse**

Run: `flutter test test/kachel_text_test.dart && flutter analyze`
Expected: PASS, 56 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/dashboard_tile.dart lib/presentation/providers/bereich_zaehler_provider.dart lib/presentation/screens/home_screen.dart test/kachel_text_test.dart
git commit -m "refactor: DashboardTile eigene Datei, Zaehler je Bereichs-Eintrag

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 4: `BereichGruppenListe` und `BereichScreen`

**Files:**
- Create: `lib/presentation/widgets/bereich_gruppen_liste.dart`
- Create: `lib/presentation/screens/bereich_screen.dart`
- Test: `test/bereich_gruppen_liste_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/bereich_gruppen_liste_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

void main() {
  // Echte Schrift, sonst misst der Test eine breitere Ersatzschrift
  // (Fehlalarme vom 13. und 15.09.2026, siehe kachel_text_test.dart).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    String? Function(BereichEintrag)? zaehler,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final getippt = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              BereichGruppenListe(
                gruppen: kBereichMehr.gruppen,
                zaehler: zaehler ?? (_) => null,
                onTap: getippt.add,
              ),
            ],
          ),
        ),
      ),
    );
    return getippt;
  }

  testWidgets('zeigt Gruppenkoepfe und alle Eintraege der Mehr-Seite', (
    tester,
  ) async {
    await pump(tester);
    for (final t in ['Unterwegs', 'Büro', 'Einrichtung']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final e in kBereichMehr.alleEintraege) {
      expect(find.text(e.titel), findsOneWidget, reason: e.titel);
    }
  });

  testWidgets('Tippen meldet das Ziel', (tester) async {
    final getippt = await pump(tester);
    await tester.tap(find.text('Abschlüsse und Steuern'));
    await tester.tap(find.text('Material'));
    expect(getippt, ['/abschluesse', '/materialien']);
  });

  testWidgets('Zaehler erscheint nur, wo einer geliefert wird', (tester) async {
    await pump(
      tester,
      zaehler: (e) => e.ziel == '/rechnungen' ? '2 offen' : null,
    );
    expect(find.text('2 offen'), findsOneWidget);
  });

  testWidgets('passt auf 360 px ohne Ueberlauf und ohne gekuerzte Titel', (
    tester,
  ) async {
    await pump(tester, zaehler: (e) => e.zaehler == null ? null : '12 offen');
    expect(tester.takeException(), isNull);
    for (final e in kBereichMehr.alleEintraege) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(e.titel));
      expect(absatz.didExceedMaxLines, isFalse, reason: e.titel);
    }
  });
}
```

- [ ] **Step 2: Test laufen lassen**

Run: `flutter test test/bereich_gruppen_liste_test.dart`
Expected: FAIL — Datei fehlt.

- [ ] **Step 3: Implementieren**

`lib/presentation/widgets/bereich_gruppen_liste.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/dashboard_tile.dart';

/// Zeichnet Bereichs-Gruppen: Kopf, dann Kacheln oder Zeilen.
///
/// CanvasKit: Zeilen aus `InkWell` + `Container` + `Row`, kein `ListTile` —
/// die Mehr-Seite ist nach der Leiste die meistbenutzte Weiche der App, ein
/// nicht rendernder Eintrag fiele erst auf, wenn man ihn braucht (CLAUDE.md,
/// drei bestätigte Vorfälle).
class BereichGruppenListe extends StatelessWidget {
  final List<BereichGruppe> gruppen;
  final String? Function(BereichEintrag) zaehler;
  final ValueChanged<String> onTap;

  const BereichGruppenListe({
    super.key,
    required this.gruppen,
    required this.zaehler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in gruppen) ...[
          if (g.titel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                g.titel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (g.alsKacheln)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 2.1,
              children: [
                for (final e in g.eintraege)
                  DashboardTile(
                    icon: e.icon,
                    label: e.titel,
                    count: zaehler(e),
                    color: AppColors.primary,
                    onTap: () => onTap(e.ziel),
                  ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < g.eintraege.length; i++)
                    _Zeile(
                      eintrag: g.eintraege[i],
                      zaehler: zaehler(g.eintraege[i]),
                      trennlinie: i < g.eintraege.length - 1,
                      onTap: () => onTap(g.eintraege[i].ziel),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  final BereichEintrag eintrag;
  final String? zaehler;
  final bool trennlinie;
  final VoidCallback onTap;

  const _Zeile({
    required this.eintrag,
    required this.zaehler,
    required this.trennlinie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: trennlinie
              ? const Border(bottom: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: Row(
          children: [
            Icon(eintrag.icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eintrag.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (eintrag.untertitel != null)
                    Text(
                      eintrag.untertitel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (zaehler != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  zaehler!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/presentation/screens/bereich_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/providers/bereich_zaehler_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

/// Eine Bereichsseite: Titel, optionale Karten oben, dann die Gruppen.
///
/// `push` statt `go`: Aus dem Bereich geöffnete Screens führen mit «zurück»
/// wieder hierher.
class BereichScreen extends ConsumerWidget {
  final Bereich bereich;
  final List<Widget> kopf;

  const BereichScreen({super.key, required this.bereich, this.kopf = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaehler = ref.watch(bereichZaehlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(bereich.titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          ...kopf,
          BereichGruppenListe(
            gruppen: bereich.gruppen,
            zaehler: zaehler,
            onTap: (ziel) => context.push(ziel),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/bereich_gruppen_liste_test.dart`
Expected: PASS. Schlägt der 360-px-Test wegen eines gekürzten Titels fehl, den Titel in `bereiche.dart` kürzen — nicht die Schrift verkleinern.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/bereich_gruppen_liste.dart lib/presentation/screens/bereich_screen.dart test/bereich_gruppen_liste_test.dart
git commit -m "feat(nav): BereichGruppenListe und BereichScreen, CanvasKit-sicher

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 5: Karten der Bank-Seite herauslösen

**Files:**
- Create: `lib/presentation/widgets/bank_waechter_karte.dart`
- Create: `lib/presentation/widgets/camt_erinnerung_karte.dart`
- Modify: `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: `BankWaechterKarte`**

Die Klasse `_BankWaechterCard` (Dashboard, ab Zeile 473 bis vor `/// ` des `_NavTile`-Kommentars, ca. Zeile 575) **unverändert im Inhalt** nach `lib/presentation/widgets/bank_waechter_karte.dart` verschieben und dort in `BankWaechterKarte` (öffentlich) umbenennen, Konstruktor `const BankWaechterKarte({super.key, required this.stand});`. Die Imports, die sie braucht, mitnehmen (mindestens `flutter/material.dart`, `flutter_riverpod` für `AsyncValue`, `app_theme.dart`, `buchhaltung_providers.dart` für `BankWaechterStand`, `go_router` falls sie `context.push` nutzt). Kopfkommentar:

```dart
/// Bank-Wächter: Journal gegen letzten Bank-Schlusssaldo, dazu «Tilgung
/// ohne Aufbau» auf Verbindlichkeitskonten. Bis v0.130.0 in der
/// Buchhaltung, seit v0.131.0 auf der Seite «Bank und Zahlungen» — dort,
/// wo man den Auszug importiert, der den Befund auflöst.
```

- [ ] **Step 2: `CamtErinnerungKarte`**

`lib/presentation/widgets/camt_erinnerung_karte.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';

/// Wochen-Erinnerung: Ist der letzte erfasste Auszug älter als 7 Tage,
/// einen neuen hochladen. Bis v0.130.0 in der Buchhaltung.
class CamtErinnerungKarte extends ConsumerWidget {
  const CamtErinnerungKarte({super.key});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letzte = ref.watch(letzteCamtPeriodeProvider).valueOrNull;
    final faellig =
        letzte == null || DateTime.now().difference(letzte).inDays > 7;
    if (!faellig) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/buchhaltung/camt-import'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                letzte == null
                    ? 'Noch kein Bankauszug erfasst — camt-Datei hochladen'
                    : 'Letzter Auszug bis ${_fmt(letzte)} — neuen camt-Auszug hochladen',
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
```

Vorher im Dashboard nachsehen, wie `_fmt` (Zeile 390) formatiert, und exakt dasselbe Format übernehmen, falls es abweicht.

- [ ] **Step 3: Dashboard auf die neuen Klassen umstellen (Zwischenschritt)**

Im Dashboard `_BankWaechterCard(stand: …)` durch `BankWaechterKarte(stand: …)` ersetzen und den Import ergänzen. Den `if (camtErinnerung) Container(...)`-Block durch `const CamtErinnerungKarte(),` ersetzen und die dann unbenutzten Variablen `letzteCamtPeriode`/`camtErinnerung` entfernen. (Task 8 entfernt beide Karten ganz aus der Buchhaltung.)

- [ ] **Step 4: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/bank_waechter_karte.dart lib/presentation/widgets/camt_erinnerung_karte.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "refactor: Bank-Waechter und camt-Erinnerung als eigene Widgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 6: Stammdaten aus den Einstellungen lösen

**Files:**
- Create: `lib/presentation/screens/einstellungen/stammdaten_screen.dart`
- Modify: `lib/presentation/screens/einstellungen/einstellungen_screen.dart`

- [ ] **Step 1: `StammdatenScreen` anlegen**

Neue Datei mit `class StammdatenScreen extends ConsumerStatefulWidget` und State `_StammdatenScreenState`. **Aus `einstellungen_screen.dart` verschieben** (nicht kopieren):

| Was | Zeilen (Stand v0.130.0) |
|---|---|
| `_editPoNummer` | 33–66 |
| Karte «Geschäft» | 491–513 |
| Karte «Lohn-Einstellungen» | 609–622 |
| `MwstSaetzeSection` + ganzer `aktuellePreise.when(...)`-Block | 624–903 |
| `_SectionCard`, `_InfoRow`, `_EditableInfoRow`, `_TwoColRow` | 910–Ende |

`build` der neuen Datei:

```dart
  @override
  Widget build(BuildContext context) {
    final aktuellePreise = ref.watch(aktuellePreiseProvider);
    final geschaeftAsync = ref.watch(geschaeftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stammdaten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // … Karte «Geschäft» (verschoben)
          // Anlagen: Im Alltag öffnet man sie über den Betrieb; die
          // Gesamtliste ist Stammdatenpflege (0–1 Aufrufe in 14 Tagen).
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => context.push('/anlagen'),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.propane_tank_outlined, color: AppColors.primary),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Anlagen',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          // … Karte «Lohn-Einstellungen» (verschoben)
          // … MwstSaetzeSection + aktuellePreise.when(...) (verschoben)
        ],
      ),
    );
  }
```

Beim Verschieben die zwei Material-Knöpfe im Preis-Block ersetzen (CanvasKit-Regel; Vorfall 20.06.2026 «FilledButton unsichtbar»):

```dart
                    TapKnopf(
                      text: 'Erste Preisversion erstellen',
                      icon: Icons.add,
                      primaer: true,
                      onTap: () => context.push('/einstellungen/preise/neu'),
                    ),
```

statt `ElevatedButton.icon(...)` (Zeile ~642) und

```dart
                  TapKnopf(
                    text: 'Neue Preise erfassen',
                    icon: Icons.add,
                    primaer: true,
                    onTap: () => context.push('/einstellungen/preise/neu'),
                  ),
```

statt des `SizedBox(width: double.infinity, child: FilledButton.icon(...))` (Zeile ~889). Vorher in `lib/presentation/widgets/tap_knopf.dart` prüfen, ob `TapKnopf` die volle Breite von selbst einnimmt; falls nicht, in `SizedBox(width: double.infinity, child: …)` belassen.

Imports der neuen Datei: `material`, `flutter_riverpod`, `go_router`, `intl` (DateFormat), `app_theme`, `preis_repository`, `geschaeft_providers`, `preis_providers`, `widgets/geschaeft_form.dart`, `widgets/mwst_saetze_section.dart`, `tap_knopf.dart` — `flutter analyze` zeigt fehlende und überzählige an.

- [ ] **Step 2: Einstellungen verkleinern**

In `einstellungen_screen.dart` bleiben: Google Kalender, Google Kontakte, Speicher aufräumen. **Löschen:** die Karte «Nutzung der App» (Zeilen 573–586; zieht nach Auswertungen). Am Ende der `children` ergänzen:

```dart
          // Abmelden und Sync (bis v0.130.0 auf der Startseite): Das
          // Abmelde-Symbol sass dort neben der Sync-Anzeige — ein Fehltipp
          // meldete unterwegs ab.
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TapKnopf(
                text: 'Sync erzwingen',
                icon: Icons.sync,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Synchronisierung gestartet...')),
                  );
                  final r = await SyncService.syncAll();
                  final m = syncMeldung(
                    pushed: r.pushed,
                    pulled: r.pulled,
                    fehler: r.errors,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(m.text),
                      backgroundColor: m.istFehler ? AppColors.offline : null,
                      duration: Duration(seconds: m.istFehler ? 8 : 3),
                    ),
                  );
                },
              ),
            ),
          TapKnopf(
            text: 'Abmelden',
            icon: Icons.logout,
            onTap: () async {
              if (!kIsWeb) SyncService.stopListening();
              await SupabaseService.client.auth.signOut();
            },
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'SBS Projer v$kAppVersion',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
```

Neue Imports: `package:flutter/foundation.dart` (`kIsWeb`), `core/app_version.dart`, `core/util/sync_meldung.dart`, `services/supabase/supabase_service.dart`, `services/sync/sync_service_export.dart`. Nicht mehr gebrauchte entfernen (`intl`, `preis_repository`, `geschaeft_providers`, `preis_providers`, `geschaeft_form`, `mwst_saetze_section` — nur wenn `flutter analyze` sie als unbenutzt meldet).

- [ ] **Step 3: Analyse**

Run: `flutter analyze`
Expected: 56 issues. (Die Route `/stammdaten` folgt in Task 8.)

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/einstellungen/
git commit -m "refactor: Stammdaten aus den Einstellungen geloest, Abmelden und Sync in die Einstellungen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 7: Heute nur noch der Tag

**Files:**
- Modify: `lib/presentation/screens/home_screen.dart`
- Modify: `test/kachel_text_test.dart`

- [ ] **Step 1: Quelltext-Test umschreiben (schlägt fehl)**

In `test/kachel_text_test.dart` den Test `'die Startseite zeigt nur noch die drei Kacheln ohne Leisten-Ziel'` ersetzen durch:

```dart
  test('die Startseite ist nur noch der Tag (v0.131.0)', () {
    final quelle =
        File('lib/presentation/screens/home_screen.dart').readAsStringSync();
    for (final weg in [
      'DashboardTile(',
      '_KachelGrid',
      '_WeitereSection',
      '_MenuListTile',
      'Icons.logout',
    ]) {
      expect(quelle.contains(weg), isFalse,
          reason: '$weg gehoert seit v0.131.0 auf Mehr bzw. in die '
              'Einstellungen — auf Heute rutscht es unter den Tagesplan');
    }
    for (final bleibt in [
      'ArbeitstagKarte(',
      'HeuteListe(',
      '_AufgabenKarte(',
      'zeigeDiktatSheet',
    ]) {
      expect(quelle.contains(bleibt), isTrue, reason: bleibt);
    }
  });
```

(Der Test braucht `testWidgets` nicht mehr — `test` genügt, `import 'dart:io';` ist schon da.)

Run: `flutter test test/kachel_text_test.dart`
Expected: FAIL

- [ ] **Step 2: Startseite umbauen**

In `home_screen.dart`:
- `actions:` der AppBar: den `IconButton` «Abmelden» entfernen, nur `_SyncIndicator` bleibt.
- `body`-`children`: `const SizedBox(height: 8), const _KachelGrid(), const SizedBox(height: 16), const _WeitereSection(),` entfernen. Übrig: `_AufgabenKarte`, `ArbeitstagKarte`, `HeuteListe`.
- Klassen `_KachelGrid`, `_WeitereSection`, `_MenuListTile` löschen, ebenso den Import von `dashboard_tile.dart`.
- Nicht mehr genutzte Imports entfernen (`kIsWeb`, `sync_meldung`, `material_providers`, `buchung_providers`, `event_providers`, `supabase_service`, `sync_service_export`, `aufgaben_providers` nur falls unbenutzt — `_AufgabenKarte` nutzt `aufgabenJetztProvider`, also bleibt er).
- Über `body:` einen Kommentar setzen:

```dart
      // Seit v0.131.0 nur noch der Tag: Kacheln und «Weitere» rutschten mit
      // jedem Stopp des Tagesplans tiefer und waren am Handy kaum zu
      // erreichen. Sie stehen jetzt unter «Mehr» in der Leiste.
```

- [ ] **Step 3: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues. (`aufgaben_eine_quelle_waechter_test` bleibt grün: `_AufgabenKarte` liest `aufgabenJetztProvider`.)

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/home_screen.dart test/kachel_text_test.dart
git commit -m "feat: Heute zeigt nur noch den Tag

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 8: Routen, Bereichsseiten, verkleinerte Buchhaltung

**Files:**
- Modify: `lib/core/config/router.dart`
- Modify: `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
- Delete: `test/buchhaltung_gruppen_waechter_test.dart` (ersetzt durch `bereiche_test.dart`, Test «kein Ziel steht in zwei Bereichsseiten»)
- Modify: `test/canvaskit_sichere_widgets_test.dart`

- [ ] **Step 1: Routen ergänzen**

In `router.dart` direkt nach `GoRoute(path: '/', …)` einfügen:

```dart
    // Bereiche (v0.131.0) — Aufbau in lib/core/config/bereiche.dart.
    GoRoute(
      path: '/mehr',
      builder: (context, state) => const BereichScreen(bereich: kBereichMehr),
    ),
    GoRoute(
      path: '/bank',
      builder: (context, state) => const BereichScreen(
        bereich: kBereichBank,
        kopf: [CamtErinnerungKarte(), _BankWaechterKopf()],
      ),
    ),
    GoRoute(
      path: '/abschluesse',
      builder: (context, state) =>
          const BereichScreen(bereich: kBereichAbschluesse),
    ),
    GoRoute(
      path: '/auswertungen',
      builder: (context, state) =>
          const BereichScreen(bereich: kBereichAuswertungen),
    ),
    GoRoute(
      path: '/stammdaten',
      builder: (context, state) => const StammdatenScreen(),
    ),
```

`BankWaechterKarte` braucht den Provider-Wert; dafür am Ende von `router.dart` eine kleine Hülle:

```dart
/// Liest den Bank-Wächter-Stand für die Seite «Bank und Zahlungen».
class _BankWaechterKopf extends ConsumerWidget {
  const _BankWaechterKopf();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BankWaechterKarte(stand: ref.watch(bankWaechterProvider));
}
```

Imports ergänzen: `bereiche.dart`, `bereich_screen.dart`, `camt_erinnerung_karte.dart`, `bank_waechter_karte.dart`, `stammdaten_screen.dart`, `buchhaltung_providers.dart`, `flutter_riverpod` (falls noch nicht importiert).

- [ ] **Step 2: Buchhaltung verkleinern**

In `buchhaltung_dashboard_screen.dart`:
- Den `Builder` mit `BueroOffenBlock` (Zeilen 65–84) löschen, ebenso `const CamtErinnerungKarte(),` und `BankWaechterKarte(...)` samt folgendem Abstand. Grund als Kommentar an der Stelle:

```dart
          // «Was ist offen?», camt-Erinnerung und Bank-Wächter stehen seit
          // v0.131.0 nicht mehr hier: die offenen Punkte als Zähler auf
          // «Mehr» und in der Glocke, Bank-Themen auf «Bank und Zahlungen».
```

- Die Kennzahl-Kachel «Offene Rechnungen» antippbar machen (führt nach `/rechnungen`):

```dart
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/rechnungen'),
                  child: _KennzahlCard(
                    label: 'Offene Rechnungen',
                    value: '$offeneCount',
                    icon: Icons.receipt_long,
                    color: AppColors.warning,
                  ),
                ),
              ),
```

- Alles von `// Navigation — zwei Gruppen …` (Zeile ~166) bis einschliesslich des letzten `_NavTile` (Jahresrechnungen, Zeile ~277) ersetzen durch:

```dart
          BereichGruppenListe(
            gruppen: kBereichBuchhaltung.gruppen,
            zaehler: ref.watch(bereichZaehlerProvider),
            onTap: (ziel) => context.push(ziel),
          ),
```

- Klasse `_NavTile` löschen; unbenutzte Imports entfernen (`aufgabe.dart`, `aufgaben_providers.dart`, `aufgaben_aktionen.dart`, `buero_offen_block.dart`, `camt_abgleich_providers.dart`), neue ergänzen (`bereiche.dart`, `bereich_zaehler_provider.dart`, `bereich_gruppen_liste.dart`).

`BueroOffenBlock` bleibt als Datei bestehen, falls `flutter analyze` keine weitere Nutzung meldet: dann `lib/presentation/widgets/buero_offen_block.dart` löschen und in `test/canvaskit_sichere_widgets_test.dart` aus der Dateiliste nehmen.

- [ ] **Step 3: CanvasKit-Wächter erweitern**

In `test/canvaskit_sichere_widgets_test.dart` in der Liste von `'Listenzeilen ohne CanvasKit-tote Widgets'` ergänzen:

```dart
      'lib/presentation/widgets/bereich_gruppen_liste.dart',
      'lib/presentation/screens/bereich_screen.dart',
```

und in der Verbotsliste des Tests ergänzen:

```dart
        'TabBar(',
        'NavigationBar(',
        'ElevatedButton',
```

- [ ] **Step 4: Alten Gruppen-Wächter entfernen**

```bash
git rm test/buchhaltung_gruppen_waechter_test.dart
```

- [ ] **Step 5: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 6: Commit**

```bash
git add -A lib/core/config/router.dart lib/presentation/screens/buchhaltung/ lib/presentation/widgets/ test/
git commit -m "feat(nav): Mehr, Bank, Abschluesse, Auswertungen, Stammdaten; Buchhaltung verkleinert

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 9: `BereichReiter` und Betriebe | Personen

**Files:**
- Create: `lib/presentation/widgets/bereich_reiter.dart`
- Modify: `lib/presentation/screens/betriebe/betriebe_list_screen.dart:109-139`
- Modify: `lib/presentation/screens/kontakte/kontakte_list_screen.dart` (AppBar)
- Test: `test/bereich_reiter_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/bereich_reiter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_reiter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<String>> pump(
    WidgetTester tester,
    List<BereichReiterEintrag> reiter,
    String aktiv,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gewaehlt = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('X'),
            bottom: BereichReiter(
              reiter: reiter,
              aktiverPfad: aktiv,
              onWechsel: gewaehlt.add,
            ),
          ),
        ),
      ),
    );
    return gewaehlt;
  }

  testWidgets('aktiver Reiter gruen, andere grau', (tester) async {
    await pump(tester, kReiterBetriebe, '/kontakte');
    expect(
      tester.widget<Text>(find.text('Personen')).style?.color,
      AppColors.primary,
    );
    expect(
      tester.widget<Text>(find.text('Betriebe')).style?.color,
      AppColors.textSecondary,
    );
  });

  testWidgets('Tippen wechselt, der aktive meldet nichts', (tester) async {
    final gewaehlt = await pump(tester, kReiterBetriebe, '/betriebe');
    await tester.tap(find.text('Betriebe'));
    await tester.tap(find.text('Personen'));
    expect(gewaehlt, ['/kontakte']);
  });

  testWidgets('vier Reiter passen auf 360 px', (tester) async {
    await pump(tester, const [
      BereichReiterEintrag('Kunden', '/rechnungen'),
      BereichReiterEintrag('Heineken', '/heineken'),
      BereichReiterEintrag('Pro Betrieb', '/rechnungen/pro-betrieb'),
      BereichReiterEintrag('Jährlich', '/jahresrechnung'),
    ], '/rechnungen');
    expect(tester.takeException(), isNull);
    for (final t in ['Kunden', 'Heineken', 'Pro Betrieb', 'Jährlich']) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });
}
```

Run: `flutter test test/bereich_reiter_test.dart`
Expected: FAIL — Datei fehlt.

- [ ] **Step 2: Implementieren**

`lib/presentation/widgets/bereich_reiter.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

class BereichReiterEintrag {
  final String titel;
  final String pfad;
  const BereichReiterEintrag(this.titel, this.pfad);
}

/// Die Personen sind seit v0.131.0 ein Reiter der Betriebe: Wirte ruft man
/// über ihren Betrieb an (39 Aufrufe Betrieb-Detail am Handy in 14 Tagen,
/// 0 Kontakte-Liste).
const kReiterBetriebe = [
  BereichReiterEintrag('Betriebe', '/betriebe'),
  BereichReiterEintrag('Personen', '/kontakte'),
];

/// Umschalter unter der AppBar.
///
/// WARUM kein `TabBar`: Ein TabBar bettet die Reiter-Screens ein — jeder
/// hat aber eine eigene AppBar und eine eigene Route, auf die Mails und
/// Aufgaben zeigen. Hier bleibt jeder Reiter der bestehende Screen unter
/// seiner Route; der Umschalter wechselt nur die Route (`go`, damit «zurück»
/// nicht durch jeden Reiterwechsel führt). Dazu CanvasKit: kein
/// Material-Komfort-Widget in der Navigation (CLAUDE.md).
class BereichReiter extends StatelessWidget implements PreferredSizeWidget {
  final List<BereichReiterEintrag> reiter;
  final String aktiverPfad;

  /// Für Tests; ohne Angabe wird per `context.go` gewechselt.
  final ValueChanged<String>? onWechsel;

  const BereichReiter({
    super.key,
    required this.reiter,
    required this.aktiverPfad,
    this.onWechsel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (final r in reiter)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: r.pfad == aktiverPfad
                    ? null
                    : () => onWechsel != null
                          ? onWechsel!(r.pfad)
                          : context.go(r.pfad),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: r.pfad == aktiverPfad
                            ? AppColors.primary
                            : AppColors.divider,
                        width: r.pfad == aktiverPfad ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    r.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: r.pfad == aktiverPfad
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: r.pfad == aktiverPfad
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Test laufen lassen**

Run: `flutter test test/bereich_reiter_test.dart`
Expected: PASS

- [ ] **Step 4: In die Betriebe und die Personen einbauen**

`betriebe_list_screen.dart`, in der `AppBar(` (Zeile ~110):
- `bottom: const BereichReiter(reiter: kReiterBetriebe, aktiverPfad: '/betriebe'),` ergänzen.
- Den `leading`-`IconButton` so ändern, dass er nicht abstürzt, wenn nichts zum Zurückgehen da ist (nach einem Reiterwechsel per `go`):

```dart
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
```

`kontakte_list_screen.dart`, in deren `AppBar(`: `bottom: const BereichReiter(reiter: kReiterBetriebe, aktiverPfad: '/kontakte'),` — **nur wenn `widget.betriebId == null`** (eine auf einen Betrieb gefilterte Kontaktliste ist kein Reiter):

```dart
        bottom: widget.betriebId == null
            ? const BereichReiter(
                reiter: kReiterBetriebe,
                aktiverPfad: '/kontakte',
              )
            : null,
```

Der bestehende Kategorie-Filter der Kontaktliste (`_filterKategorie`) bleibt unverändert; er ist der Filter «Betrieb · Heineken · Event · Alle» aus der Spec. Im AppBar-Titel steht weiter `_appBarTitle()`.

- [ ] **Step 5: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/bereich_reiter.dart lib/presentation/screens/betriebe/betriebe_list_screen.dart lib/presentation/screens/kontakte/kontakte_list_screen.dart test/bereich_reiter_test.dart
git commit -m "feat(nav): Umschalter Betriebe | Personen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 10: Erreichbarkeits-Wächter

**Files:**
- Create: `test/erreichbarkeit_waechter_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_reiter.dart';

/// Jeder Listen-Screen ist über die Navigation erreichbar (v0.131.0).
///
/// WARUM: Die Bestellungen-Liste war bis v0.47.0 unauffindbar, und mit dem
/// Wegfall der «Weitere»-Liste auf Heute könnte das jedem Eintrag passieren,
/// den niemand umhängt. Erreichbar heisst: Leisten-Ziel, Eintrag in
/// `bereiche.dart`, Reiter — oder eine Unterseite, deren Link in der
/// genannten Datei wirklich steht.
void main() {
  final router = File('lib/core/config/router.dart').readAsStringSync();
  final pfade = RegExp(r"path:\s*'([^']+)'")
      .allMatches(router)
      .map((m) => m.group(1)!)
      .toSet();

  bool detailOderFormular(String p) =>
      p.contains('/:') ||
      p.endsWith('/neu') ||
      p.endsWith('/bearbeiten') ||
      !zeigtNavigation(p);

  final direkt = <String>{
    for (final z in NavZiel.values) navPfad(z),
    for (final b in kAlleBereiche) ...b.alleEintraege.map((e) => e.ziel),
    ...kReiterBetriebe.map((r) => r.pfad),
  };

  /// Unterseiten: Route → Datei, in der der Weg dorthin steht.
  const unterseiten = <String, String>{
    '/betriebe/servicezeiten':
        'lib/presentation/screens/betriebe/betriebe_list_screen.dart',
    '/betriebe/saisondaten':
        'lib/presentation/screens/touren/tourenplanung_screen.dart',
    '/betriebe/vorschlaege': 'lib/core/util/aufgabe.dart',
    '/anlagen': 'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/heineken/zuweisungen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/heineken/raster':
        'lib/presentation/screens/heineken/heineken_rechnungen_list_screen.dart',
    '/rechnungen/pro-betrieb':
        'lib/presentation/screens/rechnungen/rechnungen_list_screen.dart',
    '/buchhaltung/abschreibung':
        'lib/services/buchhaltung/abschluss_regeln.dart',
    '/buchhaltung/camt-pruefliste': 'lib/core/util/aufgaben_regeln.dart',
    '/buchhaltung/eingangsrechnungen/regeln':
        'lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart',
    '/buchhaltung/eingangsrechnungen/zahlungsfile':
        'lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart',
    '/buchhaltung/lohn/einstellungen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/materialien/bestellungen':
        'lib/presentation/screens/materialien/materialien_list_screen.dart',
    '/einstellungen/biersorten':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/einstellungen/regionen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/google-termine':
        'lib/presentation/screens/einstellungen/einstellungen_screen.dart',
  };

  /// Routen ohne jeden Link im Code (Stand 22.09.2026). Sie bleiben für alte
  /// Lesezeichen bestehen; vermutlich Überbleibsel, seit der Bankauszug-
  /// Import vier Reiter hat (v0.16.19). Aufräumen ist eine eigene Aufgabe
  /// (ToDo.md) — hier stehen sie, damit der Wächter nicht blind wird.
  const ohneLink = {
    '/buchhaltung/bilanz',
    '/buchhaltung/debitoren',
    '/buchhaltung/camt-regeln',
    '/buchhaltung/camt-dateien',
  };

  test('router.dart wird gelesen', () {
    expect(pfade.length, greaterThan(50));
  });

  test('jede Listen-Route ist erreichbar', () {
    final fehlt = <String>[];
    for (final p in pfade) {
      if (p == '/login' || detailOderFormular(p)) continue;
      if (direkt.contains(p) || ohneLink.contains(p)) continue;
      final datei = unterseiten[p];
      if (datei != null && File(datei).readAsStringSync().contains("'$p")) {
        continue;
      }
      fehlt.add(p);
    }
    expect(
      fehlt,
      isEmpty,
      reason:
          'Nicht erreichbar: ${fehlt.join(', ')}. In bereiche.dart eintragen '
          'oder als Unterseite mit der verlinkenden Datei in diesen Test.',
    );
  });

  test('Unterseiten- und Ausnahmeliste ohne Karteileichen', () {
    for (final p in [...unterseiten.keys, ...ohneLink]) {
      expect(pfade.contains(p), isTrue, reason: '$p gibt es nicht mehr');
    }
    for (final e in unterseiten.entries) {
      expect(
        File(e.value).readAsStringSync().contains("'${e.key}"),
        isTrue,
        reason: '${e.value} verlinkt ${e.key} nicht mehr',
      );
    }
  });

  test('jedes Bereichs-Ziel gibt es als Route', () {
    for (final z in direkt) {
      expect(pfade.contains(z), isTrue, reason: z);
    }
  });
}
```

- [ ] **Step 2: Laufen lassen**

Run: `flutter test test/erreichbarkeit_waechter_test.dart`
Expected: PASS. Meldet der Test eine Route als nicht erreichbar, **zuerst prüfen**, ob sie wirklich verlinkt ist (`grep -rn "'/pfad" lib`). Wenn ja, mit ihrer Datei in `unterseiten` aufnehmen. Wenn nein, bei Daniel nachfragen, statt sie stillschweigend zu `ohneLink` zu legen.

- [ ] **Step 3: Commit**

```bash
git add test/erreichbarkeit_waechter_test.dart
git commit -m "test: Waechter - jeder Listen-Screen ist erreichbar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 11: Auslieferung v0.131.0

**Files:**
- Modify: `pubspec.yaml:4`, `lib/core/app_version.dart`
- Modify: `docs/chronik.md`, `ToDo.md`, `Projekt.md` (Stand-Zeile)

- [ ] **Step 1: Version**

`pubspec.yaml` Zeile 4: `version: 0.131.0+780`. `lib/core/app_version.dart`: `const String kAppVersion = '0.131.0';`

Run: `flutter test test/app_version_test.dart`
Expected: PASS

- [ ] **Step 2: Volle Prüfung**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 3: Sichtprüfung im Browser (Pflicht vor dem Deploy)**

Lokal starten (`flutter run -d edge` oder über die Browser-Vorschau), Fenster auf **360 × 800**. Prüfen und je einen Screenshot machen:
1. Heute: nur Aufgaben-Karte, Arbeitstag, Heute-Liste, Diktieren; kein Abmelde-Symbol.
2. Leiste: fünf Ziele lesbar, «Mehr» leuchtet auf `/mehr`, `/buchhaltung`, `/stammdaten`.
3. Mehr: drei Gruppen, Kacheln und Zeilen sichtbar, Zähler an Material/Aufgaben/Büro-Zeilen, jede Zeile öffnet ihr Ziel, «zurück» führt nach Mehr.
4. Bank und Zahlungen: camt-Erinnerung (falls fällig) und Bank-Wächter oben.
5. Buchhaltung: Kennzahlen, «Offene Rechnungen» öffnet die Forderungen, Gruppen «Bücher» und «Rechnungen».
6. Stammdaten: Geschäft, Anlagen, Lohn, MWST, Preise; «Neue Preise erfassen» sichtbar und antippbar.
7. Einstellungen: Google, Speicher, Abmelden, Version.
8. Betriebe ↔ Personen: Umschalter wechselt, «Betriebe» leuchtet in beiden; Zurück-Pfeil in den Betrieben stürzt nicht ab.

- [ ] **Step 4: Doku**

- `docs/chronik.md`: oben einen Abschnitt `## 22.09.2026 — v0.131.0` mit den Punkten aus Teil A.
- `ToDo.md`: Stand-Zeile auf v0.131.0; unter «Klicktests am Handy» einen Eintrag v0.131.0 mit den acht Punkten aus Step 3.
- `Projekt.md`: Stand-Zeile auf v0.131.0 und Testzahl.

- [ ] **Step 5: Commit, dann Deploy nach CLAUDE.md**

```bash
git add -A
git commit -m "release: v0.131.0 - Navigation Mehr und Bereiche

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin main
```

Dann den Deploy-Ablauf aus `CLAUDE.md` Schritt 1–3 ausführen (Build mit `--pwa-strategy=none`, Cache-Bust, `404.html` mitkopieren, `gh-pages` committen `deploy v0.131.0 — Navigation Mehr`, pushen, zurück auf `main`). Danach https://danielproyer.github.io/sbs-projer-dev/ öffnen und prüfen, dass in der Kopfzeile `v0.131.0` steht.

---

# Teil B — v0.132.0

## Task 12: Rechnungen mit Reitern

**Files:**
- Modify: `lib/presentation/widgets/bereich_reiter.dart` (Konstante)
- Modify: `lib/presentation/screens/rechnungen/rechnungen_list_screen.dart` (AppBar)
- Modify: `lib/presentation/screens/heineken/heineken_rechnungen_list_screen.dart` (AppBar + Bergkunden-Zeile)
- Modify: `lib/presentation/screens/rechnungen/offen_pro_betrieb_screen.dart` (AppBar)
- Modify: `lib/presentation/screens/jahresrechnung/jahresrechnung_generate_screen.dart` (AppBar)
- Modify: `lib/core/config/bereiche.dart` (Übergangsgruppe entfernen)
- Modify: `test/erreichbarkeit_waechter_test.dart`, `test/bereiche_test.dart`

- [ ] **Step 1: Konstante ergänzen**

In `bereich_reiter.dart`:

```dart
/// Der Rechnungs-Bereich (v0.132.0): vorher hingen die vier Screens einzeln
/// in der Buchhaltung, die Rechnungen zwei Stufen tief.
const kReiterRechnungen = [
  BereichReiterEintrag('Kunden', '/rechnungen'),
  BereichReiterEintrag('Heineken', '/heineken'),
  BereichReiterEintrag('Pro Betrieb', '/rechnungen/pro-betrieb'),
  BereichReiterEintrag('Jährlich', '/jahresrechnung'),
];
```

- [ ] **Step 2: In die vier Screens einbauen**

In jeder der vier AppBars `bottom: const BereichReiter(reiter: kReiterRechnungen, aktiverPfad: '<eigene Route>'),` ergänzen — `'/rechnungen'`, `'/heineken'`, `'/rechnungen/pro-betrieb'`, `'/jahresrechnung'`. Hat ein Screen einen eigenen `leading`-Knopf mit `context.pop()`, auf `context.canPop() ? context.pop() : context.go('/mehr')` umstellen. Hat ein Screen schon ein `bottom:`, **anhalten und melden** statt zu überschreiben.

- [ ] **Step 3: Bergkundenpauschalen an ihren festen Ort**

*(Nachtrag 22.09.2026: Keine Mahnwesen-Aktion — `/buchhaltung/mahnwesen` ist nur eine Weiterleitung auf `/rechnungen`, das Mahnwesen IST die Kunden-Seite. Der Erreichbarkeits-Wächter erkennt solche Aliase seit Commit ad377b81 selbst.)*

In `heineken_rechnungen_list_screen.dart` als erstes Element der Liste:

```dart
            // Bergkundenpauschalen werden mit der Heineken-Monatsrechnung
            // verrechnet — hier werden sie gesucht (v0.132.0).
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: InkWell(
                onTap: () => context.push('/bergkundenpauschalen'),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.landscape, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bergkundenpauschalen',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
```

Vorher die Struktur der Liste ansehen (ListView mit `children` oder `ListView.builder`); bei einem Builder die Karte über dem Builder in eine `Column` setzen.

- [ ] **Step 4: Übergangsgruppe entfernen**

In `bereiche.dart` aus `kBereichBuchhaltung` die Gruppe `titel: 'Rechnungen'` löschen, den Kommentar über `kBereichBuchhaltung` auf die verbleibende Gruppe anpassen. In `test/erreichbarkeit_waechter_test.dart`:
- `direkt` um `...kReiterRechnungen.map((r) => r.pfad),` ergänzen,
- in `unterseiten` ergänzen:

```dart
    '/bergkundenpauschalen':
        'lib/presentation/screens/heineken/heineken_rechnungen_list_screen.dart',
```

- `'/rechnungen/pro-betrieb'` aus `unterseiten` entfernen (jetzt Reiter).

- [ ] **Step 5: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 6: Commit**

```bash
git add -A lib/ test/
git commit -m "feat(nav): Rechnungen mit Reitern, Bergkundenpauschalen im Heineken-Reiter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 13: Event-Fenster (TDD)

**Files:**
- Create: `lib/core/util/event_fenster.dart`
- Test: `test/event_fenster_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_fenster.dart';

void main() {
  final von = DateTime(2026, 10, 10);
  final bis = DateTime(2026, 10, 12);

  test('8 Tage vorher: nein', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 2)), isFalse);
  });
  test('7 Tage vorher: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 3)), isTrue);
  });
  test('waehrend des Events: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 11, 23, 30)), isTrue);
  });
  test('letzter Tag: ja', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 12, 22)), isTrue);
  });
  test('Tag danach: nein', () {
    expect(eventImFenster(von, bis, DateTime(2026, 10, 13)), isFalse);
  });
  test('ohne Start: nein', () {
    expect(eventImFenster(null, bis, DateTime(2026, 10, 11)), isFalse);
  });
  test('ohne Ende gilt der Starttag als Ende', () {
    expect(eventImFenster(von, null, DateTime(2026, 10, 10)), isTrue);
    expect(eventImFenster(von, null, DateTime(2026, 10, 11)), isFalse);
  });
  test('ueber die Zeitumstellung (25.10.2026) zaehlt der Kalendertag', () {
    final v = DateTime(2026, 11, 1);
    expect(eventImFenster(v, v, DateTime(2026, 10, 25, 1)), isTrue);
    expect(eventImFenster(v, v, DateTime(2026, 10, 24, 23)), isFalse);
  });
}
```

Run: `flutter test test/event_fenster_test.dart`
Expected: FAIL — Datei fehlt.

- [ ] **Step 2: Implementieren**

`lib/core/util/event_fenster.dart`:

```dart
/// Steht ein Event gerade an? Ab 7 Tagen vor dem Start bis und mit dem
/// letzten Tag (v0.132.0).
///
/// WARUM in UTC-Kalendertagen: Lokale Differenzen über eine Zeitumstellung
/// fressen einen Tag (23-Stunden-Tag, Memory «Datumsdifferenzen in UTC»).
library;

int _tag(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

bool eventImFenster(DateTime? von, DateTime? bis, DateTime jetzt) {
  if (von == null) return false;
  final heute = _tag(jetzt);
  final start = _tag(von);
  final ende = _tag(bis ?? von);
  return heute >= start - 7 && heute <= ende;
}
```

- [ ] **Step 3: Tests laufen lassen**

Run: `flutter test test/event_fenster_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/core/util/event_fenster.dart test/event_fenster_test.dart
git commit -m "feat: Event-Fenster 7 Tage vorher bis letzter Tag

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 14: Event-Karte auf Heute

**Files:**
- Create: `lib/presentation/widgets/event_karte.dart`
- Modify: `lib/presentation/screens/home_screen.dart`
- Modify: `test/kachel_text_test.dart` (bleibt-Liste), `test/canvaskit_sichere_widgets_test.dart`

- [ ] **Step 1: Widget schreiben**

`lib/presentation/widgets/event_karte.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_fenster.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Anstehende Events oben auf Heute — sonst stehen Events nur unter
/// «Mehr» (v0.132.0). Eine Karte je Event im Fenster.
class EventKarten extends ConsumerWidget {
  const EventKarten({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jetzt = DateTime.now();
    final events = (ref.watch(eventsProvider).valueOrNull ?? const [])
        .where((e) => eventImFenster(e.terminVon, e.terminBis, jetzt))
        .toList();
    if (events.isEmpty) return const SizedBox.shrink();
    final betriebe = ref.watch(betriebLookupProvider);
    final fmt = DateFormat('dd.MM.');
    return Column(
      children: [
        for (final e in events)
          GestureDetector(
            onTap: () => context.push('/events/${e.routeId}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.festival, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${betriebe[e.betriebId]?.name ?? 'Event'} · '
                      '${fmt.format(e.terminVon!)}'
                      '${e.terminBis != null ? '–${fmt.format(e.terminBis!)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

Vorher prüfen: Ist `betriebLookupProvider` nach `serverId` (= `betriebId` des Events) geschlüsselt? In `tour_providers.dart` `_buildBetriebMap` ansehen. Falls anders geschlüsselt, den passenden Lookup nehmen. Die Route der Event-Detailseite ist `/events/:id` — prüfen, dass `e.routeId` dort erwartet wird (wie in `events_list_screen`/`event_detail_screen`).

- [ ] **Step 2: Auf Heute einbauen**

In `home_screen.dart` als **erstes** Kind der `ListView`: `const EventKarten(),` plus Import. In `test/kachel_text_test.dart` die bleibt-Liste um `'EventKarten('` ergänzen. In `test/canvaskit_sichere_widgets_test.dart` `'lib/presentation/widgets/event_karte.dart'` in die Dateiliste aufnehmen.

- [ ] **Step 3: Tests und Analyse**

Run: `flutter test && flutter analyze`
Expected: alle PASS, 56 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/event_karte.dart lib/presentation/screens/home_screen.dart test/
git commit -m "feat: anstehende Events oben auf Heute

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 15: Auslieferung v0.132.0

- [ ] **Step 1: Version** — `pubspec.yaml` Zeile 4 `version: 0.132.0+781`, `kAppVersion = '0.132.0'`. Run: `flutter test test/app_version_test.dart` → PASS.
- [ ] **Step 2: Volle Prüfung** — `flutter test && flutter analyze` → alle PASS, 56 issues.
- [ ] **Step 3: Sichtprüfung 360 × 800 mit Screenshots:**
  1. Mehr → Rechnungen: vier Reiter, «Jährlich» nicht gekürzt, jeder wechselt, der aktive leuchtet.
  3. Heineken: Zeile «Bergkundenpauschalen» oben.
  4. Buchhaltung: nur noch «Bücher».
  5. Heute: Event-Karte — zum Prüfen vorübergehend ein Event mit `termin_von` in 3 Tagen im Browser anzeigen lassen (bestehendes Event per Formular ändern **nur nach Rückfrage bei Daniel**; sonst die Karte über einen Widget-Test mit einem Stub-Provider belegen und im Browser nur prüfen, dass Heute ohne anstehendes Event unverändert aussieht).
- [ ] **Step 4: Doku** — `docs/chronik.md` Abschnitt v0.132.0; `ToDo.md` Stand und Klicktests v0.132.0; unter «Beobachten»: «Nutzungsmessung ab 06.10.2026 auswerten — wird Mehr angenommen, welche Büro-Screens am Handy? Grundlage für Teil 3 (Büro handytauglich)». `Projekt.md` Stand-Zeile und im Abschnitt «Was die App kann» die Navigation (Leiste mit Mehr, Bereiche) nachführen.
- [ ] **Step 5: Commit, Push, Deploy** wie Task 11 Step 5, Commit-Text `release: v0.132.0 - Rechnungen mit Reitern, Event-Karte`, Deploy-Commit `deploy v0.132.0 — Rechnungen-Bereich`. Live-Version in der Kopfzeile prüfen.

---

## Abweichungen von der Spec (bewusst)

- **Stammdaten und Einstellungen sind keine `BereichScreen`**, sondern
  eigene Screens: Sie enthalten eingebettete Formulare (Geschäft,
  MWST-Sätze, PO-Nummer, Google-Verbindung), keine reinen Link-Listen.
- ~~**Mahnwesen** bekommt einen festen Platz~~ — *zurückgenommen
  22.09.2026:* `/buchhaltung/mahnwesen` leitet nur auf `/rechnungen` weiter;
  die Spec lag richtig, das Mahnwesen ist die Kunden-Seite.
- ~~**Vier Routen ohne Link** als Ausnahme~~ — *zurückgenommen 22.09.2026:*
  Es sind Weiterleitungen für alte Links. Der Erreichbarkeits-Wächter
  erkennt reine Weiterleitungen selbst (Commit ad377b81); kein ToDo-Punkt.
- **Nachtrag (nicht in der Spec):** Die Leiste hört seit Commit 1390e9e4 auf
  `routerDelegate` statt `routeInformationProvider` — sonst stand sie auf dem
  Anmeldebildschirm und fehlte nach dem Anmelden (go_router meldet
  Weiterleitungen dem Provider ohne `notifyListeners()`).
- Der Reiter «Jahresrechnungen» heisst **«Jährlich»**, damit vier Reiter auf
  360 px ungekürzt passen.
