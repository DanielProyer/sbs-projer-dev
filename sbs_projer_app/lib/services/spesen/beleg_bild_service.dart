import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Bildbearbeitung für gescannte Belege.
///
/// Hintergrund (Daniel 26.07.2026): Belege wurden mehrfach falsch
/// ausgerichtet gespeichert. Ursache ist die EXIF-Orientierung — das Handy
/// speichert das Foto liegend und vermerkt die Drehung nur als Tag, das beim
/// Weiterverarbeiten verloren geht. `autoAusrichten` backt die Drehung in die
/// Pixel, bevor der Beleg zur Erkennung und ins Archiv geht; `drehen` bleibt
/// für die Handkorrektur.
class BelegBildService {
  /// Wendet eine vorhandene EXIF-Orientierung auf die Pixel an.
  ///
  /// Gibt die Eingabe **unverändert** zurück, wenn kein Tag gesetzt ist, das
  /// Bild bereits richtig steht oder die Daten nicht lesbar sind — so wird
  /// nichts unnötig neu komprimiert und ein bereits gedrehtes Bild nicht ein
  /// zweites Mal gedreht.
  static List<int> autoAusrichten(List<int> bytes, {String dateityp = 'jpg'}) {
    try {
      final bild = img.decodeImage(Uint8List.fromList(bytes));
      if (bild == null) return bytes;

      final orientierung = bild.exif.imageIfd.orientation;
      if (orientierung == null || orientierung == 1) return bytes;

      final gerade = img.bakeOrientation(bild);
      return dateityp == 'png'
          ? img.encodePng(gerade)
          : img.encodeJpg(gerade, quality: 88);
    } catch (_) {
      return bytes;
    }
  }

  /// Dreht das Bild um `grad` (90, 180 oder 270) im Uhrzeigersinn.
  /// Gibt bei nicht lesbaren Daten die Eingabe unverändert zurück.
  static List<int> drehen(List<int> bytes, int grad, {String dateityp = 'jpg'}) {
    final normiert = ((grad % 360) + 360) % 360;
    if (normiert == 0) return bytes;

    try {
      final bild = img.decodeImage(Uint8List.fromList(bytes));
      if (bild == null) return bytes;

      final gedreht = img.copyRotate(bild, angle: normiert);
      return dateityp == 'png'
          ? img.encodePng(gedreht)
          : img.encodeJpg(gedreht, quality: 88);
    } catch (_) {
      return bytes;
    }
  }
}
