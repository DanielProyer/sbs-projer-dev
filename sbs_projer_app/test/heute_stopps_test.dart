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
      final plan = [reinigung('r_1', anlageIds: ['a1']), stoerung('s_1')];
      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {},
        erledigteEinsatzIds: const {},
      );
      expect(offen.map((e) => e.id), ['r_1', 's_1']);
    });

    test('Reinigung mit gereinigter Anlage faellt raus', () {
      final offen = offeneStopps(
        plan: [reinigung('r_1', anlageIds: ['a1'])],
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {},
      );
      expect(offen, isEmpty);
    });

    test('gebuendelter Besuch bleibt offen, solange eine Anlage fehlt', () {
      final offen = offeneStopps(
        plan: [reinigung('r_1', anlageIds: ['a1', 'a2', 'a3'])],
        gereinigteAnlageIds: const {'a1', 'a2'},
        erledigteEinsatzIds: const {},
      );
      expect(offen.map((e) => e.id), ['r_1'],
          reason: 'a3 fehlt noch — der Besuch darf nicht verschwinden');
    });

    test('gebuendelter Besuch faellt erst raus, wenn alle Anlagen erledigt sind', () {
      final offen = offeneStopps(
        plan: [reinigung('r_1', anlageIds: ['a1', 'a2'])],
        gereinigteAnlageIds: const {'a1', 'a2'},
        erledigteEinsatzIds: const {},
      );
      expect(offen, isEmpty);
    });

    test('Stoerung faellt ueber die Einsatz-Id raus', () {
      final offen = offeneStopps(
        plan: [stoerung('s_1'), stoerung('s_2')],
        gereinigteAnlageIds: const {},
        erledigteEinsatzIds: const {'s_1'},
      );
      expect(offen.map((e) => e.id), ['s_2']);
    });

    test('Reinigung ohne Anlagen gilt nie als erledigt', () {
      final offen = offeneStopps(
        plan: [reinigung('r_1')],
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {},
      );
      expect(offen.map((e) => e.id), ['r_1'],
          reason: 'ohne Anlagenbezug laesst sich nichts abgleichen');
    });

    test('Reihenfolge des Plans bleibt erhalten', () {
      final plan = [
        reinigung('r_1', anlageIds: ['a1']),
        reinigung('r_2', anlageIds: ['a2']),
        reinigung('r_3', anlageIds: ['a3']),
      ];
      final offen = offeneStopps(
        plan: plan,
        gereinigteAnlageIds: const {'a2'},
        erledigteEinsatzIds: const {},
      );
      expect(offen.map((e) => e.id), ['r_1', 'r_3']);
    });
  });

  group('erledigtZaehler', () {
    test('zaehlt erledigte gegen die Gesamtzahl', () {
      final plan = [
        reinigung('r_1', anlageIds: ['a1']),
        reinigung('r_2', anlageIds: ['a2']),
        stoerung('s_1'),
      ];
      final zaehler = erledigtZaehler(
        plan: plan,
        gereinigteAnlageIds: const {'a1'},
        erledigteEinsatzIds: const {'s_1'},
      );
      expect(zaehler.erledigt, 2);
      expect(zaehler.gesamt, 3);
    });
  });
}
