import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/material_kategorie_repository.dart';

// --- Lager (Fahrzeugbestand) ---

final materialienStreamProvider = StreamProvider<List<Lager>>((ref) {
  return LagerRepository.watchAll();
});

final materialienProvider = Provider<List<Lager>>((ref) {
  return ref.watch(materialienStreamProvider).valueOrNull ?? [];
});

final materialCountProvider = FutureProvider<int>((ref) {
  ref.watch(materialienStreamProvider);
  return LagerRepository.count();
});

final niedrigCountProvider = FutureProvider<int>((ref) {
  ref.watch(materialienStreamProvider);
  return LagerRepository.countNiedrig();
});

// --- Kategorien ---

final kategorienProvider = FutureProvider<List<MaterialKategorie>>((ref) {
  return MaterialKategorieRepository.getAll();
});
