import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';

final buchungenStreamProvider = StreamProvider<List<Buchung>>((ref) {
  return BuchungRepository.watchAll();
});

final buchungenProvider = Provider<List<Buchung>>((ref) {
  return ref.watch(buchungenStreamProvider).valueOrNull ?? [];
});

/// Saldi aller Konten — wird invalidiert wenn buchungenStreamProvider sich ändert.
final kontoSaldiProvider = FutureProvider<Map<int, double>>((ref) {
  ref.watch(buchungenStreamProvider);
  return BuchungService.getAllSaldi();
});
