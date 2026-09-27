import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';

/// Gleiche Werte wie `kStartorte` (tour_providers.dart) — hier kopiert, weil
/// die reine Regel bewusst nichts aus `presentation/` kennt.
const startorte = <String, ({double lat, double lng})>{
  'domat_ems': (lat: 46.8328452, lng: 9.4529918),
  'chur': (lat: 46.8639692, lng: 9.5278708),
};

final datum = DateTime(2026, 9, 25);

// Drei Betriebe mit Koordinaten (Bündner Rheintal), einer ohne.
const a = (id: 'betrieb-a', name: 'Peppino', lat: 46.85, lng: 9.53);
const b = (id: 'betrieb-b', name: 'Holländer', lat: 46.80, lng: 9.83);
const c = (id: 'betrieb-c', name: 'Linden', lat: 46.86, lng: 9.50);

EinsatzHalt einsatz(
  String id,
  ({String id, String name, double lat, double lng})? betrieb, {
  String typ = 'reinigung',
  String? von,
  String? bis,
  DateTime? stempel,
}) => EinsatzHalt(
  einsatzId: id,
  typ: typ,
  betriebId: betrieb?.id,
  betriebName: betrieb?.name,
  lat: betrieb?.lat,
  lng: betrieb?.lng,
  von: von,
  bis: bis,
  stempel: stempel,
);

List<Halt> halte(
  List<EinsatzHalt> einsaetze, {
  String? arbeitsbeginn = '07:30',
  String? arbeitsende = '17:00',
  String startortMorgen = 'domat_ems',
  String startortAbend = 'domat_ems',
  ({double lat, double lng})? beginnUnterwegs,
  ({double lat, double lng})? endeUnterwegs,
}) => halteAusKette(
  arbeitsbeginn: arbeitsbeginn,
  arbeitsende: arbeitsende,
  startortMorgen: startortMorgen,
  startortAbend: startortAbend,
  einsaetze: einsaetze,
  datum: datum,
  startorte: startorte,
  beginnUnterwegs: beginnUnterwegs,
  endeUnterwegs: endeUnterwegs,
);

/// ~200 m bzw. ~400 m nördlich (1° Breite ≈ 111 km).
({double lat, double lng}) nahBei(double lat, double lng) =>
    (lat: lat + 0.0018, lng: lng);
({double lat, double lng}) knappDaneben(double lat, double lng) =>
    (lat: lat + 0.0036, lng: lng);

const zuerich = (lat: 47.37, lng: 8.54);

/// Nachschlag ohne Treffer — jede Fahrt fällt auf die Luftlinie zurück.
({double km, String quelle})? keinTreffer(Halt von, Halt nach) => null;

/// Halt ohne Koordinaten, nur für die Befund-Tests.
Halt betriebHalt(String id, int ankunft, int abfahrt) => Halt(
  typ: HaltTyp.betrieb,
  id: id,
  name: id,
  ankunftMin: ankunft,
  abfahrtMin: abfahrt,
  quelle: 'reinigung',
);

/// Kette Startort → X → Startort mit zwei Fahrten, deren km der Nachschlag
/// fest vorgibt (hin + zurück = [summe]).
TagesFahrten tagMitKm(
  double summe, {
  int? kmStart = 50000,
  int? kmEnde,
  List<EinsatzHalt> ohneZeit = const [],
  bool feierabendErfasst = true,
}) {
  final kette = [
    const Halt(
      typ: HaltTyp.startort,
      id: 'domat_ems',
      name: 'Domat/Ems',
      abfahrtMin: 450,
      quelle: 'arbeitsbeginn',
    ),
    betriebHalt('x', 480, 540),
    const Halt(
      typ: HaltTyp.startort,
      id: 'domat_ems',
      name: 'Domat/Ems',
      ankunftMin: 600,
      quelle: 'feierabend',
    ),
  ];
  return tagesFahrten(
    halte: kette,
    ohneZeit: ohneZeit,
    km: (von, nach) => (km: summe / 2, quelle: 'anfahrt'),
    kmStart: kmStart,
    kmEnde: kmEnde,
    feierabendErfasst: feierabendErfasst,
  );
}

