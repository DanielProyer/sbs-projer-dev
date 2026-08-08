import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/heineken_pdf_regenerierbar.dart';

void main() {
  // PDF-Services laden die Unicode-Schrift aus den Assets (rootBundle).
  TestWidgetsFlutterBinding.ensureInitialized();
  group('darfHeinekenPdfNeuGenerieren', () {
    test('App-Ära ab April 2026 ist erlaubt', () {
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2026, 4, 1)), isTrue);
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2026, 6, 1)), isTrue);
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2026, 12, 1)), isTrue);
    });

    test('historische Monate (Original-PDFs im Storage) sind gesperrt', () {
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2026, 3, 1)), isFalse);
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2019, 5, 1)), isFalse);
      expect(darfHeinekenPdfNeuGenerieren(DateTime(2025, 12, 1)), isFalse);
    });

    test('ohne Monat greift die Sperre nicht (Fehlerfall behandelt der Aufrufer)', () {
      expect(darfHeinekenPdfNeuGenerieren(null), isTrue);
    });
  });
}
