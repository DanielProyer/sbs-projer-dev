import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/core/util/routen_punkt_key.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/presentation/providers/arbeitstag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Zusammenbau «Fahrten aus der Kette» je Monat (Task 3): aus den rohen
/// Monatsabfragen (Tagesplan, Einsätze, Wegpunkte) plus Betriebs- und
/// Distanz-Nachschlag entstehen die Tages-Fahrten.

/// Gleiche Werte wie `kStartorte` (tour_providers.dart) — die reine Regel
/// kennt nichts aus `presentation/`.
const startorte = <String, ({double lat, double lng})>{
  'domat_ems': (lat: 46.8328452, lng: 9.4529918),
  'chur': (lat: 46.8639692, lng: 9.5278708),
};

const betriebe = <String, BetriebOrt>{
  'betrieb-a': (name: 'Peppino', lat: 46.85, lng: 9.53),
  'betrieb-b': (name: 'Holländer', lat: 46.80, lng: 9.83),
  'betrieb-c': (name: 'Linden', lat: 46.86, lng: 9.50),
  'betrieb-x': (name: 'Ohne Koordinaten', lat: null, lng: null),
};

final tag = DateTime(2026, 9, 25);

/// Startort-Wahl wie `startortSchluessel`: nur bei Positionen, die hier
/// bewusst gesetzt sind; sonst `null` (→ Rückfall Domat/Ems).
String? startortFuer(({double lat, double lng})? p) {
  if (p == null) return null;
  if (p == startorte['chur']) return 'chur';
  if (p == startorte['domat_ems']) return 'domat_ems';
  return null;
}

TagesplanRoh plan({
  String? beginn = '07:30',
  String? ende = '17:00',
  int? kmStart = 50000,
  int? kmEnde = 50200,
  ({double lat, double lng})? start,
  ({double lat, double lng})? endPos,
}) => (
  beginn: beginn,
  ende: ende,
  kmStart: kmStart,
  kmEnde: kmEnde,
  startPosition: start,
  endPosition: endPos,
);

EinsatzRoh einsatz(
  String id,
  String? betriebId, {
  String typ = 'reinigung',
  String? von,
  String? bis,
  DateTime? datum,
}) => (
  id: id,
  typ: typ,
  betriebId: betriebId,
  datum: datum ?? tag,
  von: von,
  bis: bis,
);

/// Ein Wegpunkt-Stempel. Position standardmässig genau am Betrieb (nur
/// Stempel ≤ 300 m vom Betrieb zählen); [pos] setzt sie ausdrücklich,
/// [ohneGps] lässt sie weg.
StempelRoh stempel(
  DateTime zeitpunkt, {
  String quelle = 'stoerung',
  String? betriebId,
  String? referenzId,
  ({double lat, double lng})? pos,
  bool ohneGps = false,
}) {
  final b = betriebId == null ? null : betriebe[betriebId];
  final amBetrieb = (b == null || b.lat == null || b.lng == null)
      ? null
      : (lat: b.lat!, lng: b.lng!);
  final ort = ohneGps ? null : (pos ?? amBetrieb);
  return (
    zeitpunkt: zeitpunkt,
    quelle: quelle,
    betriebId: betriebId,
    referenzId: referenzId,
    lat: ort?.lat,
    lng: ort?.lng,
  );
}

/// ~200 m bzw. ~400 m nördlich von [p] (1° Breite ≈ 111 km).
({double lat, double lng}) nahBei(({double lat, double lng}) p) =>
    (lat: p.lat + 0.0018, lng: p.lng);
({double lat, double lng}) knappDaneben(({double lat, double lng}) p) =>
    (lat: p.lat + 0.0036, lng: p.lng);

({double lat, double lng}) ortVon(String betriebId) =>
    (lat: betriebe[betriebId]!.lat!, lng: betriebe[betriebId]!.lng!);

const zuerich = (lat: 47.37, lng: 8.54);

Map<DateTime, TagesFahrten> bauen({
  Map<DateTime, TagesplanRoh>? tagesplaene,
  List<EinsatzRoh> einsaetze = const [],
  List<StempelRoh> stempelListe = const [],
  Map<String, Map<String, double>> anfahrten = const {},
  Map<String, double> routen = const {},
  Map<String, double> punkte = const {},
}) => monatsFahrtenBauen(
  tagesplaene: tagesplaene ?? {tag: plan()},
  einsaetze: einsaetze,
  stempel: stempelListe,
  betriebe: betriebe,
  anfahrten: anfahrten,
  routen: routen,
  punkte: punkte,
  startorte: startorte,
  startortFuer: startortFuer,
);

/// Schlüssel im Punkt-Cache (`routen_punkte`) — bewusst ausgeschrieben statt
/// über `punktKey` gerechnet, damit das Format selbst geprüft ist.
const keyDomat = 'p:46.8328,9.4530';
const keyChur = 'p:46.8640,9.5279';
const keyZuerich = 'p:47.3700,8.5400';

/// Routen-Enden wie sie `fehlendeRoutenPaare` baut.
RoutenEnde betriebEnde(String id) => (betriebId: id, lat: null, lng: null);
RoutenEnde punktEnde(({double lat, double lng}) p) =>
    (betriebId: null, lat: p.lat, lng: p.lng);

/// Anfahrten ab Domat/Ems zu allen drei Betrieben mit Koordinaten — für
/// Tests, die nur die Betrieb→Betrieb-Aufträge ansehen.
const alleAnfahrten = {
  'domat_ems': {'betrieb-a': 12.0, 'betrieb-b': 30.0, 'betrieb-c': 8.0},
};

