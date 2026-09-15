# Ein Aufgaben-Begriff (B6) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Glocke, Startkarte, Kachel, Sheet und Aufgaben-Screen lesen **eine** Liste (`aufgabenListeProvider`); Erinnerungen, eigene Aufgaben, anstehende Einsätze und Vorschläge stehen darin nach Fälligkeit; Glocke/Karte/Kachel/Sheet zeigen den Ausschnitt «jetzt fällig».

**Architektur:** Ein Eintragstyp `AufgabenEintrag` mit Quelle (Enum) statt Callbacks; eine reine Funktion `baueAufgabenListe(…)` mit Primitiven baut die Liste, eine reine Funktion `jetztFaellig(…)` filtert sie. Die Detektoren ziehen unverändert in eine eigene Datei, die anstehenden Einsätze kommen über die B2-Adapter. Eine Zeile `AufgabeZeile` (CanvasKit-sicher) und eine Aktionsklasse `AufgabenAktionen` bedienen Sheet und Screen. Zum Schluss fallen die sechs alten Listen (B2-Zyklus).

**Tech-Stack:** Flutter · Riverpod · GoRouter · Supabase · `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-15-aufgaben-begriff-b6-design.md`

**Modellwahl:** 1, 2, 4, 8 mechanisch (Sonnet). 3, 5, 6, 7 mehrere Dateien (Sonnet, Review durch Koordinator). 9 Koordinator.

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/core/util/einsatz.dart` | `Einsatz.geplantAm` | Ändern |
| `lib/core/util/aufgabe.dart` | `AufgabenQuelle`, `AufgabenEintrag`, `SaisonVorschlag`, `SaisonTerminEintrag`, `einsatzFaelligkeit`, `jetztFaellig`, `faelligText`, `baueAufgabenListe` | **Neu** |
| `lib/presentation/providers/aufgaben_detektoren_provider.dart` | `aufgabenZeilenProvider`, `aufgabenDetektorenProvider` (verschobener Detektor-Block) | **Neu** |
| `lib/presentation/providers/einsatz_providers.dart` | `anstehendeEinsaetzeProvider` | Ändern |
| `lib/presentation/providers/aufgaben_providers.dart` | `aufgabenListeProvider`, `aufgabenJetztProvider`, `aufgabenBadgeProvider`; alter Inhalt weg | Ersetzen |
| `lib/presentation/widgets/aufgabe_zeile.dart` | `AufgabeZeile` | **Neu** |
| `lib/presentation/widgets/aufgaben_aktionen.dart` | `AufgabenAktionen` (dorthin, snooze, erledigt, einplanen, bestaetigen), `neueAufgabeDialog` | **Neu** |
| `lib/presentation/screens/aufgaben/aufgaben_screen.dart` | `AufgabenInhalt` (rein) + `AufgabenScreen` (angebunden) | Ersetzen |
| `lib/presentation/widgets/aufgaben_sheet.dart` | Sheet auf `AufgabeZeile`, ohne `ListTile` | Ersetzen |
| `lib/presentation/widgets/aufgaben_glocke.dart:17` | Badge aus `aufgabenBadgeProvider` | Ändern |
| `lib/presentation/screens/home_screen.dart:100-107, 186-187, 487-503` | Kachelzähler und Startkarte aus den neuen Providern | Ändern |
| `lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart:100,124` | liest/invalidiert die neue Liste | Ändern |
| `lib/core/config/router.dart` | sechs alte Listenrouten + Importe weg | Ändern |
| sechs `*_list_screen.dart` | löschen | Löschen |
| `test/einsatz_test.dart` | `geplantAm` | Ändern |
| `test/aufgabe_test.dart` | Regeln und Listenaufbau | **Neu** |
| `test/aufgaben_providers_test.dart` | Vereinigung, Badge | **Neu** |
| `test/aufgabe_zeile_test.dart` | Zeile, Roboto, 360 px | **Neu** |
| `test/aufgaben_inhalt_test.dart` | Gruppen, Leerzustand, Aktionen | **Neu** |
| `test/aufgaben_eine_quelle_waechter_test.dart` | fünf Oberflächen, eine Quelle | **Neu** |
| `test/canvaskit_sichere_widgets_test.dart` | `aufgabe_zeile.dart`, `aufgaben_sheet.dart` | Ändern |
| `test/status_vergleiche_ratsche_test.dart` | 23 → 20 | Ändern |

**Version:** v0.106.0 (`pubspec.yaml` Zeile 4 `0.106.0+749`, `kAppVersion`).

**Gilt für alle Aufgaben:** Arbeitsverzeichnis `sbs_projer_app`; Bash `export PATH="$PATH:/c/flutter/bin"`; `flutter analyze` hat 56 vorbestehende Infos — keine neuen (fallen welche weg, ist das gut, dann die neue Zahl melden); Kommentare Deutsch (Schweiz: «ss»), erklären das WARUM; Commit-Nachrichten ohne Umlaute; nie `git stash`; Layout-Tests laden Roboto (Muster `test/kachel_text_test.dart:28-35`); CanvasKit-Regel: Listenzeilen und kritische Aktionen aus `InkWell`/`GestureDetector` + `Container` + `Row`, kein `ListTile`, kein `FilledButton`/`OutlinedButton`; `IconButton` und `FloatingActionButton` sind bewährt. Im VM-Testlauf gelten die nativen Isar-Klassen: `late`-Felder setzen, `routeId` ist `id.toString()`.

---

### Task 1: `Einsatz.geplantAm`

**Files:**
- Modify: `lib/core/util/einsatz.dart`
- Modify: `test/einsatz_test.dart`

Die Fälligkeit eines Einsatzes ist der geplante Tag, sonst das Meldedatum. `Einsatz` (B2) trägt heute nur `datum` und `zeit` (Uhrzeit nur bei Stufe geplant); `geplantAm` fehlt.

- [ ] **Step 1: Test ergänzen** — in `test/einsatz_test.dart`, Gruppe `einsatzAusStoerung`, ein Test dazu:

```dart
    test('geplantAm wird uebernommen, auch wenn die Stufe nicht geplant ist', () {
      final s = StoerungLocal()
        ..serverId = 's3'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 10)
        ..geplantAm = DateTime(2026, 9, 17)
        ..arbeitVon = '09:00'
        ..status = 'offen'
        ..problemBeschreibung = 'x';
      final e = einsatzAusStoerung(s, betrieb: betrieb());
      expect(e.status, EinsatzStatus.inArbeit);
      expect(e.geplantAm, DateTime(2026, 9, 17));
    });
```

und in `einsatzAusMontage` ein Test, der `..geplantAm = DateTime(2026, 9, 20)` setzt und `e.geplantAm` prüft; in `einsatzAusReinigung` prüfen: `expect(e.geplantAm, isNull)`.

- [ ] **Step 2:** `flutter test test/einsatz_test.dart` — FEHLER: `geplantAm` nicht definiert.

- [ ] **Step 3: Feld ergänzen** — in `class Einsatz` nach `final DateTime datum;`:

```dart
  /// Geplanter Tag (Störung/Montage). Für die Aufgaben-Fälligkeit (B6):
  /// `geplantAm ?? datum` — ein geplanter Einsatz ist am Plantag fällig,
  /// nicht am Meldetag.
  final DateTime? geplantAm;
```

Konstruktor: `this.geplantAm,` nach `required this.datum,`. In `einsatzAusStoerung`: `geplantAm: s.geplantAm,` und in `einsatzAusMontage`: `geplantAm: m.geplantAm,` jeweils nach `datum:`. Die anderen Adapter setzen nichts (null).

- [ ] **Step 4:** `flutter test test/einsatz_test.dart test/einsatz_providers_test.dart test/einsaetze_screen_test.dart test/einsatz_zeile_test.dart` — alle grün. `flutter analyze` — 56.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/einsatz.dart test/einsatz_test.dart
git commit -m "feat: Einsatz traegt geplantAm fuer die Aufgaben-Faelligkeit (B6)"
```

---

### Task 2: Der Eintrag und die Regeln

**Files:**
- Create: `lib/core/util/aufgabe.dart`
- Test: `test/aufgabe_test.dart`

Bestehend und wiederverwendet: `Aufgabe {key, titel, dringend, route, manuellErledigbar}`, `eigeneSichtbar(faelligAm, heute)`, `snoozeAktiv(snoozeBis, heute)` in `lib/core/util/aufgaben_regeln.dart`; `planungsText({geplantAm, geplantZeit})` in `lib/core/util/einsatz_faellig.dart`; `TerminVergleich(betriebId:, typ:, datum:)` und `terminDecktVorschlagAb({vorschlagBetriebId, vorschlagTyp, vorschlagDatum, bestehendeTermine})` in `lib/core/util/termin_abgleich.dart`; `Einsatz`, `EinsatzTyp`, `einsatzTypLabel` in `einsatz.dart`; `EinsatzStatus` in `einsatz_lage.dart`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/aufgabe_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';

final heute = DateTime(2026, 9, 15, 10, 30);
final heuteTag = DateTime(2026, 9, 15);

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.stoerung,
  String name = 'Calanda',
  EinsatzStatus status = EinsatzStatus.offen,
  DateTime? datum,
  DateTime? geplantAm,
  String? zeit,
  String? beschreibung = 'Zapfhahn tropft',
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: 'x1',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: datum ?? DateTime(2026, 9, 10),
  geplantAm: geplantAm,
  zeit: zeit,
  beschreibung: beschreibung,
  status: status,
  kennzeichen: EinsatzKennzeichen.keines,
);

AufgabenEintrag eintrag(AufgabenQuelle q, {DateTime? faellig, bool dringend = false}) =>
    AufgabenEintrag(
      quelle: q,
      key: 'k',
      titel: 't',
      faellig: faellig,
      dringend: dringend,
    );

