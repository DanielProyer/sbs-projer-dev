import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/spesen/spesen_import_service.dart';

void main() {
  group('istPrivatbezug', () {
    test('privat -> true', () {
      expect(SpesenImportService.istPrivatbezug('privat'), isTrue);
    });
    test('alle Geschäftskategorien -> false', () {
      for (final k in [
        'benzin',
        'material',
        'berufskleider',
        'parkgebuehren',
        'entsorgung',
        'essen',
      ]) {
        expect(SpesenImportService.istPrivatbezug(k), isFalse, reason: k);
      }
    });
  });

  group('positionBuchen (Regel Daniel 28.07.: Tabak = Privatkauf)', () {
    test('Privatbezug bar/bank -> buchen (Soll 2260, Kasse/Bank stimmt)', () {
      expect(SpesenImportService.positionBuchen('privat', Zahlungsweg.bar),
          isTrue);
      expect(SpesenImportService.positionBuchen('privat', Zahlungsweg.bank),
          isTrue);
    });
    test('Privatbezug privat bezahlt -> nicht buchen (wäre 2260 an 2260)', () {
      expect(SpesenImportService.positionBuchen('privat', Zahlungsweg.privat),
          isFalse);
    });
    test('Geschäftsposition wird bei jedem Zahlungsweg gebucht', () {
      for (final w in Zahlungsweg.values) {
        expect(SpesenImportService.positionBuchen('essen', w), isTrue);
        expect(SpesenImportService.positionBuchen('benzin', w), isTrue);
      }
    });
  });
}
