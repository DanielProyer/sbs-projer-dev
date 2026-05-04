import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/biersorte.dart';
import 'package:sbs_projer_app/data/repositories/biersorte_repository.dart';

/// Alle Biersorten des Users.
final biersortenProvider = FutureProvider<List<Biersorte>>((ref) async {
  return BiersorteRepository.getAll();
});

/// Anzahl Bierleitungen pro Biersorte (name → count).
final biersorteLeitungenCountProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(biersortenProvider); // invalidiert mit
  return BiersorteRepository.getLeitungenCounts();
});

/// Map: name.toLowerCase() → kategorie (für schnellen Lookup).
final biersorteKategorieMapProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final biersorten = await ref.watch(biersortenProvider.future);
  return {
    for (final b in biersorten) b.name.toLowerCase(): b.kategorie,
  };
});
