import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/repositories/pikett_dienst_repository.dart';

final pikettDiensteStreamProvider = StreamProvider<List<PikettDienstLocal>>((ref) {
  return PikettDienstRepository.watchAll();
});

final pikettDiensteProvider = Provider<List<PikettDienstLocal>>((ref) {
  return ref.watch(pikettDiensteStreamProvider).valueOrNull ?? [];
});

final pikettDienstCountProvider = FutureProvider<int>((ref) {
  ref.watch(pikettDiensteStreamProvider);
  return PikettDienstRepository.count();
});