void main() {
  group('einsatzFaelligkeit', () {
    test('geplanter Tag vor Meldedatum', () {
      expect(
        einsatzFaelligkeit(einsatz(datum: DateTime(2026, 9, 10), geplantAm: DateTime(2026, 9, 17))),
        DateTime(2026, 9, 17),
      );
    });
    test('ohne Plan das Meldedatum', () {
      expect(einsatzFaelligkeit(einsatz(datum: DateTime(2026, 9, 10))), DateTime(2026, 9, 10));
    });
  });

  group('jetztFaellig', () {
    test('Detektor und Aenderungsvorschlag immer', () {
      expect(jetztFaellig(eintrag(AufgabenQuelle.detektor), heute), isTrue);
      expect(jetztFaellig(eintrag(AufgabenQuelle.aenderungsVorschlag), heute), isTrue);
    });
    test('eigene: 7 Tage voraus sichtbar, 8 nicht, ohne Datum immer', () {
      expect(jetztFaellig(eintrag(AufgabenQuelle.eigene, faellig: DateTime(2026, 9, 22)), heute), isTrue);
      expect(jetztFaellig(eintrag(AufgabenQuelle.eigene, faellig: DateTime(2026, 9, 23)), heute), isFalse);
      expect(jetztFaellig(eintrag(AufgabenQuelle.eigene), heute), isTrue);
    });
    test('Einsatz, Saison-Vorschlag, Termin: erst heute oder ueberfaellig', () {
      for (final q in [AufgabenQuelle.einsatz, AufgabenQuelle.saisonVorschlag, AufgabenQuelle.termin]) {
        expect(jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 14)), heute), isTrue, reason: '$q gestern');
        expect(jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 15, 23)), heute), isTrue, reason: '$q heute');
        expect(jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 16)), heute), isFalse, reason: '$q morgen');
        expect(jetztFaellig(eintrag(q), heute), isFalse, reason: '$q ohne Datum');
      }
    });
  });

  group('faelligText', () {
    test('ueberfaellig, heute, morgen, Datum, ohne', () {
      expect(faelligText(DateTime(2026, 9, 12), heute), 'überfällig seit 3 Tagen');
      expect(faelligText(DateTime(2026, 9, 14), heute), 'überfällig seit 1 Tag');
      expect(faelligText(DateTime(2026, 9, 15), heute), 'heute');
      expect(faelligText(DateTime(2026, 9, 16), heute), 'morgen');
      expect(faelligText(DateTime(2026, 9, 17), heute), 'Do 17.09.');
      expect(faelligText(null, heute), '');
    });
  });

  group('baueAufgabenListe', () {
    List<AufgabenEintrag> baue({
      List<Aufgabe> detektoren = const [],
      List<Map<String, dynamic>> zeilen = const [],
      List<Einsatz> anstehend = const [],
      List<SaisonVorschlag> vorschlaege = const [],
      List<SaisonTerminEintrag> termine = const [],
      int aenderungsVorschlaege = 0,
    }) => baueAufgabenListe(
      detektoren: detektoren,
      aufgabenZeilen: zeilen,
      anstehend: anstehend,
      saisonVorschlaege: vorschlaege,
      saisonTermine: termine,
      aenderungsVorschlaege: aenderungsVorschlaege,
      heute: heute,
    );

    test('Detektor wird zum Eintrag mit Faelligkeit heute und Route', () {
      final l = baue(detektoren: [
        const Aufgabe(key: 'heineken:2026-08', titel: 'Heineken August', dringend: true, route: '/heineken'),
      ]);
      expect(l.single.quelle, AufgabenQuelle.detektor);
      expect(l.single.faellig, heuteTag);
      expect(l.single.route, '/heineken');
      expect(l.single.dringend, isTrue);
      expect(l.single.snoozebar, isTrue);
      expect(l.single.erledigbar, isFalse, reason: 'nur MWST ist manuell erledigbar');
    });

    test('gesnoozter Detektor fehlt, abgelaufener Snooze nicht', () {
      final det = [const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf')];
      expect(baue(detektoren: det, zeilen: [
        {'typ': 'snooze', 'key': 'mahnlauf', 'snooze_bis': '2026-09-16'},
      ]), isEmpty);
      expect(baue(detektoren: det, zeilen: [
        {'typ': 'snooze', 'key': 'mahnlauf', 'snooze_bis': '2026-09-14'},
      ]), hasLength(1));
    });

    test('eigene Aufgaben: alle offenen, auch kuenftige; erledigte nicht; dringend ab heute', () {
      final l = baue(zeilen: [
        {'typ': 'eigene', 'id': 'a1', 'titel': 'Filter bestellen', 'faellig_am': '2026-10-01', 'erledigt_am': null},
        {'typ': 'eigene', 'id': 'a2', 'titel': 'Anrufen', 'faellig_am': '2026-09-15', 'erledigt_am': null},
        {'typ': 'eigene', 'id': 'a3', 'titel': 'Alt', 'faellig_am': '2026-09-01', 'erledigt_am': '2026-09-02'},
      ]);
      expect(l.map((e) => e.titel), ['Anrufen', 'Filter bestellen']);
      expect(l[0].dringend, isTrue);
      expect(l[0].eigeneId, 'a2');
      expect(l[0].key, 'eigene:a2');
      expect(l[0].erledigbar, isTrue);
      expect(l[1].dringend, isFalse);
    });

    test('gesnoozte eigene Aufgabe fehlt', () {
      expect(baue(zeilen: [
        {'typ': 'eigene', 'id': 'a1', 'titel': 'x', 'faellig_am': null, 'erledigt_am': null},
        {'typ': 'snooze', 'key': 'eigene:a1', 'snooze_bis': '2026-09-20'},
      ]), isEmpty);
    });

    test('Einsatz: Titel, Untertitel mit Planungstext, Faelligkeit aus geplantAm, einplanbar', () {
      final l = baue(anstehend: [
        einsatz(status: EinsatzStatus.geplant, geplantAm: DateTime(2026, 9, 17), zeit: '14:00'),
      ]);
      final e = l.single;
      expect(e.quelle, AufgabenQuelle.einsatz);
      expect(e.titel, 'Störung Calanda');
      expect(e.untertitel, 'Zapfhahn tropft · 17.09. 14:00');
      expect(e.faellig, DateTime(2026, 9, 17));
      expect(e.route, '/stoerungen/x1');
      expect(e.key, 'einsatz:stoerung:x1');
      expect(e.einplanbar, isTrue);
      expect(e.snoozebar, isFalse);
      expect(e.dringend, isFalse);
    });

    test('Stoerung ohne Termin ist dringend; Eigenauftrag nicht einplanbar', () {
      final l = baue(anstehend: [
        einsatz(status: EinsatzStatus.offen),
        einsatz(typ: EinsatzTyp.eigenauftrag, status: EinsatzStatus.inArbeit, beschreibung: null),
      ]);
      expect(l.firstWhere((e) => e.einsatz!.typ == EinsatzTyp.stoerung).dringend, isTrue);
      final ea = l.firstWhere((e) => e.einsatz!.typ == EinsatzTyp.eigenauftrag);
      expect(ea.einplanbar, isFalse);
      expect(ea.untertitel, 'nicht geplant');
    });

    test('Saison-Vorschlag wird von einem bestaetigten Termin (±7 Tage) verdeckt', () {
      final SaisonVorschlag vorschlag = (
        betriebId: 'b9',
        betriebName: 'Piz Piz',
        betriebOrt: 'Lenzerheide',
        typ: 'endreinigung',
        zielDatum: DateTime(2026, 10, 20),
        beschreibung: 'Endreinigung',
      );
      final ohne = baue(vorschlaege: [vorschlag]);
      expect(ohne.single.quelle, AufgabenQuelle.saisonVorschlag);
      expect(ohne.single.titel, 'Endreinigung Piz Piz');
      expect(ohne.single.bestaetigbar, isTrue);
      expect(ohne.single.saison!.anlass, 'saisonende');
      expect(ohne.single.route, '/betriebe/b9');

      final mit = baue(vorschlaege: [vorschlag], termine: [
        (id: 't1', betriebId: 'b9', betriebName: 'Piz Piz', betriebOrt: 'Lenzerheide',
         typ: 'endreinigung', datum: DateTime(2026, 10, 22), titel: 'Endreinigung Piz Piz'),
      ]);
      expect(mit.map((e) => e.quelle), [AufgabenQuelle.termin]);
      expect(mit.single.terminId, 't1');
      expect(mit.single.erledigbar, isTrue);
    });

    test('Aenderungsvorschlaege: ein Eintrag, snoozebar, Route zur Pruefliste', () {
      final l = baue(aenderungsVorschlaege: 4);
      expect(l.single.titel, '4 Änderungsvorschläge prüfen');
      expect(l.single.key, 'vorschlaege');
      expect(l.single.route, '/betriebe/vorschlaege');
      expect(l.single.snoozebar, isTrue);
      expect(baue(aenderungsVorschlaege: 0), isEmpty);
    });

    test('Sortierung: Faelligkeit aufsteigend, ohne Datum zuletzt, am selben Tag dringend und Quelle', () {
      final l = baue(
        detektoren: [const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf')],
        zeilen: [
          {'typ': 'eigene', 'id': 'a1', 'titel': 'Ohne Datum', 'faellig_am': null, 'erledigt_am': null},
          {'typ': 'eigene', 'id': 'a2', 'titel': 'Heute eigene', 'faellig_am': '2026-09-15', 'erledigt_am': null},
        ],
        anstehend: [
          einsatz(name: 'Gestern', datum: DateTime(2026, 9, 14), status: EinsatzStatus.offen),
          einsatz(name: 'Morgen', geplantAm: DateTime(2026, 9, 16), status: EinsatzStatus.geplant),
        ],
      );
      expect(l.map((e) => e.titel), [
        'Störung Gestern',      // 14.09.
        'Heute eigene',         // 15.09., dringend (faellig heute)
        'Mahnlauf',             // 15.09., nicht dringend
        'Störung Morgen',       // 16.09.
        'Ohne Datum',
      ]);
    });
  });
}
```

- [ ] **Step 2:** `flutter test test/aufgabe_test.dart` — FEHLER: `aufgabe.dart` fehlt.

- [ ] **Step 3: Umsetzung** — `lib/core/util/aufgabe.dart`:

```dart
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/core/util/termin_abgleich.dart';

/// Ein Aufgaben-Begriff (B6).
///
/// WARUM: Glocke und Kachel «Aufgaben» hatten zwei Quellen — die Glocke
/// zeigte die fällige Heineken-Rechnung, aber nicht die offene Störung; die
/// Kachel umgekehrt (Befund 4 der App-Analyse 09/2026). Hier steht einmal,
/// was eine Aufgabe ist, wann sie «jetzt fällig» ist und wie die Liste
/// gebaut wird. Reine Funktionen mit Primitiven — testbar ohne Supabase.
library;

/// Woher ein Eintrag kommt. Die Reihenfolge ist die Sortierung innerhalb
/// eines Tages (nach «dringend»).
enum AufgabenQuelle { detektor, eigene, einsatz, saisonVorschlag, aenderungsVorschlag, termin }

/// Berechneter Eröffnungs-/Endreinigungs-Vorschlag aus der Saison-Automatik.
typedef SaisonVorschlag = ({
  String betriebId,
  String betriebName,
  String? betriebOrt,
  String typ, // 'eroeffnungsreinigung' | 'endreinigung'
  DateTime zielDatum,
  String beschreibung,
});

/// Bestätigter Saison-Termin (Tabelle `termine`, offen).
typedef SaisonTerminEintrag = ({
  String id,
  String betriebId,
  String betriebName,
  String? betriebOrt,
  String typ,
  DateTime datum,
  String titel,
});

/// Was «Bestätigen» bei einem Saison-Vorschlag anlegt.
typedef SaisonTerminAnlage = ({
  String betriebId,
  String typ,
  DateTime datum,
  String titel,
  String anlass,
});

/// Ein Eintrag der gemeinsamen Aufgabenliste. Trägt Daten, keine Callbacks —
/// welche Knöpfe eine Zeile zeigt, folgt aus der Quelle.
class AufgabenEintrag {
  final AufgabenQuelle quelle;
  /// Deterministisch, für Snooze und Marker: 'heineken:2026-08',
  /// 'eigene:<uuid>', 'einsatz:stoerung:<routeId>', 'saison:<betriebId>:<typ>',
  /// 'vorschlaege', 'termin:<id>'.
  final String key;
  final String titel;
  final String? untertitel;
  final DateTime? faellig;
  final bool dringend;
  /// «Dorthin»-Ziel; bei Einsätzen die Detailseite.
  final String? route;
  final Einsatz? einsatz;
  final String? eigeneId;
  final String? terminId;
  final SaisonTerminAnlage? saison;
  /// Nur Detektoren: Haken zeigen (heute nur MWST).
  final bool manuellErledigbar;

  const AufgabenEintrag({
    required this.quelle,
    required this.key,
    required this.titel,
    this.untertitel,
    this.faellig,
    this.dringend = false,
    this.route,
    this.einsatz,
    this.eigeneId,
    this.terminId,
    this.saison,
    this.manuellErledigbar = false,
  });

  bool get erledigbar =>
      quelle == AufgabenQuelle.eigene ||
      quelle == AufgabenQuelle.termin ||
      (quelle == AufgabenQuelle.detektor && manuellErledigbar);

  /// Einsätze werden nicht gesnoozt, sondern eingeplant.
  bool get snoozebar =>
      quelle == AufgabenQuelle.detektor ||
      quelle == AufgabenQuelle.eigene ||
      quelle == AufgabenQuelle.aenderungsVorschlag;

  bool get einplanbar =>
      quelle == AufgabenQuelle.einsatz &&
      (einsatz!.typ == EinsatzTyp.stoerung || einsatz!.typ == EinsatzTyp.montage);

  bool get bestaetigbar => quelle == AufgabenQuelle.saisonVorschlag;
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fälligkeit eines Einsatzes: der geplante Tag, sonst das Meldedatum.
DateTime einsatzFaelligkeit(Einsatz e) => e.geplantAm ?? e.datum;

/// Gehört der Eintrag in Glocke, Startkarte, Kachelzähler und Sheet?
/// Detektoren und Änderungsvorschläge immer (Snooze ist schon angewandt);
/// eigene Aufgaben ab Fälligkeit −7 Tage (bestehende Regel); Einsätze,
/// Saison-Vorschläge und Termine erst am Tag selbst oder überfällig —
/// die geplante Montage von Donnerstag steht im Tagesplan, nicht in der
/// Glocke (Daniel 15.09.2026, Schwelle 1).
bool jetztFaellig(AufgabenEintrag a, DateTime heute) => switch (a.quelle) {
  AufgabenQuelle.detektor || AufgabenQuelle.aenderungsVorschlag => true,
  AufgabenQuelle.eigene => eigeneSichtbar(a.faellig, heute),
  AufgabenQuelle.einsatz ||
  AufgabenQuelle.saisonVorschlag ||
  AufgabenQuelle.termin =>
    a.faellig != null && !_tag(a.faellig!).isAfter(_tag(heute)),
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Kurztext für die Zeile: «überfällig seit 3 Tagen», «heute», «morgen»,
/// «Do 17.09.» oder leer.
String faelligText(DateTime? faellig, DateTime heute) {
  if (faellig == null) return '';
  final f = _tag(faellig);
  final h = _tag(heute);
  final tage = h.difference(f).inDays;
  if (tage > 0) return 'überfällig seit $tage ${tage == 1 ? 'Tag' : 'Tagen'}';
  if (tage == 0) return 'heute';
  if (tage == -1) return 'morgen';
  return '${_wochentage[f.weekday - 1]} '
      '${f.day.toString().padLeft(2, '0')}.${f.month.toString().padLeft(2, '0')}.';
}

/// Baut die eine Liste. Sortiert nach Fälligkeit (ohne Datum zuletzt), am
/// selben Tag dringend zuerst, dann Quelle, dann Titel.
List<AufgabenEintrag> baueAufgabenListe({
  required List<Aufgabe> detektoren,
  required List<Map<String, dynamic>> aufgabenZeilen,
  required List<Einsatz> anstehend,
  required List<SaisonVorschlag> saisonVorschlaege,
  required List<SaisonTerminEintrag> saisonTermine,
  required int aenderungsVorschlaege,
  required DateTime heute,
}) {
  final heuteTag = _tag(heute);

  final snoozes = <String, DateTime>{};
  for (final z in aufgabenZeilen.where((z) => z['typ'] == 'snooze')) {
    final bis = DateTime.tryParse(z['snooze_bis'] as String? ?? '');
    if (z['key'] != null && bis != null) snoozes[z['key'] as String] = bis;
  }
  bool gesnoozt(String key) => snoozeAktiv(snoozes[key], heute);

  final liste = <AufgabenEintrag>[];

  // Detektoren sind per Definition jetzt fällig — Fälligkeit heute, damit sie
  // im Screen unter «Heute» stehen und nicht unter «Ohne Datum».
  for (final a in detektoren) {
    if (gesnoozt(a.key)) continue;
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.detektor,
      key: a.key,
      titel: a.titel,
      faellig: heuteTag,
      dringend: a.dringend,
      route: a.route,
      manuellErledigbar: a.manuellErledigbar,
    ));
  }

  if (aenderungsVorschlaege > 0 && !gesnoozt('vorschlaege')) {
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.aenderungsVorschlag,
      key: 'vorschlaege',
      titel: '$aenderungsVorschlaege Änderungsvorschläge prüfen',
      faellig: heuteTag,
      route: '/betriebe/vorschlaege',
    ));
  }

  for (final z in aufgabenZeilen.where((z) => z['typ'] == 'eigene')) {
    if (z['erledigt_am'] != null) continue;
    final id = z['id'] as String;
    final key = 'eigene:$id';
    if (gesnoozt(key)) continue;
    final faellig = DateTime.tryParse(z['faellig_am'] as String? ?? '');
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.eigene,
      key: key,
      titel: (z['titel'] ?? '?') as String,
      faellig: faellig,
      dringend: faellig != null && !_tag(faellig).isAfter(heuteTag),
      eigeneId: id,
    ));
  }

  for (final e in anstehend) {
    final faellig = einsatzFaelligkeit(e);
    final plan = e.typ == EinsatzTyp.stoerung || e.typ == EinsatzTyp.montage
        ? planungsText(geplantAm: e.geplantAm, geplantZeit: e.zeit)
        : null;
    final untertitel = [
      if (e.beschreibung != null && e.beschreibung!.isNotEmpty) e.beschreibung!,
      if (plan != null) plan,
      if (plan == null && e.betriebOrt != null) e.betriebOrt!,
    ].join(' · ');
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.einsatz,
      key: 'einsatz:${e.typ.name}:${e.routeId}',
      titel: '${e.typLabel} ${e.betriebName}',
      untertitel: untertitel.isEmpty ? null : untertitel,
      faellig: faellig,
      // Gemeldet ohne Termin oder überfällig — das ist der Morgen-Fall.
      dringend: e.status == EinsatzStatus.offen || _tag(faellig).isBefore(heuteTag),
      route: e.detailRoute,
      einsatz: e,
    ));
  }

  final bestehende = [
    for (final t in saisonTermine)
      TerminVergleich(betriebId: t.betriebId, typ: t.typ, datum: t.datum),
  ];
  for (final v in saisonVorschlaege) {
    // Ein Vorschlag, den ein bestätigter Termin (±7 Tage) abdeckt, würde
    // sonst doppelt erscheinen — einmal als Vorschlag, einmal als Termin.
    if (terminDecktVorschlagAb(
      vorschlagBetriebId: v.betriebId,
      vorschlagTyp: v.typ,
      vorschlagDatum: v.zielDatum,
      bestehendeTermine: bestehende,
    )) {
      continue;
    }
    final label = v.typ == 'endreinigung' ? 'Endreinigung' : 'Eröffnungsreinigung';
    final titel = '$label ${v.betriebName}'.trim();
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.saisonVorschlag,
      key: 'saison:${v.betriebId}:${v.typ}',
      titel: titel,
      untertitel: v.betriebOrt,
      faellig: v.zielDatum,
      route: '/betriebe/${v.betriebId}',
      saison: (
        betriebId: v.betriebId,
        typ: v.typ,
        datum: v.zielDatum,
        titel: titel,
        anlass: v.typ == 'endreinigung' ? 'saisonende' : 'saisonstart',
      ),
    ));
  }

  for (final t in saisonTermine) {
    final label = t.typ == 'endreinigung' ? 'Endreinigung' : 'Eröffnungsreinigung';
    liste.add(AufgabenEintrag(
      quelle: AufgabenQuelle.termin,
      key: 'termin:${t.id}',
      titel: t.titel.isNotEmpty ? t.titel : '$label ${t.betriebName}',
      untertitel: t.betriebOrt,
      faellig: t.datum,
      dringend: _tag(t.datum).isBefore(heuteTag),
      route: '/betriebe/${t.betriebId}',
      terminId: t.id,
    ));
  }

  liste.sort((a, b) {
    if (a.faellig == null && b.faellig == null) return a.titel.compareTo(b.titel);
    if (a.faellig == null) return 1;
    if (b.faellig == null) return -1;
    final tag = _tag(a.faellig!).compareTo(_tag(b.faellig!));
    if (tag != 0) return tag;
    final d = (b.dringend ? 1 : 0) - (a.dringend ? 1 : 0);
    if (d != 0) return d;
    final q = a.quelle.index.compareTo(b.quelle.index);
    if (q != 0) return q;
    return a.titel.compareTo(b.titel);
  });
  return liste;
}
```

- [ ] **Step 4:** `flutter test test/aufgabe_test.dart` — BESTANDEN, 14 Tests. `flutter analyze` — 56. `dart format` auf beide Dateien. Wenn der Sortiertest die Reihenfolge «Heute eigene» vor «Mahnlauf» nicht liefert: Der Detektor ist nicht dringend, die eigene Aufgabe schon (fällig heute) — dringend sortiert vor Quelle. Der Test ist richtig; die Umsetzung prüfen.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/aufgabe.dart test/aufgabe_test.dart
git commit -m "feat: ein Aufgaben-Eintrag, Faelligkeitsregel und Listenaufbau (B6)"
```

