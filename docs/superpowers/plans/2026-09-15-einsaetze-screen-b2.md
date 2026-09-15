# Ein Einsätze-Screen für alle Typen (B2) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Ein Screen `/einsaetze` zeigt Reinigungen, Störungen, Montagen, Eigenaufträge, Saison-Belege, Termine und Pikett in einer Liste mit **einem** abgeleiteten Status — ohne Datenbankänderung.

**Architektur:** Der Status ist eine reine Funktion je Typ aus vorhandenen Feldern (`core/util/einsatz_status.dart`). Eine Sicht `Einsatz` übersetzt jedes lokale Modell in dieselbe Form (`core/util/einsatz.dart`). Ein Provider vereinigt die vorhandenen Quellen zu `List<Einsatz>`; der Screen filtert und zeigt, die Detailseiten bleiben. Eine neue Abfrage liefert je Jahr die Beleg-Ids mit Ertragsbuchung — daraus folgt «verrechnet» für Reinigungen. Zwei Wächter halten den Zustand: eine Ratsche über die verstreuten Statusvergleiche und ein Ablaufdatum für die sechs alten Listen.

**Tech-Stack:** Flutter · Riverpod · GoRouter · Supabase · `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-15-einsaetze-screen-b2-design.md`

**Modellwahl je Aufgabe:** 1, 2, 3, 7, 8 sind mechanisch (Sonnet). 4, 5, 6 brauchen Zusammenspiel mehrerer Dateien (Sonnet, Review bei Opus/Fable). 9 macht der Koordinator selbst.

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/core/util/einsatz_status.dart` | Enums `EinsatzStatus`, `EinsatzKennzeichen`; sieben Ableitungsfunktionen | **Neu** |
| `lib/core/util/einsatz.dart` | Sicht `Einsatz`, `EinsatzTyp`, sieben `einsatzAus…`-Adapter, `EinsatzFilter`, `filtereEinsaetze` | **Neu** |
| `lib/data/repositories/buchung_repository.dart` | `belegIdsMitBuchung({ab, bis})` | Ändern |
| `lib/presentation/providers/einsatz_providers.dart` | `belegIdsMitBuchungProvider(jahr)`, `einsaetzeProvider(jahr)` | **Neu** |
| `lib/presentation/widgets/einsatz_zeile.dart` | `StatusBadge`, `EinsatzZeile` — CanvasKit-sicher | **Neu** |
| `lib/presentation/screens/einsaetze/einsaetze_screen.dart` | `EinsaetzeInhalt` (reine Darstellung) + `EinsaetzeScreen` (angebunden), «+»-Sheet | **Neu** |
| `lib/core/config/router.dart` | Route `/einsaetze`, Helfer `einsatzTypAusQuery` | Ändern |
| `lib/presentation/screens/home_screen.dart:139-169,261` | Kacheln und Pikett-Eintrag führen auf `/einsaetze?typ=…` | Ändern |
| `test/einsatz_status_test.dart` | Ableitung tabellengetrieben | **Neu** |
| `test/einsatz_test.dart` | Adapter, Filter | **Neu** |
| `test/einsatz_providers_test.dart` | Vereinigung mit überschriebenen Quellen | **Neu** |
| `test/einsatz_zeile_test.dart` | Zeile mit echter Schrift auf 360 px | **Neu** |
| `test/einsaetze_screen_test.dart` | Inhalt: Filter greifen, «+»-Verhalten | **Neu** |
| `test/einsatz_typ_query_test.dart` | Routen-Helfer | **Neu** |
| `test/status_vergleiche_ratsche_test.dart` | Ratsche: Zahl darf nur sinken | **Neu** |
| `test/alte_listen_ablauf_test.dart` | Alte Listen weg ab v0.106.0 | **Neu** |
| `test/canvaskit_sichere_widgets_test.dart` | Zeile in die Wächterliste | Ändern |

**Versionen:** B2 liefert als **v0.105.0**. Die alten Listenrouten fallen mit **v0.106.0**.

**Gilt für alle Aufgaben:** Flutter-PATH in Bash `export PATH="$PATH:/c/flutter/bin"`; `flutter analyze` hat 56 vorbestehende Infos — keine neuen; Kommentare erklären das WARUM und stehen auf Deutsch; Commit-Nachrichten ohne Umlaute; Tests prüfen echtes Verhalten, nie einen Nachbau; Layout-Tests laden Roboto (Muster in `test/kachel_text_test.dart`).

---

### Task 1: Der abgeleitete Status

**Files:**
- Create: `lib/core/util/einsatz_status.dart`
- Test: `test/einsatz_status_test.dart`

Hintergrund: Sechs Typen, vier Status-Vokabulare. Die Datenbank kennt praktisch nur «fertig» (je Tabelle ein Wert); «geplant» und «in Arbeit» ergeben sich aus `geplant_am`, `arbeit_von`/`arbeit_bis` und `termine`. «Verrechnet» ist bei Reinigungen `abgerechnet` **oder** Ertragsbuchung vorhanden — `abgerechnet` allein heisst nur «in einer Heineken-Monatsrechnung». Alle Eingaben sind Primitive, kein Modell: So laufen die Tests ohne Isar, und die Regel bleibt für die v2 lesbar.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsatz_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';

void main() {
  const keines = EinsatzKennzeichen.keines;

  group('reinigungLage', () {
    test('abgeschlossen ohne Buchung und ohne Heineken-Flag = erledigt', () {
      final l = reinigungLage(status: 'abgeschlossen', abgerechnet: false, hatBuchung: false);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, keines);
    });

    test('Tresenrechnung mit Ertragsbuchung = verrechnet, obwohl abgerechnet false', () {
      final l = reinigungLage(status: 'abgeschlossen', abgerechnet: false, hatBuchung: true);
      expect(l.status, EinsatzStatus.verrechnet);
    });

    test('Heineken-Reinigung: abgerechnet reicht, keine Buchung noetig', () {
      final l = reinigungLage(status: 'abgeschlossen', abgerechnet: true, hatBuchung: false);
      expect(l.status, EinsatzStatus.verrechnet);
    });

    test('offen (angelegt, nicht abgeschlossen) = in Arbeit', () {
      expect(reinigungLage(status: 'offen', abgerechnet: false, hatBuchung: false).status,
          EinsatzStatus.inArbeit);
    });

    test('storniert = erledigt mit Kennzeichen abgebrochen, nie verrechnet', () {
      final l = reinigungLage(status: 'storniert', abgerechnet: true, hatBuchung: true);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
    });

    test('unbekannter Wert wirft nicht, sondern ergibt offen', () {
      expect(reinigungLage(status: 'irgendwas', abgerechnet: false, hatBuchung: false).status,
          EinsatzStatus.offen);
    });
  });

  group('stoerungLage', () {
    test('offen ohne Termin = offen', () {
      expect(stoerungLage(status: 'offen', abgerechnet: false).status, EinsatzStatus.offen);
    });

    test('offen mit geplant_am = geplant', () {
      expect(
        stoerungLage(status: 'offen', geplantAm: DateTime(2026, 9, 17), abgerechnet: false).status,
        EinsatzStatus.geplant,
      );
    });

    test('Arbeit begonnen ohne Ende = in Arbeit, auch bei Status offen', () {
      expect(
        stoerungLage(status: 'offen', arbeitVon: '09:10', abgerechnet: false).status,
        EinsatzStatus.inArbeit,
      );
    });

    test('in_bearbeitung = in Arbeit', () {
      expect(stoerungLage(status: 'in_bearbeitung', abgerechnet: false).status,
          EinsatzStatus.inArbeit);
    });

    test('behoben = erledigt', () {
      expect(stoerungLage(status: 'behoben', abgerechnet: false).status, EinsatzStatus.erledigt);
    });

    test('nicht_behebbar = erledigt mit Kennzeichen', () {
      final l = stoerungLage(status: 'nicht_behebbar', abgerechnet: false);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.nichtBehebbar);
    });

    test('abgerechnet gewinnt ueber alles — hoechste Stufe', () {
      expect(stoerungLage(status: 'in_bearbeitung', abgerechnet: true).status,
          EinsatzStatus.verrechnet);
    });
  });

  group('montageLage', () {
    test('geplant = geplant', () {
      expect(montageLage(status: 'geplant', abgerechnet: false).status, EinsatzStatus.geplant);
    });
    test('geplant mit begonnener Arbeit = in Arbeit', () {
      expect(montageLage(status: 'geplant', arbeitVon: '08:00', abgerechnet: false).status,
          EinsatzStatus.inArbeit);
    });
    test('begonnen und beendet zaehlt nicht mehr als in Arbeit', () {
      expect(
        montageLage(status: 'geplant', arbeitVon: '08:00', arbeitBis: '10:00', abgerechnet: false)
            .status,
        EinsatzStatus.geplant,
      );
    });
    test('abgeschlossen = erledigt', () {
      expect(montageLage(status: 'abgeschlossen', abgerechnet: false).status,
          EinsatzStatus.erledigt);
    });
    test('abgebrochen = erledigt mit Kennzeichen, nie verrechnet', () {
      final l = montageLage(status: 'abgebrochen', abgerechnet: true);
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
    });
  });

  group('eigenauftragLage', () {
    test('behoben = erledigt', () {
      expect(eigenauftragLage(status: 'behoben', abgerechnet: false).status,
          EinsatzStatus.erledigt);
    });
    test('nachbearbeitung_noetig = in Arbeit', () {
      expect(eigenauftragLage(status: 'nachbearbeitung_noetig', abgerechnet: false).status,
          EinsatzStatus.inArbeit);
    });
    test('nicht_behebbar = erledigt mit Kennzeichen', () {
      expect(eigenauftragLage(status: 'nicht_behebbar', abgerechnet: false).kennzeichen,
          EinsatzKennzeichen.nichtBehebbar);
    });
    test('abgerechnet = verrechnet', () {
      expect(eigenauftragLage(status: 'behoben', abgerechnet: true).status,
          EinsatzStatus.verrechnet);
    });
  });

  group('saisonreinigungLage (Beleg)', () {
    test('ein Beleg ist immer erledigt', () {
      expect(saisonreinigungLage(abgerechnet: false).status, EinsatzStatus.erledigt);
    });
    test('abgerechnet = verrechnet', () {
      expect(saisonreinigungLage(abgerechnet: true).status, EinsatzStatus.verrechnet);
    });
  });

  group('terminLage', () {
    test('vorgeschlagen = offen', () {
      expect(terminLage(status: 'vorgeschlagen').status, EinsatzStatus.offen);
    });
    test('geplant = geplant', () {
      expect(terminLage(status: 'geplant').status, EinsatzStatus.geplant);
    });
    test('erledigt = erledigt', () {
      expect(terminLage(status: 'erledigt').status, EinsatzStatus.erledigt);
    });
    test('abgesagt = erledigt mit Kennzeichen abgebrochen', () {
      final l = terminLage(status: 'abgesagt');
      expect(l.status, EinsatzStatus.erledigt);
      expect(l.kennzeichen, EinsatzKennzeichen.abgebrochen);
    });
  });

  group('pikettLage', () {
    test('aktiv = in Arbeit', () {
      expect(pikettLage(istAktiv: true, abgerechnet: false).status, EinsatzStatus.inArbeit);
    });
    test('inaktiv = erledigt', () {
      expect(pikettLage(istAktiv: false, abgerechnet: false).status, EinsatzStatus.erledigt);
    });
    test('abgerechnet = verrechnet', () {
      expect(pikettLage(istAktiv: false, abgerechnet: true).status, EinsatzStatus.verrechnet);
    });
  });

  test('Reihenfolge der Stufen ist die Reihenfolge des Enums', () {
    expect(EinsatzStatus.values, [
      EinsatzStatus.offen,
      EinsatzStatus.geplant,
      EinsatzStatus.inArbeit,
      EinsatzStatus.erledigt,
      EinsatzStatus.verrechnet,
    ]);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsatz_status_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: einsatz_status.dart`

