import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';

/// Eingangsrechnungen (Kreditoren) für die Listen-/Bestätigungsansicht.
/// Lädt alle relevanten Stati (ohne `verworfen`).
final eingangsrechnungenProvider =
    FutureProvider<List<Eingangsrechnung>>((ref) async {
  return EingangsrechnungRepository.getByStatus(const [
    'erkannt',
    'bestaetigt',
    'gebucht',
    'zahlung_vorgemerkt',
    'exportiert',
    'bezahlt',
    'abgelegt',
  ]);
});
