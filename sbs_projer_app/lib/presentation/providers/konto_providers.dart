import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/konto.dart';
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';

final kontenStreamProvider = StreamProvider<List<Konto>>((ref) {
  return KontoRepository.watchAll();
});

final kontenProvider = Provider<List<Konto>>((ref) {
  return ref.watch(kontenStreamProvider).valueOrNull ?? [];
});

final kontenCountProvider = FutureProvider<int>((ref) {
  ref.watch(kontenStreamProvider);
  return KontoRepository.count();
});
