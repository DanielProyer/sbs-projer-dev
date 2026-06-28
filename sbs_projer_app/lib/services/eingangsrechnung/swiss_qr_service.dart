import 'dart:typed_data';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_data.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_decoder_export.dart';

/// Dekodiert den Swiss-QR-Code eines Belegs (PDF/Bild) und liefert die
/// strukturierten Zahldaten — oder null, wenn kein QR-Code gelesen werden
/// konnte (z.B. schlechter Scan, kein QR, Native-Plattform).
class SwissQrService {
  static Future<SwissQrData?> decode({
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final raw = await decodeQrRaw(bytes, mediaType);
    if (raw == null || raw.isEmpty) return null;
    return parseSwissQrPayload(raw);
  }
}