- [ ] **Step 3: Umsetzung**

```dart
// lib/core/util/einsatz_status.dart

/// Ein Status für alle Einsatztypen (B2).
///
/// WARUM: Sechs Typen, vier Vokabulare — «fertig» heisst je nach Tabelle
/// `abgeschlossen` oder `behoben`, «verrechnet» ist nirgends ein Status,
/// sondern ein Flag daneben, und `anlage_detail_screen.dart:878` verglich
/// eine Störung mit `'abgeschlossen'`, einem Wert, den Störungen nie tragen.
/// Hier steht die Regel einmal. Die Tabellen bleiben, wie sie sind: Sie
/// kennen ohnehin nur «fertig» (Ist-Aufnahme 15.09.2026: je Tabelle genau
/// ein Wert), und die Datenbank ist mit der v2 geteilt.
///
/// Alle Eingaben sind Primitive — kein Modell —, damit die Tests ohne Isar
/// laufen und die Regel als Vorlage für das Einsatz-Modell der v2 taugt.
library;

/// Die fünf Stufen, in dieser Reihenfolge. Die Reihenfolge ist der Vorrang:
/// Trifft mehr als eine zu, gilt die höhere.
enum EinsatzStatus { offen, geplant, inArbeit, erledigt, verrechnet }

/// Steht neben der Stufe, ändert sie nicht — bleibt sichtbar, statt in
/// «erledigt» zu verschwinden.
enum EinsatzKennzeichen { keines, abgebrochen, nichtBehebbar }

typedef EinsatzLage = ({EinsatzStatus status, EinsatzKennzeichen kennzeichen});

EinsatzLage _lage(
  EinsatzStatus status, [
  EinsatzKennzeichen kennzeichen = EinsatzKennzeichen.keines,
]) => (status: status, kennzeichen: kennzeichen);

/// Abgebrochene Einsätze sind abgeschlossen, ohne dass etwas geleistet
/// wurde: Stufe «erledigt», Kennzeichen «abgebrochen», und nie «verrechnet» —
/// selbst wenn ein Flag anderes behauptet.
EinsatzLage _abgebrochen() =>
    _lage(EinsatzStatus.erledigt, EinsatzKennzeichen.abgebrochen);

/// Reinigung. «Verrechnet» ist `abgerechnet` ODER Ertragsbuchung vorhanden:
/// Heineken-Reinigungen bekommen keine eigene Buchung (die entsteht erst mit
/// der Monatsrechnung) und tragen `abgerechnet`; Bar, Tresen, Mail, Post und
/// Jahresrechnung bekommen beim Abschluss eine Buchung und tragen nie
/// `abgerechnet`. Das Oder deckt beide und die 8'439 Altdaten ohne
/// Zahlungsart.
EinsatzLage reinigungLage({
  required String status,
  required bool abgerechnet,
  required bool hatBuchung,
}) {
  if (status == 'storniert') return _abgebrochen();
  if (abgerechnet || hatBuchung || status == 'abgerechnet') {
    return _lage(EinsatzStatus.verrechnet);
  }
  return switch (status) {
    'abgeschlossen' => _lage(EinsatzStatus.erledigt),
    'offen' => _lage(EinsatzStatus.inArbeit),
    // Unbekannt wirft nicht — so fällt ein neuer Wert in der Liste auf,
    // statt die Liste zu stürzen.
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Störung. «Offen» ist ein eigener Zustand vor «geplant»: gemeldet, aber
/// noch ohne Termin — das ist, was Daniel morgens sucht.
EinsatzLage stoerungLage({
  required String status,
  DateTime? geplantAm,
  String? arbeitVon,
  String? arbeitBis,
  required bool abgerechnet,
}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  final arbeitLaeuft = arbeitVon != null && arbeitBis == null;
  return switch (status) {
    'behoben' => _lage(EinsatzStatus.erledigt),
    'nicht_behebbar' => _lage(EinsatzStatus.erledigt, EinsatzKennzeichen.nichtBehebbar),
    'in_bearbeitung' => _lage(EinsatzStatus.inArbeit),
    'offen' when arbeitLaeuft => _lage(EinsatzStatus.inArbeit),
    'offen' when geplantAm != null => _lage(EinsatzStatus.geplant),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Montage.
EinsatzLage montageLage({
  required String status,
  String? arbeitVon,
  String? arbeitBis,
  required bool abgerechnet,
}) {
  if (status == 'abgebrochen') return _abgebrochen();
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  final arbeitLaeuft = arbeitVon != null && arbeitBis == null;
  return switch (status) {
    'abgeschlossen' => _lage(EinsatzStatus.erledigt),
    'in_bearbeitung' => _lage(EinsatzStatus.inArbeit),
    'geplant' when arbeitLaeuft => _lage(EinsatzStatus.inArbeit),
    'geplant' => _lage(EinsatzStatus.geplant),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Eigenauftrag. Kein «geplant» — das Modell hat kein Plandatum.
EinsatzLage eigenauftragLage({required String status, required bool abgerechnet}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  return switch (status) {
    'behoben' => _lage(EinsatzStatus.erledigt),
    'nicht_behebbar' => _lage(EinsatzStatus.erledigt, EinsatzKennzeichen.nichtBehebbar),
    'nachbearbeitung_noetig' => _lage(EinsatzStatus.inArbeit),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Saison-Beleg (`eroeffnungsreinigungen`, `art` eroeffnung oder
/// endreinigung). Ein Beleg ist per Definition erledigt; das Geplante dazu
/// steht in `termine`.
EinsatzLage saisonreinigungLage({required bool abgerechnet}) =>
    _lage(abgerechnet ? EinsatzStatus.verrechnet : EinsatzStatus.erledigt);

/// Termin (`termine`): vorgeschlagen · geplant · erledigt · abgesagt.
EinsatzLage terminLage({required String status}) => switch (status) {
  'abgesagt' => _abgebrochen(),
  'erledigt' => _lage(EinsatzStatus.erledigt),
  'geplant' => _lage(EinsatzStatus.geplant),
  _ => _lage(EinsatzStatus.offen),
};

/// Pikett: aktiv heisst gerade im Dienst.
EinsatzLage pikettLage({required bool istAktiv, required bool abgerechnet}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  return _lage(istAktiv ? EinsatzStatus.inArbeit : EinsatzStatus.erledigt);
}

/// Anzeigename je Stufe — an einer Stelle, damit Badge und Filter dasselbe
/// Wort verwenden.
String einsatzStatusLabel(EinsatzStatus s) => switch (s) {
  EinsatzStatus.offen => 'offen',
  EinsatzStatus.geplant => 'geplant',
  EinsatzStatus.inArbeit => 'in Arbeit',
  EinsatzStatus.erledigt => 'erledigt',
  EinsatzStatus.verrechnet => 'verrechnet',
};

String einsatzKennzeichenLabel(EinsatzKennzeichen k) => switch (k) {
  EinsatzKennzeichen.keines => '',
  EinsatzKennzeichen.abgebrochen => 'abgebrochen',
  EinsatzKennzeichen.nichtBehebbar => 'nicht behebbar',
};
```

- [ ] **Step 4: Test laufen lassen, Erfolg prüfen**

