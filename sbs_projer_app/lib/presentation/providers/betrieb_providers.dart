import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  return BetriebRepository.watchAll();
});

/// Ferien-Perioden aus der Tabelle `betrieb_ferien`, gruppiert nach
/// `betriebId` (== [BetriebLocal.serverId]). Solange dieser Provider noch
/// laedt oder fehlschlaegt, bleibt die Map leer — [betriebeProvider] setzt
/// dann kein [BetriebLocal.ferienPerioden] und die Aufrufer in
/// core/util/betrieb_ferien.dart fallen automatisch auf die alten
/// Spaltenpaare zurueck.
final ferienPeriodenProvider =
    FutureProvider<Map<String, List<({DateTime von, DateTime bis})>>>((
      ref,
    ) async {
      final alle = await BetriebFerienRepository.getAll();
      final map = <String, List<({DateTime von, DateTime bis})>>{};
      for (final f in alle) {
        (map[f.betriebId] ??= []).add((von: f.von, bis: f.bis));
      }
      return map;
    });

final betriebeProvider = Provider<List<BetriebLocal>>((ref) {
  final list = ref.watch(betriebeStreamProvider).valueOrNull ?? [];
  final ferienAsync = ref.watch(ferienPeriodenProvider);
  final ferienMap = ferienAsync.valueOrNull;
  for (final b in list) {
    final serverId = b.serverId;
    if (serverId == null) continue;
    // Erst wenn die Tabelle geladen ist, wird sie zur alleinigen Quelle —
    // dann auch mit LEERER Liste, denn "keine Periode" ist eine Aussage.
    // Ohne das kaeme eine geloeschte Ferienperiode ueber die alten Spalten
    // zurueck und liesse sich nie entfernen.
    if (ferienMap != null) {
      b.ferienPerioden = ferienMap[serverId] ?? const [];
    }
  }
  return [...list]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

final betriebCountProvider = Provider<int>((ref) {
  return ref.watch(betriebeProvider).length;
});

final betriebNameMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null) b.serverId!: b.name,
  };
});

final betriebOrtMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null && b.ort != null) b.serverId!: b.ort!,
  };
});

final betriebRegionIdMapProvider = Provider<Map<String, String?>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {
    for (final b in list)
      if (b.serverId != null) b.serverId!: b.regionId,
  };
});
