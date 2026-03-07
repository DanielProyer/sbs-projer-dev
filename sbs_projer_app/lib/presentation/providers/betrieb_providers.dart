import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  return BetriebRepository.watchAll();
});

final betriebeProvider = Provider<List<BetriebLocal>>((ref) {
  return ref.watch(betriebeStreamProvider).valueOrNull ?? [];
});

final betriebCountProvider = FutureProvider<int>((ref) {
  ref.watch(betriebeStreamProvider);
  return BetriebRepository.count();
});
