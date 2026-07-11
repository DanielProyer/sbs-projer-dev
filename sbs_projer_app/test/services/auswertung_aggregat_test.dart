import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_modell.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_aggregat.dart';

void main() {
  group('aggregiere / MonatsWerte', () {
    test('summiert Kategorien, Kunde/Heineken/Total netto+brutto', () {
      final daten = aggregiere([
        const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 100, 108),
        const ArbeitsPosten(AuswertungKategorie.montage, 2025, 6, 200, 216),
        const ArbeitsPosten(AuswertungKategorie.stoerung, 2025, 6, 50, 54),
      ]);
      final m = daten.monat(2025, 6)!;
      expect(m.anzahlGesamt, 3);
      expect(m.reinigungKunde(false), 100);
      expect(m.rechnungHk(false), 250); // montage + stoerung
      expect(m.total(false), 350);
      expect(m.reinigungKunde(true), 108);
      expect(m.rechnungHk(true), 270);
      expect(m.total(true), 378);
    });

    test('reinigungHk zählt zu Heineken, nicht zu Kunde', () {
      final daten = aggregiere([
        const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 100, 108),
        const ArbeitsPosten(AuswertungKategorie.reinigungHk, 2025, 6, 80, 86),
      ]);
      final m = daten.monat(2025, 6)!;
      expect(m.reinigungKunde(false), 100);
      expect(m.rechnungHk(false), 80);
      expect(m.total(false), 180);
    });

    test('gleiche Kategorie im selben Monat wird addiert (Anzahl hoch)', () {
      final daten = aggregiere([
        const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 100, 108),
        const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 50, 54),
      ]);
      final w = daten.monat(2025, 6)!.kat(AuswertungKategorie.reinigung);
      expect(w.anzahl, 2);
      expect(w.netto, 150);
      expect(w.brutto, 162);
    });

    test('leerer / fehlender Monat liefert Nullwerte', () {
      final daten = aggregiere([
        const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 100, 108),
      ]);
      expect(daten.monat(2025, 3), isNull);
      final leer = daten.monateVon(2025)[2]; // März
      expect(leer.anzahlGesamt, 0);
      expect(leer.total(false), 0);
    });
  });

  group('Reduktionen', () {
    final daten = aggregiere([
      const ArbeitsPosten(AuswertungKategorie.reinigung, 2024, 6, 100, 108),
      const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 6, 120, 130),
      const ArbeitsPosten(AuswertungKategorie.montage, 2025, 6, 200, 216),
      const ArbeitsPosten(AuswertungKategorie.reinigung, 2025, 7, 90, 97),
    ]);

    test('jahresWerte summiert alle Monate', () {
      final j = daten.jahresWerte(2025);
      expect(j.monat, 0);
      expect(j.kat(AuswertungKategorie.reinigung).netto, 210); // 120 + 90
      expect(j.rechnungHk(false), 200); // montage
      expect(j.total(false), 410);
    });

    test('monateVon füllt 12 Monate', () {
      expect(daten.monateVon(2025).length, 12);
      expect(daten.monateVon(2025)[5].jahr, 2025); // Juni
    });

    test('monatsvergleich: Juni über Jahre', () {
      final juni = daten.monatsvergleich(6);
      expect(juni.keys.toList()..sort(), [2024, 2025]);
      expect(juni[2024]!.total(false), 100);
      expect(juni[2025]!.total(false), 320); // reinigung 120 + montage 200
    });

    test('jahre aufsteigend', () {
      expect(daten.jahre, [2024, 2025]);
    });
  });
}
