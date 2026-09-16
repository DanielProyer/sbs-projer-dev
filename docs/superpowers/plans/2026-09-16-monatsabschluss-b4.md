# Monatsabschluss als geführte Checkliste (B4) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Ein Screen zeigt für einen gewählten Monat zehn Prüfregeln in vier Gruppen mit Ampel und Sprungziel — und die Büro-Startseite meldet, wenn der Vormonat noch hakt.

**Architektur:** Dasselbe Muster wie die jährliche Abschlussprüfung, in eigenen Dateien: ein `MonatsKontext`, der alle Daten einmal vorlädt, zehn `MonatsRegel`-Klassen, ein `pruefeMonat()`. `Pruefbefund` und `PruefStatus` werden geteilt. Der Kontext trägt überwiegend `Einsatz`-Objekte aus B2 — deren abgeleitete Lage beantwortet vier der zehn Regeln direkt und macht die Tests leicht.

**Tech-Stack:** Flutter · Riverpod · Supabase · `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-16-monatsabschluss-b4-design.md`

**Modellwahl:** 1–5 mechanisch (Sonnet). 6 fasst Screen und Büro-Startseite an (Sonnet, Review durch Koordinator). 7 Koordinator.

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/services/buchhaltung/monats_pruef_service.dart` | `MonatsKontext`, `pruefeMonat`, `MonatsRegel` | **Neu** |
| `lib/services/buchhaltung/monats_regeln.dart` | die zehn Regeln, `alleMonatsRegeln()` | **Neu** |
| `lib/presentation/providers/monats_pruef_provider.dart` | `monatsPruefungProvider`, `monatsabschlussOffenProvider` | **Neu** |
| `lib/core/util/aufgaben_regeln.dart` | `monatsabschlussAufgabe` | Ändern |
| `lib/presentation/providers/aufgaben_detektoren_provider.dart` | Detektor i) | Ändern |
| `lib/presentation/screens/buchhaltung/monatsabschluss_screen.dart` | `MonatsabschlussInhalt` (rein) + `MonatsabschlussScreen` | **Neu** |
| `lib/core/config/router.dart` | Route `/buchhaltung/monatsabschluss` | Ändern |
| `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` | Nav-Eintrag in «Abschluss & Berichte» | Ändern |
| `test/monats_regeln_test.dart` | die zehn Regeln | **Neu** |
| `test/monats_pruef_service_test.dart` | Sortierung, Vollzähligkeit | **Neu** |
| `test/monatsabschluss_inhalt_test.dart` | Screen-Inhalt, 360 px | **Neu** |
| `test/aufgaben_regeln_test.dart` | `monatsabschlussAufgabe` | Ändern |
| `test/buchhaltung_gruppen_waechter_test.dart` | neues Ziel in «Abschluss & Berichte» | Ändern |
| `test/canvaskit_sichere_widgets_test.dart` | neuer Screen in der Dateiliste | Ändern |

**Version:** v0.109.0 (`pubspec.yaml` Zeile 4 `0.109.0+755`, `kAppVersion`).

**Gilt für alle Aufgaben:** Arbeitsverzeichnis `sbs_projer_app`; in Bash `export PATH="$PATH:/c/flutter/bin"`; `flutter analyze` hat 56 vorbestehende Infos — keine neuen (weniger ist gut, dann die Zahl melden); Kommentare auf Deutsch (Schweiz: «ss» statt «ß»), sie erklären das WARUM; Commit-Nachrichten ohne Umlaute; nie `git stash`; Layout-Tests laden Roboto (Muster `test/kachel_text_test.dart:28-35`); **CanvasKit-Regel:** Listenzeilen und Navigation aus `InkWell`/`GestureDetector` + `Container` + `Row`, **kein `ListTile`, `NavigationBar`, `FilledButton`, `OutlinedButton`**; eine Datei mit `library;`-Direktive trägt sie **vor** den Importen; `dart format` kann `if (…) return …;` umbrechen und damit `curly_braces_in_flow_control_structures` auslösen — dann Klammern setzen.

---

### Task 1: Kontext, Regel-Gerüst und Lauf

**Files:**
- Create: `lib/services/buchhaltung/monats_pruef_service.dart`
- Test: `test/monats_pruef_service_test.dart`

Vorbild ist `lib/services/buchhaltung/abschluss_pruef_service.dart` (Jahresprüfung) — lies es zuerst, besonders `Pruefbefund` (Zeile 8), `PruefStatus` (Zeile 5) und `pruefe()` (Zeile 156). Beide Typen werden hier **wiederverwendet**, nicht neu gebaut.

Der Kontext trägt vorbereitete Daten statt roher Modelle: `Einsatz` (aus B2, `lib/core/util/einsatz.dart`) beantwortet mit seiner abgeleiteten Lage vier Regeln direkt und lässt sich im Test mit einem Konstruktor bauen — `ReinigungLocal` und Konsorten wären Isar-Klassen mit `late`-Feldern.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/monats_pruef_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

MonatsKontext leer({int jahr = 2026, int monat = 8, DateTime? heute}) =>
    MonatsKontext(
      jahr: jahr,
      monat: monat,
      heute: heute ?? DateTime(2026, 9, 16),
      einsaetze: const [],
      mailRechnungenOffen: 0,
      heinekenStatus: null,
      bergTage: const {},
      pauschalenTage: const {},
      camtDeckung: const [],
      offenePrueflisteImMonat: 0,
      lohnMonate: const {},
    );

void main() {
  test('Zeitraum: von und bis umfassen den ganzen Monat', () {
    final k = leer(jahr: 2026, monat: 2);
    expect(k.von, DateTime(2026, 2, 1));
    expect(k.bis, DateTime(2026, 2, 28));
    expect(leer(jahr: 2024, monat: 2).bis, DateTime(2024, 2, 29),
        reason: 'Schaltjahr');
    expect(leer(jahr: 2026, monat: 12).bis, DateTime(2026, 12, 31));
  });

  test('laufender Monat wird erkannt', () {
    expect(leer(jahr: 2026, monat: 9, heute: DateTime(2026, 9, 16)).istLaufenderMonat,
        isTrue);
    expect(leer(jahr: 2026, monat: 8, heute: DateTime(2026, 9, 16)).istLaufenderMonat,
        isFalse);
  });

  test('pruefeMonat laeuft ueber die registrierten Regeln', () {
    // Nach Task 1 ist die Liste leer; die Vollzaehligkeit prueft Task 4,
    // wenn alle zehn Regeln stehen — so bleibt kein roter Commit zurueck.
    expect(pruefeMonat(leer()), hasLength(alleMonatsRegeln().length));
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/monats_pruef_service_test.dart`
Erwartet: FEHLER — `monats_pruef_service.dart` fehlt.

- [ ] **Step 3: Umsetzung** — `lib/services/buchhaltung/monats_pruef_service.dart`:

