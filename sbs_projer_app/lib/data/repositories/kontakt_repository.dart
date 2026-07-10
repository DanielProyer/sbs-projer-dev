import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/kontakt.dart';
import 'package:sbs_projer_app/data/mappers/kontakt_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class KontaktRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<KontaktLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('kontakte').select()
          .eq('user_id', _userId)
          .order('kategorie')
          .order('vorname');
      return rows.map((r) => KontaktMapper.fromDto(Kontakt.fromJson(r))).toList();
    }
    return IsarService.kontaktFindAll();
  }

  static Future<List<KontaktLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('kontakte').select()
          .eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => KontaktMapper.fromDto(Kontakt.fromJson(r))).toList();
    }
    return IsarService.kontaktFilterByBetrieb(betriebId);
  }

  static Stream<List<KontaktLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.kontaktWatchByBetrieb(betriebId);
  }

  static Future<List<KontaktLocal>> getByKategorie(String kategorie) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('kontakte').select()
          .eq('user_id', _userId).eq('kategorie', kategorie)
          .order('vorname');
      return rows.map((r) => KontaktMapper.fromDto(Kontakt.fromJson(r))).toList();
    }
    return IsarService.kontaktFilterByKategorie(kategorie);
  }

  static Future<KontaktLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('kontakte').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return KontaktMapper.fromDto(Kontakt.fromJson(rows.first));
    }
    return IsarService.kontaktGet(int.parse(id));
  }

  static Future<void> save(KontaktLocal kontakt) async {
    kontakt.userId = _userId;
    // Server-UUID client-seitig generieren (wie EventRepository): damit ist ein
    // offline neu angelegter Kontakt sofort referenzierbar (z.B. Event-Zuordnung).
    kontakt.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = KontaktMapper.toJson(kontakt);
      await SupabaseService.client.from('kontakte').upsert(json);
      return;
    }
    kontakt.isSynced = false;
    kontakt.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.kontaktPut(kontakt);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('kontakte').delete().eq('id', id);
      return;
    }
    await IsarService.kontaktDelete(int.parse(id));
  }

  /// Gibt die erste E-Mail-Adresse für eine Kategorie+Rolle zurück.
  static Future<String?> getEmailByKategorieRolle(String kategorie, String rolle) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('kontakte').select('email')
          .eq('user_id', _userId)
          .eq('kategorie', kategorie)
          .eq('rolle', rolle)
          .not('email', 'is', null)
          .limit(1);
      if (rows.isEmpty) return null;
      final email = rows.first['email'] as String?;
      return (email != null && email.isNotEmpty) ? email : null;
    }
    final all = await getByKategorie(kategorie);
    for (final k in all) {
      if (k.rolle == rolle && k.email != null && k.email!.isNotEmpty) {
        return k.email;
      }
    }
    return null;
  }

  // --- Heineken Kontakt-Zuweisungen ---

  /// Alle Zuweisungen laden (Map: funktion → KontaktLocal?).
  static Future<Map<String, KontaktLocal?>> getAllHeinekenZuweisungen() async {
    final result = <String, KontaktLocal?>{
      'monatsrechnung': null,
      'raster': null,
      'heigenie_service': null,
      'materialbestellung': null,
      'rsl': null,
    };

    final rows = await SupabaseService.client
        .from('heineken_kontakt_zuweisungen')
        .select('funktion, kontakt_id, kontakte(*)')
        .eq('user_id', _userId);

    for (final row in rows) {
      final funktion = row['funktion'] as String;
      final kontaktJson = row['kontakte'] as Map<String, dynamic>?;
      if (kontaktJson != null) {
        result[funktion] = KontaktMapper.fromDto(Kontakt.fromJson(kontaktJson));
      }
    }
    return result;
  }

  /// Einzelne Zuweisung lesen.
  static Future<KontaktLocal?> getHeinekenZuweisung(String funktion) async {
    final rows = await SupabaseService.client
        .from('heineken_kontakt_zuweisungen')
        .select('kontakt_id, kontakte(*)')
        .eq('user_id', _userId)
        .eq('funktion', funktion)
        .limit(1);
    if (rows.isEmpty) return null;
    final kontaktJson = rows.first['kontakte'] as Map<String, dynamic>?;
    if (kontaktJson == null) return null;
    return KontaktMapper.fromDto(Kontakt.fromJson(kontaktJson));
  }

  /// Zuweisung setzen (kontaktId == null → löschen).
  static Future<void> setHeinekenZuweisung(String funktion, String? kontaktId) async {
    if (kontaktId == null) {
      await SupabaseService.client
          .from('heineken_kontakt_zuweisungen')
          .delete()
          .eq('user_id', _userId)
          .eq('funktion', funktion);
    } else {
      await SupabaseService.client.from('heineken_kontakt_zuweisungen').upsert(
        {
          'user_id': _userId,
          'funktion': funktion,
          'kontakt_id': kontaktId,
        },
        onConflict: 'user_id,funktion',
      );
    }
  }
}
