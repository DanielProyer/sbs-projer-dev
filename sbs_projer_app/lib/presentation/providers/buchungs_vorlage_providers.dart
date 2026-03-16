import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_vorlage_repository.dart';

final buchungsVorlagenStreamProvider =
    StreamProvider<List<BuchungsVorlage>>((ref) {
  return BuchungsVorlageRepository.watchAll();
});

final buchungsVorlagenProvider = Provider<List<BuchungsVorlage>>((ref) {
  return ref.watch(buchungsVorlagenStreamProvider).valueOrNull ?? [];
});

/// Nur manuelle Vorlagen (ohne auto_trigger) für das Buchung-Formular.
final manuelleBuchungsVorlagenProvider =
    FutureProvider<List<BuchungsVorlage>>((ref) {
  return BuchungsVorlageRepository.getManuell();
});