```dart
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

/// Was eine Monatsregel zum Prüfen braucht — einmal geladen, nicht je Regel.
///
/// WARUM `Einsatz` statt der Isar-Modelle: Die abgeleitete Lage aus B2
/// (`einsatz_lage.dart`) beantwortet vier der zehn Regeln direkt — «offen»,
/// «erledigt», «verrechnet» stehen dort schon —, und ein `Einsatz` lässt
/// sich im Test mit einem Konstruktor bauen. Was sich daraus nicht ablesen
/// lässt (Zahlungsart, Heineken-Status, Bankdeckung), liegt als schlanker
/// Wert daneben.
class MonatsKontext {
  final int jahr, monat;
  final DateTime heute;

  /// Alle Einsätze des Monats — Reinigungen, Störungen, Montagen.
  final List<Einsatz> einsaetze;

  /// Reinigungen des Monats mit Zahlungsart «Rechnung per Mail», deren
  /// Rechnung noch auf «offen» steht (Versandvermerk fehlt).
  final int mailRechnungenOffen;

  /// `zahlungsstatus` der Heineken-Monatsrechnung; `null` = keine Rechnung.
  final String? heinekenStatus;

  /// Tage mit mindestens einer abgeschlossenen Reinigung bei einem
  /// Bergkunden, als `betriebId|yyyy-MM-dd` — die Pauschale gilt pro Betrieb
  /// und Tag, nicht pro Anlage (180 CHF je Besuch).
  final Set<String> bergTage;

  /// Dieselben Schlüssel, für die eine Pauschale erfasst ist.
  final Set<String> pauschalenTage;

  /// Von–bis jeder importierten camt-Datei.
  final List<({DateTime von, DateTime bis})> camtDeckung;

  /// Offene Prüflisten-Einträge mit Buchungsdatum im Monat.
  final int offenePrueflisteImMonat;

  /// Monate des Jahres, für die eine Lohnabrechnung existiert.
  final Set<int> lohnMonate;

  const MonatsKontext({
    required this.jahr,
    required this.monat,
    required this.heute,
    required this.einsaetze,
    required this.mailRechnungenOffen,
    required this.heinekenStatus,
    required this.bergTage,
    required this.pauschalenTage,
    required this.camtDeckung,
    required this.offenePrueflisteImMonat,
    required this.lohnMonate,
  });

  DateTime get von => DateTime(jahr, monat, 1);

  /// Tag 0 des Folgemonats ist der letzte Tag dieses Monats — deckt auch
  /// Februar und Schaltjahre ab.
  DateTime get bis => DateTime(jahr, monat + 1, 0);

  bool get istLaufenderMonat => heute.year == jahr && heute.month == monat;

  /// Einsätze eines Typs.
  List<Einsatz> vomTyp(EinsatzTyp t) =>
      einsaetze.where((e) => e.typ == t).toList();

  /// Der Monatsname für Titel und Hinweise.
  String get monatName => monatsName(monat);
}

/// Monatsname 1–12. Freistehend, damit auch der Detektor ihn nutzen kann,
/// ohne einen ganzen Kontext zu bauen.
String monatsName(int monat) => const [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
][monat - 1];

/// Eine Regel des Monatsabschlusses. Gleicher Schnitt wie `AbschlussRegel`
/// der Jahresprüfung — dieselbe `Pruefbefund`-Ausgabe, damit Screen und
/// Zählung wiederverwendbar bleiben.
abstract class MonatsRegel {
  String get id;
  String get gruppe;
  String get titel;
  Pruefbefund pruefe(MonatsKontext k);

  Pruefbefund befund(
    PruefStatus s, {
    String ist = '',
    String soll = '',
    String hinweis = '',
    String? route,
  }) => Pruefbefund(
    regelId: id,
    gruppe: gruppe,
    status: s,
    titel: titel,
    ist: ist,
    soll: soll,
    hinweis: hinweis,
    aktionRoute: route,
  );

  /// Was erst am Monatsende fällig ist, meldet im laufenden Monat gelb
  /// statt rot — sonst stünde der laufende Monat immer auf Alarm.
  Pruefbefund? laeuftNoch(MonatsKontext k, {String? route}) =>
      k.istLaufenderMonat
          ? befund(PruefStatus.gelb,
              hinweis: 'Monat läuft noch.', route: route)
          : null;
}

/// Prüft den Monat: erst nach Status (rot, gelb, grün), dann nach der
/// Reihenfolge in `alleMonatsRegeln()`.
List<Pruefbefund> pruefeMonat(MonatsKontext k) {
  final regeln = alleMonatsRegeln();
  final rang = {for (var i = 0; i < regeln.length; i++) regeln[i].id: i};
  final l = regeln.map((r) => r.pruefe(k)).toList();
  l.sort((a, b) {
    final s = a.status.index.compareTo(b.status.index);
    return s != 0 ? s : rang[a.regelId]!.compareTo(rang[b.regelId]!);
  });
  return l;
}
```

Der Test verlangt `alleMonatsRegeln()` aus `monats_regeln.dart` — die Datei entsteht in Task 2. Lege sie hier schon mit einer **leeren** Liste an, damit Task 1 übersetzt:

```dart
// lib/services/buchhaltung/monats_regeln.dart
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';

/// Die Regeln des Monatsabschlusses, in Anzeigereihenfolge (B4).
List<MonatsRegel> alleMonatsRegeln() => [];
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/monats_pruef_service_test.dart`
Erwartet: BESTANDEN, 3 Tests (die Liste ist noch leer — die Vollzähligkeit prüft Task 4). `flutter analyze` — 56.

- [ ] **Step 5: Commit**

```bash
git add lib/services/buchhaltung/monats_pruef_service.dart lib/services/buchhaltung/monats_regeln.dart test/monats_pruef_service_test.dart
git commit -m "feat: Kontext und Geruest fuer den Monatsabschluss (B4)"
```

---

### Task 2: Die vier Einsatz-Regeln

**Files:**
- Modify: `lib/services/buchhaltung/monats_regeln.dart`
- Test: `test/monats_regeln_test.dart`

Alle vier lesen `k.einsaetze`. Die Lage kommt aus B2 (`EinsatzStatus` in `lib/core/util/einsatz_lage.dart`): `inArbeit` heisst bei einer Reinigung «angelegt, nicht abgeschlossen»; `erledigt` heisst «abgeschlossen, aber weder `abgerechnet` noch Ertragsbuchung»; `verrechnet` heisst «gebucht oder in der Monatsrechnung». Kulanz-Reinigungen tragen seit v0.106.2 `betragCHF == null` und fallen damit aus der Buchungsregel.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/monats_regeln_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.reinigung,
  EinsatzStatus status = EinsatzStatus.verrechnet,
  double? betrag = 94.05,
  int tag = 12,
  String name = 'Calanda',
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: '$name-$tag',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 8, tag),
  status: status,
  kennzeichen: EinsatzKennzeichen.keines,
  betragCHF: betrag,
);

MonatsKontext kontext({
  List<Einsatz> einsaetze = const [],
  int mailRechnungenOffen = 0,
  String? heinekenStatus = 'freigegeben',
  Set<String> bergTage = const {},
  Set<String> pauschalenTage = const {},
  List<({DateTime von, DateTime bis})> camtDeckung = const [
    (von: DateTime(2026, 8, 1), bis: DateTime(2026, 8, 31)),
  ],
  int offenePrueflisteImMonat = 0,
  Set<int> lohnMonate = const {8},
  int monat = 8,
  DateTime? heute,
}) => MonatsKontext(
  jahr: 2026,
  monat: monat,
  heute: heute ?? DateTime(2026, 9, 16),
  einsaetze: einsaetze,
  mailRechnungenOffen: mailRechnungenOffen,
  heinekenStatus: heinekenStatus,
  bergTage: bergTage,
  pauschalenTage: pauschalenTage,
  camtDeckung: camtDeckung,
  offenePrueflisteImMonat: offenePrueflisteImMonat,
  lohnMonate: lohnMonate,
);

Pruefbefund lauf(String regelId, MonatsKontext k) =>
    alleMonatsRegeln().firstWhere((r) => r.id == regelId).pruefe(k);

