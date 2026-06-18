import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/erfolgsrechnung_pdf_service.dart';

void main() {
  test('ER-PDF wird ohne Layout-Fehler erzeugt und ist ein echtes PDF', () async {
    const er = ErfolgsrechnungDaten(
      nettoerloes: 50000,
      materialaufwand: 20000,
      personalaufwand: 10000,
      uebrigerAufwand: 5000,
      abschreibungen: 2000,
      finanzerfolg: -500,
      nebenerfolg: 0,
      steuern: 1500,
    );
    final konten = ErKontenAufstellung([
      ErKlasse(3, const [ErKonto(3400, 50000, bezeichnung: 'Dienstleistungserlöse')]),
      ErKlasse(4, const [ErKonto(4000, 20000, bezeichnung: 'Materialaufwand')]),
      ErKlasse(5, const [ErKonto(5000, 10000, bezeichnung: 'Löhne')]),
    ]);

    final bytes = await ErfolgsrechnungPdfService.generate(
      er,
      konten,
      (von: DateTime(2026, 1, 1), bis: DateTime(2026, 12, 31)),
    );

    expect(bytes.isNotEmpty, isTrue);
    // PDF-Magic-Header "%PDF"
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
