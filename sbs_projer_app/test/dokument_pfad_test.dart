import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

void main() {
  test('Storage-Pfad: user/bereich/jahr/id_dateiname', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'steuern',
          jahr: 2025,
          dokumentId: 'd1',
          dateiname: 'Rg 1.pdf'),
      'u1/steuern/2025/d1_Rg_1.pdf',
    );
  });

  test('Storage-Pfad ohne Jahr nutzt ohne-jahr', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'bank',
          jahr: null,
          dokumentId: 'd2',
          dateiname: 'a.pdf'),
      'u1/bank/ohne-jahr/d2_a.pdf',
    );
  });

  test('Storage-Pfad ersetzt Umlaute und Leerzeichen', () {
    expect(
      dokumentStoragePfad(
          userId: 'u1',
          bereich: 'steuern',
          jahr: 2024,
          dokumentId: 'd3',
          dateiname: 'Veranlagung Zürich.pdf'),
      'u1/steuern/2024/d3_Veranlagung_Z_rich.pdf',
    );
  });

  test('Typ-Vorschläge je Bereich: steuern enthält veranlagung, sonstiges immer dabei', () {
    expect(dokumentTypen('steuern'), contains('veranlagung'));
    expect(dokumentTypen('versicherungen'), contains('sonstiges'));
    expect(dokumentTypLabel('rechnung_definitiv'), 'Rechnung definitiv');
  });

  test('Unbekannter Bereich/Typ fällt sauber zurück', () {
    expect(dokumentTypen('unbekannt'), ['sonstiges']);
    expect(dokumentTypLabel('xyz'), 'xyz');
  });

  test('Pflicht-Typen: abgeschlossenes Jahr 6, laufendes Jahr 3', () {
    expect(pflichtTypen(jahr: 2024, heute: DateTime(2026, 9, 2)).length, 6);
    expect(pflichtTypen(jahr: 2026, heute: DateTime(2026, 9, 2)),
        ['jahresrechnung', 'lohnausweis', 'zinsausweis']);
  });

  test('Pflicht-Typ-Label: mit und ohne Steuerart-Suffix', () {
    expect(pflichtTypLabel('veranlagung:kanton'), 'Veranlagungsverfügung Kanton/Gemeinde');
    expect(pflichtTypLabel('jahresrechnung'), 'Jahresrechnung');
  });

  group('Kategorien je Bereich', () {
    test('Steuern behalten ihre Steuerarten', () {
      final k = dokumentKategorien('steuern');
      expect(k, isNotNull);
      expect(k!.keys, containsAll(['bund', 'kanton', 'mwst', 'busse']));
    });

    test('Versicherungen kennen die Pensionskasse', () {
      final k = dokumentKategorien('versicherungen');
      expect(k, isNotNull);
      expect(k!['pensionskasse'], 'Pensionskasse (BVG)');
      expect(k['ahv'], 'AHV/IV/EO/ALV/FAK (SVA)');
      expect(k.keys, containsAll(['ahv', 'pensionskasse', 'unfall', 'haftpflicht']));
    });

    test('Bereiche ohne feste Liste liefern null (Freitext im Dialog)', () {
      expect(dokumentKategorien('bank'), isNull);
      expect(dokumentKategorien('sonstiges'), isNull);
    });
  });

  group('Dokumenttypen der Versicherungen', () {
    test('decken ab, was im PK-Ordner tatsaechlich liegt', () {
      final t = dokumentTypen('versicherungen');
      expect(
        t,
        containsAll([
          'police',
          'rechnung_definitiv',
          'mahnung',
          'kontoauszug',
          'freizuegigkeit',
          'verfuegung',
          'vertrag',
        ]),
        reason: 'Die Ordner 06_PK und 04_SVA enthalten genau diese Typen',
      );
    });

    test('haben alle ein Label', () {
      for (final typ in dokumentTypen('versicherungen')) {
        expect(dokumentTypLabel(typ), isNot(typ),
            reason: 'Typ $typ ohne Label faellt im UI als Code auf');
      }
    });
  });
}
