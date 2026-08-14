import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Storage-Zugriff für Event-Dokumente (PDF) im privaten Bucket 'event-dokumente'.
class EventDokumentStorage {
  static const _bucket = 'event-dokumente';
  static String get _userId => SupabaseService.dataUserId;

  /// Lädt ein PDF hoch und gibt den gespeicherten Pfad zurück.
  /// Pfad: `userId/eventId/uuid.pdf` (erste Ebene = userId für RLS).
  static Future<String> upload(String eventId, Uint8List pdfBytes) async {
    final pfad = '$_userId/$eventId/${const Uuid().v4()}.pdf';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad,
          pdfBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
    return pfad;
  }

  /// Lädt ein Lageplan-Bild (JPG/PNG/WebP) hoch — gleicher Bucket wie die
  /// PDFs, aber mit Bild-ContentType, sonst zeigt der Browser die signierte
  /// URL als Download statt als Bild an.
  static Future<String> uploadBild(
      String eventId, Uint8List bytes, String endung) async {
    final ext = endung.toLowerCase() == 'jpeg' ? 'jpg' : endung.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final pfad = '$_userId/$eventId/${const Uuid().v4()}.$ext';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return pfad;
  }

  /// Lädt ein Typenschild-Foto (Kühler/Pumpe, V2-6) hoch. Deterministischer
  /// Pfad je Gerät+Teil (statt UUID wie bei den anderen Uploads hier) —
  /// ein erneutes Foto überschreibt bewusst das alte (upsert), sonst
  /// sammeln sich bei jeder Nachkorrektur verwaiste Bilder im Bucket.
  static Future<String> uploadTechnikFoto(
    String geraetServerId,
    Uint8List bytes,
    String teil, // 'kuehler' oder 'pumpe'
  ) async {
    final pfad = '$_userId/technik/${geraetServerId}_$teil.jpg';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return pfad;
  }

  /// Signierte URL (1h gültig) zum Öffnen im PDF-Viewer.
  static Future<String> getSignedUrl(String pfad) =>
      SupabaseService.client.storage.from(_bucket).createSignedUrl(pfad, 3600);

  /// Entfernt die Datei aus dem Bucket (Fehler werden geschluckt — Datensatz-Löschung hat Vorrang).
  static Future<void> delete(String pfad) async {
    try {
      await SupabaseService.client.storage.from(_bucket).remove([pfad]);
    } catch (_) {}
  }
}
