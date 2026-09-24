import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

/// Ein Mahnfall nach Id (Arbeitsblatt `/rechnungen/mahnfall/:id`).
final mahnfallProvider = FutureProvider.autoDispose.family<Mahnfall?, String>(
    (ref, id) => MahnfallRepository.getById(id));

/// Alle Mahnfälle, in denen eine Rechnung steht (Hinweis im Mahnverlauf).
final mahnfaelleZuRechnungProvider =
    FutureProvider.autoDispose.family<List<Mahnfall>, String>(
        (ref, rechnungId) => MahnfallRepository.getByRechnung(rechnungId));

/// Die Rechnungen eines Falls, frisch aus der DB, in der Reihenfolge des
/// Falls. Hängt am [mahnfallProvider] — ein Invalidate des Falls lädt sie
/// mit neu (Zahlungsstatus nach «Konkurs», «abgeschrieben» …).
final mahnfallRechnungenProvider =
    FutureProvider.autoDispose.family<List<Rechnung>, String>((ref, id) async {
  final fall = await ref.watch(mahnfallProvider(id).future);
  if (fall == null) return const [];
  final out = <Rechnung>[];
  for (final rid in fall.rechnungIds) {
    final r = await RechnungRepository.getById(rid);
    if (r != null) out.add(r);
  }
  return out;
});

/// Protokoll-Pfade aller Reinigungspositionen einer Rechnung.
final protokollPfadeZuRechnungProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
        (ref, rechnungId) => MahnfallRepository.protokollPfadeZuRechnung(rechnungId));
