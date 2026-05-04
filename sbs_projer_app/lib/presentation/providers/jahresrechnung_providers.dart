import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/services/rechnung/jahresrechnung_service.dart';

/// Alle Betriebe mit rechnungsstellung == 'jahresrechnung'.
final jahresrechnungBetriebeProvider =
    FutureProvider<List<BetriebLocal>>((ref) async {
  final alle = await BetriebRepository.getAll();
  return alle
      .where((b) => b.rechnungsstellung == 'jahresrechnung')
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Noch nicht abgerechnete Reinigungen eines Betriebs im Jahr.
final offeneJahresreinigungenProvider = FutureProvider.family<
    List<ReinigungLocal>, ({String betriebId, int jahr})>((ref, params) async {
  return JahresrechnungService.sammleReinigungen(
      params.betriebId, params.jahr);
});
