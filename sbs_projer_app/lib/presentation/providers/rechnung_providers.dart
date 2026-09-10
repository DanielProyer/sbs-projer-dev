import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
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

/// Abgeschlossene Reinigungen ohne ERTRAGSBUCHUNG — die zweite Frühwarnung
/// in den Forderungen.
///
/// Bis zum 10.09.2026 war das Nachbuchen ausschliesslich über den Dialog der
/// Warnung «Reinigungen ohne Rechnung» erreichbar. Fehlte nur die Buchung —
/// der häufigere Fall, weil sie der letzte Schritt der Abschlusskette ist —
/// erschien diese Warnung gar nicht, und es gab keinen Weg zum Nachbuchen.
/// Signina (07.09.) und Mountain Plaza (09.09.) lagen deshalb tagelang.
///
/// Bewusst nur die letzten 60 Tage: Ein Abbruch fällt binnen Wochen auf, und
/// die volle Suche über die ganze Historie gehört in den Knopf, nicht in
/// jeden Aufbau dieses Screens.
final fehlendeBuchungenProvider =
    FutureProvider<List<FehlendeBuchung>>((ref) async {
  return BuchungNachholService.finde(
    ab: DateTime.now().subtract(const Duration(days: 60)),
  );
});