Run: `flutter test test/einsatz_status_test.dart`
Erwartet: BESTANDEN, 28 Tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/einsatz_status.dart test/einsatz_status_test.dart
git commit -m "feat: ein abgeleiteter Status fuer alle Einsatztypen (B2)"
```

---

### Task 2: Die Einsatz-Sicht, Adapter und Filter

**Files:**
- Create: `lib/core/util/einsatz.dart`
- Test: `test/einsatz_test.dart`

Hintergrund: Der Screen soll eine Liste eines Typs zeigen, nicht sechs. `Einsatz` ist eine Sicht, kein Modell — sie wird aus den geladenen Daten berechnet, wie `TourEintrag` (`tour_providers.dart:359`) es für den Tourenplan tut. Die Adapter nehmen das lokale Modell plus den nachgeschlagenen Betrieb; der Reinigungs-Adapter zusätzlich `hatBuchung`.

Felder der lokalen Modelle (geprüft 15.09.2026): `ReinigungLocal` (`serverId`, `anlageId`, `betriebId`, `datum`, `preisBrutto`, `zahlungsart`, `status`, `abgerechnet`, `routeId`) · `StoerungLocal` (`betriebId`, `datum`, `geplantAm`, `geplantZeit`, `arbeitVon`, `arbeitBis`, `status`, `preisNetto`, `abgerechnet`, `problemBeschreibung`, `anlageTyp`, `istKilometerabrechnung`, `stoerungBereiche`, `routeId`) · `MontageLocal` (`betriebId`, `datum`, `geplantAm`, `geplantZeit`, `arbeitVon`, `arbeitBis`, `status`, `kostenArbeit`, `abgerechnet`, `beschreibung`, `montageTyp`, `routeId`) · `EigenauftragLocal` (`betriebId`, `datum`, `status`, `pauschale`, `abgerechnet`, `routeId`) · `EroeffnungsreinigungLocal` (`betriebId`, `datum`, `art`, `preis`, `abgerechnet`, `routeId`) · `PikettDienstLocal` (`datumStart`, `datumEnde`, `istAktiv`, `pauschale`, `pauschaleGesamt`, `abgerechnet`, `routeId`) · `TerminDto` (`id`, `betriebId`, `datum`, `uhrzeitVon`, `typ`, `titel`, `status`) · `BetriebLocal` (`serverId`, `name`, `ort`, `regionId`, `betriebNr`).

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsatz_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';

BetriebLocal betrieb() => BetriebLocal()
  ..serverId = 'b1'
  ..name = 'Calanda'
  ..ort = 'Chur'
  ..regionId = 'r1'
  ..betriebNr = '4711';

void main() {
  group('einsatzAusReinigung', () {
    test('uebernimmt Betrieb, Datum, Bruttopreis und leitet den Status ab', () {
      final r = ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..preisBrutto = 177.30
        ..status = 'abgeschlossen'
        ..abgerechnet = false;

      final e = einsatzAusReinigung(r, betrieb: betrieb(), hatBuchung: true);

      expect(e.typ, EinsatzTyp.reinigung);
      expect(e.typLabel, 'Reinigung');
      expect(e.betriebName, 'Calanda');
      expect(e.betriebOrt, 'Chur');
      expect(e.betriebNr, '4711');
      expect(e.regionId, 'r1');
      expect(e.datum, DateTime(2026, 9, 15));
      expect(e.betragCHF, 177.30);
      expect(e.status, EinsatzStatus.verrechnet);
      expect(e.detailRoute, '/reinigungen/${r.routeId}');
    });

    test('ohne Betrieb bleibt der Name ein Platzhalter statt zu werfen', () {
      final r = ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'fehlt'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'abgeschlossen';
      final e = einsatzAusReinigung(r, betrieb: null, hatBuchung: false);
      expect(e.betriebName, 'Unbekannter Betrieb');
    });
  });

  group('einsatzAusStoerung', () {
    test('nimmt problemBeschreibung, geplante Zeit und die Zusatzfilter-Felder mit', () {
      final s = StoerungLocal()
        ..serverId = 's1'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 17)
        ..geplantAm = DateTime(2026, 9, 17)
        ..geplantZeit = '14:00'
        ..status = 'offen'
        ..problemBeschreibung = 'Zapfhahn tropft'
        ..anlageTyp = 'heigenie'
        ..istKilometerabrechnung = false
        ..preisNetto = 94.05;

      final e = einsatzAusStoerung(s, betrieb: betrieb());

      expect(e.typ, EinsatzTyp.stoerung);
      expect(e.status, EinsatzStatus.geplant);
      expect(e.zeit, '14:00');
      expect(e.beschreibung, 'Zapfhahn tropft');
      expect(e.anlageTyp, 'heigenie');
      expect(e.betragCHF, isNull, reason: 'geplant zeigt keinen Betrag');
    });

    test('erledigte Stoerung zeigt den Nettopreis', () {
      final s = StoerungLocal()
        ..serverId = 's2'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'behoben'
        ..problemBeschreibung = 'x'
        ..preisNetto = 94.05;
      expect(einsatzAusStoerung(s, betrieb: betrieb()).betragCHF, 94.05);
    });
  });

  group('einsatzAusMontage', () {
    test('nimmt beschreibung und kostenArbeit', () {
      final m = MontageLocal()
        ..serverId = 'm1'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..montageTyp = 'neuanlage'
        ..beschreibung = 'neue Anlage'
        ..datum = DateTime(2026, 9, 10)
        ..status = 'abgeschlossen'
        ..kostenArbeit = 250;
      final e = einsatzAusMontage(m, betrieb: betrieb());
      expect(e.typ, EinsatzTyp.montage);
      expect(e.beschreibung, 'neue Anlage');
      expect(e.betragCHF, 250);
      expect(e.status, EinsatzStatus.erledigt);
    });
  });

  group('einsatzAusTermin', () {
    test('Termin oeffnet den Betrieb und hat keinen Betrag', () {
      final t = TerminDto(
        id: 't1',
        userId: 'u',
        betriebId: 'b1',
        datum: DateTime(2026, 9, 20),
        uhrzeitVon: '08:00',
        uhrzeitBis: null,
        typ: 'endreinigung',
        anlass: 'saisonende',
        titel: 'Endreinigung Piz Piz',
        notizen: null,
        status: 'geplant',
      );
      final e = einsatzAusTermin(t, betrieb: betrieb());
      expect(e.typ, EinsatzTyp.termin);
      expect(e.typLabel, 'Termin Endreinigung');
      expect(e.zeit, '08:00');
      expect(e.betragCHF, isNull);
      expect(e.status, EinsatzStatus.geplant);
      expect(e.detailRoute, '/betriebe/b1');
    });
  });

  group('filtereEinsaetze', () {
    final calanda = einsatzAusReinigung(
      ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'abgeschlossen',
      betrieb: betrieb(),
      hatBuchung: true,
    );
    final stoerungDavos = einsatzAusStoerung(
      StoerungLocal()
        ..serverId = 's1'
        ..userId = 'u'
        ..betriebId = 'b2'
        ..datum = DateTime(2026, 8, 3)
        ..status = 'offen'
        ..problemBeschreibung = 'x'
        ..anlageTyp = 'david',
      betrieb: BetriebLocal()
        ..serverId = 'b2'
        ..name = 'Roessli'
        ..ort = 'Davos'
        ..regionId = 'r2',
    );
    final alle = [calanda, stoerungDavos];

    test('ohne Filter bleibt alles', () {
      expect(filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026)), hasLength(2));
    });

    test('Typ-Filter', () {
      final f = const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung});
      expect(filtereEinsaetze(alle, f).single.typ, EinsatzTyp.stoerung);
    });

    test('Status-Filter', () {
      final f = const EinsatzFilter(jahr: 2026, status: {EinsatzStatus.offen});
      expect(filtereEinsaetze(alle, f).single.betriebName, 'Roessli');
    });

    test('Monat', () {
      expect(filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026, monat: 8)).single.betriebName,
          'Roessli');
    });

    test('Region', () {
      expect(filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026, regionIds: {'r1'})).single
          .betriebName, 'Calanda');
    });

    test('Suche findet ueber den Ort — A9', () {
      expect(filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026, suche: 'davos')).single
          .betriebName, 'Roessli');
    });

    test('Stoerungs-Zusatzfilter greift nur, wenn genau Stoerung gewaehlt ist', () {
      final nurStoerung = const EinsatzFilter(
        jahr: 2026, typen: {EinsatzTyp.stoerung}, anlageTyp: 'heigenie');
      expect(filtereEinsaetze(alle, nurStoerung), isEmpty,
          reason: 'david != heigenie');

      final beideTypen = const EinsatzFilter(
        jahr: 2026, typen: {EinsatzTyp.stoerung, EinsatzTyp.reinigung}, anlageTyp: 'heigenie');
      expect(filtereEinsaetze(alle, beideTypen), hasLength(2),
          reason: 'bei mehreren Typen wird der Zusatzfilter ignoriert');
    });

    test('Sortierung: neuestes Datum zuerst', () {
      expect(filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026)).first.betriebName, 'Calanda');
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsatz_test.dart`
Erwartet: FEHLER — `einsatz.dart` fehlt.

Geprüft 15.09.2026: Im VM-Testlauf gelten die **nativen** Isar-Klassen (`dart.library.html` ist dort falsch). Deren `late`-Felder müssen gesetzt sein, bevor etwas sie liest — der Adapter liest `userId` nicht, die Tests setzen es trotzdem, damit ein späteres Feld nicht überrascht. `routeId` ist im VM-Lauf `id.toString()` (also `'0'`), nie der `serverId` — deshalb prüft kein Test einen konkreten `routeId`-Wert, nur `detailRoute` relativ zu `r.routeId`. Der `TerminDto`-Konstruktor hat genau die Felder aus dem Test (`anlass` und `status` haben Vorgaben).

- [ ] **Step 3: Umsetzung**

