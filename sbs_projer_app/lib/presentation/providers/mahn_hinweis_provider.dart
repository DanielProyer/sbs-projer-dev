import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/mahn_hinweis.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

const _keinHinweis = MahnHinweis(
  stufe: MahnHinweisStufe.keine,
  offene: [],
  anzahlGemahnt: 0,
  summeOffen: 0,
);

/// Hinweis beim Service (Mahnwesen Teil 3): gemahnte Rechnungen eines
/// Betriebs (Server-Id). Rechnungen ab [kMahnStart] seitenweise über
/// `getKundenrechnungenAb` (`.order('id')`), sperrende Mahnfälle des Betriebs.
///
/// Fehler → [MahnHinweisStufe.keine]: Das Band ist nur ein Hinweis und darf
/// das Formular nie blockieren.
final mahnHinweisProvider =
    FutureProvider.autoDispose.family<MahnHinweis, String>((ref, betriebId) async {
  try {
    final rechnungen =
        await RechnungRepository.getKundenrechnungenAb(kMahnStart, betriebId: betriebId);
    final faelle = await MahnfallRepository.getSperrendeFaelle();
    final imMahnfall = {
      for (final f in faelle)
        if (f.betriebId == betriebId) ...f.rechnungIds,
    };
    return mahnHinweis(rechnungen: rechnungen, imMahnfall: imMahnfall);
  } catch (e) {
    debugPrint('[MahnHinweis] $betriebId: $e');
    return _keinHinweis;
  }
});
