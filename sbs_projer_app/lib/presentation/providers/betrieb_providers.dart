import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

final betriebeStreamProvider = StreamProvider<List<BetriebLocal>>((ref) {
  return BetriebRepository.watchAll();
});

final betriebeProvider = Provider<List<BetriebLocal>>((ref) {
  final list = ref.watch(betriebeStreamProvider).valueOrNull ?? [];
  return [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

final betriebCountProvider = Provider<int>((ref) {
  return ref.watch(betriebeProvider).length;
});

final betriebNameMapProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(betriebeProvider);
  return {for (final b in list) if (b.serverId != null) b.serverId!: b.name};
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
  return {for (final b in list) if (b.serverId != null) b.serverId!: b.regionId};
});