void main() {
  group('reinigungen_offen', () {
    test('alles abgeschlossen ist gruen', () {
      final b = lauf('reinigungen_offen', kontext(einsaetze: [einsatz()]));
      expect(b.status, PruefStatus.gruen);
    });
    test('eine offene Reinigung ist rot und nennt die Zahl', () {
      final b = lauf('reinigungen_offen', kontext(einsaetze: [
        einsatz(),
        einsatz(status: EinsatzStatus.inArbeit, tag: 14, name: 'Roessli'),
      ]));
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/einsaetze?typ=reinigung');
    });
    test('Stoerungen zaehlen hier nicht mit', () {
      final b = lauf('reinigungen_offen', kontext(einsaetze: [
        einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.offen),
      ]));
      expect(b.status, PruefStatus.gruen);
    });
  });

  group('einsaetze_offen', () {
    test('erledigte Stoerungen und Montagen sind gruen', () {
      final b = lauf('einsaetze_offen', kontext(einsaetze: [
        einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.erledigt),
        einsatz(typ: EinsatzTyp.montage, status: EinsatzStatus.verrechnet),
      ]));
      expect(b.status, PruefStatus.gruen);
    });
    test('offene oder geplante sind rot', () {
      for (final s in [
        EinsatzStatus.offen,
        EinsatzStatus.geplant,
        EinsatzStatus.inArbeit,
      ]) {
        final b = lauf('einsaetze_offen', kontext(einsaetze: [
          einsatz(typ: EinsatzTyp.stoerung, status: s),
        ]));
        expect(b.status, PruefStatus.rot, reason: '$s');
      }
    });
  });

  group('ertragsbuchungen', () {
    test('verrechnete Reinigungen sind gruen', () {
      final b = lauf('ertragsbuchungen', kontext(einsaetze: [einsatz()]));
      expect(b.status, PruefStatus.gruen);
    });
    test('abgeschlossen ohne Buchung ist rot', () {
      final b = lauf('ertragsbuchungen', kontext(einsaetze: [
        einsatz(status: EinsatzStatus.erledigt),
      ]));
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/rechnungen');
    });
    test('Kulanz zaehlt nicht — sie traegt keinen Betrag', () {
      final b = lauf('ertragsbuchungen', kontext(einsaetze: [
        einsatz(status: EinsatzStatus.erledigt, betrag: null),
      ]));
      expect(b.status, PruefStatus.gruen);
    });
    test('Stoerungen zaehlen hier nicht', () {
      final b = lauf('ertragsbuchungen', kontext(einsaetze: [
        einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.erledigt),
      ]));
      expect(b.status, PruefStatus.gruen);
    });
  });

  group('versandvermerk', () {
    test('keine offene Mail-Rechnung ist gruen', () {
      expect(lauf('versandvermerk', kontext()).status, PruefStatus.gruen);
    });
    test('offene Mail-Rechnungen sind rot', () {
      final b = lauf('versandvermerk', kontext(mailRechnungenOffen: 2));
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('2'));
      expect(b.aktionRoute, '/rechnungen');
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/monats_regeln_test.dart`
Erwartet: FEHLER — `alleMonatsRegeln()` ist leer, `firstWhere` findet nichts («No element»).

- [ ] **Step 3: Umsetzung** — `lib/services/buchhaltung/monats_regeln.dart` ersetzen:

```dart
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';

/// Die Regeln des Monatsabschlusses (B4).
///
/// WARUM monatlich: Der Monat ist der Takt des Geschäfts —
/// Heineken-Monatsrechnung, Lohnlauf, Bankauszug. Und der Fehlertyp «Kette
/// bricht ab» (03./04.09.2026: zwei Ertragsbuchungen fehlten, weil das Handy
/// mitten im Abschluss wegging) wird hier sichtbar, bevor er teuer wird.
///
/// Gleicher Schnitt wie die Jahresprüfung, eigene Dateien: Die 17
/// Jahresregeln funktionieren und werden nicht angefasst.

// ---------------------------------------------------------------- Einsätze

class ReinigungenOffenRegel extends MonatsRegel {
  @override
  String get id => 'reinigungen_offen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Alle Reinigungen abgeschlossen';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // «in Arbeit» heisst bei einer Reinigung: angelegt, nicht abgeschlossen.
    final offen = k
        .vomTyp(EinsatzTyp.reinigung)
        .where((e) => e.status == EinsatzStatus.inArbeit)
        .length;
    if (offen == 0) {
      return befund(PruefStatus.gruen, ist: 'keine offen');
    }
    return befund(
      PruefStatus.rot,
      ist: '$offen offen',
      soll: 'keine offen',
      hinweis: offen == 1
          ? 'Eine Reinigung steht noch auf «offen».'
          : '$offen Reinigungen stehen noch auf «offen».',
      route: '/einsaetze?typ=reinigung',
    );
  }
}

class EinsaetzeOffenRegel extends MonatsRegel {
  @override
  String get id => 'einsaetze_offen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Störungen und Montagen erledigt';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    const nichtFertig = {
      EinsatzStatus.offen,
      EinsatzStatus.geplant,
      EinsatzStatus.inArbeit,
    };
    final offen = k.einsaetze
        .where((e) =>
            (e.typ == EinsatzTyp.stoerung || e.typ == EinsatzTyp.montage) &&
            nichtFertig.contains(e.status))
        .length;
    if (offen == 0) {
      return befund(PruefStatus.gruen, ist: 'alle erledigt');
    }
    return befund(
      PruefStatus.rot,
      ist: '$offen offen',
      soll: 'alle erledigt',
      hinweis: 'Ein Einsatz aus diesem Monat ist noch nicht abgeschlossen.',
      route: '/einsaetze?typ=stoerung',
    );
  }
}

class ErtragsbuchungenRegel extends MonatsRegel {
  @override
  String get id => 'ertragsbuchungen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Jede Reinigung hat ihre Ertragsbuchung';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // «erledigt» heisst: abgeschlossen, aber weder `abgerechnet` noch
    // Ertragsbuchung (B2, einsatz_lage.dart). Kulanz trägt keinen Betrag
    // und gehört nicht dazu.
    final ohne = k
        .vomTyp(EinsatzTyp.reinigung)
        .where((e) =>
            e.status == EinsatzStatus.erledigt && (e.betragCHF ?? 0) > 0)
        .length;
    if (ohne == 0) {
      return befund(PruefStatus.gruen, ist: 'alle gebucht');
    }
    return befund(
      PruefStatus.rot,
      ist: '$ohne ohne Buchung',
      soll: 'alle gebucht',
      hinweis: 'Die Ertragsbuchung ist der letzte Schritt der Abschlusskette '
          'und damit das erste Opfer, wenn die Verbindung abbricht. Über '
          'Forderungen nachbuchen.',
      route: '/rechnungen',
    );
  }
}

class VersandvermerkRegel extends MonatsRegel {
  @override
  String get id => 'versandvermerk';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Mail-Rechnungen mit Versandvermerk';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.mailRechnungenOffen == 0) {
      return befund(PruefStatus.gruen, ist: 'alle vermerkt');
    }
    return befund(
      PruefStatus.rot,
      ist: '${k.mailRechnungenOffen} ohne Vermerk',
      soll: 'alle vermerkt',
      hinweis: 'Entweder ist die Rechnung nie angekommen, oder sie geht '
          'doppelt raus — Postausgang prüfen.',
      route: '/rechnungen',
    );
  }
}

