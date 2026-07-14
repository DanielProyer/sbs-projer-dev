import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';

final reinigungenStreamProvider = StreamProvider<List<ReinigungLocal>>((ref) {
  return ReinigungRepository.watchAll();
});

final reinigungenProvider = Provider<List<ReinigungLocal>>((ref) {
  return ref.watch(reinigungenStreamProvider).valueOrNull ?? [];
});

final reinigungCountProvider = Provider<int>((ref) {
  return ref.watch(reinigungenProvider).length;
});

/// Anzahl Reinigungen im aktuellen Jahr
final reinigungCountAktuellesJahrProvider = Provider<int>((ref) {
  final all = ref.watch(reinigungenProvider);
  final jahr = DateTime.now().year;
  return all.where((r) => r.datum.year == jahr).length;
});

/// Reinigungen eines Kalenderjahres (server-seitig gefiltert) — schneller Pfad
/// für die Reinigungsliste (nur ~1 Jahr statt aller ~8600 Zeilen).
final reinigungenByJahrProvider =
    FutureProvider.family<List<ReinigungLocal>, int>((ref, jahr) {
  return ReinigungRepository.getByJahr(jahr);
});

/// Verfügbare Jahre für den Jahr-Filter (lädt nur die Datums-Spalte).
final reinigungJahreProvider = FutureProvider<List<int>>((ref) {
  return ReinigungRepository.getJahre();
});

final reinigungenByAnlageProvider =
    StreamProvider.family<List<ReinigungLocal>, String>((ref, anlageId) {
  return ReinigungRepository.watchByAnlage(anlageId);
});

final reinigungenByBetriebProvider =
    StreamProvider.family<List<ReinigungLocal>, String>((ref, betriebId) {
  return ReinigungRepository.watchByBetrieb(betriebId);
});
