// lib/services/mail/bericht_mail_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BerichtMailService {
  /// Fixer Empfänger der Bericht-Mails.
  /// TODO(settings): später E-Mail des Geschäftsführers aus den Einstellungen.
  static const empfaenger = 'dani.proyer@gmail.com';

  static Future<void> send({
    required String subject,
    required String bodyText,
    required String filename,
    required Uint8List pdf,
  }) async {
    await SupabaseService.client.functions.invoke('send-pdf-mail', body: {
      'to': empfaenger,
      'subject': subject,
      'bodyText': bodyText,
      'filename': filename,
      'pdfBase64': base64Encode(pdf),
    });
  }
}
