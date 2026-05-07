import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';

final anlagenStreamProvider = StreamProvider<List<AnlageLocal>>((ref) {
  return AnlageRepository.watchAll();
});

final anlagenProvider = Provider<List<AnlageLocal>>((ref) {
  return ref.watch(anlagenStreamProvider).valueOrNull ?? [];
});

final anlageCountProvider = Provider<int>((ref) {
  return ref.watch(anlagenProvider).length;
});

final anlagenByBetriebProvider =
    StreamProvider.family<List<AnlageLocal>, String>((ref, betriebId) {
  return AnlageRepository.watchByBetrieb(betriebId);
});
