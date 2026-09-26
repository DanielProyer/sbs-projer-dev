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
