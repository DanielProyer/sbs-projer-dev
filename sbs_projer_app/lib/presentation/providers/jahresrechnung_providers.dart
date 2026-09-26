import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

/// Alle Betriebe mit rechnungsstellung == 'jahresrechnung'.
final jahresrechnungBetriebeProvider =
    FutureProvider<List<BetriebLocal>>((ref) async {
  final alle = await BetriebRepository.getAll();
  return alle
      .where((b) => b.rechnungsstellung == 'jahresrechnung')
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});