/// Die Regeln des Monatsabschlusses, in Anzeigereihenfolge (B4).
List<MonatsRegel> alleMonatsRegeln() => [
  ReinigungenOffenRegel(),
  EinsaetzeOffenRegel(),
  ErtragsbuchungenRegel(),
  VersandvermerkRegel(),
];
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/monats_regeln_test.dart`
Erwartet: BESTANDEN, 11 Tests. `flutter test test/monats_pruef_service_test.dart` — die Regel-Tests scheitern noch (4 statt 10); das ist nach Task 4 behoben. `flutter analyze` — 56. `dart format`.

- [ ] **Step 5: Commit**

```bash
git add lib/services/buchhaltung/monats_regeln.dart test/monats_regeln_test.dart
git commit -m "feat: vier Einsatz-Regeln fuer den Monatsabschluss (B4)"
```

---

### Task 3: Die vier Heineken-Regeln

**Files:**
- Modify: `lib/services/buchhaltung/monats_regeln.dart`
- Modify: `test/monats_regeln_test.dart`

Die Status-Kette der Heineken-Monatsrechnung ist `offen → gesendet → freigegeben → bezahlt` (CLAUDE.md). `freigegeben` löst die Debitoren/Ertrag-Buchung, `bezahlt` den Zahlungseingang. Eine Rechnung, die schon `bezahlt` ist, hat die früheren Stufen hinter sich — die Regeln prüfen darum «mindestens Stufe X».

Die Bergkundenpauschale gilt **pro Betrieb und Tag** (180 CHF je Besuch, nicht je Anlage) — deshalb vergleicht die Regel Tagesschlüssel, nicht Reinigungen.

- [ ] **Step 1: Die fehlschlagenden Tests schreiben** — an `test/monats_regeln_test.dart` anhängen:

```dart
  group('heineken_rechnung', () {
    test('Rechnung vorhanden ist gruen', () {
      expect(lauf('heineken_rechnung', kontext(heinekenStatus: 'offen')).status,
          PruefStatus.gruen);
    });
    test('keine Rechnung ist rot', () {
      final b = lauf('heineken_rechnung', kontext(heinekenStatus: null));
      expect(b.status, PruefStatus.rot);
      expect(b.aktionRoute, '/heineken');
    });
    test('im laufenden Monat nur gelb', () {
      final b = lauf(
        'heineken_rechnung',
        kontext(monat: 9, heinekenStatus: null, heute: DateTime(2026, 9, 16)),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });

  group('heineken_gesendet', () {
    test('gesendet und spaeter sind gruen', () {
      for (final s in ['gesendet', 'freigegeben', 'bezahlt']) {
        expect(lauf('heineken_gesendet', kontext(heinekenStatus: s)).status,
            PruefStatus.gruen, reason: s);
      }
    });
    test('offen ist gelb', () {
      expect(lauf('heineken_gesendet', kontext(heinekenStatus: 'offen')).status,
          PruefStatus.gelb);
    });
    test('ohne Rechnung gelb, ohne doppelten Alarm', () {
      final b = lauf('heineken_gesendet', kontext(heinekenStatus: null));
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('Rechnung'));
    });
  });

  group('heineken_freigegeben', () {
    test('freigegeben und bezahlt sind gruen', () {
      for (final s in ['freigegeben', 'bezahlt']) {
        expect(lauf('heineken_freigegeben', kontext(heinekenStatus: s)).status,
            PruefStatus.gruen, reason: s);
      }
    });
    test('gesendet ist gelb — Ertrag noch nicht gebucht', () {
      final b = lauf('heineken_freigegeben', kontext(heinekenStatus: 'gesendet'));
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('Ertrag'));
    });
  });

  group('bergkundenpauschalen', () {
    test('keine Bergkunden im Monat ist gruen', () {
      expect(lauf('bergkundenpauschalen', kontext()).status, PruefStatus.gruen);
    });
    test('jeder Berg-Tag hat seine Pauschale', () {
      final b = lauf('bergkundenpauschalen', kontext(
        bergTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
        pauschalenTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
      ));
      expect(b.status, PruefStatus.gruen);
    });
    test('fehlende Pauschale ist gelb und nennt die Zahl', () {
      final b = lauf('bergkundenpauschalen', kontext(
        bergTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
        pauschalenTage: const {'b9|2026-08-12'},
      ));
      expect(b.status, PruefStatus.gelb);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/bergkundenpauschalen');
    });
  });
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/monats_regeln_test.dart`
Erwartet: FEHLER — die vier Regel-Ids gibt es nicht («No element»).

- [ ] **Step 3: Umsetzung** — in `lib/services/buchhaltung/monats_regeln.dart` vor `alleMonatsRegeln()` einfügen:

```dart
// ---------------------------------------------------------------- Heineken

/// Die Stufen der Heineken-Monatsrechnung (CLAUDE.md):
/// `offen → gesendet → freigegeben → bezahlt`. «Mindestens Stufe X» heisst:
/// Der aktuelle Status liegt an oder hinter dieser Stelle.
const _heinekenStufen = ['offen', 'gesendet', 'freigegeben', 'bezahlt'];

bool _mindestens(String? status, String stufe) {
  if (status == null) return false;
  final ist = _heinekenStufen.indexOf(status);
  final soll = _heinekenStufen.indexOf(stufe);
  return ist >= 0 && soll >= 0 && ist >= soll;
}

class HeinekenRechnungRegel extends MonatsRegel {
  @override
  String get id => 'heineken_rechnung';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung erstellt';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.heinekenStatus != null) {
      return befund(PruefStatus.gruen, ist: 'erstellt');
    }
    return laeuftNoch(k, route: '/heineken') ??
        befund(
          PruefStatus.rot,
          ist: 'fehlt',
          soll: 'erstellt',
          hinweis: 'Ohne Rechnung kein Ertrag für ${k.monatName}.',
          route: '/heineken',
        );
  }
}

class HeinekenGesendetRegel extends MonatsRegel {
  @override
  String get id => 'heineken_gesendet';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung versendet';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (_mindestens(k.heinekenStatus, 'gesendet')) {
      return befund(PruefStatus.gruen, ist: 'versendet');
    }
    if (k.heinekenStatus == null) {
      // Kein zweiter roter Alarm — die Regel darüber sagt es schon.
      return befund(PruefStatus.gelb,
          ist: 'keine Rechnung', hinweis: 'Rechnung zuerst erstellen.',
          route: '/heineken');
    }
    return befund(
      PruefStatus.gelb,
      ist: k.heinekenStatus!,
      soll: 'gesendet',
      hinweis: 'Rechnung liegt bereit, ist aber noch nicht raus.',
      route: '/heineken',
    );
  }
}

class HeinekenFreigegebenRegel extends MonatsRegel {
  @override
  String get id => 'heineken_freigegeben';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung freigegeben';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (_mindestens(k.heinekenStatus, 'freigegeben')) {
      return befund(PruefStatus.gruen, ist: 'freigegeben');
    }
    if (k.heinekenStatus == null) {
      return befund(PruefStatus.gelb,
          ist: 'keine Rechnung', hinweis: 'Rechnung zuerst erstellen.',
          route: '/heineken');
    }
    return befund(
      PruefStatus.gelb,
      ist: k.heinekenStatus!,
      soll: 'freigegeben',
      hinweis: 'Erst die Freigabe bucht Debitoren und Ertrag.',
      route: '/heineken',
    );
  }
}

