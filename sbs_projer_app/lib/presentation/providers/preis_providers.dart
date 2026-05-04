import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';

/// Aktuelle Preise (gültig für heute).
final aktuellePreiseProvider = FutureProvider<Preis?>((ref) {
  return PreisRepository.getAktuell();
});

/// Alle Preisversionen, sortiert nach gueltig_ab absteigend.
final allePreiseProvider = FutureProvider<List<Preis>>((ref) {
  ref.watch(aktuellePreiseProvider);
  return PreisRepository.getAll();
});