```dart
// lib/core/util/einsatz.dart
import 'package:sbs_projer_app/core/util/betrieb_suche.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';

/// Die Einsatzarten des gemeinsamen Screens (B2).
enum EinsatzTyp { reinigung, stoerung, montage, eigenauftrag, saisonreinigung, termin, pikett }

String einsatzTypLabel(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => 'Reinigung',
  EinsatzTyp.stoerung => 'Störung',
  EinsatzTyp.montage => 'Montage',
  EinsatzTyp.eigenauftrag => 'Eigenauftrag',
  EinsatzTyp.saisonreinigung => 'Saisonreinigung',
  EinsatzTyp.termin => 'Termin',
  EinsatzTyp.pikett => 'Pikett',
};

/// Eine Sicht auf einen Einsatz — kein Modell, keine Tabelle. Wird aus den
/// geladenen Daten berechnet, wie `TourEintrag` für den Tourenplan.
class Einsatz {
  final EinsatzTyp typ;
  /// Feiner als der Typ: «Eröffnungsreinigung», «Endreinigung»,
  /// «Termin Endreinigung».
  final String typLabel;
  final String routeId;
  final String? betriebId;
  final String betriebName;
  final String? betriebOrt;
  final String? betriebNr;
  final String? regionId;
  final DateTime datum;
  /// Nur bei Geplantem: Störung/Montage `geplantZeit`, Termin `uhrzeitVon`.
  final String? zeit;
  final String? beschreibung;
  final EinsatzStatus status;
  final EinsatzKennzeichen kennzeichen;
  /// `null` bei Geplantem und bei Terminen — dort gibt es noch nichts zu
  /// verrechnen.
  final double? betragCHF;
  // Die drei Störungs-Zusatzfilter aus Paket 06 — nur bei Störungen belegt.
  final String? anlageTyp;
  final bool istKilometerabrechnung;
  final List<int> stoerungBereiche;

  const Einsatz({
    required this.typ,
    required this.typLabel,
    required this.routeId,
    required this.betriebId,
    required this.betriebName,
    required this.betriebOrt,
    required this.betriebNr,
    required this.regionId,
    required this.datum,
    required this.status,
    required this.kennzeichen,
    this.zeit,
    this.beschreibung,
    this.betragCHF,
    this.anlageTyp,
    this.istKilometerabrechnung = false,
    this.stoerungBereiche = const [],
  });

  /// Die bestehende Detailseite des Typs. Termine haben keine — sie öffnen
  /// den Betrieb.
  String get detailRoute => switch (typ) {
    EinsatzTyp.reinigung => '/reinigungen/$routeId',
    EinsatzTyp.stoerung => '/stoerungen/$routeId',
    EinsatzTyp.montage => '/montagen/$routeId',
    EinsatzTyp.eigenauftrag => '/eigenauftraege/$routeId',
    EinsatzTyp.saisonreinigung => '/eroeffnungsreinigungen/$routeId',
    EinsatzTyp.termin => '/betriebe/$betriebId',
    EinsatzTyp.pikett => '/pikett/$routeId',
  };

  bool get istGeplantOderOffen =>
      status == EinsatzStatus.offen || status == EinsatzStatus.geplant;
}

const _unbekannt = 'Unbekannter Betrieb';

/// Betrag nur, wenn der Einsatz stattgefunden hat — bei Geplantem wäre er
/// eine Schätzung, die wie eine Tatsache aussieht.
double? _betragWennErledigt(EinsatzLage l, double? betrag) =>
    (l.status == EinsatzStatus.offen || l.status == EinsatzStatus.geplant) ? null : betrag;

Einsatz einsatzAusReinigung(
  ReinigungLocal r, {
  required BetriebLocal? betrieb,
  required bool hatBuchung,
}) {
  final l = reinigungLage(status: r.status, abgerechnet: r.abgerechnet, hatBuchung: hatBuchung);
  return Einsatz(
    typ: EinsatzTyp.reinigung,
    typLabel: 'Reinigung',
    routeId: r.routeId,
    betriebId: r.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: r.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, r.preisBrutto),
  );
}

Einsatz einsatzAusStoerung(StoerungLocal s, {required BetriebLocal? betrieb}) {
  final l = stoerungLage(
    status: s.status,
    geplantAm: s.geplantAm,
    arbeitVon: s.arbeitVon,
    arbeitBis: s.arbeitBis,
    abgerechnet: s.abgerechnet,
  );
  return Einsatz(
    typ: EinsatzTyp.stoerung,
    typLabel: 'Störung',
    routeId: s.routeId,
    betriebId: s.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: s.datum,
    zeit: l.status == EinsatzStatus.geplant ? s.geplantZeit : null,
    beschreibung: s.problemBeschreibung,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, s.preisNetto),
    anlageTyp: s.anlageTyp,
    istKilometerabrechnung: s.istKilometerabrechnung,
    stoerungBereiche: s.stoerungBereiche ?? const [],
  );
}

Einsatz einsatzAusMontage(MontageLocal m, {required BetriebLocal? betrieb}) {
  final l = montageLage(
    status: m.status,
    arbeitVon: m.arbeitVon,
    arbeitBis: m.arbeitBis,
    abgerechnet: m.abgerechnet,
  );
  return Einsatz(
    typ: EinsatzTyp.montage,
    typLabel: 'Montage',
    routeId: m.routeId,
    betriebId: m.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: m.datum,
    zeit: l.status == EinsatzStatus.geplant ? m.geplantZeit : null,
    beschreibung: m.beschreibung,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, m.kostenArbeit),
  );
}

Einsatz einsatzAusEigenauftrag(EigenauftragLocal e, {required BetriebLocal? betrieb}) {
  final l = eigenauftragLage(status: e.status, abgerechnet: e.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.eigenauftrag,
    typLabel: 'Eigenauftrag',
    routeId: e.routeId,
    betriebId: e.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: e.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, e.pauschale),
  );
}

Einsatz einsatzAusSaisonreinigung(EroeffnungsreinigungLocal s, {required BetriebLocal? betrieb}) {
  final l = saisonreinigungLage(abgerechnet: s.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.saisonreinigung,
    typLabel: s.art == 'endreinigung' ? 'Endreinigung' : 'Eröffnungsreinigung',
    routeId: s.routeId,
    betriebId: s.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: s.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: s.preis,
  );
}

Einsatz einsatzAusTermin(TerminDto t, {required BetriebLocal? betrieb}) {
  final l = terminLage(status: t.status);
  final art = switch (t.typ) {
    'eroeffnungsreinigung' => 'Eröffnungsreinigung',
    'endreinigung' => 'Endreinigung',
    _ => t.titel,
  };
  return Einsatz(
    typ: EinsatzTyp.termin,
    typLabel: 'Termin $art',
    routeId: t.id,
    betriebId: t.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: t.datum,
    zeit: t.uhrzeitVon,
    beschreibung: t.notizen,
    status: l.status,
    kennzeichen: l.kennzeichen,
  );
}

/// Pikett hängt an keinem Betrieb — der Dienst gilt für das ganze Gebiet.
Einsatz einsatzAusPikett(PikettDienstLocal p) {
  final l = pikettLage(istAktiv: p.istAktiv, abgerechnet: p.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.pikett,
    typLabel: 'Pikett',
    routeId: p.routeId,
    betriebId: null,
    betriebName: 'Pikettdienst',
    betriebOrt: null,
    betriebNr: null,
    regionId: null,
    datum: p.datumStart,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: p.pauschaleGesamt ?? p.pauschale,
  );
}

/// Der Filterzustand des Screens. Unveränderlich, damit er sich testen und
/// in der URL abbilden lässt.
class EinsatzFilter {
  final int jahr;
  final int monat; // 0 = alle
  final Set<EinsatzTyp> typen; // leer = alle
  final Set<EinsatzStatus> status; // leer = alle
  final Set<String> regionIds; // leer = alle
  final String suche;
  // Störungs-Zusatzfilter — wirken nur, wenn `typen` genau {stoerung} ist.
  final String? anlageTyp; // null = alle, 'ohne' = ohne Typ
  final String kmFilter; // 'alle' | 'mit' | 'ohne'
  final int? bereich; // 1..5

  const EinsatzFilter({
    required this.jahr,
    this.monat = 0,
    this.typen = const {},
    this.status = const {},
    this.regionIds = const {},
    this.suche = '',
    this.anlageTyp,
    this.kmFilter = 'alle',
    this.bereich,
  });

  bool get nurStoerung => typen.length == 1 && typen.contains(EinsatzTyp.stoerung);

  EinsatzFilter copyWith({
    int? jahr,
    int? monat,
    Set<EinsatzTyp>? typen,
    Set<EinsatzStatus>? status,
    Set<String>? regionIds,
    String? suche,
    Object? anlageTyp = _unveraendert,
    String? kmFilter,
    Object? bereich = _unveraendert,
  }) => EinsatzFilter(
    jahr: jahr ?? this.jahr,
    monat: monat ?? this.monat,
    typen: typen ?? this.typen,
    status: status ?? this.status,
    regionIds: regionIds ?? this.regionIds,
    suche: suche ?? this.suche,
    anlageTyp: anlageTyp == _unveraendert ? this.anlageTyp : anlageTyp as String?,
    kmFilter: kmFilter ?? this.kmFilter,
    bereich: bereich == _unveraendert ? this.bereich : bereich as int?,
  );
}

const _unveraendert = Object();

/// Reine Filterfunktion — der Screen ruft sie mit seinem Zustand auf.
List<Einsatz> filtereEinsaetze(List<Einsatz> alle, EinsatzFilter f) {
  final gefiltert = alle.where((e) {
    if (e.datum.year != f.jahr) return false;
    if (f.monat != 0 && e.datum.month != f.monat) return false;
    if (f.typen.isNotEmpty && !f.typen.contains(e.typ)) return false;
    if (f.status.isNotEmpty && !f.status.contains(e.status)) return false;
    if (f.regionIds.isNotEmpty && !f.regionIds.contains(e.regionId)) return false;
    if (f.suche.trim().isNotEmpty &&
        !betriebPasst(
          name: e.betriebName,
          ort: e.betriebOrt,
          betriebNr: e.betriebNr,
          suche: f.suche,
        ) &&
        !(e.beschreibung?.toLowerCase().contains(f.suche.trim().toLowerCase()) ?? false)) {
      return false;
    }
    if (f.nurStoerung) {
      if (f.anlageTyp == 'ohne' && e.anlageTyp != null) return false;
      if (f.anlageTyp != null && f.anlageTyp != 'ohne' && e.anlageTyp != f.anlageTyp) {
        return false;
      }
      if (f.kmFilter == 'mit' && !e.istKilometerabrechnung) return false;
      if (f.kmFilter == 'ohne' && e.istKilometerabrechnung) return false;
      if (f.bereich != null && !e.stoerungBereiche.contains(f.bereich)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.datum.compareTo(a.datum));
  return gefiltert;
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/einsatz_test.dart`
Erwartet: BESTANDEN, 15 Tests.

Run: `flutter analyze lib/core/util/einsatz.dart`
Erwartet: keine Befunde. Meldet die Analyse, dass `stoerungBereiche` kein `List<int>?` ist, prüfe den Typ in `stoerung_local.dart` und passe die Zeile `stoerungBereiche: …` an — die Testerwartung bleibt.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/einsatz.dart test/einsatz_test.dart
git commit -m "feat: Einsatz-Sicht, Adapter und Filter fuer alle Typen (B2)"
```

---

### Task 3: Beleg-Ids mit Ertragsbuchung je Zeitraum

**Files:**
- Modify: `lib/data/repositories/buchung_repository.dart` (nach `getByBeleg`, Zeile 127–135)

Hintergrund: «Verrechnet» einer Reinigung braucht «hat Ertragsbuchung». `getByBeleg(id)` wäre eine Anfrage je Zeile — tausend je Jahr. Diese Abfrage holt alle Beleg-Ids eines Zeitraums in **einer** Anfrage. Ohne automatisierten Test: Sie spricht mit Supabase, und ein Test ohne Netz prüfte nur sich selbst. Geprüft wird sie in Task 9 im Browser (Reinigungen mit Tresen-/Mailrechnung müssen «verrechnet» zeigen).

- [ ] **Step 1: Methode ergänzen**

```dart
  /// Alle Beleg-Ids, zu denen im Zeitraum eine nicht stornierte
  /// Ertragsbuchung existiert (`beleg_typ = 'rechnung'`, siehe
  /// `reinigung_buchung_service.dart`).
  ///
  /// WARUM eine Sammelabfrage: Der Einsätze-Screen (B2) leitet «verrechnet»
  /// bei Reinigungen aus der Ertragsbuchung ab. `getByBeleg` je Zeile wären
  /// rund tausend Anfragen pro Jahr; hier ist es eine. Seitenweise geladen,
  /// weil PostgREST bei 1000 Zeilen deckelt (CLAUDE.md), mit `id` als
  /// eindeutigem Sortierschlüssel.
  static Future<Set<String>> belegIdsMitBuchung({
    required DateTime ab,
    required DateTime bis,
  }) async {
    final abStr = ab.toIso8601String().split('T').first;
    final bisStr = bis.toIso8601String().split('T').first;
    final ids = <String>{};
    const seite = 1000;
    var von = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('buchungen')
          .select('beleg_id')
          .eq('user_id', _userId)
          .eq('beleg_typ', 'rechnung')
          .eq('ist_storniert', false)
          .gte('datum', abStr)
          .lte('datum', bisStr)
          .not('beleg_id', 'is', null)
          .order('id')
          .range(von, von + seite - 1);
      for (final r in rows) {
        ids.add(r['beleg_id'] as String);
      }
      if (rows.length < seite) break;
      von += seite;
    }
    return ids;
  }
