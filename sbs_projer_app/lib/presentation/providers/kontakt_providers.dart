import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';

/// Alle Kontakte des Users.
final kontakteProvider =
    FutureProvider<List<KontaktLocal>>((ref) async {
  return KontaktRepository.getAll();
});

/// Kontakte gefiltert nach Kategorie.
final kontakteByKategorieProvider =
    FutureProvider.family<List<KontaktLocal>, String>((ref, kategorie) async {
  return KontaktRepository.getByKategorie(kategorie);
});

/// Kontakte eines Betriebs.
final kontakteByBetriebProvider =
    FutureProvider.family<List<KontaktLocal>, String>((ref, betriebId) async {
  return KontaktRepository.getByBetrieb(betriebId);
});

