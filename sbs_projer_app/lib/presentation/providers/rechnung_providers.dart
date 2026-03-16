import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

final rechnungenStreamProvider = StreamProvider<List<Rechnung>>((ref) {
  return RechnungRepository.watchAll();
});

final rechnungenProvider = Provider<List<Rechnung>>((ref) {
  return ref.watch(rechnungenStreamProvider).valueOrNull ?? [];
});

final rechnungCountProvider = FutureProvider<int>((ref) {
  ref.watch(rechnungenStreamProvider);
  return RechnungRepository.count();
});

final offeneRechnungenCountProvider = FutureProvider<int>((ref) {
  ref.watch(rechnungenStreamProvider);
  return RechnungRepository.countOffene();
});

final rechnungenByBetriebProvider =
    StreamProvider.family<List<Rechnung>, String>((ref, betriebId) {
  return RechnungRepository.watchByBetrieb(betriebId);
});
