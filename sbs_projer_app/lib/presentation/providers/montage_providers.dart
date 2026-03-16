import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';

final montagenStreamProvider = StreamProvider<List<MontageLocal>>((ref) {
  return MontageRepository.watchAll();
});

final montagenProvider = Provider<List<MontageLocal>>((ref) {
  return ref.watch(montagenStreamProvider).valueOrNull ?? [];
});

final montageCountProvider = FutureProvider<int>((ref) {
  ref.watch(montagenStreamProvider);
  return MontageRepository.count();
});

final montagenByAnlageProvider =
    StreamProvider.family<List<MontageLocal>, String>((ref, anlageId) {
  return MontageRepository.watchByAnlage(anlageId);
});

final montagenByBetriebProvider =
    StreamProvider.family<List<MontageLocal>, String>((ref, betriebId) {
  return MontageRepository.watchByBetrieb(betriebId);
});
