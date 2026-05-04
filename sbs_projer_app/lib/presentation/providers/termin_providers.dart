import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';

final termineStreamProvider = StreamProvider<List<TerminLocal>>((ref) {
  return TerminRepository.watchAll();
});

final termineProvider = Provider<List<TerminLocal>>((ref) {
  return ref.watch(termineStreamProvider).valueOrNull ?? [];
});

final terminCountProvider = FutureProvider<int>((ref) {
  ref.watch(termineStreamProvider);
  return TerminRepository.count();
});

final termineByBetriebProvider =
    StreamProvider.family<List<TerminLocal>, String>((ref, betriebId) {
  return TerminRepository.watchByBetrieb(betriebId);
});

/// Termine der nächsten 7 Tage (für Dashboard-Widget)
final anstehendeTermineProvider = FutureProvider<List<TerminLocal>>((ref) async {
  ref.watch(termineStreamProvider);
  final heute = DateTime.now();
  final in7Tagen = heute.add(const Duration(days: 7));
  final termine = await TerminRepository.getByDateRange(heute, in7Tagen);
  // Nur geplante und vorgeschlagene Termine, sortiert nach Datum
  final filtered = termine
      .where((t) => t.status == 'geplant' || t.status == 'vorgeschlagen')
      .toList()
    ..sort((a, b) => a.datum.compareTo(b.datum));
  return filtered;
});
