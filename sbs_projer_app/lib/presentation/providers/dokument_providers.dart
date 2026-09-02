import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';

typedef DokumentFilter = ({String? bereich, int? jahr});

final dokumenteProvider = FutureProvider.family<List<Dokument>, DokumentFilter>(
  (ref, f) => DokumentRepository.getAll(bereich: f.bereich, jahr: f.jahr),
);

/// Jahre, in denen Dokumente eines Bereichs liegen (für Filter-Dropdowns).
final dokumentJahreProvider = FutureProvider.family<List<int>, String?>((
  ref,
  bereich,
) async {
  final docs = await DokumentRepository.getAll(bereich: bereich);
  final jahre = docs.map((d) => d.jahr).whereType<int>().toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return jahre;
});
