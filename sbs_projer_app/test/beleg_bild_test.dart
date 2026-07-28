import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbs_projer_app/services/spesen/beleg_bild_service.dart';

void main() {
  /// Querformat-Testbild mit optionalem EXIF-Orientation-Tag.
  List<int> testBild({int? orientation}) {
    final bild = img.Image(width: 40, height: 20);
    img.fill(bild, color: img.ColorRgb8(200, 200, 200));
    if (orientation != null) {
      bild.exif.imageIfd.orientation = orientation;
    }
    return img.encodeJpg(bild);
  }

  group('autoAusrichten (EXIF)', () {
    test('Orientation 6 (90° gedreht aufgenommen) -> Pixel werden gedreht', () {
      final ein = testBild(orientation: 6);
      final aus = BelegBildService.autoAusrichten(ein);
      final bild = img.decodeImage(Uint8List.fromList(aus))!;
      expect(bild.width, 20);
      expect(bild.height, 40);
    });

    test('Orientation 1 (bereits richtig) -> Bytes unverändert', () {
      final ein = testBild(orientation: 1);
      expect(BelegBildService.autoAusrichten(ein), same(ein));
    });

    test('ohne EXIF -> Bytes unverändert (kein Neu-Encodieren)', () {
      final ein = testBild();
      expect(BelegBildService.autoAusrichten(ein), same(ein));
    });

    test('unlesbare Daten -> Eingabe unverändert', () {
      final unlesbar = [1, 2, 3, 4, 5];
      expect(BelegBildService.autoAusrichten(unlesbar), same(unlesbar));
    });
  });

  group('drehen', () {
    test('90° tauscht Breite und Höhe', () {
      final aus = BelegBildService.drehen(testBild(), 90);
      final bild = img.decodeImage(Uint8List.fromList(aus))!;
      expect(bild.width, 20);
      expect(bild.height, 40);
    });

    test('180° behält die Masse', () {
      final aus = BelegBildService.drehen(testBild(), 180);
      final bild = img.decodeImage(Uint8List.fromList(aus))!;
      expect(bild.width, 40);
      expect(bild.height, 20);
    });

    test('0° gibt die Eingabe unverändert zurück', () {
      final ein = testBild();
      expect(BelegBildService.drehen(ein, 0), same(ein));
    });
  });
}
