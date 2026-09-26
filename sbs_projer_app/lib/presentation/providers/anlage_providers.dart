import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';

final anlagenStreamProvider = StreamProvider<List<AnlageLocal>>((ref) {
  return AnlageRepository.watchAll();
});

final anlagenProvider = Provider<List<AnlageLocal>>((ref) {
  return ref.watch(anlagenStreamProvider).valueOrNull ?? [];
});
