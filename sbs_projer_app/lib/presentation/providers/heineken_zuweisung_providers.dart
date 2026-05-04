import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';

/// Alle Heineken-Zuweisungen (Map: funktion → KontaktLocal?).
final heinekenZuweisungenProvider =
    FutureProvider<Map<String, KontaktLocal?>>((ref) async {
  return KontaktRepository.getAllHeinekenZuweisungen();
});
