// lib/services/mail/bericht_mail_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BerichtMailService {
  /// Fallback, falls kein Empfänger ermittelbar.
  static const fallbackEmpfaenger = 'dani.proyer@gmail.com';

  static Future<void> send({
    required String to,
    required String subject,
    required String bodyText,
    required String filename,
    required Uint8List pdf,
  }) async {
    await SupabaseService.client.functions.invoke('send-pdf-mail', body: {
      'to': to,
      'subject': subject,
      'bodyText': bodyText,
      'filename': filename,
      'pdfBase64': base64Encode(pdf),
    });
  }
}
