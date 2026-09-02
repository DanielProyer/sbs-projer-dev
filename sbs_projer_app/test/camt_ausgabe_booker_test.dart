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
    Map<String, dynamic> felder({
      required bool isCredit,
      int vorlageSoll = 8900,
      int vorlageHaben = 1020,
      double mwstSatz = 0,
      int? mwstKonto,
    }) => ausgabeBuchungsFelder(
      betrag: 2405.50,
      isCredit: isCredit,
      mwstSatz: mwstSatz,
      vorlageSoll: vorlageSoll,
      vorlageHaben: vorlageHaben,
      vorlageMwstKonto: mwstKonto,
    );

    test('Belastung Kanton mit Rückstellung → Soll 2208, Bank bleibt im Haben', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: false),
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
        steuer: const SteuerZuordnung(
            steuerjahr: 2024, steuerart: 'bund', hatRueckstellung: false),
      );
      expect(f['soll_konto'], 1020);
      expect(f['haben_konto'], 8900);
      expect(f['steuerjahr'], 2024);
      expect(f['steuerart'], 'bund');
    });

    test('Rückerstattungs-Vorlage (1020/2208): Bank bleibt im Soll, Steuerkonto ins Haben', () {
      // Die Seite folgt der BANK, nicht der camt-Richtung: eine als 1020/2208
      // definierte Vorlage darf auch bei einer Belastung nicht die Bank
      // überschreiben — sonst verschwindet der Zahlungsweg aus der Buchung.
      final f = steuerFelderAnwenden(
        felder(isCredit: false, vorlageSoll: 1020, vorlageHaben: 2208),
        steuer: const SteuerZuordnung(
            steuerjahr: 2025, steuerart: 'bund', hatRueckstellung: false),
      );
      expect(f['soll_konto'], 1020);
      expect(f['haben_konto'], 8900);
    });

    test('MWST läuft immer über 2202 — auch mit Rückstellung', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: false),
        steuer: const SteuerZuordnung(
            steuerjahr: 2026, steuerart: 'mwst', hatRueckstellung: true),
      );
      expect(f['soll_konto'], 2202);
      expect(f['steuerart'], 'mwst');
    });

    test('Steuern tragen keine Vorsteuer — MwSt-Split wird neutralisiert', () {
      final f = steuerFelderAnwenden(
        felder(isCredit: false, mwstSatz: 8.1, mwstKonto: 1171),
        steuer: const SteuerZuordnung(
            steuerjahr: 2025, steuerart: 'kanton', hatRueckstellung: false),
      );
      expect(f['mwst_konto'], isNull);
      expect(f['mwst_satz'], 0);
      expect(f['mwst_betrag'], 0.0);
      expect(f['betrag_netto'], f['betrag_brutto']);
    });
  });

  group('rueckstellungsRest / rueckstellungsJahre', () {
    test('Echte Datenform (2208-Zeilen ohne steuerjahr): überzogen → leer', () {
      // Produktivstand 02.09.2026: Rückstellung 2025 = 4000 im Abschluss 2025,
      // die beiden Umbuchungen liegen im Geschäftsjahr 2026 und tragen KEIN
      // steuerjahr. Nach Jahren gruppiert sähe 2025 nach +4000 aus, obwohl das
      // Konto gesamthaft mit −1153.50 überzogen ist → keine Rückstellung mehr.
      final buchungen = [
        _b(soll: 8900, haben: 2208, betrag: 4000, geschaeftsjahr: 2025),
        _b(soll: 2208, haben: 8900, betrag: 2405.50, geschaeftsjahr: 2026),
        _b(soll: 2208, haben: 8900, betrag: 2748.00, geschaeftsjahr: 2026),
      ];
      expect(rueckstellungsJahre(buchungen), isEmpty);
      expect(rueckstellungsRest(buchungen), isEmpty);
    });

    test('Jahr mit offener Rückstellung zählt, aufgebrauchtes Jahr nicht', () {
      // Dieselben Zeilen, aber mit zugeordnetem steuerjahr (Import Task 14):
      // 2025 ist aufgebraucht, 2024 trägt noch 5000 — Gesamtsaldo deckelt.
      final buchungen = [
        _b(soll: 8900, haben: 2208, betrag: 4000, geschaeftsjahr: 2025),
        _b(soll: 2208, haben: 8900, betrag: 2405.50, geschaeftsjahr: 2026, steuerjahr: 2025),
        _b(soll: 2208, haben: 8900, betrag: 2748.00, geschaeftsjahr: 2026, steuerjahr: 2025),
        _b(soll: 8900, haben: 2208, betrag: 5000, geschaeftsjahr: 2024),
      ];
      final jahre = rueckstellungsJahre(buchungen);
      expect(jahre.contains(2024), isTrue);
      expect(jahre.contains(2025), isFalse);
      // Gesamtsaldo 4000 − 5153.50 + 5000 = 3846.50 < 5000 → gedeckelt.
      expect(rueckstellungsRest(buchungen)[2024], closeTo(3846.50, 0.005));
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
