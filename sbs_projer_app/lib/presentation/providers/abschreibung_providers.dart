import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/repositories/abschreibung_lauf_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/jahrgang_abschreibung.dart';

/// Eine Zeile «Entgeltsminderung» (MWST Ziff. 235) für ein Quartal.
typedef Entgeltsminderung = ({
  int jahr,
  int quartal,
  double satz,
  double netto,
  double mwst,
  int anzahl,
  String text,
});

/// Ziff. 235 je Quartal und Satz aus `view_entgeltsminderung` (Migration 196).
///
/// WARUM die Sicht und nicht die Lauf-Tabelle: Eine einzelne Abschreibung
/// (Mahnwesen) gehört genauso in Ziff. 235 wie ein Jahrgangslauf, hängt aber
/// an keinem Lauf. Am 20.09.2026 wären so 5.60 aus der Q3-Deklaration
/// gefallen. Die Sicht führt beides zusammen, ohne doppelt zu zählen.
final entgeltsminderungProvider = FutureProvider.autoDispose
    .family<List<Entgeltsminderung>, int>((ref, jahr) async {
      final rows = await SupabaseService.client
          .from('view_entgeltsminderung')
          .select()
          .eq('user_id', SupabaseService.dataUserId)
          .eq('jahr', jahr)
          .order('quartal')
          .order('satz');
      double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
      return [
        for (final r in rows)
          (
            jahr: r['jahr'] as int,
            quartal: r['quartal'] as int,
            satz: d(r['satz']),
            netto: d(r['netto']),
            mwst: d(r['mwst']),
            anzahl: r['anzahl'] as int? ?? 0,
            text: r['text'] as String? ?? '',
          ),
      ];
    });

/// Alle Abschreibungsläufe (wenige Zeilen, eine je Geschäftsjahr).
final abschreibungLaeufeProvider =
    FutureProvider.autoDispose<List<AbschreibungLauf>>(
      (ref) => AbschreibungLaufRepository.getAll(),
    );

/// Vorschau des Schritts «Jahrgang abschreiben» für ein Geschäftsjahr.
final jahrgangAbschreibVorschauProvider = FutureProvider.autoDispose
    .family<AbschreibVorschau, int>((ref, jahr) async {
      final (offene, betriebe) = await (
        RechnungRepository.getOffene(),
        BetriebRepository.getAll(),
      ).wait;
      final namen = {
        for (final b in betriebe)
          if (b.serverId != null) b.serverId!: b.name,
      };
      return AbschreibVorschau.aus(
        auswahlFuer(offene, geschaeftsjahr: jahr, betriebNamen: namen),
      );
    });
