import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

void main() {
  group('SollIst', () {
    test('definitiv vorhanden: offen = definitiv - bezahlt', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2024, bundProvisorisch: 1088, bundDefinitiv: 2405.50, kantonProvisorisch: 1279, kantonDefinitiv: 2748),
        bezahlt: {'bund': 2405.50, 'kanton': 2748.00},
      );
      expect(s.zeile('bund').offen, closeTo(0, 0.001));
      expect(s.zeile('kanton').definitiv, 2748.00);
      expect(s.totalDefinitiv, 5153.50);
      expect(s.totalOffen, closeTo(0, 0.001));
      expect(s.ampel, SteuerAmpel.ausgeglichen);
    });
    test('ohne definitiv: offen = provisorisch - bezahlt; Zeile ist provisorisch', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2025, bundProvisorisch: 2405.50, kantonProvisorisch: 2748),
        bezahlt: {'bund': 2405.50, 'kanton': 2748.00, 'busse': 0},
      );
      expect(s.zeile('bund').offen, closeTo(0, 0.001));
      expect(s.zeile('bund').istProvisorisch, isTrue);
    });
    test('Rückzahlung: bezahlt netto negativ → offen positiv (Zins zu Gunsten der Firma), Ampel schuld', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2019, bundDefinitiv: 0, kantonDefinitiv: 47),
        bezahlt: {'bund': -9.20, 'kanton': 47.0},
      );
      expect(s.zeile('bund').offen, closeTo(9.20, 0.001));
      expect(s.ampel, SteuerAmpel.schuld);
    });
    test('Guthaben: mehr bezahlt als definitiv → Ampel guthaben, totalOffen negativ', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2023, bundDefinitiv: 1088, kantonDefinitiv: 1279),
        bezahlt: {'bund': 1088, 'kanton': 1309},
      );
      expect(s.totalOffen, closeTo(-30, 0.001));
      expect(s.ampel, SteuerAmpel.guthaben);
    });
    test('unbekannte Steuerart aus der View erscheint als eigene Zeile und zählt in totalBezahlt', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2022),
        bezahlt: {'kanton': 56, 'unbekannt': 12.5},
      );
      expect(s.zeilen.any((z) => z.steuerart == 'unbekannt'), isTrue);
      expect(s.totalBezahlt, closeTo(68.5, 0.001));
    });
    test('mwst und busse: definitiv = bezahlt, nie offen', () {
      final s = SteuerjahrRechner.sollIst(jahr: const Steuerjahr(jahr: 2022), bezahlt: {'mwst': 394.20, 'busse': 150});
      expect(s.zeile('mwst').offen, closeTo(0, 0.001));
      expect(s.zeile('busse').definitiv, 150);
    });
  });

  group('Dossier', () {
    test('abgeschlossenes Jahr: 4 von 6', () {
      final d = SteuerjahrRechner.dossier(jahr: 2024, heute: DateTime(2026, 9, 2), vorhanden: [
        ('jahresrechnung', null), ('lohnausweis', null), ('steuererklaerung', null), ('veranlagung', 'bund'),
      ]);
      expect(d.vorhanden, 4);
      expect(d.total, 6);
      expect(d.fehlend, ['zinsausweis', 'veranlagung:kanton']);
    });
    test('laufendes Jahr: 3 Pflichttypen', () {
      final d = SteuerjahrRechner.dossier(jahr: 2026, heute: DateTime(2026, 9, 2), vorhanden: []);
      expect(d.total, 3);
      expect(d.vorhanden, 0);
    });
  });
}