---

### Task 3: Die Provider — eine Quelle

**Files:**
- Create: `lib/presentation/providers/aufgaben_detektoren_provider.dart`
- Modify: `lib/presentation/providers/einsatz_providers.dart`
- Modify: `lib/presentation/providers/aufgaben_providers.dart` (neue Provider **zusätzlich**; der alte `aufgabenProvider` bleibt bis Task 7)
- Test: `test/aufgaben_providers_test.dart`

Vorhandene Provider (geprüft): `stoerungenProvider`, `montagenProvider`, `eigenauftraegeProvider` (`Provider<List<…>>`), `offeneTermineProvider` (`FutureProvider<List<TerminDto>>`), `betriebLookupProvider` (`Provider<Map<String, BetriebLocal>>`, `tour_providers.dart:560`), `autoTermineProvider` (`Provider.family<List<TourEintrag>, DateTime>`, `tour_providers.dart:746`; `TourEintrag` hat `betriebId`, `betriebName`, `betriebOrt`, `zielDatum`, `beschreibung`, `faelligkeit` mit `FaelligkeitsStatus.endreinigungFaellig`/`eroeffnungFaellig` aus `tour_filter.dart`), `offeneVorschlaegeAnzahlProvider` (`Provider<int>`, `betrieb_vorschlag_providers.dart:15`), `saisonAnkerFehltProvider`, `fehlendeBuchungenProvider` (werden von den Detektoren gebraucht, Importe aus dem alten `aufgabenProvider` übernehmen).

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/aufgaben_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  final calanda = BetriebLocal()
    ..serverId = 'b1'
    ..name = 'Calanda'
    ..ort = 'Chur';

  StoerungLocal stoerung(String id, String status, {DateTime? geplantAm}) => StoerungLocal()
    ..serverId = id
    ..userId = 'u'
    ..betriebId = 'b1'
    ..datum = DateTime(2026, 9, 10)
    ..geplantAm = geplantAm
    ..status = status
    ..problemBeschreibung = 'x';

  List<Override> basis({
    List<StoerungLocal> stoerungen = const [],
    List<Aufgabe> detektoren = const [],
    List<Map<String, dynamic>> zeilen = const [],
    List<TerminDto> termine = const [],
    int vorschlaege = 0,
  }) => [
    stoerungenProvider.overrideWithValue(stoerungen),
    montagenProvider.overrideWithValue(const []),
    eigenauftraegeProvider.overrideWithValue(const []),
    offeneTermineProvider.overrideWith((ref) async => termine),
    betriebLookupProvider.overrideWithValue({'b1': calanda}),
    autoTermineProvider.overrideWith((ref, tag) => const []),
    offeneVorschlaegeAnzahlProvider.overrideWithValue(vorschlaege),
    aufgabenDetektorenProvider.overrideWith((ref) async => detektoren),
    aufgabenZeilenProvider.overrideWith((ref) async => zeilen),
  ];

  test('anstehendeEinsaetzeProvider: offen/geplant/inArbeit, erledigte nicht, Saison-Termine nicht', () {
    final container = ProviderContainer(overrides: basis(
      stoerungen: [stoerung('s1', 'offen'), stoerung('s2', 'behoben'), stoerung('s3', 'in_bearbeitung')],
      termine: [
        TerminDto(id: 't1', userId: 'u', betriebId: 'b1', datum: DateTime(2026, 10, 1),
            typ: 'endreinigung', titel: 'Endreinigung', status: 'geplant'),
        TerminDto(id: 't2', userId: 'u', betriebId: 'b1', datum: DateTime(2026, 10, 2),
            typ: 'besuch', titel: 'Besuch', status: 'geplant'),
      ],
    ));
    addTearDown(container.dispose);
    // offeneTermineProvider ist asynchron — einmal auflösen lassen.
    return container.read(offeneTermineProvider.future).then((_) {
      final l = container.read(anstehendeEinsaetzeProvider);
      expect(l.map((e) => e.routeId).toSet(), containsAll(['t2']));
      expect(l.where((e) => e.typ.name == 'stoerung'), hasLength(2));
      expect(l.any((e) => e.routeId == 't1'), isFalse, reason: 'Saison-Termin laeuft als Quelle termin');
    });
  });

  test('aufgabenListeProvider vereinigt Detektor, eigene, Einsatz, Termin und Vorschlaege', () async {
    final container = ProviderContainer(overrides: basis(
      stoerungen: [stoerung('s1', 'offen')],
      detektoren: [const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf', route: '/buchhaltung/mahnwesen')],
      zeilen: [
        {'typ': 'eigene', 'id': 'a1', 'titel': 'Anrufen', 'faellig_am': null, 'erledigt_am': null},
      ],
      termine: [
        TerminDto(id: 't1', userId: 'u', betriebId: 'b1', datum: DateTime(2026, 10, 1),
            typ: 'endreinigung', titel: '', status: 'geplant'),
      ],
      vorschlaege: 2,
    ));
    addTearDown(container.dispose);

    final liste = await container.read(aufgabenListeProvider.future);
    expect(liste.map((e) => e.quelle).toSet(), {
      AufgabenQuelle.detektor,
      AufgabenQuelle.eigene,
      AufgabenQuelle.einsatz,
      AufgabenQuelle.termin,
      AufgabenQuelle.aenderungsVorschlag,
    });
    expect(liste.firstWhere((e) => e.quelle == AufgabenQuelle.termin).titel, 'Endreinigung Calanda',
        reason: 'leerer Termin-Titel wird aus Typ und Betrieb gebildet');
    expect(liste.firstWhere((e) => e.quelle == AufgabenQuelle.einsatz).titel, 'Störung Calanda');
  });

  test('Badge zaehlt nur jetzt Faelliges', () async {
    final container = ProviderContainer(overrides: basis(
      stoerungen: [
        stoerung('s1', 'offen'), // gemeldet 10.09., ohne Termin -> ueberfaellig
        stoerung('s2', 'offen', geplantAm: DateTime.now().add(const Duration(days: 3))),
      ],
      zeilen: [
        {'typ': 'eigene', 'id': 'a1', 'titel': 'In 30 Tagen',
         'faellig_am': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first,
         'erledigt_am': null},
      ],
    ));
    addTearDown(container.dispose);
    await container.read(aufgabenListeProvider.future);
    expect(container.read(aufgabenBadgeProvider), 1);
    expect(container.read(aufgabenJetztProvider).single.titel, 'Störung Calanda');
  });
}
```

`TerminDto`-Konstruktor: `const TerminDto({required id, required userId, required betriebId, required datum, uhrzeitVon, uhrzeitBis, required typ, anlass = 'manuell', required titel, notizen, status = 'geplant'})`.

- [ ] **Step 2:** `flutter test test/aufgaben_providers_test.dart` — FEHLER (Provider fehlen).

- [ ] **Step 3: Detektoren verschieben** — `lib/presentation/providers/aufgaben_detektoren_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Die Zeilen der Tabelle `aufgaben` (eigene, Snoozes, Marker) — eine
/// Abfrage, die Detektoren und die Liste teilen. Nach jeder Aktion
/// invalidieren.
final aufgabenZeilenProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (SupabaseService.currentUser == null) return const [];
  try {
    return await AufgabenRepository.alleZeilen();
  } catch (e) {
    debugPrint('[Aufgaben] Tabelle nicht ladbar: $e');
    return const [];
  }
});

