import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ReinigungBuchungNachtragErgebnis {
  /// Abgeschlossene, verrechenbare Reinigungen ab Stichtag ohne Buchung.
  final int kandidaten;

  /// Erfolgreich nachgebucht.
  final int gebucht;

  /// Vom Buchungs-Service bewusst übersprungen (netto 0, keine Vorlage,
  /// keine Rechnungs-/Barzahlungsart) — kein Fehler.
  final int uebersprungen;

  /// Fehlgeschlagen (Betrieb fehlt / Exception).
  final int fehler;

  const ReinigungBuchungNachtragErgebnis({
    required this.kandidaten,
    required this.gebucht,
    required this.uebersprungen,
    required this.fehler,
  });
}

/// Trägt fehlende Reinigungs-Buchungen nach — z.B. wenn beim Abschluss der
/// Rechnungs-/Buchungsblock scheiterte und die Buchung übersprungen wurde.
///
/// Nutzt exakt dieselbe Logik wie die Live-Buchung ([ReinigungBuchungService])
/// und ist idempotent (Duplikat-Check via `beleg_id`). Es wird KEINE Rechnung
/// erzeugt und KEINE Mail versendet — nur die Buchhaltung.
///
/// **Sicherheits-Stichtag [stichtag]:** Reinigungen davor sind über den
/// Buchhaltungs-Voll-Import (Excel) abgedeckt und werden NIE einzeln gebucht
/// (sonst Doppelerfassung).
class ReinigungBuchungNachtrag {
  static const stichtag = '2025-12-01';

  static Future<ReinigungBuchungNachtragErgebnis> nachtragen(
      {bool dryRun = false}) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser!.id;
    const pageSize = 1000;

    // 1. Abgeschlossene Reinigungen ab Stichtag laden (seitenweise).
    final rows = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final page = await client
          .from('reinigungen')
          .select()
          .eq('user_id', userId)
          .eq('status', 'abgeschlossen')
          .gte('datum', stichtag)
          .order('datum')
          .order('id')
          .range(from, from + pageSize - 1);
      final list = List<Map<String, dynamic>>.from(page);
      rows.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }

    // 2. Bereits gebuchte Belege sammeln (beleg_typ='rechnung').
    final gebuchteBelege = <String>{};
    from = 0;
    while (true) {
      final page = await client
          .from('buchungen')
          .select('beleg_id')
          .eq('beleg_typ', 'rechnung')
          .range(from, from + pageSize - 1);
      final list = List<Map<String, dynamic>>.from(page);
      for (final b in list) {
        final id = b['beleg_id']?.toString();
        if (id != null && id.isNotEmpty) gebuchteBelege.add(id);
      }
      if (list.length < pageSize) break;
      from += pageSize;
    }

    // 3. Kandidaten ermitteln und (falls nicht dryRun) nachbuchen.
    int kandidaten = 0, gebucht = 0, uebersprungen = 0, fehler = 0;
    for (final row in rows) {
      final r = ReinigungMapper.fromDto(Reinigung.fromJson(row));
      if (r.istKulanz || r.istHeinekenMonteur) continue;
      final sid = r.serverId;
      if (sid == null || gebuchteBelege.contains(sid)) continue;
      kandidaten++;
      if (dryRun) continue;
      try {
        final betrieb = await BetriebRepository.getByServerId(r.betriebId);
        if (betrieb == null) {
          fehler++;
          continue;
        }
        final buchung =
            await ReinigungBuchungService.createFromReinigung(r, betrieb);
        if (buchung != null) {
          gebucht++;
        } else {
          uebersprungen++;
        }
      } catch (e) {
        debugPrint('[Nachtrag] $sid: $e');
        fehler++;
      }
    }

    return ReinigungBuchungNachtragErgebnis(
      kandidaten: kandidaten,
      gebucht: gebucht,
      uebersprungen: uebersprungen,
      fehler: fehler,
    );
  }
}
