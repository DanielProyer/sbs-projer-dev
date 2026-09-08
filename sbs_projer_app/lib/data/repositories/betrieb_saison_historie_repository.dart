import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/saison_historie.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Eine archivierte Saison, wie sie aus der Datenbank kommt.
class ArchivierteSaison {
  final String saison; // 'winter' | 'sommer'
  final DateTime start;
  final DateTime? ende;
  const ArchivierteSaison({
    required this.saison,
    required this.start,
    this.ende,
  });

  /// «13.12.2025–29.03.2026» bzw. «13.12.2025–offen»
  String get zeitraum {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.'
        '${x.month.toString().padLeft(2, '0')}.${x.year}';
    return '${d(start)}–${ende == null ? 'offen' : d(ende!)}';
  }
}

/// Archiv der Saisonfenster (Tabelle `betrieb_saison_historie`).
///
/// Bewusst ohne Isar-/Offline-Pfad: Das Archiv wird ausschliesslich beim
/// Bearbeiten eines Betriebs gelesen und geschrieben, und das passiert online.
/// Ein nativer Zweig wäre heute toter Code — die Android-App (V2) entsteht in
/// einem eigenen Repository und baut ihren Zugriff ohnehin neu.
class BetriebSaisonHistorieRepository {
  static const _table = 'betrieb_saison_historie';

  /// Archivierte Saisons eines Betriebs, neueste zuerst.
  static Future<List<ArchivierteSaison>> getFuerBetrieb(
    String betriebId,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];
    final rows = await SupabaseService.client
        .from(_table)
        .select('saison, start_datum, ende_datum')
        .eq('user_id', userId)
        .eq('betrieb_id', betriebId)
        .order('start_datum', ascending: false)
        .order('id');
    return [
      for (final r in rows)
        ArchivierteSaison(
          saison: r['saison'] as String,
          start: DateTime.parse(r['start_datum'] as String),
          ende: r['ende_datum'] == null
              ? null
              : DateTime.parse(r['ende_datum'] as String),
        ),
    ];
  }

  /// Schreibt abgeschlossene Saisons ins Archiv.
  ///
  /// Idempotent: Dieselbe Saison zweimal zu archivieren (etwa weil ein
  /// Startdatum geändert und wieder zurückgesetzt wurde) läuft über den
  /// eindeutigen Index ins Leere, statt Dubletten anzulegen.
  ///
  /// Wirft nicht — ein fehlgeschlagenes Archiv darf das Speichern des
  /// Betriebs nie verhindern.
  static Future<void> archiviere(
    String betriebId,
    List<SaisonArchivEintrag> eintraege,
  ) async {
    if (eintraege.isEmpty) return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    String tag(DateTime d) => d.toIso8601String().split('T').first;
    try {
      await SupabaseService.client.from(_table).upsert(
        [
          for (final e in eintraege)
            {
              'betrieb_id': betriebId,
              'user_id': userId,
              'saison': e.saison,
              'start_datum': tag(e.start),
              'ende_datum': e.ende == null ? null : tag(e.ende!),
            },
        ],
        onConflict: 'betrieb_id,saison,start_datum',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('[Saison-Archiv] fehlgeschlagen: $e');
    }
  }
}
