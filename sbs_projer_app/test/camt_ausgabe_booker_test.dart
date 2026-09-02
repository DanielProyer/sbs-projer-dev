import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';

Buchung _b({
  required int soll,
  required int haben,
  required double betrag,
  required int geschaeftsjahr,
  int? steuerjahr,
  bool istStorniert = false,
  String? stornoVonId,
}) => Buchung(
  id: 'b${soll}_$haben$betrag$geschaeftsjahr',
  userId: 'u1',
  datum: DateTime(geschaeftsjahr, 12, 31),
  sollKonto: soll,
  habenKonto: haben,
  betragNetto: betrag,
  betragBrutto: betrag,
  beschreibung: 'Test',
  geschaeftsjahr: geschaeftsjahr,
  steuerjahr: steuerjahr,
  istStorniert: istStorniert,
  stornoVonId: stornoVonId,
);

void main() {
  group('steuerKontoFuer', () {
    test('Bund/Kanton mit Rückstellung → 2208, ohne → 8900; Busse → 8900; MWST → 2202', () {
      expect(steuerKontoFuer(steuerart: 'bund', hatRueckstellung: true), 2208);
      expect(steuerKontoFuer(steuerart: 'kanton', hatRueckstellung: false), 8900);
      expect(steuerKontoFuer(steuerart: 'busse', hatRueckstellung: true), 8900);
      expect(steuerKontoFuer(steuerart: 'mwst', hatRueckstellung: true), 2202);
    });

    test('istSteuerKonto erkennt 8900/2208/2202', () {
      expect(istSteuerKonto(8900), isTrue);
      expect(istSteuerKonto(2208), isTrue);
      expect(istSteuerKonto(2202), isTrue);
      expect(istSteuerKonto(6200), isFalse);
    });
  });

  group('steuerFelderAnwenden', () {
    Map<String, dynamic> felder({required bool isCredit}) => ausgabeBuchungsFelder(
      betrag: 2405.50,
      isCredit: isCredit,
      mwstSatz: 0,
      vorlageSoll: 8900,
      vorlageHaben: 1020,
    );

    test('Belastung Kanton mit Rückstellung → Soll 2208, Bank bleibt im Haben', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: false),
        isCredit: false,
        steuer: const SteuerZuordnung(
            steuerjahr: 2025, steuerart: 'kanton', hatRueckstellung: true),
      );
      expect(f['soll_konto'], 2208);
      expect(f['haben_konto'], 1020);
      expect(f['steuerjahr'], 2025);
      expect(f['steuerart'], 'kanton');
      expect(f['betrag_brutto'], 2405.50);
    });

    test('Gutschrift (Rückzahlung) Bund ohne Rückstellung → Haben 8900, Bank im Soll', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: true),
        isCredit: true,
        steuer: const SteuerZuordnung(
            steuerjahr: 2024, steuerart: 'bund', hatRueckstellung: false),
      );
      expect(f['soll_konto'], 1020);
      expect(f['haben_konto'], 8900);
      expect(f['steuerjahr'], 2024);
      expect(f['steuerart'], 'bund');
    });

    test('MWST läuft immer über 2202 — auch mit Rückstellung', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: false),
        isCredit: false,
        steuer: const SteuerZuordnung(
            steuerjahr: 2026, steuerart: 'mwst', hatRueckstellung: true),
      );
      expect(f['soll_konto'], 2202);
      expect(f['steuerart'], 'mwst');
    });
  });

  group('rueckstellungsJahre', () {
    test('Jahr mit offener Rückstellung zählt, aufgebrauchtes Jahr nicht', () {
      // Realfall 02.09.2026: Rückstellung 2025 = 4000 (8900/2208), danach zwei
      // Umbuchungen 2405.50 + 2748.00 (2208/8900) → Saldo negativ, weitere
      // Zahlungen gehören auf 8900, nicht nochmals gegen die Rückstellung.
      final jahre = rueckstellungsJahre([
        _b(soll: 8900, haben: 2208, betrag: 4000, geschaeftsjahr: 2025),
        _b(soll: 2208, haben: 8900, betrag: 2405.50, geschaeftsjahr: 2026, steuerjahr: 2025),
        _b(soll: 2208, haben: 8900, betrag: 2748.00, geschaeftsjahr: 2026, steuerjahr: 2025),
        _b(soll: 8900, haben: 2208, betrag: 5000, geschaeftsjahr: 2024),
      ]);
      expect(jahre.contains(2024), isTrue);
      expect(jahre.contains(2025), isFalse);
    });

    test('Stornierte Buchungen und Gegenbuchungen zählen nicht', () {
      final jahre = rueckstellungsJahre([
        _b(soll: 8900, haben: 2208, betrag: 3000, geschaeftsjahr: 2023, istStorniert: true),
        _b(soll: 2208, haben: 8900, betrag: 3000, geschaeftsjahr: 2023, stornoVonId: 'x'),
        _b(soll: 6200, haben: 1020, betrag: 999, geschaeftsjahr: 2023),
      ]);
      expect(jahre, isEmpty);
    });
  });
}
