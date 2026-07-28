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

final buchungenCountProvider = Provider<int>((ref) {
  return ref.watch(buchungenProvider).length;
});

final buchungenByPeriodeProvider =
    FutureProvider.family<List<Buchung>, ({int jahr, int monat})>((ref, params) {
  ref.watch(buchungenStreamProvider);
  return BuchungRepository.getByPeriode(params.jahr, params.monat);
});

final buchungenByKontoProvider =
    FutureProvider.family<List<Buchung>, int>((ref, kontonummer) {
  ref.watch(buchungenStreamProvider);
  return BuchungRepository.getByKonto(kontonummer);
});

final buchungenCountByPeriodeProvider =
    FutureProvider.family<int, ({int jahr, int monat})>((ref, params) {
  ref.watch(buchungenStreamProvider);
  return BuchungRepository.countByPeriode(params.jahr, params.monat);
});

/// Saldi aller Konten — wird invalidiert wenn buchungenStreamProvider sich ändert.
final kontoSaldiProvider = FutureProvider<Map<int, double>>((ref) {
  ref.watch(buchungenStreamProvider);
  return BuchungService.getAllSaldi();
});

/// Gescannte Spesenbelege des laufenden Jahres — Zahl auf der Dashboard-Kachel
/// (analog zu den uebrigen Kacheln: aktuelles Jahr, nicht die Gesamthistorie).
final spesenBelegeCountAktuellesJahrProvider = FutureProvider<int>((ref) {
  ref.watch(buchungenStreamProvider);
  return BuchungRepository.spesenBelegeImJahr(DateTime.now().year);
});
