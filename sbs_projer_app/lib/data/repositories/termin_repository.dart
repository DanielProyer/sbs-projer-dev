import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Zugriff auf die Tabelle `termine` (Migration 037 + 086 + 130).
///
/// Reines Server-Feature (kein Isar/Offline-Teil) — wie
/// `BetriebVorschlagRepository`: ein bestätigter Termin ohne Kalender-Push
/// wäre wertlos, und der Push braucht ohnehin eine Online-Verbindung.
///
/// Leitgedanke (Etappe 4): «Berechnet bleibt berechnet, bestätigt wird
/// gespeichert.» Die Saison-Automatik (`autoTermineProvider` in
/// `tour_providers.dart`) rechnet immer weiter; erst [anlegen] schreibt hier
/// eine feste Zeile mit Kalender-Erinnerung.
class TerminRepository {
  static String get _userId => SupabaseService.currentUser!.id;
  static const _table = 'termine';

  /// Alle offenen Termine (`status = 'geplant'`), chronologisch.
  static Future<List<TerminDto>> offene() async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('status', 'geplant')
        .order('datum');
    return rows.map((r) => TerminDto.fromJson(r)).toList();
  }

  /// Legt einen neuen Termin an und stösst danach den Kalender-Push an.
  ///
  /// Der Push ist fire-and-forget: `GoogleCalendarSyncService.push` fängt
  /// Fehler bereits intern ab (siehe dort), das zusätzliche try/catch hier
  /// ist ein Sicherheitsnetz — ein Kalenderfehler darf das Anlegen des
  /// Termins nie verhindern.
  static Future<TerminDto> anlegen({
    required String betriebId,
    required String typ,
    required DateTime datum,
    required String titel,
    String? notizen,
    String anlass = 'manuell',
  }) async {
    final dto = TerminDto(
      id: const Uuid().v4(),
      userId: _userId,
      betriebId: betriebId,
      datum: datum,
      typ: typ,
      anlass: anlass,
      titel: titel,
      notizen: notizen,
      status: 'geplant',
    );
    await SupabaseService.client.from(_table).insert(dto.toJson());
    try {
      await GoogleCalendarSyncService.push('termin', dto.id);
    } catch (_) {
      // push() faengt bereits intern ab -- dieser Fang ist nur ein
      // zusaetzliches Sicherheitsnetz.
    }
    return dto;
  }

  /// Markiert den Termin als erledigt. Der Kalender-Eintrag wird beim
  /// nächsten Push/Reconcile automatisch entfernt (`buildEvent()` liefert
  /// für Status `erledigt`/`abgesagt` `null`, siehe
  /// `google-calendar-sync/index.ts`).
  static Future<void> erledigen(String id) async {
    await SupabaseService.client
        .from(_table)
        .update({'status': 'erledigt'})
        .eq('id', id);
    try {
      await GoogleCalendarSyncService.push('termin', id);
    } catch (_) {}
  }

  /// Löscht den Termin. Der Push danach räumt den verwaisten
  /// Kalender-Eintrag auf (die Zeile ist dann weg, `pushOne` löscht das
  /// gemappte Google-Event, wenn es die Entität nicht mehr findet).
  static Future<void> loeschen(String id) async {
    await SupabaseService.client.from(_table).delete().eq('id', id);
    try {
      await GoogleCalendarSyncService.push('termin', id);
    } catch (_) {}
  }
}
