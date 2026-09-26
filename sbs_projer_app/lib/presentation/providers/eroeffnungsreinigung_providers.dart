import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';

final eroeffnungsreinigungenStreamProvider = StreamProvider<List<EroeffnungsreinigungLocal>>((ref) {
  return EroeffnungsreinigungRepository.watchAll();
});

final eroeffnungsreinigungenProvider = Provider<List<EroeffnungsreinigungLocal>>((ref) {
  return ref.watch(eroeffnungsreinigungenStreamProvider).valueOrNull ?? [];
});
