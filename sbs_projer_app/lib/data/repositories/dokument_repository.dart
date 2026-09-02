import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class DokumentRepository {
  static String get _userId => SupabaseService.dataUserId;
  static const _bucket = 'dokumente';

  /// Alle Dokumente eines Bereichs (optional eines Jahres), neueste zuerst.
  static Future<List<Dokument>> getAll({String? bereich, int? jahr}) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      var q =
          SupabaseService.client.from('dokumente').select().eq('user_id', _userId);
      if (bereich != null) q = q.eq('bereich', bereich);
      if (jahr != null) q = q.eq('jahr', jahr);
      final rows = await q
          .order('jahr', ascending: false)
          // Dokumente ohne Datum nach unten statt an den Anfang.
          .order('dokument_datum', ascending: false, nullsFirst: false)
          .order('id') // stabile Pagination
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map(Dokument.fromJson).toList();
  }

  /// Datei hochladen + Metadaten anlegen. Die Dokument-ID wird vorab erzeugt,
  /// damit sie Teil des Storage-Pfads ist (eindeutig, ohne Timestamp-Raten).
  static Future<Dokument> upload({
    required String bereich,
    required String typ,
    String? kategorie,
    int? jahr,
    DateTime? dokumentDatum,
    double? betrag,
    String? referenz,
    required String titel,
    String? notizen,
    required String dateiname,
    required String dateityp,
    required Uint8List bytes,
    String? buchungId,
  }) async {
    final id = const Uuid().v4();
    final pfad = dokumentStoragePfad(
      userId: _userId,
      bereich: bereich,
      jahr: jahr,
      dokumentId: id,
      dateiname: dateiname,
    );
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: FileOptions(contentType: dateityp, upsert: true),
        );
    // Scheitert der Insert, muss die bereits hochgeladene Datei weg — sonst
    // liegt sie ohne DB-Zeile im Bucket und ist über die App nicht mehr
    // auffindbar (für `buchungs-belege` brauchte genau das nachträglich eine
    // Aufräum-RPC).
    try {
      final rows = await SupabaseService.client.from('dokumente').insert({
        'id': id,
        'user_id': _userId,
        'bereich': bereich,
        'typ': typ,
        'kategorie': kategorie,
        'jahr': jahr,
        'dokument_datum': dokumentDatum?.toIso8601String().split('T').first,
        'betrag': betrag,
        'referenz': referenz,
        'titel': titel,
        'notizen': notizen,
        'dateiname': dateiname,
        'dateityp': dateityp,
        'groesse_bytes': bytes.length,
        'storage_pfad': pfad,
        'buchung_id': buchungId,
      }).select();
      return Dokument.fromJson(rows.first);
    } catch (_) {
      try {
        await SupabaseService.client.storage.from(_bucket).remove([pfad]);
      } catch (e) {
        debugPrint('Dokument-Upload: Aufräumen von $pfad fehlgeschlagen: $e');
      }
      rethrow;
    }
  }

  static Future<void> update(String id, Map<String, dynamic> felder) async {
    await SupabaseService.client
        .from('dokumente')
        .update({...felder, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Erst die DB-Zeile, dann die Datei. Scheitert nur das Storage-Löschen,
  /// bleibt eine verwaiste Datei zurück — das Dokument gilt aber als gelöscht,
  /// deshalb wird der Fehler nur protokolliert und nicht weitergereicht.
  static Future<void> delete(Dokument d) async {
    await SupabaseService.client.from('dokumente').delete().eq('id', d.id);
    try {
      await SupabaseService.client.storage.from(_bucket).remove([d.storagePfad]);
    } catch (e) {
      debugPrint('Dokument gelöscht, Datei ${d.storagePfad} blieb liegen: $e');
    }
  }

  static Future<String> signedUrl(String storagePfad) =>
      SupabaseService.client.storage.from(_bucket).createSignedUrl(storagePfad, 3600);

  static Future<Uint8List> download(String storagePfad) =>
      SupabaseService.client.storage.from(_bucket).download(storagePfad);
}
