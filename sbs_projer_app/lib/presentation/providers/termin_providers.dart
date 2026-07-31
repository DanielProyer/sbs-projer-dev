import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';

/// Offene Termine (`status = 'geplant'`, Tabelle `termine`) — bestätigte
/// Eröffnungs-/Endreinigungen und sonstige manuelle Termine.
///
/// Leitgedanke (Etappe 4): «Berechnet bleibt berechnet, bestätigt wird
/// gespeichert» — dieser Provider zeigt nur, was Daniel tatsächlich
/// bestätigt hat; die laufend berechneten Vorschläge liefert weiterhin
/// `autoTermineProvider` in `tour_providers.dart`.
final offeneTermineProvider = FutureProvider<List<TerminDto>>((ref) {
  return TerminRepository.offene();
});
