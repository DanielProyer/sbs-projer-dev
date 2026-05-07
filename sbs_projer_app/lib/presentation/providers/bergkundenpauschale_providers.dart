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

final bergkundenpauschaleCountProvider = Provider<int>((ref) {
  return ref.watch(bergkundenpauschaleProvider).length;
});

/// Anzahl Bergkundenpauschalen im aktuellen Jahr
final bergkundenpauschaleCountAktuellesJahrProvider = Provider<int>((ref) {
  final all = ref.watch(bergkundenpauschaleProvider);
  final jahr = DateTime.now().year;
  return all.where((p) => p.datum.year == jahr).length;
});

final bergkundenpauschaleByBetriebProvider = FutureProvider.family<
    List<BergkundenpauschaleLocal>, String>((ref, betriebId) {
  return BergkundenpauschaleRepository.getByBetrieb(betriebId);
});