/// Die sechs Detektoren (Heineken-Rechnung, MWST, Mahnlauf, Saisondaten,
/// fehlende Buchungen, Versandvermerk) — unverändert aus dem früheren
/// `aufgabenProvider` (B6). Ohne Snooze: den wendet `baueAufgabenListe` an.
/// Jeder Detektor ist einzeln abgesichert; einer, der fällt, leert nicht die
/// Liste.
final aufgabenDetektorenProvider = FutureProvider<List<Aufgabe>>((ref) async {
  if (SupabaseService.currentUser == null) return const [];
  final heute = DateTime.now();
  final client = SupabaseService.client;
  final zeilen = await ref.watch(aufgabenZeilenProvider.future);
  final marker = zeilen
      .where((z) => z['typ'] == 'marker' && z['key'] != null)
      .map((z) => z['key'] as String)
      .toSet();

  final detektoren = <Aufgabe>[];

  // … hier die Blöcke a) bis f) aus dem alten `aufgabenProvider`
  // (aufgaben_providers.dart, Zeilen 47–150) WÖRTLICH einfügen — vom
  // Kommentar «// a) Heineken» bis einschliesslich dem try/catch von
  // «// f) Versandvermerk». Nichts umformulieren.

  return detektoren;
});
```

Die Blöcke a)–f) per Copy aus der alten Datei übernehmen (nicht neu schreiben). Der alte `aufgabenProvider` bleibt in `aufgaben_providers.dart` vorerst stehen — er liest die Tabelle selbst; das Doppel verschwindet in Task 7.

- [ ] **Step 4: Anstehende Einsätze** — in `lib/presentation/providers/einsatz_providers.dart` ergänzen (Import `einsatz_lage.dart` dazu):

```dart
/// Anstehende Einsätze für die Aufgabenliste (B6): Störungen, Montagen,
/// Eigenaufträge und offene Termine mit Stufe offen/geplant/inArbeit — aus
/// den Speicher-Providern über die B2-Adapter, ohne Jahresgrenze und ohne
/// Buchungsabfrage (für Offenes belanglos). Saison-Termine laufen in der
/// Aufgabenliste als eigene Quelle und fehlen hier; Reinigungen («offen» =
/// Entwurf), Saison-Belege und Pikett sind nie Aufgaben.
final anstehendeEinsaetzeProvider = Provider<List<Einsatz>>((ref) {
  final betriebe = ref.watch(betriebLookupProvider);
  const anstehend = {EinsatzStatus.offen, EinsatzStatus.geplant, EinsatzStatus.inArbeit};
  final termine = ref.watch(offeneTermineProvider).valueOrNull ?? const [];
  return [
    for (final s in ref.watch(stoerungenProvider))
      einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
    for (final m in ref.watch(montagenProvider))
      einsatzAusMontage(m, betrieb: betriebe[m.betriebId]),
    for (final e in ref.watch(eigenauftraegeProvider))
      einsatzAusEigenauftrag(e, betrieb: betriebe[e.betriebId]),
    for (final t in termine)
      if (t.typ != 'eroeffnungsreinigung' && t.typ != 'endreinigung')
        einsatzAusTermin(t, betrieb: betriebe[t.betriebId]),
  ].where((e) => anstehend.contains(e.status)).toList();
});
```

- [ ] **Step 5: Die Liste** — in `lib/presentation/providers/aufgaben_providers.dart` ergänzen (Importe: `aufgabe.dart`, `aufgaben_detektoren_provider.dart`, `einsatz_providers.dart`, `betrieb_vorschlag_providers.dart`, `termin_providers.dart`, `tour_filter.dart` für `FaelligkeitsStatus`):

```dart
/// Die eine Aufgabenliste (B6): Detektoren + eigene Aufgaben + anstehende
/// Einsätze + Saison-Vorschläge + bestätigte Saison-Termine +
/// Änderungsvorschläge, nach Fälligkeit. Glocke, Startkarte, Kachel, Sheet
/// und Screen lesen alle hier.
final aufgabenListeProvider = FutureProvider<List<AufgabenEintrag>>((ref) async {
  if (SupabaseService.currentUser == null) return const [];
  final heute = DateTime.now();
  final heuteTag = DateTime(heute.year, heute.month, heute.day);
  final betriebe = ref.watch(betriebLookupProvider);

  final detektoren = await ref.watch(aufgabenDetektorenProvider.future);
  final zeilen = await ref.watch(aufgabenZeilenProvider.future);
  final termine = await ref.watch(offeneTermineProvider.future);

  final saisonVorschlaege = <SaisonVorschlag>[
    for (final e in ref.watch(autoTermineProvider(heuteTag)))
      if (e.betriebId != null && e.zielDatum != null)
        if (e.faelligkeit == FaelligkeitsStatus.endreinigungFaellig ||
            e.faelligkeit == FaelligkeitsStatus.eroeffnungFaellig)
          (
            betriebId: e.betriebId!,
            betriebName: e.betriebName,
            betriebOrt: e.betriebOrt,
            typ: e.faelligkeit == FaelligkeitsStatus.endreinigungFaellig
                ? 'endreinigung'
                : 'eroeffnungsreinigung',
            zielDatum: e.zielDatum!,
            beschreibung: e.beschreibung,
          ),
  ];

  final saisonTermine = <SaisonTerminEintrag>[
    for (final t in termine)
      if (t.typ == 'eroeffnungsreinigung' || t.typ == 'endreinigung')
        (
          id: t.id,
          betriebId: t.betriebId,
          betriebName: betriebe[t.betriebId]?.name ?? '?',
          betriebOrt: betriebe[t.betriebId]?.ort,
          typ: t.typ,
          datum: t.datum,
          titel: t.titel,
        ),
  ];

  return baueAufgabenListe(
    detektoren: detektoren,
    aufgabenZeilen: zeilen,
    anstehend: ref.watch(anstehendeEinsaetzeProvider),
    saisonVorschlaege: saisonVorschlaege,
    saisonTermine: saisonTermine,
    aenderungsVorschlaege: ref.watch(offeneVorschlaegeAnzahlProvider),
    heute: heute,
  );
});

