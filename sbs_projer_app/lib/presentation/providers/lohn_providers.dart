import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/data/models/lohn_abrechnung.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';

final lohnEinstellungenProvider =
    FutureProvider.family<LohnEinstellungen?, int>((ref, jahr) {
  return LohnRepository.getEinstellungen(jahr);
});

final lohnAbrechnungenProvider =
    FutureProvider.family<List<LohnAbrechnung>, int>((ref, jahr) {
  return LohnRepository.getAbrechnungen(jahr);
});

final lohnJahresTotaleProvider =
    FutureProvider.family<Map<String, double>, int>((ref, jahr) {
  return LohnRepository.jahresTotale(jahr);
});
