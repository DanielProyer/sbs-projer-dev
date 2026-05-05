import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/eroeffnungsreinigung_repository.dart';

final eroeffnungsreinigungenStreamProvider = StreamProvider<List<EroeffnungsreinigungLocal>>((ref) {
  return EroeffnungsreinigungRepository.watchAll();
});

final eroeffnungsreinigungenProvider = Provider<List<EroeffnungsreinigungLocal>>((ref) {
  return ref.watch(eroeffnungsreinigungenStreamProvider).valueOrNull ?? [];
});

final eroeffnungsreinigungCountProvider = FutureProvider<int>((ref) {
  ref.watch(eroeffnungsreinigungenStreamProvider);
  return EroeffnungsreinigungRepository.count();
});

/// Anzahl Eröffnungsreinigungen im aktuellen Jahr
final eroeffnungsreinigungCountAktuellesJahrProvider = Provider<int>((ref) {
  final all = ref.watch(eroeffnungsreinigungenProvider);
  final jahr = DateTime.now().year;
  return all.where((e) => e.datum.year == jahr).length;
});

final eroeffnungsreinigungenByBetriebProvider =
    StreamProvider.family<List<EroeffnungsreinigungLocal>, String>((ref, betriebId) {
  return EroeffnungsreinigungRepository.watchByBetrieb(betriebId);
});
