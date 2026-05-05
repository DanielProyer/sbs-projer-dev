import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';

final eigenauftraegeStreamProvider = StreamProvider<List<EigenauftragLocal>>((ref) {
  return EigenauftragRepository.watchAll();
});

final eigenauftraegeProvider = Provider<List<EigenauftragLocal>>((ref) {
  return ref.watch(eigenauftraegeStreamProvider).value ?? [];
});

final eigenauftragCountProvider = FutureProvider<int>((ref) {
  ref.watch(eigenauftraegeStreamProvider);
  return EigenauftragRepository.count();
});

/// Anzahl Eigenaufträge im aktuellen Jahr
final eigenauftragCountAktuellesJahrProvider = Provider<int>((ref) {
  final all = ref.watch(eigenauftraegeProvider);
  final jahr = DateTime.now().year;
  return all.where((e) => e.datum.year == jahr).length;
});

final eigenauftraegeByBetriebProvider =
    StreamProvider.family<List<EigenauftragLocal>, String>((ref, betriebId) {
  return EigenauftragRepository.watchByBetrieb(betriebId);
});
