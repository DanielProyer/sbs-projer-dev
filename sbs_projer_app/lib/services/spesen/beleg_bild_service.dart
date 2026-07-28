import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Bildbearbeitung für gescannte Belege.
///
/// Hintergrund (Daniel 26.07.2026): Belege wurden mehrfach falsch
/// ausgerichtet gespeichert. Die Drehung wirkt auf die Bytes, die
/// anschliessend im Storage landen — die bereits erkannten Werte bleiben
/// unverändert (Entscheid 28.07.: kein erneuter KI-Durchlauf nach dem Drehen).
class BelegBildService {
  /// Dreht das Bild um `grad` (90, 180 oder 270) im Uhrzeigersinn.
  /// Gibt bei nicht lesbaren Daten die Eingabe unverändert zurück.
  static Uint8List drehen(Uint8List bytes, int grad, {String dateityp = 'jpg'}) {
    final normiert = ((grad % 360) + 360) % 360;
    if (normiert == 0) return bytes;

    final bild = img.decodeImage(bytes);
    if (bild == null) return bytes;

    final gedreht = img.copyRotate(bild, angle: normiert);
    return dateityp == 'png'
        ? img.encodePng(gedreht)
        : img.encodeJpg(gedreht, quality: 88);
  }
}