```

- [ ] **Step 2: Pagination-Wächter prüfen**

Run: `flutter test test/pagination_stabil_test.dart`
Erwartet: BESTANDEN — die neue Abfrage sortiert nach `id` und fällt dem Wächter nicht auf. Schlägt er an, steht `.order('id')` nicht direkt vor `.range(...)`; Reihenfolge korrigieren.

- [ ] **Step 3: Analyse und Commit**

Run: `flutter analyze lib/data/repositories/buchung_repository.dart`
Erwartet: keine neuen Befunde.

```bash
git add lib/data/repositories/buchung_repository.dart
git commit -m "feat: Beleg-Ids mit Ertragsbuchung je Zeitraum in einer Abfrage (B2)"
```

---

### Task 4: Die Provider — Vereinigung der Quellen

**Files:**
- Create: `lib/presentation/providers/einsatz_providers.dart`
- Test: `test/einsatz_providers_test.dart`

Vorhandene Quellen (geprüft): `reinigungenByJahrProvider(jahr)` (`FutureProvider.family<List<ReinigungLocal>, int>`), `stoerungenProvider`, `montagenProvider`, `eigenauftraegeProvider`, `eroeffnungsreinigungenProvider`, `pikettDiensteProvider` (alle `Provider<List<…>>`), `offeneTermineProvider` (`FutureProvider<List<TerminDto>>`), `betriebLookupProvider` (`Provider<Map<String, BetriebLocal>>`, `tour_providers.dart:560`).

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsatz_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  test('einsaetzeProvider vereinigt die Quellen und leitet verrechnet aus den Beleg-Ids ab',
      () async {
    final calanda = BetriebLocal()
      ..serverId = 'b1'
      ..name = 'Calanda'
      ..ort = 'Chur';
    final r1 = ReinigungLocal()
      ..serverId = 'r1'
      ..userId = 'u'
      ..anlageId = 'a1'
      ..betriebId = 'b1'
      ..datum = DateTime(2026, 9, 15)
      ..status = 'abgeschlossen'
      ..preisBrutto = 177.30;
    final r2 = ReinigungLocal()
      ..serverId = 'r2'
      ..userId = 'u'
      ..anlageId = 'a1'
      ..betriebId = 'b1'
      ..datum = DateTime(2026, 9, 14)
      ..status = 'abgeschlossen';
    final s1 = StoerungLocal()
      ..serverId = 's1'
      ..userId = 'u'
      ..betriebId = 'b1'
      ..datum = DateTime(2026, 9, 10)
      ..status = 'behoben'
      ..problemBeschreibung = 'x';

    final container = ProviderContainer(overrides: [
      reinigungenByJahrProvider.overrideWith((ref, jahr) async => jahr == 2026 ? [r1, r2] : []),
      stoerungenProvider.overrideWithValue([s1]),
      montagenProvider.overrideWithValue(const []),
      eigenauftraegeProvider.overrideWithValue(const []),
      eroeffnungsreinigungenProvider.overrideWithValue(const []),
      pikettDiensteProvider.overrideWithValue(const []),
      offeneTermineProvider.overrideWith((ref) async => const []),
      betriebLookupProvider.overrideWithValue({'b1': calanda}),
      belegIdsMitBuchungProvider.overrideWith((ref, jahr) async => {'r1'}),
    ]);
    addTearDown(container.dispose);

    final liste = await container.read(einsaetzeProvider(2026).future);

    expect(liste, hasLength(3));
    // Reihenfolge ueber Datum pruefen — `routeId` ist im VM-Lauf
    // `id.toString()`, nicht der serverId.
    expect(liste.map((e) => e.datum.day), [15, 14, 10], reason: 'neuestes Datum zuerst');
    expect(liste[0].status, EinsatzStatus.verrechnet, reason: 'r1 hat eine Buchung');
    expect(liste[1].status, EinsatzStatus.erledigt, reason: 'r2 hat keine');
    expect(liste[0].betriebName, 'Calanda');
    expect(liste[2].typ, EinsatzTyp.stoerung);
  });

  test('Stoerungen anderer Jahre werden nicht mitgeliefert', () async {
    final alt = StoerungLocal()
      ..serverId = 's0'
      ..userId = 'u'
      ..betriebId = 'b1'
      ..datum = DateTime(2025, 3, 1)
      ..status = 'behoben'
      ..problemBeschreibung = 'x';
    final container = ProviderContainer(overrides: [
      reinigungenByJahrProvider.overrideWith((ref, jahr) async => const []),
      stoerungenProvider.overrideWithValue([alt]),
      montagenProvider.overrideWithValue(const []),
      eigenauftraegeProvider.overrideWithValue(const []),
      eroeffnungsreinigungenProvider.overrideWithValue(const []),
      pikettDiensteProvider.overrideWithValue(const []),
      offeneTermineProvider.overrideWith((ref) async => const []),
      betriebLookupProvider.overrideWithValue(const {}),
      belegIdsMitBuchungProvider.overrideWith((ref, jahr) async => const {}),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(einsaetzeProvider(2026).future), isEmpty);
  });
}
```

Die Importpfade sind geprüft (15.09.2026); `regionenProvider` und `betriebLookupProvider` liegen beide in `tour_providers.dart`.

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsatz_providers_test.dart`
Erwartet: FEHLER — `einsatz_providers.dart` fehlt.

- [ ] **Step 3: Umsetzung**

```dart
// lib/presentation/providers/einsatz_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Beleg-Ids mit Ertragsbuchung im Kalenderjahr — eine Anfrage je Jahr,
/// gecacht, solange der Screen offen ist. Grundlage für «verrechnet» bei
/// Reinigungen (siehe `einsatz_status.dart`).
final belegIdsMitBuchungProvider = FutureProvider.family<Set<String>, int>((ref, jahr) {
  return BuchungRepository.belegIdsMitBuchung(
    ab: DateTime(jahr, 1, 1),
    bis: DateTime(jahr, 12, 31),
  );
});

/// Alle Einsätze eines Kalenderjahres, als eine Liste, neuestes Datum zuerst.
///
/// Reinigungen kommen jahresweise vom Server (rund 1'000 je Jahr), alle
/// anderen Typen liegen ohnehin vollständig im Speicher und werden hier auf
/// das Jahr gefiltert. Termine sind nur die offenen — die erledigten sind als
/// Saison-Beleg schon in der Liste.
final einsaetzeProvider = FutureProvider.family<List<Einsatz>, int>((ref, jahr) async {
  final betriebe = ref.watch(betriebLookupProvider);
  final reinigungen = await ref.watch(reinigungenByJahrProvider(jahr).future);
  final belegIds = await ref.watch(belegIdsMitBuchungProvider(jahr).future);
  final termine = await ref.watch(offeneTermineProvider.future);

  bool imJahr(DateTime d) => d.year == jahr;

  final liste = <Einsatz>[
    for (final r in reinigungen)
      einsatzAusReinigung(
        r,
        betrieb: betriebe[r.betriebId],
        hatBuchung: r.serverId != null && belegIds.contains(r.serverId),
      ),
    for (final s in ref.watch(stoerungenProvider))
      if (imJahr(s.datum)) einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
    for (final m in ref.watch(montagenProvider))
      if (imJahr(m.datum)) einsatzAusMontage(m, betrieb: betriebe[m.betriebId]),
    for (final e in ref.watch(eigenauftraegeProvider))
      if (imJahr(e.datum)) einsatzAusEigenauftrag(e, betrieb: betriebe[e.betriebId]),
    for (final s in ref.watch(eroeffnungsreinigungenProvider))
      if (imJahr(s.datum)) einsatzAusSaisonreinigung(s, betrieb: betriebe[s.betriebId]),
    for (final p in ref.watch(pikettDiensteProvider))
      if (imJahr(p.datumStart)) einsatzAusPikett(p),
    for (final t in termine)
      if (imJahr(t.datum)) einsatzAusTermin(t, betrieb: betriebe[t.betriebId]),
  ]..sort((a, b) => b.datum.compareTo(a.datum));
  return liste;
});
```

`betriebLookupProvider` (`tour_providers.dart:545`) schlüsselt seine Map nach `routeId` **und** `serverId` — `betriebe[r.betriebId]` trifft auf Web und nativ.

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/einsatz_providers_test.dart`
Erwartet: BESTANDEN, 2 Tests.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/einsatz_providers.dart test/einsatz_providers_test.dart
git commit -m "feat: einsaetzeProvider vereinigt sieben Quellen zu einer Liste (B2)"
```

---

### Task 5: Status-Badge und Einsatz-Zeile

**Files:**
- Create: `lib/presentation/widgets/einsatz_zeile.dart`
- Test: `test/einsatz_zeile_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart` (Dateiliste des zweiten Tests)

**CanvasKit-Regel:** Zeile aus `InkWell` + `Container` + `Row`. Kein `ListTile`, kein `FilledButton`, kein `ExpansionTile` — drei bestätigte Vorfälle. Vorbild: `_StoppZeile` in `lib/presentation/widgets/heute_liste.dart:277`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsatz_zeile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.reinigung,
  String name = 'Calanda',
  EinsatzStatus status = EinsatzStatus.erledigt,
  EinsatzKennzeichen kennzeichen = EinsatzKennzeichen.keines,
  double? betrag = 177.30,
  String? zeit,
  String? beschreibung,
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: 'x',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 9, 15),
  status: status,
  kennzeichen: kennzeichen,
  betragCHF: betrag,
  zeit: zeit,
  beschreibung: beschreibung,
);

Widget rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: ListView(children: [kind])),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt Betrieb, Typ, Ort, Datum, Status und Betrag', (tester) async {
    await tester.pumpWidget(rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () {})));
    expect(find.text('Calanda'), findsOneWidget);
    expect(find.textContaining('Reinigung · Chur · Di 15.09.'), findsOneWidget);
    expect(find.text('erledigt'), findsOneWidget);
    expect(find.text("177.30"), findsOneWidget);
  });

  testWidgets('geplant zeigt Uhrzeit und keinen Betrag', (tester) async {
    await tester.pumpWidget(rahmen(EinsatzZeile(
      einsatz: einsatz(typ: EinsatzTyp.montage, status: EinsatzStatus.geplant, betrag: null, zeit: '09:00'),
      onTap: () {},
    )));
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('geplant'), findsOneWidget);
    expect(find.textContaining('CHF'), findsNothing);
  });

  testWidgets('Kennzeichen steht neben dem Status', (tester) async {
    await tester.pumpWidget(rahmen(EinsatzZeile(
      einsatz: einsatz(typ: EinsatzTyp.stoerung, kennzeichen: EinsatzKennzeichen.nichtBehebbar, betrag: 94.05),
      onTap: () {},
    )));
    expect(find.text('nicht behebbar'), findsOneWidget);
  });

  testWidgets('Beschreibung der Stoerung erscheint in der zweiten Zeile', (tester) async {
    await tester.pumpWidget(rahmen(EinsatzZeile(
      einsatz: einsatz(typ: EinsatzTyp.stoerung, beschreibung: 'Zapfhahn tropft'),
      onTap: () {},
    )));
    expect(find.textContaining('Zapfhahn tropft'), findsOneWidget);
  });

  testWidgets('Tipp loest onTap aus', (tester) async {
    var getippt = false;
    await tester.pumpWidget(rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () => getippt = true)));
    await tester.tap(find.text('Calanda'));
    expect(getippt, isTrue);
  });

  testWidgets('passt auf 360 px, Betriebsname wird nicht gekuerzt', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(rahmen(EinsatzZeile(
      einsatz: einsatz(name: 'Seerestaurant Schlüssel', status: EinsatzStatus.verrechnet, betrag: 1234.55),
      onTap: () {},
    )));

    expect(tester.takeException(), isNull);
    final absatz = tester.renderObject<RenderParagraph>(find.text('Seerestaurant Schlüssel'));
    expect(absatz.didExceedMaxLines, isFalse);
  });

  testWidgets('kein ListTile, kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () {})));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsatz_zeile_test.dart`
