import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnung_zustellung.dart';

void main() {
  group('zustellungsText', () {
    test('zeigt beide Daten, wenn übergeben und versendet gesetzt sind', () {
      expect(
        zustellungsText(
          uebergebenAm: DateTime(2026, 7, 7),
          versendetAm: DateTime(2026, 8, 4),
        ),
        'Übergeben 07.07.2026 · Versendet 04.08.2026',
      );
    });

    test('zeigt nur Übergabe, wenn nur uebergebenAm gesetzt ist', () {
      expect(
        zustellungsText(uebergebenAm: DateTime(2026, 7, 7)),
        'Übergeben 07.07.2026',
      );
    });

    test('zeigt nur Versand, wenn nur versendetAm gesetzt ist', () {
      expect(
        zustellungsText(versendetAm: DateTime(2026, 8, 4)),
        'Versendet 04.08.2026',
      );
    });

    test('zeigt einen Strich, wenn keines gesetzt ist', () {
      expect(zustellungsText(), '—');
    });
  });
}
