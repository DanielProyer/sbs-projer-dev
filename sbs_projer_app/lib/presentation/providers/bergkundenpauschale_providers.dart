import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';

final bergkundenpauschaleStreamProvider =
    StreamProvider<List<BergkundenpauschaleLocal>>((ref) {
  return BergkundenpauschaleRepository.watchAll();
});

final bergkundenpauschaleProvider =
    Provider<List<BergkundenpauschaleLocal>>((ref) {
  return ref.watch(bergkundenpauschaleStreamProvider).value ?? [];
});
