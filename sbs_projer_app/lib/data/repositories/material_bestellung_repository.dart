import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/material_bestellung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MaterialBestellungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<MaterialBestellung>> getAll() async {
    final rows = await SupabaseService.client
        .from('material_bestellungen')
        .select()
        .eq('user_id', _userId)
        .order('datum', ascending: false);
    return rows.map((r) => MaterialBestellung.fromJson(r)).toList();
  }

  static Future<MaterialBestellung?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('material_bestellungen')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return MaterialBestellung.fromJson(rows.first);
  }

  static Future<List<MaterialBestellposition>> getPositionen(
      String bestellungId) async {
    final rows = await SupabaseService.client
        .from('material_bestellpositionen')
        .select()
        .eq('bestellung_id', bestellungId)
        .order('sortierung');
    return rows.map((r) => MaterialBestellposition.fromJson(r)).toList();
  }

  static Future<String> nextBestellNr() async {
    final rows = await SupabaseService.client
        .from('material_bestellungen')
        .select('bestell_nr')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 'MB-001';
    final last = rows.first['bestell_nr'] as String;
    final numMatch = RegExp(r'(\d+)$').firstMatch(last);
    if (numMatch == null) return 'MB-001';
    final next = int.parse(numMatch.group(1)!) + 1;
    return 'MB-${next.toString().padLeft(3, '0')}';
  }

  static Future<MaterialBestellung> create({
    required String bestellNr,
    required DateTime datum,
    String? empfaengerName,
    String? empfaengerEmail,
    String? notizen,
    required List<MaterialBestellposition> positionen,
  }) async {
    final bestellungRows = await SupabaseService.client
        .from('material_bestellungen')
        .insert({
          'user_id': _userId,
          'bestell_nr': bestellNr,
          'datum': datum.toIso8601String().substring(0, 10),
          'empfaenger_name': empfaengerName,
          'empfaenger_email': empfaengerEmail,
          'status': 'entwurf',
          'notizen': notizen,
        })
        .select();

    final bestellung = MaterialBestellung.fromJson(bestellungRows.first);

    if (positionen.isNotEmpty) {
      await SupabaseService.client.from('material_bestellpositionen').insert(
            positionen
                .map((p) => {
                      ...p.toJson(),
                      'bestellung_id': bestellung.id,
                    })
                .toList(),
          );
    }

    return bestellung;
  }

  static Future<void> updateStatus(String id, String status) async {
    await SupabaseService.client
        .from('material_bestellungen')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Bucht die Abholung **atomar** (Bestände +, `menge_erhalten`, Status
  /// 'abgeholt'). [mengen]: positionId → erhaltene Menge (aus `abholPayload`).
  /// Wirft, wenn die Bestellung nicht im Status 'gesendet' ist — dann wurde
  /// nichts geschrieben (Transaktion).
  static Future<void> abholen(
      String bestellungId, Map<String, double> mengen) async {
    await SupabaseService.client.rpc('material_bestellung_abholen', params: {
      'p_bestellung_id': bestellungId,
      'p_mengen': mengen,
    });
  }

  /// Macht die Abholung **atomar** rückgängig (Bestände −, `menge_erhalten`
  /// gelöscht, Status zurück auf 'gesendet').
  static Future<void> abholungRueckgaengig(String bestellungId) async {
    await SupabaseService.client.rpc(
      'material_bestellung_abholung_rueckgaengig',
      params: {'p_bestellung_id': bestellungId},
    );
  }

  static Future<void> setPdfPath(String id, String path) async {
    await SupabaseService.client
        .from('material_bestellungen')
        .update({'pdf_storage_path': path})
        .eq('id', id);
  }

  static Future<void> uploadPdf(String bestellungId, Uint8List pdfBytes) async {
    final path = '$_userId/$bestellungId/bestellung.pdf';
    await SupabaseService.client.storage
        .from('bestellung-pdfs')
        .uploadBinary(path, pdfBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ));
    await setPdfPath(bestellungId, path);
  }

  static Future<String> getSignedPdfUrl(String path) async {
    return SupabaseService.client.storage
        .from('bestellung-pdfs')
        .createSignedUrl(path, 3600);
  }
}
