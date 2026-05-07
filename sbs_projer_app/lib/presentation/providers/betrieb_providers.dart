import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  return BetriebRepository.watchAll();
});

final betriebeProvider = Provider<List<BetriebLocal>>((ref) {
  final list = ref.watch(betriebeStreamProvider).valueOrNull ?? [];
  return [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

final betriebCountProvider = Provider<int>((ref) {
  return ref.watch(betriebeProvider).length;
});
