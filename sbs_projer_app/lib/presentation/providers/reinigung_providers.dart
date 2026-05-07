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

final reinigungenByAnlageProvider =
    StreamProvider.family<List<ReinigungLocal>, String>((ref, anlageId) {
  return ReinigungRepository.watchByAnlage(anlageId);
});

final reinigungenByBetriebProvider =
    StreamProvider.family<List<ReinigungLocal>, String>((ref, betriebId) {
  return ReinigungRepository.watchByBetrieb(betriebId);
});