/// Der Ausschnitt «jetzt fällig» — leer, solange die Liste lädt (Glocke,
/// Karte und Kachel vertragen das; das Sheet zeigt den Ladezustand selbst).
final aufgabenJetztProvider = Provider<List<AufgabenEintrag>>((ref) {
  final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
  final heute = DateTime.now();
  return liste.where((a) => jetztFaellig(a, heute)).toList();
});

/// Glocken-Badge und Kachelzähler — dieselbe Zahl.
final aufgabenBadgeProvider = Provider<int>((ref) => ref.watch(aufgabenJetztProvider).length);
```

Im Test wird `SupabaseService.currentUser` gelesen — ist Supabase im Test nicht initialisiert und wirft der Zugriff, dann `if (SupabaseService.currentUser == null)` in beiden neuen Providern durch einen Helfer ersetzen: `bool _eingeloggt() { try { return SupabaseService.currentUser != null; } catch (_) { return true; } }` mit Kommentar «im Test ohne Supabase gilt: eingeloggt» — und das im Report melden.

- [ ] **Step 6:** `flutter test test/aufgaben_providers_test.dart test/aufgaben_regeln_test.dart` — BESTANDEN (3 + bestehende). `flutter analyze` — 56. `dart format` auf die neue Datei und den Test.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/aufgaben_detektoren_provider.dart lib/presentation/providers/einsatz_providers.dart lib/presentation/providers/aufgaben_providers.dart test/aufgaben_providers_test.dart
git commit -m "feat: aufgabenListeProvider - eine Quelle fuer Glocke, Kachel, Sheet und Screen (B6)"
```

---

### Task 4: Die Zeile

**Files:**
- Create: `lib/presentation/widgets/aufgabe_zeile.dart`
- Test: `test/aufgabe_zeile_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart` (Dateiliste im Test «Listenzeilen ohne CanvasKit-tote Widgets»)

Vorbild: `EinsatzZeile` in `lib/presentation/widgets/einsatz_zeile.dart` (B2); dort auch `einsatzTypIcon(t)`, `einsatzTypFarbe(t)`. Farben: `AppColors.primary/success/warning/error/info/textSecondary`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/aufgabe_zeile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';

final heute = DateTime(2026, 9, 15);

Einsatz stoerung() => Einsatz(
  typ: EinsatzTyp.stoerung,
  typLabel: 'Störung',
  routeId: 's1',
  betriebId: 'b1',
  betriebName: 'Calanda',
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 9, 10),
  status: EinsatzStatus.offen,
  kennzeichen: EinsatzKennzeichen.keines,
);

AufgabenEintrag eintrag({
  AufgabenQuelle quelle = AufgabenQuelle.eigene,
  String titel = 'Filter bestellen',
  String? untertitel,
  DateTime? faellig,
  bool dringend = false,
  bool manuellErledigbar = false,
  Einsatz? einsatz,
}) => AufgabenEintrag(
  quelle: quelle,
  key: 'k',
  titel: titel,
  untertitel: untertitel,
  faellig: faellig,
  dringend: dringend,
  route: '/x',
  einsatz: einsatz,
  eigeneId: quelle == AufgabenQuelle.eigene ? 'a1' : null,
  manuellErledigbar: manuellErledigbar,
);

Widget rahmen(Widget kind) => MaterialApp(home: Scaffold(body: ListView(children: [kind])));

