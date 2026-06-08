import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';

final camtPrueflisteProvider =
    FutureProvider.autoDispose<List<CamtPrueflisteEintrag>>((ref) async {
  return CamtPrueflisteRepository.getOffen();
});
