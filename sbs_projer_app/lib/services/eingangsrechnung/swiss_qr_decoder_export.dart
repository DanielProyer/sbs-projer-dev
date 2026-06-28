// Conditional Export: Web nutzt dart:js_interop (pdf.js + jsQR via
// window.sbsDecodeQr), Native fällt auf den Stub zurück (null).
export 'swiss_qr_decoder.dart'
    if (dart.library.js_interop) 'swiss_qr_decoder_web.dart';
