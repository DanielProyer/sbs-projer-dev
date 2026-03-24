import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchungs_beleg.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';

final buchungsBelegeProvider =
    FutureProvider.family<List<BuchungsBeleg>, String>((ref, buchungId) {
  return BuchungsBelegRepository.getByBuchung(buchungId);
});
