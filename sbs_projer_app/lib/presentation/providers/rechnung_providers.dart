import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

final rechnungenStreamProvider = StreamProvider<List<Rechnung>>((ref) {
  return RechnungRepository.watchAll();
});

final rechnungenProvider = Provider<List<Rechnung>>((ref) {
  return ref.watch(rechnungenStreamProvider).valueOrNull ?? [];
});

final rechnungCountProvider = Provider<int>((ref) {
  return ref.watch(rechnungenProvider).length;
});

final offeneRechnungenCountProvider = Provider<int>((ref) {
  return ref.watch(rechnungenProvider)
      .where((r) => r.zahlungsstatus != 'bezahlt' && r.zahlungsstatus != 'abgeschrieben')
      .length;
});

/// Kundenrechnungen (Datenbasis für den Forderungen-Hub). Die Mahnfällig-
/// Berechnung erfolgt im Screen via ForderungService.
final forderungenProvider = Provider<List<Rechnung>>((ref) {
  final alle = ref.watch(rechnungenProvider);
  return alle.where((r) => r.rechnungstyp == 'rechnung_kunde').toList();
});

final rechnungenByBetriebProvider =
    StreamProvider.family<List<Rechnung>, String>((ref, betriebId) {
  return RechnungRepository.watchByBetrieb(betriebId);
});

final mahnwesenDashboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return RechnungRepository.getMahnwesenDashboard();
});
