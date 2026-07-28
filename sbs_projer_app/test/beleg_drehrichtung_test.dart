import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbs_projer_app/services/spesen/beleg_bild_service.dart';

/// Beweist die Drehrichtung an einem Marker statt an den Bildmassen —
/// 90° links und 90° rechts tauschen beide Breite und Höhe, nur die Lage des
/// Markers verrät, in welche Richtung tatsächlich gedreht wurde.
void main() {
  /// 40x20-Bild, schwarzer Block OBEN LINKS.
  Uint8List markerBild() {
    final bild = img.Image(width: 40, height: 20);
    img.fill(bild, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(bild,
        x1: 0, y1: 0, x2: 9, y2: 4, color: img.ColorRgb8(0, 0, 0));
    return Uint8List.fromList(img.encodeJpg(bild));
  }

  bool istDunkel(img.Image b, int x, int y) => b.getPixel(x, y).r < 100;

  test('drehen(90) dreht im Uhrzeigersinn: oben links -> oben rechts', () {
    final aus = img.decodeImage(
        Uint8List.fromList(BelegBildService.drehen(markerBild(), 90)))!;
    expect(aus.width, 20);
    expect(aus.height, 40);
    // Im Uhrzeigersinn wandert die obere linke Ecke nach oben rechts.
    expect(istDunkel(aus, aus.width - 2, 2), isTrue,
        reason: 'Marker muss oben rechts liegen');
    expect(istDunkel(aus, 2, 2), isFalse,
        reason: 'oben links muss frei sein');
  });

  test('drehen(270) dreht gegen den Uhrzeigersinn: oben links -> unten links',
      () {
    final aus = img.decodeImage(
        Uint8List.fromList(BelegBildService.drehen(markerBild(), 270)))!;
    expect(istDunkel(aus, 2, aus.height - 3), isTrue,
        reason: 'Marker muss unten links liegen');
  });

  test('gedrehtes Bild trägt KEIN EXIF-Orientation-Tag mehr', () {
    // Sonst dreht der Browser beim Anzeigen ein zweites Mal.
    final mitTag = img.Image(width: 40, height: 20);
    mitTag.exif.imageIfd.orientation = 6;
    final ein = Uint8List.fromList(img.encodeJpg(mitTag));

    final gedreht = img.decodeImage(
        Uint8List.fromList(BelegBildService.drehen(ein, 90)))!;
    final orientierung = gedreht.exif.imageIfd.orientation;
    expect(orientierung == null || orientierung == 1, isTrue,
        reason: 'Orientation war $orientierung');
  });

  test('autoAusrichten hinterlässt ebenfalls kein Tag', () {
    final mitTag = img.Image(width: 40, height: 20);
    mitTag.exif.imageIfd.orientation = 6;
    final ein = Uint8List.fromList(img.encodeJpg(mitTag));

    final aus = img.decodeImage(
        Uint8List.fromList(BelegBildService.autoAusrichten(ein)))!;
    final orientierung = aus.exif.imageIfd.orientation;
    expect(orientierung == null || orientierung == 1, isTrue,
        reason: 'Orientation war $orientierung');
  });
}
