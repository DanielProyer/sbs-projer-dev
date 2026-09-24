import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';

void main() {
  group('betreibungsKostenvorschuss (GebV SchKG Art. 16)', () {
    test('Stufen', () {
      expect(betreibungsKostenvorschuss(94.05), 7);
      expect(betreibungsKostenvorschuss(100), 7);
      expect(betreibungsKostenvorschuss(100.05), 20);
      expect(betreibungsKostenvorschuss(470.25), 20);
      expect(betreibungsKostenvorschuss(999), 40);
      expect(betreibungsKostenvorschuss(5000), 60);
      expect(betreibungsKostenvorschuss(50000), 90);
      expect(betreibungsKostenvorschuss(500000), 190);
      expect(betreibungsKostenvorschuss(2000000), 400);
    });
  });

  group('fortsetzungsFenster (SchKG 88)', () {
    test('frühestens 20 Tage nach Zahlungsbefehl, verwirkt nach 1 Jahr', () {
      final f = fortsetzungsFenster(DateTime.utc(2026, 11, 20));
      expect(f.ab, DateTime.utc(2026, 12, 10));
      expect(f.bis, DateTime.utc(2027, 11, 20));
    });
  });

  group('mahnfallAufgaben', () {
    final heute = DateTime.utc(2026, 12, 15);
    test('Heineken seit 20 Tagen ohne Ergebnis → Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'Hemingway, Chur', status: 'heineken',
        heinekenKontaktAm: DateTime.utc(2026, 11, 20), heute: heute);
      expect(a.single.key, 'mahnfall:f1:heineken');
    });
    test('Heineken erst 10 Tage → keine Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'heineken',
        heinekenKontaktAm: DateTime.utc(2026, 12, 5), heute: heute);
      expect(a, isEmpty);
    });
    test('Vermittlungsfrist abgelaufen → dringend', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'heineken_frist',
        heinekenFristBis: DateTime.utc(2026, 12, 10), heute: heute);
      expect(a.single.key, 'mahnfall:f1:frist');
      expect(a.single.dringend, isTrue);
    });
    test('Zahlungsbefehl ohne Rechtsvorschlag, +20 Tage → Fortsetzung möglich', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 11, 20), rechtsvorschlag: false,
        heute: heute);
      expect(a.single.key, 'mahnfall:f1:fortsetzung');
    });
    test('Fortsetzung schon gestellt → keine Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 11, 20), rechtsvorschlag: false,
        fortsetzungAm: DateTime.utc(2026, 12, 12), heute: heute);
      expect(a, isEmpty);
    });
    test('11 Monate nach Zahlungsbefehl ohne Fortsetzung → dringende Warnung', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 1, 10), rechtsvorschlag: true,
        heute: DateTime.utc(2026, 12, 15));
      expect(a.single.key, 'mahnfall:f1:verwirkung');
      expect(a.single.dringend, isTrue);
    });
    test('Übernahme durch Heineken → dringende Buchungsaufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'erledigt',
        erledigung: 'uebernommen', uebernahmeVerbucht: false, heute: heute);
      expect(a.single.key, 'mahnfall:f1:uebernahme');
      expect(a.single.dringend, isTrue);
    });
  });

  test('alleBezahlt: nur wenn jede Rechnung bezahlt oder abgeschrieben', () {
    expect(alleBezahlt(['bezahlt', 'abgeschrieben']), isTrue);
    expect(alleBezahlt(['bezahlt', 'mahnung_2']), isFalse);
    expect(alleBezahlt(const []), isFalse);
  });
}