Widget zeile(AufgabenEintrag e, {
  VoidCallback? onDorthin,
  ValueChanged<int>? onSnooze,
  VoidCallback? onErledigt,
  VoidCallback? onEinplanen,
  VoidCallback? onBestaetigen,
}) => AufgabeZeile(
  eintrag: e,
  heute: heute,
  onDorthin: onDorthin ?? () {},
  onSnooze: onSnooze ?? (_) {},
  onErledigt: onErledigt ?? () {},
  onEinplanen: onEinplanen ?? () {},
  onBestaetigen: onBestaetigen ?? () {},
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('eigene Aufgabe: Titel, Faelligkeitstext, Snooze und Erledigt, kein Einplanen', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag(faellig: DateTime(2026, 9, 17)))));
    expect(find.text('Filter bestellen'), findsOneWidget);
    expect(find.textContaining('Do 17.09.'), findsOneWidget);
    expect(find.byTooltip('Später erinnern'), findsOneWidget);
    expect(find.byTooltip('Erledigt'), findsOneWidget);
    expect(find.byTooltip('Einplanen'), findsNothing);
    expect(find.byTooltip('Termin bestätigen'), findsNothing);
  });

  testWidgets('Detektor ohne Haken, mit Dorthin und Snooze', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag(quelle: AufgabenQuelle.detektor, titel: 'Mahnlauf', faellig: heute))));
    expect(find.byTooltip('Erledigt'), findsNothing);
    expect(find.byTooltip('Dorthin'), findsOneWidget);
    expect(find.byTooltip('Später erinnern'), findsOneWidget);
  });

  testWidgets('MWST-Detektor mit Haken', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag(quelle: AufgabenQuelle.detektor, manuellErledigbar: true))));
    expect(find.byTooltip('Erledigt'), findsOneWidget);
  });

  testWidgets('Stoerung: Einplanen, kein Snooze, ueberfaellig-Text', (tester) async {
    await tester.pumpWidget(rahmen(zeile(
      eintrag(quelle: AufgabenQuelle.einsatz, titel: 'Störung Calanda', untertitel: 'Zapfhahn tropft · nicht geplant',
          faellig: DateTime(2026, 9, 12), dringend: true, einsatz: stoerung()),
    )));
    expect(find.byTooltip('Einplanen'), findsOneWidget);
    expect(find.byTooltip('Später erinnern'), findsNothing);
    expect(find.textContaining('überfällig seit 3 Tagen'), findsOneWidget);
  });

  testWidgets('Saison-Vorschlag: Bestaetigen', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag(quelle: AufgabenQuelle.saisonVorschlag, faellig: heute))));
    expect(find.byTooltip('Termin bestätigen'), findsOneWidget);
  });

  testWidgets('Knoepfe rufen die Callbacks', (tester) async {
    var erledigt = false, dorthin = false;
    await tester.pumpWidget(rahmen(zeile(eintrag(), onErledigt: () => erledigt = true, onDorthin: () => dorthin = true)));
    await tester.tap(find.byTooltip('Erledigt'));
    expect(erledigt, isTrue);
    await tester.tap(find.text('Filter bestellen'));
    expect(dorthin, isTrue);
  });

  testWidgets('Snooze-Menue bietet 1/3/7 Tage', (tester) async {
    int? tage;
    await tester.pumpWidget(rahmen(zeile(eintrag(), onSnooze: (t) => tage = t)));
    await tester.tap(find.byTooltip('Später erinnern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Tage'));
    await tester.pumpAndSettle();
    expect(tage, 3);
  });

  testWidgets('360 px, drei Knoepfe, Titel bleibt lesbar', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(rahmen(zeile(
      eintrag(quelle: AufgabenQuelle.einsatz, titel: 'Störung Seerestaurant Schlüssel', faellig: heute, einsatz: stoerung()),
    )));
    expect(tester.takeException(), isNull);
    final absatz = tester.renderObject<RenderParagraph>(find.text('Störung Seerestaurant Schlüssel'));
    expect(absatz.didExceedMaxLines, isFalse);
  });

  testWidgets('kein ListTile, kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag())));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
```

- [ ] **Step 2:** `flutter test test/aufgabe_zeile_test.dart` — FEHLER (Datei fehlt).

- [ ] **Step 3: Umsetzung** — `lib/presentation/widgets/aufgabe_zeile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';

/// Eine Zeile der Aufgabenliste — für Sheet und Screen dieselbe (B6).
///
/// CanvasKit: `InkWell` + `Container` + `Row`, kein `ListTile` (CLAUDE.md).
/// Welche Knöpfe erscheinen, folgt aus der Quelle des Eintrags
/// (`erledigbar`, `snoozebar`, `einplanbar`, `bestaetigbar`).
class AufgabeZeile extends StatelessWidget {
  final AufgabenEintrag eintrag;
  final DateTime heute;
  final VoidCallback onDorthin;
  final ValueChanged<int> onSnooze;
  final VoidCallback onErledigt;
  final VoidCallback onEinplanen;
  final VoidCallback onBestaetigen;

  const AufgabeZeile({
    super.key,
    required this.eintrag,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
    required this.onEinplanen,
    required this.onBestaetigen,
  });

  Widget _icon() {
    final e = eintrag;
    switch (e.quelle) {
      case AufgabenQuelle.einsatz:
        return Icon(einsatzTypIcon(e.einsatz!.typ), size: 20, color: einsatzTypFarbe(e.einsatz!.typ));
      case AufgabenQuelle.saisonVorschlag:
        return const Icon(Icons.cleaning_services_outlined, size: 20, color: AppColors.primary);
      case AufgabenQuelle.termin:
        return const Icon(Icons.cleaning_services, size: 20, color: AppColors.success);
      case AufgabenQuelle.aenderungsVorschlag:
        return const Icon(Icons.fact_check_outlined, size: 20, color: AppColors.info);
      case AufgabenQuelle.detektor:
      case AufgabenQuelle.eigene:
        return Icon(Icons.circle, size: 12, color: e.dringend ? AppColors.error : AppColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = eintrag;
    final zeit = faelligText(e.faellig, heute);
    final untertitel = [
      if (e.untertitel != null && e.untertitel!.isNotEmpty) e.untertitel!,
      if (zeit.isNotEmpty) zeit,
    ].join(' · ');
    final ueberfaellig = zeit.startsWith('überfällig');

    return InkWell(
      onTap: e.route == null ? null : onDorthin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: _icon())),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (untertitel.isNotEmpty)
                    Text(
                      untertitel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ueberfaellig ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (e.route != null && e.quelle != AufgabenQuelle.eigene)
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                tooltip: 'Dorthin',
                visualDensity: VisualDensity.compact,
                onPressed: onDorthin,
              ),
            if (e.einplanbar)
              IconButton(
                icon: const Icon(Icons.event_outlined, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Einplanen',
                visualDensity: VisualDensity.compact,
                onPressed: onEinplanen,
              ),
            if (e.bestaetigbar)
              IconButton(
                icon: const Icon(Icons.event_available_outlined, size: 20),
                color: AppColors.primary,
                tooltip: 'Termin bestätigen',
                visualDensity: VisualDensity.compact,
                onPressed: onBestaetigen,
              ),
            if (e.snoozebar)
              PopupMenuButton<int>(
                icon: const Icon(Icons.snooze, size: 18),
                tooltip: 'Später erinnern',
                onSelected: onSnooze,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('1 Tag')),
                  PopupMenuItem(value: 3, child: Text('3 Tage')),
                  PopupMenuItem(value: 7, child: Text('7 Tage')),
                ],
              ),
            if (e.erledigbar)
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
                tooltip: 'Erledigt',
                visualDensity: VisualDensity.compact,
                onPressed: onErledigt,
              ),
          ],
        ),
      ),
    );
  }
}
```

Hinweis zum Test «eigene Aufgabe … kein Einplanen»: Der Testeintrag hat `route: '/x'`, aber bei `quelle == eigene` zeigt die Zeile keinen Dorthin-Knopf (eigene Aufgaben haben kein Ziel; der Tipp auf die Zeile bleibt `onDorthin`, damit der Test «Knoepfe rufen die Callbacks» den Tipp auf den Titel prüfen kann). Der Detektor-Test erwartet den Dorthin-Knopf.

- [ ] **Step 4:** `flutter test test/aufgabe_zeile_test.dart` — BESTANDEN, 9 Tests. Läuft die 360-px-Zeile über: `visualDensity: VisualDensity.compact` ist gesetzt; zusätzlich `padding: EdgeInsets.zero` und `constraints: const BoxConstraints(minWidth: 36, minHeight: 36)` auf die `IconButton`s — nicht die Schrift verkleinern.

- [ ] **Step 5: Wächter erweitern** — in `test/canvaskit_sichere_widgets_test.dart` die Dateiliste des Tests «Listenzeilen ohne CanvasKit-tote Widgets» um `'lib/presentation/widgets/aufgabe_zeile.dart'` ergänzen (nur diese; `aufgaben_sheet.dart` kommt in Task 7, wenn sein `ListTile` weg ist). `flutter test test/canvaskit_sichere_widgets_test.dart` — BESTANDEN.

- [ ] **Step 6:** `flutter analyze` — 56. `dart format` auf Zeile und Test. Commit:

```bash
git add lib/presentation/widgets/aufgabe_zeile.dart test/aufgabe_zeile_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: AufgabeZeile - eine Zeile fuer Sheet und Screen, CanvasKit-sicher (B6)"
```

---

### Task 5: Die Aktionen

**Files:**
- Create: `lib/presentation/widgets/aufgaben_aktionen.dart`

Kein eigener Unit-Test: Alle Methoden sprechen mit Supabase bzw. dem Tagesplan. Geprüft wird über `flutter analyze` und die Sichtprüfung (Task 9). Der Einplanen-Ablauf ist **bestehender Code** aus `lib/presentation/screens/aufgaben/aufgaben_screen.dart` (Störung Zeilen 127–193, Montage 195–260) — kopieren, nicht neu schreiben; die Kommentare zum Geisterblock (02.08.2026) mitnehmen. Der Screen selbst wird erst in Task 6 umgebaut — bis dahin gibt es die Logik doppelt.

- [ ] **Step 1: Datei anlegen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einplanen_sheet.dart';

/// Die Aktionen der Aufgabenliste — Sheet und Screen rufen dieselben (B6).
/// Jede Aktion endet mit dem Invalidieren der Tabelle und der Liste; Fehler
/// landen als SnackBar, nie als stiller Abbruch.
class AufgabenAktionen {
  final WidgetRef ref;
  const AufgabenAktionen(this.ref);

  void _neuLaden() {
    ref.invalidate(aufgabenZeilenProvider);
    ref.invalidate(aufgabenListeProvider);
  }

  Future<void> _sicher(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      _neuLaden();
    }
  }

  /// «Dorthin». Im Sheet erst das Sheet schliessen — der Router-Push aus
  /// dem Sheet-Kontext heraus landete sonst unter dem Sheet.
  void dorthin(BuildContext context, AufgabenEintrag a, {bool imSheet = false}) {
    final route = a.route;
    if (route == null) return;
    if (imSheet) Navigator.pop(context);
    router.push(route);
  }

  Future<void> snooze(BuildContext context, AufgabenEintrag a, int tage) =>
      _sicher(context, () => AufgabenRepository.snooze(a.key, tage));

  Future<void> erledigt(BuildContext context, AufgabenEintrag a) => _sicher(context, () async {
    switch (a.quelle) {
      case AufgabenQuelle.eigene:
        await AufgabenRepository.eigeneErledigen(a.eigeneId!);
      case AufgabenQuelle.termin:
        await TerminRepository.erledigen(a.terminId!);
        ref.invalidate(offeneTermineProvider);
      case AufgabenQuelle.detektor:
        await AufgabenRepository.markerSetzen(a.key);
      default:
        return;
    }
  });

  Future<void> bestaetigen(BuildContext context, AufgabenEintrag a) => _sicher(context, () async {
    final s = a.saison;
    if (s == null) return;
    await TerminRepository.anlegen(
      betriebId: s.betriebId,
      typ: s.typ,
      datum: s.datum,
      titel: s.titel,
      anlass: s.anlass,
    );
    ref.invalidate(offeneTermineProvider);
  });

  /// Einplanen einer Störung oder Montage — der Ablauf aus dem früheren
  /// Aufgaben-Screen, unverändert. Das Rohmodell wird über die `routeId`
  /// nachgeschlagen, weil der Eintrag nur die Einsatz-Sicht trägt.
  Future<void> einplanen(BuildContext context, AufgabenEintrag a) async {
    final e = a.einsatz;
    if (e == null) return;
    final lookup = ref.read(betriebLookupProvider);
    if (e.typ == EinsatzTyp.stoerung) {
      final s = ref.read(stoerungenProvider).where((x) => x.routeId == e.routeId).firstOrNull;
      if (s == null) return;
      final betrieb = s.betriebId != null ? lookup[s.betriebId!] : null;
      // … hier den Rumpf von `onEinplanen` der Störung aus aufgaben_screen.dart
      // (ab `final titel = betrieb?.name ?? '?';` bis zum Ende des
      // `einsatzUmplanen(...)`-Aufrufs) WÖRTLICH einfügen; `ref.invalidate(stoerungenStreamProvider)`
      // bleibt darin. Danach: _neuLaden();
    } else if (e.typ == EinsatzTyp.montage) {
      final m = ref.read(montagenProvider).where((x) => x.routeId == e.routeId).firstOrNull;
      if (m == null) return;
      final betrieb = m.betriebId != null ? lookup[m.betriebId!] : null;
      // … analog den Rumpf von `onEinplanen` der Montage einfügen
      // (mit dem `heigenie_service`-Zweig für den TourEintragTyp). Danach: _neuLaden();
    }
  }
}

/// Dialog «Neue Aufgabe» — für Sheet und Screen derselbe. `TextButton`
/// statt `FilledButton` (CanvasKit-Regel).
Future<void> neueAufgabeDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  DateTime? faellig;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Neue Aufgabe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    faellig == null ? 'Kein Datum' : DateFormat('dd.MM.yyyy').format(faellig!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final gewaehlt = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (gewaehlt != null) setState(() => faellig = gewaehlt);
                  },
                  child: const Text('Datum wählen'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Anlegen')),
        ],
      ),
    ),
  );
  if (ok != true || controller.text.trim().isEmpty) return;
  await AufgabenRepository.eigeneAnlegen(controller.text.trim(), faellig);
  ref.invalidate(aufgabenZeilenProvider);
  ref.invalidate(aufgabenListeProvider);
}
```

Die beiden «WÖRTLICH einfügen»-Stellen sind die einzigen, die nicht ausgeschrieben sind — der Code steht in `aufgaben_screen.dart` Zeilen 141–192 (Störung) und 209–259 (Montage), jeweils der Rumpf des `onEinplanen: () async { … }`. Die lokalen Namen (`s`, `m`, `betrieb`, `ergebnis`, `altesDatum`) passen unverändert. `firstOrNull` braucht `package:collection` oder Dart ≥ 3.0 (`Iterable.firstOrNull` aus `dart:core` seit 3.0 — im Projekt vorhanden; sonst `import 'package:collection/collection.dart'`).

