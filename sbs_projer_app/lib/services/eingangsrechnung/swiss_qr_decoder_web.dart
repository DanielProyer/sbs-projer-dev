import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

/// Web-Implementierung: ruft die in web/index.html definierte JS-Funktion
/// window.sbsDecodeQr(base64, mediaType) auf. Diese rastert (bei PDF) die
/// erste Seite via pdf.js und liest den QR-Code via jsQR. Rückgabe ist der
/// rohe Swiss-QR-Payload-Text oder null (kein QR / Fehler).
@JS('sbsDecodeQr')
external JSPromise<JSAny?> _sbsDecodeQr(JSString base64, JSString mediaType);

Future<String?> decodeQrRaw(Uint8List bytes, String mediaType) async {
  try {
    final b64 = base64Encode(bytes);
    final res = await _sbsDecodeQr(b64.toJS, mediaType.toJS).toDart;
    if (res == null) return null;
    final str = (res as JSString).toDart;
    return str.isEmpty ? null : str;
  } catch (_) {
    // sbsDecodeQr nicht vorhanden / Bibliothek nicht geladen / Decode-Fehler.
    return null;
  }
}
