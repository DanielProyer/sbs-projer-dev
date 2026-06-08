import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/repositories/camt_regel_repository.dart';

final camtRegelnProvider =
    FutureProvider.autoDispose<List<CamtRegel>>((ref) async {
  return CamtRegelRepository.getAll();
});