- [ ] **Step 2:** `flutter analyze` — 56 (die Datei wird noch von niemandem genutzt; unbenutzte Importe vermeiden). `dart format`.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/aufgaben_aktionen.dart
git commit -m "feat: AufgabenAktionen - dorthin, snooze, erledigt, einplanen, bestaetigen an einer Stelle (B6)"
```

---

### Task 6: Der Screen

**Files:**
- Replace: `lib/presentation/screens/aufgaben/aufgaben_screen.dart`
- Test: `test/aufgaben_inhalt_test.dart`

`offeneEigeneAufgabenProvider` wird von `home_screen.dart:102` noch gebraucht — es bleibt **in dieser Aufgabe** am Ende der Datei stehen und fällt in Task 7.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/aufgaben_inhalt_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/screens/aufgaben/aufgaben_screen.dart';

final heute = DateTime(2026, 9, 15, 9);

AufgabenEintrag e(String titel, DateTime? faellig, {AufgabenQuelle quelle = AufgabenQuelle.eigene}) =>
    AufgabenEintrag(quelle: quelle, key: titel, titel: titel, faellig: faellig, eigeneId: 'x');

Widget rahmen(List<AufgabenEintrag> liste, {ValueChanged<AufgabenEintrag>? onErledigt, VoidCallback? onNeu}) =>
    MaterialApp(
      home: AufgabenInhalt(
        eintraege: liste,
        heute: heute,
        onDorthin: (_) {},
        onSnooze: (_, __) {},
        onErledigt: onErledigt ?? (_) {},
        onEinplanen: (_) {},
        onBestaetigen: (_) {},
        onNeu: onNeu ?? () {},
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Die Gruppenueberschrift «Fr, 18.09.2026» kommt aus DateFormat('de_CH');
    // ohne Locale-Daten wirft das im Test (main.dart laedt sie beim Start).
    await initializeDateFormatting('de_CH');
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Gruppen Ueberfaellig, Heute, Morgen, Datum, Ohne Datum in dieser Reihenfolge', (tester) async {
    await tester.pumpWidget(rahmen([
      e('Alt', DateTime(2026, 9, 12)),
      e('Jetzt', DateTime(2026, 9, 15)),
      e('Bald', DateTime(2026, 9, 16)),
      e('Spaeter', DateTime(2026, 9, 18)),
      e('Irgendwann', null),
    ]));
    for (final g in ['Überfällig', 'Heute', 'Morgen', 'Ohne Datum']) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    expect(find.textContaining('18.09.2026'), findsOneWidget);
    final y = <String, double>{
      for (final t in ['Überfällig', 'Heute', 'Morgen', 'Ohne Datum'])
        t: tester.getTopLeft(find.text(t)).dy,
    };
    expect(y['Überfällig']! < y['Heute']! && y['Heute']! < y['Morgen']! && y['Morgen']! < y['Ohne Datum']!, isTrue);
  });

  testWidgets('Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(const []));
    expect(find.text('Keine anstehenden Aufgaben.'), findsOneWidget);
  });

  testWidgets('Erledigt meldet den Eintrag', (tester) async {
    AufgabenEintrag? erledigt;
    await tester.pumpWidget(rahmen([e('Anrufen', heute)], onErledigt: (a) => erledigt = a));
    await tester.tap(find.byTooltip('Erledigt'));
    expect(erledigt?.titel, 'Anrufen');
  });

  testWidgets('Plus meldet Neu', (tester) async {
    var neu = false;
    await tester.pumpWidget(rahmen(const [], onNeu: () => neu = true));
    await tester.tap(find.byKey(const Key('aufgabe_neu')));
    expect(neu, isTrue);
  });
}
```

- [ ] **Step 2:** `flutter test test/aufgaben_inhalt_test.dart` — FEHLER (`AufgabenInhalt` fehlt).

- [ ] **Step 3: Screen ersetzen** — `lib/presentation/screens/aufgaben/aufgaben_screen.dart` vollständig neu (den Block `offeneEigeneAufgabenProvider` mit seinem Kommentar aus der alten Datei ans Ende übernehmen, sonst nichts):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';

/// Aufgaben-Screen (B6): die eine Aufgabenliste, vollständig — auch das,
/// was erst nächste Woche ansteht. Der Aufbau der Liste liegt in
/// `aufgabenListeProvider`; hier nur Darstellung und Aktionen.
class AufgabenInhalt extends StatelessWidget {
  final List<AufgabenEintrag> eintraege;
  final DateTime heute;
  final ValueChanged<AufgabenEintrag> onDorthin;
  final void Function(AufgabenEintrag, int tage) onSnooze;
  final ValueChanged<AufgabenEintrag> onErledigt;
  final ValueChanged<AufgabenEintrag> onEinplanen;
  final ValueChanged<AufgabenEintrag> onBestaetigen;
  final VoidCallback onNeu;

  const AufgabenInhalt({
    super.key,
    required this.eintraege,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
    required this.onEinplanen,
    required this.onBestaetigen,
    required this.onNeu,
  });

  String _gruppe(DateTime? d, DateTime heuteTag) {
    if (d == null) return 'Ohne Datum';
    final tag = DateTime(d.year, d.month, d.day);
    if (tag.isBefore(heuteTag)) return 'Überfällig';
    if (tag == heuteTag) return 'Heute';
    if (tag == heuteTag.add(const Duration(days: 1))) return 'Morgen';
    return DateFormat('EE, dd.MM.yyyy', 'de_CH').format(tag);
  }

  @override
  Widget build(BuildContext context) {
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final kinder = <Widget>[];
    String? letzte;
    for (final a in eintraege) {
      final g = _gruppe(a.faellig, heuteTag);
      if (g != letzte) {
        letzte = g;
        kinder.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            g,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: g == 'Überfällig' ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ));
      }
      kinder.add(AufgabeZeile(
        eintrag: a,
        heute: heute,
        onDorthin: () => onDorthin(a),
        onSnooze: (t) => onSnooze(a, t),
        onErledigt: () => onErledigt(a),
        onEinplanen: () => onEinplanen(a),
        onBestaetigen: () => onBestaetigen(a),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: eintraege.isEmpty
          ? const Center(
              child: Text('Keine anstehenden Aufgaben.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 88), children: kinder),
      floatingActionButton: FloatingActionButton(
        key: const Key('aufgabe_neu'),
        onPressed: onNeu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AufgabenScreen extends ConsumerWidget {
  const AufgabenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(aufgabenListeProvider);
    final aktionen = AufgabenAktionen(ref);
    return liste.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Aufgaben')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Aufgaben')),
        body: Center(child: Text('Aufgaben konnten nicht geladen werden: $e')),
      ),
      data: (eintraege) => AufgabenInhalt(
        eintraege: eintraege,
        heute: DateTime.now(),
        onDorthin: (a) => aktionen.dorthin(context, a),
        onSnooze: (a, t) => aktionen.snooze(context, a, t),
        onErledigt: (a) => aktionen.erledigt(context, a),
        onEinplanen: (a) => aktionen.einplanen(context, a),
        onBestaetigen: (a) => aktionen.bestaetigen(context, a),
        onNeu: () => neueAufgabeDialog(context, ref),
      ),
    );
  }
}

// --- bis Task 7 (B6): wird noch von home_screen.dart gebraucht ---
// [hier den unveränderten Block `offeneEigeneAufgabenProvider` samt
//  Kommentar aus der alten Datei einfügen, Zeilen 19–44]
```

`DateFormat('EE, dd.MM.yyyy', 'de_CH')` braucht initialisierte Locale-Daten — der Test lädt sie in `setUpAll` (`main.dart` tut das beim App-Start).

- [ ] **Step 4:** `flutter test test/aufgaben_inhalt_test.dart` — BESTANDEN, 4 Tests. `flutter analyze` — 56 oder weniger (unbenutzte Importe im alten Screen sind weg). `dart format`.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/aufgaben/aufgaben_screen.dart test/aufgaben_inhalt_test.dart
git commit -m "feat: Aufgaben-Screen liest die eine Liste, Aufbau raus aus dem Widget (B6)"
```

---

### Task 7: Sheet, Glocke, Startseite, MWST — und die alten Provider weg

**Files:**
- Replace: `lib/presentation/widgets/aufgaben_sheet.dart`
- Modify: `lib/presentation/widgets/aufgaben_glocke.dart:17`
- Modify: `lib/presentation/screens/home_screen.dart` (Zeilen 100–107 Zähler, 186–187 Kachel, 487–503 Startkarte, Importe)
- Modify: `lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart:100,124`
- Modify: `lib/presentation/providers/aufgaben_providers.dart` (alter `aufgabenProvider`, `AufgabenStand`, `EigeneAufgabe` weg)
- Modify: `lib/presentation/screens/aufgaben/aufgaben_screen.dart` (`offeneEigeneAufgabenProvider` weg)
- Test: `test/aufgaben_eine_quelle_waechter_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart` (`aufgaben_sheet.dart` in die Liste)

- [ ] **Step 1: Wächter schreiben** — `test/aufgaben_eine_quelle_waechter_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B6: Fünf Oberflächen, eine Quelle. Glocke, Startkarte, Kachel, Sheet und
/// Screen lesen `aufgabenListeProvider`/`aufgabenJetztProvider`/
/// `aufgabenBadgeProvider` — und rechnen nichts selbst aus den Einsatz-
/// Providern zusammen. Vorher zeigte die Kachel andere Zahlen als die Glocke
/// (Befund 4 der App-Analyse 09/2026). Kommentare werden ausgeblendet.
void main() {
  const dateien = [
    'lib/presentation/widgets/aufgaben_glocke.dart',
    'lib/presentation/widgets/aufgaben_sheet.dart',
    'lib/presentation/screens/aufgaben/aufgaben_screen.dart',
    'lib/presentation/screens/home_screen.dart',
  ];
  const verboten = [
    'offeneEigeneAufgabenProvider',
    'AufgabenStand',
    'stoerungOffen(',
    'montageOffen(',
    'aufgabenProvider)',
    'aufgabenProvider.',
  ];
  final erlaubt = RegExp(r'aufgaben(Liste|Jetzt|Badge)Provider');

  for (final pfad in dateien) {
    test('$pfad liest die eine Aufgabenliste', () {
      final code = File(pfad)
          .readAsLinesSync()
          .map((z) {
            final k = z.indexOf('//');
            return k == -1 ? z : z.substring(0, k);
          })
          .join('\n');
      for (final v in verboten) {
        expect(code.contains(v), isFalse, reason: '$pfad enthaelt noch "$v"');
      }
      expect(erlaubt.hasMatch(code), isTrue, reason: '$pfad liest keinen der neuen Provider');
    });
  }
}
```

- [ ] **Step 2:** `flutter test test/aufgaben_eine_quelle_waechter_test.dart` — FEHLER (alle vier Dateien).

- [ ] **Step 3: Sheet ersetzen** — `lib/presentation/widgets/aufgaben_sheet.dart` vollständig:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';

bool _sheetOffen = false;

/// Öffnet das Aufgaben-Sheet (von Dashboard-Karte und Glocke genutzt).
/// Re-Entry-Guard: die Glocke liegt als Stack-Sibling über dem
/// Navigator-Overlay und bleibt bei offenem Sheet tippbar — ohne Guard
/// würde ein erneuter Tap ein zweites Sheet stapeln.
void zeigeAufgabenSheet(BuildContext context) {
  if (_sheetOffen) return;
  _sheetOffen = true;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AufgabenSheet(),
  ).whenComplete(() => _sheetOffen = false);
}

