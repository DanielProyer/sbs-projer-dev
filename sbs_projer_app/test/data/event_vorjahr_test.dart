import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';

EventKontaktLocal _z(String kontaktId, String rolle) => EventKontaktLocal()
  ..userId = 'test'
  ..eventId = 'evt'
  ..kontaktId = kontaktId
  ..rolle = rolle;

void main() {
  group('fehlendeZuordnungen', () {
    test('leeres Ziel: alles wird uebernommen', () {
      final quelle = [_z('k1', 'ok'), _z('k2', 'stand')];
      expect(EventKontaktRepository.fehlendeZuordnungen(quelle, []).length, 2);
    });
    test('gleiche (kontaktId, rolle) wird uebersprungen', () {
      final quelle = [_z('k1', 'ok'), _z('k2', 'stand')];
      final ziel = [_z('k1', 'ok')];
      final neu = EventKontaktRepository.fehlendeZuordnungen(quelle, ziel);
      expect(neu.length, 1);
      expect(neu.first.kontaktId, 'k2');
    });
    test('gleicher Kontakt mit ANDERER Rolle wird uebernommen', () {
      final quelle = [_z('k1', 'bau')];
      final ziel = [_z('k1', 'ok')];
      expect(EventKontaktRepository.fehlendeZuordnungen(quelle, ziel).length, 1);
    });
  });
}
