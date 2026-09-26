import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tagesplan_ist_zeiten.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  final tag = DateTime(2026, 9, 28);

  ReinigungLocal reinigung(String betrieb, DateTime datum) => ReinigungLocal()
    ..serverId = 'r_$betrieb'
    ..userId = 'u'
    ..anlageId = 'a1'
    ..betriebId = betrieb
    ..datum = datum
    ..uhrzeitStart = '08:00'
    ..uhrzeitEnde = '08:45'
    ..status = 'abgeschlossen';

  const plan = [
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r1',
      betriebId: 'b1',
      betriebName: 'Rössli',
      beschreibung: '',
    ),
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r2',
      betriebId: 'b2',
      betriebName: 'Krone',
      beschreibung: '',
    ),
    TourEintrag(
      typ: TourEintragTyp.stoerung,
      id: 's_1',
      betriebId: 'b3',
      betriebName: 'Pöstli',
      beschreibung: '',
    ),
  ];

  final WegpunktTag stempel = (
    zeitpunkt: DateTime(2026, 9, 28, 10, 30),
    quelle: 'stoerung',
    betriebId: 'b3',
    lat: null,
    lng: null,
  );

  test('Reinigung am Tag und Störungs-Stempel gelten als erledigt', () {
    final ist = ermittleIstZeiten(
      eintraege: plan,
      datum: tag,
      erledigtePruefen: true,
      reinigungen: [
        reinigung('b1', tag),
        reinigung('b2', tag.add(const Duration(days: 1))), // anderer Tag
      ],
      wegpunkte: [stempel],
      dauerFuer: (_) => 60,
    );
    expect(ist.keys, unorderedEquals(['r1', 's_1']));
    expect(ist['r1'], (von: 8 * 60, bis: 8 * 60 + 45));
    expect(ist['s_1'], (von: 9 * 60 + 30, bis: 10 * 60 + 30));
  });

  group('hist_-Einträge', () {
    ReinigungLocal besuch(int id, String von, String bis, {String? server}) =>
        ReinigungLocal()
          ..id = id
          ..serverId = server
          ..userId = 'u'
          ..anlageId = 'a$id'
          ..betriebId = 'b1'
          ..datum = tag
          ..uhrzeitStart = von
          ..uhrzeitEnde = bis
          ..status = 'abgeschlossen';

    test('zwei Besuche am selben Betrieb behalten je ihre Zeiten', () {
      final ist = ermittleIstZeiten(
        eintraege: const [
          TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: 'hist_41',
            betriebId: 'b1',
            betriebName: 'Rössli',
            beschreibung: '',
          ),
          TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: 'hist_42',
            betriebId: 'b1',
            betriebName: 'Rössli',
            beschreibung: '',
          ),
        ],
        datum: tag,
        erledigtePruefen: true,
        // Im Test (nicht Web) ist `routeId` die lokale Id.
        reinigungen: [
          besuch(41, '08:00', '08:30', server: 's41'),
          besuch(42, '15:00', '15:40', server: 's42'),
        ],
        wegpunkte: const [],
        dauerFuer: (_) => 60,
      );
      expect(ist['hist_41'], (von: 8 * 60, bis: 8 * 60 + 30));
      expect(ist['hist_42'], (von: 15 * 60, bis: 15 * 60 + 40));
    });

    test('ohne serverId (nie synchronisiert) kein hist_-Treffer', () {
      final ist = ermittleIstZeiten(
        eintraege: const [
          TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: 'hist_43',
            betriebId: 'b1',
            betriebName: 'Rössli',
            beschreibung: '',
          ),
        ],
        datum: tag,
        erledigtePruefen: true,
        reinigungen: [besuch(43, '08:00', '08:30')],
        wegpunkte: const [],
        dauerFuer: (_) => 60,
      );
      expect(ist, isEmpty);
    });
  });

  test('Montage und HeiGenie über Wegpunkt-Quelle «montage»', () {
    WegpunktTag wp(String quelle, String betrieb, int h, int m) => (
      zeitpunkt: DateTime(2026, 9, 28, h, m),
      quelle: quelle,
      betriebId: betrieb,
      lat: null,
      lng: null,
    );
    final ist = ermittleIstZeiten(
      eintraege: const [
        TourEintrag(
          typ: TourEintragTyp.montage,
          id: 'm_5',
          betriebId: 'b5',
          betriebName: 'Adler',
          beschreibung: '',
        ),
        TourEintrag(
          typ: TourEintragTyp.heigenie,
          id: 'm_6',
          betriebId: 'b6',
          betriebName: 'Bären',
          beschreibung: '',
        ),
        TourEintrag(
          typ: TourEintragTyp.montage,
          id: 'm_7',
          betriebId: 'b7',
          betriebName: 'Krone',
          beschreibung: '',
        ),
      ],
      datum: tag,
      erledigtePruefen: true,
      reinigungen: const [],
      wegpunkte: [
        wp('montage', 'b5', 14, 0),
        wp('montage', 'b6', 0, 30), // Start würde vor Mitternacht liegen
        wp('stoerung', 'b7', 11, 0), // falsche Quelle für eine Montage
      ],
      dauerFuer: (e) => e.id == 'm_5' ? 180 : 60,
    );
    expect(ist.keys, unorderedEquals(['m_5', 'm_6']));
    expect(ist['m_5'], (von: 11 * 60, bis: 14 * 60));
    expect(ist['m_6'], (von: 0, bis: 30));
  });

  test('unbrauchbare Zeiten, offener Status, fremder Betrieb → offen', () {
    ReinigungLocal r(
      String betrieb, {
      String? von = '08:00',
      String? bis = '08:45',
      String status = 'abgeschlossen',
    }) => reinigung(betrieb, tag)
      ..uhrzeitStart = von
      ..uhrzeitEnde = bis
      ..status = status;

    TourEintrag besuch(String id, String betrieb) => TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: id,
      betriebId: betrieb,
      betriebName: betrieb,
      beschreibung: '',
    );

    final ist = ermittleIstZeiten(
      eintraege: [
        besuch('r1', 'b1'),
        besuch('r2', 'b2'),
        besuch('r3', 'b3'),
        besuch('r4', 'b4'),
        besuch('r5', 'b5'),
        const TourEintrag(
          typ: TourEintragTyp.stoerung,
          id: 's_6',
          betriebId: 'b6',
          betriebName: 'b6',
          beschreibung: '',
        ),
        const TourEintrag(
          typ: TourEintragTyp.stoerung,
          id: 's_7',
          betriebName: 'ohne Betrieb',
          beschreibung: '',
        ),
      ],
      datum: tag,
      erledigtePruefen: true,
      reinigungen: [
        r('b1', von: '09:00', bis: '09:00'), // bis == von
        r('b2', von: '10:00', bis: '09:30'), // bis < von
        r('b3', bis: null), // Ende fehlt
        r('b4', status: 'entwurf'), // nicht abgeschlossen
        r('b9'), // fremder Betrieb
      ],
      wegpunkte: [
        (
          zeitpunkt: DateTime(2026, 9, 28, 11),
          quelle: 'stoerung',
          betriebId: 'b9', // fremder Betrieb
          lat: null,
          lng: null,
        ),
        (
          zeitpunkt: DateTime(2026, 9, 28, 12),
          quelle: 'stoerung',
          betriebId: null, // Stempel ohne Betrieb trifft nichts
          lat: null,
          lng: null,
        ),
      ],
      dauerFuer: (_) => 60,
    );
    expect(ist, isEmpty);
  });

  test('ohne Prüfung (künftiger Tag) bleibt alles offen', () {
    final ist = ermittleIstZeiten(
      eintraege: plan,
      datum: tag,
      erledigtePruefen: false,
      reinigungen: [reinigung('b1', tag)],
      wegpunkte: [stempel],
      dauerFuer: (_) => 60,
    );
    expect(ist, isEmpty);
  });
}