void main() {
  group('monatsFahrtenBauen — Beispieltag', () {
    // 2 Reinigungen, 1 Störung nur mit Stempel, Feierabend erfasst.
    final ergebnis = bauen(
      tagesplaene: {tag: plan(start: startorte['domat_ems'])},
      einsaetze: [
        einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
        einsatz('r2', 'betrieb-b', von: '10:00:00', bis: '11:00:00'),
        einsatz('s1', 'betrieb-c', typ: 'stoerung'),
      ],
      stempelListe: [
        stempel(DateTime(2026, 9, 25, 13, 15), betriebId: 'betrieb-c'),
      ],
      anfahrten: {
        'domat_ems': {'betrieb-a': 12.0, 'betrieb-c': 8.0},
      },
      // Nur die Gegenrichtung gespeichert — der Nachschlag prüft beide.
      routen: {'betrieb-b>betrieb-a': 20.0},
    );
    final t = ergebnis[tag]!;

    test('vier Fahrten in der richtigen Reihenfolge', () {
      expect(t.fahrten.length, 4);
      expect(t.fahrten.map((f) => '${f.von.id}>${f.nach.id}').toList(), [
        'domat_ems>betrieb-a',
        'betrieb-a>betrieb-b',
        'betrieb-b>betrieb-c',
        'betrieb-c>domat_ems',
      ]);
      expect(t.fahrten[1].von.name, 'Peppino');
      expect(t.fahrten[1].nach.name, 'Holländer');
    });

    test('km-Quellen: Anfahrt, Route (Gegenrichtung), ohne Route, Heimweg', () {
      expect(t.fahrten[0].km, 12.0);
      expect(t.fahrten[0].kmQuelle, kKmQuelleAnfahrt);
      expect(t.fahrten[1].km, 20.0);
      expect(t.fahrten[1].kmQuelle, kKmQuelleRoute);
      // b → c ist (noch) nicht geroutet: keine km, keine Schätzung.
      expect(t.fahrten[2].km, isNull);
      expect(t.fahrten[2].kmQuelle, isNull);
      // Heimweg Betrieb → Startort: Anfahrt in umgekehrter Richtung.
      expect(t.fahrten[3].km, 8.0);
      expect(t.fahrten[3].kmQuelle, kKmQuelleAnfahrt);
    });

    test('Zeiten: Störung als Punkt-Halt aus dem Stempel', () {
      expect(t.fahrten[2].abfahrtMin, 11 * 60);
      expect(t.fahrten[2].ankunftMin, 13 * 60 + 15);
      expect(t.fahrten[3].abfahrtMin, 13 * 60 + 15);
      expect(t.fahrten[3].ankunftMin, 17 * 60);
      expect(t.fahrten[2].nach.quelle, 'wegpunkt');
    });

    test('Befunde: Zähler-Kontrolle wartet auf die fehlende Strecke', () {
      expect(t.kmZaehler, 200);
      expect(t.kmFahrten, 40); // 12 + 20 + 8, ohne b → c
      expect(t.fahrtenOhneKm, 1);
      expect(t.differenz, isNull);
      expect(t.befunde, [
        'Zähler-Kontrolle erst, wenn alle Fahrten eine Strecke haben',
        '1 Fahrt noch ohne geroutete Strecke',
      ]);
      expect(t.ohneZeit, isEmpty);
    });

    test('ist die Route da, kommt die Zähler-Kontrolle', () {
      final mitRoute = bauen(
        tagesplaene: {tag: plan(start: startorte['domat_ems'])},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00:00', bis: '11:00:00'),
          einsatz('s1', 'betrieb-c', typ: 'stoerung'),
        ],
        stempelListe: [
          stempel(DateTime(2026, 9, 25, 13, 15), betriebId: 'betrieb-c'),
        ],
        anfahrten: {
          'domat_ems': {'betrieb-a': 12.0, 'betrieb-c': 8.0},
        },
        routen: {'betrieb-b>betrieb-a': 20.0, 'betrieb-b>betrieb-c': 30.0},
      )[tag]!;
      expect(mitRoute.kmVollstaendig, isTrue);
      expect(mitRoute.kmFahrten, 70);
      expect(mitRoute.differenz, 130);
      expect(mitRoute.befunde, [
        'Zähler 200 km, Fahrten 70 km — 130 km unerklärt '
            '(privat oder Umweg?)',
      ]);
    });
  });

  group('monatsFahrtenBauen — Stempel', () {
    test('Stempel über referenz_id geht dem Betriebs-Stempel vor', () {
      final t = bauen(
        einsaetze: [einsatz('m1', 'betrieb-b', typ: 'montage')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 9, 10),
            quelle: 'montage',
            betriebId: 'betrieb-b',
          ),
          stempel(
            DateTime(2026, 9, 25, 14, 20),
            quelle: 'montage',
            betriebId: 'betrieb-b',
            referenzId: 'm1',
          ),
        ],
      )[tag]!;
      expect(t.fahrten[0].ankunftMin, 14 * 60 + 20);
    });

    test('mehrere Betriebs-Stempel: der früheste zählt', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(DateTime(2026, 9, 25, 15, 0), betriebId: 'betrieb-b'),
          stempel(DateTime(2026, 9, 25, 10, 5), betriebId: 'betrieb-b'),
        ],
      )[tag]!;
      expect(t.fahrten[0].ankunftMin, 10 * 60 + 5);
    });

    test('Stempel einer anderen Einsatzart am selben Betrieb zählt nicht', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 5),
            quelle: 'montage',
            betriebId: 'betrieb-b',
          ),
        ],
      )[tag]!;
      expect(t.ohneZeit.map((e) => e.einsatzId), ['s1']);
      expect(t.befunde, contains('1 Einsatz ohne Zeit — nicht in den Fahrten'));
    });

    test('Stempel vom Vortag zählt nicht', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(DateTime(2026, 9, 24, 16, 0), betriebId: 'betrieb-b'),
        ],
      )[tag]!;
      expect(t.ohneZeit.length, 1);
      // Morgens und abends derselbe Startort — keine Fahrt.
      expect(t.fahrten, isEmpty);
    });

    test('Störung ohne Zeit und ohne Stempel landet in ohneZeit mit Namen', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-c', typ: 'stoerung')],
      )[tag]!;
      expect(t.ohneZeit.single.betriebName, 'Linden');
      expect(t.ohneZeit.single.typ, 'stoerung');
    });
  });

  group('monatsFahrtenBauen — Startorte und Tage', () {
    test('Startort je Position, ohne Endposition Rückfall Domat/Ems', () {
      final t = bauen(
        tagesplaene: {tag: plan(start: startorte['chur'])},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
      )[tag]!;
      expect(t.fahrten.first.von.id, 'chur');
      expect(t.fahrten.first.von.name, 'Chur');
      expect(t.fahrten.last.nach.id, 'domat_ems');
    });

    test('ohne GPS beim Arbeitsbeginn → Rückfall Domat/Ems, kein Befund', () {
      final t = bauen(
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
      )[tag]!;
      expect(t.fahrten.first.von.id, 'domat_ems');
      expect(t.befunde.where((b) => b.contains('nicht am Startort')), isEmpty);
    });

    test('ohne Feierabend kein Heimweg, Befund', () {
      final t = bauen(
        tagesplaene: {tag: plan(ende: null, kmEnde: null)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
      )[tag]!;
      expect(t.fahrten.length, 1);
      expect(t.befunde, contains('Kein Feierabend erfasst — Heimweg fehlt'));
      expect(
        t.befunde,
        contains('Zählerstand fehlt — keine Kontrolle möglich'),
      );
    });

    test('Tag nur mit Einsätzen (kein Tagesplan) erscheint mit Befunden', () {
      final ergebnis = bauen(
        tagesplaene: const {},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-c', von: '10:00', bis: '10:30'),
        ],
      );
      final t = ergebnis[tag]!;
      expect(t.fahrten.length, 1); // a → c, ohne Startorte
      expect(t.befunde, contains('Kein Arbeitsbeginn erfasst — Anfahrt fehlt'));
      expect(t.befunde, contains('Kein Feierabend erfasst — Heimweg fehlt'));
    });

    test('leere Tagesplan-Zeile (nur geplant) ergibt keinen Tag', () {
      final ergebnis = bauen(
        tagesplaene: {
          DateTime(2026, 9, 30): plan(
            beginn: null,
            ende: null,
            kmStart: null,
            kmEnde: null,
          ),
        },
      );
      expect(ergebnis, isEmpty);
    });

    test('Tagesschlüssel ohne Uhrzeit, Einsätze nach Tag getrennt', () {
      final ergebnis = bauen(
        tagesplaene: {DateTime(2026, 9, 25, 0, 0): plan()},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz(
            'r2',
            'betrieb-b',
            von: '08:00',
            bis: '09:00',
            datum: DateTime(2026, 9, 26),
          ),
        ],
      );
      expect(ergebnis.keys.toSet(), {tag, DateTime(2026, 9, 26)});
      expect(ergebnis[tag]!.fahrten.length, 2);
      expect(ergebnis[DateTime(2026, 9, 26)]!.fahrten, isEmpty);
    });

    test('Einsatz ohne Betrieb: Fahrt ohne Distanz', () {
      final t = bauen(
        einsaetze: [einsatz('s1', null, typ: 'stoerung', von: '09:00')],
      )[tag]!;
      expect(t.fahrten.length, 2);
      expect(t.fahrten.first.nach.name, 'Störung');
      expect(t.fahrten.first.km, isNull);
      expect(
        t.befunde,
        contains('2 Fahrten ohne Distanz (Koordinaten fehlen)'),
      );
    });
  });

  // Störungs-/Montage-Stempel entstehen beim Abschliessen — oft abends
  // zuhause (17 von 28 Störungs-Stempeln in Domat/Ems, Stand 27.09.2026).
  // Ein solcher Stempel ist keine Ankunftszeit am Betrieb.
  group('monatsFahrtenBauen — Stempel nur am Betrieb (≤ 300 m)', () {
    List<String> ohneZeitIds(TagesFahrten t) =>
        t.ohneZeit.map((e) => e.einsatzId).toList();

    test('Stempel ~200 m vom Betrieb → Punkt-Halt', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 11, 20),
            betriebId: 'betrieb-b',
            pos: nahBei(ortVon('betrieb-b')),
          ),
        ],
      )[tag]!;
      expect(t.ohneZeit, isEmpty);
      expect(t.fahrten.first.nach.id, 'betrieb-b');
      expect(t.fahrten.first.ankunftMin, 11 * 60 + 20);
      expect(t.fahrten.first.nach.quelle, 'wegpunkt');
    });

    // Keine Fahrt, und auch kein «nach Feierabend»-Befund: Der Einsatz ist
    // gar nicht in der Kette.
    test('Stempel 19:56 zuhause → ohne Zeit', () {
      final t = bauen(
        tagesplaene: {tag: plan(ende: '17:30')},
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 19, 56),
            betriebId: 'betrieb-b',
            pos: startorte['domat_ems'],
          ),
        ],
      )[tag]!;
      expect(ohneZeitIds(t), ['s1']);
      expect(t.fahrten, isEmpty); // Domat/Ems → Domat/Ems
      expect(t.befunde.where((b) => b.contains('Zeit prüfen')), isEmpty);
    });

    test('Stempel ohne GPS → ohne Zeit', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 11, 20),
            betriebId: 'betrieb-b',
            ohneGps: true,
          ),
        ],
      )[tag]!;
      expect(ohneZeitIds(t), ['s1']);
    });

    test('Stempel ~400 m daneben → ohne Zeit', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 11, 20),
            betriebId: 'betrieb-b',
            pos: knappDaneben(ortVon('betrieb-b')),
          ),
        ],
      )[tag]!;
      expect(ohneZeitIds(t), ['s1']);
    });

    test('früher Stempel weit weg, späterer nah: der nahe zählt', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 9, 0),
            betriebId: 'betrieb-b',
            pos: startorte['domat_ems'],
          ),
          stempel(
            DateTime(2026, 9, 25, 11, 30),
            betriebId: 'betrieb-b',
            pos: nahBei(ortVon('betrieb-b')),
          ),
        ],
      )[tag]!;
      expect(t.ohneZeit, isEmpty);
      expect(t.fahrten.first.ankunftMin, 11 * 60 + 30);
    });

    test('auch ein Referenz-Stempel muss am Betrieb liegen', () {
      final t = bauen(
        einsaetze: [einsatz('m1', 'betrieb-b', typ: 'montage')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 18, 40),
            quelle: 'montage',
            referenzId: 'm1',
            pos: startorte['domat_ems'],
          ),
        ],
      )[tag]!;
      expect(ohneZeitIds(t), ['m1']);
    });

    test('Einsatz ohne Betrieb / Betrieb ohne Koordinaten → ohne Zeit', () {
      final t = bauen(
        einsaetze: [
          einsatz('s1', null, typ: 'stoerung'),
          einsatz('s2', 'betrieb-x', typ: 'stoerung'),
        ],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 0),
            referenzId: 's1',
            pos: ortVon('betrieb-a'),
          ),
          stempel(
            DateTime(2026, 9, 25, 11, 0),
            betriebId: 'betrieb-x',
            pos: ortVon('betrieb-a'),
          ),
        ],
      )[tag]!;
      expect(ohneZeitIds(t), ['s1', 's2']);
    });

    test('Zähler-Befund nennt die Einsätze ohne Zeit als mögliche Ursache', () {
      final t = bauen(
        tagesplaene: {tag: plan(kmStart: 50000, kmEnde: 50060)},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('s1', 'betrieb-b', typ: 'stoerung'),
          einsatz('s2', 'betrieb-c', typ: 'stoerung'),
        ],
        anfahrten: {
          'domat_ems': {'betrieb-a': 10.0},
        },
      )[tag]!;
      expect(
        t.befunde.first,
        'Zähler 60 km, Fahrten 20 km — 40 km unerklärt (privat oder '
        'Umweg?), davon evtl. 2 Einsätze ohne Zeit',
      );
    });
  });

  // An 6 von 33 Tagen lag die Startposition > 5 km von beiden Startorten
  // (z. B. 18.09. 05:38, 82 km von zuhause, 0,8 km vom ersten Betrieb).
  // Domat/Ems anzunehmen erfand dort ~100 km Anfahrt.
  group('monatsFahrtenBauen — Arbeitsbeginn/Feierabend unterwegs', () {
    List<String> wege(TagesFahrten t) =>
        t.fahrten.map((f) => '${f.von.id}>${f.nach.id}').toList();

    test('Arbeitsbeginn fern von Startorten → Halt an der GPS-Position', () {
      final t = bauen(
        tagesplaene: {tag: plan(start: zuerich)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
        // Die Anfahrt ab Domat/Ems darf nicht greifen — er startete anderswo.
        anfahrten: {
          'domat_ems': {'betrieb-a': 12.0},
        },
      )[tag]!;
      final erste = t.fahrten.first;
      expect(erste.von.id, kGpsStartId);
      expect(erste.von.name, 'Arbeitsbeginn unterwegs');
      expect(erste.von.typ, HaltTyp.startort);
      expect(erste.von.lat, zuerich.lat);
      expect(erste.von.abfahrtMin, 7 * 60 + 30);
      expect(erste.nach.id, 'betrieb-a');
      // Ab einer GPS-Position gibt es keine Anfahrtszeit; ohne Punkt-Route
      // bleibt die Fahrt ohne km (routbar ist sie seit Migration 213).
      expect(erste.km, isNull);
      expect(erste.kmQuelle, isNull);
      expect(t.befunde, contains('Arbeitsbeginn nicht am Startort'));
      expect(t.befunde, contains('1 Fahrt noch ohne geroutete Strecke'));
      expect(t.befunde.where((b) => b.contains('Anfahrtszeiten')), isEmpty);
      expect(t.differenz, isNull); // Zähler da, aber eine Strecke fehlt
      // Der Heimweg a → Domat/Ems hat seine Anfahrt (rückwärts).
      expect(t.fahrten.last.km, 12.0);
    });

    test('Arbeitsbeginn unterwegs mit Punkt-Route → km und Kontrolle', () {
      final t = bauen(
        tagesplaene: {tag: plan(start: zuerich, kmEnde: 50140)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
        anfahrten: {
          'domat_ems': {'betrieb-a': 12.0},
        },
        // Gespeichert in der Gegenrichtung — der Nachschlag prüft beide.
        punkte: {'b:betrieb-a>$keyZuerich': 125.3},
      )[tag]!;
      expect(t.fahrten.first.km, 125.3);
      expect(t.fahrten.first.kmQuelle, kKmQuelleRoute);
      expect(t.kmVollstaendig, isTrue);
      expect(t.kmFahrten, 137.3);
      expect(t.differenz, closeTo(2.7, 1e-9));
      expect(t.befunde, ['Arbeitsbeginn nicht am Startort']);
    });

    test('Arbeitsbeginn ≤ 300 m vom ersten Betrieb → keine Anfahrt', () {
      final t = bauen(
        tagesplaene: {tag: plan(start: nahBei(ortVon('betrieb-b')))},
        einsaetze: [
          einsatz('r1', 'betrieb-b', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-c', von: '10:00', bis: '10:30'),
        ],
      )[tag]!;
      expect(wege(t), ['betrieb-b>betrieb-c', 'betrieb-c>domat_ems']);
      expect(
        t.befunde,
        contains('Arbeitsbeginn nicht am Startort — bei Holländer'),
      );
    });

    test('Feierabend fern von Startorten → Halt an der GPS-Position', () {
      final t = bauen(
        tagesplaene: {
          tag: plan(start: startorte['domat_ems'], endPos: zuerich),
        },
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
        anfahrten: {
          'domat_ems': {'betrieb-a': 12.0},
        },
      )[tag]!;
      expect(t.fahrten.first.kmQuelle, kKmQuelleAnfahrt); // morgens normal
      final letzte = t.fahrten.last;
      expect(letzte.nach.id, kGpsEndeId);
      expect(letzte.nach.name, 'Feierabend unterwegs');
      expect(letzte.nach.ankunftMin, 17 * 60);
      expect(letzte.km, isNull);
      expect(letzte.kmQuelle, isNull);
      expect(t.befunde, contains('Feierabend nicht am Startort'));
    });

    test('Feierabend ≤ 300 m vom letzten Betrieb → kein Heimweg', () {
      final t = bauen(
        tagesplaene: {
          tag: plan(
            start: startorte['domat_ems'],
            endPos: nahBei(ortVon('betrieb-b')),
          ),
        },
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00', bis: '10:30'),
        ],
      )[tag]!;
      expect(wege(t), ['domat_ems>betrieb-a', 'betrieb-a>betrieb-b']);
      expect(
        t.befunde,
        contains('Feierabend nicht am Startort — bei Holländer'),
      );
    });

    test('ohne Zeit für Arbeitsbeginn kein «unterwegs»-Befund', () {
      final t = bauen(
        tagesplaene: {tag: plan(beginn: null, start: zuerich)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
      )[tag]!;
      expect(t.befunde, isNot(contains('Arbeitsbeginn nicht am Startort')));
      expect(t.befunde, contains('Kein Arbeitsbeginn erfasst — Anfahrt fehlt'));
    });
  });

  group('monatsFahrtenBauen — Tage ohne Einsätze, Zeiten ausserhalb', () {
    test('Einsatz-Stempel nach Feierabend → «Zeit prüfen»', () {
      final t = bauen(
        tagesplaene: {tag: plan(ende: '17:30')},
        einsaetze: [einsatz('s1', 'betrieb-b', typ: 'stoerung')],
        stempelListe: [
          stempel(DateTime(2026, 9, 25, 19, 56), betriebId: 'betrieb-b'),
        ],
      )[tag]!;
      expect(
        t.befunde,
        contains(
          'Einsatz 19:56 bei Holländer nach Feierabend 17:30 — Zeit prüfen',
        ),
      );
    });

    test('Reinigung vor Arbeitsbeginn → «Zeit prüfen»', () {
      final t = bauen(
        tagesplaene: {tag: plan(beginn: '07:00')},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '06:10', bis: '06:50')],
      )[tag]!;
      expect(
        t.befunde,
        contains(
          'Einsatz 06:10 bei Peppino vor Arbeitsbeginn 07:00 — Zeit prüfen',
        ),
      );
    });

    test('Tag ohne Einsätze: keine Fahrt, Zähler-km unerklärt', () {
      final t = bauen(
        tagesplaene: {
          tag: plan(
            start: startorte['domat_ems'],
            endPos: startorte['domat_ems'],
            kmEnde: 50040,
          ),
        },
      )[tag]!;
      expect(t.fahrten, isEmpty);
      expect(t.kmFahrten, 0);
      expect(t.befunde, [
        'Zähler 40 km, Fahrten 0 km — 40 km unerklärt (privat oder Umweg?)',
      ]);
    });

    test('zwei Startorte ohne Einsätze: Domat/Ems → Chur ohne Strecke', () {
      final t = bauen(
        tagesplaene: {
          tag: plan(
            start: startorte['domat_ems'],
            endPos: startorte['chur'],
            kmEnde: null,
          ),
        },
      )[tag]!;
      final f = t.fahrten.single;
      expect(f.von.id, 'domat_ems');
      expect(f.nach.id, 'chur');
      expect(f.km, isNull);
      expect(f.kmQuelle, isNull);
      expect(t.befunde, contains('1 Fahrt noch ohne geroutete Strecke'));
      expect(t.befunde.where((b) => b.contains('Anfahrtszeiten')), isEmpty);
    });

    test('Domat/Ems → Chur mit Punkt-Route: km aus routen_punkte', () {
      final t = bauen(
        tagesplaene: {
          tag: plan(
            start: startorte['domat_ems'],
            endPos: startorte['chur'],
            kmEnde: 50010,
          ),
        },
        punkte: {'$keyDomat>$keyChur': 9.8},
      )[tag]!;
      expect(t.fahrten.single.km, 9.8);
      expect(t.fahrten.single.kmQuelle, kKmQuelleRoute);
      expect(t.befunde, isEmpty); // Zähler 10, Fahrten 9.8
    });
  });

  // Leerfahrt («War geschlossen»): kein Einsatz, aber ein Besuch vor Ort —
  // der Wegpunkt `quelle='vergeblich'` ist ein Punkt-Halt.
  group('monatsFahrtenBauen — Leerfahrt', () {
    test('Leerfahrt-Stempel am Betrieb ist ein Punkt-Halt', () {
      final t = bauen(
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 15),
            quelle: 'vergeblich',
            betriebId: 'betrieb-c',
          ),
        ],
      )[tag]!;
      expect(t.fahrten.map((f) => '${f.von.id}>${f.nach.id}').toList(), [
        'domat_ems>betrieb-a',
        'betrieb-a>betrieb-c',
        'betrieb-c>domat_ems',
      ]);
      expect(t.fahrten[1].nach.name, 'Linden');
      expect(t.fahrten[1].ankunftMin, 10 * 60 + 15);
      expect(t.ohneZeit, isEmpty);
    });

    test('Leerfahrt-Stempel weit weg vom Betrieb → ohne Zeit', () {
      final t = bauen(
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 19, 0),
            quelle: 'vergeblich',
            betriebId: 'betrieb-c',
            pos: startorte['domat_ems'],
          ),
        ],
      )[tag]!;
      expect(t.ohneZeit.single.typ, 'vergeblich');
      expect(t.ohneZeit.single.betriebName, 'Linden');
    });

    test('Leerfahrt gibt keinem Einsatz am selben Betrieb die Zeit', () {
      final t = bauen(
        einsaetze: [einsatz('s1', 'betrieb-c', typ: 'stoerung')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 15),
            quelle: 'vergeblich',
            betriebId: 'betrieb-c',
          ),
        ],
      )[tag]!;
      expect(t.ohneZeit.map((e) => e.einsatzId), ['s1']);
      expect(t.fahrten.map((f) => f.nach.id), ['betrieb-c', 'domat_ems']);
    });

    test('Tag nur mit einer Leerfahrt (ohne Tagesplan) erscheint', () {
      final ergebnis = bauen(
        tagesplaene: const {},
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 0),
            quelle: 'vergeblich',
            betriebId: 'betrieb-c',
          ),
        ],
      );
      expect(ergebnis.keys, [tag]);
      expect(ergebnis[tag]!.fahrten, isEmpty); // nur ein Halt
    });
  });

  group('kmNachschlagAus', () {
    final km = kmNachschlagAus(
      anfahrten: {
        'chur': {'betrieb-a': 5.5},
      },
      routen: {'betrieb-a>betrieb-b': 31.2},
      punkte: const {},
    );
    const chur = Halt(
      typ: HaltTyp.startort,
      id: 'chur',
      name: 'Chur',
      quelle: 'arbeitsbeginn',
    );
    const a = Halt(
      typ: HaltTyp.betrieb,
      id: 'betrieb-a',
      name: 'A',
      quelle: 'reinigung',
    );
    const b = Halt(
      typ: HaltTyp.betrieb,
      id: 'betrieb-b',
      name: 'B',
      quelle: 'reinigung',
    );

    test('Startort ↔ Betrieb in beiden Richtungen aus den Anfahrten', () {
      expect(km(chur, a), (km: 5.5, quelle: kKmQuelleAnfahrt));
      expect(km(a, chur), (km: 5.5, quelle: kKmQuelleAnfahrt));
    });

    test('Betrieb ↔ Betrieb in beiden Richtungen aus den Routen', () {
      expect(km(a, b), (km: 31.2, quelle: kKmQuelleRoute));
      expect(km(b, a), (km: 31.2, quelle: kKmQuelleRoute));
    });

    test('ohne Eintrag null (dann bleibt die Fahrt ohne km)', () {
      expect(km(chur, b), isNull);
      const domat = Halt(
        typ: HaltTyp.startort,
        id: 'domat_ems',
        name: 'Domat/Ems',
        quelle: 'feierabend',
      );
      expect(km(chur, domat), isNull);
    });

    // Punkt-Routen (Migration 213): für JEDES Paar mit Koordinaten, nach
    // Anfahrten und Betriebs-Routen. Schlüssel 'b:<id>' / 'p:<lat>,<lng>'.
    group('Punkt-Routen', () {
      Halt ort(
        String id,
        HaltTyp typ,
        ({double lat, double lng}) p, [
        String quelle = 'reinigung',
      ]) => Halt(
        typ: typ,
        id: id,
        name: id,
        lat: p.lat,
        lng: p.lng,
        quelle: quelle,
      );
      final domat = ort(
        'domat_ems',
        HaltTyp.startort,
        startorte['domat_ems']!,
        'arbeitsbeginn',
      );
      final churP = ort(
        'chur',
        HaltTyp.startort,
        startorte['chur']!,
        'feierabend',
      );
      final gps = ort(kGpsStartId, HaltTyp.startort, zuerich, 'arbeitsbeginn');
      final aP = ort('betrieb-a', HaltTyp.betrieb, ortVon('betrieb-a'));
      final bP = ort('betrieb-b', HaltTyp.betrieb, ortVon('betrieb-b'));

      final mitPunkten = kmNachschlagAus(
        anfahrten: {
          'domat_ems': {'betrieb-a': 12.0},
        },
        routen: {'betrieb-a>betrieb-b': 31.2},
        punkte: {
          '$keyZuerich>b:betrieb-a': 125.3,
          '$keyDomat>$keyChur': 9.8,
          '$keyChur>b:betrieb-b': 28.4,
          // Konkurriert mit der Anfahrt Domat/Ems → a (die gewinnt).
          '$keyDomat>b:betrieb-a': 99.9,
          // Konkurriert mit der Betriebs-Route a → b (die gewinnt).
          'b:betrieb-a>b:betrieb-b': 77.7,
        },
      );

      test('GPS-Position → Betrieb', () {
        expect(mitPunkten(gps, aP), (km: 125.3, quelle: kKmQuelleRoute));
        // Gegenrichtung (Feierabend unterwegs am selben Ort).
        expect(mitPunkten(aP, gps), (km: 125.3, quelle: kKmQuelleRoute));
      });

      test('Startort → Startort', () {
        expect(mitPunkten(domat, churP), (km: 9.8, quelle: kKmQuelleRoute));
        expect(mitPunkten(churP, domat), (km: 9.8, quelle: kKmQuelleRoute));
      });

      test('Startort → Betrieb ohne Anfahrt, aber mit Punkt-Route', () {
        expect(mitPunkten(churP, bP), (km: 28.4, quelle: kKmQuelleRoute));
        expect(mitPunkten(bP, churP), (km: 28.4, quelle: kKmQuelleRoute));
      });

      test('Anfahrt hat Vorrang vor der Punkt-Route', () {
        expect(mitPunkten(domat, aP), (km: 12.0, quelle: kKmQuelleAnfahrt));
        expect(mitPunkten(aP, domat), (km: 12.0, quelle: kKmQuelleAnfahrt));
      });

      test('Betriebs-Route hat Vorrang vor der Punkt-Route', () {
        expect(mitPunkten(aP, bP), (km: 31.2, quelle: kKmQuelleRoute));
      });

      test('ohne Koordinaten kein Punkt-Nachschlag', () {
        // Dieselben Ids, aber ohne lat/lng — der Schlüssel fehlt.
        expect(mitPunkten(chur, b), isNull);
      });
    });
  });

  // Seit Migration 213 routet `fahrzeit-route` auch Punkte: JEDE Fahrt ohne
  // km mit Koordinaten an beiden Enden ist ein Auftrag — Betrieb als Id,
  // Startort und GPS-Position als lat/lng.
  group('fehlendeRoutenPaare', () {
    test('Betrieb→Betrieb und Anfahrt ohne km, je Paar einmal', () {
      final ergebnis = bauen(
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00', bis: '11:00'),
          einsatz('r3', 'betrieb-a', von: '12:00', bis: '13:00'),
          einsatz('r4', 'betrieb-c', von: '14:00', bis: '15:00'),
          einsatz('r5', 'betrieb-x', von: '16:00', bis: '16:30'),
        ],
        routen: {'betrieb-c>betrieb-a': 4.0},
      );
      // domat→a: Anfahrt ohne Eintrag → Punkt → Betrieb; a→b und b→a sind
      // dasselbe Paar; a→c ist geroutet; c→x und x→domat: x hat keine
      // Koordinaten.
      expect(fehlendeRoutenPaare(ergebnis.values), [
        (
          von: punktEnde(startorte['domat_ems']!),
          nach: betriebEnde('betrieb-a'),
          schluessel: 'b:betrieb-a|$keyDomat',
        ),
        (
          von: betriebEnde('betrieb-a'),
          nach: betriebEnde('betrieb-b'),
          schluessel: 'b:betrieb-a|b:betrieb-b',
        ),
      ]);
    });

    test('GPS-Fahrt, Leerfahrt und Heimweg sind Aufträge', () {
      final ergebnis = bauen(
        tagesplaene: {tag: plan(start: zuerich)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
        stempelListe: [
          stempel(
            DateTime(2026, 9, 25, 10, 15),
            quelle: 'vergeblich',
            betriebId: 'betrieb-c',
          ),
        ],
      );
      final t = ergebnis[tag]!;
      expect(t.fahrten.map((f) => '${f.von.id}>${f.nach.id}').toList(), [
        '$kGpsStartId>betrieb-a',
        'betrieb-a>betrieb-c',
        'betrieb-c>domat_ems',
      ]);
      expect(fehlendeRoutenPaare(ergebnis.values), [
        (
          von: punktEnde(zuerich),
          nach: betriebEnde('betrieb-a'),
          schluessel: 'b:betrieb-a|$keyZuerich',
        ),
        (
          von: betriebEnde('betrieb-a'),
          nach: betriebEnde('betrieb-c'),
          schluessel: 'b:betrieb-a|b:betrieb-c',
        ),
        (
          von: betriebEnde('betrieb-c'),
          nach: punktEnde(startorte['domat_ems']!),
          schluessel: 'b:betrieb-c|$keyDomat',
        ),
      ]);
    });

    test('Startort → Startort ist ein Auftrag mit zwei Punkten', () {
      final ergebnis = bauen(
        tagesplaene: {
          tag: plan(start: startorte['domat_ems'], endPos: startorte['chur']),
        },
      );
      expect(fehlendeRoutenPaare(ergebnis.values), [
        (
          von: punktEnde(startorte['domat_ems']!),
          nach: punktEnde(startorte['chur']!),
          schluessel: '$keyDomat|$keyChur',
        ),
      ]);
    });

    test('Fahrten mit km und ohne Koordinaten sind keine Aufträge', () {
      final ergebnis = bauen(
        tagesplaene: {tag: plan(start: zuerich)},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          // Einsatz ohne Betrieb und Betrieb ohne Koordinaten.
          einsatz('s1', null, typ: 'stoerung', von: '10:00'),
          einsatz('r2', 'betrieb-x', von: '11:00', bis: '11:30'),
        ],
        punkte: {'$keyZuerich>b:betrieb-a': 125.3},
      );
      expect(ergebnis[tag]!.fahrten.first.km, 125.3);
      expect(fehlendeRoutenPaare(ergebnis.values), isEmpty);
    });

    test('ein Auftrag je Paar, auch in beiden Richtungen', () {
      final ergebnis = bauen(
        // Beginn und Feierabend an derselben GPS-Position.
        tagesplaene: {tag: plan(start: zuerich, endPos: zuerich)},
        einsaetze: [einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00')],
      );
      expect(ergebnis[tag]!.fahrten, hasLength(2));
      expect(fehlendeRoutenPaare(ergebnis.values), [
        (
          von: punktEnde(zuerich),
          nach: betriebEnde('betrieb-a'),
          schluessel: 'b:betrieb-a|$keyZuerich',
        ),
      ]);
    });

    // Seit 29.09.2026 zeigt eine Fahrt ohne Route gar keine km — routen
    // lohnt sich also überall. Die Tage mit Zählerstand kommen zuerst: Dort
    // wartet eine Kontrolle auf die Strecke.
    test('auch Tage ohne Zählerstand', () {
      final ohneZaehler = bauen(
        tagesplaene: {tag: plan(kmEnde: null)},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00', bis: '11:00'),
        ],
        anfahrten: alleAnfahrten,
      );
      expect(ohneZaehler[tag]!.kmZaehler, isNull);
      expect(fehlendeRoutenPaare(ohneZaehler.values).map((p) => p.schluessel), [
        'b:betrieb-a|b:betrieb-b',
      ]);
    });

    test('Tage mit Zählerstand zuerst, sonst in der übergebenen Folge', () {
      final t26 = DateTime(2026, 9, 26), t27 = DateTime(2026, 9, 27);
      final ergebnis = bauen(
        tagesplaene: {
          tag: plan(kmEnde: null), // 25.: ohne Zähler
          t26: plan(), // 26.: mit Zähler
          t27: plan(kmEnde: null), // 27.: ohne Zähler
        },
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00', bis: '11:00'),
          einsatz('r3', 'betrieb-b', von: '08:00', bis: '09:00', datum: t26),
          einsatz('r4', 'betrieb-c', von: '10:00', bis: '11:00', datum: t26),
          einsatz('r5', 'betrieb-c', von: '08:00', bis: '09:00', datum: t27),
          einsatz('r6', 'betrieb-a', von: '10:00', bis: '11:00', datum: t27),
        ],
        anfahrten: alleAnfahrten,
      );
      // Neueste zuerst übergeben (wie der Provider).
      final paare = fehlendeRoutenPaare([
        ergebnis[t27]!,
        ergebnis[t26]!,
        ergebnis[tag]!,
      ]);
      expect(paare.map((p) => (p.von.betriebId, p.nach.betriebId)), [
        ('betrieb-b', 'betrieb-c'), // 26. — mit Zähler
        ('betrieb-c', 'betrieb-a'), // 27.
        ('betrieb-a', 'betrieb-b'), // 25.
      ]);
    });

    test('ein Paar nur einmal, auch über Tage mit und ohne Zähler', () {
      final t26 = DateTime(2026, 9, 26);
      final ergebnis = bauen(
        tagesplaene: {tag: plan(kmEnde: null), t26: plan()},
        einsaetze: [
          einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
          einsatz('r2', 'betrieb-b', von: '10:00', bis: '11:00'),
          einsatz('r3', 'betrieb-b', von: '08:00', bis: '09:00', datum: t26),
          einsatz('r4', 'betrieb-a', von: '10:00', bis: '11:00', datum: t26),
        ],
        anfahrten: alleAnfahrten,
      );
      expect(fehlendeRoutenPaare([ergebnis[tag]!, ergebnis[t26]!]), [
        // Vom Tag mit Zähler, in dessen Richtung.
        (
          von: betriebEnde('betrieb-b'),
          nach: betriebEnde('betrieb-a'),
          schluessel: 'b:betrieb-a|b:betrieb-b',
        ),
      ]);
    });
  });

  // OSRM-Demo-Server: höchstens 1 Anfrage/s, keine Massenabfragen. Vorher
  // holte jeder Erfolg die nächsten zehn, bis der ganze Monat durch war.
  // Seit 29.09.2026 25 je Lauf (≥ 28 s bei ≥ 1,1 s Abstand) und 100 je
  // Sitzung: Ohne Route zeigt eine Fahrt keine km mehr.
  group('routenAuswahl', () {
    /// Auftrag Betrieb [von] → Betrieb [nach] mit richtungslosem Schlüssel
    /// (wie `fehlendeRoutenPaare` ihn baut).
    RoutenAuftrag auftrag(String von, String nach) => (
      von: betriebEnde(von),
      nach: betriebEnde(nach),
      schluessel: routenPaarSchluessel('b:$von', 'b:$nach'),
    );
    List<RoutenAuftrag> paare(int n, [String p = 'a']) => [
      for (var i = 0; i < n; i++) auftrag('$p$i', 'z$i'),
    ];
    Set<String> angefragt(int n) => {
      for (var i = 0; i < n; i++) routenPaarSchluessel('b:alt$i', 'b:z$i'),
    };

    test('Standard: 25 je Lauf, 100 je Sitzung', () {
      expect(kRoutenJeLauf, 25);
      expect(kRoutenJeSitzung, 100);
    });

    test('Deckel je Lauf', () {
      expect(
        routenAuswahl(kandidaten: paare(40), schonAngefragt: {}),
        paare(25),
      );
      expect(
        routenAuswahl(kandidaten: paare(40), schonAngefragt: {}, jeLauf: 3),
        paare(3),
      );
    });

    test('Deckel je Sitzung zählt die schon angefragten mit', () {
      expect(
        routenAuswahl(kandidaten: paare(10), schonAngefragt: angefragt(95)),
        paare(5),
      );
      expect(
        routenAuswahl(kandidaten: paare(10), schonAngefragt: angefragt(100)),
        isEmpty,
      );
      expect(
        routenAuswahl(kandidaten: paare(10), schonAngefragt: angefragt(101)),
        isEmpty,
      );
    });

    test('keine Doppel: schon angefragt, Gegenrichtung, zweimal gelistet', () {
      final auswahl = routenAuswahl(
        kandidaten: [
          auftrag('a', 'b'),
          auftrag('b', 'a'),
          auftrag('e', 'f'),
          auftrag('c', 'd'),
          auftrag('c', 'd'),
        ],
        schonAngefragt: {routenPaarSchluessel('b:f', 'b:e')},
      );
      expect(auswahl, [auftrag('a', 'b'), auftrag('c', 'd')]);
    });

    test('Doppel zählen nicht gegen den Deckel je Lauf', () {
      final auswahl = routenAuswahl(
        kandidaten: [auftrag('a', 'b'), auftrag('a', 'b'), auftrag('c', 'd')],
        schonAngefragt: {},
        jeLauf: 2,
      );
      expect(auswahl, [auftrag('a', 'b'), auftrag('c', 'd')]);
    });

    test('Punkt-Aufträge laufen unter demselben Deckel', () {
      final punkt = (
        von: punktEnde(zuerich),
        nach: betriebEnde('betrieb-a'),
        schluessel: 'b:betrieb-a|$keyZuerich',
      );
      final auswahl = routenAuswahl(
        kandidaten: [punkt, ...paare(30)],
        schonAngefragt: {},
      );
      expect(auswahl, hasLength(kRoutenJeLauf));
      expect(auswahl.first, punkt);
    });

    test('die Menge der schon angefragten bleibt unverändert', () {
      final schon = angefragt(2);
      routenAuswahl(kandidaten: paare(5), schonAngefragt: schon);
      expect(schon, angefragt(2));
    });
  });

  group('Anfahrten: eine Abfrage für Minuten und km', () {
    test('beide bisherigen Provider lesen aus derselben Tabelle', () async {
      final container = ProviderContainer(
        overrides: [
          anfahrtenProvider.overrideWith(
            (ref) async => (
              minuten: {
                'chur': {'betrieb-a': 12},
              },
              distanzen: {
                'chur': {'betrieb-a': 9.4},
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(anfahrtszeitenProvider.future), {
        'chur': {'betrieb-a': 12},
      });
      expect(await container.read(anfahrtsDistanzenProvider.future), {
        'chur': {'betrieb-a': 9.4},
      });
    });
  });

  group('monatsFahrtenProvider (Verdrahtung)', () {
    test(
      'führt Tagesplan, Einsätze, Distanzen und Betriebe zusammen',
      () async {
        final container = ProviderContainer(
          overrides: [
            arbeitstageProvider.overrideWith(
              (ref, m) async => [
                (
                  datum: DateTime(2026, 9, 25),
                  beginn: '07:30',
                  ende: '17:00',
                  kmStart: 50000,
                  kmEnde: 50040,
                  // Morgens in Chur gestartet, Feierabend ohne GPS.
                  startPosition: (lat: 46.8639692, lng: 9.5278708),
                  endPosition: null,
                ),
              ],
            ),
            fahrtenEinsaetzeProvider.overrideWith(
              (ref, m) async => (
                einsaetze: [
                  einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
                  einsatz('s1', 'betrieb-b', typ: 'stoerung'),
                ],
                stempel: [
                  stempel(
                    DateTime(2026, 9, 25, 10, 30),
                    betriebId: 'betrieb-b',
                  ),
                ],
              ),
            ),
            anfahrtsDistanzenProvider.overrideWith(
              (ref) async => {
                'chur': {'betrieb-a': 5.0},
                'domat_ems': {'betrieb-b': 9.0},
              },
            ),
            fahrzeitenMapProvider.overrideWith(
              (ref) async => <String, FahrzeitEintrag>{
                'betrieb-a>betrieb-b': (
                  minuten: 25,
                  quelle: 'route',
                  distanzKm: 21.5,
                  distanzQuelle: 'osrm',
                ),
              },
            ),
            punktRoutenProvider.overrideWith((ref) async => const {}),
            betriebeStreamProvider.overrideWith(
              (ref) => Stream.value([
                BetriebLocal()
                  ..serverId = 'betrieb-a'
                  ..name = 'Peppino'
                  ..latitude = 46.85
                  ..longitude = 9.53,
                BetriebLocal()
                  ..serverId = 'betrieb-b'
                  ..name = 'Holländer'
                  ..latitude = 46.80
                  ..longitude = 9.83,
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        // Am Leben halten (autoDispose), solange der Test liest.
        final abo = container.listen(
          tagesFahrtenProvider(DateTime(2026, 9, 25, 14, 30)),
          (_, _) {},
        );
        addTearDown(abo.close);

        final t = (await container.read(
          tagesFahrtenProvider(DateTime(2026, 9, 25, 14, 30)).future,
        ))!;
        expect(t.fahrten.map((f) => '${f.von.name}>${f.nach.name}').toList(), [
          'Chur>Peppino',
          'Peppino>Holländer',
          'Holländer>Domat/Ems',
        ]);
        expect(t.fahrten.map((f) => f.km).toList(), [5.0, 21.5, 9.0]);
        expect(t.kmFahrten, 35.5);
        expect(t.kmZaehler, 40);
        expect(t.befunde, isEmpty); // 4.5 km Differenz liegt in der Toleranz
        // Die Kette selbst (für den Arbeitszeit-Vorschlag beim Abschliessen).
        expect(t.halte.map((h) => h.id).toList(), [
          'chur',
          'betrieb-a',
          'betrieb-b',
          'domat_ems',
        ]);
        expect(
          await container.read(
            tagesFahrtenProvider(DateTime(2026, 9, 26)).future,
          ),
          isNull,
        );
      },
    );

    // Migration 213: Die Punkt-Routen fliessen in den Monat ein — hier die
    // Anfahrt ab einer GPS-Position, die es in `anfahrtszeiten` nie gibt.
    test('Punkt-Routen füllen die Fahrt ab der GPS-Position', () async {
      final container = ProviderContainer(
        overrides: [
          arbeitstageProvider.overrideWith(
            (ref, m) async => [
              (
                datum: DateTime(2026, 9, 25),
                beginn: '07:30',
                ende: '17:00',
                kmStart: 50000,
                kmEnde: 50140,
                startPosition: zuerich,
                endPosition: null,
              ),
            ],
          ),
          fahrtenEinsaetzeProvider.overrideWith(
            (ref, m) async => (
              einsaetze: [
                einsatz('r1', 'betrieb-a', von: '08:00', bis: '09:00'),
              ],
              stempel: const <StempelRoh>[],
            ),
          ),
          anfahrtsDistanzenProvider.overrideWith(
            (ref) async => {
              'domat_ems': {'betrieb-a': 12.0},
            },
          ),
          fahrzeitenMapProvider.overrideWith(
            (ref) async => const <String, FahrzeitEintrag>{},
          ),
          punktRoutenProvider.overrideWith(
            (ref) async => {'$keyZuerich>b:betrieb-a': 125.3},
          ),
          betriebeStreamProvider.overrideWith(
            (ref) => Stream.value([
              BetriebLocal()
                ..serverId = 'betrieb-a'
                ..name = 'Peppino'
                ..latitude = 46.85
                ..longitude = 9.53,
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final abo = container.listen(
        tagesFahrtenProvider(DateTime(2026, 9, 25)),
        (_, _) {},
      );
      addTearDown(abo.close);

      final t = (await container.read(
        tagesFahrtenProvider(DateTime(2026, 9, 25)).future,
      ))!;
      expect(t.fahrten.map((f) => f.km).toList(), [125.3, 12.0]);
      expect(t.fahrten.first.kmQuelle, kKmQuelleRoute);
      expect(t.kmVollstaendig, isTrue);
      expect(t.befunde, ['Arbeitsbeginn nicht am Startort']);
    });
  });

  group('Einsatz vor Ort?', () {
    test('Störung: nur offene zählen nicht', () {
      expect(stoerungWarVorOrt('offen'), isFalse);
      expect(stoerungWarVorOrt('in_bearbeitung'), isTrue);
      expect(stoerungWarVorOrt('behoben'), isTrue);
      expect(stoerungWarVorOrt('nicht_behebbar'), isTrue);
    });

    test('Montage: geplante und reine Abrechnungsposten zählen nicht', () {
      expect(montageWarVorOrt('geplant', 'neumontage'), isFalse);
      expect(montageWarVorOrt('abgeschlossen', 'abaenderung'), isTrue);
      expect(montageWarVorOrt('abgebrochen', 'heigenie_service'), isTrue);
      expect(montageWarVorOrt('abgeschlossen', 'spesen'), isFalse);
      expect(
        montageWarVorOrt('abgeschlossen', 'aufwandsentschaedigung'),
        isFalse,
      );
      expect(montageWarVorOrt('abgeschlossen', null), isTrue);
    });
  });
}
