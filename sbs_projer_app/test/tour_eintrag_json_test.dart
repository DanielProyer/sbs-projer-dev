import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  group('TourEintrag JSON — Lademigration (Task 5, Review-Fix)', () {
    test(
      'Alt-JSON mit einzelnem anlageId, ohne anlageIds -> anlageIds = [anlageId]',
      () {
        final json = {
          'typ': 'reinigung',
          'id': 'x1',
          'anlageId': 'anlage-1',
          'betriebName': 'Betrieb X',
          'beschreibung': '',
        };

        final e = tourEintragFromJson(json);

        expect(e.anlageIds, ['anlage-1']);
        expect(e.anlageId, 'anlage-1');
      },
    );

    test(
      'Alt-JSON ohne anlageId und ohne anlageIds -> leere Liste, kein Crash',
      () {
        final json = {
          'typ': 'stoerung',
          'id': 'x2',
          'betriebName': 'Betrieb Y',
          'beschreibung': '',
        };

        final e = tourEintragFromJson(json);

        expect(e.anlageIds, isEmpty);
        expect(e.anlageId, isNull);
      },
    );

    test(
      'Roundtrip neu -> toJson -> fromJson: alle vier neuen Felder identisch',
      () {
        const original = TourEintrag(
          typ: TourEintragTyp.reinigung,
          id: 'x3',
          betriebName: 'Betrieb Z',
          beschreibung: '',
          anlageIds: ['a1', 'a2', 'a3'],
          dauerMinuten: 45,
          ankerZeit: '09:30',
          uebernommen: true,
        );

        final restored = tourEintragFromJson(tourEintragToJson(original));

        expect(restored.anlageIds, original.anlageIds);
        expect(restored.dauerMinuten, original.dauerMinuten);
        expect(restored.ankerZeit, original.ankerZeit);
        expect(restored.uebernommen, original.uebernommen);
      },
    );

    test(
      'Roundtrip Alt-Map -> from -> to -> from: anlageIds bleibt stabil',
      () {
        final altJson = {
          'typ': 'reinigung',
          'id': 'x4',
          'anlageId': 'alte-anlage',
          'betriebName': 'Betrieb Alt',
          'beschreibung': '',
        };

        final erstesLaden = tourEintragFromJson(altJson);
        final wiederGespeichert = tourEintragToJson(erstesLaden);
        final zweitesLaden = tourEintragFromJson(wiederGespeichert);

        expect(zweitesLaden.anlageIds, ['alte-anlage']);
        expect(zweitesLaden.anlageIds, erstesLaden.anlageIds);
      },
    );
  });
}
