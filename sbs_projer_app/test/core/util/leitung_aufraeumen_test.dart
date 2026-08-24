import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/leitung_aufraeumen.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';

EventLeitungLocal _leitung({
  required String nummer,
  String? standId,
  String? standAnlageId,
  bool isSynced = true,
}) {
  return EventLeitungLocal()
    ..serverId = 'srv-$nummer'
    ..userId = 'u1'
    ..eventId = 'ev1'
    ..nummer = nummer
    ..quelleId = 'anstich-A'
    ..standId = standId
    ..standAnlageId = standAnlageId
    ..isSynced = isSynced;
}

void main() {
  group('leitungenNachStandLoeschung', () {
    test('Leitung des gelöschten Stands verliert Ziel und Gerätezeile', () {
      // Der Bug: Nach dem Löschen eines Stands zeigte die lokale Isar-Kopie
      // der Leitung weiter auf den verschwundenen Stand — das Pikett bekam
      // ein Ziel genannt, das es nicht mehr gab.
      final leitungen = [
        _leitung(nummer: '7', standId: 'stand-1', standAnlageId: 'anlage-1'),
      ];

      final betroffen = leitungenNachStandLoeschung(leitungen, 'stand-1');

      expect(betroffen, hasLength(1));
      expect(betroffen.single.standId, isNull);
      expect(betroffen.single.standAnlageId, isNull);
      expect(betroffen.single.nummer, '7');
    });

    test('Leitung eines anderen Stands bleibt unberührt', () {
      final andere =
          _leitung(nummer: '9', standId: 'stand-2', standAnlageId: 'anlage-2');
      final leitungen = [
        _leitung(nummer: '7', standId: 'stand-1'),
        andere,
      ];

      final betroffen = leitungenNachStandLoeschung(leitungen, 'stand-1');

      expect(betroffen, hasLength(1));
      expect(betroffen.single.nummer, '7');
      expect(andere.standId, 'stand-2');
      expect(andere.standAnlageId, 'anlage-2');
    });

    test('Leitung ohne Ziel bleibt unberührt', () {
      final leitungen = [_leitung(nummer: '3', standId: null)];

      expect(leitungenNachStandLoeschung(leitungen, 'stand-1'), isEmpty);
    });

    test('kein Treffer: leere Liste', () {
      final leitungen = [_leitung(nummer: '7', standId: 'stand-9')];

      expect(leitungenNachStandLoeschung(leitungen, 'stand-1'), isEmpty);
    });

    test('bereinigte Leitung gilt weiter als synchron', () {
      // Der Server hat die Änderung bereits selbst vollzogen: der FK
      // event_leitungen.stand_id steht auf ON DELETE SET NULL. Lokal wird
      // nur nachgezogen — als ungesynct zu markieren würde die Zeile grundlos
      // ein zweites Mal hochschieben.
      final leitungen = [
        _leitung(nummer: '7', standId: 'stand-1', isSynced: true),
      ];

      final betroffen = leitungenNachStandLoeschung(leitungen, 'stand-1');

      expect(betroffen.single.isSynced, isTrue);
    });
  });
}
