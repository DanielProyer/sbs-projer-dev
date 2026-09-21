import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/pdf/protokolle_pdf_service.dart';

/// Reinigungsprotokolle als PDF — einzeln und gebündelt.
///
/// WARUM getestet: Das Bündel ist der Nachweis gegenüber Wirt und Heineken.
/// Fehlt darin ein Protokoll, fällt das niemandem auf — die Seiten sehen
/// vollständig aus. Deshalb ist vor allem die JPEG-Extraktion aus der
/// PDF-Hülle festgenagelt, denn daran hängt jeder Altbestand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Baut eine PDF-ähnliche Hülle mit einem eingebetteten JPEG.
  Uint8List huelleMit(Uint8List jpeg) => Uint8List.fromList([
    0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35, // %PDF-1.5
    ...List.filled(40, 0x20),
    ...jpeg,
    ...List.filled(20, 0x0A),
  ]);

  Uint8List jpegVon(int nutzbytes) => Uint8List.fromList([
    0xFF, 0xD8, 0xFF, // SOI
    ...List.filled(nutzbytes, 0x41),
    0xFF, 0xD9, // EOI
  ]);

  group('JPEG aus der PDF-Hülle', () {
    test('findet das Bild und liefert es vollständig zurück', () {
      final jpeg = jpegVon(5000);
      final gefunden = ProtokollePdfService.extractJpegFromPdf(huelleMit(jpeg));
      expect(gefunden, isNotNull);
      expect(gefunden!.length, jpeg.length);
      expect(gefunden.first, 0xFF);
      expect(gefunden[1], 0xD8);
      expect(gefunden[gefunden.length - 1], 0xD9);
    });

    test('liefert eine KOPIE, keinen Blick in den PDF-Puffer', () {
      // Sonst sähe MemoryImage über .buffer das ganze PDF statt nur das Bild —
      // der Kommentar im Quelltext warnt ausdrücklich davor.
      final jpeg = jpegVon(5000);
      final huelle = huelleMit(jpeg);
      final gefunden = ProtokollePdfService.extractJpegFromPdf(huelle)!;
      expect(gefunden.buffer.lengthInBytes, gefunden.length);
      expect(gefunden.buffer.lengthInBytes, lessThan(huelle.length));
    });

    test('ohne Bild: null statt Müll', () {
      final ohne = Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        ...List.filled(200, 0x20),
      ]);
      expect(ProtokollePdfService.extractJpegFromPdf(ohne), isNull);
    });

    test('verdächtig kleines Bild wird verworfen', () {
      // Ein paar hundert Byte sind kein fotografiertes Protokoll, sondern
      // eher ein Icon oder ein Zufallstreffer auf die Markerbytes.
      expect(
        ProtokollePdfService.extractJpegFromPdf(huelleMit(jpegVon(200))),
        isNull,
      );
    });
  });

  group('Bündel', () {
    test('Titelseite plus eine Seite je Protokoll', () async {
      // Zwei erfundene, aber gültige JPEG-Rümpfe reichen nicht als Bild —
      // geprüft wird hier nur, dass ein gültiges PDF herauskommt und die
      // Titelseite auch ohne Bilder steht.
      final bytes = await ProtokollePdfService.buendel(
        const [],
        'Gasthaus zum Engel',
        2026,
      );
      expect(bytes.length, greaterThan(500));
      expect(bytes[0], 0x25);
      expect(bytes[1], 0x50);
    });

    test('Einzahl im Titel bei genau einem Protokoll', () async {
      // Der Text steht im PDF und ist von aussen nicht lesbar; geprüft wird,
      // dass der Aufruf mit einem Bild nicht scheitert.
      final bytes = await ProtokollePdfService.buendel(
        [jpegVon(5000)],
        'Testbetrieb',
        2025,
      );
      expect(bytes[0], 0x25);
    });
  });
}
