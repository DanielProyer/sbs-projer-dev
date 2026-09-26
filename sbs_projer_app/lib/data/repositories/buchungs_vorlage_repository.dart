import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Buchungsvorlagen (kein Isar).
class BuchungsVorlageRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Einmal geladene Vorlagen, für die restliche Sitzung gehalten.
  ///
  /// WARUM: Der Reinigungsabschluss lädt vor jeder Buchung alle 47 Vorlagen,
  /// nur um daraus eine einzige zu nehmen (Geschäftsfall 1 oder 1.1). Am
  /// 15.09.2026 scheiterte das Buchen und danach auch das Nachbuchen in
  /// Lenzerheide zweimal genau daran: «Failed to fetch» auf
  /// `buchungs_vorlagen`, obwohl die Reinigung längst erfasst war. Bei
  /// schlechtem Empfang in den Bergen hing die ganze Ertragsbuchung an einer
  /// Tabelle, die sich seit dem 10.06.2026 nicht mehr geändert hat.
  ///
  /// Der Cache ist gefahrlos: Diese Klasse hat keine schreibende Methode, die
  /// App kann Vorlagen nur lesen. Geändert werden sie per Migration — dann
  /// reicht ein Neuladen der Seite.
  static List<BuchungsVorlage>? _cache;

  /// Verwirft den Cache — für Tests und einen erzwungenen Neuabruf.
  static Future<List<BuchungsVorlage>> getAll({bool frisch = false}) async {
    if (!frisch && _cache != null) return _cache!;
    try {
      final rows = await SupabaseService.client
          .from('buchungs_vorlagen')
          .select()
          .eq('user_id', _userId)
          .order('geschaeftsfall_id');
      _cache = rows.map((r) => BuchungsVorlage.fromJson(r)).toList();
      return _cache!;
    } catch (_) {
      // Kein Empfang: Der zuletzt bekannte Stand ist allemal besser als eine
      // ausgefallene Ertragsbuchung. Ohne Cache bleibt nur der Fehler.
      if (_cache != null) return _cache!;
      rethrow;
    }
  }

  /// Für die Vorlagen-Liste in der Buchhaltung — die soll den echten Stand
  /// zeigen, nicht den gecachten, und läuft ohnehin am Schreibtisch mit Netz.
  static Stream<List<BuchungsVorlage>> watchAll() {
    return Stream.fromFuture(getAll(frisch: true));
  }

  /// Gibt nur manuelle Vorlagen zurück (ohne auto_trigger).
  static Future<List<BuchungsVorlage>> getManuell() async {
    final rows = await SupabaseService.client
        .from('buchungs_vorlagen')
        .select()
        .eq('user_id', _userId)
        .isFilter('auto_trigger', null)
        .eq('ist_aktiv', true)
        .order('geschaeftsfall_id');
    return rows.map((r) => BuchungsVorlage.fromJson(r)).toList();
  }
}
