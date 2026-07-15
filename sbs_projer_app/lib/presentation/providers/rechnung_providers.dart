import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/rechnung/reinigungen_ohne_rechnung.dart';

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

final rechnungenByBetriebProvider =
    StreamProvider.family<List<Rechnung>, String>((ref, betriebId) {
  return RechnungRepository.watchByBetrieb(betriebId);
});

/// Abgeschlossene Reinigungen ohne Kundenrechnung — Frühwarnung in den
/// Forderungen. Siehe [ReinigungenOhneRechnung] für den Hintergrund (38 stille
/// Ausfälle 26.06.–13.07.2026, Ursache bis heute ungeklärt).
final reinigungenOhneRechnungProvider =
    FutureProvider<List<ReinigungOhneRechnung>>((ref) async {
  return ReinigungenOhneRechnung.finde();
});
