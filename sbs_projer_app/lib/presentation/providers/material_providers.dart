import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_kategorie_repository.dart';

// --- Lager (Fahrzeugbestand) ---

final materialienStreamProvider = StreamProvider<List<Lager>>((ref) {
  return LagerRepository.watchAll();
});

// `valueOrNull` liefert beim Neuladen (invalidate) den letzten Stand weiter,
// nicht `[]` — darauf verlässt sich die Kartenansicht des Material-Screens:
// Nach jedem Bestand ± wird neu geladen, und ein kurzes itemCount 0 würfe
// den PageView auf die erste Karte zurück (test/material_providers_test.dart).
final materialienProvider = Provider<List<Lager>>((ref) {
  return ref.watch(materialienStreamProvider).valueOrNull ?? [];
});

final niedrigCountProvider = Provider<int>((ref) {
  return ref.watch(materialienProvider).where((m) => m.bestandNiedrig == true).length;
});

final vorgemerktCountProvider = Provider<int>((ref) {
  return ref.watch(materialienProvider).where((m) => m.vorgemerkt).length;
});

// --- Kategorien ---

final kategorienProvider = FutureProvider<List<MaterialKategorie>>((ref) {
  return MaterialKategorieRepository.getAll();
});
