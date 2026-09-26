import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class RechnungPdfStorage {
  static const _bucket = 'rechnung-pdfs';
  static String get _userId => SupabaseService.currentUser!.id;

  /// PDF in Supabase Storage hochladen
  static Future<void> uploadPdf(String rechnungId, Uint8List bytes) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';

    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Liegt das Rechnungs-PDF wirklich im Storage?
  ///
  /// Bewusst am Storage geprüft und nicht an `pdf_url` in der Datenbank: Am
  /// 01.09.2026 brach ein Upload ab, während die Rechnung selbst angelegt war.
  /// Nur die Ablage weiss, ob die Datei existiert — die DB kennt bestenfalls
  /// eine alte Signatur.
  static Future<bool> existiert(String rechnungId) async {
    try {
      final eintraege = await SupabaseService.client.storage
          .from(_bucket)
          .list(path: '$_userId/$rechnungId');
      return eintraege.any((f) => f.name == 'rechnung.pdf');
    } catch (_) {
      return false;
    }
  }

  /// Signed URL für das PDF (1 Stunde gültig)
  static Future<String> getSignedUrl(String rechnungId) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// Protokolle-PDF hochladen (separate Datei neben der Rechnung)
  static Future<void> uploadProtokollePdf(String rechnungId, Uint8List bytes) async {
    final path = '$_userId/$rechnungId/protokolle.pdf';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Signed URL für das Protokolle-PDF (1 Stunde gültig)
  static Future<String> getProtokollSignedUrl(String rechnungId) async {
    final path = '$_userId/$rechnungId/protokolle.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// Signed URL für ein Mahnungs-PDF aus der Zeit vor dem Mahnlauf
  /// (bis v0.133 je Rechnung als `mahnung_<stufe>.pdf` abgelegt; neue
  /// Schreiben liegen unter `mahnungen/<id>/`, siehe [getMahnlaufSignedUrl]).
  static Future<String> getMahnungSignedUrl(
      String rechnungId, int stufe) async {
    final path = '$_userId/$rechnungId/mahnung_$stufe.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// PDF aus Storage löschen
  static Future<void> deletePdf(String rechnungId) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';
    await SupabaseService.client.storage.from(_bucket).remove([path]);
  }

  /// Mahnlauf-PDF hochladen (v0.134.0): Mahnschreiben, Kontoauszug-Beilage
  /// oder Druck-Variante eines Sammel-Mahnschreibens. [mahnschreibenId] wird
  /// vom Aufrufer client-seitig per Uuid erzeugt (üblicher Weg im Projekt),
  /// damit der Storage-Pfad schon vor dem DB-Insert des Protokolls feststeht.
  ///
  /// WARUM `SupabaseService.dataUserId` statt [_userId]: Das Mahnprotokoll
  /// (`mahnschreiben`-Zeile) trägt `user_id = dataUserId`, damit RLS
  /// (`user_id = auth.uid()`) greift — der Pfad muss mit demselben Präfix
  /// beginnen, sonst lehnt `send-rechnung-mail` den Anhang ab
  /// (`zusatzPdfPfadErlaubt`). Für Daniel (kein Gast) ist das identisch mit
  /// [_userId].
  static Future<void> uploadMahnlaufPdf(
      String mahnschreibenId, String datei, Uint8List bytes) async {
    final path =
        '${SupabaseService.dataUserId}/mahnungen/$mahnschreibenId/$datei';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Mahnfall-PDF hochladen (v0.135.0): Kontoauszug-Beilage der Mail an
  /// Heineken. Gleiches Präfix `dataUserId` wie [uploadMahnlaufPdf] (sonst
  /// lehnt `send-rechnung-mail` den Anhang ab), Ordner `mahnfaelle`.
  static Future<void> uploadMahnfallPdf(
      String fallId, String datei, Uint8List bytes) async {
    final path = '${SupabaseService.dataUserId}/mahnfaelle/$fallId/$datei';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Signed URL für ein Mahnlauf-PDF (Mahnschreiben, Kontoauszug oder Druck).
  static Future<String> getMahnlaufSignedUrl(
      String mahnschreibenId, String datei) async {
    final path =
        '${SupabaseService.dataUserId}/mahnungen/$mahnschreibenId/$datei';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }
}