/// Das Sheet zeigt den Ausschnitt «jetzt fällig» der einen Liste (B6) —
/// dieselben Zeilen und Aktionen wie der Screen.
class _AufgabenSheet extends ConsumerWidget {
  const _AufgabenSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(aufgabenListeProvider);
    final heute = DateTime.now();
    final aktionen = AufgabenAktionen(ref);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: liste.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Fehler: $e')),
          data: (alle) {
            final jetzt = alle.where((a) => jetztFaellig(a, heute)).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('Aufgaben', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Aufgabe'),
                      onPressed: () => neueAufgabeDialog(context, ref),
                    ),
                    TextButton(
                      key: const Key('aufgaben_alle'),
                      onPressed: () {
                        Navigator.pop(context);
                        router.push('/aufgaben');
                      },
                      child: Text(alle.length > jetzt.length ? 'Alle (${alle.length})' : 'Alle'),
                    ),
                  ],
                ),
                if (jetzt.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Text('Alles erledigt 🎉')),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in jetzt)
                        AufgabeZeile(
                          eintrag: a,
                          heute: heute,
                          onDorthin: () => aktionen.dorthin(context, a, imSheet: true),
                          onSnooze: (t) => aktionen.snooze(context, a, t),
                          onErledigt: () => aktionen.erledigt(context, a),
                          onEinplanen: () => aktionen.einplanen(context, a),
                          onBestaetigen: () => aktionen.bestaetigen(context, a),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Glocke** — `aufgaben_glocke.dart:17`: `final badge = ref.watch(aufgabenBadgeProvider);`

- [ ] **Step 5: Startseite** — in `home_screen.dart`:
  - Zeilen 100–107 (`// Aufgaben-Zähler …` bis `.length;`) ersetzen durch `final aufgabenCount = ref.watch(aufgabenBadgeProvider);` mit Kommentar `// Kachelzähler = Glocken-Badge — dieselbe Quelle (B6).`
  - `_AufgabenKarte` (ab Zeile 487): `final stand = …` ersetzen durch

```dart
    final jetzt = ref.watch(aufgabenJetztProvider);
    if (jetzt.isEmpty) return const SizedBox.shrink();
    final titel = jetzt.map((a) => a.titel).take(3).toList();
    final dringend = jetzt.any((a) => a.dringend);
    final label = jetzt.length == 1 ? '1 Aufgabe offen' : '${jetzt.length} Aufgaben offen';
```

  (der Rest der Karte bleibt). Importe: `aufgaben_screen.dart` entfernen, falls nur wegen `offeneEigeneAufgabenProvider` importiert (prüfen: `grep -n "AufgabenScreen\|offeneEigene" lib/presentation/screens/home_screen.dart`); `stoerung_providers.dart`/`montage_providers.dart` nur entfernen, wenn `flutter analyze` sie als unbenutzt meldet.

- [ ] **Step 6: MWST-Screen** — `mwst_abrechnung_screen.dart` Zeilen 95–130 lesen. Zeile 100 `ref.watch(aufgabenProvider).valueOrNull` liest den Stand, um zu prüfen, ob die MWST-Aufgabe eines Quartals offen ist (Schlüssel `mwst:<jahr>-Q<n>`); Zeile 124 invalidiert nach `markerSetzen`. Ersetzen: `final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];` und die bisherige Prüfung `stand.offene.any((a) => a.key == …)` durch `liste.any((a) => a.key == …)`; Zeile 124: `ref.invalidate(aufgabenZeilenProvider); ref.invalidate(aufgabenListeProvider);`. Import `aufgaben_detektoren_provider.dart` dazu. Verhalten unverändert — wenn die Stelle etwas anderes tut als beschrieben, im Report melden und die Absicht erhalten.

- [ ] **Step 7: Alte Provider löschen** — in `aufgaben_providers.dart` alles bis auf die drei neuen Provider (und ihre Importe) entfernen: `EigeneAufgabe`, `AufgabenStand`, `aufgabenProvider`. In `aufgaben_screen.dart` den Block `offeneEigeneAufgabenProvider` am Ende entfernen. `grep -rn "aufgabenProvider\b\|offeneEigeneAufgabenProvider\|AufgabenStand" lib/ test/` — keine Treffer mehr (ausser den neuen Namen mit Präfix).

- [ ] **Step 8: CanvasKit-Wächter** — `'lib/presentation/widgets/aufgaben_sheet.dart'` in die Dateiliste in `test/canvaskit_sichere_widgets_test.dart`.

- [ ] **Step 9:** `flutter test test/aufgaben_eine_quelle_waechter_test.dart test/canvaskit_sichere_widgets_test.dart test/kachel_zaehler_test.dart test/kachel_text_test.dart test/heute_liste_test.dart` — BESTANDEN. Dann `flutter test` komplett — grün. `flutter analyze` — ≤ 56, Zahl melden. `dart format` auf Sheet.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/widgets/aufgaben_sheet.dart lib/presentation/widgets/aufgaben_glocke.dart lib/presentation/screens/home_screen.dart lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart lib/presentation/providers/aufgaben_providers.dart lib/presentation/screens/aufgaben/aufgaben_screen.dart test/aufgaben_eine_quelle_waechter_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: Glocke, Startkarte, Kachel und Sheet lesen die eine Aufgabenliste (B6)"
```

---

### Task 8: Die sechs alten Listen entfernen

**Files:**
- Delete: `lib/presentation/screens/reinigungen/reinigungen_list_screen.dart`, `lib/presentation/screens/stoerungen/stoerungen_list_screen.dart`, `lib/presentation/screens/montagen/montagen_list_screen.dart`, `lib/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart`, `lib/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_list_screen.dart`, `lib/presentation/screens/pikett/pikett_dienste_list_screen.dart`
- Modify: `lib/core/config/router.dart` (Importe Zeilen 16, 20, 30, 33, 36, 39; Routenblöcke bei `path: '/reinigungen',` 279, `/stoerungen` 314, `/montagen` 342, `/pikett` 370, `/eigenauftraege` 394, `/eroeffnungsreinigungen` 425 — je der 4-zeilige `GoRoute(path, builder)`-Block, **nicht** die `/…/neu`- und `/…/:id`-Routen daneben)
- Modify: `test/status_vergleiche_ratsche_test.dart` (`erlaubt` 23 → 20)

Geprüft 15.09.2026: nichts anderes verlinkt (`push('/reinigungen')` o. ä.) oder importiert die sechs Dateien, kein Test rendert sie. Die Kacheln zeigen seit v0.105.0 auf `/einsaetze`.

- [ ] **Step 1: Wächter vorab prüfen** — `alte_listen_ablauf_test.dart` schlägt erst ab v0.106.0 an. Um die Arbeit jetzt zu prüfen, den Test einmal mit `kAppVersion`-unabhängiger Sicht laufen lassen: in `test/alte_listen_ablauf_test.dart` **nichts ändern**; stattdessen nach dem Löschen `grep -c "path: '/reinigungen',\|path: '/stoerungen',\|path: '/montagen',\|path: '/pikett',\|path: '/eigenauftraege',\|path: '/eroeffnungsreinigungen'," lib/core/config/router.dart` — muss `0` liefern.

- [ ] **Step 2: Löschen und Router bereinigen** — `git rm` der sechs Dateien; in `router.dart` die sechs Importe und die sechs Listen-Routenblöcke entfernen. Zeilennummern vorher mit `grep -n` bestätigen (sie verschieben sich beim Löschen).

- [ ] **Step 3: Ratsche senken** — `const erlaubt = 23;` → `20` und den Kommentar ergänzen: `// 15.09.2026: 23 -> 20, drei Vergleiche lagen in den alten Listen (B6).` Run `flutter test test/status_vergleiche_ratsche_test.dart` — BESTANDEN mit genau 20 (meldet der Test weniger, den kleineren Wert eintragen).

- [ ] **Step 4:** `flutter analyze` — Zahl melden (unbenutzte Importe in den gelöschten Dateien sind weg; es dürfen keine Fehler entstehen). `flutter test test/alte_listen_ablauf_test.dart test/einsatz_typ_query_test.dart test/status_vergleiche_ratsche_test.dart test/web_404_weiche_test.dart` — grün.

- [ ] **Step 5: Commit**

```bash
git add -A lib/presentation/screens lib/core/config/router.dart test/status_vergleiche_ratsche_test.dart
git commit -m "chore: sechs alte Listen-Screens entfernt - /einsaetze ist seit v0.105.0 der Weg (B2-Zyklus)"
```

---

### Task 9: Sichtprüfung, Version, Auslieferung, Doku

Koordinator.

- [ ] **Step 1:** `flutter analyze && flutter test` — alles grün; Zahlen notieren.

- [ ] **Step 2: Sichtprüfung** — Wegwerf-Datei `lib/heute_probe.dart` rendert `AufgabenInhalt` mit Einträgen aller sechs Quellen (dringend/nicht, überfällig/heute/morgen/ohne Datum) auf 360 und 1400 px; dazu das Sheet mit denselben Daten (`AufgabeZeile`-Liste in einem `showModalBottomSheet`). Prüfen: Knöpfe je Quelle, Fälligkeitstext rot bei überfällig, Gruppen, «Alle (N)». Danach löschen, nie committen.

- [ ] **Step 3: Version und Deploy** — `pubspec.yaml` Zeile 4 `0.106.0+749`, `kAppVersion` `'0.106.0'`; `flutter test test/app_version_test.dart test/alte_listen_ablauf_test.dart` (der Ablauf-Wächter ist jetzt scharf und muss grün sein). Build, Cache-Bust, Service Worker löschen, `404.html`, `gh-pages`, Live-`version.json` prüfen — nach CLAUDE.md.

- [ ] **Step 4: Doku** — `ToDo.md` (B6 erledigt, Ratsche 20, alte Listen weg, Klicktest Daniel: Glocke zeigt Störung von gestern und MWST in einer Liste; Kachelzähler = Badge; Einplanen aus dem Sheet; alte Routen 404 → Startseite), `docs/app-analyse-2026-09.md` (B6 ✅ mit Schwelle 1), Memory `app_analyse_2026_09.md`.

---

## Nach der Auslieferung

- [ ] Klicktest Daniel (Task 9, Schritt 4).
- [ ] Prüfpunkt aus der Heineken-Rückmeldung (ToDo.md): «verrechnet» bei Barzahler-/Jahresrechnungs-Reinigungen per SQL gegen `buchungen.beleg_id` je `zahlungsart`.