void main() {
  group('halteAusKette', () {
    test('Startort zuerst, Einsätze nach Zeit, Feierabend zuletzt', () {
      final h = halte([
        einsatz('r2', b, von: '10:00', bis: '10:40'),
        einsatz('r1', a, von: '08:00', bis: '08:30'),
        einsatz('r3', c, von: '13:15', bis: '13:45'),
      ]);
      expect(h.map((x) => x.id).toList(), [
        'domat_ems',
        a.id,
        b.id,
        c.id,
        'domat_ems',
      ]);
      expect(h.first.typ, HaltTyp.startort);
      expect(h.first.ankunftMin, isNull);
      expect(h.first.abfahrtMin, 7 * 60 + 30);
      expect(h.first.quelle, 'arbeitsbeginn');
      expect(h.first.lat, startorte['domat_ems']!.lat);
      expect(h.last.ankunftMin, 17 * 60);
      expect(h.last.abfahrtMin, isNull);
      expect(h.last.quelle, 'feierabend');
    });

    test('Einsatz vor dem Arbeitsbeginn bleibt hinter dem Startort', () {
      // Tippfehler oder zu spät gedrückter Arbeitsbeginn — die Kette beginnt
      // trotzdem am Startort, sonst entstünde eine Fahrt «Betrieb → zuhause».
      final h = halte([
        einsatz('r1', a, von: '07:00', bis: '07:20'),
      ], arbeitsbeginn: '07:30');
      expect(h.map((x) => x.id).toList(), ['domat_ems', a.id, 'domat_ems']);
    });

    test('Reinigung mit Zeiten: Ankunft = Start, Abfahrt = Ende', () {
      final h = halte([einsatz('r1', a, von: '08:05', bis: '08:50')]);
      final r = h[1];
      expect(r.typ, HaltTyp.betrieb);
      expect(r.id, a.id);
      expect(r.name, 'Peppino');
      expect(r.ankunftMin, 8 * 60 + 5);
      expect(r.abfahrtMin, 8 * 60 + 50);
      expect(r.quelle, 'reinigung');
      expect(r.lat, a.lat);
    });

    test('Sekunden in der Uhrzeit stören nicht (HH:mm:ss)', () {
      final h = halte([einsatz('r1', a, von: '08:05:00', bis: '08:50:00')]);
      expect(h[1].ankunftMin, 8 * 60 + 5);
      expect(h[1].abfahrtMin, 8 * 60 + 50);
    });

    test('Störung ohne Zeiten mit Stempel → Punkt-Halt', () {
      final h = halte([
        einsatz(
          's1',
          b,
          typ: 'stoerung',
          stempel: DateTime(2026, 9, 25, 11, 42, 30),
        ),
      ]);
      final s = h[1];
      expect(s.id, b.id);
      expect(s.ankunftMin, 11 * 60 + 42);
      expect(s.abfahrtMin, 11 * 60 + 42);
      expect(s.quelle, 'wegpunkt');
    });

    test('Zeiten gehen dem Stempel vor', () {
      final h = halte([
        einsatz(
          'm1',
          b,
          typ: 'montage',
          von: '09:00',
          bis: '11:00',
          stempel: DateTime(2026, 9, 25, 12, 0),
        ),
      ]);
      expect(h[1].ankunftMin, 9 * 60);
      expect(h[1].abfahrtMin, 11 * 60);
      expect(h[1].quelle, 'montage');
    });

    test('nur eine der beiden Zeiten → Punkt-Halt an der bekannten', () {
      final h = halte([
        einsatz('r1', a, von: '08:00'),
        einsatz('r2', b, bis: '10:30'),
      ]);
      expect(h[1].ankunftMin, 8 * 60);
      expect(h[1].abfahrtMin, 8 * 60);
      expect(h[2].ankunftMin, 10 * 60 + 30);
      expect(h[2].abfahrtMin, 10 * 60 + 30);
    });

    test('Störung ohne Zeit und ohne Stempel → nicht in der Kette', () {
      final ohne = einsatz('s1', b, typ: 'stoerung');
      final liste = [einsatz('r1', a, von: '08:00', bis: '08:30'), ohne];
      final h = halte(liste);
      expect(h.map((x) => x.id), isNot(contains(b.id)));
      expect(einsaetzeOhneZeit(liste, datum: datum), [ohne]);
    });

    test('Stempel eines anderen Tages zählt nicht', () {
      final fremd = einsatz(
        's1',
        b,
        typ: 'stoerung',
        stempel: DateTime(2026, 9, 24, 16, 0),
      );
      expect(halte([fremd]).map((x) => x.id), isNot(contains(b.id)));
      expect(einsaetzeOhneZeit([fremd], datum: datum), [fremd]);
    });

    group('Verschmelzen am selben Betrieb', () {
      test(
        'Lücke ≤ 15 min → ein Halt (früheste Ankunft, späteste Abfahrt)',
        () {
          final h = halte([
            einsatz('r1', a, von: '08:00', bis: '08:30'),
            einsatz(
              's1',
              a,
              typ: 'stoerung',
              stempel: DateTime(2026, 9, 25, 8, 45),
            ),
          ]);
          expect(h.map((x) => x.id).toList(), ['domat_ems', a.id, 'domat_ems']);
          expect(h[1].ankunftMin, 8 * 60);
          expect(h[1].abfahrtMin, 8 * 60 + 45);
        },
      );

      test('Lücke > 15 min → zwei Halte, aber keine Fahrt dazwischen', () {
        final h = halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
          einsatz('r2', a, von: '08:46', bis: '09:10'),
        ]);
        expect(h.map((x) => x.id).toList(), [
          'domat_ems',
          a.id,
          a.id,
          'domat_ems',
        ]);
        final f = fahrtenAusHalten(h, keinTreffer);
        expect(f, hasLength(2)); // hin und heim, nicht A → A
        expect(f.map((x) => x.nach.id), [a.id, 'domat_ems']);
      });

      test('anderer Betrieb → nie verschmelzen', () {
        final h = halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
          einsatz('r2', c, von: '08:35', bis: '09:00'),
        ]);
        expect(h.map((x) => x.id).toList(), [
          'domat_ems',
          a.id,
          c.id,
          'domat_ems',
        ]);
      });
    });

    test('ohne Arbeitsbeginn kein Morgen-, ohne Feierabend kein Abendhalt', () {
      final h = halte(
        [einsatz('r1', a, von: '08:00', bis: '08:30')],
        arbeitsbeginn: null,
        arbeitsende: null,
      );
      expect(h.map((x) => x.id).toList(), [a.id]);
    });

    test('Abend-Startort kann ein anderer sein (Chur)', () {
      final h = halte([
        einsatz('r1', a, von: '08:00', bis: '08:30'),
      ], startortAbend: 'chur');
      expect(h.last.id, 'chur');
      expect(h.last.name, 'Chur');
      expect(h.last.lat, startorte['chur']!.lat);
    });

    group('Arbeitsbeginn/Feierabend unterwegs', () {
      test('Arbeitsbeginn fern vom ersten Betrieb → GPS-Halt', () {
        final h = halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
        ], beginnUnterwegs: zuerich);
        final s = h.first;
        expect(s.typ, HaltTyp.startort);
        expect(s.id, kGpsStartId);
        expect(s.name, 'Arbeitsbeginn unterwegs');
        expect(s.lat, zuerich.lat);
        expect(s.lng, zuerich.lng);
        expect(s.ankunftMin, isNull);
        expect(s.abfahrtMin, 7 * 60 + 30);
        expect(s.quelle, 'arbeitsbeginn');
        expect(h.last.id, 'domat_ems'); // abends normal
      });

      test('Arbeitsbeginn ≤ 300 m vom ersten Betrieb → dessen Id/Name', () {
        final h = halte([
          einsatz('r2', c, von: '10:00', bis: '10:30'),
          einsatz('r1', b, von: '08:00', bis: '08:30'),
        ], beginnUnterwegs: nahBei(b.lat, b.lng));
        expect(h.first.id, b.id);
        expect(h.first.name, 'Holländer');
        expect(h.first.typ, HaltTyp.startort);
        // Gleiche Id wie der erste Betrieb → keine Anfahrt.
        final f = fahrtenAusHalten(h, keinTreffer);
        expect(f.map((x) => '${x.von.id}>${x.nach.id}'), [
          '${b.id}>${c.id}',
          '${c.id}>domat_ems',
        ]);
      });

      test('~400 m vom ersten Betrieb → GPS-Halt, eigene Fahrt', () {
        final h = halte([
          einsatz('r1', b, von: '08:00', bis: '08:30'),
        ], beginnUnterwegs: knappDaneben(b.lat, b.lng));
        expect(h.first.id, kGpsStartId);
        final f = fahrtenAusHalten(h, keinTreffer);
        expect(f.first.kmQuelle, kKmQuelleLuftlinie);
      });

      test('Feierabend fern vom letzten Betrieb → GPS-Halt', () {
        final h = halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
        ], endeUnterwegs: zuerich);
        final e = h.last;
        expect(e.typ, HaltTyp.startort);
        expect(e.id, kGpsEndeId);
        expect(e.name, 'Feierabend unterwegs');
        expect(e.ankunftMin, 17 * 60);
        expect(e.abfahrtMin, isNull);
        expect(e.quelle, 'feierabend');
        expect(h.first.id, 'domat_ems');
      });

      test('Feierabend ≤ 300 m vom letzten Betrieb → dessen Id/Name', () {
        final h = halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
          einsatz('r2', c, von: '10:00', bis: '10:30'),
        ], endeUnterwegs: nahBei(c.lat, c.lng));
        expect(h.last.id, c.id);
        expect(h.last.name, 'Linden');
        expect(fahrtenAusHalten(h, keinTreffer).last.nach.id, c.id);
        expect(fahrtenAusHalten(h, keinTreffer), hasLength(2));
      });

      test('ohne Einsätze: GPS-Halt, nicht an einem Betrieb', () {
        final h = halte(const [], beginnUnterwegs: zuerich);
        expect(h.map((x) => x.id).toList(), [kGpsStartId, 'domat_ems']);
      });
    });
  });

  group('stempelAmBetrieb', () {
    StempelRoh s(double? lat, double? lng) => (
      zeitpunkt: DateTime(2026, 9, 25, 11, 0),
      quelle: 'stoerung',
      betriebId: b.id,
      referenzId: null,
      lat: lat,
      lng: lng,
    );
    final ort = (lat: b.lat, lng: b.lng);

    test('Radius 300 m', () => expect(kStempelRadiusKm, 0.3));

    test('~200 m → am Betrieb, ~400 m → nicht', () {
      final nah = nahBei(b.lat, b.lng), weit = knappDaneben(b.lat, b.lng);
      expect(stempelAmBetrieb(s(b.lat, b.lng), ort), isTrue);
      expect(stempelAmBetrieb(s(nah.lat, nah.lng), ort), isTrue);
      expect(stempelAmBetrieb(s(weit.lat, weit.lng), ort), isFalse);
    });

    test('ohne Koordinaten auf einer Seite → nicht am Betrieb', () {
      expect(stempelAmBetrieb(s(null, null), ort), isFalse);
      expect(stempelAmBetrieb(s(b.lat, null), ort), isFalse);
      expect(
        stempelAmBetrieb(s(b.lat, b.lng), (lat: null, lng: null)),
        isFalse,
      );
      expect(stempelAmBetrieb(s(b.lat, b.lng), null), isFalse);
    });
  });

  group('fahrtenAusHalten', () {
    test('Fahrt vom Startort zur ersten Reinigung', () {
      final h = halte([einsatz('r1', a, von: '08:05', bis: '08:50')]);
      final f = fahrtenAusHalten(h, keinTreffer);
      expect(f.first.von.id, 'domat_ems');
      expect(f.first.nach.id, a.id);
      expect(f.first.abfahrtMin, 7 * 60 + 30);
      expect(f.first.ankunftMin, 8 * 60 + 5);
      expect(f.first.dauerMin, 35);
    });

    test('Heimweg nur mit Feierabend', () {
      final mit = fahrtenAusHalten(
        halte([einsatz('r1', a, von: '08:00', bis: '08:30')]),
        keinTreffer,
      );
      expect(mit, hasLength(2));
      expect(mit.last.nach.id, 'domat_ems');
      expect(mit.last.abfahrtMin, 8 * 60 + 30);
      expect(mit.last.ankunftMin, 17 * 60);

      final ohne = fahrtenAusHalten(
        halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
        ], arbeitsende: null),
        keinTreffer,
      );
      expect(ohne, hasLength(1));
      expect(ohne.single.nach.id, a.id);
    });

    test('km aus dem Nachschlag samt Quelle', () {
      final h = halte([
        einsatz('r1', a, von: '08:00', bis: '08:30'),
        einsatz('r2', b, von: '09:30', bis: '10:00'),
      ]);
      final f = fahrtenAusHalten(h, (von, nach) {
        if (von.typ == HaltTyp.startort || nach.typ == HaltTyp.startort) {
          return (km: 7.4, quelle: 'anfahrt');
        }
        return (km: 31.2, quelle: 'route');
      });
      expect(f.map((x) => x.km), [7.4, 31.2, 7.4]);
      expect(f.map((x) => x.kmQuelle), ['anfahrt', 'route', 'anfahrt']);
    });

    test('Rückfall Luftlinie × Umwegfaktor, Quelle «luftlinie»', () {
      final h = halte([einsatz('r1', a, von: '08:00', bis: '08:30')]);
      final f = fahrtenAusHalten(h, keinTreffer);
      final luft = haversineKm(
        startorte['domat_ems']!.lat,
        startorte['domat_ems']!.lng,
        a.lat,
        a.lng,
      );
      final erwartet = (luftlinieStreckeKm(luft) * 10).round() / 10;
      expect(f.first.km, erwartet);
      expect(f.first.kmQuelle, 'luftlinie');
    });

    test('ohne Koordinaten keine km (und keine Quelle)', () {
      final kette = [betriebHalt('x', 480, 500), betriebHalt('y', 520, 540)];
      final f = fahrtenAusHalten(kette, keinTreffer);
      expect(f.single.km, isNull);
      expect(f.single.kmQuelle, isNull);
    });

    test('Dauer null bei Überlappung statt negativer Minuten', () {
      final kette = [betriebHalt('x', 480, 540), betriebHalt('y', 530, 560)];
      expect(fahrtenAusHalten(kette, keinTreffer).single.dauerMin, isNull);
    });
  });

  group('tagesFahrten — Befunde', () {
    test('Zähler 148, Fahrten 132 → 16 km unerklärt', () {
      final t = tagMitKm(132, kmEnde: 50148);
      expect(t.kmZaehler, 148);
      expect(t.kmFahrten, 132);
      expect(t.differenz, 16);
      expect(t.differenzAuffaellig, isTrue);
      expect(
        t.befunde,
        contains(
          'Zähler 148 km, Fahrten 132 km — 16 km unerklärt '
          '(privat oder Umweg?)',
        ),
      );
    });

    test('Zähler 148, Fahrten 145 → +3 km, kein Befund', () {
      final t = tagMitKm(145, kmEnde: 50148);
      expect(t.differenz, 3);
      expect(t.differenzAuffaellig, isFalse);
      expect(t.befunde, isEmpty);
    });

    test('Fahrten deutlich über dem Zähler → «Zählerstand prüfen»', () {
      final t = tagMitKm(160, kmEnde: 50148);
      expect(t.differenz, -12);
      expect(t.differenzAuffaellig, isTrue);
      expect(
        t.befunde,
        contains(
          'Fahrten 160 km liegen über dem Zähler 148 km — Zählerstand prüfen',
        ),
      );
    });

    test('−4 km bei Zähler 148 liegt in der Toleranz (7.4 km)', () {
      // Regel |Δ| > max(5 km, 5 %) gilt in beide Richtungen: gerouteten
      // Strecken fehlen ein paar Kilometer Genauigkeit, das ist kein Befund.
      final t = tagMitKm(152, kmEnde: 50148);
      expect(t.differenz, -4);
      expect(t.differenzAuffaellig, isFalse);
      expect(t.befunde, isEmpty);
    });

    test('Toleranz wächst mit dem Zähler (5 % von 300 = 15 km)', () {
      expect(tagMitKm(286, kmEnde: 50300).differenzAuffaellig, isFalse);
      expect(tagMitKm(284, kmEnde: 50300).differenzAuffaellig, isTrue);
    });

    test('kurzer Tag: mindestens 5 km Toleranz', () {
      expect(tagMitKm(35, kmEnde: 50040).differenzAuffaellig, isFalse);
      expect(tagMitKm(34, kmEnde: 50040).differenzAuffaellig, isTrue);
    });

    test('ohne Zähler: keine Differenz, Befund «Zählerstand fehlt»', () {
      final t = tagMitKm(132, kmEnde: null);
      expect(t.kmZaehler, isNull);
      expect(t.differenz, isNull);
      expect(t.differenzAuffaellig, isFalse);
      expect(t.befunde, ['Zählerstand fehlt — keine Kontrolle möglich']);
    });

    test('Abendstand kleiner als Morgenstand → Tippfehler-Befund', () {
      final t = tagMitKm(132, kmStart: 50148, kmEnde: 50000);
      expect(t.kmZaehler, isNull);
      expect(t.befunde, [
        'Zählerstand Feierabend 50000 km liegt unter dem Morgenstand '
            '50148 km — Tippfehler?',
      ]);
    });

    test('Einsätze ohne Zeit werden gezählt', () {
      final eins = tagMitKm(
        132,
        kmEnde: 50132,
        ohneZeit: [einsatz('s1', b, typ: 'stoerung')],
      );
      expect(eins.befunde, ['1 Einsatz ohne Zeit — nicht in den Fahrten']);
      final zwei = tagMitKm(
        132,
        kmEnde: 50132,
        ohneZeit: [
          einsatz('s1', b, typ: 'stoerung'),
          einsatz('m1', c, typ: 'montage'),
        ],
      );
      expect(zwei.befunde, ['2 Einsätze ohne Zeit — nicht in den Fahrten']);
      expect(zwei.ohneZeit, hasLength(2));
    });

    test('Fahrten nur als Luftlinie werden gemeldet', () {
      final h = halte([
        einsatz('r1', a, von: '08:00', bis: '08:30'),
        einsatz('r2', b, von: '09:30', bis: '10:00'),
      ]);
      final t = tagesFahrten(
        halte: h,
        ohneZeit: const [],
        km: (von, nach) =>
            von.typ == HaltTyp.startort ? (km: 5.0, quelle: 'anfahrt') : null,
        feierabendErfasst: true,
      );
      expect(t.fahrten, hasLength(3));
      expect(t.fahrtenNurLuftlinie, 2);
      expect(
        t.befunde,
        contains('2 von 3 Fahrten nur als Luftlinie geschätzt'),
      );
    });

    test('die Kette kommt unverändert im Ergebnis mit (Arbeitszeit-Vorschlag)',
        () {
      final h = halte([
        einsatz('r1', a, von: '08:00', bis: '08:30'),
        einsatz('r2', b, von: '09:30', bis: '10:00'),
      ]);
      final t = tagesFahrten(
        halte: h,
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
      );
      expect(t.halte, same(h));
      expect(t.halte.map((x) => x.id).toList(), [
        'domat_ems',
        'betrieb-a',
        'betrieb-b',
        'domat_ems',
      ]);
    });

    test('Fahrten ganz ohne Distanz werden gemeldet', () {
      final t = tagesFahrten(
        halte: [betriebHalt('x', 480, 500), betriebHalt('y', 520, 540)],
        ohneZeit: const [],
        km: keinTreffer,
        kmStart: 50000,
        kmEnde: 50000,
        feierabendErfasst: true,
      );
      expect(t.kmFahrten, 0);
      expect(t.befunde, ['1 Fahrt ohne Distanz (Koordinaten fehlen)']);
    });

    test('Kein Feierabend → Heimweg fehlt', () {
      final t = tagMitKm(148, kmEnde: 50148, feierabendErfasst: false);
      expect(t.befunde, ['Kein Feierabend erfasst — Heimweg fehlt']);
    });

    test('Kein Arbeitsbeginn → Anfahrt fehlt', () {
      final t = tagesFahrten(
        halte: [betriebHalt('x', 480, 500), betriebHalt('y', 520, 540)],
        ohneZeit: const [],
        km: (von, nach) => (km: 10.0, quelle: 'route'),
        kmStart: 50000,
        kmEnde: 50010,
        feierabendErfasst: true,
        arbeitsbeginnErfasst: false,
      );
      expect(t.befunde, ['Kein Arbeitsbeginn erfasst — Anfahrt fehlt']);
    });

    test('positive Differenz + Einsätze ohne Zeit: «davon evtl.»', () {
      final eins = tagMitKm(
        132,
        kmEnde: 50148,
        ohneZeit: [einsatz('s1', b, typ: 'stoerung')],
      );
      expect(
        eins.befunde.first,
        'Zähler 148 km, Fahrten 132 km — 16 km unerklärt (privat oder '
        'Umweg?), davon evtl. 1 Einsatz ohne Zeit',
      );
      final zwei = tagMitKm(
        132,
        kmEnde: 50148,
        ohneZeit: [
          einsatz('s1', b, typ: 'stoerung'),
          einsatz('m1', c, typ: 'montage'),
        ],
      );
      expect(zwei.befunde.first, endsWith('davon evtl. 2 Einsätze ohne Zeit'));
      // Negative Differenz: Einsätze ohne Zeit erklären nichts.
      final minus = tagMitKm(
        160,
        kmEnde: 50148,
        ohneZeit: [einsatz('s1', b, typ: 'stoerung')],
      );
      expect(minus.befunde.first, isNot(contains('davon evtl.')));
    });

    test('Einsatz nach Feierabend → «Zeit prüfen» mit Betriebsname', () {
      final t = tagesFahrten(
        halte: halte([
          einsatz('r1', a, von: '08:00', bis: '08:30'),
          einsatz(
            's1',
            b,
            typ: 'stoerung',
            stempel: DateTime(2026, 9, 25, 19, 56),
          ),
        ], arbeitsende: '17:30'),
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
      );
      expect(
        t.befunde,
        contains(
          'Einsatz 19:56 bei Holländer nach Feierabend 17:30 — Zeit prüfen',
        ),
      );
      expect(t.befunde.where((x) => x.contains('Peppino')), isEmpty);
    });

    test('Einsatz vor Arbeitsbeginn → «Zeit prüfen» mit Betriebsname', () {
      final t = tagesFahrten(
        halte: halte([
          einsatz('r1', a, von: '06:10', bis: '06:40'),
        ], arbeitsbeginn: '07:00'),
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
      );
      expect(
        t.befunde,
        contains(
          'Einsatz 06:10 bei Peppino vor Arbeitsbeginn 07:00 — Zeit prüfen',
        ),
      );
    });

    test('Einsatz genau zu Beginn/Feierabend → kein Zeit-Befund', () {
      final t = tagesFahrten(
        halte: halte([
          einsatz('r1', a, von: '07:30', bis: '08:00'),
          einsatz('r2', c, von: '17:00', bis: '17:00'),
        ]),
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
      );
      expect(t.befunde.where((x) => x.contains('Zeit prüfen')), isEmpty);
    });

    test('Arbeitsbeginn/Feierabend unterwegs werden gemeldet', () {
      final fern = tagesFahrten(
        halte: halte(
          [einsatz('r1', a, von: '08:00', bis: '08:30')],
          beginnUnterwegs: zuerich,
          endeUnterwegs: zuerich,
        ),
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
        arbeitsbeginnUnterwegs: true,
        feierabendUnterwegs: true,
      );
      expect(fern.befunde, contains('Arbeitsbeginn nicht am Startort'));
      expect(fern.befunde, contains('Feierabend nicht am Startort'));

      final amBetrieb = tagesFahrten(
        halte: halte(
          [einsatz('r1', a, von: '08:00', bis: '08:30')],
          beginnUnterwegs: nahBei(a.lat, a.lng),
          endeUnterwegs: nahBei(a.lat, a.lng),
        ),
        ohneZeit: const [],
        km: keinTreffer,
        feierabendErfasst: true,
        arbeitsbeginnUnterwegs: true,
        feierabendUnterwegs: true,
      );
      expect(
        amBetrieb.befunde,
        contains('Arbeitsbeginn nicht am Startort — bei Peppino'),
      );
      expect(
        amBetrieb.befunde,
        contains('Feierabend nicht am Startort — bei Peppino'),
      );
      expect(amBetrieb.fahrten, isEmpty);
    });

    test('km-Summe ohne Gleitkomma-Rauschen', () {
      final t = tagesFahrten(
        halte: [
          betriebHalt('x', 480, 500),
          betriebHalt('y', 520, 540),
          betriebHalt('z', 560, 580),
        ],
        ohneZeit: const [],
        km: (von, nach) => von.id == 'x'
            ? (km: 12.3, quelle: 'route')
            : (km: 4.1, quelle: 'route'),
        feierabendErfasst: true,
      );
      expect(t.kmFahrten, 16.4);
    });
  });

  group('Hilfen', () {
    test('kmText: eine Nachkommastelle mit Punkt', () {
      expect(kmText(12.34), '12.3 km');
      expect(kmText(7), '7.0 km');
    });

    test('luftlinieStreckeKm = Luftlinie × Umwegfaktor', () {
      expect(luftlinieStreckeKm(10), 10 * umwegFaktor(10));
      expect(luftlinieStreckeKm(0), 0);
    });
  });
}