Erwartet: FEHLER — `einsatz_zeile.dart` fehlt.

- [ ] **Step 3: Umsetzung**

```dart
// lib/presentation/widgets/einsatz_zeile.dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

IconData einsatzTypIcon(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => Icons.cleaning_services,
  EinsatzTyp.stoerung => Icons.warning_amber,
  EinsatzTyp.montage => Icons.build,
  EinsatzTyp.eigenauftrag => Icons.build_circle_outlined,
  EinsatzTyp.saisonreinigung => Icons.cleaning_services_outlined,
  EinsatzTyp.termin => Icons.event,
  EinsatzTyp.pikett => Icons.nightlight_round,
};

Color einsatzTypFarbe(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => AppColors.success,
  EinsatzTyp.stoerung => AppColors.warning,
  EinsatzTyp.montage => AppColors.info,
  EinsatzTyp.eigenauftrag => const Color(0xFF7C3AED),
  EinsatzTyp.saisonreinigung => AppColors.primary,
  EinsatzTyp.termin => AppColors.primary,
  EinsatzTyp.pikett => Colors.indigo,
};

Color _statusFarbe(EinsatzStatus s) => switch (s) {
  EinsatzStatus.offen => AppColors.warning,
  EinsatzStatus.geplant => AppColors.info,
  EinsatzStatus.inArbeit => AppColors.info,
  EinsatzStatus.erledigt => AppColors.success,
  EinsatzStatus.verrechnet => AppColors.textSecondary,
};

/// Kleiner Chip mit Stufe und, falls vorhanden, Kennzeichen — dieselbe
/// Bauart wie der Zähler-Chip der Startseiten-Kacheln.
class StatusBadge extends StatelessWidget {
  final EinsatzStatus status;
  final EinsatzKennzeichen kennzeichen;
  const StatusBadge({super.key, required this.status, this.kennzeichen = EinsatzKennzeichen.keines});

  @override
  Widget build(BuildContext context) {
    final farbe = _statusFarbe(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: farbe.withAlpha(25),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            einsatzStatusLabel(status),
            style: TextStyle(color: farbe, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        if (kennzeichen != EinsatzKennzeichen.keines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              einsatzKennzeichenLabel(kennzeichen),
              style: const TextStyle(fontSize: 10, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// Eine Zeile des Einsätze-Screens (Variante B, wie die Heute-Liste).
///
/// CanvasKit: `InkWell` + `Container` + `Row` — kein `ListTile`. Auf dem
/// produktiven CanvasKit-Web haben Material-Komfort-Widgets dreimal nicht
/// gerendert oder nicht reagiert (CLAUDE.md).
class EinsatzZeile extends StatelessWidget {
  final Einsatz einsatz;
  final VoidCallback onTap;
  const EinsatzZeile({super.key, required this.einsatz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = einsatz;
    final datum =
        '${_wochentage[e.datum.weekday - 1]} '
        '${e.datum.day.toString().padLeft(2, '0')}.'
        '${e.datum.month.toString().padLeft(2, '0')}.';
    final zweiteZeile = [
      e.typLabel,
      if (e.betriebOrt != null && e.betriebOrt!.isNotEmpty) e.betriebOrt!,
      if (e.zeit != null) '$datum ${e.zeit}' else datum,
      if (e.beschreibung != null && e.beschreibung!.isNotEmpty) e.beschreibung!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            Icon(einsatzTypIcon(e.typ), color: einsatzTypFarbe(e.typ), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.betriebName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    zweiteZeile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: e.status, kennzeichen: e.kennzeichen),
            if (e.betragCHF != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  chf(e.betragCHF!),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Die Testerwartung `find.text("177.30")` setzt voraus, dass `chf(177.30)` genau `177.30` liefert (Tausender-Apostroph erst ab 1'000). Für `1234.55` steht dann `1'234.55` in der Zeile — der 360-px-Test prüft nur den Namen.

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/einsatz_zeile_test.dart`
Erwartet: BESTANDEN, 7 Tests. Läuft der 360-px-Test über, `width: 56` des Betrags auf 52 senken und die Beschreibung auf `maxLines: 1` — nicht die Schrift verkleinern.

- [ ] **Step 5: Wächter erweitern**

In `test/canvaskit_sichere_widgets_test.dart` den zweiten Test (`'Heute-Liste ohne CanvasKit-tote Widgets'`) auf eine Dateiliste umstellen: aus

```dart
    final datei = File('lib/presentation/widgets/heute_liste.dart');
```

wird eine Schleife über

```dart
    for (final pfad in [
      'lib/presentation/widgets/heute_liste.dart',
      'lib/presentation/widgets/einsatz_zeile.dart',
    ]) {
      final datei = File(pfad);
      // … bestehender Rumpf unverändert, `heute_liste.dart` im reason-Text
      // durch `$pfad` ersetzen …
    }
```

Run: `flutter test test/canvaskit_sichere_widgets_test.dart`
Erwartet: BESTANDEN.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/einsatz_zeile.dart test/einsatz_zeile_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: Einsatz-Zeile mit Status-Badge, CanvasKit-sicher (B2)"
```

---

### Task 6: Der Screen

**Files:**
- Create: `lib/presentation/screens/einsaetze/einsaetze_screen.dart`
- Test: `test/einsaetze_screen_test.dart`

Zwei Klassen: `EinsaetzeInhalt` (reine Darstellung, testbar ohne Provider) und `EinsaetzeScreen` (angebunden). Filterbausteine wie in `stoerungen_list_screen.dart:150-240`: `AppFilterMultiDropdown<T>(label, options: List<(T, String)>, selected: Set<T>, onChanged)` und `AppFilterDropdown<T>(hint, value, options, onChanged, nullable, isExpanded)` — beide sind `AppFilterItem` und werden mit `.build(context)` eingesetzt. `AppJahrMonatLeiste(jahre, selectedJahr, onJahrChanged, selectedMonat, onMonatChanged, trailing)`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsaetze_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/presentation/screens/einsaetze/einsaetze_screen.dart';

Einsatz e(EinsatzTyp typ, String name, {EinsatzStatus status = EinsatzStatus.erledigt, String ort = 'Chur'}) =>
    Einsatz(
      typ: typ,
      typLabel: einsatzTypLabel(typ),
      routeId: name,
      betriebId: 'b_$name',
      betriebName: name,
      betriebOrt: ort,
      betriebNr: null,
      regionId: null,
      datum: DateTime(2026, 9, 15),
      status: status,
      kennzeichen: EinsatzKennzeichen.keines,
    );

final alle = [
  e(EinsatzTyp.reinigung, 'Calanda'),
  e(EinsatzTyp.stoerung, 'Roessli', status: EinsatzStatus.offen, ort: 'Davos'),
  e(EinsatzTyp.montage, 'Posthotel', status: EinsatzStatus.geplant),
];

