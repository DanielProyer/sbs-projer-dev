import 'dart:typed_data';

/// Native-/Fallback-Stub: ohne Browser kein QR-Decoding.
/// Die Web-Implementierung (swiss_qr_decoder_web.dart) ruft pdf.js + jsQR
/// via window.sbsDecodeQr auf.
Future<String?> decodeQrRaw(Uint8List bytes, String mediaType) async => null;
