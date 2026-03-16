import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';

final stoerungenStreamProvider = StreamProvider<List<StoerungLocal>>((ref) {
  return StoerungRepository.watchAll();
});

final stoerungenProvider = Provider<List<StoerungLocal>>((ref) {
  return ref.watch(stoerungenStreamProvider).valueOrNull ?? [];
});

final stoerungCountProvider = FutureProvider<int>((ref) {
  ref.watch(stoerungenStreamProvider);
  return StoerungRepository.count();
});

final stoerungenByAnlageProvider =
    StreamProvider.family<List<StoerungLocal>, String>((ref, anlageId) {
  return StoerungRepository.watchByAnlage(anlageId);
});

final stoerungenByBetriebProvider =
    StreamProvider.family<List<StoerungLocal>, String>((ref, betriebId) {
  return StoerungRepository.watchByBetrieb(betriebId);
});