Widget rahmen({
  required EinsatzFilter filter,
  ValueChanged<EinsatzFilter>? onFilter,
  ValueChanged<Einsatz>? onOeffnen,
  ValueChanged<EinsatzTyp?>? onNeu,
}) => MaterialApp(
  home: EinsaetzeInhalt(
    alle: alle,
    filter: filter,
    jahre: const [2026, 2025],
    regionen: const [],
    anlagenTypen: const ['heigenie', 'david'],
    onFilter: onFilter ?? (_) {},
    onOeffnen: onOeffnen ?? (_) {},
    onNeu: onNeu ?? (_) {},
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('ohne Filter stehen alle drei da', (tester) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026)));
    expect(find.text('Calanda'), findsOneWidget);
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Posthotel'), findsOneWidget);
  });

  testWidgets('Typ-Filter zeigt nur den Typ', (tester) async {
    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung}),
    ));
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Calanda'), findsNothing);
  });

  testWidgets('Status-Filter zeigt nur offene', (tester) async {
    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026, status: {EinsatzStatus.offen}),
    ));
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Posthotel'), findsNothing);
  });

  testWidgets('Suche findet ueber den Ort', (tester) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026, suche: 'davos')));
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Calanda'), findsNothing);
  });

  testWidgets('Stoerungs-Zusatzfilter erscheinen nur bei genau Stoerung', (tester) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026)));
    expect(find.text('Alle Bereiche'), findsNothing);

    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung}),
    ));
    expect(find.text('Alle Bereiche'), findsOneWidget);
  });

  testWidgets('Tipp auf die Zeile meldet den Einsatz', (tester) async {
    Einsatz? geoeffnet;
    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026),
      onOeffnen: (x) => geoeffnet = x,
    ));
    await tester.tap(find.text('Calanda'));
    expect(geoeffnet?.betriebName, 'Calanda');
  });

  testWidgets('Plus mit genau einem Typ meldet diesen Typ', (tester) async {
    EinsatzTyp? typ;
    var aufrufe = 0;
    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.montage}),
      onNeu: (t) { typ = t; aufrufe++; },
    ));
    await tester.tap(find.byKey(const Key('einsaetze_neu')));
    expect(aufrufe, 1);
    expect(typ, EinsatzTyp.montage);
  });

  testWidgets('Plus ohne eindeutigen Typ meldet null — der Screen fragt dann nach', (tester) async {
    EinsatzTyp? typ = EinsatzTyp.reinigung;
    await tester.pumpWidget(rahmen(
      filter: const EinsatzFilter(jahr: 2026),
      onNeu: (t) => typ = t,
    ));
    await tester.tap(find.byKey(const Key('einsaetze_neu')));
    expect(typ, isNull);
  });

  testWidgets('Leerzustand statt leerer Flaeche', (tester) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026, suche: 'gibtsnicht')));
    expect(find.text('Keine Einsätze für diese Auswahl'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsaetze_screen_test.dart`
Erwartet: FEHLER — `einsaetze_screen.dart` fehlt.

- [ ] **Step 3: Den Inhalt umsetzen**

```dart
// lib/presentation/screens/einsaetze/einsaetze_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_status.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

String _anlageTypLabel(String typ) =>
    typ.isEmpty ? typ : typ[0].toUpperCase() + typ.substring(1);

/// Darstellung ohne Datenanbindung — testbar ohne Provider.
class EinsaetzeInhalt extends StatelessWidget {
  final List<Einsatz> alle;
  final EinsatzFilter filter;
  final List<int> jahre;
  final List<RegionLocal> regionen;
  final List<String> anlagenTypen;
  final ValueChanged<EinsatzFilter> onFilter;
  final ValueChanged<Einsatz> onOeffnen;
  /// `null` heisst: kein eindeutiger Typ gewählt — der Screen fragt nach.
  final ValueChanged<EinsatzTyp?> onNeu;

  const EinsaetzeInhalt({
    super.key,
    required this.alle,
    required this.filter,
    required this.jahre,
    required this.regionen,
    required this.anlagenTypen,
    required this.onFilter,
    required this.onOeffnen,
    required this.onNeu,
  });

  @override
  Widget build(BuildContext context) {
    final gefiltert = filtereEinsaetze(alle, filter);
    final summe = gefiltert.fold(0.0, (s, e) => s + (e.betragCHF ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einsätze'),
        actions: [
          if (regionen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppFilterMultiDropdown<String>(
                label: 'Regionen',
                options: [
                  for (final r in regionen)
                    if (r.serverId != null) (r.serverId!, r.name),
                ],
                selected: filter.regionIds,
                onChanged: (s) => onFilter(filter.copyWith(regionIds: s)),
              ).build(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Betrieb, Ort oder Nummer…',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => onFilter(filter.copyWith(suche: v)),
            ),
          ),
          // Typ und Status als Mehrfach-Dropdowns, keine Chip-Reihe: Sieben
          // Typen wären auf 360 px zwei Zeilen Chips (Regel «kompakte
          // Dropdowns statt Chips», ui_smartphone_first).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterMultiDropdown<EinsatzTyp>(
                    label: 'Alle Typen',
                    isExpanded: true,
                    options: [for (final t in EinsatzTyp.values) (t, einsatzTypLabel(t))],
                    selected: filter.typen,
                    onChanged: (s) => onFilter(filter.copyWith(typen: s)),
                  ).build(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppFilterMultiDropdown<EinsatzStatus>(
                    label: 'Alle Status',
                    isExpanded: true,
                    options: [for (final s in EinsatzStatus.values) (s, einsatzStatusLabel(s))],
                    selected: filter.status,
                    onChanged: (s) => onFilter(filter.copyWith(status: s)),
                  ).build(context),
                ),
              ],
            ),
          ),
          // Die drei Störungs-Zusatzfilter aus Paket 06 — nur wenn genau
          // «Störung» gewählt ist, sonst belasten sie die Liste ohne Nutzen.
          if (filter.nurStoerung)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: AppFilterDropdown<String>(
                      hint: 'Alle Typen',
                      isExpanded: true,
                      value: filter.anlageTyp,
                      options: [
                        for (final t in anlagenTypen) (t, _anlageTypLabel(t)),
                        ('ohne', 'Ohne Typ'),
                      ],
                      onChanged: (v) => onFilter(filter.copyWith(anlageTyp: v)),
                    ).build(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterDropdown<String>(
                      hint: 'Alle Arten',
                      isExpanded: true,
                      nullable: false,
                      value: filter.kmFilter,
                      options: const [
                        ('ohne', 'Störung'),
                        ('mit', 'Kilometerabrechnung'),
                        ('alle', 'Alle Arten'),
                      ],
                      onChanged: (v) => onFilter(filter.copyWith(kmFilter: v ?? 'alle')),
                    ).build(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterDropdown<int>(
                      hint: 'Alle Bereiche',
                      isExpanded: true,
                      value: filter.bereich,
                      options: const [
                        (1, '1 - Zapfhahn'),
                        (2, '2 - Leitung'),
                        (3, '3 - Kühler'),
                        (4, '4 - Zapfkopf'),
                        (5, '5 - Gas'),
                      ],
                      onChanged: (v) => onFilter(filter.copyWith(bereich: v)),
                    ).build(context),
                  ),
                ],
              ),
            ),
          AppJahrMonatLeiste(
            jahre: jahre,
            selectedJahr: filter.jahr,
            onJahrChanged: (j) => onFilter(filter.copyWith(jahr: j)),
            selectedMonat: filter.monat,
            onMonatChanged: (m) => onFilter(filter.copyWith(monat: m)),
            trailing: Text(
              summe > 0 ? '${gefiltert.length} – ${chf(summe)}' : '${gefiltert.length} Einsätze',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: gefiltert.isEmpty
                ? const Center(
                    child: Text(
                      'Keine Einsätze für diese Auswahl',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: gefiltert.length,
                    itemBuilder: (_, i) => EinsatzZeile(
                      einsatz: gefiltert[i],
                      onTap: () => onOeffnen(gefiltert[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              key: const Key('einsaetze_neu'),
              onPressed: () => onNeu(filter.typen.length == 1 ? filter.typen.single : null),
              child: const Icon(Icons.add),
            ),
    );
  }
}
```

`regionenProvider` (`Provider<List<RegionLocal>>`) liegt in `tour_providers.dart:43`; `RegionLocal` hat `serverId` und `name`. `FloatingActionButton` ist in allen sechs alten Listen im Einsatz und auf CanvasKit bewährt; er bleibt.

- [ ] **Step 4: Die angebundene Fassung und das «+»-Sheet**

Unter `EinsaetzeInhalt` in derselben Datei:

```dart
/// Angebunden: hält den Filterzustand, lädt das Jahr, navigiert.
class EinsaetzeScreen extends ConsumerStatefulWidget {
  final EinsatzTyp? vorgewaehlterTyp;
  const EinsaetzeScreen({super.key, this.vorgewaehlterTyp});

  @override
  ConsumerState<EinsaetzeScreen> createState() => _EinsaetzeScreenState();
}

class _EinsaetzeScreenState extends ConsumerState<EinsaetzeScreen> {
  late EinsatzFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = EinsatzFilter(
      jahr: DateTime.now().year,
      typen: widget.vorgewaehlterTyp == null ? const {} : {widget.vorgewaehlterTyp!},
    );
  }

  @override
  Widget build(BuildContext context) {
    final jahre = ref.watch(reinigungJahreProvider).valueOrNull ?? [DateTime.now().year];
    final regionen = ref.watch(regionenProvider);
    final einsaetze = ref.watch(einsaetzeProvider(_filter.jahr));

    return einsaetze.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Einsätze')),
        body: Center(child: Text('Einsätze konnten nicht geladen werden: $e')),
      ),
      data: (alle) {
        final anlagenTypen = alle
            .where((e) => e.typ == EinsatzTyp.stoerung)
            .map((e) => e.anlageTyp)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        return EinsaetzeInhalt(
          alle: alle,
          filter: _filter,
          jahre: jahre,
          regionen: regionen,
          anlagenTypen: anlagenTypen,
          onFilter: (f) => setState(() => _filter = f),
          onOeffnen: (e) => context.push(e.detailRoute),
          onNeu: (typ) => typ == null
              ? _typWaehlen(context)
              : _neu(GoRouter.of(context), typ),
        );
      },
    );
  }

  /// Nimmt den Router, nicht den Kontext: Aus dem «+»-Sheet heraus ist der
  /// Sheet-Kontext nach `Navigator.pop` nicht mehr gültig (Lehre aus
  /// `diktat_sheet.dart`, A4).
  void _neu(GoRouter router, EinsatzTyp typ) {
    final route = switch (typ) {
      EinsatzTyp.reinigung => '/reinigungen/neu',
      EinsatzTyp.stoerung => '/stoerungen/neu',
      EinsatzTyp.montage => '/montagen/neu',
      EinsatzTyp.eigenauftrag => '/eigenauftraege/neu',
      EinsatzTyp.saisonreinigung => '/eroeffnungsreinigungen/neu',
      EinsatzTyp.pikett => '/pikett/neu',
      // Termine entstehen im Tourenplan und per Diktat, nicht hier.
      EinsatzTyp.termin => '/touren',
    };
    router.push(route);
  }

  /// Typ-Auswahl aus `GestureDetector` + `Container` — kein `ListTile`
  /// (CanvasKit-Regel).
  void _typWaehlen(BuildContext context) {
    final router = GoRouter.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in EinsatzTyp.values)
              if (t != EinsatzTyp.termin)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(ctx);
                    _neu(router, t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Icon(einsatzTypIcon(t), color: einsatzTypFarbe(t), size: 22),
                        const SizedBox(width: 14),
                        Text(einsatzTypLabel(t), style: const TextStyle(fontSize: 15)),
                      ],
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

- [ ] **Step 5: Tests laufen lassen**

Run: `flutter test test/einsaetze_screen_test.dart`
Erwartet: BESTANDEN, 9 Tests.

Run: `flutter analyze`
Erwartet: 56 Befunde (Normalzustand), keine neuen.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/einsaetze/ test/einsaetze_screen_test.dart
git commit -m "feat: Einsaetze-Screen mit Typ-, Status-, Zeitraum- und Betriebsfilter (B2)"
```

---

### Task 7: Route und Kacheln

**Files:**
- Modify: `lib/core/config/router.dart` (Helfer neben `anlageIdsAusQuery`; Route vor `/reinigungen`)
- Modify: `lib/presentation/screens/home_screen.dart:139,146,153,162,169,261`
- Test: `test/einsatz_typ_query_test.dart`

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```dart
// test/einsatz_typ_query_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';

void main() {
  test('bekannter Typ wird erkannt', () {
    expect(einsatzTypAusQuery('stoerung'), EinsatzTyp.stoerung);
    expect(einsatzTypAusQuery('saisonreinigung'), EinsatzTyp.saisonreinigung);
  });

  test('fehlend oder unbekannt ergibt null — alle Typen', () {
    expect(einsatzTypAusQuery(null), isNull);
    expect(einsatzTypAusQuery(''), isNull);
    expect(einsatzTypAusQuery('irgendwas'), isNull);
  });
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/einsatz_typ_query_test.dart`
Erwartet: FEHLER — `einsatzTypAusQuery` nicht definiert.

- [ ] **Step 3: Helfer und Route**

In `router.dart` neben `anlageIdsAusQuery`:

```dart
/// `?typ=stoerung` auf dem Einsätze-Screen. Unbekannt oder fehlend heisst
/// «alle Typen» — ein Tippfehler in einem Link darf die Liste nicht leeren.
EinsatzTyp? einsatzTypAusQuery(String? wert) {
  if (wert == null || wert.isEmpty) return null;
  for (final t in EinsatzTyp.values) {
    if (t.name == wert) return t;
  }
  return null;
}
```

Import ergänzen: `import 'package:sbs_projer_app/core/util/einsatz.dart';` und `import 'package:sbs_projer_app/presentation/screens/einsaetze/einsaetze_screen.dart';`

Die Route, direkt vor `GoRoute(path: '/reinigungen', …)`:

```dart
    // Einsätze (B2) — eine Liste für alle Typen.
    GoRoute(
      path: '/einsaetze',
      builder: (context, state) => EinsaetzeScreen(
        vorgewaehlterTyp: einsatzTypAusQuery(state.uri.queryParameters['typ']),
      ),
    ),
```

- [ ] **Step 4: Kacheln umleiten**

In `home_screen.dart` die sechs `onTap`-Ziele ersetzen:

| Zeile | alt | neu |
|---|---|---|
| 139 | `context.push('/reinigungen')` | `context.push('/einsaetze?typ=reinigung')` |
| 146 | `context.push('/stoerungen')` | `context.push('/einsaetze?typ=stoerung')` |
| 153 | `context.push('/montagen')` | `context.push('/einsaetze?typ=montage')` |
| 162 | `context.push('/eigenauftraege')` | `context.push('/einsaetze?typ=eigenauftrag')` |
| 169 | `context.push('/eroeffnungsreinigungen')` | `context.push('/einsaetze?typ=saisonreinigung')` |
| 261 | `context.push('/pikett')` | `context.push('/einsaetze?typ=pikett')` |

Über dem Kachel-Block ein Kommentar:

```dart
        // Seit v0.105.0 (B2) führen die Einsatz-Kacheln auf den gemeinsamen
        // Einsätze-Screen mit vorgewähltem Typ. Die alten Listen bleiben bis
        // v0.106.0 unter ihren Routen erreichbar (test/alte_listen_ablauf_test.dart).
```

- [ ] **Step 5: Tests, Analyse, Commit**

Run: `flutter test test/einsatz_typ_query_test.dart && flutter analyze`
Erwartet: 2 Tests grün; 56 Befunde.

```bash
git add lib/core/config/router.dart lib/presentation/screens/home_screen.dart test/einsatz_typ_query_test.dart
git commit -m "feat: Route /einsaetze, Kacheln fuehren auf den gemeinsamen Screen (B2)"
```

---

### Task 8: Zwei Wächter — Ratsche und Ablauf

**Files:**
- Create: `test/status_vergleiche_ratsche_test.dart`
- Create: `test/alte_listen_ablauf_test.dart`

- [ ] **Step 1: Die Ratsche schreiben — zuerst mit Startwert 9999**

```dart
// test/status_vergleiche_ratsche_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratsche: Die verstreuten Statusvergleiche dürfen nur weniger werden.
///
/// WARUM: Sechs Einsatztypen tragen vier Status-Vokabulare. Seit B2 gibt es
/// eine Ableitung (`einsatz_status.dart`), aber rund 37 Stellen vergleichen
/// noch direkt (`status == 'behoben'`). Sie alle auf einmal umzubauen wäre
/// eine Grossaktion mit Risiko; sie einfach zu lassen hiesse, dass neue
/// dazukommen. Diese Ratsche schreibt den Stand fest — jeder, der eine
/// dieser Dateien anfasst, senkt die Zahl, und `anlage_detail_screen.dart:878`
/// (Störung == 'abgeschlossen', ein Wert, den Störungen nie tragen)
/// verschwindet, sobald jemand dort vorbeikommt.
///
/// Zählt nur Vergleiche der Einsatz-Vokabulare; `zahlungsstatus` der
/// Rechnungen und andere Statusfelder sind ausgenommen (kein Identifikator-
/// zeichen direkt vor `status`).
void main() {
  test('Statusvergleiche werden nicht mehr', () {
    // Startwert nach Umsetzung von B2 eingetragen. Nur senken.
    const erlaubt = 9999;

    final muster = RegExp(
      r"(?<![A-Za-z_])status\s*==\s*'(offen|geplant|in_bearbeitung|behoben|"
      r"abgeschlossen|abgerechnet|storniert|nicht_behebbar|abgebrochen|"
      r"nachbearbeitung_noetig|erledigt|vorgeschlagen|abgesagt)'",
    );
    const ausgenommen = {
      'lib/core/util/einsatz_status.dart',
      'lib/core/util/tour_filter.dart',
    };

    final treffer = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      if (ausgenommen.any(pfad.endsWith)) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final k = zeilen[i].indexOf('//');
        final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
        if (muster.hasMatch(code)) treffer.add('$pfad:${i + 1}');
      }
    }

    expect(
      treffer.length,
      lessThanOrEqualTo(erlaubt),
      reason:
          'Es gibt ${treffer.length} direkte Statusvergleiche, erlaubt sind '
          '$erlaubt. Neue Vergleiche gehoeren nicht in den Code — die Stufe '
          'liefert einsatz_status.dart. Wer eine Datei anfasst, stellt deren '
          'Vergleiche um und senkt den Wert hier.\n${treffer.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Startwert messen und eintragen**

Run: `flutter test test/status_vergleiche_ratsche_test.dart`
Erwartet: BESTANDEN (9999 ist hoch genug). Dann den echten Stand ermitteln — den Test einmal mit `const erlaubt = 0;` laufen lassen; die Fehlermeldung nennt die Zahl («Es gibt N direkte Statusvergleiche») und listet die Stellen. **Diese Zahl N eintragen**, Test erneut laufen lassen: BESTANDEN.

- [ ] **Step 3: Gegenprobe**

In irgendeiner Screen-Datei testweise eine Zeile `if (x.status == 'behoben') {}` einfügen, Test laufen lassen — muss FEHLSCHLAGEN mit N+1. Zeile wieder entfernen.

- [ ] **Step 4: Den Ablauf-Wächter schreiben**

```dart
// test/alte_listen_ablauf_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/app_version.dart';

/// Die sechs alten Listen-Screens bleiben nach B2 einen Auslieferungszyklus
/// als Rückfalltür erreichbar — und danach nicht mehr. Ohne dieses
/// Ablaufdatum blieben sie für immer: Niemand räumt auf, was nicht stört.
void main() {
  test('alte Listenrouten sind ab v0.106.0 entfernt', () {
    const ablaufAb = '0.106.0';
    if (_versionKleiner(kAppVersion, ablaufAb)) return; // noch Gnadenfrist

    final router = File('lib/core/config/router.dart').readAsStringSync();
    const alteRouten = [
      "path: '/reinigungen',",
      "path: '/stoerungen',",
      "path: '/montagen',",
      "path: '/eigenauftraege',",
      "path: '/eroeffnungsreinigungen',",
      "path: '/pikett',",
    ];
    final noch = alteRouten.where(router.contains).toList();
    expect(
      noch,
      isEmpty,
      reason:
          'Version $kAppVersion — die alten Listen sollten seit $ablaufAb '
          'weg sein. Noch vorhanden: $noch. Screens, Routen und ihre Tests '
          'entfernen; die Kacheln zeigen laengst auf /einsaetze.',
    );
  });
}

bool _versionKleiner(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i];
  }
  return false;
}
```

Run: `flutter test test/alte_listen_ablauf_test.dart`
Erwartet: BESTANDEN (Version 0.104.x/0.105.0 liegt vor dem Ablauf).

Gegenprobe: `ablaufAb` testweise auf `'0.100.0'` setzen → muss FEHLSCHLAGEN und die sechs Routen nennen. Zurücksetzen.

- [ ] **Step 5: Commit**

```bash
git add test/status_vergleiche_ratsche_test.dart test/alte_listen_ablauf_test.dart
git commit -m "test: Ratsche fuer Statusvergleiche und Ablauf der alten Listen (B2)"
```

---

### Task 9: Sichtprüfung, Version, Auslieferung, Doku

Macht der Koordinator selbst.

- [ ] **Step 1: Volle Suite und Analyse**

Run: `flutter analyze && flutter test`
Erwartet: 56 Befunde; alle Tests grün (vorher 1445 plus die neuen aus Task 1–8).

- [ ] **Step 2: Sichtprüfung im Browser**

Der Screen liegt hinter dem Login. Eine Wegwerf-Datei `lib/heute_probe.dart` (wie bei A1) rendert `EinsaetzeInhalt` mit gemischten Einsätzen aller sieben Typen, auch mit Kennzeichen, bei 360 px und bei 1400 px. Prüfen: Zeile passt, Badge lesbar, Störungs-Zusatzfilter erscheinen nur bei «Störung», Leerzustand, «+»-Sheet aus `GestureDetector`. Datei danach löschen, nie committen.

Was sich ohne Login nicht prüfen lässt und Daniel nach dem Deploy prüft: die Kachel öffnet den Screen mit vorgewähltem Typ; ein Tipp öffnet die richtige Detailseite; eine Tresen-Reinigung von heute zeigt «verrechnet» (Task 3 wirkt), eine geplante Störung «geplant».

- [ ] **Step 3: Version und Deploy**

`pubspec.yaml` Zeile 4 auf `0.105.0+748` **und** `kAppVersion` auf `'0.105.0'`; `flutter test test/app_version_test.dart`. Dann nach `CLAUDE.md`: Build mit `--base-href "/sbs-projer-dev/" --pwa-strategy=none`, Cache-Bust, `flutter_service_worker.js` löschen, `404.html` mitliefern, auf `gh-pages` ausliefern, Live-`version.json` prüfen.

- [ ] **Step 4: Doku**

- `ToDo.md`: B2 als erledigt mit dem Ratschen-Startwert; Hinweis, dass die alten Listen mit v0.106.0 fallen (der Wächter erinnert).
- `docs/app-analyse-2026-09.md`: B2 ✅ mit den zwei Abweichungen (fünf Stufen; Aufgaben-Screen bleibt für B6).
- Memory `app_analyse_2026_09.md`: Stand nachziehen.
- **Übergabe an die Heineken-Session** (Memory `projektuebergreifend_absprechen`): `einsatz_status.dart` ist die Spezifikation des Einsatz-Modells (C1) — dort nicht nachbauen, sondern übernehmen.

---

## Nach der Auslieferung

- [ ] Klicktest Daniel (siehe Task 9, Schritt 2).
- [ ] Beim nächsten Deploy nach v0.105.0: die sechs alten Listen samt Routen und Tests entfernen — spätestens, wenn `alte_listen_ablauf_test.dart` anschlägt.
- [ ] Bei jeder Datei aus der Ratschen-Liste, die ohnehin angefasst wird: Vergleiche auf `einsatz_status.dart` umstellen, Wert senken.