class BergkundenpauschalenRegel extends MonatsRegel {
  @override
  String get id => 'bergkundenpauschalen';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Bergkundenpauschalen erfasst';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // Pro Betrieb und Tag eine Pauschale (180 CHF je Besuch), nicht je
    // Anlage — deshalb Tagesschlüssel statt Reinigungen.
    final fehlen = k.bergTage.difference(k.pauschalenTage);
    if (fehlen.isEmpty) {
      return befund(PruefStatus.gruen,
          ist: k.bergTage.isEmpty ? 'keine Bergkunden' : 'alle erfasst');
    }
    return laeuftNoch(k, route: '/bergkundenpauschalen') ??
        befund(
          PruefStatus.gelb,
          ist: '${fehlen.length} fehlen',
          soll: '${k.bergTage.length} Besuche',
          hinweis: 'Ein Besuch bei einem Bergkunden ohne Pauschale.',
          route: '/bergkundenpauschalen',
        );
  }
}
```

und die Liste erweitern:

```dart
List<MonatsRegel> alleMonatsRegeln() => [
  ReinigungenOffenRegel(),
  EinsaetzeOffenRegel(),
  ErtragsbuchungenRegel(),
  VersandvermerkRegel(),
  HeinekenRechnungRegel(),
  HeinekenGesendetRegel(),
  HeinekenFreigegebenRegel(),
  BergkundenpauschalenRegel(),
];
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/monats_regeln_test.dart`
Erwartet: BESTANDEN, 21 Tests. `flutter analyze` — 56. `dart format`.

- [ ] **Step 5: Commit**

```bash
git add lib/services/buchhaltung/monats_regeln.dart test/monats_regeln_test.dart
git commit -m "feat: vier Heineken-Regeln fuer den Monatsabschluss (B4)"
```

---

### Task 4: Bank und Lohn

**Files:**
- Modify: `lib/services/buchhaltung/monats_regeln.dart`
- Modify: `test/monats_regeln_test.dart`

- [ ] **Step 1: Die fehlschlagenden Tests schreiben** — anhängen:

```dart
  group('bank_abgedeckt', () {
    test('Datei deckt den Monat, Pruefliste leer — gruen', () {
      expect(lauf('bank_abgedeckt', kontext()).status, PruefStatus.gruen);
    });
    test('keine Datei ist gelb', () {
      final b = lauf('bank_abgedeckt', kontext(camtDeckung: const []));
      expect(b.status, PruefStatus.gelb);
      expect(b.aktionRoute, '/buchhaltung/camt-import');
    });
    test('Datei deckt nur einen Teil ist gelb', () {
      final b = lauf('bank_abgedeckt', kontext(camtDeckung: const [
        (von: DateTime(2026, 8, 1), bis: DateTime(2026, 8, 20)),
      ]));
      expect(b.status, PruefStatus.gelb);
    });
    test('mehrere Dateien duerfen den Monat gemeinsam decken', () {
      final b = lauf('bank_abgedeckt', kontext(camtDeckung: const [
        (von: DateTime(2026, 7, 25), bis: DateTime(2026, 8, 15)),
        (von: DateTime(2026, 8, 16), bis: DateTime(2026, 9, 5)),
      ]));
      expect(b.status, PruefStatus.gruen);
    });
    test('offene Prueflisten-Eintraege sind gelb', () {
      final b = lauf('bank_abgedeckt', kontext(offenePrueflisteImMonat: 4));
      expect(b.status, PruefStatus.gelb);
      expect(b.ist, contains('4'));
      expect(b.aktionRoute, '/buchhaltung/camt-pruefliste');
    });
    test('im laufenden Monat nur gelb, ohne Vorwurf', () {
      final b = lauf('bank_abgedeckt', kontext(
        monat: 9, camtDeckung: const [], heute: DateTime(2026, 9, 16)));
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });

  group('lohnlauf', () {
    test('Abrechnung vorhanden ist gruen', () {
      expect(lauf('lohnlauf', kontext(lohnMonate: const {8})).status,
          PruefStatus.gruen);
    });
    test('fehlende Abrechnung ist gelb', () {
      final b = lauf('lohnlauf', kontext(lohnMonate: const {7}));
      expect(b.status, PruefStatus.gelb);
      expect(b.aktionRoute, '/buchhaltung/lohn');
    });
    test('im laufenden Monat nur gelb mit Hinweis', () {
      final b = lauf('lohnlauf', kontext(
        monat: 9, lohnMonate: const {}, heute: DateTime(2026, 9, 16)));
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/monats_regeln_test.dart`
Erwartet: FEHLER — `bank_abgedeckt` und `lohnlauf` gibt es nicht.

- [ ] **Step 3: Umsetzung** — vor `alleMonatsRegeln()` einfügen:

```dart
// ------------------------------------------------------------- Bank & Lohn

class BankAbgedecktRegel extends MonatsRegel {
  @override
  String get id => 'bank_abgedeckt';
  @override
  String get gruppe => 'Bank';
  @override
  String get titel => 'Bankauszug importiert und geprüft';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // Deckung Tag für Tag: Mehrere Auszüge dürfen den Monat gemeinsam
    // abdecken — Daniel zieht sie nicht immer monatsweise.
    var tag = k.von;
    final luecken = <DateTime>[];
    while (!tag.isAfter(k.bis)) {
      final gedeckt = k.camtDeckung.any((d) =>
          !tag.isBefore(d.von) && !tag.isAfter(d.bis));
      if (!gedeckt) luecken.add(tag);
      tag = tag.add(const Duration(days: 1));
    }

    if (luecken.isNotEmpty) {
      return laeuftNoch(k, route: '/buchhaltung/camt-import') ??
          befund(
            PruefStatus.gelb,
            ist: '${luecken.length} Tage ohne Auszug',
            soll: 'ganzer Monat',
            hinweis: 'Bankauszug für ${k.monatName} importieren.',
            route: '/buchhaltung/camt-import',
          );
    }

    if (k.offenePrueflisteImMonat > 0) {
      return befund(
        PruefStatus.gelb,
        ist: '${k.offenePrueflisteImMonat} offen',
        soll: 'Prüfliste leer',
        hinweis: 'Buchungen aus diesem Monat warten auf die Zuordnung.',
        route: '/buchhaltung/camt-pruefliste',
      );
    }

    return befund(PruefStatus.gruen, ist: 'importiert, Prüfliste leer');
  }
}

class LohnlaufRegel extends MonatsRegel {
  @override
  String get id => 'lohnlauf';
  @override
  String get gruppe => 'Lohn';
  @override
  String get titel => 'Lohnlauf gemacht';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.lohnMonate.contains(k.monat)) {
      return befund(PruefStatus.gruen, ist: 'abgerechnet');
    }
    return laeuftNoch(k, route: '/buchhaltung/lohn') ??
        befund(
          PruefStatus.gelb,
          ist: 'fehlt',
          soll: 'abgerechnet',
          hinweis: 'Keine Lohnabrechnung für ${k.monatName}.',
          route: '/buchhaltung/lohn',
        );
  }
}
```

und die Liste vervollständigen — die zehn Regeln in Anzeigereihenfolge:

```dart
List<MonatsRegel> alleMonatsRegeln() => [
  ReinigungenOffenRegel(),
  EinsaetzeOffenRegel(),
  ErtragsbuchungenRegel(),
  VersandvermerkRegel(),
  HeinekenRechnungRegel(),
  HeinekenGesendetRegel(),
  HeinekenFreigegebenRegel(),
  BergkundenpauschalenRegel(),
  BankAbgedecktRegel(),
  LohnlaufRegel(),
];
```

- [ ] **Step 4: Die Vollzähligkeit prüfen** — an `test/monats_pruef_service_test.dart` anhängen (vor der schliessenden `}` von `main()`):

```dart
  test('alle zehn Regeln laufen und kommen genau einmal vor', () {
    final befunde = pruefeMonat(leer());
    expect(befunde, hasLength(10));
    expect(befunde.map((b) => b.regelId).toSet(), hasLength(10));
    expect(alleMonatsRegeln(), hasLength(10));
  });

  test('sortiert rot vor gelb vor gruen', () {
    final reihenfolge = pruefeMonat(leer()).map((b) => b.status.index).toList();
    final sortiert = [...reihenfolge]..sort();
    expect(reihenfolge, orderedEquals(sortiert));
  });

  test('jede Regel traegt Gruppe und Titel, vier Gruppen', () {
    for (final b in pruefeMonat(leer())) {
      expect(b.gruppe, isNotEmpty, reason: b.regelId);
      expect(b.titel, isNotEmpty, reason: b.regelId);
    }
    expect(
      pruefeMonat(leer()).map((b) => b.gruppe).toSet(),
      {'Einsätze', 'Heineken', 'Bank', 'Lohn'},
    );
  });
```

- [ ] **Step 5: Tests laufen lassen**

Run: `flutter test test/monats_regeln_test.dart test/monats_pruef_service_test.dart`
Erwartet: BESTANDEN — 30 Regel-Tests und 6 Service-Tests. `flutter analyze` — 56. `dart format`.

- [ ] **Step 6: Commit**

```bash
git add lib/services/buchhaltung/monats_regeln.dart test/monats_regeln_test.dart test/monats_pruef_service_test.dart
git commit -m "feat: Bank- und Lohn-Regel, zehn Regeln vollstaendig (B4)"
```

---

### Task 5: Provider und Detektor

**Files:**
- Create: `lib/presentation/providers/monats_pruef_provider.dart`
- Modify: `lib/core/util/aufgaben_regeln.dart`
- Modify: `lib/presentation/providers/aufgaben_detektoren_provider.dart`
- Modify: `test/aufgaben_regeln_test.dart`

Vorbild für das parallele Laden: `abschlussPruefungProvider` in `lib/presentation/providers/buchhaltung_providers.dart:169` (`await (…, …).wait`). Für den Detektor: die Regelfunktionen in `aufgaben_regeln.dart` (`bankPrueflisteAufgabe`, B3) und die Detektoren g)/h) in `aufgaben_detektoren_provider.dart`.

- [ ] **Step 1: Die fehlschlagende Regelfunktion testen** — an `test/aufgaben_regeln_test.dart` anhängen:

```dart
  group('monatsabschlussAufgabe', () {
    test('nichts offen ergibt nichts', () {
      expect(monatsabschlussAufgabe(0, 'August'), isNull);
    });
    test('Titel nennt Monat und Zahl', () {
      expect(monatsabschlussAufgabe(1, 'August')!.titel,
          'Monatsabschluss August: 1 Punkt offen');
      expect(monatsabschlussAufgabe(3, 'August')!.titel,
          'Monatsabschluss August: 3 Punkte offen');
    });
    test('ist ein Vorrat und zeigt auf den Screen', () {
      final a = monatsabschlussAufgabe(3, 'August')!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/monatsabschluss');
      expect(a.key, 'monatsabschluss');
    });
  });
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/aufgaben_regeln_test.dart`
Erwartet: FEHLER — `monatsabschlussAufgabe` ist nicht definiert.

- [ ] **Step 3: Regelfunktion** — in `lib/core/util/aufgaben_regeln.dart` nach `eingangsrechnungenAufgabe`:

```dart
/// Punkte, die der Monatsabschluss des Vormonats offen lässt.
///
/// Ein Stapel, kein Termin (B3): Er steht auf der Büro-Startseite, nicht in
/// der Glocke. Gezählt werden alle nicht-grünen Regeln — gelb heisst beim
/// Monatsabschluss «noch offen».
Aufgabe? monatsabschlussAufgabe(int anzahl, String monatName) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'monatsabschluss',
        titel: 'Monatsabschluss $monatName: $anzahl '
            '${anzahl == 1 ? 'Punkt' : 'Punkte'} offen',
        route: '/buchhaltung/monatsabschluss',
        istVorrat: true,
      );
```

- [ ] **Step 4: Der Provider** — `lib/presentation/providers/monats_pruef_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ein Monat als Schlüssel — Records sind vergleichbar, damit taugen sie als
/// `family`-Argument ohne eigene Klasse.
typedef MonatsSchluessel = ({int jahr, int monat});

String _tagSchluessel(String betriebId, DateTime d) =>
    '$betriebId|${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Die Befunde eines Monats. Lädt alles einmal und parallel — nach dem
/// Vorbild von `abschlussPruefungProvider`.
final monatsPruefungProvider = FutureProvider.autoDispose
    .family<List<Pruefbefund>, MonatsSchluessel>((ref, m) async {
  final von = DateTime(m.jahr, m.monat, 1);
  final bis = DateTime(m.jahr, m.monat + 1, 0);
  bool imMonat(DateTime d) => !d.isBefore(von) && !d.isAfter(bis);

  final betriebe = ref.watch(betriebLookupProvider);
  final reinigungen = await ref.watch(reinigungenByJahrProvider(m.jahr).future);
  final belegIds = await BuchungRepository.belegIdsMitBuchung(ab: von, bis: bis);

  final einsaetze = <Einsatz>[
    for (final r in reinigungen)
      if (imMonat(r.datum))
        einsatzAusReinigung(
          r,
          betrieb: betriebe[r.betriebId],
          hatBuchung: r.serverId != null && belegIds.contains(r.serverId),
        ),
    for (final s in ref.watch(stoerungenProvider))
      if (imMonat(s.datum)) einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
    for (final mo in ref.watch(montagenProvider))
      if (imMonat(mo.datum)) einsatzAusMontage(mo, betrieb: betriebe[mo.betriebId]),
  ];

  // Berg-Tage aus den Reinigungen des Monats: ein Besuch = Betrieb + Tag.
  final bergTage = <String>{
    for (final r in reinigungen)
      if (imMonat(r.datum) &&
          r.status == 'abgeschlossen' &&
          (betriebe[r.betriebId]?.istBergkunde ?? false))
        _tagSchluessel(r.betriebId, r.datum),
  };

  final client = SupabaseService.client;
  final uid = SupabaseService.dataUserId;
  final vonStr = von.toIso8601String().split('T').first;
  final bisStr = bis.toIso8601String().split('T').first;

  var pauschalenTage = <String>{};
  try {
    final rows = await client
        .from('bergkundenpauschalen')
        .select('betrieb_id, datum')
        .eq('user_id', uid)
        .gte('datum', vonStr)
        .lte('datum', bisStr);
    pauschalenTage = {
      for (final r in rows)
        _tagSchluessel(
            r['betrieb_id'] as String, DateTime.parse(r['datum'] as String)),
    };
  } catch (e) {
    debugPrint('[Monatsabschluss] Pauschalen: $e');
  }

  String? heinekenStatus;
  try {
    final rows = await client
        .from('rechnungen')
        .select('zahlungsstatus')
        .eq('user_id', uid)
        .eq('rechnungstyp', 'heineken_monat')
        .eq('heineken_monat', vonStr)
        .limit(1);
    if (rows.isNotEmpty) heinekenStatus = rows.first['zahlungsstatus'] as String?;
  } catch (e) {
    debugPrint('[Monatsabschluss] Heineken-Rechnung: $e');
  }

  // Mail-Rechnungen ohne Versandvermerk: Die Zahlungsart steht an der
  // Reinigung, nicht an der Rechnung — deshalb über die Reinigungen des
  // Monats und deren Rechnungsstatus.
  var mailRechnungenOffen = 0;
  try {
    final rows = await client
        .from('rechnungen')
        .select('id, betrieb_id, created_at')
        .eq('user_id', uid)
        .eq('zahlungsstatus', 'offen')
        .neq('rechnungstyp', 'heineken_monat')
        .gte('created_at', vonStr)
        .lte('created_at', '${bisStr}T23:59:59');
    for (final r in rows) {
      final betriebId = r['betrieb_id']?.toString();
      if (betriebId == null) continue;
      final rein = await client
          .from('reinigungen')
          .select('id')
          .eq('betrieb_id', betriebId)
          .eq('zahlungsart', 'rechnung_mail')
          .eq('datum', (r['created_at'] as String).split('T').first)
          .limit(1);
      if (rein.isNotEmpty) mailRechnungenOffen++;
    }
  } catch (e) {
    debugPrint('[Monatsabschluss] Versandvermerk: $e');
  }

  var camtDeckung = <({DateTime von, DateTime bis})>[];
  try {
    final dateien = await CamtDateiRepository.getAll();
    camtDeckung = [for (final d in dateien) (von: d.von, bis: d.bis)];
  } catch (e) {
    debugPrint('[Monatsabschluss] camt-Dateien: $e');
  }

  var offenePruefliste = 0;
  try {
    final offen = await ref.watch(camtPrueflisteProvider.future);
    offenePruefliste = offen.where((e) => imMonat(e.bookingDatum)).length;
  } catch (e) {
    debugPrint('[Monatsabschluss] Prüfliste: $e');
  }

  var lohnMonate = <int>{};
  try {
    final abrechnungen = await LohnRepository.getAbrechnungen(m.jahr);
    lohnMonate = {for (final a in abrechnungen) a.monat};
  } catch (e) {
    debugPrint('[Monatsabschluss] Lohn: $e');
  }

  return pruefeMonat(MonatsKontext(
    jahr: m.jahr,
    monat: m.monat,
    heute: DateTime.now(),
    einsaetze: einsaetze,
    mailRechnungenOffen: mailRechnungenOffen,
    heinekenStatus: heinekenStatus,
    bergTage: bergTage,
    pauschalenTage: pauschalenTage,
    camtDeckung: camtDeckung,
    offenePrueflisteImMonat: offenePruefliste,
    lohnMonate: lohnMonate,
  ));
});

/// Der Vormonat als Schlüssel — die Vorgabe des Screens und die Grundlage
/// des Detektors.
MonatsSchluessel vormonat(DateTime heute) {
  final d = DateTime(heute.year, heute.month - 1, 1);
  return (jahr: d.year, monat: d.month);
}
```

Prüfe die Namen `CamtDateiRepository.getAll()`, `LohnRepository.getAbrechnungen(jahr)`, `BetriebLocal.istBergkunde`, `SupabaseService.dataUserId` und die Feldnamen `d.von`/`d.bis` mit `grep`, bevor du sie nutzt; weicht etwas ab, passe es an und melde es.

- [ ] **Step 5: Der Detektor** — in `lib/presentation/providers/aufgaben_detektoren_provider.dart` nach Detektor h):

```dart
  // i) Monatsabschluss des Vormonats — die Zahl der nicht-grünen Regeln.
  //    Ein Vorrat: gehört ins Büro, nicht in die Glocke (B4).
  try {
    final m = vormonat(heute);
    final befunde = await ref.watch(monatsPruefungProvider(m).future);
    final offen =
        befunde.where((b) => b.status != PruefStatus.gruen).length;
    final a = monatsabschlussAufgabe(offen, monatsName(m.monat));
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Monatsabschluss-Detektor: $e');
  }
```

Importe ergänzen: `monats_pruef_provider.dart`, `monats_pruef_service.dart`, `abschluss_pruef_service.dart`.

- [ ] **Step 6: Prüfen**

Run: `flutter test test/aufgaben_regeln_test.dart test/aufgaben_providers_test.dart`
Erwartet: BESTANDEN. `flutter analyze` — 56. `dart format` auf die neue Datei.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/monats_pruef_provider.dart lib/core/util/aufgaben_regeln.dart lib/presentation/providers/aufgaben_detektoren_provider.dart test/aufgaben_regeln_test.dart
git commit -m "feat: Provider und Buero-Detektor fuer den Monatsabschluss (B4)"
```

---

### Task 6: Screen, Route und Nav-Eintrag

**Files:**
- Create: `lib/presentation/screens/buchhaltung/monatsabschluss_screen.dart`
- Modify: `lib/core/config/router.dart`
- Modify: `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
- Test: `test/monatsabschluss_inhalt_test.dart`
- Modify: `test/buchhaltung_gruppen_waechter_test.dart`, `test/canvaskit_sichere_widgets_test.dart`

Vorbild für die Darstellung: `lib/presentation/screens/buchhaltung/audit_screen.dart` — besonders `_zeile(Pruefbefund)` (Zeile 211) und die Gruppierung (Zeile 83–86). Die Jahr/Monat-Auswahl kommt von `AppJahrMonatLeiste` (`lib/presentation/widgets/filter/app_jahr_monat_leiste.dart`, Parameter `jahre`, `selectedJahr`, `onJahrChanged`, `selectedMonat`, `onMonatChanged`, `trailing`).

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/monatsabschluss_inhalt_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/monatsabschluss_screen.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

Pruefbefund b(
  String id,
  PruefStatus s, {
  String gruppe = 'Einsätze',
  String titel = 'Eine Regel',
  String? route,
}) => Pruefbefund(
  regelId: id,
  gruppe: gruppe,
  status: s,
  titel: titel,
  ist: 'Ist-Wert',
  aktionRoute: route,
);

Widget rahmen(
  List<Pruefbefund> befunde, {
  ValueChanged<Pruefbefund>? onZeile,
}) => MaterialApp(
  home: MonatsabschlussInhalt(
    befunde: befunde,
    jahr: 2026,
    monat: 8,
    jahre: const [2026, 2025],
    onJahr: (_) {},
    onMonat: (_) {},
    onZeile: onZeile ?? (_) {},
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt Gruppen und Regeln', (tester) async {
    await tester.pumpWidget(rahmen([
      b('r1', PruefStatus.rot, titel: 'Alle Reinigungen abgeschlossen'),
      b('h1', PruefStatus.gelb, gruppe: 'Heineken', titel: 'Monatsrechnung erstellt'),
      b('l1', PruefStatus.gruen, gruppe: 'Lohn', titel: 'Lohnlauf gemacht'),
    ]));
    expect(find.text('Einsätze'), findsOneWidget);
    expect(find.text('Heineken'), findsOneWidget);
    expect(find.text('Lohn'), findsOneWidget);
    expect(find.text('Alle Reinigungen abgeschlossen'), findsOneWidget);
  });

  testWidgets('Kopfzeile zaehlt die offenen Punkte', (tester) async {
    await tester.pumpWidget(rahmen([
      b('r1', PruefStatus.rot),
      b('r2', PruefStatus.gelb),
      b('r3', PruefStatus.gruen),
    ]));
    expect(find.textContaining('2 von 3'), findsOneWidget);
  });

  testWidgets('alles gruen meldet sich', (tester) async {
    await tester.pumpWidget(rahmen([b('r1', PruefStatus.gruen)]));
    expect(find.textContaining('Alles erledigt'), findsOneWidget);
  });

  testWidgets('Tipp auf eine Zeile mit Ziel meldet den Befund', (tester) async {
    Pruefbefund? getippt;
    await tester.pumpWidget(rahmen(
      [b('r1', PruefStatus.rot, titel: 'Mit Ziel', route: '/rechnungen')],
      onZeile: (x) => getippt = x,
    ));
    await tester.tap(find.text('Mit Ziel'));
    expect(getippt?.regelId, 'r1');
  });

  testWidgets('auf 360 px kein Ueberlauf, kein ListTile', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(rahmen([
      b('r1', PruefStatus.rot, titel: 'Jede Reinigung hat ihre Ertragsbuchung'),
      b('r2', PruefStatus.gelb, gruppe: 'Bank', titel: 'Bankauszug importiert und geprüft'),
    ]));
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/monatsabschluss_inhalt_test.dart`
Erwartet: FEHLER — `monatsabschluss_screen.dart` fehlt.

- [ ] **Step 3: Umsetzung** — `lib/presentation/screens/buchhaltung/monatsabschluss_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/monats_pruef_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

/// Der Monatsabschluss als Liste — reine Darstellung, testbar ohne Provider.
///
/// WARUM: Der Monat ist der Takt des Geschäfts, und «Kette bricht ab» (zwei
/// fehlende Ertragsbuchungen am 03./04.09.2026) fällt monatlich auf, bevor
/// es teuer wird. Gleiche Bauart wie die Jahresprüfung, nur zehn Regeln
/// statt siebzehn (B4).
class MonatsabschlussInhalt extends StatelessWidget {
  final List<Pruefbefund> befunde;
  final int jahr, monat;
  final List<int> jahre;
  final ValueChanged<int> onJahr;
  final ValueChanged<int> onMonat;
  final ValueChanged<Pruefbefund> onZeile;

  const MonatsabschlussInhalt({
    super.key,
    required this.befunde,
    required this.jahr,
    required this.monat,
    required this.jahre,
    required this.onJahr,
    required this.onMonat,
    required this.onZeile,
  });

  static Color farbe(PruefStatus s) => switch (s) {
    PruefStatus.rot => AppColors.error,
    PruefStatus.gelb => AppColors.warning,
    PruefStatus.gruen => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final offen = befunde.where((b) => b.status != PruefStatus.gruen).length;
    final gruppen = <String, List<Pruefbefund>>{};
    for (final b in befunde) {
      gruppen.putIfAbsent(b.gruppe, () => []).add(b);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Monatsabschluss')),
      body: Column(
        children: [
          AppJahrMonatLeiste(
            jahre: jahre,
            selectedJahr: jahr,
            onJahrChanged: onJahr,
            selectedMonat: monat,
            onMonatChanged: onMonat,
            trailing: Text(
              offen == 0
                  ? 'Alles erledigt 🎉'
                  : '$offen von ${befunde.length} offen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: offen == 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final g in gruppen.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                    child: Text(
                      g.key,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final b in g.value) _zeile(b),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// CanvasKit: `InkWell` + `Container` + `Row`, kein `ListTile`.
  Widget _zeile(Pruefbefund b) => InkWell(
    onTap: b.aktionRoute == null ? null : () => onZeile(b),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: farbe(b.status),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.titel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (b.ist.isNotEmpty || b.soll.isNotEmpty)
                  Text(
                    'Ist: ${b.ist}${b.soll.isEmpty ? '' : ' · Soll: ${b.soll}'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                if (b.hinweis.isNotEmpty)
                  Text(
                    b.hinweis,
                    style: TextStyle(fontSize: 11, color: farbe(b.status)),
                  ),
              ],
            ),
          ),
          if (b.aktionRoute != null)
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}

/// Angebunden: hält die Monatswahl und lädt die Befunde.
class MonatsabschlussScreen extends ConsumerStatefulWidget {
  const MonatsabschlussScreen({super.key});

  @override
  ConsumerState<MonatsabschlussScreen> createState() =>
      _MonatsabschlussScreenState();
}

class _MonatsabschlussScreenState extends ConsumerState<MonatsabschlussScreen> {
  late MonatsSchluessel _m;

  @override
  void initState() {
    super.initState();
    // Der Vormonat ist die sinnvolle Vorgabe: Den laufenden kann man noch
    // nicht abschliessen.
    _m = vormonat(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final befunde = ref.watch(monatsPruefungProvider(_m));
    final jetzt = DateTime.now();
    final jahre = [for (var j = jetzt.year; j >= jetzt.year - 3; j--) j];

    return befunde.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Monatsabschluss')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Monatsabschluss')),
        body: Center(child: Text('Prüfung nicht möglich: $e')),
      ),
      data: (liste) => MonatsabschlussInhalt(
        befunde: liste,
        jahr: _m.jahr,
        monat: _m.monat,
        jahre: jahre,
        onJahr: (j) => setState(() => _m = (jahr: j, monat: _m.monat)),
        onMonat: (mo) => setState(
            () => _m = (jahr: _m.jahr, monat: mo == 0 ? _m.monat : mo)),
        onZeile: (b) => context.push(b.aktionRoute!),
      ),
    );
  }
}
```

`AppJahrMonatLeiste` kennt «alle Monate» als `0`; der Monatsabschluss braucht immer einen Monat, deshalb bleibt bei `0` der bisherige stehen.

- [ ] **Step 4: Route und Nav-Eintrag**

In `lib/core/config/router.dart` neben den anderen `/buchhaltung/…`-Routen:

```dart
    GoRoute(
      path: '/buchhaltung/monatsabschluss',
      builder: (context, state) => const MonatsabschlussScreen(),
    ),
```

mit Import von `monatsabschluss_screen.dart`.

In `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` in der Gruppe **Abschluss & Berichte**, direkt vor «Abschlussprüfung»:

```dart
          _NavTile(
            icon: Icons.event_available,
            title: 'Monatsabschluss',
            subtitle: 'Zehn Punkte je Monat: Einsätze, Heineken, Bank, Lohn',
            onTap: () => context.push('/buchhaltung/monatsabschluss'),
          ),
```

In `test/buchhaltung_gruppen_waechter_test.dart` die Liste `abschluss` um `'/buchhaltung/monatsabschluss'` ergänzen — an der Stelle, die der Reihenfolge im Screen entspricht (vor `/buchhaltung/audit`). Der Test prüft die Reihenfolge, also muss der Eintrag an der richtigen Position stehen.

In `test/canvaskit_sichere_widgets_test.dart` die Dateiliste um `'lib/presentation/screens/buchhaltung/monatsabschluss_screen.dart'` ergänzen.

- [ ] **Step 5: Prüfen**

Run: `flutter test test/monatsabschluss_inhalt_test.dart test/buchhaltung_gruppen_waechter_test.dart test/canvaskit_sichere_widgets_test.dart`
Erwartet: BESTANDEN. Dann `flutter analyze` — 56 — und die volle `flutter test` — grün.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/buchhaltung/monatsabschluss_screen.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart test/monatsabschluss_inhalt_test.dart test/buchhaltung_gruppen_waechter_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: Monatsabschluss-Screen mit Route und Nav-Eintrag (B4)"
```

---

### Task 7: Sichtprüfung, Version, Auslieferung, Doku

Macht der Koordinator selbst.

- [ ] **Step 1: Volle Suite und Analyse**

Run: `flutter analyze && flutter test`
Erwartet: 56 Befunde oder weniger, alle Tests grün.

- [ ] **Step 2: Sichtprüfung im Browser**

Wegwerf-Datei `lib/heute_probe.dart` (wie bei B1/B2/B3/B6), gebaut mit `flutter build web -t lib/heute_probe.dart --base-href "/"`, über `.claude/launch.json` («flutter-web») geöffnet. Sie rendert `MonatsabschlussInhalt` mit zehn erfundenen Befunden — je Gruppe mindestens einer in rot, gelb und grün — auf 360 px und 1400 px. Prüfen: Gruppenüberschriften, Ampelpunkte, Kopfzeile «N von 10 offen», Hinweistext in der Statusfarbe, Pfeil nur bei Zeilen mit Ziel. Zweiter Zustand: alle grün → «Alles erledigt 🎉». Danach löschen, nie committen.

- [ ] **Step 3: Version und Auslieferung**

`pubspec.yaml` Zeile 4 auf `0.109.0+755`, `kAppVersion` auf `'0.109.0'`; `flutter test test/app_version_test.dart`. Dann nach `CLAUDE.md`: Build mit `--base-href "/sbs-projer-dev/" --pwa-strategy=none`, `main.dart.js` in `flutter_bootstrap.js` cache-busten, `flutter_service_worker.js` löschen, `404.html` mitliefern, auf `gh-pages` ausliefern, Live-`version.json` prüfen.

- [ ] **Step 4: Doku**

- `ToDo.md`: B4 erledigt, mit den zehn Regeln und dem Hinweis, dass der laufende Monat bei Heineken, Lohn und Bank gelb statt rot meldet.
- `docs/app-analyse-2026-09.md`: B4 ✅.
- Memory `app_analyse_2026_09.md` und `MEMORY.md` nachziehen.

**Klicktest Daniel:** Vormonat ist vorgewählt · jede rote Zeile führt ans richtige Ziel · der Detektor auf der Büro-Startseite zeigt dieselbe Zahl wie der Screen · der laufende Monat zeigt bei Heineken, Lohn und Bank «Monat läuft noch» statt rot · ein Monat ohne Bergkunden meldet dort grün.

---

## Nach der Auslieferung

- [ ] Klicktest Daniel (Task 7).
- [ ] Den August 2026 durchgehen: Die Heineken-Rechnung für August fehlt (bekannt aus dem ToDo) — der Monatsabschluss sollte genau das als ersten roten Punkt zeigen. Das ist die beste Probe aufs Exempel.
